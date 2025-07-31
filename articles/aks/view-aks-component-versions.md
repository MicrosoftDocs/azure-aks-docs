---
title: View AKS component versions (Preview)
description: Learn how to retrieve detailed version information for all Azure Kubernetes Service (AKS) cluster components using AKS Component Insights.
ms.topic: how-to
ms.subservice: aks-cluster-management
ms.custom: azure-kubernetes-service, devx-track-azurecli
ms.date: 07/31/2025
author: kaarthis
ms.author: kaarthis

# Customer intent: "As a cloud administrator, I want to see the exact versions of all components running in my AKS cluster, so I can plan upgrades and troubleshoot issues effectively."
---

# View AKS component versions (Preview)

AKS Component Insights (Preview) provides detailed visibility into the exact versions of all components running in your Azure Kubernetes Service cluster. This feature helps you understand your cluster's current state, plan upgrades, and identify potential compatibility issues.

## Prerequisites

- An existing AKS cluster
- Azure CLI version 2.34.1 or later, or Azure PowerShell version 5.9.0 or later
- The `aks-preview` CLI extension version 18.0.0b19 or later

## Install the preview extension

To use AKS Component Insights, you need the preview extension:

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview

# Update to the latest version if already installed
az extension update --name aks-preview
```

## View component versions using Azure CLI

### Get cluster component versions

Use the `az aks get-upgrades` command to view component versions:

```azurecli-interactive
az aks get-upgrades --resource-group myResourceGroup --name myAKSCluster
```

### Get component versions in JSON format

To see detailed output in JSON format:

```azurecli-interactive
az aks get-upgrades --resource-group myResourceGroup --name myAKSCluster --output json
```

## View component versions using REST API

You can also retrieve component information using the REST API:

```bash
# Using curl (requires authentication)
curl -X GET \
  "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ContainerService/managedClusters/{cluster-name}/upgradeProfiles/default?api-version=2025-05-01" \
  -H "Authorization: Bearer {access-token}"
```

## Understanding the output

The component information is returned in the `componentsByReleases` section:

```json
{
  "controlPlaneProfile": {
    "componentsByReleases": [
      {
        "kubernetesVersion": "1.32",
        "components": [
          {
            "name": "azure-policy-webhook",
            "version": "1.13.0",
            "hasBreakingChanges": false
          },
          {
            "name": "cloud-provider-node-manager-linux",
            "version": "v1.32.0",
            "hasBreakingChanges": false
          },
          {
            "name": "osm-sidecar",
            "version": "v1.32.2-hotfix.20241216",
            "hasBreakingChanges": false
          }
        ]
      }
    ]
  }
}
```

### Component information fields

Each component entry includes:

- **name**: The component identifier
- **version**: The exact version that will be (or is) installed
- **hasBreakingChanges**: Whether this component version introduces breaking changes

### Component categories

Components are organized into several categories. The following are examples of components you might see:

#### Control plane components (examples)
- `cloud-provider-node-manager-linux`
- `cloud-provider-node-manager-windows`
- `cluster-autoscaler`

#### Add-ons and integrations (examples)
- `azure-policy-webhook`
- `azure-monitor-containers`
- `application-gateway-ingress-controller`

#### Service mesh and networking (examples)
- `osm-sidecar`
- `istio-control-plane`
- `cilium-operator`

#### OS and runtime components (examples)
- `containerd`
- `kubernetes-node-components`
- `azure-linux-kernel`

> [!NOTE]
> The actual components shown will vary based on your cluster configuration, enabled add-ons, and Kubernetes version. Use the `az aks get-upgrades` command to see the complete list of components for your specific cluster.

## Common use cases

### Pre-upgrade planning

Before upgrading your cluster, check what components will change:

```azurecli-interactive
az aks get-upgrades --resource-group myResourceGroup --name myAKSCluster --output table
```

### Troubleshooting compatibility issues

If you're experiencing issues, check the exact component versions:

```azurecli-interactive
az aks show --resource-group myResourceGroup --name myAKSCluster --output table
```

## Monitoring component changes

### Set up alerts for breaking changes

You can create Azure Monitor alerts to notify you when upgrades with breaking changes are available by monitoring the REST API response for `hasBreakingChanges: true`.

## Limitations and considerations

### Preview limitations

- Component Insights is currently in preview
- Not all components may be listed in early preview versions
- Output format may change before general availability

### Permissions required

To view component information, you need:
- `Microsoft.ContainerService/managedClusters/read` permission
- Access to the cluster's resource group

### Regional availability

Component Insights is available in all regions where AKS is supported.

## Troubleshooting

### Extension not found error

If you receive an extension not found error, install the preview extension:

```azurecli-interactive
az extension add --name aks-preview
```

### API version not supported

Ensure you're using the latest extension version:

```azurecli-interactive
az extension update --name aks-preview
```

### Empty component list

If no components are returned:
1. Verify your cluster is running a supported Kubernetes version
2. Check that the preview extension is correctly installed
3. Ensure you have proper permissions

## Next steps

- [Understanding AKS component versioning](aks-component-versioning.md)
- [Upgrade an AKS cluster](upgrade-aks-cluster.md)
- [Configure automatic upgrades](auto-upgrade-cluster.md)
- [Supported Kubernetes versions in AKS](supported-kubernetes-versions.md)
