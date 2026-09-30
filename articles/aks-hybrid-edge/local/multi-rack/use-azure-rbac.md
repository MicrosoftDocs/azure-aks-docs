---
title: Use Azure RBAC for AKS on Azure Local for multi-rack deployments
description: Learn how to enable and use Azure role-based access control (RBAC) with Microsoft Entra ID to authorize Kubernetes API requests on AKS on Azure Local for multi-rack deployments.
ms.topic: how-to
ms.custom: devx-track-azurecli, multi-rack
ms.date: 09/01/2026
ms.author: rickbartra
author: rickbartra
---

# Use Azure RBAC for AKS on Azure Local for multi-rack deployments

This article describes how to enable Azure role-based access control (RBAC) on an AKS on Azure Local for multi-rack deployments cluster. Infrastructure administrators can use Azure role-based access control (Azure RBAC) to control who can access the _kubeconfig_ file and the permissions they have. Kubernetes operators can interact with Kubernetes clusters using the **kubectl** tool based on the given permissions. By using Azure RBAC, administrators can authorize Kubernetes API requests by using Microsoft Entra ID identities and Azure role assignments instead of managing Kubernetes `RoleBinding` and `ClusterRoleBinding` resources manually.

For a conceptual overview of the underlying technology, see [Azure RBAC for Azure Arc-enabled Kubernetes](/azure/azure-arc/kubernetes/azure-rbac).

> [!NOTE]
> The Azure Arc article is informational only. Configuration steps such as installing the authentication and authorization webhook and wiring the Kubernetes API server are performed automatically when you enable Azure RBAC on a multi-rack cluster. This article covers the customer-facing steps you're responsible for.

## What is Azure RBAC for Kubernetes?

Azure RBAC for Kubernetes lets you authorize Kubernetes API calls&mdash;for example, `kubectl get pods` or `kubectl apply`&mdash;by using **Microsoft Entra ID** users and groups together with **Azure role assignments** scoped to the connected cluster resource.

When a request reaches the Kubernetes API server, the server forwards the user identity and requested action to Azure. Azure decides whether the caller is granted an Azure role that permits the action and returns the result. If the caller is permitted, the request is allowed; otherwise, it's denied.

This capability provides a single, consolidated way to manage cluster access&mdash;the Azure portal or the Azure CLI&mdash;using the same identities you already use for the rest of Azure.

## Prerequisites

Before you enable Azure RBAC on a multi-rack cluster, make sure you have:
> [!IMPORTANT]
> You can only enable Azure RBAC when you **create** the cluster. Enabling or disabling of Azure RBAC to an existing multi-rack cluster is not allowed.
- A Microsoft Entra ID tenant.
- The Azure CLI, with the `aksarc` and `connectedk8s` extensions installed. If you need to install or upgrade Azure CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The **User Access Administrator** role at the resource group (or higher) scope where the cluster is created. The built-in **Owner** role also satisfies this requirement.
- To use kubectl with the Azure AD Admin Group, you don't need any specific role, but you must ensure you are in one of the groups in the **add-admin-group** list of the connected cluster resource.

- If your cluster connects to Azure through an outbound HTTP proxy, allow the endpoint `*.obo.arc.azure.com:8084` through the proxy.

## Step 1: Enable Azure RBAC

Enable Azure RBAC when you create the AKS Arc cluster by passing the `--enable-azure-rbac` flag to `az aksarc create`:

```azurecli
az aksarc create \
  --name <cluster-name> \
  --resource-group <resource-group> \
  --custom-location <custom-location-id> \
  --enable-azure-rbac
  # ... plus your usual networking and agent pool flags
```

