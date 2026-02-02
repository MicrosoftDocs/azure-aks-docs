---
title: Bring Your Own Container Network Interface (CNI) Plugin with Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn how to bring your own Container Network Interface (CNI) plugin with Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 06/20/2023
# Customer intent: As an advanced Kubernetes user, I want to deploy an AKS cluster with no preinstalled CNI plugin so that I can use a custom CNI solution that aligns with my on-premises environment.
---

# Bring your own CNI plugin with Azure Kubernetes Service (AKS)

Kubernetes doesn't provide a network interface system by default. Instead, [network plugins][kubernetes-cni] provide this functionality. Azure Kubernetes Service (AKS) provides several supported Container Network Interface (CNI) plugins. For information on supported plugins, see [Networking concepts for applications in Azure Kubernetes Service][aks-network-concepts].

The supported plugins meet most networking needs in Kubernetes. However, advanced AKS users might want the same CNI plugin that they used in on-premises Kubernetes environments. Or these users might want to use advanced functionalities available in other CNI plugins.

This article shows how to deploy an AKS cluster with no CNI plugin preinstalled. From there, you can install any CNI plugin that works in Azure.

## Support

Microsoft support can't assist with CNI-related issues in clusters that you deploy by bringing your own CNI plugin. For example, CNI-related issues would cover most east/west (pod to pod) traffic, along with `kubectl proxy` and similar commands. If you want CNI-related support, use a supported AKS network plugin or seek support from the CNI plugin vendor.

Microsoft still provides support for issues that aren't related to CNI.

## IP address planning considerations

When using a bring your own CNI (BYO CNI) plugin with AKS, IP address planning responsibilities are split between AKS and the customer-managed CNI. Unlike AKS-managed CNI plugins, AKS does not allocate or manage pod IP addresses when a BYO CNI is used.

> [!NOTE]
> The [IP address planning for your Azure Kubernetes Service (AKS) clusters](concepts-network-ip-address-planning.md) article focuses on AKS-managed networking plugins. In BYO CNI scenarios, only guidance related to node subnet sizing, upgrade and scaling behavior, and Kubernetes service address ranges is applicable. Pod IP address allocation, routing, and scaling behavior is determined by the selected CNI plugin.

### Virtual network and subnet sizing

AKS still requires a virtual network and subnet to host cluster nodes. Subnet sizing should account for:

- The maximum number of nodes per node pool
- Additional nodes required for upgrade and scale operations, such as surge upgrades
- Azure resources that allocate IP addresses from subnets in the virtual network, such as internal load balancers

AKS upgrades and scaling operations remain node-based. During these operations, AKS may temporarily provision additional nodes, so the subnet must be large enough to accommodate the maximum node count.

> Pod IP addresses are not allocated from the AKS subnet when using BYO CNI unless explicitly implemented by the CNI plugin.

### Kubernetes service address range

All AKS clusters, including those using BYO CNI, require a Kubernetes service address range (`serviceCIDR`) and a DNS service IP address (`dnsServiceIP`). The following constraints apply:

- The service address range must not overlap with the virtual network or any connected network
- The service CIDR must be smaller than /12
- The DNS service IP must be within the service CIDR range and must not be the first IP address in the range

These requirements are independent of the CNI plugin.

### Pod networking and IP management

With BYO CNI, pod IP address management (IPAM), routing, and scaling behavior are entirely determined by the CNI plugin.

AKS does not:
- Allocate pod IP addresses
- Pre-assign per-node pod CIDR ranges
- Enforce pod IP reuse or release behavior

Guidance related to overlay or flat networking models, per-node pod CIDR sizing, or subnet sizing formulas that include pod counts does not apply to BYO CNI scenarios.

### Maximum pods per node

AKS enforces a configurable maximum number of pods per node (`maxPods`) at the kubelet level. When using BYO CNI, this setting limits pod scheduling density but does not determine IP capacity. You are responsible for ensuring that the selected CNI plugin can support the configured pod density and cluster scale.

## Prerequisites

