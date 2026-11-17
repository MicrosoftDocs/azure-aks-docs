---
title: Agent Sandbox cluster extension (preview)
description: Learn how to run isolated AI agent workloads on Azure Kubernetes Service (AKS) with the Agent Sandbox cluster extension.
author: wangyira
ms.author: wangamanda
ms.date: 11/04/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Run isolated AI agent workloads with the Agent Sandbox cluster extension (preview)

The Agent Sandbox cluster extension uses the open-source Kubernetes [Agent Sandbox project](https://github.com/kubernetes-sigs/agent-sandbox) to manage AI agent execution environments. The project provides a declarative API for managing individual, stateful workloads, such as an AI coding agent's code-execution environment or an interactive notebook session.

For example, a coding assistant can use a Sandbox to run generated Python code, execute unit tests, and collect results without running that code inside the assistant application's own process. You describe the execution environment's container image, runtime, and resource requirements in a Kubernetes `Sandbox` resource. The extension's controller creates and manages the pod for that environment; the selected runtime provides workload isolation.

You can use the Agent Sandbox cluster extension on its own with Pod sandboxing, or together with the [Pod snapshot cluster extension (preview)](pod-snapshot-cluster-extension.md) to capture and restore workload state. You control AKS node capacity and manage the node pools and cluster.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites
- Use a managed-identity AKS cluster running Kubernetes version 1.35 or later with Pod sandboxing enabled and Kata VM isolation v2 configured. Cluster extensions don't support service-principal-based clusters; [switch to managed identity](system-assigned-managed-identity.md#update-an-existing-cluster-to-use-a-system-assigned-managed-identity) before continuing. A cluster without Pod sandboxing isn't sufficient. For general background, see [Pod sandboxing](use-pod-sandboxing.md) and [Pod sandboxing considerations](considerations-pod-sandboxing.md). Verify Kata v2 support by following the checks in this article before installing the extension.
- To capture and restore workload state, also meet the requirements for the optional [Pod snapshot cluster extension (preview)](pod-snapshot-cluster-extension.md).
- Azure CLI version 2.85.0 or later for cluster extension commands. Run `az --version` to find your version and `az upgrade` to upgrade. Also meet the CLI requirements in the linked Kata v2 setup instructions. For more information, see [Install Azure CLI][install-azure-cli].
- Pod sandboxing support only v6 VM SKUs in these families: Dasv6, Dadsv6, Dalsv6, Daldsv6, Easv6, Eadsv6, Falsv6, Fasv6, and Famsv6.
- The `k8s-extension` Azure CLI extension installed. Install or update it with `az extension add --name k8s-extension --upgrade`.
- The `Microsoft.KubernetesConfiguration` resource provider [registered](/cli/azure/provider#az-provider-register) in your subscription.

## Limitations
- Regional availability depends on the AKS release that added Kata VM isolation v2 support. To check whether your region has it, find AKS release `1025` in the [AKS Release Tracker](https://releases.aks.azure.com/AKSRelease).
- When you use the Agent Sandbox and Pod snapshot cluster extensions together, you can suspend and resume the same Sandbox. This preview doesn't support restoring a single snapshot to multiple independent Sandboxes, including those in a snapshot-backed warm pool.
- AKS Automatic isn't yet supported.

## Prepare your AKS cluster

Use an existing compatible cluster or create one by using the optional commands in this section. For general background, see [Pod sandboxing](use-pod-sandboxing.md). This walkthrough requires Kata VM isolation v2, not the earlier `kata-vm-isolation` runtime described in that article. The commands depend on Kata v2 availability in your region. Complete the runtime verification steps in the following section before installing the extension. Installing the Agent Sandbox cluster extension doesn't enable Pod sandboxing or configure the node runtime.

1. Select your subscription.

    ```azurecli
    az account set --subscription "<subscription-name-or-id>"
    ```

1. Set the names of your cluster, its resource group, and its Pod sandboxing node pool. For a new cluster, choose an unused cluster name and use `katapool` for the node pool name.

    ```bash
    export RESOURCE_GROUP="<resource-group-name>"
    export CLUSTER_NAME="<aks-cluster-name>"
    export NODEPOOL_NAME="katapool"
    ```

    For an existing cluster, set `NODEPOOL_NAME` to its Pod sandboxing node pool name and skip the next three steps.

1. For a new cluster, select a region and create a resource group. Use a region with AKS release `1025` and Azure Linux node image `202610.30.1` or newer. Check the [AKS Release Tracker](https://releases.aks.azure.com/AKSRelease) and [Azure Linux Node Images Release Tracker](https://releases.aks.azure.com/AzureLinux). Confirm that `Standard_D4as_v6` is available and that your subscription has sufficient quota in that region.

    ```bash
    export LOCATION="<supported-azure-region>"
    ```

    ```azurecli
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    ```

1. Create a cluster with a regular system node pool, Kubernetes 1.35, Azure Linux, an OIDC issuer, and workload identity enabled. The separate system pool provides capacity for components such as the Pod snapshot access broker.

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

1. Add a User node pool with Pod sandboxing enabled. This example uses two nodes with the same `Standard_D4as_v6` SKU, which meets the Pod snapshot walkthrough's node-count and VM-family requirements. Restore requires the exact source VM SKU. Alternatively, pod sandboxing supports v6 VM SKUs in these families: Dasv6, Dadsv6, Dalsv6, Daldsv6, Easv6, Eadsv6, Falsv6, Fasv6, and Famsv6.

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

    Verify the managed node image and Kata v2 runtime in the following steps before installing either extension.

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

1. Verify the Pod sandboxing node pool's workload runtime, OS SKU, VM size, and node image.

    ```azurecli
    az aks nodepool show \
      --cluster-name "$CLUSTER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --name "$NODEPOOL_NAME" \
      --query "{workloadRuntime:workloadRuntime,osSKU:not_null(osSku,osSKU),vmSize:vmSize,nodeImageVersion:nodeImageVersion}" \
      --output table
    ```

    The output must show `KataVmIsolation` and `AzureLinux`. Confirm that the VM size meets the Kata VM isolation v2 prerequisites. For Pod snapshot, require a supported v6 SKU and Azure Linux node image `202610.30.1` or newer. These properties alone don't distinguish Kata VM isolation v2 from the earlier Kata runtime.

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

    Continue only if the matching node count equals the configured pool size and is at least `1`, or at least `2` for the Pod snapshot walkthrough. If the pool is scaling or upgrading, wait for the operation to finish and repeat the count checks.

    Nodes created before Kata VM isolation v2 was available can be Ready without carrying the required capability label. After Kata v2 becomes available in the region, create a replacement pool with a distinct name by using the pool creation and reconciliation commands in the preceding steps, then repeat the runtime checks. Don't manually add the capability label to unsupported nodes.

    ```bash
    kubectl wait --for=condition=Ready node \
      --selector "kubernetes.azure.com/kata-vm-isolation-v2=true,agentpool=$NODEPOOL_NAME" \
      --timeout=5m
    ```

    If the counts don't match, no nodes match, or the wait times out, complete the Kata v2 setup before installing the Agent Sandbox cluster extension.

## Install the Agent Sandbox cluster extension

The commands in this section use the `RESOURCE_GROUP` and `CLUSTER_NAME` environment variables. If you started a new shell session, set them again as described in [Prepare your AKS cluster](#prepare-your-aks-cluster).

Use Agent Sandbox extension version `1.0.7` or later. The create command doesn't pin a version and uses the service-offered version with automatic upgrades enabled by default.

The extension adds the following resource types:

| Resource | API group and version | Purpose |
| --- | --- | --- |
| `Sandbox` | `agents.x-k8s.io/v1beta1` | A single, stateful, isolated environment backed by one pod. |
| `SandboxTemplate` | `extensions.agents.x-k8s.io/v1beta1` | Defines the environment for warm-pool Sandboxes, including image, runtime, and resources. |
| `SandboxWarmPool` | `extensions.agents.x-k8s.io/v1beta1` | Maintains a reserve of ready Sandboxes created from a template. |
| `SandboxClaim` | `extensions.agents.x-k8s.io/v1beta1` | Requests a Sandbox from a warm pool for one agent session. |

1. Create the Agent Sandbox cluster extension on the AKS cluster you configured with Pod sandboxing and the Kata v2 runtime.

    ```azurecli
    az k8s-extension create \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name agent-sandbox \
      --extension-type Microsoft.AgentSandbox 
    ``` 

1. Check the extension's provisioning state.

    ```azurecli
    az k8s-extension show \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name agent-sandbox \
      --query '{type:extensionType,state:provisioningState,version:currentVersion}'
    ```

    Continue only after `state` is `Succeeded` and `version` is `1.0.7` or later. A successful installation of an older version doesn't meet this requirement.

1. Wait for the controller and check that the Sandbox API is installed.

    ```bash
    kubectl -n agent-sandbox-system rollout status \
      deployment/agent-sandbox-controller --timeout=5m
    ```

    ```bash
    kubectl get crd sandboxes.agents.x-k8s.io
    ```

    ```bash
    kubectl api-resources --api-group=agents.x-k8s.io
    ```

    The following example uses `agents.x-k8s.io/v1beta1`. Confirm that the `sandboxes` resource lists that version in the `APIVERSION` column.

## Run an isolated AI agent workload

1. Create a namespace for the example.

    ```bash
    kubectl create namespace agent-demo
    ```

1. Create a file named `agent-sandbox.yaml` with the following manifest. Replace `<agent-container-image>` with your workload image. Adjust resource requests and limits for your workload.

    ```yaml
    apiVersion: agents.x-k8s.io/v1beta1
    kind: Sandbox
    metadata:
      name: agent-demo
      namespace: agent-demo
    spec:
      podTemplate:
        metadata:
          labels:
            app: agent-demo
        spec:
          enableServiceLinks: false
          runtimeClassName: kata-vm-isolation-v2
          containers:
            - name: agent
              image: <agent-container-image>
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
    ```

1. Apply the manifest.

    ```bash
    kubectl apply -f agent-sandbox.yaml
    ```

1. Wait for the Sandbox to become Ready. This step waits for the controller to create and ready its backing pod before inspecting pods by label.

    ```bash
    kubectl -n agent-demo wait --for=condition=Ready \
      sandbox/agent-demo --timeout=5m
    ```

    ```bash
    kubectl -n agent-demo wait --for=condition=Ready pod \
      --selector app=agent-demo --timeout=5m
    ```

    ```bash
    kubectl -n agent-demo get pods --selector app=agent-demo -o wide
    ```

    ```bash
    kubectl -n agent-demo get pods -l app=agent-demo \
      -o custom-columns=NAME:.metadata.name,RUNTIME:.spec.runtimeClassName,NODE:.spec.nodeName
    ```

    Check that `RUNTIME` is `kata-vm-isolation-v2` and `NODE` shows the assigned node.

    Pod readiness alone doesn't prove the workload completed initialization. Check your application's health endpoint or logs as appropriate.

## Configure a warm pool

This section is optional. Your standalone Sandbox is ready to use after you complete the preceding verification steps. Configure a warm pool if you need environments available before new agent sessions start.

A warm pool keeps Sandboxes running before an agent requests them, reducing the need to wait for a new environment to start. A `SandboxTemplate` defines the environment, a `SandboxWarmPool` maintains the available reserve, and a `SandboxClaim` requests a Sandbox from that pool. These resources must be in the same namespace.

This example uses the `agent-demo` namespace that you created in [Run an isolated AI agent workload](#run-an-isolated-ai-agent-workload) and maintains two available Sandboxes. Warm Sandboxes consume compute resources even when no agent is using them. Plan capacity for the reserve, claimed Sandboxes, and any standalone Sandboxes you created earlier. A warm pool doesn't require the Pod snapshot cluster extension.


### Check warm-pool API availability

1. Confirm that the extension installed all three resource definitions.

    ```bash
    kubectl get crd \
      sandboxtemplates.extensions.agents.x-k8s.io \
      sandboxwarmpools.extensions.agents.x-k8s.io \
      sandboxclaims.extensions.agents.x-k8s.io
    ```

1. Verify the API version and claim field used by this example.

    ```bash
    kubectl api-resources --api-group=extensions.agents.x-k8s.io
    ```

    ```bash
    kubectl explain sandboxclaims.spec.warmPoolRef \
      --api-version=extensions.agents.x-k8s.io/v1beta1
    ```

    Continue only if all three resources serve `extensions.agents.x-k8s.io/v1beta1` and the claim supports `warmPoolRef`. If a resource or field is missing, check the supported extension version before continuing. Don't install upstream controllers over the managed extension.

### Create a template and warm pool

1. Create `agent-warm-pool.yaml` from the following template. Replace `<agent-container-image>` with your long-running agent service image and adjust resource requests and limits for your workload.

    > [!IMPORTANT]
    > Before applying this template, add a container `readinessProbe` that checks whether your application finishes initialization and can accept work. The probe is application-specific and isn't included in this template. Without it, the pool can report an environment as Ready before the application is usable.

    ```yaml
    apiVersion: extensions.agents.x-k8s.io/v1beta1
    kind: SandboxTemplate
    metadata:
      name: agent-template
      namespace: agent-demo
    spec:
      podTemplate:
        metadata:
          labels:
            app: agent-warm-pool
        spec:
          enableServiceLinks: false
          runtimeClassName: kata-vm-isolation-v2
          containers:
            - name: agent
              image: <agent-container-image>
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
    ---
    apiVersion: extensions.agents.x-k8s.io/v1beta1
    kind: SandboxWarmPool
    metadata:
      name: agent-warm-pool
      namespace: agent-demo
    spec:
      replicas: 2
      sandboxTemplateRef:
        name: agent-template
    ```

1. Apply the template and pool.

    ```bash
    kubectl apply -f agent-warm-pool.yaml
    ```

1. Wait until two Sandboxes are Ready, then inspect the pool and its pods.

    ```bash
    kubectl -n agent-demo wait \
      --for=jsonpath='{.status.readyReplicas}'=2 \
      sandboxwarmpool/agent-warm-pool --timeout=10m
    ```

    ```bash
    kubectl -n agent-demo get sandboxwarmpool agent-warm-pool
    ```

    ```bash
    kubectl -n agent-demo get pods \
      --selector app=agent-warm-pool -o wide
    ```

    Confirm that the pool reports two ready sandboxes. The pod output shows their assigned nodes and current status. It doesn't verify the nodes' runtime configuration.

### Claim a Sandbox

Create a separate claim for each agent session. A claim takes ownership of an available Sandbox, and the pool creates a replacement to restore its reserve. The pool's replica count doesn't limit the total number of claimed Sandboxes.

1. Create `agent-sandbox-claim.yaml`.

    ```yaml
    apiVersion: extensions.agents.x-k8s.io/v1beta1
    kind: SandboxClaim
    metadata:
      name: agent-session
      namespace: agent-demo
    spec:
      warmPoolRef:
        name: agent-warm-pool
    ```

1. Apply the claim and wait for it to become Ready.

    ```bash
    kubectl apply -f agent-sandbox-claim.yaml
    ```

    ```bash
    kubectl -n agent-demo wait --for=condition=Ready \
      sandboxclaim/agent-session --timeout=10m
    ```

1. Get the assigned Sandbox name and inspect its status.

    ```bash
    export CLAIMED_SANDBOX="$(kubectl -n agent-demo get \
      sandboxclaim agent-session -o jsonpath='{.status.sandbox.name}')"
    ```

    ```bash
    kubectl -n agent-demo get sandbox "$CLAIMED_SANDBOX" -o yaml
    ```

    Use your application's health endpoint or logs to verify that the assigned environment is usable. To check that the pool replenishes its reserve, repeat the pool readiness check after the claim completes.

1. When the session ends, delete its claim and the owned Sandbox resources.

    ```bash
    kubectl -n agent-demo delete sandboxclaim agent-session \
      --cascade=foreground --wait=true --timeout=5m
    ```

    Deleting the claim doesn't return the used Sandbox to the pool. The pool maintains its reserve with separate Sandboxes. Save any application data you need before deleting the claim.

### Change warm-pool capacity

To maintain three available Sandboxes instead of two, scale the pool:

```bash
kubectl -n agent-demo scale sandboxwarmpool agent-warm-pool --replicas=3
```

```bash
kubectl -n agent-demo wait \
  --for=jsonpath='{.status.readyReplicas}'=3 \
  sandboxwarmpool/agent-warm-pool --timeout=10m
```

Update `spec.replicas` in `agent-warm-pool.yaml` too, so reapplying the file doesn't reset the capacity. Scaling the pool changes the unclaimed reserve, not Sandboxes already assigned to claims. Pool pods remain running and consume resources until you scale down or delete the pool.

## Restore a Sandbox from a pod snapshot

This section is optional. Use snapshot restore to resume captured workload state instead of starting a new environment. It doesn't require a warm pool.

You can install the [Pod snapshot cluster extension](pod-snapshot-cluster-extension.md) and Agent Sandbox in either order. The Pod snapshot manager detects the Sandbox API when it becomes available, including after the manager starts, without requiring a restart.

The Pod snapshot article shows how to create a Ready snapshot, authorize the Agent Sandbox controller, and request an explicit or implicit restore. Creating a new Sandbox without restore intent starts a new workload normally.

When switching between explicit restore, implicit restore, and cold start, create a new Sandbox with a distinct name and pod-template label. Update the readiness and Pod lookup commands to use the new name and label selector. Alternatively, delete the previous Sandbox, wait for its Pod to be deleted, and recreate it with the desired restore intent. Don't change restore intent on an existing restore Sandbox: the webhook rejects updates to its Pod's immutable restore fields, which can leave the Sandbox `Ready=False` while its original Pod continues running.

For an explicit restore, add the following fields under `spec.podTemplate.metadata` in a new Sandbox manifest:

```yaml
labels:
  podsnapshot.aks.azure.com/restore: "true"
annotations:
  podsnapshot.aks.azure.com/restore-from: <snapshot-name>
```

The snapshot must be in the same namespace as the `Sandbox` resource. Keep the source and restore container identities and resource sizing compatible. Don't set runtime-private restore annotations or snapshot paths yourself.

## Clean up resources

Keep the extension controllers running until you delete their workloads and dependent resources. If a command fails or times out, stop and resolve the failure before continuing. Don't remove finalizers to force cleanup.

The commands use the dedicated `agent-demo` namespace. Don't delete this namespace if it contains resources you need to keep. If you also used Pod snapshot, stop scheduled captures before removing workloads, and keep both extensions running until snapshot cleanup finishes.

1. Set the cluster values again if needed, and get credentials to select the cluster you want to clean up.

    ```bash
    export RESOURCE_GROUP="<resource-group-name>"
    export CLUSTER_NAME="<aks-cluster-name>"
    ```

    ```azurecli
    az aks get-credentials \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME"
    ```

1. If you configured the warm pool example, delete the pool first to stop replenishment, then delete its example claim and template. Delete any additional claims you created for other sessions. Foreground deletion waits for owned resources to be removed.

    ```bash
    kubectl -n agent-demo delete sandboxwarmpool agent-warm-pool \
      --ignore-not-found --cascade=foreground --wait=true --timeout=5m

    kubectl -n agent-demo delete sandboxclaim agent-session \
      --ignore-not-found --cascade=foreground --wait=true --timeout=5m

    kubectl -n agent-demo delete sandboxtemplate agent-template \
      --ignore-not-found --wait=true --timeout=5m
    ```

1. Delete the example Sandbox and wait for its pod to be removed. Delete any additional implicit-restore or cold-start Sandboxes you created in this namespace.

    ```bash
    kubectl -n agent-demo delete sandbox agent-demo \
      --ignore-not-found --cascade=foreground --wait=true --timeout=5m
    ```

1. Confirm that no example pods remain. If you captured snapshots, complete the [Pod snapshot cleanup](pod-snapshot-cluster-extension.md#clean-up-resources) before deleting the namespace or uninstalling either extension. Include any snapshots, triggers, and policies you created in `agent-demo`, not just the `workload-demo` namespace used by that article.

    ```bash
    kubectl -n agent-demo get pods
    ```

    Continue only when the example pods and any associated snapshots are deleted. Delete the dedicated example namespace if it contains no resources you need to keep.

    ```bash
    kubectl delete namespace agent-demo \
      --ignore-not-found --wait=true --timeout=10m
    ```

1. If no Sandboxes, warm pools, or claims in any namespace depend on the extension, delete the `agent-sandbox` cluster extension instance. Finish removing snapshot-backed Sandboxes while both controllers are still running.

    ```azurecli
    az k8s-extension delete \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --name agent-sandbox \
      --yes
    ```

1. List the remaining extensions to verify that `agent-sandbox` is removed.

    ```azurecli
    az k8s-extension list \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --cluster-type managedClusters \
      --query '[].{name:name,state:provisioningState}' -o table
    ```

1. Optionally, delete the AKS cluster only if you created it solely for these walkthroughs and no longer need any workloads or resources on it. If you used both extensions, finish both cleanup procedures before deleting the cluster.

    ```azurecli
    az aks delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME" \
      --yes
    ```

    If you keep the cluster, its nodes continue to incur charges. This command doesn't delete the resource group or the separate snapshot storage account and broker identity. Don't delete a shared cluster or resource group.

## Next steps

- [Capture and restore pod state with the Pod snapshot cluster extension](pod-snapshot-cluster-extension.md).
- [Understand Pod sandboxing considerations](considerations-pod-sandboxing.md).
- [Deploy and manage cluster extensions for AKS](cluster-extensions.md).

<!-- INTERNAL LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli