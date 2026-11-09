---
title: Configure Managed Support for DRANET on Azure Kubernetes Service (AKS)
description: Learn how to enable managed support for DRANET on an AKS node pool for RDMA workloads and migrate from a self-deployed network operator.
ms.topic: how-to
ms.date: 11/9/2026
author: sdesai345
ms.author: sachidesai
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Configure managed support for DRANET on Azure Kubernetes Service (AKS)

[DRANET](https://github.com/kubernetes-sigs/dranet) is a Kubernetes network driver that uses Dynamic Resource Allocation (DRA) to support high-performance networking for applications. Managed support for DRANET provides an opt-in experience to simplify Remote Direct Memory Access (RDMA) networking on Azure Kubernetes Service (AKS) nodes. When you enable this node pool feature, AKS installs, updates, and manages the networking drivers compatible with the RDMA virtual machine (VM) size.

Use managed support for DRANET for distributed AI and machine learning training, inference, and high-performance computing workloads that need low-latency, high-throughput communication over InfiniBand. The feature can reduce the operational work of managing RDMA networking components yourself.

## How managed support for DRANET works

Enable managed support for DRANET separately on each node pool with an [Azure RDMA-capable VM size](/azure/virtual-machines/sizes/overview). AKS labels the nodes in that pool with `network-dra` and manages the network drivers for you.

To use DRA, create a `ResourceClaimTemplate` that describes the network interface cards (NICs) your workload needs, such as the device class and number of NICs. Reference the template from your deployment, then Kubernetes creates a resource claim for that pod. The AKS scheduler uses this claim and available devices to place the pod on a node that can provide the requested NICs, thus avoiding placement of the workload onto a node that can't meet its networking needs.

## Limitations

- Managed support for DRANET is supported on RDMA-capable [VM sizes in Azure](/azure/virtual-machines/sizes/overview), such as the [N-series](/azure/virtual-machines/sizes/overview#gpu-accelerated) and [H-series](/azure/virtual-machines/sizes/overview#high-performance-compute).
- AKS [node auto-provisioning (NAP)](./node-auto-provisioning.md) is not currently supported with DRANET.
- Windows node pools are not supported with this feature.
- This feature is not supported on AKS clusters with [bring-your-own CNI plugin](/azure/aks/use-byo-cni).
- Don't run [NVIDIA Network Operator](https://github.com/Mellanox/network-operator) or [AMD Network Operator](https://github.com/ROCm/network-operator) components that manage overlapping RDMA resources on the same nodes where managed support for DRANET is enabled.
- Managed support for DRANET doesn't convert workloads that use RDMA device plugin resources. Update those workloads to use DRA resource claims.

## Prerequisites

Before you begin, ensure you have the following prerequisites:

- An existing AKS cluster with a minimum Kubernetes version `1.35`.
- Quota for an RDMA-capable Azure VM size in the same region as your AKS cluster.
- Azure CLI version `2.91.0` or later. Run `az --version` to find the installed version.

Set environment variables for the examples in this article:

```azurecli-interactive
RESOURCE_GROUP=<resource-group>
CLUSTER_NAME=<cluster-name>
NODE_POOL_NAME=<node-pool-name>
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
```

## Migrate from Network Operator

If you're running [NVIDIA Network Operator](https://github.com/Mellanox/network-operator) on your AKS cluster, don't use it with managed support for DRANET on the same nodes. Both systems install and manage overlapping RDMA components. If you installed NVIDIA Network Operator, remove it and its managed resources before you enable managed support for DRANET.

> [!IMPORTANT]
> Removing NVIDIA Network Operator interrupts workloads that use its networking resources. Stop or move affected workloads before you begin. 
> Review any custom resources before deleting them because they might contain configurations that you need to retain.

1. Get your AKS cluster credentials.

   ```azurecli-interactive
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $CLUSTER_NAME
   ```

1. List Helm releases and identify the NVIDIA Network Operator release name and namespace.

   ```bash
   helm list --all-namespaces
   ```

   A common installation uses the release name `network-operator` and the
   namespace `nvidia-network-operator`. Use the values from your environment in
   the following commands.

1. List the custom resources managed through NVIDIA Network Operator.

   ```bash
   kubectl get nicclusterpolicies.mellanox.com --all-namespaces
   kubectl get hostdevicenetworks.mellanox.com --all-namespaces
   kubectl get macvlannetworks.mellanox.com --all-namespaces
   kubectl get ipoibnetworks.mellanox.com --all-namespaces
   ```

   If a resource type isn't installed, `kubectl` returns a message that the server doesn't have that resource type. Delete the resources returned by the commands according to your deployment's removal procedure.

1. Uninstall the Helm release. Replace the placeholders with the release name and namespace from the previous step.

   ```bash
   helm uninstall <network-operator-release> \
     --namespace <network-operator-namespace> \
     --wait
   ```

1. Confirm that the Helm release and Network Operator pods are removed.

   ```bash
   helm status <network-operator-release> \
     --namespace <network-operator-namespace>
   kubectl get pods --namespace <network-operator-namespace>
   ```

   Helm returns `release: not found`, while Kubernetes returns `No resources found` or reports that the namespace isn't found.

1. Confirm that no NVIDIA Network Operator custom resources remain.

   ```bash
   kubectl get nicclusterpolicies.mellanox.com --all-namespaces
   kubectl get hostdevicenetworks.mellanox.com --all-namespaces
   kubectl get macvlannetworks.mellanox.com --all-namespaces
   kubectl get ipoibnetworks.mellanox.com --all-namespaces
   ```

   Each installed resource type should return `No resources found`.

1. List the remaining NVIDIA Network Operator custom resource definitions (CRDs).

   ```bash
   kubectl get customresourcedefinitions | grep mellanox.com
   ```

   Helm can leave CRDs behind. After you confirm that no other workloads or
   operators use these CRDs, follow the [NVIDIA Network Operator uninstall guidance](https://docs.nvidia.com/networking/display/cokan10/network+operator) to remove the CRDs installed by your release.

If you installed the [AMD Network Operator](https://github.com/ROCm/network-operator), follow a similar process to remove its networking plugins and Helm charts before you enable managed support for DRANET.

## Enable managed support for DRANET on a new node pool

Choose the node OS for the new node pool. Each node pool needs an RDMA-capable VM size and `--enable-managed-dranet`.

| Node OS | `--os-sku` value | Notes |
|---|---|---|
| Ubuntu Linux | Omit the parameter | Default OS SKU for the cluster's Kubernetes version. |
| Azure Linux | `AzureLinux` | Set `--os-sku` explicitly. |
| Azure Container Linux | `AzureContainerLinux` | Set `--os-sku` explicitly. Review the Azure Container Linux limitations later in this section. |

### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-rdma-node-pool)

To use the default Ubuntu operating system (OS) SKU, create the node pool without specifying an OS SKU. The node pool uses the default operating system based on the Kubernetes version of the cluster.

Create an RDMA-capable node pool with the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command and set `--enable-managed-dranet`.

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NODE_POOL_NAME \
  --node-count 1 \
  --node-vm-size Standard_ND40rs_v2 \
  --enable-managed-dranet
```

The command returns the node pool resource. The response includes the following values after AKS accepts the configuration:

```json
{
  "networkProfile": {
    "dranet": {
      "mode": "Managed"
    }
  },
  "provisioningState": "Succeeded"
}
```

### [Azure Linux node pool](#tab/add-azure-linux-rdma-node-pool)

To use Azure Linux, specify the OS SKU by setting `--os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default.

Create an RDMA-capable node pool with the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command, `--os-sku` set to `AzureLinux`, and `--enable-managed-dranet`.

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NODE_POOL_NAME \
  --os-sku AzureLinux \
  --node-count 1 \
  --node-vm-size Standard_ND40rs_v2 \
  --enable-managed-dranet
```

The command returns the node pool resource. The response includes `"provisioningState": "Succeeded"` and `"networkProfile": { "dranet": { "mode": "Managed" } }` after AKS accepts the configuration.

### [Azure Container Linux node pool](#tab/add-azure-container-linux-rdma-node-pool)

To use Azure Container Linux, specify the OS SKU by setting `--os-sku` to `AzureContainerLinux` during node pool creation. The `os-type` is set to `Linux` by default.

Create an RDMA-capable node pool with the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command, `--os-sku` set to `AzureContainerLinux`, and `--enable-managed-dranet`.

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NODE_POOL_NAME \
  --os-sku AzureContainerLinux \
  --node-count 1 \
  --node-vm-size Standard_ND40rs_v2 \
  --enable-managed-dranet
```

The command returns the node pool resource. The response includes `"provisioningState": "Succeeded"` and `"networkProfile": { "dranet": { "mode": "Managed" } }` after AKS accepts the configuration.

[!INCLUDE [azure container linux limitations](./includes/azure-container-linux-limitations.md)]

If the initial command response shows an in-progress state, wait for the node pool to reach `Succeeded` before you deploy RDMA workloads.

---

## Enable managed support for DRANET on an existing node pool

Before you update an existing node pool, remove any self-managed RDMA components that overlap with managed support for DRANET. Enable the feature by using the [`az aks nodepool update`](/cli/azure/aks/nodepool#az-aks-nodepool-update) command.

```azurecli-interactive
az aks nodepool update \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NODE_POOL_NAME \
  --enable-managed-dranet
```

Omitting `--enable-managed-dranet` from a later node pool update preserves the existing DRANET network profile setting.

## Verify managed support for DRANET

1. Confirm that the node pool provisioning state is `Succeeded` and the DRANET
   mode is `Managed`.

   ```azurecli-interactive
   az aks nodepool show \
     --resource-group $RESOURCE_GROUP \
     --cluster-name $CLUSTER_NAME \
     --name $NODE_POOL_NAME \
     --query "{provisioningState:provisioningState,DRANET:networkProfile.dranet.mode}" \
     --output table
   ```

   The expected output resembles the following example:

   ```output
   ProvisioningState    DRANET
   -------------------  ------------
   Succeeded            Managed
   ```

1. Confirm that AKS labeled nodes in the node pool for RDMA workload scheduling.

   ```bash
   kubectl get nodes \
     --selector agentpool=$NODE_POOL_NAME,network-dra \
     --show-labels
   ```

   The command returns the nodes in the selected node pool. Each returned node includes the `network-dra` label. An empty result indicates that labeling isn't complete or that the node pool doesn't contain a ready node.

## Run a workload that requests an RDMA NIC

The following example uses a [`Standard_ND96isr_H200_v5`](/azure/virtual-machines/sizes/gpu-accelerated/nd-h200-v5-series) RDMA-capable node pool and a DRA `ResourceClaimTemplate` to request eight RDMA interfaces from the `dranet.azure.com` device class.

1. Confirm that managed support for DRANET is enabled on the node pool:

    ```azurecli-interactive
    az aks nodepool show \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name $NODE_POOL_NAME \
      --query "{vmSize:vmSize,dranetMode:networkProfile.dranet.mode}" \
      --output table
    ```

    The output should report `Standard_ND96isr_H200_v5` for `vmSize` and `Managed` for `dranetMode`.

1. Confirm that DRANET published its DRA device class:

    ```bash
    kubectl get deviceclass.resource.k8s.io
    ```

    The output should show the `rdma.kubernetes.azure.com` device class and the `dra.net` driver.

1. Create a file named `dranet-workload.yaml` with the following resource claim template and pod. Replace `<node-pool-name>` with the value of `$NODE_POOL_NAME`:

    ```yaml
    apiVersion: resource.k8s.io/v1beta1
    kind: ResourceClaimTemplate
    metadata:
      name: rdma-dra-template
      namespace: default
    spec:
      spec:
        devices:
          requests:
            - name: ib-interfaces
              deviceClassName: rdma.kubernetes.azure.com
              count: 8
              selectors:
                - cel:
                    expression: 'device.driver == "dra.net" && device.attributes["dra.net"].rdma == true'
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: dranet-dra-workload
      namespace: default
    spec:
      nodeSelector:
        agentpool: <node-pool-name>
        network-dra: "true"
      resourceClaims:
        - name: rdma-nic-claim
          resourceClaimTemplateName: rdma-dra-template
      containers:
        - name: workload
          image: mcr.microsoft.com/mirror/docker/library/ubuntu:24.04
          command: ["sleep", "3600"]
          resources:
            claims:
              - name: rdma-nic-claim
    ```

    The `count: 8` field requests eight interfaces. Kubernetes creates a `ResourceClaim` from the template, and the DRANET driver allocates devices for the pod. If the node can't satisfy the request, the pod won't be scheduled.

1. Create the claim template and workload:

    ```bash
    kubectl apply -f dranet-workload.yaml
    ```

1. Confirm that Kubernetes allocated the claim and scheduled the pod on a node:

    ```bash
    kubectl get resourceclaim -n default -o wide
    kubectl describe resourceclaim dranet-dra-workload-rdma-nic-claim -n default
    ```

1. Locate the DRANET pod on the node assigned to the workload and check its logs for resource preparation and device injection:

    ```bash
    NODE_NAME=$(kubectl get pod dranet-dra-workload \
      -n default -o jsonpath='{.spec.nodeName}')
    DRANET_POD=$(kubectl get pod -n kube-system \
      -l app.kubernetes.io/name=dranet \
      --field-selector spec.nodeName=$NODE_NAME \
      -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -n kube-system $DRANET_POD --tail=50 \
      | grep -E "(NodePrepareResources|Allocated|CDI|mlx5)"
    ```

1. Delete the sample workload and claim template when you're finished:

    ```bash
    kubectl delete pod dranet-dra-workload --ignore-not-found=true
    kubectl delete resourceclaimtemplate rdma-dra-template \
      -n default --ignore-not-found=true
    kubectl delete resourceclaim dranet-dra-workload-rdma-nic-claim \
      -n default --ignore-not-found=true
    ```

## Disable managed support for DRANET

1. Disable managed support for DRANET on an existing node pool with the [`az resource update`](/cli/azure/resource#az-resource-update) command:

    ```azurecli-interactive
    az resource update \
   --ids "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME/agentPools/$NODE_POOL_NAME" \
   --api-version 2026-06-01 \
   --set properties.networkProfile.dranet.mode=Unmanaged
    ```

1. Confirm that the network profile reflects `Unmanaged` DRANET mode with the [`az aks nodepool show`](/cli/azure/aks/nodepool#az-aks-nodepool-show) command:

    ```azurecli-interactive
    az aks nodepool show \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name $NODE_POOL_NAME \
      --query "networkProfile.dranet.mode" \
      --output tsv
    ```

    The expected output is `Unmanaged` with the `network-dra` label removed from nodes in that pool.

## FAQ

### Does managed support for DRANET enable RDMA on every node pool?

No. The setting applies only to the node pool where you enable it. Enable managed support for DRANET separately on each supported node pool that needs RDMA networking.

### Can I use managed support for DRANET with a self-managed NVIDIA or AMD Network Operator?

Don't use both systems to manage overlapping networking components on the same nodes. Remove the Network Operator and confirm that its resources are gone before you enable managed support for DRANET. Confirm the support policy before retaining any separately managed NVIDIA or AMD networking component.

### Is managed support for DRANET enabled by default?

No. An omitted DRANET profile and `mode=Unmanaged` both mean that AKS doesn't manage DRANET components for the node pool.

## Troubleshoot managed support for DRANET

If the node pool remains in a failed provisioning state, review the node pool operation details and AKS activity logs. Confirm that the Azure VM size, Kubernetes version, and node OS SKU support managed support for DRANET. Also confirm that self-managed networking components aren't still running on the target nodes.

Use the following steps to check the managed components:

1. Confirm that every node in the opted-in node pool is `Ready` and has the
   `network-dra` label.

   ```bash
   kubectl get nodes \
     --selector agentpool=$NODE_POOL_NAME \
     --show-labels
   ```

   If a node isn't `Ready`, use `kubectl describe node <node-name>` to review its conditions and recent events. If the label is missing, confirm that the node pool reports `Succeeded` and `networkProfile.dranet.mode` reports `Managed`. Wait for an in-progress node pool operation to finish. If the operation failed, resolve the error shown in the Azure activity log before you retry the node pool update.

1. Confirm that the DRANET components are running. The command includes
   container images so that it can find components even if their workload names change between releases.

   ```bash
   POD_COLUMNS='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IMAGES:.spec.containers[*].image'
   kubectl get pods --all-namespaces \
     --output custom-columns="$POD_COLUMNS" \
     | grep -i dranet
   ```

   The returned pods should have a `Running` status. If no pods are returned,
   confirm that at least one node pool has DRANET mode set to `Managed`. If a pod isn't running, use `kubectl describe pod {pod-name} --namespace {namespace}` and `kubectl logs {pod-name} --namespace {namespace} --all-containers` to review events and logs.

## Next steps

- Learn about [Azure RDMA-capable VM sizes](/azure/virtual-machines/sizes/overview).
- Review [Kubernetes Dynamic Resource Allocation (DRA)](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/).
- Learn about workload scheduling [best practices](/azure/aks/operator-best-practices-scheduler) on AKS.