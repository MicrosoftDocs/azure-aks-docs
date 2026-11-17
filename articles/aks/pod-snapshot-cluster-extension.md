---
title: Pod snapshot cluster extension (preview)
description: Learn how to capture pod state for faster startup on Azure Kubernetes Service (AKS) with the Pod snapshot cluster extension.
author: wangyira
ms.author: wangamanda
ms.date: 11/03/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Capture pod state for faster startup with the Pod snapshot cluster extension (preview)

The Pod snapshot cluster extension captures the runtime state of a supported sandboxed pod on Azure Kubernetes Service (AKS). Restore that state to a new pod to resume processes without repeating initialization. Restore doesn't recreate the original Kubernetes Pod object. Use snapshots for workloads with costly initialization, including AI agents, isolated business application sessions, development environments, and workers that load large in-memory datasets.

By using Pod sandboxing and Kata VM isolation v2 (preview), the extension stores snapshots in [Azure Blob storage](/azure/storage/blobs/) and supports explicit or implicit snapshot selection. You can restore Pods independently of the [Agent Sandbox cluster extension (preview)](agent-sandbox-cluster-extension.md), or use both extensions to restore Sandbox workloads.

This article walks through installation, capture, and restore using your own workload. Adapt the manifests to your application's runtime requirements. Optional sections cover Sandbox restore and scheduled snapshots. Compare end-to-end restore time with cold-start time to assess startup improvements. Your application or orchestration layer still manages workload creation and idle shutdown.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites
- Use an AKS cluster running Kubernetes version 1.35 or later with Pod sandboxing enabled and Kata VM isolation v2 configured. A cluster without Pod sandboxing isn't sufficient. For general background, see [Pod sandboxing](use-pod-sandboxing.md) and [Pod sandboxing considerations](considerations-pod-sandboxing.md). Verify Kata v2 support by following the checks in this article before installing the extension.
- A Bash environment with [Azure CLI](/cli/azure/install-azure-cli) version 2.85.0 or later, `kubectl`, and `envsubst` installed. The `envsubst` command is provided by GNU gettext. Use Azure Cloud Shell in Bash mode or a local Bash environment on Linux, macOS, or Windows Subsystem for Linux (WSL).
- Snapshot and restore support only v6 VM SKUs in these families: Dasv6, Dadsv6, Dalsv6, Daldsv6, Easv6, Eadsv6, Falsv6, Fasv6, and Famsv6.
- Two Ready nodes with the same supported VM SKU for this walkthrough. Restore requires the exact source VM SKU.
- An available system node pool for the snapshot access broker. The snapshot access broker is a component that the pod snapshot cluster extension runs in the `pod-snapshot-system` namespace. It authenticates to Azure Blob Storage by using workload identity and gives node workers short-lived access scoped to their operations.
- Permission to create the storage account, managed identity, and cluster extension; assign Azure roles; and manage the Kubernetes resources and restore permissions in the example namespace.
- An AKS OIDC issuer and Microsoft Entra Workload ID enabled for the broker's workload identity. For an existing cluster, follow [Enable OIDC issuer and Microsoft Entra Workload ID on an AKS cluster](workload-identity-deploy-cluster.md#enable-oidc-issuer-and-microsoft-entra-workload-id-on-an-aks-cluster) and select **Update an existing AKS cluster** before continuing.
- For the optional Sandbox restore example, install the [Agent Sandbox cluster extension (preview)](agent-sandbox-cluster-extension.md) and wait for its controller to become Ready before creating Sandbox workloads. You can install the two extensions in either order.

