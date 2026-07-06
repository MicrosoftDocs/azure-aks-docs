---
title: Use Microsoft Entra ID Authorization for the Kubernetes API in Azure Kubernetes Service (AKS)
description: Learn how to authorize Kubernetes API access in Azure Kubernetes Service (AKS) using Microsoft Entra ID role assignments and ABAC conditions.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.custom: devx-track-azurecli
ms.date: 07/06/2026
ms.author: shasb
author: shashankbarsin
ai-usage: ai-assisted
# Customer intent: "As a cluster operator, I want to authorize access to the Kubernetes API using Microsoft Entra ID identities and granular conditions, so that I can govern cluster access at scale across many clusters from a single identity plane."
---

# Use Microsoft Entra ID authorization for the Kubernetes API in Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article shows how to authorize calls to the Kubernetes API in Azure Kubernetes Service (AKS) by using Microsoft Entra ID identities. Microsoft Entra ID authorization for the Kubernetes API uses Azure RBAC role assignments to grant access to Kubernetes resources. For built-in Kubernetes resources, assign one of the AKS built-in roles (such as Azure Kubernetes Service RBAC Reader) at the cluster or namespace scope. For custom resources (CRDs), assign a custom role with Azure ABAC conditions that specify which CRD groups or kinds the assignee can access. The two role assignments compose: one grants access to standard Kubernetes resources, and the other grants conditional access to specific custom resources.

For most production workloads, AKS Automatic is the recommended production-ready default for AKS. AKS Automatic clusters are preconfigured with Azure RBAC for Kubernetes authorization, so you can focus on assigning the right Microsoft Entra role assignments to users, groups, and service principals.

For a conceptual overview of the available Kubernetes API authorization options in AKS, see [Cluster authorization concepts](concepts-cluster-authorization.md).

> [!NOTE]
> When you use [integrated authentication between Microsoft Entra ID and AKS](managed-azure-ad.md), you can use Microsoft Entra users, groups, or service principals as subjects in [Kubernetes role-based access control (Kubernetes RBAC)][kubernetes-rbac]. By using Microsoft Entra ID authorization, you don't need to separately manage user identities and credentials for Kubernetes. However, you still need to set up and manage Microsoft Entra ID role assignments and any Kubernetes RBAC bindings separately.

> [!NOTE]
> AKS Automatic clusters are preconfigured to use Azure RBAC for Kubernetes authorization. You don't need to enable `--enable-azure-rbac` on AKS Automatic clusters. In AKS Standard, you can enable or disable Azure RBAC based on your cluster configuration.

## Prerequisites

