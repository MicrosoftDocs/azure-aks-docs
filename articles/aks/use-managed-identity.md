---
title: Use a managed identity in Azure Kubernetes Service (AKS)
description: Learn how to use a system-assigned, user-assigned, or pre-created kubelet managed identity in Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - ignite-2023
ms.date: 06/07/2024
zone_pivot_groups: use-managed-identity
# Customer intent: "As a DevOps engineer, I want to implement managed identities in Azure Kubernetes Service (AKS) so that I can securely authorize access to Azure resources without managing credentials manually."
---

# Use a managed identity in Azure Kubernetes Service (AKS)

This article provides step-by-step instructions on how to enable and use a system-assigned, user-assigned, or pre-created kubelet managed identity in Azure Kubernetes Service (AKS).

## AKS managed identity prerequisites

- Read the [Overview of managed identities in Azure Kubernetes Service (AKS)](managed-identity-overview.md) to understand the different types of managed identities available in AKS and how you can use them to securely access Azure resources.
- Before running the examples in this article, set your subscription as the current active subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription <subscription-id>
    ```

- Create an Azure resource group if you don't already have one by calling the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create \
        --name <resource-group-name> \
        --location <location>
    ```

### Azure CLI version minimum requirements

- Make sure you have Azure CLI version 2.23.0 or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- To [use a pre-created kubelet managed identity][use-a-pre-created-kubelet-managed-identity], you need Azure CLI version 2.26.0 or later installed.
- To update an existing cluster to use a [system-assigned managed identity][update-system-assigned-managed-identity-on-an-existing-cluster] or [a user-assigned managed identity][update-user-assigned-managed-identity-on-an-existing-cluster], you need Azure CLI version 2.49.0 or later installed.

### Limitations

