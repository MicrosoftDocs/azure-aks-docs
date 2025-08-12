---
title: How to use managed namespaces (preview)
description: Step-by-step guide on using managed namespaces (preview) in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 08/04/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
zone_pivot_groups: bicep-azure-cli-portal
---

# Use managed namespaces (preview) in Azure Kubernetes Service (AKS)

**Applies to:** :heavy_check_mark: AKS Automatic (preview) :heavy_check_mark: AKS Standard

Managed namespaces in Azure Kubernetes Service (AKS) provide a way to logically isolate workloads and teams within a cluster. This feature enables administrators to enforce resource quotas, apply network policies, and manage access control at the namespace level. For a detailed overview of managed namespaces, see the [managed namespaces overview][aks-managed-namespaces-overview].

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

### Prerequisites

- An Azure account with an active subscription. If you don't have one, you can [create an account for free][create-azure-subscription].
- An [AKS cluster][quick-automatic-managed-network] set up in your Azure environment with [Azure role-based access control for Kubernetes authorization][azure-rbac-k8s].
- To use the network policy feature, the AKS cluster needs to be [configured with a network policy engine][aks-network-policy-options]. Cilium is our recommended engine.

| Prerequisite                     | Notes                                                                 |
|------------------------------|------------------------------------------------------------------------|
| **Azure CLI**                | `2.74.0` or later installed. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli]. |
| **Azure CLI `aks-preview` extension**                | `18.0.0b10` or later. To find the version, run `az --version`. If you need to install or upgrade, see [Manage Azure CLI extensions][azure-cli-extensions]. |
| **AKS API Version**          | `2025-05-02-preview` or later. For more information, see [AKS Preview API lifecycle][aks-preview-api-lifecycle]. |
| **Feature Flag(s)**             | `ManagedNamespacePreview` must be registered to use managed namespaces.    |
| **Required permission(s)**      | `Microsoft.ContainerService/managedClusters/managedNamespaces/*` or `Azure Kubernetes Service Namespace Contributor` built-in role. `Microsoft.Resources/deployments/*` on the resource group containing the cluster. For more information, see [Managed namespaces built-in roles][aks-managed-namespaces-roles]. |

### Limitations

- Trying to on-board system namespaces such as `kube-system`, `app-routing-system`, `istio-system`, `gatekeeper-system`, etc. to be managed namespaces isn't allowed.
- When a namespace is a managed namespace, changes to the namespace via the Kubernetes API are blocked.
:::zone target="docs" pivot="azure-portal"
- Listing existing namespaces to convert in the portal doesn't work with private clusters. You can add new namespaces.
  
:::zone-end

<!-- Azure CLI -->
:::zone target="docs" pivot="azure-cli"
## Install the aks-preview CLI extension

To install the aks-preview extension, run the [`az extension add`](/cli/azure/extension#az-extension-add) command.

```azurecli-interactive
az extension add --name aks-preview
```

Run the following command to update to the latest version of the extension released.

```azurecli-interactive
az extension update --name aks-preview
```

### Register the feature flag

To use managed namespaces in preview, register the following flag using the [az feature register][az-feature-register] command.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name ManagedNamespacePreview
```

Verify the registration status by using the [az feature show][az-feature-show] command. It takes a few minutes for the status to show *Registered*.

```azurecli-interactive
az feature show --namespace Microsoft.ContainerService --name ManagedNamespacePreview
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register][az-provider-register] command.

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

:::zone-end

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

## Install the aks-preview CLI extension

To install the aks-preview extension, run the following command.

```azurecli-interactive
az extension add --name aks-preview
```

Run the following command to update to the latest version of the extension released.

```azurecli-interactive
az extension update --name aks-preview
```

### Register the feature flag

To use managed namespaces in preview, register the following flag using the [az feature register][az-feature-register] command.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name ManagedNamespacePreview
```

Verify the registration status by using the [az feature show][az-feature-show] command. It takes a few minutes for the status to show *Registered*.

```azurecli-interactive
az feature show --namespace Microsoft.ContainerService --name ManagedNamespacePreview
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register][az-provider-register] command.

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

:::zone-end
## Create a managed namespace on a cluster and assign users

> [!NOTE]
> When you create a managed namespace, a component is installed on the cluster to reconcile the namespace with the state in Azure Resource Manager (ARM). This component blocks changes to the managed fields and resources from the Kubernetes API, ensuring consistency with the desired configuration.

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