- You need the Azure CLI version 2.24.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- You need `kubectl`, with a minimum version of [1.18.3](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.18.md#v1183).
- You need managed Microsoft Entra integration enabled on your cluster before you can add Microsoft Entra ID authorization for the Kubernetes API. If you need to enable managed Microsoft Entra integration, see [Use Microsoft Entra ID in AKS](managed-azure-ad.md).
- New role assignments can take up to five minutes to propagate and be updated by the authorization server.
- Microsoft Entra ID authorization for the Kubernetes API requires that the Microsoft Entra tenant configured for authentication is the same as the tenant for the subscription that holds your AKS cluster.

## AKS cluster mode behavior

| Cluster mode | Azure RBAC for Kubernetes authorization |
| ------------ | --------------------------------------- |
| AKS Automatic | Preconfigured (enabled by default) |
| AKS Standard | Optional (enable with `--enable-azure-rbac`) |

## Create a new AKS cluster with managed Microsoft Entra integration and Microsoft Entra ID authorization

### AKS Automatic (recommended for production workloads)

For new production workloads, use AKS Automatic. Azure RBAC for Kubernetes authorization is preconfigured on AKS Automatic clusters.

1. Create an AKS Automatic cluster by following [Create an Azure Kubernetes Service (AKS) Automatic cluster](./automatic/quick-automatic-managed-network.md).
1. Optional: verify that Azure RBAC for Kubernetes authorization is enabled on your cluster using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    az aks show \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --query "aadProfile.enableAzureRbac" \
      --output tsv
    ```

### AKS Standard

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    export RESOURCE_GROUP=<resource-group-name>
    export LOCATION=<azure-region>

    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

1. Create an AKS Standard cluster with managed Microsoft Entra integration and Microsoft Entra ID authorization using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    export CLUSTER_NAME=<cluster-name>

    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-aad \
        --enable-azure-rbac \
        --generate-ssh-keys
    ```

    Your output should look similar to the following example output:

    ```output
    "AADProfile": {
        "adminGroupObjectIds": null,
        "clientAppId": null,
        "enableAzureRbac": true,
        "managed": true,
        "serverAppId": null,
        "serverAppSecret": null,
        "tenantId": "****-****-****-****-****"
    }
    ```

## Enable Microsoft Entra ID authorization on an existing AKS cluster

For existing AKS Standard clusters, enable Microsoft Entra ID authorization for the Kubernetes API using the [`az aks update`][az-aks-update] command with the `--enable-azure-rbac` flag.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>

# Enable Microsoft Entra ID authorization for the Kubernetes API
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-azure-rbac
```

AKS Automatic clusters already have Azure RBAC for Kubernetes authorization preconfigured. You don't need to run `--enable-azure-rbac` for AKS Automatic.

## AKS built-in roles

AKS provides the following built-in roles:

| Role | Description |
| ---- | ----------- |
| [Azure Kubernetes Service RBAC Reader](/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-reader)  | Allows read-only access to see most objects in a namespace. It doesn't allow viewing roles or role bindings. This role doesn't allow viewing `Secrets`, since reading the contents of Secrets enables access to ServiceAccount credentials in the namespace, which would allow API access as any ServiceAccount in the namespace (a form of privilege escalation).  |
| [Azure Kubernetes Service RBAC Writer](/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-writer) | Allows read/write access to most objects in a namespace. This role doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing `Secrets` and running Pods as any ServiceAccount in the namespace, so it can be used to gain the API access levels of any ServiceAccount in the namespace. |
| [Azure Kubernetes Service RBAC Admin](/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-admin)  | Allows admin access, intended to be granted within a namespace. Allows read/write access to most resources in a namespace (or cluster scope), including the ability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. |
| [Azure Kubernetes Service RBAC Cluster Admin](/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-cluster-admin)  | Allows super-user access to perform any action on any resource. It gives full control over every resource in the cluster and in all namespaces. |

## Create role assignments for cluster access

### [Azure CLI](#tab/azure-cli)

1. Get your AKS resource ID using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS resource ID
    AKS_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id --output tsv)
    ```

1. Create a role assignment using the [`az role assignment create`][az-role-assignment-create] command. `<AAD-ENTITY-ID>` can be a username or the client ID of a service principal. The following example creates a role assignment for the Azure Kubernetes Service RBAC Admin role.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS resource ID
    AKS_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id --output tsv)

    # Create a role assignment for the Azure Kubernetes Service RBAC Admin role
    az role assignment create --role "Azure Kubernetes Service RBAC Admin" --assignee <AAD-ENTITY-ID> --scope $AKS_ID
    ```

    > [!NOTE]
    > You can create the Azure Kubernetes Service RBAC Reader and Azure Kubernetes Service RBAC Writer role assignments scoped to a specific namespace within the cluster using the [`az role assignment create`][az-role-assignment-create] command and setting the scope to the desired namespace.
    >
    > ```azurecli-interactive
    > az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee <AAD-ENTITY-ID> --scope $AKS_ID/namespaces/<namespace-name>
    > ```

### [Azure portal](#tab/azure-portal)

1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
1. In the service menu, select **Access control (IAM)** > **Add role assignment**.
1. On the **Role** tab, select the role you want, such as _Azure Kubernetes Service RBAC Admin_, and then select **Next**.
1. On the **Members** tab, configure the following settings:

    - **Assign access to**: Select **User, group, or service principal**.
    - **Members**: Select **+ Select members**, search for and select the members you want, and then select **Select**.

1. Select **Review + assign** > **Assign**.

    > [!NOTE]
    > In the Azure portal, after you create role assignments scoped to a desired namespace, you can't see role assignments for namespace [at a scope][list-role-assignments-at-a-scope-at-portal]. You can find them by using the [`az role assignment list`][az-role-assignment-list] command, or [list role assignments for a user or group][list-role-assignments-for-a-user-or-group-at-portal], which you assigned the role to.
    >
    > ```azurecli-interactive
    > az role assignment list --scope $AKS_ID/namespaces/<namespace-name>
    > ```

---

## Create custom roles definitions

For built-in Kubernetes resources, custom role definitions reference the corresponding API group action under `Microsoft.ContainerService/managedClusters/`. The following example allows a user to only read deployments and nothing else. For the full list of possible actions, see [Microsoft.ContainerService operations](/azure/role-based-access-control/resource-provider-operations#microsoftcontainerservice). To filter access to specific custom resource (CRD) groups or kinds, see [Restrict custom resource access using ABAC conditions](#restrict-custom-resource-access-using-abac-conditions-preview) later in this article.

1. To create your own custom role definitions, copy the following file, replace `<YOUR-SUBSCRIPTION-ID>` with your own subscription ID, and then save it as `deploy-view.json`.

    ```json
    {
        "Name": "AKS Deployment Reader",
        "Description": "Lets you view all deployments in cluster/namespace.",
        "Actions": [],
        "NotActions": [],
        "DataActions": [
            "Microsoft.ContainerService/managedClusters/apps/deployments/read"
        ],
        "NotDataActions": [],
        "assignableScopes": [
            "/subscriptions/<YOUR-SUBSCRIPTION-ID>"
        ]
    }
    ```

1. Create the role definition using the [`az role definition create`][az-role-definition-create] command, setting the `--role-definition` to the `deploy-view.json` file you created in the previous step.

    ```azurecli-interactive
    az role definition create --role-definition @deploy-view.json 
    ```

1. Assign the role definition to a user or other identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
        # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS resource ID
    AKS_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id --output tsv)

    # Create a role assignment for the AKS Deployment Reader role
    az role assignment create --role "AKS Deployment Reader" --assignee <AAD-ENTITY-ID> --scope $AKS_ID
    ```