Optionally, pre-seed Microsoft Entra ID groups as cluster administrators by passing `--aad-admin-group-object-ids`. For more information, see [Admin group access (optional)](#admin-group-access-optional).

> [!IMPORTANT]
> You can only enable Azure RBAC when you **create** the cluster. Enabling or disabling of Azure RBAC to an existing multi-rack cluster is not allowed.

### What to expect during cluster creation

Enabling Azure RBAC adds extra setup work to cluster bring-up: the authorization webhook is installed and the Kubernetes API server is configured to consult it. As a result, **multi-rack cluster creation could require extra time** when `--enable-azure-rbac` is set. This is expected and only affects initial cluster creation; steady-state operation is unaffected.

## Step 2: Create role assignments for users to access the cluster

Use the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command to create role assignments.

The following different user personas need to be assigned Azure roles via Azure RBAC for the AKS Arc cluster to function end-to-end:

| Persona | Role | Scope |
| --- | --- | --- |
| The user (or service principal) creating the cluster | **User Access Administrator** (or **Owner**) | Resource group or higher |
| The connected cluster's system-assigned managed identity | **Connected Cluster Managed Identity CheckAccess Reader** | Connected cluster resource |
| End users or groups of the cluster | **Azure Arc Enabled Kubernetes Cluster User Role** *and* an Azure Arc Kubernetes role (for example, **Azure Arc Kubernetes Viewer**) | Connected cluster resource |

The following sections cover the second and third identities. The first identity is handled in the [Prerequisites](#prerequisites) section.

### Assign the role for the connected cluster managed identity

Each connected cluster has its own system-assigned managed identity. For Azure RBAC to work, that identity needs the **Connected Cluster Managed Identity CheckAccess Reader** role on the connected cluster resource. This role lets the cluster ask Azure "is principal X allowed to do action Y on this cluster?" on every Kubernetes API call.

To assign the role, run the following commands:

```azurecli
SUBSCRIPTION="<your-subscription-id>"
RESOURCE_GROUP="<your-resource-group>"
CLUSTER_NAME="<your-cluster-name>"
SCOPE="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Kubernetes/connectedClusters/${CLUSTER_NAME}"

CLUSTER_MSI=$(az connectedk8s show -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" \
  --query "identity.principalId" -o tsv)

az role assignment create \
  --role "Connected Cluster Managed Identity CheckAccess Reader" \
  --assignee-object-id "$CLUSTER_MSI" \
  --assignee-principal-type ServicePrincipal \
  --scope "$SCOPE"
```

> [!IMPORTANT]
> This assignment must be in place for Azure RBAC to function. Without it, `kubectl` calls fail with permission errors even for users who are granted Kubernetes roles.

### Assign roles to end users

To use the cluster, an end user (or group) needs **two** Azure role assignments on the connected cluster resource:

- **Azure Arc Enabled Kubernetes Cluster User Role**: required to connect to the cluster through `az connectedk8s proxy`. For more information, see [Connect to the cluster](#step-3-connect-to-the-cluster).
- An **Azure Arc Kubernetes** role that grants Kubernetes permissions, for example **Azure Arc Kubernetes Viewer** for read-only access. For the full list of built-in roles and what each one grants, see [Azure RBAC for Azure Arc-enabled Kubernetes](/azure/azure-arc/kubernetes/azure-rbac).

```azurecli
USER_OBJECT_ID="<entra-user-or-group-object-id>"

# Lets the user open a connectedk8s proxy session against the cluster.
az role assignment create \
  --role "Azure Arc Enabled Kubernetes Cluster User Role" \
  --assignee "$USER_OBJECT_ID" \
  --scope "$SCOPE"

# Grants Kubernetes-level read access through Azure RBAC.
az role assignment create \
  --role "Azure Arc Kubernetes Viewer" \
  --assignee "$USER_OBJECT_ID" \
  --scope "$SCOPE"
```

> [!NOTE]
> If you only assign the Cluster User Role, the user can connect but every API call is denied. If you only assign the Kubernetes role, the user can't open the proxy in the first place.

### Create custom role definitions

Create your own role definitions to use in role assignments when the built-in roles don't grant the exact set of permissions you want.

The following example shows a role definition that allows a user to only read deployments. For the full list of data actions you can use to construct a role definition, see [Microsoft.Kubernetes operations](/azure/role-based-access-control/resource-provider-operations#microsoftkubernetes). For more information about creating a custom role, see [Steps to create a custom role](/azure/role-based-access-control/custom-roles#steps-to-create-a-custom-role).

To create your own custom role definition, copy the following JSON object into a file called `deploy-view.json`. Replace the `<YOUR SUBSCRIPTION ID>` placeholder with your actual subscription ID. The custom role uses a single data action and lets the assignee view all deployments in the scope (cluster or namespace) where the role assignment is created.

```json
{
    "Name": "AKS Arc Deployment Reader",
    "Description": "Lets you view all deployments in cluster/namespace.",
    "Actions": [],
    "NotActions": [],
    "DataActions": [
        "Microsoft.Kubernetes/connectedClusters/apps/deployments/read"
    ],
    "NotDataActions": [],
    "assignableScopes": [
        "/subscriptions/<YOUR SUBSCRIPTION ID>"
    ]
}
```

For more information about custom roles and how to author them, see [Azure custom roles](/azure/role-based-access-control/custom-roles).

Create the role definition with the [`az role definition create`](/cli/azure/role/definition#az-role-definition-create) command, setting the `--role-definition` parameter to the `deploy-view.json` file you created in the previous step:

```azurecli
az role definition create --role-definition @deploy-view.json
```

Assign the role definition to a user or other identity with the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command:

```azurecli
az role assignment create \
  --role "AKS Arc Deployment Reader" \
  --assignee "$USER_OBJECT_ID" \
  --scope "$SCOPE"
```

## Step 3: Connect to the cluster

You connect to an Azure RBAC-enabled cluster the same way as any other multi-rack cluster, using either `az aksarc get-credentials` (direct mode) or `az connectedk8s proxy` (proxy mode). For the full connection steps and how to install `kubectl`, see [Connect to the cluster](resource-manager-quickstart.md#step-7-connect-to-the-cluster).

The following details are specific to Azure RBAC:

- **Authentication and authorization.** The first time you run a `kubectl` command, you're prompted to sign in with Microsoft Entra ID, and the API server authorizes the request based on your Azure role assignments (for example, **Azure Arc Kubernetes Viewer**).
- **Admin kubeconfig bypasses Azure RBAC.** If you pass the `--admin` flag to `az aksarc get-credentials`, the command downloads a certificate-based admin kubeconfig that contains secrets and bypasses Microsoft Entra ID sign-in and Azure RBAC. Store it securely and rotate it periodically. For more information, see [Retrieve certificate-based admin kubeconfig in AKS Arc](../hyperconverged/retrieve-admin-kubeconfig.md).

### Admin group access (optional)

You can optionally pre-seed one or more Microsoft Entra ID groups as cluster administrators by passing `--aad-admin-group-object-ids` (comma-separated group object IDs) at cluster creation time. The operator binds those groups to the Kubernetes `cluster-admin` role via a `ClusterRoleBinding`, so their members can perform any action on the cluster. Their requests are authorized by in-cluster Kubernetes RBAC before the Azure RBAC check is consulted.

If you don't specify `--aad-admin-group-object-ids`, the cluster is still fully functional. Administrative access is then granted entirely through Azure role assignments (for example, **Azure Arc Kubernetes Cluster Admin**) on the connected cluster resource. For more information, see [Assign roles to end users](#assign-roles-to-end-users).

> [!WARNING]
> Limit admin group membership to break-glass and day-2 administration scenarios. These members bypass Azure RBAC entirely.

## Step 4: Audit access decisions

Two sources of logs record Azure RBAC activity inside the cluster:

- **Kubernetes audit logs** on the control-plane nodes: These logs capture all API requests, including the username, action, resource, and decision.
- **`guard` pod logs** in the `azure-arc` namespace: This component forwards each authentication and authorization decision to Azure. These logs show the per-request CheckAccess calls and their results.

To view recent guard activity, run:

```bash
kubectl logs -n azure-arc deploy/guard
```

Use these logs to diagnose and troubleshoot access-related problems.

## Troubleshoot common issues

| Symptom | Likely cause |
| --- | --- |
| `kubectl` returns 403 for every call. | The user has no Kubernetes-level role (for example, `Azure Arc Kubernetes Viewer`) on the cluster scope, or the connected cluster managed identity is missing the **Connected Cluster Managed Identity CheckAccess Reader** role. |
| `az connectedk8s proxy` fails to start or hangs at authentication. | The user is missing the **Azure Arc Enabled Kubernetes Cluster User Role** on the cluster scope. |
| All access checks fail with internal errors in `guard` logs. | The connected cluster managed identity doesn't have **Connected Cluster Managed Identity CheckAccess Reader** on the cluster. Rerun the role assignment from [Assign the role for the connected cluster managed identity](#assign-the-role-for-the-connected-cluster-managed-identity). |
| A user can do anything in the cluster regardless of Azure role assignments. | The user is a member of one of the `--aad-admin-group-object-ids` groups. See [Admin group access (optional)](#admin-group-access-optional). |
| Cluster create succeeded, but `--enable-azure-rbac` doesn't appear to be active. | Azure RBAC can only be enabled at create time. Verify that the original `az aksarc create` call included `--enable-azure-rbac`. If not, re-create the cluster. |

For deeper investigation, check the `guard` pod logs and the kube-apiserver audit logs as described in [Audit access decisions](#step-4-audit-access-decisions).

## Known limitations

- **Enable-only at creation.** Azure RBAC can't be turned on or off on an existing multi-rack cluster. To change this setting, you must create a new cluster.
- **Admin group flag is optional.** Pre-seeding cluster admins via `--aad-admin-group-object-ids` is supported but not required. For more information, see [Admin group access (optional)](#admin-group-access-optional).

## End-to-end example

The following walkthrough creates an Azure RBAC multi-rack cluster, assigns the required roles to the cluster managed identity and to a user, and verifies that the user can reach the cluster through the connected cluster proxy.

1. Set the inputs and select the subscription:

   ```azurecli
   SUBSCRIPTION="<your-subscription-id>"
   RESOURCE_GROUP="<your-resource-group>"
   CLUSTER_NAME="<your-cluster-name>"
   CUSTOM_LOCATION_ID="<your-custom-location-resource-id>"
   ADMIN_GROUP_OBJECT_ID="<entra-group-object-id-for-cluster-admins>"   # optional
   USER_OBJECT_ID="<entra-user-or-group-object-id-to-grant-access-to>"

   az account set --subscription "$SUBSCRIPTION"

   SCOPE="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Kubernetes/connectedClusters/${CLUSTER_NAME}"
   ```

1. Create the cluster with Azure RBAC enabled (omit `--aad-admin-group-object-ids` if you don't want a preseeded admin group):

   ```azurecli
   az aksarc create \
     --name "$CLUSTER_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --custom-location "$CUSTOM_LOCATION_ID" \
     --enable-azure-rbac \
     --aad-admin-group-object-ids "$ADMIN_GROUP_OBJECT_ID"
     # ... plus your usual networking and agent pool flags
   ```

1. Grant the connected cluster managed identity the **CheckAccess Reader** role:

   ```azurecli
   CLUSTER_MSI=$(az connectedk8s show -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" \
     --query "identity.principalId" -o tsv)

   az role assignment create \
     --role "Connected Cluster Managed Identity CheckAccess Reader" \
     --assignee-object-id "$CLUSTER_MSI" \
     --assignee-principal-type ServicePrincipal \
     --scope "$SCOPE"
   ```

1. Grant a user proxy access and read-only Kubernetes access:

   ```azurecli
   az role assignment create \
     --role "Azure Arc Enabled Kubernetes Cluster User Role" \
     --assignee "$USER_OBJECT_ID" \
     --scope "$SCOPE"

   az role assignment create \
     --role "Azure Arc Kubernetes Viewer" \
     --assignee "$USER_OBJECT_ID" \
     --scope "$SCOPE"
   ```

1. Connect and verify (run as the user from the previous step):

   ```azurecli
   az connectedk8s proxy -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" &
   sleep 10

   # Should succeed (Viewer permits read).
   kubectl get pods --all-namespaces

   # Should be denied with a 403 (Viewer doesn't permit writes).
   kubectl create namespace rbac-test || echo "denied as expected"
   ```