The following Bicep example demonstrates how to create a managed namespace as a subresource of a managed cluster. Make sure to select the appropriate value for `defaultNetworkPolicy`, `adoptionPolicy`, and `deletePolicy`. For more information about what those parameters mean, see the [managed namespaces overview][aks-managed-namespaces-overview].

```bicep
resource existingCluster 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' existing = {
  name: 'contoso-cluster'
}

resource managedNamespace 'Microsoft.ContainerService/managedClusters/managedNamespaces@2025-05-02-preview' = {
  parent: existingCluster
  name: 'retail-team'
  location: location
  properties: {
    defaultResourceQuota: {
      cpuRequest: '1000m'
      cpuLimit: '2000m'
      memoryRequest: '512Mi'
      memoryLimit: '1Gi'
    }
    defaultNetworkPolicy: {
      ingress: 'AllowSameNamespace'
      egress: 'AllowAll'
    }
    adoptionPolicy: 'IfIdentical'
    deletePolicy: 'Keep'
    labels: {
      environment: 'dev'
    }
    annotations: {
      owner: 'retail'
    }
  }
}
```

Save the Bicep file **managedNamespace.bicep** to your local computer.

Deploy the Bicep file using the Azure CLI.

```azurecli-interactive
az deployment group create --resource-group <resource-group> --template-file managedNamespace.bicep
```

:::zone-end

<!-- Azure CLI -->
:::zone target="docs" pivot="azure-cli"

### Define variables

Define the following variables to be used in the subsequent steps.

```azurecli-interactive
RG_NAME=cluster-rg
CLUSTER_NAME=contoso-cluster
NAMESPACE_NAME=retail-team
LABELS="environment=dev"
ANNOTATIONS="owner=retail"
```

### Create the managed namespace

To customize its configuration, managed namespaces have various parameter options to choose from during creation. Make sure to select the appropriate value for `ingress-network-policy`, `egress-network-policy`, `adoption-policy`, and `delete-policy`. For more information about what those parameters mean, see the [managed namespaces overview][aks-managed-namespaces-overview].


```azurecli-interactive
az aks namespace add \
    --name ${NAMESPACE_NAME} \
    --cluster-name ${CLUSTER_NAME} \
    --resource-group ${RG_NAME} \
    --cpu-request 1000m \
    --cpu-limit 2000m \
    --memory-request 512Mi \
    --memory-limit 1Gi \
    --ingress-policy [AllowSameNamespace|AllowAll|DenyAll] \
    --egress-policy [AllowSameNamespace|AllowAll|DenyAll] \
    --adoption-policy [Never|IfIdentical|Always] \
    --delete-policy [Keep|Delete] \
    --labels ${LABELS} \
    --annotations ${ANNOTATIONS}
```

### Assign role

After the namespace is created, you can assign [one of the built-in roles][aks-managed-namespaces-roles] for the control plane and data plane.

```azurecli-interactive
ASSIGNEE="user@contoso.com"
NAMESPACE_ID=$(az aks namespace show --name ${NAMESPACE_NAME} --cluster-name ${CLUSTER_NAME} --resource-group ${RG_NAME} --query id -o tsv)
```

Assign a control plane role to be able to view the managed namespace in the portal, Azure CLI output, and ARM. This role also allows the user to retrieve the credentials to connect to this namespace.

```azurecli-interactive
az role assignment create \
  --assignee ${ASSIGNEE} \
  --role "Azure Kubernetes Service Namespace User" \
  --scope ${NAMESPACE_ID}
```

Assign data plane role to be able to get access to create resources within the namespace using the Kubernetes API.

```azurecli-interactive
az role assignment create \
  --assignee ${ASSIGNEE} \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope ${NAMESPACE_ID}
```

:::zone-end

<!-- Portal -->
:::zone target="docs" pivot="azure-portal"
1. Sign in to the [Azure portal][azure-portal].
1. On the Azure portal home page, select **Create a resource**.
1. In the **Categories** section, select **Managed Kubernetes Namespaces**.
1. On the **Basics** tab,  under **Project details** configure the following settings:
    1. Select the target **cluster** to create the namespace on.
    1. If you're creating a new namespace, leave the default **create new**, otherwise choose **change existing to managed** to convert an existing namespace.
