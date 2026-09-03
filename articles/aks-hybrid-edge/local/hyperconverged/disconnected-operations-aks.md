---
title: Manage AKS for Azure Local with disconnected operations (preview)
description: Manage Azure Kubernetes Service (AKS) Arc for Azure Local with disconnected operations (preview).
ms.topic: how-to
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.custom: hyperconverged
ai-usage: ai-assisted
---

# Manage AKS for Azure Local with disconnected operations (preview)

This article gives you an overview of Azure Kubernetes Service (AKS) Arc for disconnected operations for Azure Local (preview). It closely mirrors AKS capabilities on Azure Local and includes many references to Azure Local AKS articles. You learn how to deploy and manage AKS clusters in disconnected environments, understand key differences, and review limitations to ensure successful implementation.

[!INCLUDE [IMPORTANT](../../includes/aks-disconnected-operations-preview.md)]

## Overview

AKS for disconnected operations allows you to manage Kubernetes clusters and deploy applications across various environments using disconnected operations. This capability ensures you can maintain consistent management and operational experience of AKS on Azure Local using a local control plane.

## Prerequisites

- [Azure Command-Line Interface (CLI)](/azure/azure-local/manage/disconnected-operations-cli) installed on your local machine.
- An Azure subscription associated with disconnected operations.
- Understanding of AKS and Azure Arc concepts.
- Complete [Identity for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-identity).
- Complete [Networking for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-network).
- Complete [Public key infrastructure (PKI) for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-pki).
- Complete [Hardware for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-overview#eligibility-criteria).
- Complete [Set up for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-set-up).

## Limitations

Limitations for disconnected operations with AKS include:

- Support for disconnected operations begins with the 2408 release.
- Supported Kubernetes versions: 1.33.4 and 1.33.5.
- Windows node pools aren't supported.
- Microsoft Entra ID (formerly Azure Active Directory) isn't supported for disconnected operations.
- GPUs aren't supported.
- Arc Gateway isn't supported for configuring outbound URLs.
- Create logical networks using the CLI only. The portal isn't supported.
- Create SSH keys using the CLI only. The portal isn't supported.

## Create an AKS cluster

To create an AKS cluster that supports disconnected operations, see [Create an AKS cluster through CLI](../aks-create-clusters-cli.md#create-a-kubernetes-cluster) and [Create a Kubernetes cluster using the Azure portal](../aks-create-clusters-portal.md#create-a-kubernetes-cluster).

### Install the Azure CLI extension

Before you install the Azure CLI extension, make sure you have the following installed:

- [Azure CLI](/azure/azure-local/manage/disconnected-operations-cli?view=azloc-2602&preserve-view=true)
- Extension version:
  - customlocation: 0.1.4
  - aksarc: 1.2.23
  - stack-hci-vm: 1.11.1

Install the CLI extension using the following commands:

```azurecli
az extension add --name aksarc --version 1.2.23 
az extension add --name stack-hci-vm --version 1.11.1 
az config set core.instance_discovery=false --only-show-errors
 ```

For more information, see [Install the Azure CLI extension](../aks-create-clusters-cli.md).

### Sign in with Azure CLI

You can use the `az login` command to sign in to your Azure account. For more information, see [Sign in with credentials on the command line](/cli/azure/authenticate-azure-cli-interactively#sign-in-with-credentials-on-the-command-line).

### Create logical networks

Use the [`az stack-hci-vm network lnet create`](/cli/azure/stack-hci-vm/network/lnet#az-stack-hci-vm-network-lnet-create) command to create a logical network on the virtual machine (VM) switch in Static IP configuration. For information on limitations, see [Limitations](#limitations).

```azurecli
az stack-hci-vm network lnet create \
  --subscription $subscription \
  --resource-group $resource_group \
  --custom-location $customLocationID \
  --name $lnetName \
  --vm-switch-name $vmSwitchName \
  --ip-allocation-method "Static" \
  --address-prefixes $addressPrefixes \
  --gateway $gateway \
  --dns-servers $dnsServers \
  --ip-pool-start $ipPoolStart \
  --ip-pool-end $ipPoolEnd
```

For more information, see [Create logical networks](aks-networks.md).

> [!NOTE]
> Logical networks are created through CLI only; the portal isn't supported. For more information, see [Azure Local VM limitations](/azure/azure-local/manage/disconnected-operations-arc-vm#limitations).

### Create the cluster

To create the AKS cluster, we recommend you use CLI. For more information, see [Create an AKS cluster through CLI](../aks-create-clusters-cli.md#create-a-kubernetes-cluster).

To use the Azure portal, see [Create a Kubernetes cluster using the Azure portal](../aks-create-clusters-portal.md#create-a-kubernetes-cluster). To create the SSH keys, see [Generate and store SSH keys with the Azure CLI](/azure/virtual-machines/ssh-keys-azure-cli).

Use the [`az aksarc create`](/cli/azure/aksarc#az-aksarc-create) command to create a Kubernetes cluster.

```azurecli
az aksarc create \
  --name $aksclustername \
  --resource-group $resource_group \
  --custom-location $customlocationID \
  --vnet-ids $logicnetId \
  --generate-ssh-keys
```

> [!NOTE]
> You should get JSON formatted information about the cluster once the creation is complete.

Here's an example script to create logical networks and an AKS cluster.

```azurecli
# Check and update variables according to your environment.

$subscriptionId = " "  # Update the Starter Subscription Id of your environment
$location = "autonomous"
$resourceGroupName = " " # Update the resource group name
$customLocationResourceName = " "   # This name would be referenced in resource group
$customLocationResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.ExtendedLocation/customLocations/$customLocationResourceName"
  
# IP config detail.
 
$aszhost = <Host Machine> # update with host machine name
# YAML file would be information on the following:  
$vmSwitchName= # The value of vswitchname
$addressPrefixes= # The value of ipaddressprefix
$gateway= # The value of gateway
$dnsservers= # The value of dnsservers
$ipPoolStart= # Set this according to $addressPrefixes, don't overlap k8snodeippoolstart and k8snodeippoolend
$ipPoolEnd= # Set this according to $addressPrefixes, don't overlap k8snodeippoolstart and k8snodeippoolend
  
# Create Logical Network for AKS cluster.

$lNetName = "aksarc-lnet-static"
az stack-hci-vm network lnet create `
--resource-group $resourceGroupName `
--custom-location $customLocationResourceId `
--location $location `
--name $lNetName `
--ip-allocation-method "Static" `
--address-prefixes $addressPrefixes `
--ip-pool-start $ipPoolStart `
--ip-pool-end $ipPoolEnd `
--gateway $gateway `
--dns-servers $dnsservers `
--vm-switch-name $vmSwitchName
  
# Create AKS cluster using az cli.
 
$logicNetId = (az stack-hci-vm network lnet show --resource-group $resourceGroupName --name $lNetName --query id -o tsv)
$aksClusterName = " " # please enter the clustername
$controlPlaneIp = # Set this according to $addressPrefixes, please don't overlap $ipPoolStart and $ipPoolEnd
az aksarc create -n $aksClusterName `
--resource-group $resourceGroupName `
--custom-location $customLocationResourceId `
--node-count 2 `
--vnet-ids $logicNetId `
--generate-ssh-keys `
--control-plane-ip $controlPlaneIp `
--only-show-errors
# --node-vm-size 'Standard_D8s_v3' `
```

### Retrieve `kubeconfig`

To retrieve the `kubeconfig` file for the AKS cluster, use the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command. Make sure you use your admin credentials.

Here's an example:

```azurecli
az aksarc get-credentials --resource-group myResourceGroup --name myAKSCluster --admin
```

To retrieve the certificate-based admin kubeconfig for an AKS cluster Hybrid and Edge.

Here's an example:

```azurecli
az aksarc get-credentials \
  --name "sample-aksarccluster" \
  --resource-group "sample-rg" \
  --file C:\AksArc\config-admin \
  --adminkubectl \
  --kubeconfig C:\AksArc\config-admin get ns  
```

For more information, see [Retrieve kubeconfig](retrieve-admin-kubeconfig.md#retrieve-the-certificate-based-admin-kubeconfig-using-az-cli).

### Delete an AKS cluster

You can use the [`az aksarc delete`](/cli/azure/aksarc#az-aksarc-delete) command to delete the AKS cluster you created.

```azurecli
az aksarc delete --name $aksclustername --resource-group $resource_group
```

## Related content

- [AKS on Azure Local architecture](cluster-architecture.md)
- [AKS Hybrid and Edge network requirements](network-system-requirements.md)
- [Manage node pools for an AKS cluster](manage-node-pools.md)
- [Use cluster autoscaler on an AKS arc cluster](auto-scale-aks-arc.md)
