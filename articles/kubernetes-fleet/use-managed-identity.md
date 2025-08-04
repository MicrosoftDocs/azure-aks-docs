---
title: Use a managed identity in Azure Kubernetes Fleet Manager
description: Learn how to use a system-assigned or user-assigned managed identity in Azure Kubernetes Fleet Manager
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: how-to
ms.date: 08/04/2025
# Customer intent: "As a DevOps engineer, I want to implement managed identities in Azure Kubernetes Service (AKS) so that I can securely authorize access to Azure resources without managing credentials manually."
---

# Use a managed identity in Azure Kubernetes Fleet Manager

Azure Kubernetes Fleet Manager uses a Microsoft Entra identity to access Azure resources like Azure Traffic Manager or to manage long-running background activities such as multi-cluster [auto-upgrade][fleet-auto-upgrade]. Managed identities for Azure resources are the recommended way to authorize access from a Fleet Manager to other Azure services.

You can use a managed identity to authorize access from a Fleet Manager to any service that supports Microsoft Entra authorization, without needing to manage credentials or include them in your code. You assign to the managed identity an Azure role-based access control (Azure RBAC) role to grant it permissions to a particular resource in Azure. For more information about Azure RBAC, see [What is Azure role\-based access control \(Azure RBAC\)?](/azure/role-based-access-control/overview).

This article shows how to enable the following types of managed identity on a new or existing Azure Kubernetes Fleet Manager:

* **System-assigned managed identity.** A system-assigned managed identity is associated with a single Azure resource, such as a Fleet Manager. It exists for the lifecycle of the Fleet Manager only.
* **User-assigned managed identity.** A user-assigned managed identity is a standalone Azure resource that a Fleet Manager can use to authorize access to other Azure services. It persists separately from the Fleet Manager and can be used by multiple Azure resources.

To learn more about managed identities, see [Managed identities for Azure resources](/entra/identity/managed-identities-azure-resources/overview).

## Overview

Fleet Manager uses a managed identity to request tokens from Microsoft Entra. These tokens are used to authorize access to other resources running in Azure. You can assign an Azure RBAC role to a managed identity to grant your Fleet Manager permissions to access specific resources. 

A managed identity can be either system-assigned or user-assigned. These two types of managed identities are similar in that you can use either type to authorize access to Azure resources from your Fleet Manager. The key difference is a system-assigned managed identity is associated with a single Azure resource like a Fleet Manager, while a user-assigned managed identity is a standalone Azure resource and can be shared across multiple Azure resources. For more information on the differences between types of managed identities, see **Managed identity types** in [Managed identities for Azure resources][managed-identity-resources-overview].

Both types of managed identities are managed by the Azure platform, so that you can authorize access from your applications without needing to provision or rotate any secrets. Azure manages the identity's credentials for you.

When you deploy a Fleet Manager you can choose to use a system-assigned or a user-assigned managed identity.

You can update an existing Fleet Manager to use a managed identity from an application service principal. You can also update an existing Fleet Manager to a different type of managed identity. If your Fleet Manager is already using a managed identity and the identity was changed, for example if you updated the Fleet Manager identity type from system-assigned to user-assigned, then there's a delay while control plane components switch to the new identity. Control plane components continue to use the old identity until its token expires. After the token is refreshed, they switch to the new identity. This process can take several hours.

## Before you begin

Make sure you have Azure CLI version 2.75.0 or later installed. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

Before running the Azure CLI examples in this article, set your subscription as the current active subscription by calling the [az account set][az-account-set] command and passing in your subscription ID.

```azurecli-interactive
az account set --subscription <subscription-id>
```

Also create an Azure resource group if you don't already have one by calling the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create \
    --name myResourceGroup \
    --location westus2
