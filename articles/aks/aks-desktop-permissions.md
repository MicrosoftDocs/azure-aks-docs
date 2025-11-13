---
title: Understand permissions and RBAC in AKS desktop (Preview)
description: Learn how to set up Azure Kubernetes Service (AKS) desktop with the required infrastructure and permissions for cluster operators and developers.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: how-to
ms.date: 11/13/2025
ms.author: alalve
# Customer intent: As a cluster operator or developer, I want to understand the setup requirements and permissions for AKS desktop, so that I can configure my environment based on my role.
---

# Get started with permission assignments in AKS desktop (Preview)

AKS desktop builds on existing AKS and Azure features to provide an application-focused experience for deploying and managing workloads. This article helps you get started with AKS desktop by explaining the required infrastructure and permissions for two common scenarios:

- Cluster operators who set up infrastructure.

- Developers who deploy applications.

When you create projects in AKS desktop, any attributed [AKS managed namespaces](concepts-managed-namespaces.md) are created in the same resource group as your cluster.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop might undergo design changes, add or delete additional features, and more. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at the official [AKS desktop GitHub repository](https://github.com/Azure/aks-desktop).

## Prerequisites

These prerequisites apply to all users:

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

- Ensure you have Azure CLI version 2.64.0 or later installed and configured. Check your version with `az --version`. For installation or upgrade instructions, see [Install Azure CLI](/cli/azure/install-azure-cli).

- The `aks-preview` Azure CLI extension. Install it using the `az extension add --name aks-preview` command.

- A basic understanding of Azure role-based access control (RBAC), see [What is Azure RBAC?](/azure/role-based-access-control/overview) and [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

- An Azure Resource group that Contains your AKS cluster and any AKS managed projects created through AKS desktop.

- An AKS Automatic Cluster, which is the Kubernetes cluster where your applications run from.

- An Azure Container Registry (ACR) to your container images for deployment.

## Choose your scenario

AKS desktop supports two primary user scenarios. Select the scenario that matches your role:

- **Scenario 1: I'm a cluster operator** - You're responsible for setting up the AKS infrastructure, creating clusters, and managing access for development teams.

- **Scenario 2: I'm a developer** - You need to deploy applications, manage projects, and view application metrics in an existing AKS desktop environment.

# [Cluster Operator](#tab/cluster-operator)

As a cluster operator, you're responsible for provisioning and configuring the foundational infrastructure that enables development teams to build and deploy applications. Your responsibilities include:

- Creating the required Azure infrastructure (resource group, AKS cluster, ACR)
- Configuring ACR integration with your AKS cluster
- Assigning permissions for users to create projects
- Optionally, delegating permission management to project creators

## Step 1: Create infrastructure resources

To create the infrastructure resources, you need permissions to create resources in Azure. If you aren't assigned the **Owner** RBAC role, you need the **Contributor** role to create resources and the **User Access Administrator** role to assign permissions to other users. Assign permissions to users so they can create resources in the resource group by following these steps:

1. Set environment variables for your resource group and cluster name by running the following command:

    ```azurecli-interactive
    myResourceGroup=<infra-resource-group>
    myClusterName=<cluster-name>
    ```

1. Assign the necessary role to create resources in the resource group using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command:

    ```azurecli-interactive
    az role assignment create --role "Contributor" \
        --assignee <user-id> \
        --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup
    ```

## Step 2: Create the AKS cluster with ACR integration

You must ensure the cluster is authorized to connect to the ACR. Choose one of the following options:

### Option 1: Attach ACR during cluster creation

Create the cluster and attach the ACR using the [`az aks create`](/cli/azure/aks#az-aks-create) command.

```azurecli-interactive
az aks create \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --sku automatic \
    --attach-acr <registry-name>
```

### Option 2: Attach ACR to an existing cluster

Update an existing cluster to attach the ACR using the [`az aks update`](/cli/azure/aks#az-aks-update) command.

```azurecli-interactive
az aks update \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --attach-acr <registry-name>
```

## Step 3: Assign permissions for project creation

AKS desktop projects create [AKS managed namespaces](concepts-managed-namespaces.md) behind the scenes. To allow users to create projects, assign them the **Azure Kubernetes Service Namespace Contributor** role on the AKS cluster.

Assign the role using the `az role assignment create` command:

```azurecli-interactive
az role assignment create \
    --role "Azure Kubernetes Service Namespace Contributor" \
    --assignee <user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName
```

## Step 4 (Optional): Allow project creators to assign access

If you want project creators to be able to assign access permissions to other users, grant them the [User Access Administrator](/azure/role-based-access-control/built-in-roles/privileged#user-access-administrator) role.

Assign the role using the `az role assignment create` command:

```azurecli-interactive
az role assignment create \
    --role "User Access Administrator" \
    --assignee <user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup
```

This permission allows the user to set permissions on any resources in the infrastructure resource group.

# [Developer](#tab/dev)

As a developer, you work within an existing AKS desktop environment to deploy applications, manage projects, and monitor your workloads. The cluster operator grants you the necessary permissions to perform these tasks. Your responsibilities include:

- Deploying applications into projects
- Viewing and managing deployed applications
- Monitoring application metrics and logs
- Modifying project access (if needed)

When a project is created in AKS desktop, permissions are automatically assigned:

**Project creator** - Receives **Owner** role on the managed namespace and can deploy applications.

**Shared access users** - Users granted access during project creation receive:

  - **Azure Kubernetes Service Namespace User** role on the managed namespace

  Including one of the following Kubernetes RBAC roles:

  - **Azure Kubernetes Service RBAC Reader** - Read-only access to resources

  - **Azure Kubernetes Service RBAC Writer** - Read and write access to deploy apps

  - **Azure Kubernetes Service RBAC Admin** - Full administrative access

To deploy applications, you need the **Writer** or **Admin** role. For more information, see [Managed namespaces built-in roles](concepts-managed-namespaces.md#managed-namespaces-built-in-roles).

## View application metrics

In the project home screen, you can view metrics for your application, such as CPU, memory, and network usage. These metrics are sourced from the Managed Prometheus endpoint backed by an Azure Monitor workspace.

To view metrics, you need the **Monitoring Data Reader** role on the Azure Monitor workspace. This role grants access to all metrics for the cluster, not just your specific projects.

Your cluster operator can assign this permission by following these steps:

1. Identify the Azure Monitor workspace used by your cluster using the [`az alerts-management prometheus-rule-group list`](/cli/azure/alerts-management/prometheus-rule-group#az-alerts-management-prometheus-rule-group-list) command:

   ```azurecli-interactive
   export WORKSPACE_ACC_FOR_PROM_RULES=$(az alerts-management prometheus-rule-group list \
       --resource-group "$myResourceGroup" \
       --query "[?clusterName=='$myClusterName'] | [0].scopes[0]" \
       --output tsv)
   ```

1. Assign the **Monitoring Data Reader** role using the `az role assignment create` command:

   ```azurecli-interactive
   az role assignment create \
       --role "Monitoring Data Reader" \
       --assignee <user-id> \
       --scope $WORKSPACE_ACC_FOR_PROM_RULES
   ```

## Modify project access permissions

Currently, AKS desktop doesn't provide a UI option to modify project permissions after creation. If you need to update your permissions or grant access to others, work with your cluster operator to update permissions using the Azure portal or Azure CLI. This process involves the following steps:

1. Granting access to the managed namespace resource by running the following command:

```azurecli-interactive
namespaceName=<namespace-or-project-name>

az role assignment create \
    --role "Azure Kubernetes Service Namespace User" \
    --assignee <user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName/namespaces/$namespaceName
```

1. Assigning one of the following Kubernetes RBAC roles based on the required access level. Modify `--role` with one of the following permissions:

- **Azure Kubernetes Service RBAC Reader** - Read-only access
- **Azure Kubernetes Service RBAC Writer** - Read and write access to deploy apps
- **Azure Kubernetes Service RBAC Admin** - Full administrative access

```azurecli-interactive
AKS_ID=$(az aks show \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --query id \
    --output tsv)

az role assignment create \
    --role "Azure Kubernetes Service RBAC Writer" \
    --assignee <user-id> \
    --scope $AKS_ID/namespaces/$namespaceName
```

1. To grant permissions to view metrics, follow the steps in the [View application metrics](#view-application-metrics) section to grant users access to view application metrics.

---

## Summary of permissions by role

The following table summarizes the key permissions needed for each role:

| Role | Task | Required Permission |
|------|------|---------------------|
| **Cluster Operator** | Create infrastructure resources | Contributor role on resource group. |
| **Cluster Operator** | Assign permissions to others | User Access Administrator role. |
| **Cluster Operator** | Enable project creation for users | Grant Azure Kubernetes Service Namespace Contributor role. |
| **Project Creator** | Create projects | Azure Kubernetes Service Namespace Contributor role on cluster. |
| **Project Creator** | Assign project access to others | User Access Administrator role (optional). |
| **Developer** | Deploy applications | Azure Kubernetes Service RBAC Writer or Admin role on namespace. |
| **Developer** | View application metrics | Monitoring Data Reader role on Azure Monitor workspace. |
| **Developer** | View resources (read-only) | Azure Kubernetes Service RBAC Reader role on namespace. |

## Next steps

- Learn about [AKS desktop overview](aks-desktop-overview.md)
- Learn how to [Deploy an application via AKS desktop](aks-desktop-app.md)
- Learn more about [Managed namespaces](concepts-managed-namespaces.md)
