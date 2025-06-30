---
title: Use labels in an Azure Kubernetes Service (AKS) cluster
description: Learn how to use labels in an Azure Kubernetes Service (AKS) cluster.
author: rayoef
ms.author: rayoflores
ms.topic: how-to
ms.date: 06/10/2024
ms.custom: innovation-engine, devx-track-azurecli, linux-related-content, kubernetes, aks
---

# Use labels in an Azure Kubernetes Service (AKS) cluster

If you have multiple node pools, you may want to add a label during node pool creation. [Kubernetes labels][kubernetes-labels] handle the scheduling rules for nodes. You can add labels to a node pool anytime and apply them to all nodes in the node pool.

In this how-to guide, you learn how to use labels in an Azure Kubernetes Service (AKS) cluster.

## Prerequisites

You need the Azure CLI version 2.2.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Create an AKS cluster with a label

You can create an AKS cluster with node labels to set key/value metadata for workload scheduling.

```bash
export RANDOM_SUFFIX=$(openssl rand -hex 3)
export RESOURCE_GROUP="myResourceGroup$RANDOM_SUFFIX"
export AKS_CLUSTER_NAME="myAKSCluster$RANDOM_SUFFIX"
az group create --name $RESOURCE_GROUP --location $REGION
```

Results:

<!-- expected_similarity=0.3 -->

```output
{
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx",
  "location": "eastus2",
  "managedBy": null,
  "name": "myResourceGroupxxx",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

Create the AKS cluster specifying node labels (e.g., dept=IT, costcenter=9000):

```azurecli-interactive
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME \
    --node-count 2 \
    --nodepool-labels dept=IT costcenter=9000 \
    --generate-ssh-keys --location $REGION
```

Results:

<!-- expected_similarity=0.3 -->

```output
{
  "aadProfile": null,
  "addonProfiles": {},
  "agentPoolProfiles": [
    {
      "count": 2,
      "enableAutoScaling": null,
      "mode": "System",
      "name": "nodepool1",
      "nodeLabels": {
        "costcenter": "9000",
        "dept": "IT"
      }
    }
  ],
  "dnsPrefix": "myaksclusterxxx-dns",
  "fqdn": "myaksclusterxxx-xxxxxxxx.hcp.eastus2.azmk8s.io",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.ContainerService/managedClusters/myAKSClusterxxx",
  "location": "eastus2",
  "name": "myAKSClusterxxx",
  "resourceGroup": "myResourceGroupxxx"
}
```

Verify the labels were set:

```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
kubectl get nodes --show-labels | grep -e "costcenter=9000" -e "dept=IT"
```

## Create a node pool with a label

You can create an additional node pool with labels for specific scheduling needs.

```bash
export NODEPOOL_NAME="labelnp"
az aks nodepool add \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --node-count 1 \
    --labels dept=HR costcenter=5000 \
