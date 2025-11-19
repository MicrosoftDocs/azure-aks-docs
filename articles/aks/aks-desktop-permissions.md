---
title: Understand permissions and RBAC in AKS desktop (Preview)
description: Learn how to set up Azure Kubernetes Service (AKS) desktop with the required infrastructure and permissions for cluster operators and developers.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: how-to
ms.date: 11/19/2025
ms.author: alalve
# Customer intent: As a cluster operator or developer, I want to understand the setup requirements and permissions for AKS desktop, so that I can configure my environment based on my role.
---

# Get started with permissions for AKS desktop (Preview)

AKS desktop builds on existing AKS and Azure features to provide an application-focused experience for deploying and managing workloads. This article helps you get started with AKS desktop by explaining the required infrastructure and permissions for two common scenarios:

- Cluster operators who set up infrastructure.

- Developers who deploy applications.

When you create projects in AKS desktop, [AKS managed namespaces](concepts-managed-namespaces.md) are created in the same resource group as your cluster.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop might undergo design changes, add or delete features, and more. You might also experience slow refresh times. If you're interested in shaping the AKS desktop experience, need help, or have any questions, engage with the engineers and product team at the official [AKS desktop GitHub repository](https://github.com/Azure/aks-desktop/issues).

## Prerequisites

These prerequisites apply to all users:

- An Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).

- Ensure you have Azure CLI version 2.64.0 or later installed and configured. Check your version with `az --version`. For installation or upgrade instructions, see [Install Azure CLI](/cli/azure/install-azure-cli).

- The `aks-preview` Azure CLI extension. Install it using the `az extension add --name aks-preview` command.

- A basic understanding of Azure role-based access control (RBAC), see [What is Azure RBAC?](/azure/role-based-access-control/overview) and [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

- An Azure Resource group that Contains your AKS cluster and any AKS managed projects created through AKS desktop.

- An AKS Automatic Cluster, which is the Kubernetes cluster where your applications run from.

- An Azure Container Registry (ACR) to your container images for deployment.

> [!IMPORTANT]
> **AKS desktop is optimized for [AKS Automatic clusters](intro-aks-automatic.md)**. AKS desktop was built for AKS Automatic clusters and doesn't currently support AKS standard SKU. AKS Automatic includes built-in metrics, observability, and other tools that enable AKS desktop to surface important insights for users.

## Understanding AKS desktop RBAC roles

AKS desktop uses Azure RBAC to control access to managed namespaces and cluster resources. Understanding these roles is essential for properly configuring permissions.

### Namespace access roles

| Role | Description |
|------|-------------|
| **Azure Kubernetes Service Namespace Contributor** | Allows access to create, update, and delete managed namespaces on a cluster. |
| **Azure Kubernetes Service Namespace User** | Allows read-only access to a managed namespace on a cluster. Allows access to list credentials on the namespace. This role is required for all users who need to work with a namespace. |

### Kubernetes RBAC roles for namespaces

Managed namespaces use the following built-in roles for data plane operations:

| Role | Description |
|------|-------------|
| **Azure Kubernetes Service RBAC Reader** | Allows read-only access to see most objects in a namespace. It doesn't allow viewing roles or role bindings. This role doesn't allow viewing Secrets, since reading the contents of Secrets enables access to ServiceAccount credentials in the namespace, which would allow API access as any ServiceAccount in the namespace (a form of privilege escalation). |
| **Azure Kubernetes Service RBAC Writer** | Allows read/write access to most objects in a namespace. This role doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing Secrets and running Pods as any ServiceAccount in the namespace, so it can be used to gain the API access levels of any ServiceAccount in the namespace. |
| **Azure Kubernetes Service RBAC Admin** | Allows read/write access to most resources in a namespace, including the ability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. |

### Cluster access role

| Role | Description |
|------|-------------|
| **Azure Kubernetes Service Cluster User Role** | Allows the use of `az aks get-credentials` without the `--admin` flag. On a Microsoft Entra ID-enabled cluster, this downloads an empty entry into `.kube/config`, which triggers browser-based authentication when first used by kubectl. **This role is crucial for developers to access the cluster and work with their assigned namespaces.** |

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

> [!NOTE]
> The recommendation is to use an AKS Automatic cluster when using AKS desktop. While standard SKU clusters work in AKS desktop, you might not see the full benefits of the project view. AKS Automatic includes built-in metrics, observability, and other tools that enable AKS desktop to surface important insights for users.

You must ensure the cluster is authorized to connect to the ACR. Choose one of the following options:

### Option 1: Attach ACR during cluster creation

Create the cluster and attach the ACR using the [`az aks create`](/cli/azure/aks#az-aks-create) command:

```azurecli-interactive
az aks create \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --sku automatic \
    --attach-acr <registry-name>
```

### Option 2: Attach ACR to an existing cluster

Update an existing cluster to attach the ACR using the [`az aks update`](/cli/azure/aks#az-aks-update) command:

```azurecli-interactive
az aks update \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --attach-acr <registry-name>
```

## Step 3: Choose a project creation model

As a cluster operator, you have two options for how developers work with projects in AKS desktop:

- **Option A: Self-service model** - Developers create and manage their own projects. This approach gives developers full autonomy but requires granting them the **Azure Kubernetes Service Namespace Contributor** role.

- **Option B: Managed model** - You create projects on behalf of developers and grant them access. This approach provides more control over project creation but requires you to assign three roles per developer.

Choose the option that best fits your organization's governance and operational model.

### Option A: Enable developers to create their own projects

To allow developers to create their own projects, assign them the **Azure Kubernetes Service Namespace Contributor** role on the AKS cluster. AKS desktop projects create [AKS managed namespaces](concepts-managed-namespaces.md) behind the scenes, and this role grants the necessary permissions.

Assign the role using the `az role assignment create` command:

```azurecli-interactive
az role assignment create \
    --role "Azure Kubernetes Service Namespace Contributor" \
    --assignee <developer-user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName
```

When developers create their own projects, they automatically receive **Owner** role on the managed namespace and can immediately start deploying applications.

### Option B: Create projects for developers and assign access

If you prefer to create projects on behalf of developers, you must assign three essential roles to enable them to access the cluster and work within their assigned namespace:

1. **Azure Kubernetes Service Cluster User Role** - Allows developers to download the cluster credentials using `az aks get-credentials`
2. **Azure Kubernetes Service Namespace User** - Grants access to the managed namespace
3. One of the Kubernetes RBAC roles (**Reader**, **Writer**, or **Admin**) - Controls what actions they can perform in the namespace

#### Assign cluster access

First, assign the cluster user role so developers can access the cluster:

```azurecli-interactive
az role assignment create \
    --role "Azure Kubernetes Service Cluster User Role" \
    --assignee <developer-user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName
```

#### Assign namespace access

Next, assign the namespace user role for the specific project/namespace:

```azurecli-interactive
namespaceName=<project-or-namespace-name>

az role assignment create \
    --role "Azure Kubernetes Service Namespace User" \
    --assignee <developer-user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName/namespaces/$namespaceName
```

#### Assign Kubernetes RBAC role

Finally, assign the appropriate Kubernetes RBAC role based on what the developer needs to do:

- Use **Azure Kubernetes Service RBAC Reader** for read-only access
- Use **Azure Kubernetes Service RBAC Writer** for deploying applications
- Use **Azure Kubernetes Service RBAC Admin** for full administrative control

```azurecli-interactive
AKS_ID=$(az aks show \
    --resource-group $myResourceGroup \
    --name $myClusterName \
    --query id \
    --output tsv)

az role assignment create \
    --role "Azure Kubernetes Service RBAC Writer" \
    --assignee <developer-user-id> \
    --scope $AKS_ID/namespaces/$namespaceName
```

> [!IMPORTANT]
> All three roles are required for developers to successfully access and work with their projects in AKS desktop. Without the **Azure Kubernetes Service Cluster User Role**, developers can't download the kubeconfig file needed to connect to the cluster.

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

## Required permissions for developers

To work with AKS desktop as a developer, your cluster operator must assign you three essential roles:

1. **Azure Kubernetes Service Cluster User Role** - Allows you to download cluster credentials using `az aks get-credentials`, which is a requirement to connect to the cluster from your local machine or through AKS desktop.

2. **Azure Kubernetes Service Namespace User** - Grants access to your assigned managed namespace/project.

3. **One Kubernetes RBAC role** - Controls what actions you can perform:
   - **Azure Kubernetes Service RBAC Reader** - Read-only access to resources
   - **Azure Kubernetes Service RBAC Writer** - Read and write access to deploy apps
   - **Azure Kubernetes Service RBAC Admin** - Full administrative access

### How permissions are assigned

When a project is created in AKS desktop:

- **Project creator** - Automatically receives **Owner** role on the managed namespace and all necessary permissions to deploy applications.

- **Other users** - Must be granted access by the cluster operator or project creator. They receive:
  - **Azure Kubernetes Service Cluster User Role** on the cluster
  - **Azure Kubernetes Service Namespace User** role on the namespace
  - One of the Kubernetes RBAC roles (Reader, Writer, or Admin)

To deploy applications, you need the **Writer** or **Admin** role. For more information, see [Managed namespaces built-in roles](concepts-managed-namespaces.md#managed-namespaces-built-in-roles).

## View application metrics

> [!NOTE]
> It might take up to 10 minutes for the metrics to populate once an application is deployed.

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

Currently, AKS desktop doesn't provide a UI option to modify project permissions after creation. If you need to update your permissions or grant access to others, work with your cluster operator to update permissions using the Azure portal or Azure CLI. This process requires assigning three roles:

### Step 1: Assign cluster access

First, grant the cluster user role to enable kubeconfig download:

```azurecli-interactive
az role assignment create \
    --role "Azure Kubernetes Service Cluster User Role" \
    --assignee <user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName
```

### Step 2: Assign namespace access

Next, grant access to the managed namespace resource:

```azurecli-interactive
namespaceName=<namespace-or-project-name>

az role assignment create \
    --role "Azure Kubernetes Service Namespace User" \
    --assignee <user-id> \
    --scope /subscriptions/<subscription-id>/resourceGroups/$myResourceGroup/providers/Microsoft.ContainerService/managedClusters/$myClusterName/namespaces/$namespaceName
```

### Step 3: Assign Kubernetes RBAC role

Assign one of the following Kubernetes RBAC roles based on the required access level:

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

### Step 4 (Optional): Grant permissions for viewing metrics

To grant permissions to view metrics, follow the steps in the [View application metrics](#view-application-metrics) section.

---

## Summary of permissions by role

The following table summarizes the key permissions needed for each role:

| Role | Task | Required Permission |
|------|------|---------------------|
| **Cluster Operator** | Create infrastructure resources | Contributor role on resource group. |
| **Cluster Operator** | Assign permissions to others | User Access Administrator role. |
| **Cluster Operator** | Enable project creation for users | Grant Azure Kubernetes Service Namespace Contributor role. |
| **Cluster Operator** | Grant developer access to projects | Assign three roles: Azure Kubernetes Service Cluster User Role, Azure Kubernetes Service Namespace User, and one Kubernetes RBAC role. |
| **Project Creator** | Create projects | Azure Kubernetes Service Namespace Contributor role on cluster. |
| **Project Creator** | Assign project access to others | User Access Administrator role (optional). |
| **Developer** | Access cluster and download kubeconfig | Azure Kubernetes Service Cluster User Role on cluster. |
| **Developer** | Access assigned namespace/project | Azure Kubernetes Service Namespace User role on namespace. |
| **Developer** | Deploy applications | Azure Kubernetes Service RBAC Writer or Admin role on namespace. |
| **Developer** | View application metrics | Monitoring Data Reader role on Azure Monitor workspace. |
| **Developer** | View resources (read-only) | Azure Kubernetes Service RBAC Reader role on namespace. |

## Next steps

- Learn about [AKS desktop overview](aks-desktop-overview.md)
- Learn how to [Deploy an application via AKS desktop](aks-desktop-app.md)
- Learn more about [Managed namespaces](concepts-managed-namespaces.md)
