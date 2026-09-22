---
title: Configure networking and create a flex node pool in AKS (preview)
description: Learn how to install Unbounded-Net, connect AKS-managed and flex node network locations, and create a flex node pool.
ms.topic: how-to
ms.date: 09/21/2026
author: leslielin-5
ms.author: leslielin
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform engineer, I want to configure networking and create a flex node pool before I prepare and attach a flex node host."
---

# Configure networking and create a flex node pool in AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Before you attach a flex node host to your Azure Kubernetes Service (AKS) cluster, install Unbounded-Net, connect the AKS-managed and flex node network locations, and create a flex node pool. Your infrastructure network provides Layer 3 connectivity between the node networks. Unbounded-Net provides pod networking between the two network locations, which Unbounded-Net calls Sites.

> [!NOTE]
> If Layer 3 connectivity isn't available, use the topology-specific [public AKS cluster with an Unbounded-Net WireGuard gateway lab](https://aka.ms/aks-flex-node/wireguard-lab). That topology isn't the primary workflow. A private AKS cluster with a WireGuard gateway isn't covered by this documentation.

The same Unbounded-Net configuration applies to the public and private AKS API access paths prepared in the preceding article.

Run the commands in this article in a Linux-compatible Bash environment that has the required tools and network access. This article calls that environment your **Bash environment**. The separate machine that joins the cluster is the **flex node host**.

For a private cluster, your Bash environment must resolve and reach the private API endpoint.

For more information about the two networking layers and customer responsibilities, see [Networking concepts for flex nodes](./flex-nodes-networking-concepts.md) and [Support policy for flex nodes](./flex-nodes-support-policy.md).

In this article, you:

- Install and verify the Unbounded-Net command-line interface (CLI).
- Install Unbounded-Net and connect the two network locations.
- Verify the networking components and AKS-managed nodes.
- Apply the temporary Kubernetes permissions required by the AKS flex daemon.
- Create and record a flex node pool.

## Before you begin

- Complete [Plan flex nodes for AKS](./plan-flex-nodes-deployment.md), including the address plan and environment file.
- Complete [Prepare an AKS cluster for flex nodes](./prepare-aks-cluster-for-flex-nodes.md).
- Use the shared environment file and dedicated kubeconfig created in the preceding articles.
- Use the `aks-preview` Azure CLI extension installed in the preceding article.
- Use a subscription that's approved for the flex nodes preview.
- Use an Azure account that can update the AKS cluster and create an agent pool.
- Ensure that the Kubernetes identity in the dedicated kubeconfig can install the cluster-scoped resources and workloads required by Unbounded-Net.
- Install Azure CLI, `kubectl`, `curl`, and `tar` in your Bash environment.
- Allow outbound HTTPS access to `github.com` from your Bash environment to download the Unbounded-Net CLI.
- Ensure that the Layer 3 path provides bidirectional reachability between the AKS-managed node network and the flex node host network. Unbounded-Net provides pod routing across this underlay.
- Ensure that you can use `sudo` to install the Unbounded-Net CLI in `/usr/local/bin`.

## Load the deployment environment

Start a new Bash session, identify the environment file from the planning article, and load it. Replace `<deployment-name>` with your deployment label.

```bash
export FLEXNODE_DEPLOYMENT="<deployment-name>"
export FLEXNODE_ENV_FILE="${HOME}/.config/aks-flexnode/${FLEXNODE_DEPLOYMENT}.env"
test -s "${FLEXNODE_ENV_FILE}"
source "${FLEXNODE_ENV_FILE}"
export KUBECONFIG="${FLEXNODE_KUBECONFIG}"
install -d -m 0700 "${WORK_DIR}"
```

Set the active subscription and display the Azure and Kubernetes targets:

```azurecli
az account set --subscription "${SUBSCRIPTION_ID}"

az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "{Cluster:name,ResourceId:id,ApiServer:(privateFqdn || fqdn)}" \
    --output table
```

```bash
kubectl cluster-info
kubectl get nodes
```

Confirm that **ResourceId** matches `AKS_RESOURCE_ID` and that the Kubernetes control-plane hostname matches **ApiServer**. If either value doesn't match, stop and reload the environment file and kubeconfig for the intended cluster.

The AKS-managed node can remain `NotReady` until you install Unbounded-Net. If a private cluster request times out, verify private DNS resolution, routing, and HTTPS access from your Bash environment.