```

The following is example output from the [`az aks nodepool list`][az-aks-nodepool-list] command showing the *labelnp* node pool is *Creating* nodes with the specified *nodeLabels*:

```bash
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER_NAME
```

Results:

<!-- expected_similarity=0.3 -->

```output
[
  {
    "count": 2,
    "name": "nodepool1",
    "nodeLabels": {
      "costcenter": "9000",
      "dept": "IT"
    }
  },
  {
    "count": 1,
    "name": "labelnp",
    "nodeLabels": {
      "costcenter": "5000",
      "dept": "HR"
    },
    "provisioningState": "Creating"
  }
]
```

Verify the labels were set:

```bash
kubectl get nodes --show-labels | grep -e "costcenter=5000" -e "dept=HR"
```

## Updating labels on existing node pools

You can update the labels on an existing node pool. Note: updating labels will overwrite the old labels.

```bash
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --labels dept=ACCT costcenter=6000 \
```

Verify the new labels are set:

```bash
kubectl get nodes --show-labels | grep -e "costcenter=6000" -e "dept=ACCT"
```

## Unavailable labels

### Reserved system labels

Since the [2021-08-19 AKS release][aks-release-2021-gh], AKS stopped the ability to make changes to AKS reserved labels. Attempting to change these labels results in an error message.

The following labels are AKS reserved labels. *Virtual node usage* specifies if these labels could be a supported system feature on virtual nodes. Some properties that these system features change aren't available on the virtual nodes because they require modifying the host.

| Label | Value | Example/Options | Virtual node usage |
| ---- | --- | --- | --- |
| kubernetes.azure.com/agentpool | \<agent pool name> | nodepool1 | Same |
| kubernetes.io/arch | amd64 | runtime.GOARCH | N/A |
| kubernetes.io/os | \<OS Type> | Linux/Windows | Same |
| node.kubernetes.io/instance-type | \<VM size> | Standard_NC6s_v3 | Virtual |
| topology.kubernetes.io/region | \<Azure region> | westus2 | Same |
| topology.kubernetes.io/zone | \<Azure zone> | 0 | Same |
| kubernetes.azure.com/cluster | \<MC_RgName> | MC_aks_myAKSCluster_westus2 | Same |
| kubernetes.azure.com/managedby | aks | aks | N/A |
| kubernetes.azure.com/mode | \<mode> | User or system | User |
| kubernetes.azure.com/role | agent | Agent | Same |
| kubernetes.azure.com/scalesetpriority | \<VMSS priority> | Spot or regular | N/A |
| kubernetes.io/hostname | \<hostname> | aks-nodepool-00000000-vmss000000 | Same |
| kubernetes.azure.com/storageprofile | \<OS disk storage profile> | Managed | N/A |
| kubernetes.azure.com/storagetier | \<OS disk storage tier> | Premium_LRS | N/A |
| kubernetes.azure.com/instance-sku | \<SKU family> | Standard_N | Virtual |
| kubernetes.azure.com/node-image-version | \<VHD version> | AKSUbuntu-1804-2020.03.05 | Virtual node version |
| kubernetes.azure.com/subnet | \<nodepool subnet name> | subnetName | Virtual node subnet name |
| kubernetes.azure.com/vnet | \<nodepool vnet name> | vnetName | Virtual node virtual network |
| kubernetes.azure.com/ppg  | \<nodepool ppg name> | ppgName | N/A |
| kubernetes.azure.com/encrypted-set | \<nodepool encrypted-set name> | encrypted-set-name | N/A |
| kubernetes.azure.com/accelerator | \<accelerator> | nvidia | N/A |
| kubernetes.azure.com/fips_enabled | \<is fips enabled?> | true | N/A |
| kubernetes.azure.com/os-sku | \<os/sku> | [Create or update OS SKU][create-or-update-os-sku] | Linux |

* *Same* is included in places where the expected values for the labels don't differ between a standard node pool and a virtual node pool. As virtual node pods don't expose any underlying virtual machine (VM), the VM SKU values are replaced with the SKU *Virtual*.
* *Virtual node version* refers to the current version of the [virtual Kubelet-ACI connector release][virtual-kubelet-release].
* *Virtual node subnet name* is the name of the subnet where virtual node pods are deployed into Azure Container Instance (ACI).
* *Virtual node virtual network* is the name of the virtual network, which contains the subnet where virtual node pods are deployed on ACI.

### Reserved prefixes

The following prefixes are AKS reserved prefixes and can't be used for any node:

* kubernetes.azure.com/
* kubernetes.io/

For more information on reserved prefixes, see [Kubernetes well-known labels, annotations, and taints][kubernetes-well-known-labels].

### Deprecated labels

The following labels are planned for deprecation with the release of [Kubernetes v1.24][aks-release-calendar]. You should change any label references to the recommended substitute.

| Label | Recommended substitute | Maintainer |
| --- | --- | --- |
| failure-domain.beta.kubernetes.io/region | topology.kubernetes.io/region | [Kubernetes][kubernetes-labels]
| failure-domain.beta.kubernetes.io/zone | topology.kubernetes.io/zone | [Kubernetes][kubernetes-labels]
| beta.kubernetes.io/arch | kubernetes.io/arch | [Kubernetes][kubernetes-labels]
| beta.kubernetes.io/instance-type | node.kubernetes.io/instance-type | [Kubernetes][kubernetes-labels]
| beta.kubernetes.io/os  | kubernetes.io/os | [Kubernetes][kubernetes-labels]
| node-role.kubernetes.io/agent* | kubernetes.azure.com/role=agent | Azure Kubernetes Service
| kubernetes.io/role* | kubernetes.azure.com/role=agent | Azure Kubernetes Service
| Agentpool* | kubernetes.azure.com/agentpool | Azure Kubernetes Service
| Storageprofile* | kubernetes.azure.com/storageprofile | Azure Kubernetes Service
| Storagetier* | kubernetes.azure.com/storagetier | Azure Kubernetes Service
| Accelerator* | kubernetes.azure.com/accelerator | Azure Kubernetes Service

*Newly deprecated. For more information, see the [Release Notes][aks-release-notes-gh].

## Next steps

Learn more about Kubernetes labels in the [Kubernetes labels documentation][kubernetes-labels].

<!-- LINKS - external -->
[aks-release-2021-gh]: https://github.com/Azure/AKS/releases/tag/2021-08-19
[aks-release-notes-gh]: https://github.com/Azure/AKS/releases
[kubernetes-labels]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
[kubernetes-label-syntax]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set
[kubernetes-well-known-labels]: https://kubernetes.io/docs/reference/labels-annotations-taints/
[virtual-kubelet-release]: https://github.com/virtual-kubelet/azure-aci/releases

<!-- LINKS - internal -->
[aks-release-calendar]: ./supported-kubernetes-versions.md#aks-kubernetes-release-calendar
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks#az-aks-nodepool-add
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[create-or-update-os-sku]: /rest/api/aks/agent-pools/create-or-update#ossku
[install-azure-cli]: /cli/azure/install-azure-cli