## Restrict custom resource access using ABAC conditions (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

ABAC conditions let you filter Microsoft Entra ID role assignments to specific custom resource (CRD) groups and kinds - centrally, from Microsoft Entra ID, without writing per-cluster Kubernetes RBAC `Role` and `RoleBinding` manifests. For background on Azure ABAC, see [What are Azure role assignment conditions?](/azure/role-based-access-control/conditions-overview)

### When to use ABAC conditions

Use this feature when you want to:

- Restrict which CRD groups or kinds an assignee can list or get.
- Centrally enforce custom resource access boundaries from Microsoft Entra ID without managing Kubernetes RBAC `Role` and `RoleBinding` objects on every cluster.
- Distinguish between CRDs published by different operators (for example, allow `secrets-store.csi.x-k8s.io` while blocking `security.istio.io`).

### Available condition attributes

The following request attributes are available when authoring conditions for the Kubernetes API on an AKS cluster:

| Attribute | Description |
| --------- | ----------- |
| `Microsoft.ContainerService/managedClusters/customResources:group` | The API group of the custom resource being accessed (for example, `secrets-store.csi.x-k8s.io`). |
| `Microsoft.ContainerService/managedClusters/customResources:kind` | The kind of the custom resource being accessed (for example, `secretproviderclasses`). |

### Add an ABAC condition to a role assignment

The following example creates an AKS CRD Reader custom role that grants read access to custom resources. Then it assigns the role with a condition that only allows access to `secretproviderclasses` in the `secrets-store.csi.x-k8s.io` group (the CRD used by the Azure Key Vault provider for the Secrets Store CSI Driver).

1. Save the following role definition to a file named `crd-reader.json`, replacing `<YOUR-SUBSCRIPTION-ID>` with your own subscription ID.

    ```json
    {
        "Name": "AKS CRD Reader",
        "Description": "Lets you read custom resources in the cluster.",
        "Actions": [],
        "NotActions": [],
        "DataActions": [
            "Microsoft.ContainerService/managedClusters/customresources/read"
        ],
        "NotDataActions": [],
        "assignableScopes": [
            "/subscriptions/<YOUR-SUBSCRIPTION-ID>"
        ]
    }
    ```

1. Create the role definition using the [`az role definition create`][az-role-definition-create] command.

    ```azurecli-interactive
    az role definition create --role-definition @crd-reader.json
    ```

1. Save the following condition to a file named `abac-condition.txt`. The condition allows non-custom-resource reads to pass through unchanged, and restricts custom resource reads to a specific group and kind.

    ```text
    (
     (
      !(ActionMatches{'Microsoft.ContainerService/managedClusters/customresources/read'})
     )
     OR
     (
      @Request[Microsoft.ContainerService/managedClusters/customResources:group] StringEqualsIgnoreCase 'secrets-store.csi.x-k8s.io'
      AND
      @Request[Microsoft.ContainerService/managedClusters/customResources:kind] StringEqualsIgnoreCase 'secretproviderclasses'
     )
    )
    ```