* For Azure Resource Manager or Bicep, use at least template version 2022-01-02-preview or 2022-06-01.
* For the Azure CLI, use at least version 2.39.0.
* The virtual network for the AKS cluster must allow outbound internet connectivity.
* AKS clusters can't use `169.254.0.0/16`, `172.30.0.0/16`, `172.31.0.0/16`, or `192.0.2.0/24` for the address range for the Kubernetes service, pods, or cluster virtual network.
* The cluster identity that the AKS cluster uses must have at least [Network Contributor](/azure/role-based-access-control/built-in-roles#network-contributor) permissions on the subnet within your virtual network. If you want to define a [custom role](/azure/role-based-access-control/custom-roles) instead of using the built-in Network Contributor role, the following permissions are required:
  * `Microsoft.Network/virtualNetworks/subnets/join/action`
  * `Microsoft.Network/virtualNetworks/subnets/read`
* The subnet assigned to the AKS node pool can't be a [delegated subnet](/azure/virtual-network/subnet-delegation-overview).
* AKS doesn't apply network security groups (NSGs) to its subnet or modify any of the NSGs associated with that subnet. If you provide your own subnet and add NSGs associated with that subnet, you must ensure that the security rules in the NSGs allow traffic within the node's Classless Inter-Domain Routing (CIDR) range. For more information, see [Network security groups][aks-network-nsg].
* AKS doesn't create a route table in the managed virtual network.
* You must specify a Pod CIDR (IP address range for pods). The AKS control plane uses this range for internal traffic routing to pods, even though pod IP assignment will be managed by your custom CNI. If no pod CIDR is provided, control plane to pod communication may fail or be misrouted. You must select a pod CIDR that does not conflict with any other network in your environment and avoids Azure reserved ranges, such as, `169.254.0.0/16`, `172.30.0.0/16`, `172.31.0.0/16`, or `192.0.2.0/24`. For example, you might use a range such as `10.XX.0.0/16` that is unique to your cluster. This ensures that the control plane can route directly to pod IPs on your nodes, and no IP overlap will occur if you integrate with other networks or clusters.

## Create an AKS cluster with no CNI plugin preinstalled

# [Azure CLI](#tab/azure-cli)

1. Create an Azure resource group for your AKS cluster by using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --location eastus --name myResourceGroup
    ```

2. Create an AKS cluster by using the [`az aks create`][az-aks-create] command. Pass the `--network-plugin` parameter with the parameter value of `none`.

    ```azurecli-interactive
    az aks create \
        --location eastus \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --network-plugin none \
        --pod-cidr "10.10.0.0/16" \
        --generate-ssh-keys
    ```

# [Azure Resource Manager](#tab/azure-resource-manager)

For information on how to deploy the following template, see the [ARM template documentation][deploy-arm-template].

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "clusterName": {
      "type": "string",
      "defaultValue": "aksbyocni"
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "kubernetesVersion": {
      "type": "string",
      "defaultValue": "1.22"
    },
    "nodeCount": {
      "type": "int",
      "defaultValue": 3
    },
    "nodeSize": {
      "type": "string",
      "defaultValue": "Standard_B2ms"
    }
  },
  "resources": [
    {
      "type": "Microsoft.ContainerService/managedClusters",
      "apiVersion": "2022-06-01",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('location')]",
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "agentPoolProfiles": [
          {
            "name": "nodepool1",
            "count": "[parameters('nodeCount')]",
            "mode": "System",
            "vmSize": "[parameters('nodeSize')]"
          }
        ],
        "dnsPrefix": "[parameters('clusterName')]",
        "kubernetesVersion": "[parameters('kubernetesVersion')]",
        "networkProfile": {
          "networkPlugin": "none",
          "podCidr": "[parameters('pod-cidr')]"
        }
      }
    }
  ]
}
```

# [Bicep](#tab/bicep)

For information on how to deploy the following template, see the [Bicep template documentation][deploy-bicep-template].

```bicep
param clusterName string = 'aksbyocni'
param location string = resourceGroup().location
param kubernetesVersion string = '1.22'
param nodeCount int = 3
param nodeSize string = 'Standard_B2ms'
param podCidr string = '10.2.0.0/16'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-06-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        mode: 'System'
        vmSize: nodeSize
      }
    ]
    dnsPrefix: clusterName
    kubernetesVersion: kubernetesVersion
    networkProfile: {
      networkPlugin: 'none'
      podCidr: podCidr
    }
  }
}
```

---

## Deploy a CNI plugin

After AKS provisioning finishes, the cluster is online. But all the nodes are in a `NotReady` state, as shown in the following example:

  ```bash
    $ kubectl get nodes
    NAME                                STATUS     ROLES   AGE    VERSION
    aks-nodepool1-23902496-vmss000000   NotReady   agent   6m9s   v1.21.9

    $ kubectl get node -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].message'
    NAME                                STATUS
    aks-nodepool1-23902496-vmss000000   container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
  ```

At this point, the cluster is ready for installation of a CNI plugin.

## Related content

* [Use a static IP address with the Azure Kubernetes Service load balancer](static-ip.md)
* [Use an internal load balancer with Azure Kubernetes Service](internal-lb.md)
* [Use the application routing add-on in Azure Kubernetes Service](app-routing.md)

<!-- LINKS - External -->
[kubernetes-cni]: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
<!-- LINKS - Internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[aks-network-concepts]: concepts-network.md
[aks-network-nsg]: concepts-network.md#network-security-groups
[deploy-bicep-template]: /azure/azure-resource-manager/bicep/deploy-cli
[az-group-create]: /cli/azure/group#az-group-create
[deploy-arm-template]: /azure/azure-resource-manager/templates/deploy-cli