- Moving or migrating a managed identity-enabled cluster to a different tenant isn't supported.
- If the cluster has Microsoft Entra pod-managed identity (`aad-pod-identity`) enabled, Node-Managed Identity (NMI) pods modify the iptables of the nodes to intercept calls to the Azure Instance Metadata (IMDS) endpoint. This configuration means any request made to the IMDS endpoint is intercepted by NMI, even if a particular pod doesn't use `aad-pod-identity`.

    The AzurePodIdentityException custom resource definition (CRD) can be configured to specify that requests to the IMDS endpoint that originate from a pod matching labels defined in the CRD should be proxied without any processing in NMI. Exclude the system pods with the `kubernetes.azure.com/managedby: aks` label in *kube-system* namespace in `aad-pod-identity` by configuring the AzurePodIdentityException CRD. For more information, see [Use Microsoft Entra pod-managed identities in Azure Kubernetes Service](use-azure-ad-pod-identity.md).
  
    To configure an exception, install the [mic-exception YAML](https://github.com/Azure/aad-pod-identity/blob/master/deploy/infra/mic-exception.yaml).

- AKS doesn't support the use of a system-assigned managed identity when using a custom private DNS zone.
- The USDOD Central, USDOD East, and USGov Iowa regions in Azure US Government cloud don't support creating a cluster with a user-assigned managed identity.

:::zone pivot="pre-created-kubelet"

- A pre-created kubelet managed identity must be a user-assigned managed identity.
- The China East and China North regions in Microsoft Azure operated by 21Vianet aren't supported.

:::zone-end

> [!NOTE]
>
> Keep the following information in mind when updating your cluster:
>
> - An update only works if there's a VHD update to consume. If you're running the latest VHD, you need to wait until the next VHD is available in order to perform the update.
>
> - The Azure CLI ensures your addon's permission is correctly set after migrating. If you're not using the Azure CLI to perform the migrating operation, you need to handle the addon identity's permission by yourself. For an example using an Azure Resource Manager (ARM) template, see [Assign Azure roles using ARM templates](/azure/role-based-access-control/role-assignments-template).
>
> - If your cluster was using `--attach-acr` to pull from images from Azure Container Registry (ACR), you need to run the `az aks update --resource-group <resource-group-name> --name <aks-cluster-name> --attach-acr <acr-resource-id>` command after updating your cluster to let the newly-created kubelet used for managed identity get the permission to pull from ACR. Otherwise, you won't be able to pull from ACR after the update.

:::zone pivot="system-assigned"

## Enable a system-assigned managed identity on an AKS cluster

### Enable a system-assigned managed identity on a new AKS cluster

A system-assigned managed identity is enabled by default when you create a new AKS cluster.

- Create an AKS cluster using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --generate-ssh-keys
    ```

### Update an existing AKS cluster to use a system-assigned managed identity

- Update an existing AKS cluster from a service principal to a system-assigned managed identity using the [`az aks update`][az-aks-update] command with the `--enable-managed-identity` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --enable-managed-identity
    ```

    After you update the cluster to use a system-assigned managed identity instead of a service principal, the control plane and pods use the system-assigned managed identity for authorization when accessing other services in Azure. Kubelet continues using a service principal until you also upgrade your agent pool. You can use the `az aks nodepool upgrade --resource-group <resource-group-name> --cluster-name <aks-cluster-name> --name <node-pool-name> --node-image-only` command on your nodes to update to a managed identity. A node pool upgrade causes downtime for your AKS cluster as the nodes in the node pools are cordoned, drained, and reimaged.

## Get the principal ID of a system-assigned managed identity

- Get the principal ID for the cluster's system-assigned managed identity using the [`az aks show`](/cli/azure/identity#az-identity-show) command.

    ```azurecli-interactive
    CLIENT_ID=$(az aks show \
        --name <aks-cluster-name> \
        --resource-group <resource-group-name> \
        --query identity.principalId \
        --output tsv)
    ```

## Add a role assignment for a system-assigned managed identity

- Assign an Azure RBAC role to the system-assigned managed identity using the [`az role assignment create`][az-role-assignment-create] command.

    For a VNet, attached Azure disk, static IP address, or route table outside the default worker node resource group, you need to assign the `Network Contributor` role on the custom resource group.

    The following example assigns the **Network Contributor** role to the system-assigned managed identity. The role assignment is scoped to the resource group that contains the VNet.

    ```azurecli-interactive
    az role assignment create \
        --assignee <client-id> \
        --role "Network Contributor" \
        --scope <custom-resource-group-id>
    ```

    > [!NOTE]
    > It can take up to 60 minutes for the permissions granted to your cluster's managed identity to propagate.

:::zone-end

:::zone pivot="user-assigned"

## Create a user-assigned managed identity

- If you don't yet have a user-assigned managed identity resource, create one using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create \
        --name <identity-name> \
        --resource-group <resource-group-name>
    ```

    Your output should resemble the following example output:
  
    ```output
    {                                  
      "clientId": "<client-id>",
      "clientSecretUrl": "<clientSecretUrl>",
      "id": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>",
      "location": "<location>",
      "name": "<identity-name>",
      "principalId": "<principal-id>",
      "resourceGroup": "<resource-group-name>",
      "tags": {},
      "tenantId": "<tenant-id>",
      "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
    }
    ```

## Get the principal ID of the user-assigned managed identity

- Get the principal ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    CLIENT_ID=$(az identity show \
        --name <identity-name> \
        --resource-group <resource-group-name> \
        --query principalId \
        --output tsv)
    ```

## Get the resource ID of the user-assigned managed identity

- Get the resource ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    RESOURCE_ID=$(az identity show \
        --name <identity-name> \
        --resource-group <resource-group-name> \
        --query id \
        --output tsv)
    ```

## Assign an Azure RBAC role to the user-assigned managed identity

- Add a role assignment for the user-assigned managed identity using the [`az role assignment create`][az-role-assignment-create] command.

    The following example assigns the **Key Vault Secrets User** role to the user-assigned managed identity to grant it permissions to access secrets in a key vault. The role assignment is scoped to the key vault resource:

    ```azurecli-interactive
    az role assignment create \
        --assignee <client-id> \
        --role "Key Vault Secrets User" \
        --scope "<keyvault-resource-id>"
    ```

    > [!NOTE]
    > It can take up to 60 minutes for the permissions granted to your cluster's managed identity to propagate.

## Enable a user-assigned managed identity on an AKS cluster

### Enable a user-assigned managed identity on a new AKS cluster

- Create an AKS cluster with the user-assigned managed identity using the [`az aks create`][az-aks-create] command. Include the `--assign-identity` parameter and pass in the resource ID for the user-assigned managed identity:

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --network-plugin azure \
        --vnet-subnet-id <vnet-subnet-id> \
        --dns-service-ip 10.2.0.10 \
        --service-cidr 10.2.0.0/24 \
        --assign-identity $RESOURCE_ID \
        --generate-ssh-keys
    ```

### Update an existing cluster to use a user-assigned managed identity

- Update an existing cluster to use a user-assigned managed identity using the [`az aks update`][az-aks-update] command. Include the `--assign-identity` parameter and pass in the resource ID for the user-assigned managed identity:

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --enable-managed-identity \
        --assign-identity $RESOURCE_ID
    ```

    The output for a successful cluster update to use a user-assigned managed identity should resemble the following example output:

    ```output
      "identity": {
        "principalId": null,
        "tenantId": null,
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>": {
            "clientId": "<client-id>",
            "principalId": "<principal-id>"
          }
        }
      },
    ```

    > [!NOTE]
    > Migrating a managed identity for the control plane from system-assigned to user-assigned doesn't result in any downtime for control plane and agent pools. Control plane components continue to the old system-assigned identity for up to several hours, until the next token refresh.

:::zone-end

## Determine which type of managed identity a cluster is using

- Verify which type of managed identity your cluster is using with the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show \
        --name <aks-cluster-name> \
        --resource-group <resource-group-name> \
        --query identity.type \
        --output tsv       
    ```

    If the cluster is using a managed identity, the value of the _type_ property will be either **SystemAssigned** or **UserAssigned**.

    If the cluster is using a service principal, the value of the _type_ property will be null. Consider upgrading your cluster to use a managed identity.

:::zone pivot="pre-created-kubelet"

## Create a kubelet managed identity

