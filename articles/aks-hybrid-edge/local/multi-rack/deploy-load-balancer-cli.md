---
title: Deploy extension for MetalLB for Azure Arc enabled Kubernetes clusters using Azure CLI
description: Learn how to deploy the MetalLB extension for Azure Arc-enabled Kubernetes clusters on Azure Local.
ms.topic: how-to
ms.custom: devx-track-azurecli, multi-rack
ms.date: 09/01/2026
ms.author: sanjanamohan
author: sanjanamsft
---

# Deploy extension for MetalLB for Azure Kubernetes Service Arc-enabled cluster using Azure CLI

**Applies to:** :heavy_check_mark: AKS on Azure Local for multi-rack deployments

The main purpose of a load balancer is to distribute traffic across multiple nodes in a Kubernetes cluster. Traffic distribution can help prevent downtime and improve overall performance of applications. AKS enabled by Azure Arc supports creating a [MetalLB](https://metallb.universe.tf/) load balancer instance on your Kubernetes cluster using an Arc extension.

## Prerequisites

- An Azure Arc-enabled Kubernetes cluster. You can create a Kubernetes cluster on Azure Local using the Azure CLI or the Azure portal. AKS on Azure Local clusters are Arc-enabled by default.
- Make sure you have enough IP addresses for the load balancer. Ensure that the IP addresses reserved for the load balancer don't conflict with the IP addresses in your logical network IP pools or the control plane IP. IP addresses are automatically allocated from logical network IP pools; plan for sufficient capacity in those pools before deploying a load balancer.
- This how-to guide assumes you understand how MetalLB works. For more information, see the [overview for MetalLB for Kubernetes](../hyperconverged/load-balancer-overview.md).

## Install the Azure CLI extension

Run the following command to install the necessary Azure CLI extension:

```azurecli
az extension add -n k8s-runtime --upgrade
```

## Enable Arc extension for MetalLB

Configure the following variables before proceeding:

| Parameter | Description |
| --------- | ----------- |
| `$subId` | Azure subscription ID of your Kubernetes cluster. |
| `$rgName` | Azure resource group of your Kubernetes cluster. |
| `$clusterName` | The name of your Kubernetes cluster. |

### Option 1: Enable Arc extension for MetalLB using `az k8s-runtime load-balancer enable`

To enable the Arc extension for MetalLB using the following command, you must have Microsoft Graph permission `Application.Read.All`. Fore more information, see [Microsoft Graph permissions reference](/graph/permissions-reference#applicationreadall). You can check if you have this permission by logging into your Azure subscription and running the following command:

```azurecli
az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --output json
```

The public Microsoft Graph application with the `Application.Read.All` permission has the `appId` `00000003-0000-0000-c000-000000000000`. If the command fails, contact your Azure tenant administrator to get the `Application.Read.All` role.

If you do have the permission, you can use the `az k8s-runtime load-balancer enable` command to install the Arc extension and register the resource provider for your Kubernetes cluster. The `--resource-uri` parameter refers to the Azure Resource Manager ID of your Kubernetes cluster:

```azurecli
az k8s-runtime load-balancer enable --resource-uri subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Kubernetes/connectedClusters/$clusterName
```

### Option 2: Enable Arc extension for MetalLB using `az k8s-extension create`

If you don't have Graph permission `Application.Read.All`, you can follow these steps:

1. Register the `Microsoft.KubernetesRuntime RP` if it's not registered. You only need to register once per Azure subscription. You can also register resource providers using the Azure portal. For more information about how to register resource providers and required permissions, see [how to register a resource provider](/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider).

   ```azurecli
   az provider register -n Microsoft.KubernetesRuntime
   ```

   You can check if the resource provider was registered successfully by running the following command.

   ```azurecli
   az provider show -n Microsoft.KubernetesRuntime -o table
   ```

   Expected output:

   ```output
   Namespace                    RegistrationPolicy    RegistrationState
   ---------------------------  --------------------  -------------------
   Microsoft.KubernetesRuntime  RegistrationRequired  Registered
   ```

1. To install the Arc extension for MetalLB, obtain the AppID of the MetalLB extension resource provider, and then run the extension create command. You must run the following commands once per Arc Kubernetes cluster.

   Obtain the Application ID of the Arc extension by running `az ad sp list`. In order to run the following command, you must be a `user` member of your Azure tenant. For more information about user and guest membership, see [default user permissions in Microsoft Entra ID](/entra/fundamentals/users-default-permissions).

   ```azurecli
   $objID = az ad sp list --filter "appId eq '00001111-aaaa-2222-bbbb-3333cccc4444'" --query "[].id" --output tsv
   ```

   Once you have the `objID`, you can install the MetalLB Arc extension on your Kubernetes cluster. To run the following command, you must have the **Kubernetes extension contributor** role.

   ```azurecli
   az k8s-extension create --cluster-name $clusterName -g $rgName --cluster-type connectedClusters --extension-type microsoft.arcnetworking --config k8sRuntimeFpaObjectId=$objID -n arcnetworking
   ```

## Deploy MetalLB load balancer on your Kubernetes cluster

> [!IMPORTANT]
> 'BGP' mode isn't currently supported on multi-rack deployments.

You can now create a load balancer for your Kubernetes cluster remotely by running the `az k8s-runtime load-balancer create` command. This command creates a custom resource of type `IPAddressPool` in the namespace `kube-system`.

Configure the following variables before proceeding:

| Parameter | Description |
| --------- | ----------- |
| `$lbName` | The name of your MetalLB load balancer instance. |
| `$advertiseMode` | The mode for your MetalLB load balancer. Supported values are `ARP`. BGP mode isn't currently supported. |
| `$ipRange` | The IP range for the MetalLB load balancer in `ARP` mode. |

> [!IMPORTANT]
> The IP range you specify must be within the address space of your logical network and must not overlap with IP addresses already allocated to nodes or other infrastructure components. Plan for sufficient IP address capacity in your logical network before configuring the load balancer IP range.

```azurecli
az k8s-runtime load-balancer create --load-balancer-name $lbName --resource-uri subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Kubernetes/connectedClusters/$clusterName --addresses $ipRange --advertise-mode $advertiseMode
```

## Next steps

- Upgrade AKS clusters [Upgrade an Azure Kubernetes Service (AKS) cluster](cluster-upgrade.md)
