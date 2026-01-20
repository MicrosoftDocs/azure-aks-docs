---
title: Set up permissions and role-based access control (RBAC) in AKS desktop (preview)
description: Learn how to set up permissions and role-based access control (RBAC) for AKS desktop in Azure Kubernetes Service (AKS) based on your role as a cluster operator or developer.
ms.subservice: aks-developer
ms.service: azure-kubernetes-service
ms.editor: schaffererin
author: qpetraroia
ms.topic: how-to
ms.date: 11/19/2025
ms.author: alalve
zone_pivot_groups: aks-desktop
# Customer intent: As a cluster operator or developer, I want to understand the setup requirements and permissions for AKS desktop, so that I can configure my environment based on my role.
---

# Set up permissions in AKS desktop (preview)

**Applies to**: :heavy_check_mark: [AKS Automatic clusters](intro-aks-automatic.md)

AKS desktop uses Azure role-based access control (RBAC) to manage user permissions for accessing and managing resources within AKS desktop. Depending on your role as a cluster operator or developer, you have different responsibilities and required permissions to work with AKS desktop effectively. This article guides you through the setup process based on your role: cluster operator or developer.

> [!NOTE]
> When you create Projects in AKS desktop, [AKS managed namespaces](concepts-managed-namespaces.md) are created in the same resource group as your cluster.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).
- Ensure you have Azure CLI version 2.64.0 or later installed and configured. Check your version using the [`az --version`](/cli/azure/reference-index#az-version) command. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The `aks-preview` Azure CLI extension. Install it using the `az extension add --name aks-preview` command.
- A basic understanding of Azure role-based access control (RBAC), see [What is Azure RBAC?](/azure/role-based-access-control/overview) and [Azure built-in roles](/azure/role-based-access-control/built-in-roles).
- An Azure resource group that contains your AKS cluster and any AKS managed Projects created through AKS desktop.
- An AKS Automatic cluster, which is the Kubernetes cluster where your applications run from.
- An Azure Container Registry (ACR) to your container images for deployment.

:::zone pivot="cluster-operator"

## Cluster operator responsibilities

As a cluster operator, you're responsible for provisioning and configuring the foundational infrastructure that enables development teams to build and deploy applications. Your responsibilities include:

- Creating the required Azure infrastructure (resource group, AKS cluster, ACR).
- Configuring ACR integration with your AKS cluster.
- Assigning permissions for users to create Projects.
- Optionally delegating permission management to Project creators.

## Create infrastructure resources

To create the infrastructure resources, you need permissions to create resources in Azure. If you aren't assigned the **Owner** RBAC role, you need the **Contributor** role to create resources and the **User Access Administrator** role to assign permissions to other users. Assign permissions to users so they can create resources in the resource group using the following steps:

1. Set environment variables for your resource group and cluster name. Make sure to replace the placeholders with your actual resource group and cluster names.

    ```bash
    export RESOURCE_GROUP=<infra-resource-group>
    export CLUSTER_NAME=<cluster-name>
    export SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    export ACR_NAME=<acr-name>
    ```

1. Assign the necessary role to create resources in the resource group using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. Make sure to replace `<user-id>` with the appropriate user or service principal ID.

    ```azurecli-interactive
    az role assignment create --role "Contributor" \
        --assignee <user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP
    ```

## Integrate ACR with your AKS cluster

> [!NOTE]
> We recommend using an AKS Automatic cluster with AKS desktop. While AKS Standard SKU work in AKS desktop, you might not see the full benefits of the Project view. AKS Automatic includes built-in metrics, observability, and other tools that enable AKS desktop to surface important insights for users.

- Attach your Azure container registry with your AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --attach-acr $ACR_NAME
    ```

## Select a Project creation model

As a cluster operator, you have two options for how developers work with Projects in AKS desktop:

- **Self-service model**: Developers create and manage their own Projects. This approach gives developers full autonomy but requires granting them the **Azure Kubernetes Service Namespace Contributor** role. When developers create their own Projects, they automatically receive **Owner** role on the managed namespace and can immediately start deploying applications.
- **Managed model**: You create Projects for developers and grant them access. This approach provides more control over Project creation but requires you to assign three roles per developer.

## [Self-service model: Allow developers to create their own Projects](#tab/self-service)

To allow developers to create their own Projects, assign them the **Azure Kubernetes Service Namespace Contributor** role on the AKS cluster. AKS desktop Projects create [AKS managed namespaces](concepts-managed-namespaces.md) behind the scenes, and this role grants the necessary permissions.

- Assign developers the **Azure Kubernetes Service Namespace Contributor** role using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service Namespace Contributor" \
        --assignee <developer-user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME
    ```

## [Managed model: Create Projects for developers and assign access](#tab/managed)

If you prefer to create Projects on behalf of developers, you must assign three essential roles to enable them to access the cluster and work within their assigned namespace:

- **Azure Kubernetes Service Cluster User Role**: Allows developers to download the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.
- **Azure Kubernetes Service Namespace User**: Grants access to the managed namespace.
- One of the Kubernetes RBAC roles (**Reader**, **Writer**, or **Admin**): Controls what actions they can perform in the namespace.

All three roles are required for developers to successfully access and work with their Projects in AKS desktop. Without the **Azure Kubernetes Service Cluster User Role**, developers can't download the kubeconfig file needed to connect to the cluster.

### Assign cluster access

- Assign the **Azure Kubernetes Service Cluster User Role** to enable kubeconfig download using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service Cluster User Role" \
        --assignee <developer-user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME
    ```

### Assign namespace access

- Assign **Azure Kubernetes Service Namespace User** role for the specific Project/namespace using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    export $NAMESPACE_NAME=<namespace-or-project-name>
    
    az role assignment create \
        --role "Azure Kubernetes Service Namespace User" \
        --assignee <developer-user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME/namespaces/$NAMESPACE_NAME
    ```

### Assign Kubernetes RBAC role

Assign the appropriate Kubernetes RBAC role based on what the developer needs to do:

- **Azure Kubernetes Service RBAC Reader** for read-only access.
- **Azure Kubernetes Service RBAC Writer** for deploying applications.
- **Azure Kubernetes Service RBAC Admin** for full administrative control.

1. Get the AKS cluster ID using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    AKS_ID=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --query id \
        --output tsv)
    ```

1. Assign the appropriate Kubernetes RBAC role using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID. The following example assigns the **Azure Kubernetes Service RBAC Writer** role:

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service RBAC Writer" \
        --assignee <developer-user-id> \
        --scope $AKS_ID/namespaces/$NAMESPACE_NAME
    ```