1. Configure the **networking policy** to be applied on the namespace.
1. Configure the **resource requests and limits** for the namespace.
1. Select the **members (users or groups)** and their **role**.
    1. Assign the  **Azure Kubernetes Service Namespace User** role to give them access to view the managed namespace in the portal, Azure CLI output, and ARM. This role also allows the user to retrieve the credentials to connect to this namespace.
    2. Assign the  **Azure Kubernetes Service RBAC Writer** role to give them access to create resources within the namespace using the Kubernetes API.
1. Select **Review + create** to run validation on the configuration. After validation completes, select **Create**.

:::zone-end

<!-- Azure CLI -->
:::zone target="docs" pivot="azure-cli"

## List managed namespaces

You can list managed namespaces at different scopes using the Azure CLI.

### At a subscription level

Run the following command to list all managed namespaces in a subscription.

```azurecli-interactive
az aks namespace list --subscription <subscription-id>
```

### At a resource group level

Run the following command to list all managed namespaces in a specific resource group.

```azurecli-interactive
az aks namespace list --resource-group <rg-name>
```

### At a cluster level

Run the following command to list all managed namespaces in a specific cluster.

```azurecli-interactive
az aks namespace list --resource-group <rg-name> --cluster-name <cluster-name>
```

:::zone-end

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

## List managed namespaces

You can list managed namespaces at different scopes using the Azure CLI.

### At a subscription level

Run the following command to list all managed namespaces in a subscription.

```azurecli-interactive
az aks namespace list --subscription <subscription-id>
```

### At a resource group level

Run the following command to list all managed namespaces in a specific resource group.

```azurecli-interactive
az aks namespace list --resource-group <rg-name>
```

### At a cluster level

Run the following command to list all managed namespaces in a specific cluster.

```azurecli-interactive
az aks namespace list --resource-group <rg-name> --cluster-name <cluster-name>
```

:::zone-end

<!-- Portal -->
:::zone target="docs" pivot="azure-portal"
<!-- empty -->
:::zone-end


<!-- Azure CLI -->
:::zone target="docs" pivot="azure-cli"

## Connect to the cluster

You can retrieve the credentials to connect to a namespace via the following command.

```azurecli-interactive
az aks namespace get-credentials --name <namespace-name> --resource-group <rg-name> --cluster-name <cluster-name>
```

:::zone-end

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

## Connect to the cluster

You can retrieve the credentials to connect to a namespace via the following command.

```azurecli-interactive
az aks namespace get-credentials --name <namespace-name> --resource-group <rg-name> --cluster-name <cluster-name>
```

:::zone-end

<!-- Portal -->
:::zone target="docs" pivot="azure-portal"
<!-- empty -->
:::zone-end

## Next steps


This article focused on using the managed namespaces feature to logically isolate teams and applications. You can further explore other guardrails and best practices to apply via [deployment safeguards][deployment-safeguards].

<!--- External Links --->
[create-azure-subscription]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[azure-portal]: https://portal.azure.com

<!--- Internal Links --->
[cluster-autoscaler]: cluster-autoscaler.md
[node-auto-provisioning]: node-autoprovision.md
[quick-automatic-managed-network]: automatic/quick-automatic-managed-network.md
[deployment-safeguards]: deployment-safeguards.md
[azure-rbac-k8s]: manage-azure-rbac.md
[install-azure-cli]: /cli/azure/install-azure-cli
[azure-cli-extensions]: /cli/azure/azure-cli-extensions-overview
[aks-preview-api-lifecycle]: /azure/aks/concepts-preview-api-life-cycle
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-feature-show]: /cli/azure/feature#az_feature_show
[az-provider-register]: /cli/azure/provider#az_provider_register
[aks-managed-namespace-rbac-reader]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-rbac-reader
[aks-managed-namespace-rbac-writer]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-rbac-writer
[aks-managed-namespace-rbac-admin]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-rbac-admin
[aks-network-policies]: use-network-policies.md
[aks-network-policy-options]: use-network-policies.md#network-policy-options-in-aks
[aks-resource-quotas]: operator-best-practices-scheduler.md#enforce-resource-quotas
[aks-managed-namespaces-overview]: concepts-managed-namespaces.md
[aks-managed-namespaces-roles]: concepts-managed-namespaces.md#managed-namespaces-built-in-roles