```

## Enable a system-assigned managed identity

A system-assigned managed identity is an identity that is associated with a Fleet Manager or another Azure resource. The system-assigned managed identity is tied to the lifecycle of the Fleet Manager. When the Fleet Manager is deleted, the system-assigned managed identity is also deleted.

Fleet Manager can use the system-assigned managed identity to authorize access to other resources running in Azure and execute long-running background processes. You can assign an Azure RBAC role to the system-assigned managed identity to grant the Fleet Manager permissions to access specific resources. For example, if your Fleet Manager needs to manage network resources, you can assign to the system-assigned managed identity an Azure RBAC role that grants those permissions.

### Enable a system-assigned managed identity on a new Fleet Manager

### [Azure portal](#tab/azure-portal)

When you create a new Fleet Manager in the Azure portal, a system-assigned managed identity is automatically created.

You can verify that the system-assigned managed identity is enabled by checking the **Identity** blade in the Fleet Manager's **Settings** section. The **System assigned** status should be **On** and the **Object (principal) ID** should be populated.

:::image type="content" source="./media/managed-identity/managed-identity-system-assigned.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal Identity pane showing the System assigned identity configuration." lightbox="./media/managed-identity/managed-identity-system-assigned.png":::

### [Azure CLI](#tab/cli)

Create a Fleet Manager using the [`az fleet create`][az-fleet-create] command, passing the `--enable-managed-identity` parameter to enable the system-assigned managed identity.

```azurecli-interactive
az fleet create \
    --resource-group myResourceGroup \
    --name myFleetName \
    --location westus2 \
    --enable-managed-identity