## Install and verify the Unbounded-Net CLI

Download the CLI archive from the release selected in the environment file.

1. Select the CLI architecture for your Bash environment.

    ```bash
    case "$(uname -m)" in
        x86_64) export UNBOUNDED_ARCH="amd64" ;;
        aarch64|arm64) export UNBOUNDED_ARCH="arm64" ;;
        *) printf 'Unsupported workstation architecture: %s\n' \
            "$(uname -m)" >&2; false ;;
    esac
    ```

1. Create a protected download directory and set the release file names.

    ```bash
    export UNBOUNDED_INSTALL_DIR="${WORK_DIR}/unbounded-cli-${UNBOUNDED_VERSION}-${UNBOUNDED_ARCH}"
    export UNBOUNDED_ARTIFACT="kubectl-unbounded-linux-${UNBOUNDED_ARCH}.tar.gz"
    export UNBOUNDED_ARCHIVE="${UNBOUNDED_INSTALL_DIR}/${UNBOUNDED_ARTIFACT}"
    install -d -m 0700 "${UNBOUNDED_INSTALL_DIR}"
    ```

1. Download the CLI archive.

    ```bash
    curl --fail --location --silent --show-error \
        --proto '=https' \
        --tlsv1.2 \
        --retry 3 \
        "https://github.com/Azure/unbounded/releases/download/${UNBOUNDED_VERSION}/${UNBOUNDED_ARTIFACT}" \
        --output "${UNBOUNDED_ARCHIVE}"
    ```

1. Extract and install the CLI.

    ```bash
    tar -xzf "${UNBOUNDED_ARCHIVE}" -C "${UNBOUNDED_INSTALL_DIR}"
    sudo install -m 0755 \
        "${UNBOUNDED_INSTALL_DIR}/kubectl-unbounded" \
        /usr/local/bin/kubectl-unbounded
    ```

1. Verify that `kubectl` can run the installed plugin.

    ```bash
    command -v kubectl-unbounded
    kubectl unbounded version
    ```

    Continue when the commands locate the CLI and return its version information.

## Install Unbounded-Net and initialize the sites

An Unbounded-Net site represents a network location:

- The primary cluster site, named `cluster`, contains the AKS-managed nodes and uses `AKS_NODE_CIDR` and `AKS_POD_CIDR`.
- The flex site, named `flex-site`, contains the external flex node hosts and uses `FLEX_NODE_CIDR` and `FLEX_POD_CIDR`.

The site configuration is independent of whether the AKS API endpoint is public or private. The underlying network must already provide Layer 3 reachability between the two node networks.

1. Install Unbounded-Net.

    ```bash
    kubectl unbounded install \
        --timeout 5m
    ```

1. Initialize the primary cluster site and flex site with the address ranges from the environment file.

    ```bash
    kubectl unbounded site init \
        --name flex-site \
        --cluster-node-cidr "${AKS_NODE_CIDR}" \
        --cluster-pod-cidr "${AKS_POD_CIDR}" \
        --node-cidr "${FLEX_NODE_CIDR}" \
        --pod-cidr "${FLEX_POD_CIDR}"
    ```

    The `--cluster-*` values configure the primary site named `cluster`. The `--name` and remaining CIDR values configure the flex site named `flex-site`.

1. Connect the two sites over the existing Layer 3 path.

    ```bash
    kubectl apply -f - <<'EOF'
    apiVersion: net.unbounded-cloud.io/v1alpha1
    kind: SitePeering
    metadata:
      name: cluster-flex-private-l3
    spec:
      sites:
        - cluster
        - flex-site
      meshNodes: true
      tunnelProtocol: Auto
    EOF
    ```

    `meshNodes: true` enables mesh connectivity between nodes in both sites. `tunnelProtocol: Auto` lets Unbounded-Net select its datapath over the existing network.

## Verify networking and AKS-managed nodes

1. Wait for the Unbounded-Net operator to create the Unbounded-Net controller and node component, and then wait for their rollouts. Installation can return before these resources exist.

    ```bash
    kubectl -n unbounded-system wait \
        --for=create \
        deployment/unbounded-net-controller \
        --timeout=5m

    kubectl -n unbounded-system wait \
        --for=create \
        daemonset/unbounded-net-node \
        --timeout=5m

    kubectl -n unbounded-system rollout status \
        deployment/unbounded-net-controller \
        --timeout=5m

    kubectl -n unbounded-system rollout status \
        daemonset/unbounded-net-node \
        --timeout=5m
    ```