- If you don't have a kubelet managed identity, create one using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create \
        --name <kubelet-identity-name> \
        --resource-group <resource-group-name>
    ```

    Your output should resemble the following example output:

    ```output
    {
      "clientId": "<client-id>",
      "clientSecretUrl": "<clientSecretUrl>",
      "id": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>",
      "location": "<location>",
      "name": "<kubelet-identity-name>",
      "principalId": "<principal-id>",
      "resourceGroup": "<resource-group-name>",
      "tags": {},
      "tenantId": "<tenant-id>",
      "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
    }
    ```

## Assign an RBAC role to the kubelet managed identity

- Assign the `acrpull` role on the kubelet managed identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create \
        --assignee <kubelet-client-id> \
        --role "acrpull" \
        --scope "<acr-registry-id>"
    ```

## Enable a kubelet managed identity on an AKS cluster

### Enable a kubelet managed identity on a new AKS cluster

- Create an AKS cluster with your existing identities using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --network-plugin azure \
        --vnet-subnet-id <vnet-subnet-id> \
        --dns-service-ip 10.2.0.10 \
        --service-cidr 10.2.0.0/24 \
        --assign-identity <identity-resource-id> \
        --assign-kubelet-identity <kubelet-identity-resource-id> \
        --generate-ssh-keys
    ```

    A successful AKS cluster creation using a kubelet managed identity should result in output similar to the following:

    ```output
      "identity": {
        "principalId": null,
        "tenantId": null,
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>": {
            "clientId": "<client-id>",
            "principalId": "<principal-id>"
          }
        }
      },
      "identityProfile": {
        "kubeletidentity": {
          "clientId": "<client-id>",
          "objectId": "<object-id>",
          "resourceId": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>"
        }
      },
    ```

### Update an existing cluster to use a kubelet managed identity

To update an existing cluster to use the kubelet managed identity, first get the current control plane managed identity for your AKS cluster.

> [!WARNING]
> Updating the kubelet managed identity upgrades your AKS cluster's node pools, make sure you have the right availability configurations, such as Pod Disruption Budgets, configured before executing this to avoid workload disruption or execute this during a maintenance window.

1. Confirm your AKS cluster is using the user-assigned managed identity using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --query "servicePrincipalProfile"
    ```

    If your cluster is using a managed identity, the output shows `clientId` with a value of **msi**. A cluster using a service principal shows an object ID. For example:

    ```output
    # The cluster is using a managed identity.
    {
      "clientId": "msi"
    }
    ```

1. After confirming your cluster is using a managed identity, find the managed identity's resource ID using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --query "identity"
    ```

    For a user-assigned managed identity, your output should look similar to the following example output:

    ```output
    {
      "principalId": null,
      "tenantId": null,
      "type": "UserAssigned",
      "userAssignedIdentities": <identity-resource-id>
          "clientId": "<client-id>",
          "principalId": "<principal-id>"
    },
    ```

1. Update your cluster with your existing identities using the [`az aks update`][az-aks-update] command. Provide the resource ID of the user-assigned managed identity for the control plane for the `assign-identity` argument. Provide the resource ID of the kubelet managed identity for the `assign-kubelet-identity` argument.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --enable-managed-identity \
        --assign-identity <identity-resource-id> \
        --assign-kubelet-identity <kubelet-identity-resource-id>
    ```

    Your output for a successful cluster update using your own kubelet managed identity should resemble the following example output:

    ```output
      "identity": {
        "principalId": null,
        "tenantId": null,
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>": {
            "clientId": "<client-id>",
            "principalId": "<principal-id>"
          }
        }
      },
      "identityProfile": {
        "kubeletidentity": {
          "clientId": "<client-id>",
          "objectId": "<object-id>",
          "resourceId": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>"
        }
      },
    ```

## Get the properties of the kubelet managed identity

- Get the properties of the kubelet managed identity using the [`az aks show`][az-aks-show]  command and query on the `identityProfile.kubeletidentity` property.

    ```azurecli-interactive
    az aks show \
        --name <aks-cluster-name> \
        --resource-group <resource-group-name> \
        --query "identityProfile.kubeletidentity"
    ```

:::zone-end

## Next steps

- Use [Azure Resource Manager templates][aks-arm-template] to create a managed identity-enabled cluster.
- Learn how to [use kubelogin][kubelogin-authentication] for all supported Microsoft Entra authentication methods in AKS.

<!-- LINKS - external -->
[aks-arm-template]: /azure/templates/microsoft.containerservice/managedclusters

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-identity-create]: /cli/azure/identity#az_identity_create
[az-identity-show]: /cli/azure/identity#az_identity_show
[use-a-pre-created-kubelet-managed-identity]: use-managed-identity.md#create-a-kubelet-managed-identity
[update-system-assigned-managed-identity-on-an-existing-cluster]: use-managed-identity.md#update-an-existing-aks-cluster-to-use-a-system-assigned-managed-identity
[update-user-assigned-managed-identity-on-an-existing-cluster]: use-managed-identity.md#update-an-existing-cluster-to-use-a-user-assigned-managed-identity
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az_group_create
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-aks-show]: /cli/azure/aks#az_aks_show
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[kubelogin-authentication]: kubelogin-authentication.md
