---
title: How to Use Managed Namespaces in Azure Kubernetes Service (AKS)
description: Step-by-step guide on using managed namespaces in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 11/18/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
zone_pivot_groups: bicep-azure-cli-portal
---

# Use managed namespaces in Azure Kubernetes Service (AKS)

**Applies to:** :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

Managed namespaces in Azure Kubernetes Service (AKS) provide a way to logically isolate workloads and teams within a cluster. This feature enables administrators to enforce resource quotas, apply network policies, and manage access control at the namespace level. For a detailed overview of managed namespaces, see the [managed namespaces overview][aks-managed-namespaces-overview].

## Before you begin

### Prerequisites

- An Azure account with an active subscription. If you don't have one, you can [create an account for free][create-azure-subscription].
- An [AKS cluster][quick-automatic-managed-network] set up in your Azure environment with [Azure role-based access control for Kubernetes authorization][azure-rbac-k8s] is required if you intend to utilize Azure RBAC roles.
- To use the network policy feature, the AKS cluster needs to be [configured with a network policy engine][aks-network-policy-options]. Cilium is our recommended engine.

| Prerequisite                     | Notes                                                                 |
|------------------------------|------------------------------------------------------------------------|
| **Azure CLI**                | `2.80.0` or later installed. To find the CLI version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli]. |
| **AKS API Version**          | `2025-09-01` or later. |
| **Required permission(s)**      | `Microsoft.ContainerService/managedClusters/managedNamespaces/*` or `Azure Kubernetes Service Namespace Contributor` built-in role. `Microsoft.Resources/deployments/*` on the resource group containing the cluster. For more information, see [Managed namespaces built-in roles][aks-managed-namespaces-roles]. |

### Limitations

- Trying to on-board system namespaces such as `kube-system`, `app-routing-system`, `istio-system`, `gatekeeper-system`, etc. to be managed namespaces isn't allowed.
- When a namespace is a managed namespace, changes to the namespace via the Kubernetes API are blocked.
:::zone target="docs" pivot="azure-portal"
- Listing existing namespaces to convert in the portal doesn't work with private clusters. You can add new namespaces.
- Attempting to get namespace credentials via `az aks namespace get-credentials` on clusters without Azure RBAC enabled will result in a `(BadRequest)` error as Entra authentication is required for namespace level credentials to be successfully passed.

:::zone-end

## Create a managed namespace on a cluster and assign users

> [!NOTE]
> When you create a managed namespace, a component is installed on the cluster to reconcile the namespace with the state in Azure Resource Manager. This component blocks changes to the managed fields and resources from the Kubernetes API, ensuring consistency with the desired configuration.

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

The following Bicep example demonstrates how to create a managed namespace as a subresource of a managed cluster. Make sure to select the appropriate value for `defaultNetworkPolicy`, `adoptionPolicy`, and `deletePolicy`. For more information about what those parameters mean, see the [managed namespaces overview][aks-managed-namespaces-overview].

```bicep
resource existingCluster 'Microsoft.ContainerService/managedClusters@2024-03-01' existing = {
  name: 'contoso-cluster'
}

resource managedNamespace 'Microsoft.ContainerService/managedClusters/managedNamespaces@2025-09-01' = {
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

Assign a control plane role to be able to view the managed namespace in the portal, Azure CLI output, and Azure Resource Manager. This role also allows the user to retrieve the credentials to connect to this namespace.

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
    1. Assign the  **Azure Kubernetes Service Namespace User** role to give them access to view the managed namespace in the portal, Azure CLI output, and Azure Resource Manager. This role also allows the user to retrieve the credentials to connect to this namespace.
    2. Assign the  **Azure Kubernetes Service RBAC Writer** role to give them access to create resources within the namespace using the Kubernetes API.
1. Select **Review + create** to run validation on the configuration. After validation completes, select **Create**.

:::zone-end

<!-- Azure CLI -->
:::zone target="docs" pivot="azure-cli"

## List managed namespaces

You can list managed namespaces at different scopes using the Azure CLI.

### Subscription level

Run the following command to list all managed namespaces in a subscription.

```azurecli-interactive
az aks namespace list --subscription <subscription-id>
```

### Resource group level

Run the following command to list all managed namespaces in a specific resource group.

```azurecli-interactive
az aks namespace list --resource-group <rg-name>
```

### Cluster level

Run the following command to list all managed namespaces in a specific cluster.

```azurecli-interactive
az aks namespace list --resource-group <rg-name> --cluster-name <cluster-name>
```

:::zone-end

<!-- Bicep -->
:::zone target="docs" pivot="bicep"

## List managed namespaces

You can list managed namespaces at different scopes using the Azure CLI.

### Subscription level

Run the following command to list all managed namespaces in a subscription.

```azurecli-interactive
az aks namespace list --subscription <subscription-id>
```

### Resource group level

Run the following command to list all managed namespaces in a specific resource group.

```azurecli-interactive
az aks namespace list --resource-group <rg-name>
```

### Cluster level

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
[quick-automatic-managed-network]: automatic/quick-automatic-managed-network.md
[deployment-safeguards]: deployment-safeguards.md
[azure-rbac-k8s]: manage-azure-rbac.md
[install-azure-cli]: /cli/azure/install-azure-cli
[aks-network-policy-options]: use-network-policies.md#network-policy-options-in-aks
[aks-managed-namespaces-overview]: concepts-managed-namespaces.md
[aks-managed-namespaces-roles]: concepts-managed-namespaces.md#managed-namespaces-built-in-roles