---

## Allow Project creators to assign access permissions (optional)

If you want Project creators to be able to assign access permissions to other users, grant them the [User Access Administrator](/azure/role-based-access-control/built-in-roles/privileged#user-access-administrator) role. This permission allows the user to set permissions on any resources in the infrastructure resource group.

- Assign the **User Access Administrator** role using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    az role assignment create \
        --role "User Access Administrator" \
        --assignee <user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP
    ```

:::zone-end

:::zone pivot="developer"

## Developer responsibilities

As a developer, you work within an existing AKS desktop environment to deploy applications, manage Projects, and monitor your workloads. The cluster operator grants you the necessary permissions to perform these tasks. Your responsibilities include:

- Deploying applications into Projects.
- Viewing and managing deployed applications.
- Monitoring application metrics and logs.
- Modifying Project access (if needed).

## Required user roles for developers

To work with AKS desktop as a developer, your cluster operator must assign you three essential roles:

- **Azure Kubernetes Service Cluster User Role**: Allows you to download cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command, which is a requirement to connect to the cluster from your local machine or through AKS desktop.
- **Azure Kubernetes Service Namespace User**: Grants access to your assigned managed namespace/Project.
- One of the Kubernetes RBAC roles (**Reader**, **Writer**, or **Admin**): Controls what actions you can perform in the namespace.

  - **Azure Kubernetes Service RBAC Reader** for read-only access.
  - **Azure Kubernetes Service RBAC Writer** for deploying applications.
  - **Azure Kubernetes Service RBAC Admin** for full administrative control.

### How permissions are assigned

Permissions are assigned based on how Projects are created in AKS desktop:

- **Project creator**: Automatically receives **Owner** role on the managed namespace and all necessary permissions to deploy applications.
- **Other users**: Must be granted access by the cluster operator or Project creator. They receive:

  - **Azure Kubernetes Service Cluster User Role** on the cluster.
  - **Azure Kubernetes Service Namespace User** role on the namespace.
  - One of the Kubernetes RBAC roles (**Reader**, **Writer**, or **Admin**).

To deploy applications, you need the **Writer** or **Admin** role. For more information, see [Managed namespaces built-in roles](concepts-managed-namespaces.md#managed-namespaces-built-in-roles).

## View application metrics

> [!NOTE]
> It might take up to 10 minutes for the metrics to populate once an application is deployed.

In the Project home screen, you can view metrics for your application, such as CPU, memory, and network usage. These metrics are sourced from the Managed Prometheus endpoint backed by an Azure Monitor workspace.

To view metrics, you need the **Monitoring Data Reader** role on the Azure Monitor workspace. This role grants access to all metrics for the cluster, not just your specific Projects.

Your cluster operator can assign this permission by following these steps:

1. Identify the Azure Monitor workspace used by your cluster using the [`az alerts-management prometheus-rule-group list`](/cli/azure/alerts-management/prometheus-rule-group#az-alerts-management-prometheus-rule-group-list) command:

   ```azurecli-interactive
   export WORKSPACE_ACC_FOR_PROM_RULES=$(az alerts-management prometheus-rule-group list \
       --resource-group "$RESOURCE_GROUP" \
       --query "[?clusterName=='$CLUSTER_NAME'] | [0].scopes[0]" \
       --output tsv)
   ```

1. Assign the **Monitoring Data Reader** role using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

   ```azurecli-interactive
   az role assignment create \
       --role "Monitoring Data Reader" \
       --assignee <user-id> \
       --scope $WORKSPACE_ACC_FOR_PROM_RULES
   ```

## Modify Project access permissions

Currently, AKS desktop doesn't provide a UI option to modify Project permissions after creation. If you need to update your permissions or grant access to others, work with your cluster operator to update permissions using the Azure portal or Azure CLI. The following steps outline how to assign the necessary roles using Azure CLI:

### Assign cluster access

- Assign the **Azure Kubernetes Service Cluster User Role** to enable kubeconfig download using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service Cluster User Role" \
        --assignee <developer-user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME
    ```

### Assign namespace access

- Assign **Azure Kubernetes Service Namespace User** role for the specific Project/namespace using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID.

    ```azurecli-interactive
    export $NAMESPACE_NAME=<namespace-or-project-name>
    
    az role assignment create \
        --role "Azure Kubernetes Service Namespace User" \
        --assignee <developer-user-id> \
        --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME/namespaces/$NAMESPACE_NAME
    ```

### Assign Kubernetes RBAC role

Assign the appropriate Kubernetes RBAC role based on what the developer needs to do:

- **Azure Kubernetes Service RBAC Reader** for read-only access.
- **Azure Kubernetes Service RBAC Writer** for deploying applications.
- **Azure Kubernetes Service RBAC Admin** for full administrative control.

1. Get the AKS cluster ID using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    AKS_ID=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --query id \
        --output tsv)
    ```

1. Assign the appropriate Kubernetes RBAC role using the [`az role assignment create`][az-role-assignment-create] command. Make sure to replace the placeholder with the appropriate user or service principal ID. The following example assigns the **Azure Kubernetes Service RBAC Writer** role:

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service RBAC Writer" \
        --assignee <developer-user-id> \
        --scope $AKS_ID/namespaces/$NAMESPACE_NAME
    ```

### Grant permissions for viewing metrics (optional)

To grant permissions to view metrics, follow the steps in the [View application metrics](#view-application-metrics) section.

:::zone-end

## Related content

- Learn how to [Deploy an application with AKS desktop (preview)](aks-desktop-app.md)
- Learn more about [Managed namespaces in AKS](concepts-managed-namespaces.md)

<!--- LINKS --->
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
