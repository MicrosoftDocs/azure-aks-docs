---
title: Use Arm64 Virtual Machines in Azure Kubernetes Service (AKS) for cost effectiveness
description: Learn how to create node pools using Arm64 Virtual Machines with Azure Kubernetes Service (AKS) for cost effectiveness
ms.topic: how-to
ms.date: 02/25/2025
author: allyford
ms.author: allyford

---

# Use Arm-based processor (Arm64) Virtual Machines (VMs) in an Azure Kubernetes Service (AKS) cluster for cost effectiveness

[Arm-based processors (Arm64)][cobalt-arm64-vm] are power-efficient and cost-effective, but don't compromise on performance. These Arm64 VMs are engineered to efficiently run dynamic, scalable workloads and can deliver up to 50% better price-performance than comparable x86-based VMs for scale-out workloads.

Because of their ability to scale workloads efficiently, Arm64 VMs are well-suited for web or application servers, open-source databases, cloud-native applications, gaming servers, and other high traffic applications.

>[!NOTE]
>While a combination of CPU, memory, and networking capacity configurations heavily influences the cost effectiveness of a SKU, Arm64 VM types are recommended for cost optimization.

In this article, you'll learn how to add a Arm64 VM to an existing node pool.

## Prerequisites

Before you begin, make sure you have:

- An existing AKS cluster.
- The [Dpsv5][arm-sku-vm1], [Dplsv5][arm-sku-vm2], or [Epsv5][arm-sku-vm3] series SKUs available for your subscription.

## Limitations
- Arm64 VMs aren't supported for Windows node pools.
- Existing node pools can't be updated to use an Arm64 VM.
- Federal Information Process Standard (FIPS)-enabled node pools are only supported with Arm64 SKUs when using Azure Linux 3.0+.
- Arm64 node pools aren't supported on Defender-enabled clusters with Kubernetes version 1.29.0 or lower.

## Create node pools with Arm64 VMs

The Arm64 processor provides low power compute for your Kubernetes workloads. Arm64 virtual machines can be added to existing clusters even mixing Intel and Arm architecture node pools within a cluster. To create an Arm64 node pool, you need to choose a [Dpsv5][arm-sku-vm1], [Dplsv5][arm-sku-vm2], or [Epsv5][arm-sku-vm3] series virtual machine.

### Add a node pool with an Arm64 VM

Use [`az aks nodepool add`][az-aks-nodepool-add] to add a node pool with an Arm64 VM to an existing cluster. Alternatively, if you're using [Azure Linux 3.0+][azure-linux-3.0], you can add a node pool with an Arm64 VM and [FIPS](./enable-fips-nodes.md) enabled.

- Add a node pool with an Arm64 VM

```azurecli-interactive
    az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name $ARM_NODE_POOL_NAME \
    --node-count 3 \
    --node-vm-size Standard_D2pds_v5
```
- Add a FIPS-enabled node pool with an Arm64 VM

Limitations: 
- Node pools with Arm64 VMs and [FIPS](./enable-fips-nodes.md) enabled aren't supported with Ubuntu OS.
- Node pools with Arm64 VMs and [FIPS](./enable-fips-nodes.md) require kubernetes version 1.32+.

Use the [`az aks nodepool add`][az-aks-nodepool-add] with `--enable-fips-image` and `--os-sku` parameters.

 ```azurecli-interactive
     az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name $ARM_NODE_POOL_NAME \
    --os-sku AzureLinux
    --enable-fips-image
    --kubernetes-version 1.32
    --node-count 3 \
    --node-vm-size Standard_D2pds_v5
```
For more information on verifying FIPS enablement and disabling FIPS, see [Enable FIPS node pools](./enable-fips-nodes.md).

- Update a node pool with an Arm64 VM to enable FIPS

Limitations: 
- Node pools with Arm64 VMs and [FIPS](./enable-fips-nodes.md) enabled aren't supported with Ubuntu OS.
- Node pools with Arm64 VMs and [FIPS](./enable-fips-nodes.md) require kubernetes version 1.32+.

Use [`az aks nodepool update`][az-aks-nodepool-update] command with the `--enable-fips-image` parameter to enable FIPS on an existing node pool.

 ```azurecli-interactive
     az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name np \
    --enable-fips-image
```

This command triggers a reimage of the node pool immediately to deploy the FIPS compliant Operating System. This reimage occurs during the node pool update. No extra steps are required.

For more information on verifying FIPS enablement and disabling FIPS, see [Enable FIPS node pools](./enable-fips-nodes.md).

## Verify the node pool uses Arm64

Verify a node pool uses Arm64 using the [`az aks nodepool show`][az-aks-nodepool-show] command and verify the `vmSize` is a [Dpsv5][arm-sku-vm1], [Dplsv5][arm-sku-vm2], or [Epsv5][arm-sku-vm3] series.

 ```azurecli-interactive
     az aks nodepool show \
     --resource-group myResourceGroup \
     --cluster-name myAKSCluster \
     --name mynodepool \
     --query vmSize
```

The following example output shows the node pool uses Arm64:

```output
 "Standard_D2pds_v5"
```

## Next steps

In this article, you learned how to add a node pool with an Arm64 VM to an AKS cluster. 
- For more recommendations for cost savings, see [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md).
- For more information about Arm64, see [Cobalt Arm-based processors (Arm64)][cobalt-arm64-vm].
- For more information on verifying FIPS enablement and disabling FIPS, see [Enable FIPS node pools](./enable-fips-nodes.md).
- For Azure Linux 3.0 enablement and support details, see [Enable Azure Linux 3.0][azure-linux-3.0].

<!-- LINKS - Internal -->
[arm-sku-vm1]: /azure/virtual-machines/dpsv5-dpdsv5-series
[arm-sku-vm2]: /azure/virtual-machines/dplsv5-dpldsv5-series
[arm-sku-vm3]: /azure/virtual-machines/epsv5-epdsv5-series
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az_aks_nodepool_show
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az_aks_nodepool_delete
[azure-linux-3.0]: /azure/azure-linux/how-to-enable-azure-linux-3
[cobalt-arm64-vm]: /azure/virtual-machines/sizes/cobalt-overview