1. Create the role assignment with the condition using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS resource ID
    AKS_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id --output tsv)

    # Create a role assignment for the AKS CRD Reader role with an ABAC condition
    az role assignment create \
        --role "AKS CRD Reader" \
        --assignee <AAD-ENTITY-ID> \
        --scope $AKS_ID \
        --condition "$(cat abac-condition.txt)" \
        --condition-version "2.0" \
        --description "Allow reads on SecretProviderClass resources only"
    ```

You can also add a condition through the Azure portal. On the **Add role assignment** page, select the **Conditions** tab, then select **Add condition** and use the visual editor to build the expression.

### Verify the condition

After the role assignment propagates (up to five minutes), sign in as the assignee and confirm they can read the allowed CRD but not other CRDs.

1. Get the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the cluster credentials
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. List `secretproviderclasses` from the `secrets-store.csi.x-k8s.io` group, which the condition allows. The command should succeed and return either the existing resources or an empty list (or a not-found error if the CRD isn't installed on the cluster).

    ```bash
    kubectl get secretproviderclasses.secrets-store.csi.x-k8s.io --all-namespaces
    ```

1. List `authorizationpolicies` from the Istio `security.istio.io` group, which the condition blocks. The command should fail with a `Forbidden` error from the Microsoft Entra ID authorization webhook (assuming the Istio CRD is installed on the cluster; otherwise `kubectl` returns a not-found error before the API server reaches the authorization webhook).

    ```bash
    kubectl get authorizationpolicies.security.istio.io --all-namespaces
    ```

## Clean up resources

### Disable Microsoft Entra ID authorization

Remove Microsoft Entra ID authorization using the [`az aks update`][az-aks-update] command with the `--disable-azure-rbac` flag.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>

# Disable Microsoft Entra ID authorization for the Kubernetes API
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --disable-azure-rbac
```

### Delete role assignment

#### [Azure CLI](#tab/azure-cli)

1. List role assignments using the [`az role assignment list`][az-role-assignment-list] command.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS resource ID
    AKS_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query id --output tsv)

    # List role assignments for the AKS cluster
    az role assignment list --scope $AKS_ID --query [].id --output tsv
    ```

1. Delete the role assignments using the [`az role assignment delete`][az-role-assignment-delete] command.

    ```azurecli-interactive
    az role assignment delete --ids <LIST OF ASSIGNMENT IDS>
    ```

#### [Azure portal](#tab/azure-portal)

1. Navigate to your AKS cluster and select **Access control (IAM)** > **Role assignments**.
1. Select the role assignment to delete, and then select **Delete** > **Yes**.

---

### Delete role definition

Delete a custom role definition using the [`az role definition delete`][az-role-definition-delete] command.

```azurecli-interactive
az role definition delete --name "AKS Deployment Reader"
```

### Delete resource group and AKS cluster

#### [Azure CLI](#tab/azure-cli)

Delete the resource group (and the AKS cluster it contains) using the [`az group delete`][az-group-delete] command.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>

# Delete the resource group and all resources in it
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

#### [Azure portal](#tab/azure-portal)

1. Navigate to the resource group that contains your AKS cluster and select **Delete resource group**.
1. On **Delete a resource group**, enter the resource group name, and then select **Delete** > **Delete**.

---

## Related content

To learn more about AKS, see the following articles:

- [What is AKS Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Cluster authorization concepts for AKS](concepts-cluster-authorization.md)
- [Access and identity options for AKS](/azure/aks/concepts-identity)
- [What is Azure RBAC?](/azure/role-based-access-control/overview)
- [What are Azure ABAC conditions?](/azure/role-based-access-control/conditions-overview)
- [Microsoft.ContainerService operations](/azure/role-based-access-control/resource-provider-operations#microsoftcontainerservice)

<!-- LINKS - Internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-show]: /cli/azure/aks#az-aks-show
[list-role-assignments-at-a-scope-at-portal]: /azure/role-based-access-control/role-assignments-list-portal#list-role-assignments-at-a-scope
[list-role-assignments-for-a-user-or-group-at-portal]: /azure/role-based-access-control/role-assignments-list-portal#list-role-assignments-for-a-user-or-group
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-role-assignment-delete]: /cli/azure/role/assignment#az-role-assignment-delete
[az-role-assignment-list]: /cli/azure/role/assignment#az-role-assignment-list
[az-group-create]: /cli/azure/group#az-group-create
[az-group-delete]: /cli/azure/group#az-group-delete
[az-aks-update]: /cli/azure/aks#az-aks-update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-role-definition-create]: /cli/azure/role/definition#az-role-definition-create
[az-role-definition-delete]: /cli/azure/role/definition#az-role-definition-delete
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[kubernetes-rbac]: kubernetes-rbac-entra-id.md