```

The command output indicates the identity type is **SystemAssigned** and includes the principal ID and tenant.

```output
{
  "eTag": "\"13003f4b-0000-1b00-0000-68900c3c0000\"",
  "hubProfile": null,
  "id": "/subscriptions/<subscription-id>/resourceGroups/myResourceGroup/providers/Microsoft.ContainerService/fleets/myFleetName",
  "identity": {
    "principalId": "<principal-id>",
    "tenantId": "<tenant-id>",
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "location": "westus2",
  "name": "flt-mgr-02",
  "provisioningState": "Succeeded",
  "resourceGroup": "myResourceGroup",
  "status": {
    "lastOperationError": null,
    "lastOperationId": "d31e866c-a3d3-46ab-8a97-094bc4672d35"
  },
  "systemData": {
    "createdAt": "2025-08-04T01:26:17.588030+00:00",
    "createdBy": "",
    "createdByType": "User",
    "lastModifiedAt": "2025-08-04T01:26:17.588030+00:00",
    "lastModifiedBy": "",
    "lastModifiedByType": "User"
  },
  "tags": null,
  "type": "Microsoft.ContainerService/fleets"
}
```

---
### Update an existing Fleet Manager to use a system-assigned managed identity

### [Azure portal](#tab/azure-portal)

You can manage the Fleet Manager managed identity using the **Identity** blade in the Fleet Manager's **Settings** section. 

1. Enable the system-assigned managed identity by setting the **System assigned** status to **On** and selecting **Save**. 

    :::image type="content" source="./media/managed-identity/managed-identity-enable-system-assigned-01.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal Identity pane showing system assigned identity disabled." lightbox="./media/managed-identity/managed-identity-enable-system-assigned-01.png":::

2. Select **Yes** on the confirmation dialog.

3. After a few moments the **System assigned** status changes to **On** and the **Object (principal) ID** should be populated.

    :::image type="content" source="./media/managed-identity/managed-identity-system-assigned.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal Identity pane showing the system assigned identity configuration." lightbox="./media/managed-identity/managed-identity-system-assigned.png":::

### [Azure CLI](#tab/cli)

To update an existing Fleet Manager to use a system-assigned managed identity, run the [az fleet update][az-fleet-update] command with the `--enable-managed-identity` parameter set to `true`.

```azurecli-interactive
az fleet update \
    --resource-group myResourceGroup \
    --name myFleetName \
    --enable-managed-identity true
```

The command output indicates the identity type is **SystemAssigned** and includes the principal ID and tenant.

```output
{
  "eTag": "\"13003f4b-0000-1b00-0000-68900c3c0000\"",
  "hubProfile": null,
  "id": "/subscriptions/<subscription-id>/resourceGroups/myResourceGroup/providers/Microsoft.ContainerService/fleets/myFleetName",
  "identity": {
    "principalId": "<principal-id>",
    "tenantId": "<tenant-id>",
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "location": "westus2",
  "name": "flt-mgr-02",
  "provisioningState": "Succeeded",
  "resourceGroup": "myResourceGroup",
  "status": {
    "lastOperationError": null,
    "lastOperationId": "d31e866c-a3d3-46ab-8a97-094bc4672d35"
  },
  "systemData": {
    "createdAt": "2025-08-04T01:26:17.588030+00:00",
    "createdBy": "",
    "createdByType": "User",
    "lastModifiedAt": "2025-08-04T01:26:17.588030+00:00",
    "lastModifiedBy": "",
    "lastModifiedByType": "User"
  },
  "tags": null,
  "type": "Microsoft.ContainerService/fleets"
}
```

---
### Add a role assignment for a system-assigned managed identity

You can assign an Azure RBAC role to the system-assigned managed identity to grant the Fleet Manager permissions on another Azure resource. Azure RBAC supports both built-in and custom role definitions that specify levels of permissions. For more information about assigning Azure RBAC roles, see [Steps to assign an Azure role](/azure/role-based-access-control/role-assignments-steps).

When you assign an Azure RBAC role to a managed identity, you must define the scope for the role. In general, it's a best practice to limit the scope of a role to the minimum privileges required by the managed identity. For more information on scoping Azure RBAC roles, see [Understand scope for Azure RBAC](/azure/role-based-access-control/scope-overview).

> [!NOTE]
> It can take up to 60 minutes for the permissions granted to your Fleet Manager's managed identity to propagate.

### [Azure portal](#tab/azure-portal)

1. Select **Azure role assignments** tab in the Fleet Manager's **Identity** blade. This opens the **Azure role assignments** pane.

      :::image type="content" source="./media/managed-identity/managed-identity-azure-role-assignment-01.png" alt-text="Screenshot of the Azure Role assignments pane." lightbox="./media/managed-identity/managed-identity-azure-role-assignment-01.png":::

2. Select **Add role assignment** to open the **Add role assignment** pane and enter:

    * **Scope** - select **Resource group**.
    
    * **Subscription** - choose the Azure subscription containing the resource group you want to use.
    
    * **Resource group** - select the resource group.
    
    * **Role** - choose the role you want to assign to the Fleet Manager's system-assigned managed identity (for example, **Network Contributor**).

      :::image type="content" source="./media/managed-identity/managed-identity-azure-role-assignment-02.png" alt-text="Screenshot of Add Role Assignment pane." lightbox="./media/managed-identity/managed-identity-azure-role-assignment-02.png":::

3. Select **Save** to assign the role to the Fleet Manager's system-assigned managed identity.

### [Azure CLI](#tab/cli)

1. Get the principal ID of the system-assigned managed identity

    To assign an Azure RBAC role to a Fleet Manager's system-assigned managed identity, you first need the principal ID for the managed identity. Get the principal ID for the Fleet Manager's system-assigned managed identity by calling the [`az fleet show`][az-fleet-show] command.
    
    ```azurecli-interactive
    # Get the principal ID for a system-assigned managed identity.
    CLIENT_ID=$(az fleet show \
        --name myFleetName \
        --resource-group myResourceGroup \
        --query identity.principalId \
        --output tsv)
    ```
    
2. Assign an Azure RBAC role to the system-assigned managed identity

    To grant a system-assigned managed identity permission to a resource in Azure, call the [`az role assignment create`][az-role-assignment-create] command to assign an Azure RBAC role to the managed identity.
    
    For example, assign the `Network Contributor` role on the custom resource group using the [`az role assignment create`][az-role-assignment-create] command. For the `--scope` parameter, provide the resource ID for the resource group for the Fleet Manager.
    
    ```azurecli-interactive
    az role assignment create \
        --assignee $CLIENT_ID \
        --role "Network Contributor" \
        --scope "<fleet-manager-resource-group-id>"
    ```

---

## Enable a user-assigned managed identity

A user-assigned managed identity is a standalone Azure resource. When you create a Fleet Manager with a user-assigned managed identity, the user-assigned managed identity resource must exist before Fleet Manager creation.

### Create a user-assigned managed identity

If you don't yet have a user-assigned managed identity resource, create one using the Azure portal or Azure CLI.

### [Azure portal](#tab/azure-portal)

Follow the steps in the [create a user-assigned managed identity documentation][user-assigned-docs].

### [Azure CLI](#tab/cli)

1. Create a user-assigned managed identity.

  If you don't yet have a user-assigned managed identity resource, create one using the [`az identity create`][az-identity-create] command.
  
  ```azurecli-interactive
  az identity create \
      --name myIdentity \
      --resource-group myResourceGroup
  ```

  Your output should resemble the following example output:
  
  ```output
  {                                  
    "clientId": "<client-id>",
    "clientSecretUrl": "<clientSecretUrl>",
    "id": "/subscriptions/<subscriptionid>/resourcegroups/myResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentity", 
    "location": "westus2",
    "name": "myIdentity",
    "principalId": "<principal-id>",
    "resourceGroup": "myResourceGroup",                       
    "tags": {},
    "tenantId": "<tenant-id>",
    "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
  }
```

2. Get the principal ID of the user-assigned managed identity

  To get the principal ID of the user-assigned managed identity, call [az identity show][az-identity-show] and query on the `principalId` property:
  
  ```azurecli-interactive
  CLIENT_ID=$(az identity show \
      --name myIdentity \
      --resource-group myResourceGroup \
      --query principalId \
      --output tsv)
  ```

3. Get the resource ID of the user-assigned managed identity

  To create a Fleet Manager with a user-assigned managed identity, you need the resource ID for the new managed identity. To get the resource ID of the user-assigned managed identity, call [az identity show][az-identity-show] and query on the `id` property:
  
  ```azurecli-interactive
  RESOURCE_ID=$(az identity show \
      --name myIdentity \
      --resource-group myResourceGroup \
      --query id \
      --output tsv)
  ```
  
---

### Assign an Azure RBAC role to the user-assigned managed identity

Before you create the Fleet Manager, add a role assignment for the managed identity.

> [!NOTE]
>
> It may take up to 60 minutes for the permissions granted to your Fleet Manager's managed identity to propagate.

### [Azure portal](#tab/azure-portal)

1. Open the managed identity in the Azure portal.

1. Select **Azure role assignments** tab in the left navigation. This opens the **Azure role assignments** pane.

      :::image type="content" source="./media/managed-identity/managed-identity-azure-role-assignment-01.png" alt-text="Screenshot of the Azure Role assignments pane." lightbox="./media/managed-identity/managed-identity-azure-role-assignment-01.png":::

2. Select **Add role assignment** to open the **Add role assignment** pane and enter:

    * **Scope** - select **Resource group**.
    
    * **Subscription** - choose the Azure subscription containing the resource group you want to use.
    
    * **Resource group** - select the resource group.
    
    * **Role** - choose the role you want to assign to the managed identity (for example, **Network Contributor**).

      :::image type="content" source="./media/managed-identity/managed-identity-azure-role-assignment-02.png" alt-text="Screenshot of Add Role Assignment pane." lightbox="./media/managed-identity/managed-identity-azure-role-assignment-02.png":::

3. Select **Save** to assign the role to the managed identity.

### [Azure CLI](#tab/cli)

Use the [`az role assignment create`][az-role-assignment-create] command to assign a role to the user-assigned managed identity.

The following example assigns the **Network Contributor** role to grant the identity permissions to access networking resources. The role assignment is scoped to the Fleet Manager resource group.

```azurecli-interactive
az role assignment create \
    --assignee $CLIENT_ID \
    --role "Network Contributor" \
    --scope "<fleet-manager-resource-group-id>"
```

---

### Create a Fleet Manager with the user-assigned managed identity

> [!NOTE]
> The USDOD Central, USDOD East, and USGov Iowa regions in Azure US Government cloud don't support creating a Fleet Manager with a user-assigned managed identity.

### [Azure portal](#tab/azure-portal)

You can't create a Fleet Manager with a user-assigned managed identity in the Azure portal. You can change the Fleet Manager identity type to user-assigned after the Fleet Manager is created, or use the Azure CLI.

### [Azure CLI](#tab/cli)

Create a Fleet Manager with the user-assigned managed identity by using the [`az fleet create`][az-fleet-create] command with the `--assign-identity` parameter. Pass in the resource ID for the user-assigned managed identity:

```azurecli-interactive
az fleet create \
    --resource-group myResourceGroup \
    --name myFleetName \
    --assign-identity $RESOURCE_ID
```

---

### Update an existing Fleet Manager to use a user-assigned managed identity

### [Azure portal](#tab/azure-portal)

You can't create a Fleet Manager with a user-assigned managed identity in the Azure portal. You can change the identity type to user-assigned after the Fleet Manager is created, or use the Azure CLI.

### [Azure CLI](#tab/cli)

To update an existing Fleet Manager to use a user-assigned managed identity, call the [`az fleet update`][az-fleet-update] command. Include the `--assign-identity` parameter and pass in the resource ID for the user-assigned managed identity:

```azurecli-interactive
az fleet update \
    --resource-group myResourceGroup \
    --name myFleetName \
    --enable-managed-identity \
    --assign-identity $RESOURCE_ID
```

The output for a successful Fleet Manager update to use a user-assigned managed identity should resemble the following example output:

```output
  "identity": {
    "principalId": null,
    "tenantId": null,
    "type": "UserAssigned",
    "userAssignedIdentities": {
      "/subscriptions/<subscriptionid>/resourcegroups/myResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentity": {
        "clientId": "<client-id>",
        "principalId": "<principal-id>"
      }
    }
  },
```
---

## Determine which type of managed identity a Fleet Manager is using

### [Azure portal](#tab/azure-portal)

You can check the Fleet Manager managed identity settings using the **Identity** blade in the Fleet Manager's **Settings** section.

Check both the **System assigned** and **User assigned** sections to determine which type of managed identity is enabled.

:::image type="content" source="./media/managed-identity/managed-identity-enable-system-assigned-01.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal Identity pane showing system assigned identity disabled." lightbox="./media/managed-identity/managed-identity-enable-system-assigned-01.png":::

### [Azure CLI](#tab/cli)

To determine which type of managed identity your existing Fleet Manager is using, call the [az fleet show][az-fleet-show] command and query for the identity's *type* property.

```azurecli
az fleet show \
    --name myFleetName \
    --resource-group myResourceGroup \
    --query identity.type \
    --output tsv       
```

The response is either **SystemAssigned** or **UserAssigned**.

---

## Limitations

* Moving or migrating a managed identity-enabled Fleet Manager to a different tenant isn't supported.

* Fleet Manager doesn't support the use of a system-assigned managed identity when using a custom private DNS zone.

## Next steps

* Use [Azure Resource Manager templates][aks-arm-template] to create a managed identity-enabled Fleet Manager.

<!-- LINKS - external -->
[aks-arm-template]: /azure/templates/microsoft.containerservice/fleets

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-identity-create]: /cli/azure/identity#az_identity_create
[az-identity-show]: /cli/azure/identity#az_identity_show
[fleet-auto-upgrade]: ./update-automation.md
[managed-identity-resources-overview]: /azure/active-directory/managed-identities-azure-resources/overview#managed-identity-types
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az_group_create
[az-fleet-create]: /cli/azure/fleet#az_fleet_create
[az-fleet-show]: /cli/azure/fleet#az_fleet_show
[az-fleet-update]: /cli/azure/fleet#az_fleet_update
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[user-assigned-docs]: /entra/identity/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azp#create-a-user-assigned-managed-identity