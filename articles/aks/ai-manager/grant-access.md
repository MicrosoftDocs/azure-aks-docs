---
title: Grant access to AI Manager (preview)
description: Choose and assign Azure roles for AI Manager management, model catalog access, inference, and Kubernetes objects.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: how-to
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
---

# Grant access to AI Manager (preview)

Use separate Azure roles for managing AI Manager resources, reading the model catalog, sending inference requests, and reading Kubernetes objects. Assign each role at the narrowest scope that meets the user's task.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- An Azure subscription with an AI Manager resource group, AI Manager, and namespace as needed for the access you're assigning.
- Azure CLI with access to the AI Manager CLI extension for the public preview, and permission to create role assignments at the target scope.
- The object ID of the user, group, or application that needs access. To find a user's object ID, run `az ad user show --id "<user-principal-name>" --query id --output tsv`. For a group, run `az ad group show --group "<group-name-or-id>" --query id --output tsv`. For an application, run `az ad sp show --id "<application-client-id>" --query id --output tsv` to get its service principal object ID.

The person creating a role assignment needs **User Access Administrator** or another role that can create role assignments at the target scope. **Azure AIManager Contributor** doesn't grant permission to assign roles.

## Choose a role and scope

| Task | Role | Recommended scope |
|---|---|---|
| Create and manage AI Manager resources | `Azure AIManager Contributor` | Resource group when creating an AI Manager. After creation, use the AI Manager or namespace scope to limit ongoing access. |
| Read AI Manager resources or list credentials and namespace API keys | `Azure AIManager User` | AI Manager or namespace |
| Read model catalog entries and calculate deployment costs | `Azure AIManager Model User` | Subscription scope, because the model catalog is scoped to a subscription and location |
| List namespace API keys and send inference requests | `Azure AIManager Inference User` | Namespace. Assigning it at the AI Manager scope grants access across its namespaces. |
| Read Kubernetes objects other than secrets, roles, and role bindings | `Azure AIManager RBAC Reader` | AI Manager or namespace |
| Read and write Kubernetes objects | `Azure AIManager RBAC Admin` | Use only for exceptional recovery; this role is broad. |

The roles differ in three ways that affect inference and credentials:

- **Inference data action:** For direct Microsoft Entra ID authentication, Azure RBAC checks the inference data action. **Azure AIManager Inference User** grants it. **Azure AIManager Contributor** and **Azure AIManager User** don't grant the inference data action.
- **Namespace API keys:** **Azure AIManager Contributor**, **Azure AIManager User**, and **Azure AIManager Inference User** can list namespace API keys. Anyone who obtains a namespace API key can use it for inference, even without the inference data action. Treat permission to list namespace API keys as access to inference credentials.
- **Kubernetes objects:** **Azure AIManager Inference User** doesn't grant general Kubernetes object or secret access.

Model catalog resources have a location-scoped ARM path under the subscription, not under a resource group or AI Manager. Assign **Azure AIManager Model User** at the subscription scope or another applicable parent scope. A role assignment only at the AI Manager or namespace scope doesn't grant catalog access.

## Set AI Manager scope variables

Set the names and subscription for the resources, and then create the scope IDs. Replace the principal object ID with the ID of the user, group, or application you're assigning.

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="<resource-group>"
export MANAGER_NAME="<ai-manager-name>"
export NAMESPACE_NAME="<namespace-name>"
export PRINCIPAL_OBJECT_ID="<principal-object-id>"

az account set --subscription "$SUBSCRIPTION_ID"

export RESOURCE_GROUP_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
export MANAGER_SCOPE="$RESOURCE_GROUP_SCOPE/providers/Microsoft.ContainerService/aiManagers/$MANAGER_NAME"
export NAMESPACE_SCOPE="$MANAGER_SCOPE/namespaces/$NAMESPACE_NAME"
```

## Assign an AI Manager role

Run these commands in the same shell session as [Set AI Manager scope variables](#set-ai-manager-scope-variables), or redefine the variables first. Set `--assignee-principal-type` to `User`, `Group`, or `ServicePrincipal` to match the principal that you're assigning.

For example, assign inference access to one namespace:

```azurecli-interactive
az role assignment create \
  --assignee-object-id "$PRINCIPAL_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Azure AIManager Inference User" \
  --scope "$NAMESPACE_SCOPE"
```

To let a user create and manage AI Manager resources in the resource group, assign **Azure AIManager Contributor** at the resource group scope:

```azurecli-interactive
az role assignment create \
  --assignee-object-id "$PRINCIPAL_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Azure AIManager Contributor" \
  --scope "$RESOURCE_GROUP_SCOPE"
```

To grant model catalog access and cost calculation, assign **Azure AIManager Model User** at the subscription scope:

```azurecli-interactive
az role assignment create \
  --assignee-object-id "$PRINCIPAL_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Azure AIManager Model User" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

## Verify an AI Manager role assignment

List assignments at the namespace scope, including assignments inherited from parent scopes:

```azurecli-interactive
az role assignment list \
  --assignee "$PRINCIPAL_OBJECT_ID" \
  --scope "$NAMESPACE_SCOPE" \
  --include-inherited \
  --output table
```

The output lists each role that the principal has at the namespace scope, including roles inherited from a parent scope. Confirm that the role you assigned appears in the `Role` column, and check the `Scope` column to see where it's assigned.

Azure role assignments aren't always effective immediately. If an operation still fails after you assign a role, see [Troubleshoot Azure RBAC](/azure/role-based-access-control/troubleshooting). For inference access, see [Connect an application to a model endpoint](./connect-to-endpoint.md).

## Next steps

- [Choose a model and estimate deployment cost](./estimate-cost.md).
- [View the AI Manager resource reference](./reference.md).