1. Wait for the current AKS-managed nodes to become ready.

    ```bash
    kubectl wait \
        --for=condition=Ready \
        nodes \
        --all \
        --timeout=5m
    ```

    If an AKS-managed node stays `NotReady`, verify that `AKS_SUBNET_CIDR` is contained within `AKS_NODE_CIDR` and that the AKS node, pod, service, and connected-network ranges don't overlap. Correct the address plan before you continue.

1. Inspect the node-to-Site assignment and Site peering.

    ```bash
    kubectl get nodes \
        -L net.unbounded-cloud.io/site \
        -o wide

    kubectl get sites,sitepeerings \
        -o wide
    ```

Confirm the following results:

- Every AKS-managed node is `Ready` and is assigned to the `cluster` Site.
- The `cluster` and `flex-site` Sites exist.
- The `cluster-flex-private-l3` peering reports two Sites and mesh nodes enabled.
- The `flex-site` Site has no nodes because you didn't attach a flex node host.

## Apply the temporary flex daemon RBAC when required

During preview, verify whether the `aks-flex-node-daemon` `ClusterRole` and `ClusterRoleBinding` already exist. Apply the temporary permissions only when either resource is absent.

The ClusterRoleBinding assigns these permissions to the `aks-flex-node-daemons` Kubernetes group. If you skip this step, the flex node agent can authenticate during host attachment but exits when its MachineOperation controller cache can't synchronize.

```bash
if ! kubectl get clusterrole aks-flex-node-daemon >/dev/null 2>&1 ||
    ! kubectl get clusterrolebinding aks-flex-node-daemon >/dev/null 2>&1; then
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aks-flex-node-daemon
  labels:
    kubernetes.azure.com/managedby: aks
rules:
  - apiGroups:
      - unbounded-cloud.io
    resources:
      - machineoperations
      - machines
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - unbounded-cloud.io
    resources:
      - machineoperations/status
    verbs:
      - get
      - patch
      - update
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aks-flex-node-daemon
  labels:
    kubernetes.azure.com/managedby: aks
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aks-flex-node-daemon
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: aks-flex-node-daemons
EOF
fi
```

Continue when both the `ClusterRole` and `ClusterRoleBinding` exist.

## Create a flex node pool

A flex node pool is a logical grouping for customer-provided compute. Don't add standard AKS node pool settings for node count, VM size, operating system type, or subnet configuration. You attach a prepared host in a later article.

The command sets the per-node pod limit and the maximum number of nodes that can be unavailable during an upgrade.

Use the example `pool-generation` label to tell the starting pool settings apart from the updated settings you apply later. The `pool-generation=initial:NoSchedule` taint prevents pods without a matching toleration from being scheduled on the flex nodes.

Create the pool by using Azure CLI:

```azurecli
az aks nodepool add \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --vm-set-type FlexNodes \
    --mode User \
    --kubernetes-version "${AKS_VERSION}" \
    --max-pods 75 \
    --max-unavailable 1 \
    --labels pool-generation=initial \
    --node-taints pool-generation=initial:NoSchedule \
    --output none
```

## Verify and record the flex node pool

1. Calculate the resource ID and retrieve the pool properties.

    ```bash
    export FLEX_POOL_RESOURCE_ID="${AKS_RESOURCE_ID}/agentPools/${FLEX_POOL_NAME}"
    ```

    ```azurecli
    az resource show \
        --ids "${FLEX_POOL_RESOURCE_ID}" \
        --api-version 2026-05-02-preview \
        --query "{Name:name,ProvisioningState:properties.provisioningState,KubernetesVersion:properties.orchestratorVersion,Type:properties.type}" \
        --output table
    ```

    Confirm that **ProvisioningState** is `Succeeded`, **KubernetesVersion** matches `AKS_VERSION`, and **Type** is `FlexNodes`.

1. Record the pool resource ID only after the verification succeeds.

    ```bash
    set_flexnode_env FLEX_POOL_RESOURCE_ID "${FLEX_POOL_RESOURCE_ID}"
    ```

The pool is now ready for the host preparation and attachment steps.

## Next step

Next, [prepare a Linux host and configure the Azure identity that the flex node agent uses](./prepare-flex-node-host-identity.md).