- The `k8s-extension` Azure CLI extension installed. Install or update it with `az extension add --name k8s-extension --upgrade`.
- The `Microsoft.KubernetesConfiguration`, `Microsoft.Storage`, and `Microsoft.ManagedIdentity` resource providers [registered](/cli/azure/provider#az-provider-register) in your subscription.

## Limitations
- Use a region that has both AKS release `1025` (see the [AKS Release Tracker](https://releases.aks.azure.com/AKSRelease)) and Azure Linux node image `202610.30.1` or newer (see the [Azure Linux Node Images Release Tracker](https://releases.aks.azure.com/AzureLinux)).
- Source and destination VM SKUs must match exactly. The examples don't establish support for restore across architectures, regions, or unqualified runtime versions.
- Snapshot and restore are validated with Kata guests configured with up to 32 GiB of memory.
- Restore uses the standard 32 MiB memory overhead of the kata-vm-isolation-v2 RuntimeClass.
- To snapshot an already restored pod, don't specify limits in the pod that's being snapshotted.
- You can capture and restore regular containers and completed one-shot init containers. Incomplete init containers, native sidecars with `restartPolicy: Always`, and ephemeral containers aren't supported.
- Snapshots capture one pod's runtime state. They aren't application-consistent backups of a distributed service or replacements for persistent-volume backups.
- External network sessions, remote leases, and external service state require application-specific validation after restore.
- Container identity must be compatible with the selected snapshot. Keep source and restore resource sizing aligned and `enableServiceLinks: false` on both.
- Azure Blob storage configurations must use the account configured for the broker. Node-local files are staging copies, not durable storage.
- Restore requires explicit Kubernetes authorization in addition to permission to create the workload.
- Restoring through Deployments, ReplicaSets, and Jobs isn't supported in this preview. Create a raw Pod or use the Agent Sandbox restore workflow instead.
- Don't edit internal snapshot provenance, inject runtime-private restore paths, or disable the restore admission guards to make an incompatible workload start.
- When you use the Agent Sandbox and Pod snapshot cluster extensions together, you can suspend and resume the same Sandbox. This preview doesn't support restoring a single snapshot to multiple independent Sandboxes, including those in a snapshot-backed warm pool.
- AKS Automatic isn't supported yet.

## How snapshot and restore work

The extension uses the following Kubernetes resources:

| Resource | Purpose |
| --- | --- |
| **PodSnapshotStorageConfig** | Defines the snapshot storage backend. This resource is cluster-scoped. |
| **PodSnapshotPolicy** | Selects eligible pods and defines capture and retention behavior in a namespace. |
| **PodSnapshotManualTrigger** | Requests a capture of a specific pod under a named policy. |
| **PodSnapshot** | Records the resulting snapshot, its source identity, and readiness. |

For Pod sandboxing and Kata VM isolation v2, the node worker captures the sandbox state and uploads it to Azure Blob storage. The snapshot access broker is a component that the extension runs in the pod-snapshot-system namespace. It authenticates by using workload identity and gives node workers short-lived access scoped to their operations. 

On restore, admission resolves a snapshot, authorizes the caller, validates the workload, and selects a node with the exact source VM SKU. The extension stages the snapshot on that node before allowing the pod to start. If restore authorization or compatibility checks fail, the request is rejected. A staging failure leaves the pod gated rather than silently starting a fresh workload.

> [!WARNING]
> Snapshots contain captured workload state, which can include credentials and other sensitive data in memory. Restrict access to the storage account and snapshot restore permissions. Restoring process memory doesn't guarantee that external connections, remote leases, or distributed application state remain valid.

## Prepare your environment

Use an existing compatible cluster or create one with the optional commands in this section. For general background, see [Pod sandboxing](use-pod-sandboxing.md). This walkthrough requires Kata VM isolation v2, not the earlier `kata-vm-isolation` runtime described in that article. The commands depend on Kata v2 availability in your region; complete the runtime verification steps in the next section before installing the extension. Installing the Pod snapshot cluster extension doesn't enable Pod sandboxing or configure the node runtime.

Run all commands in this article in the same Bash session so exported variables remain available for later commands and manifest substitution.

1. Select your subscription.

    ```azurecli
    az account set --subscription "<subscription-name-or-id>"
    ```

1. Set values for your cluster, its Kata node pool, and the resources this article creates. For a new cluster, choose an unused cluster name and set `NODEPOOL_NAME` to `katapool`. For an existing cluster, use its Kata node pool name. Use a globally unique storage account name containing 3-24 lowercase letters and digits. Replace the image placeholder with your workload's digest-pinned image reference.

    ```bash
    export RESOURCE_GROUP="<resource-group-name>"
    export CLUSTER_NAME="<aks-cluster-name>"
    export LOCATION="<supported-azure-region>"
    export NODEPOOL_NAME="katapool"
    export STORAGE_ACCOUNT="<unique-storage-account-name>"
    export STORAGE_CONTAINER="pod-snapshots"
    export BROKER_IDENTITY="pod-snapshot-broker-demo"
    export WORKLOAD_IMAGE="<your-container-image>@sha256:<image-digest>"
    ```

    Use an image that your Kata nodes can pull, and configure image pull credentials if required. Use the same immutable image reference throughout capture and restore. Your workload doesn't need a specific HTTP endpoint to use Pod snapshot.

    If you already have a compatible cluster, skip the next three steps.

1. For a new cluster, create a resource group in `$LOCATION`. Use a region with AKS release `1025` and Azure Linux node image `202610.30.1` or newer, as described in the limitations. Confirm that `Standard_D4as_v6` is available and that your subscription has sufficient quota in that region.

    ```azurecli
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    ```

1. Create a cluster with Kubernetes 1.35, Azure Linux, an OIDC issuer, and workload identity enabled. Keep the system node pool separate from the Kata pool so the snapshot access broker has eligible nodes.

    ```azurecli
    az aks create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME" \
      --location "$LOCATION" \
      --kubernetes-version 1.35 \
      --os-sku AzureLinux \
      --nodepool-name systempool \
      --node-vm-size Standard_D4as_v6 \
      --node-count 2 \
      --network-plugin azure \
      --network-plugin-mode overlay \
      --enable-managed-identity \
      --enable-oidc-issuer \
      --enable-workload-identity \
      --generate-ssh-keys
    ```

1. Add a User node pool with Pod sandboxing enabled. The two nodes use the same supported v6 VM SKU, `Standard_D4as_v6`. Restore requires the exact source VM SKU. Alternatively, pod sandboxing supports v6 VM SKUs in these families: Dasv6, Dadsv6, Dalsv6, Daldsv6, Easv6, Eadsv6, Falsv6, Fasv6, and Famsv6.

    ```azurecli
    az aks nodepool add \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --name "$NODEPOOL_NAME" \
      --mode User \
      --os-sku AzureLinux \
      --workload-runtime KataVmIsolation \
      --node-vm-size Standard_D4as_v6 \
      --node-count 2
    ```

    Reconcile the cluster configuration so AKS recognizes the new pool's workload runtime.

    ```azurecli
    az aks update \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME"
    ```

    These commands create cluster capacity but don't establish that Kata v2 is configured. Complete the node-image, RuntimeClass, capability-label, and readiness checks that follow before installing the extension.

1. Install or update the `k8s-extension` Azure CLI extension.

    ```azurecli
    az extension add --name k8s-extension --upgrade
    ```

1. Get credentials for your cluster.

    ```azurecli
    az aks get-credentials \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME"
    ```

1. Verify the Pod sandboxing node pool's workload runtime, OS SKU, and VM size.

    ```azurecli
    az aks nodepool show \
      --cluster-name "$CLUSTER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --name "$NODEPOOL_NAME" \
      --query "{workloadRuntime:workloadRuntime,osSKU:not_null(osSku,osSKU),vmSize:vmSize}" \
      --output table
    ```

    The output must show `KataVmIsolation` and `AzureLinux`. Confirm that the VM size meets the Kata VM isolation v2 prerequisites. These properties alone don't distinguish Kata VM isolation v2 from the earlier Kata runtime.

1. Verify the RuntimeClass handler and confirm that every node in the pool supports Kata v2 before waiting for readiness.

    ```bash
    kubectl get runtimeclass kata-vm-isolation-v2 \
      -o jsonpath='{.handler}{"\n"}'
    ```

    Continue only if the handler is `kata-v2`.

    List nodes in your pool that carry the capability label required by the RuntimeClass.

    ```bash
    kubectl get nodes \
      --selector "kubernetes.azure.com/kata-vm-isolation-v2=true,agentpool=$NODEPOOL_NAME"
    ```

    Get the configured pool size and the number of matching nodes.

    ```azurecli
    az aks nodepool show \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --name "$NODEPOOL_NAME" \
      --query count --output tsv
    ```

    ```bash
    kubectl get nodes \
      --selector "kubernetes.azure.com/kata-vm-isolation-v2=true,agentpool=$NODEPOOL_NAME" \
      -o go-template='{{len .items}}{{"\n"}}'
    ```

    Continue only if the matching node count equals the configured pool size and is at least `2` for this walkthrough. If the pool is scaling or upgrading, wait for the operation to finish and repeat the count checks.

    A node pool created before Kata VM isolation v2 was available must be recreated after Kata v2 becomes available in the region. Its existing nodes can be Ready without carrying `kubernetes.azure.com/kata-vm-isolation-v2=true`, leaving Kata v2 pods Pending because they don't match the RuntimeClass's node affinity. Create a replacement pool with a distinct name by using the pool creation and reconciliation commands in the previous steps, then repeat the runtime checks. Don't manually add the capability label to unsupported nodes.

    ```bash
    kubectl wait --for=condition=Ready node \
      --selector "kubernetes.azure.com/kata-vm-isolation-v2=true,agentpool=$NODEPOOL_NAME" \
      --timeout=5m
    ```

    If the counts don't match, no nodes match, or the wait times out, complete the Kata VM isolation v2 setup before installing the Pod snapshot cluster extension.

1. Check the Kata nodes' VM SKUs and node image against the snapshot prerequisites.

    ```bash
    kubectl get nodes -L node.kubernetes.io/instance-type
    ```

    ```azurecli
    az aks nodepool show \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --name "$NODEPOOL_NAME" \
      --query nodeImageVersion -o tsv
    ```

    Don't continue if the nodes, handler, or image don't meet the prerequisites. Don't modify the managed host or guest runtime to bypass a failed check.

## Configure Blob storage and workload identity

Create a dedicated storage account and identity for this example. The broker uses that identity to access the account. Each storage configuration must name the account configured for the broker.

1. Create a storage account with shared-key authentication and public Blob access disabled.

    ```azurecli
    az storage account create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$STORAGE_ACCOUNT" \
      --location "$LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --https-only true \
      --allow-blob-public-access false \
      --allow-shared-key-access false
    ```

1. Create the container through the Azure management plane.

    ```azurecli
    az storage container-rm create \
      --resource-group "$RESOURCE_GROUP" \
      --storage-account "$STORAGE_ACCOUNT" \
      --name "$STORAGE_CONTAINER" \
      --public-access off
    ```

1. Create the broker's user-assigned managed identity.

    ```azurecli
    az identity create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$BROKER_IDENTITY" \
      --location "$LOCATION"
    ```

1. Get its client ID, principal ID, and tenant ID, plus the storage resource ID and cluster OIDC issuer.

    ```bash
    export BROKER_CLIENT_ID="$(az identity show \
      --resource-group "$RESOURCE_GROUP" --name "$BROKER_IDENTITY" \
      --query clientId -o tsv)"
    export BROKER_PRINCIPAL_ID="$(az identity show \
      --resource-group "$RESOURCE_GROUP" --name "$BROKER_IDENTITY" \
      --query principalId -o tsv)"
    export TENANT_ID="$(az account show --query tenantId -o tsv)"
    export STORAGE_ID="$(az storage account show \
      --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" \
      --query id -o tsv)"
    export OIDC_ISSUER="$(az aks show \
      --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
      --query oidcIssuerProfile.issuerUrl -o tsv)"
    ```

    The OIDC issuer can't be empty. If it's missing, configure the issuer by following [Create an OIDC issuer for your cluster](use-oidc-issuer.md) before continuing.

1. Assign the broker identity `Storage Blob Data Contributor` at the storage account scope.

    ```azurecli
    az role assignment create \
      --assignee-object-id "$BROKER_PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "Storage Blob Data Contributor" \
      --scope "$STORAGE_ID"
    ```

1. Federate the identity to the broker ServiceAccount in the extension's release namespace.

    ```azurecli
    az identity federated-credential create \
      --resource-group "$RESOURCE_GROUP" \
      --identity-name "$BROKER_IDENTITY" \
      --name pod-snapshot-broker \
      --issuer "$OIDC_ISSUER" \
      --subject system:serviceaccount:pod-snapshot-system:pod-snapshot-broker \
      --audiences api://AzureADTokenExchange
    ```

    Azure role assignments can take several minutes to propagate. These broker settings are separate from the identity metadata that the extension platform supplies.

## Install the Pod snapshot cluster extension

Use Pod snapshot extension version `0.1.1` or later. The create command doesn't pin a version and uses the service-offered version with automatic upgrades enabled by default.

You can install the Pod snapshot cluster extension and the Agent Sandbox cluster extension in either order. The Pod snapshot manager detects the Sandbox API when it becomes available, including after the manager starts, without requiring a restart. The Agent Sandbox cluster extension isn't required to capture and restore raw Pods.

1. Install the cluster-scoped extension with the broker storage and identity settings. The node selector limits node-worker placement to your Kata node pool; escaped dots preserve the label key when the settings are passed to Helm.

    ```azurecli
    az k8s-extension create \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name pod-snapshot \
      --extension-type Microsoft.PodSnapshot \
      --configuration-settings \
        "broker.storageAccount=$STORAGE_ACCOUNT" \
        "azureBlob.workloadIdentity.clientID=$BROKER_CLIENT_ID" \
        "azureBlob.workloadIdentity.tenantID=$TENANT_ID" \
        "nodeWorker.nodeSelector.kubernetes\\.azure\\.com/agentpool=$NODEPOOL_NAME"
    ```

    This example doesn't grant restore access automatically. Configure namespaced permissions later in this article.

1. Inspect the extension's provisioning state.

    ```azurecli
    az k8s-extension show \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name pod-snapshot \
      --query '{type:extensionType,state:provisioningState,version:currentVersion}'
    ```

    Continue only after `state` is `Succeeded` and `version` is `0.1.1` or later. A successful installation of an older version doesn't meet this requirement.

1. Wait for the manager, broker, and node workers.

    ```bash
    kubectl -n pod-snapshot-system rollout status \
      deployment/pod-snapshot-manager \
      deployment/pod-snapshot-broker \
      daemonset/pod-snapshot-node-worker --timeout=10m
    ```

    ```bash
    kubectl -n pod-snapshot-system get pods -o wide
    ```

    Confirm that a Ready node worker runs on each Kata node. A DaemonSet rollout can succeed with zero workers.

## Configure a storage resource and policy

1. Create `snapshot-policy.yaml` with the following content.

    ```yaml
    apiVersion: podsnapshot.aks.azure.com/v1alpha1
    kind: PodSnapshotStorageConfig
    metadata:
      name: workload-storage
    spec:
      snapshotStorageConfig:
        azureBlob:
          account: ${STORAGE_ACCOUNT}
          container: ${STORAGE_CONTAINER}
          prefix: workload-demo
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: workload-demo
    ---
    apiVersion: podsnapshot.aks.azure.com/v1alpha1
    kind: PodSnapshotPolicy
    metadata:
      name: workload-policy
      namespace: workload-demo
    spec:
      storageConfigName: workload-storage
      selector:
        matchLabels:
          app: workload
      triggerConfig:
        type: manual
        postCheckpoint: resume
    ```

    `postCheckpoint: resume` lets the source workload continue after capture. The policy selects pods labeled `app: workload`.

1. Substitute the storage values and apply the manifest.

    ```bash
    envsubst '${STORAGE_ACCOUNT} ${STORAGE_CONTAINER}' \
      < snapshot-policy.yaml | kubectl apply -f -
    ```

1. Wait for the policy to become Ready.

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready \
      podsnapshotpolicy/workload-policy --timeout=5m
    ```

## Prepare your workload

Choose a workload with an observable application state so you can verify that the restored pod resumes from the snapshot instead of starting from its initial state. For example, check an in-memory session identifier, initialized application data, or progress through a long-running task. Adapt resource requests, limits, commands, arguments, configuration, and health checks to your application, and use compatible settings for capture and restore.

The following manifests are templates for your workload, not a supplied sample application. Without an application-specific readiness probe, pod readiness doesn't establish that initialization is complete. Add an appropriate probe and confirm application readiness before capture.

The manifests keep capture and restore workloads on `$NODEPOOL_NAME`, the pool covered by the node workers you installed earlier.

### Preload your container image on the Kata nodes

Optionally, preload your image before measuring restore performance to reduce image preparation time during the test. The following temporary DaemonSet prepares the nodes by starting one copy of your application on each node. It doesn't cache application data or create a snapshot.

> [!IMPORTANT]
> This step runs your application, not just an image download. Use a test workload that's safe to run in multiple copies and stop afterward.

1. Create `workload-image-preload.yaml`. Include the application configuration and image pull credentials it needs.

    ```yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: workload-image-preload
      namespace: workload-demo
    spec:
      selector:
        matchLabels:
          app: workload-image-preload
      template:
        metadata:
          labels:
            app: workload-image-preload
        spec:
          enableServiceLinks: false
          runtimeClassName: kata-vm-isolation-v2
          nodeSelector:
            kubernetes.azure.com/kata-vm-isolation-v2: "true"
            kubernetes.azure.com/agentpool: ${NODEPOOL_NAME}
          containers:
            - name: workload
              image: ${WORKLOAD_IMAGE}
              resources:
                requests:
                  cpu: 50m
                  memory: 256Mi
                limits:
                  cpu: 250m
                  memory: 256Mi
    ```

1. Apply the DaemonSet and check its readiness.

    ```bash
    envsubst '${WORKLOAD_IMAGE} ${NODEPOOL_NAME}' \
      < workload-image-preload.yaml | kubectl apply -f -
    ```

    ```bash
    kubectl -n workload-demo rollout status daemonset/workload-image-preload --timeout=10m
    ```

    ```bash
    kubectl -n workload-demo get daemonset workload-image-preload \
      -o jsonpath='desired={.status.desiredNumberScheduled}{" "}ready={.status.numberReady}{"\n"}'
    ```

    If you perform this optional step, confirm that the desired and ready counts match the number of eligible Kata nodes in `$NODEPOOL_NAME`.

1. Delete the temporary DaemonSet after all its pods are ready.

    ```bash
    kubectl -n workload-demo delete daemonset workload-image-preload --wait=true
    ```

### Start the source pod

Start the pod whose state you want to capture.

1. Create `workload-pod.yaml`:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: workload
      namespace: workload-demo
      labels:
        app: workload
    spec:
      enableServiceLinks: false
      runtimeClassName: kata-vm-isolation-v2
      nodeSelector:
        kubernetes.azure.com/agentpool: ${NODEPOOL_NAME}
      containers:
        - name: workload
          image: ${WORKLOAD_IMAGE}
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              cpu: 250m
              memory: 256Mi
    ```

1. Apply the manifest and wait for the source pod to become Ready before creating a trigger.

    ```bash
    envsubst '${WORKLOAD_IMAGE} ${NODEPOOL_NAME}' < workload-pod.yaml \
      | kubectl apply -f -
    ```

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready pod/workload --timeout=5m
    ```

1. Wait for application initialization to finish, then record state that distinguishes a resumed process from a fresh start. Use your application's API, logs, or another application-specific check. Record the expected restored state before creating the trigger. Data read only from an external database or persistent volume doesn't prove that process memory was restored.

## Capture pod state

1. Create `snapshot-trigger.yaml`. Every trigger must name the governing policy, and the target pod must match that policy's selector.

    ```yaml
    apiVersion: podsnapshot.aks.azure.com/v1alpha1
    kind: PodSnapshotManualTrigger
    metadata:
      name: workload-snapshot
      namespace: workload-demo
    spec:
      targetPod: workload
      policyName: workload-policy
    ```

1. Apply the trigger and wait for it to report completion.

    ```bash
    kubectl apply -f snapshot-trigger.yaml
    ```

    ```bash
    kubectl -n workload-demo wait --for=condition=Triggered \
      podsnapshotmanualtrigger/workload-snapshot --timeout=10m
    ```

1. Get the name of the `PodSnapshot` resource and wait for it to become Ready. Trigger completion and snapshot readiness are separate checks.

    ```bash
    export SNAPSHOT_NAME="$(kubectl -n workload-demo get \
      podsnapshotmanualtrigger workload-snapshot \
      -o jsonpath='{.status.snapshotCreated.name}')"
    ```

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready \
      "podsnapshot/$SNAPSHOT_NAME" --timeout=10m
    ```

1. Inspect the recorded snapshot identity, source VM SKU, and storage status.

    ```bash
    kubectl -n workload-demo get podsnapshot "$SNAPSHOT_NAME" -o yaml
    ```

    Confirm that the snapshot is Ready and its Azure Blob status identifies the configured account and container.

## Authorize snapshot restore

The restore label requests restore; it doesn't grant permission. The admission actor must have the custom `restore` verb on the selected `PodSnapshot`. For a raw Pod request, that actor is the Kubernetes user creating the pod. For a Sandbox, the actor is the Agent Sandbox controller that creates the pod.

> [!WARNING]
> Don't grant the `restore` verb to built-in Kubernetes controllers, such as `system:serviceaccount:kube-system:replicaset-controller` or `system:serviceaccount:kube-system:job-controller`, to enable restore through Deployments, ReplicaSets, or Jobs. The controller creates the Pod, so restore authorization checks the controller's identity, not the user who created the workload. Granting restore access to a controller delegates that access to users who can make it create Pods in the namespace, even if those users don't have restore permission themselves.

1. As a Kubernetes administrator, create `snapshot-restore-access.yaml`. Replace `<kubernetes-user-name>` with the authenticated Kubernetes username of the user who will create the restore pod.

    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: workload-snapshot-restorer
      namespace: workload-demo
    rules:
      - apiGroups: ["podsnapshot.aks.azure.com"]
        resources: ["podsnapshots"]
        resourceNames: ["${SNAPSHOT_NAME}"]
        verbs: ["restore"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: workload-user-restorer
      namespace: workload-demo
    subjects:
      - kind: User
        name: <kubernetes-user-name>
        apiGroup: rbac.authorization.k8s.io
    roleRef:
      kind: Role
      name: workload-snapshot-restorer
      apiGroup: rbac.authorization.k8s.io
    ```

    This Role grants restore access to one snapshot in one namespace. It doesn't grant permission to create pods or administer other resources.

1. Substitute the snapshot name and apply the permissions.

    ```bash
    envsubst '${SNAPSHOT_NAME}' < snapshot-restore-access.yaml \
      | kubectl apply -f -
    ```

1. As the user who will create the restore pod, verify restore permission.

    ```bash
    kubectl auth can-i restore \
      "podsnapshots.podsnapshot.aks.azure.com/$SNAPSHOT_NAME" \
      --namespace workload-demo
    ```

    The warning `Warning: verb 'restore' is not a known verb` is expected because `restore` is a custom verb. It doesn't indicate an authorization failure. Continue only if the command returns `yes`.

## Start a workload from captured pod state

1. Delete the source pod after the snapshot is Ready. Keep the policy, storage configuration, and snapshot.

    ```bash
    kubectl -n workload-demo delete pod workload --wait=true
    ```

1. Create `workload-restore.yaml`. Keep the image, container name, command, arguments, resource sizing, and `enableServiceLinks` setting aligned with the source workload.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: workload-restore
      namespace: workload-demo
      labels:
        app: workload
        podsnapshot.aks.azure.com/restore: "true"
      annotations:
        podsnapshot.aks.azure.com/restore-from: ${SNAPSHOT_NAME}
    spec:
      enableServiceLinks: false
      runtimeClassName: kata-vm-isolation-v2
      nodeSelector:
        kubernetes.azure.com/agentpool: ${NODEPOOL_NAME}
      containers:
        - name: workload
          image: ${WORKLOAD_IMAGE}
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              cpu: 250m
              memory: 256Mi
    ```

    Copy any application-specific commands, arguments, configuration, health checks, and image pull credentials from your source manifest into the restore manifest. Name the snapshot, not an artifact path. Admission injects runtime-private restore annotations after authorization.

1. Apply the manifest and wait for the restore pod.

    ```bash
    envsubst '${WORKLOAD_IMAGE} ${SNAPSHOT_NAME} ${NODEPOOL_NAME}' \
      < workload-restore.yaml \
      | kubectl apply -f -
    ```

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready \
      pod/workload-restore --timeout=10m
    ```

1. Use the same application-specific check to compare the restored state with the state recorded before capture. Confirm that initialized data, session identity, or task progress resumed from the captured point rather than returning to its initial state. Check external connections and dependencies separately. A Ready pod or a shorter startup time alone doesn't prove that process state was restored.

1. Inspect the restored pod and its events.

    ```bash
    kubectl -n workload-demo get pod workload-restore -o wide
    ```

    ```bash
    kubectl -n workload-demo get events \
      --field-selector involvedObject.name=workload-restore \
      --sort-by='.lastTimestamp'
    ```

    Check for the `AKSPodRestored` event, but verify the application state as well. Pod readiness and the event alone aren't proof that the requested snapshot's process state was consumed. The restored pod might use the source node or another node in `$NODEPOOL_NAME` with the exact same VM SKU.

## Restore an Agent Sandbox workload

This section is optional. The preceding example captures and restores a pod without Agent Sandbox. Continue here if you also want to restore a workload managed by the Agent Sandbox cluster extension.

Before creating the Sandbox, install the Agent Sandbox cluster extension and wait for its controller to become Ready, as described in the prerequisites. You don't need to restart the Pod snapshot cluster extension if you install the Agent Sandbox cluster extension later. 

The Agent Sandbox extension creates a pod from `spec.podTemplate`. Put restore intent on that pod template, not only on the Sandbox metadata.

1. Authorize the Agent Sandbox controller for the example snapshot. Create `sandbox-restore-access.yaml`:

    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: workload-sandbox-restorer
      namespace: workload-demo
    subjects:
      - kind: ServiceAccount
        name: agent-sandbox-controller
        namespace: agent-sandbox-system
    roleRef:
      kind: Role
      name: workload-snapshot-restorer
      apiGroup: rbac.authorization.k8s.io
    ```

    ```bash
    kubectl apply -f sandbox-restore-access.yaml
    ```

    By granting this permission to a controller, you delegate snapshot restore to users who can make that controller create a restore pod. Restrict Sandbox creation and update permissions accordingly.

1. Create `workload-sandbox-restore.yaml`:

    ```yaml
    apiVersion: agents.x-k8s.io/v1beta1
    kind: Sandbox
    metadata:
      name: workload-sandbox-restore
      namespace: workload-demo
    spec:
      podTemplate:
        metadata:
          labels:
            app: workload
            example: workload-sandbox-restore
            podsnapshot.aks.azure.com/restore: "true"
          annotations:
            podsnapshot.aks.azure.com/restore-from: ${SNAPSHOT_NAME}
        spec:
          enableServiceLinks: false
          runtimeClassName: kata-vm-isolation-v2
          nodeSelector:
            kubernetes.azure.com/agentpool: ${NODEPOOL_NAME}
          containers:
            - name: workload
              image: ${WORKLOAD_IMAGE}
              imagePullPolicy: IfNotPresent
              resources:
                requests:
                  cpu: 50m
                  memory: 256Mi
                limits:
                  cpu: 250m
                  memory: 256Mi
    ```

    Copy your source workload's application-specific settings into `spec.podTemplate.spec`, keeping the container identity and resource sizing compatible with the snapshot.

1. Apply the manifest and inspect the Sandbox and its pod.

    ```bash
    envsubst '${WORKLOAD_IMAGE} ${SNAPSHOT_NAME} ${NODEPOOL_NAME}' \
      < workload-sandbox-restore.yaml | kubectl apply -f -
    ```

    ```bash
    kubectl -n workload-demo get sandbox workload-sandbox-restore
    ```

    Wait for the Sandbox to become Ready before selecting its pod. This approach avoids checking for a pod before the controller creates it.

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready \
      sandbox/workload-sandbox-restore --timeout=10m
    ```

    ```bash
    kubectl -n workload-demo wait --for=condition=Ready pod \
      --selector example=workload-sandbox-restore --timeout=10m
    ```

1. Get the name of the pod created by the Sandbox controller.

    ```bash
    export SANDBOX_POD="$(kubectl -n workload-demo get pods \
      --selector example=workload-sandbox-restore \
      -o jsonpath='{.items[0].metadata.name}')"
    ```

    Use your application's API, logs, or another application-specific check against this pod to verify the captured state, independently of the earlier raw Pod restore. Confirm that the process resumed rather than initialized again.

    As an alternative to this explicit restore example, you can restore a Sandbox without naming a snapshot. See [Restore by using implicit snapshot selection](#restore-by-using-implicit-snapshot-selection).

## Restore by using implicit snapshot selection

> [!IMPORTANT]
> Implicit selection is an alternative to explicit snapshot selection, not a required next step. Delete the explicit-restore Sandbox and wait for its Pod to be deleted before trying implicit restore. Deleting the Sandbox doesn't delete the snapshot. A restore doesn't create a new snapshot, so implicit selection can reuse the same snapshot used for explicit restore unless a newer matching Ready snapshot exists.

For a raw Pod on a Pod sandboxing node pool, use the restore manifest in the previous section but omit the `podsnapshot.aks.azure.com/restore-from` annotation and keep the `podsnapshot.aks.azure.com/restore: "true"` label. Use a new Pod name if the earlier restore pod still exists. The extension computes a template hash from the regular containers' names, images, commands, and arguments and selects the most recently Ready matching snapshot in the same namespace. You don't need to supply a hash label manually.

For a Sandbox on a Pod sandboxing node pool, omit the `restore-from` annotation but keep the `restore: "true"` label to request implicit selection. The extension selects the most recently Ready snapshot in the same namespace whose nonempty container identity matches exactly.

Create a new Sandbox named `workload-sandbox-implicit` rather than editing the existing explicit-restore Sandbox. Set `spec.podTemplate.metadata.labels.example` to `workload-sandbox-implicit`. Update the readiness and Pod lookup commands to use the new Sandbox name and the selector `example=workload-sandbox-implicit`.

Don't change restore intent on an existing restore Sandbox. The webhook rejects updates to its Pod's immutable restore fields, which can leave the Sandbox `Ready=False` while its original Pod continues running.

Regular-container matching includes names, images, commands, and arguments. Completed one-shot init-container matching also includes order and restart policy. Resource values aren't part of that identity, so keep them aligned explicitly. Extra containers or a changed image don't qualify as a partial match.

Authorization is checked after snapshot selection. The example Role authorizes only the snapshot named in `SNAPSHOT_NAME`. If a scheduled policy creates a newer matching Ready snapshot, implicit restore selects that newer snapshot. If the caller isn't authorized to restore it, the request is denied; selection doesn't fall back to the older snapshot named in the Role or to a cold start.

If you combine implicit restore with scheduled snapshots and intend to allow namespace-wide restore access, replace `snapshot-restore-access.yaml` with the following Role, which omits `resourceNames`. The existing RoleBindings continue to reference this Role.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workload-snapshot-restorer
  namespace: workload-demo
rules:
  - apiGroups: ["podsnapshot.aks.azure.com"]
    resources: ["podsnapshots"]
    verbs: ["restore"]
```

```bash
kubectl apply -f snapshot-restore-access.yaml
```

> [!WARNING]
> This Role grants its bound users or ServiceAccounts restore access to every current and future `PodSnapshot` in `workload-demo`, including snapshots from other workloads or policies. It doesn't grant permission to create Pods, read snapshots, or access snapshots in other namespaces. If you created the Agent Sandbox controller RoleBinding, the broader access also applies to that controller and is delegated to users who can make it create restore Pods. Use this Role only when all bound identities are trusted to restore any snapshot in the namespace; otherwise, keep `resourceNames` and explicitly authorize each selected snapshot.

To start a workload without restoring a snapshot, create a new Pod or Sandbox without the restore label and `restore-from` annotation. For a Sandbox, use a distinct name and pod-template `example` label, such as `workload-sandbox-cold-start`, and update the readiness and Pod lookup commands to use the new name and label selector. Alternatively, delete the previous Sandbox, wait for its Pod to be deleted, and recreate the Sandbox without restore intent. Removing restore intent from an existing restore Sandbox doesn't cold-start its running Pod.

## Schedule snapshots and configure retention

This section is optional and doesn't require Agent Sandbox. It reuses the storage configuration and namespace that you created earlier. The restore walkthrough deletes the original source pod. Recreate it as a cold-start source for scheduled captures rather than selecting the restored examples, which still specify container limits and don't meet the re-snapshot limitation.

A cron policy captures one representative Ready pod matching its selector per run, not every matching pod. Use `concurrencyPolicy: Forbid` to prevent overlapping captures and `postCheckpoint: resume` to keep the source running. A cron policy with `postCheckpoint: stop` doesn't become Ready.

In the original `workload-pod.yaml`, add a dedicated label to `metadata.labels`:

```yaml
metadata:
  name: workload
  namespace: workload-demo
  labels:
    app: workload
    snapshot-schedule: workload-nightly
```

Keep the original pod specification, including your application-specific settings. Don't add the restore label or `restore-from` annotation. Don't add the `snapshot-schedule` label to restored pods or Sandbox pod templates.

Reapply the source manifest and wait for the cold-start pod to become Ready:

```bash
envsubst '${WORKLOAD_IMAGE} ${NODEPOOL_NAME}' < workload-pod.yaml \
  | kubectl apply -f -
```

```bash
kubectl -n workload-demo wait --for=condition=Ready pod/workload --timeout=5m
```

Confirm that application initialization finishes by using the application-specific check from the source workload steps before enabling scheduled captures.

Create `workload-cron-policy.yaml`:

```yaml
apiVersion: podsnapshot.aks.azure.com/v1alpha1
kind: PodSnapshotPolicy
metadata:
  name: workload-nightly
  namespace: workload-demo
spec:
  storageConfigName: workload-storage
  selector:
    matchLabels:
      app: workload
      snapshot-schedule: workload-nightly
  triggerConfig:
    type: cron
    schedule: "0 3 * * *"
    timeZone: America/Los_Angeles
    startingDeadlineSeconds: 600
    concurrencyPolicy: Forbid
    postCheckpoint: resume
  retentionConfig:
    maxSnapshots: 7
    lastAccessTimeout: 168h
```

| Field | Example value | Meaning |
| --- | --- | --- |
| `schedule` | `"0 3 * * *"` | Captures once per day at 03:00 in the specified time zone. |
| `timeZone` | `America/Los_Angeles` | Time zone for the schedule. |
| `startingDeadlineSeconds` | `600` | Limits how late a missed run can start. |
| `concurrencyPolicy` | `Forbid` | Prevents overlapping captures. |
| `postCheckpoint` | `resume` | Keeps the source pod running. A cron policy with stop doesn't become Ready. |
| `retentionConfig.maxSnapshots` | `7` | Caps usable Ready snapshots per policy, not per source pod. |
| `retentionConfig.lastAccessTimeout` | `168h` | Enables age-based cleanup based on snapshot access. |

Protected snapshots can delay retention cleanup while a restore is in flight.

> [!NOTE]
> Snapshot size generally increases with the pod's guest memory, not just the application's own state. Pods with larger memory limits can produce snapshots that consume several GB in Azure Blob storage. Measure representative snapshot sizes and choose `maxSnapshots` and storage account capacity and cost budgets accordingly. The cap is shared across all pods selected by a policy; plan for the combined size of retained snapshots and allow extra capacity while protected snapshots delay cleanup.

```bash
kubectl apply -f workload-cron-policy.yaml
```

```bash
kubectl -n workload-demo get podsnapshotpolicy workload-nightly -o yaml
```

The schedule requires a Ready cold-start source pod labeled `app: workload` and `snapshot-schedule: workload-nightly`. The dedicated label excludes the restored examples. To stop future scheduled captures, delete the cron policy. Snapshots that the policy creates aren't owned by it, so deleting the policy preserves them and stops its retention rules from applying to them. Delete those snapshots explicitly when you no longer need them.

## Clean up resources

Stop scheduled captures, delete workload consumers, and then delete snapshots before uninstalling the extension. Snapshot finalizers need the running controllers and storage access to finish cleanup. If a command fails or times out, stop and resolve the failure before continuing. Don't remove finalizers to force cleanup.

These commands delete all pods and snapshots in the dedicated `workload-demo` namespace. Don't use them unchanged in a namespace that contains workloads or snapshots you need to keep. Keep Agent Sandbox running until its Sandbox resources and pods are deleted.

Set the resource names again if you return in a new shell. Get credentials to select the cluster you intend to clean up.

```bash
export RESOURCE_GROUP="<resource-group-name>"
export CLUSTER_NAME="<aks-cluster-name>"
export STORAGE_ACCOUNT="<unique-storage-account-name>"
export BROKER_IDENTITY="pod-snapshot-broker-demo"
```

```azurecli
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

1. If you created the cron policy, delete it first to stop new scheduled captures and wait for its active run to finish. Allow any in-flight manual capture to finish before deleting its trigger or source pod.

    ```bash
    kubectl -n workload-demo delete podsnapshotpolicy workload-nightly \
      --ignore-not-found --wait=true --timeout=10m
    ```

1. Delete the optional image-preload DaemonSet if it still exists, and wait for its pods to be removed.

    ```bash
    kubectl -n workload-demo delete daemonset workload-image-preload \
      --ignore-not-found --cascade=foreground --wait=true --timeout=5m
    ```

1. If you created any Sandbox examples, delete them while Agent Sandbox is still running.

    ```bash
    kubectl -n workload-demo delete sandbox \
      workload-sandbox-restore \
      workload-sandbox-implicit \
      workload-sandbox-cold-start \
      --ignore-not-found --cascade=foreground --wait=true --timeout=10m
    ```

1. Delete the remaining example pods, including the recreated source for scheduled captures and any raw Pods created for implicit restore or cold start. In this dedicated namespace, no workload controller should remain to recreate them.

    ```bash
    kubectl -n workload-demo delete pods --all --wait=true --timeout=10m
    ```

    Confirm that no pods remain before deleting snapshots.

    ```bash
    kubectl -n workload-demo get pods
    ```

1. Delete the manual trigger after its capture finishes.

    ```bash
    kubectl -n workload-demo delete podsnapshotmanualtrigger workload-snapshot \
      --ignore-not-found --cascade=foreground --wait=true --timeout=10m
    ```

1. Delete all snapshots in the dedicated example namespace, including snapshots created by the manual trigger and cron policy. Wait for their finalizers to finish storage cleanup. Don't delete the namespace or storage resources until all snapshots are deleted.

    ```bash
    kubectl -n workload-demo delete podsnapshots --all --wait=true --timeout=10m
    ```

1. Verify that the dedicated example namespace contains no remaining snapshots before deleting it. Namespace deletion also removes the example policy and namespaced restore Role and RoleBindings.

    ```bash
    kubectl -n workload-demo get podsnapshots
    ```

    ```bash
    kubectl delete namespace workload-demo \
      --ignore-not-found --wait=true --timeout=10m
    ```

    Delete the cluster-scoped storage configuration only if no policies in other namespaces reference it. Otherwise, keep the configuration and its storage resources.

    ```bash
    kubectl delete podsnapshotstorageconfig workload-storage \
      --ignore-not-found --wait=true --timeout=5m
    ```

1. If no other workloads need the extension, uninstall it.

    ```azurecli
    az k8s-extension delete \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name pod-snapshot \
      --yes
    ```

1. List the remaining extensions to verify removal.

    ```azurecli
    az k8s-extension list \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --query '[].{name:name,state:provisioningState}' -o table
    ```

1. Only if the storage account and identity were created solely for this example and are no longer used, remove their role assignment and Azure resources.

    ```bash
    export BROKER_PRINCIPAL_ID="$(az identity show \
      --resource-group "$RESOURCE_GROUP" --name "$BROKER_IDENTITY" \
      --query principalId -o tsv)"
    export STORAGE_ID="$(az storage account show \
      --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" \
      --query id -o tsv)"
    ```

    ```azurecli
    az role assignment delete \
      --assignee "$BROKER_PRINCIPAL_ID" \
      --role "Storage Blob Data Contributor" \
      --scope "$STORAGE_ID"
    ```

    ```azurecli
    az identity delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$BROKER_IDENTITY"
    ```

    ```azurecli
    az storage account delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$STORAGE_ACCOUNT" \
      --yes
    ```

    Deleting the storage account permanently removes its contents. Don't delete a shared account or your existing AKS cluster as part of this example's cleanup.

1. Optionally, delete the AKS cluster only if you created it solely for these walkthroughs and no longer need any workloads or resources on it. If you also installed Agent Sandbox, finish its [cleanup procedure](agent-sandbox-cluster-extension.md#clean-up-resources) before deleting the cluster.

    ```azurecli
    az aks delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME" \
      --yes
    ```

    If you keep the cluster, its nodes continue to incur charges. This command doesn't delete the resource group or separate storage and identity resources. Don't delete a shared cluster or resource group.

## Next steps

- [Run isolated AI agent workloads with the Agent Sandbox cluster extension](agent-sandbox-cluster-extension.md).
- [Understand Pod sandboxing considerations](considerations-pod-sandboxing.md).
- [Deploy and manage cluster extensions for AKS](cluster-extensions.md).