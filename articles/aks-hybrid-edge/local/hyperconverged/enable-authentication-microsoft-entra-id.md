---
title: Enable Microsoft Entra authentication for Kubernetes clusters
description: Learn how to enable Microsoft Entra ID on Azure Kubernetes Service with kubelogin and authenticate Azure users with credentials or managed roles.
author: davidsmatlak
ms.author: davidsmatlak 
ms.lastreviewed: 07/26/2024
ms.reviewer: srikantsarwa
ms.topic: how-to
ms.custom: hyperconverged
  - devx-track-azurecli
ms.date: 09/01/2026

# Intent: As an IT Pro, I need to learn how to enable Microsoft Entra ID authentication for Kubernetes clusters
# Keyword: Microsoft Entra ID
---

# Enable Microsoft Entra authentication for Kubernetes clusters

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

AKS Hybrid and Edge simplifies the authentication process with Microsoft Entra ID integration. For authorization, cluster administrators can configure Kubernetes role-based access control (Kubernetes RBAC) or Azure role-based access control (Azure RBAC) based on the directory group membership of the Microsoft Entra ID integration.

Microsoft Entra authentication is provided to AKS clusters with OpenID Connect. OpenID Connect is an identity layer built on top of the OAuth 2.0 protocol. For more information about OpenID Connect, see the [OpenID Connect documentation](/entra/identity-platform/v2-protocols-oidc). For more information about the Microsoft Entra integration flow, see the [Microsoft Entra documentation](concepts-security-access-identity.md#microsoft-entra-integration).

This article describes how to enable and use Microsoft Entra ID authentication for Kubernetes clusters.

## Before you begin

- This configuration requires that you have a Microsoft Entra group for your cluster. This group is registered as an admin group on the cluster to grant admin permissions. If you don't have an existing Microsoft Entra group, you can create one using the [`az ad group create`](/cli/azure/ad/group#az_ad_group_create) command.
- To create or update a Kubernetes cluster, you need the **Azure Kubernetes Service Arc Contributor** role.
- To access the Kubernetes cluster directly using the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command and download the kubeconfig file, you need the **Microsoft.HybridContainerService/provisionedClusterInstances/listUserKubeconfig/action**, which is included in the **Azure Kubernetes Service Arc Cluster User** role permission.
- Once your Microsoft Entra group is enabled with admin access to your AKS cluster, this Microsoft Entra group can interact with Kubernetes clusters. You must install [**kubectl**](https://kubernetes.io/docs/tasks/tools/) and [**kubelogin**](https://azure.github.io/kubelogin/install.html).
- Integration can't be disabled once added. You can still use [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) to update the `aad-admin-group-object-ids` if needed.

## Enable Microsoft Entra authentication for Kubernetes cluster

### Create a new cluster with Microsoft Entra authentication

1. Create an Azure resource group using the [`az group create`](/cli/azure/group#az-group-create) command:

   ```azurecli
   az group create --name $resource_group --location centralus
   ```

1. Create an AKS cluster and enable admin access for your Microsoft Entra group using the `--aad-admin-group-object-ids` parameter in the [`az aksarc create`](/cli/azure/aksarc#az-aksarc-create) command:

    ```azurecli
    az aksarc create -n $aks_cluster_name -g $resource_group --custom-location $customlocationID --vnet-ids $logicnetId --aad-admin-group-object-ids $aadgroupID --generate-ssh-keys
    ```

### Use an existing cluster with Microsoft Entra authentication

Enable Microsoft Entra authentication on your existing Kubernetes cluster using the `--aad-admin-group-object-ids` parameter in the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command. Make sure to set your admin group to retain access on your cluster:

  ```azurecli
  az aksarc update -n $aks_cluster_name -g $resource_group --aad-admin-group-object-ids $aadgroupID
  ```

## Access your Microsoft Entra-enabled cluster

1. Get the user credentials to access your cluster using the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command. You need the **Microsoft.HybridContainerService/provisionedClusterInstances/listUserKubeconfig/action**, which is included in the **Azure Kubernetes Service Arc Cluster User** role permission:

   ```azurecli
   az aksarc get-credentials --resource-group $resource_group --name $aks_cluster_name
   ```

1. View the nodes in the cluster with the `kubectl get nodes` command and follow the instructions to sign in. You need to be in the Microsoft Entra ID group specified with the AKS cluster when you pass the `--aad-admin-group-object-ids $aadgroupID` parameter:

   ```azurecli
   kubectl get nodes
   ```

## Next steps

- [Access and identity options for AKS Hybrid and Edge](concepts-security-access-identity.md)
- [Microsoft Entra integration with Kubernetes RBAC](kubernetes-rbac-local.md)
- [Use Azure role-based access control (RBAC) for Kubernetes authorization](azure-rbac-local.md)
- Help to protect your cluster in other ways by following the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).