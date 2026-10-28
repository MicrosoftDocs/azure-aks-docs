---
title: "Azure Kubernetes Fleet Manager member cluster labels"
description: This article provides a conceptual overview of member cluster labels and how they are used in Azure Kubernetes Fleet Manager.
ms.date: 10/06/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
ai-usage: ai-assisted
---

# Azure Kubernetes Fleet Manager member cluster labels

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Member cluster labels let you describe and select clusters in Azure Kubernetes Fleet Manager. Use labels to identify clusters by attributes such as location, environment, or application team. You can then use those attributes to target resource placements, group clusters for updates, and define staged rollouts without listing individual cluster names.

This article explains how member cluster labels work and how you can use them to manage your fleet.

## The purpose of member labels

When you add an AKS or Arc-enabled Kubernetes cluster to a fleet, Fleet Manager creates an Azure member cluster resource that acts as a proxy for that cluster. Member cluster labels are key-value pairs associated with this resource. They describe the fleet member, rather than labeling the nodes or workloads inside the cluster.

If your fleet has a hub cluster, Fleet Manager creates a `MemberCluster` Kubernetes custom resource on the hub cluster to represent the joined cluster and applies the labels to it as well. Resource placement uses this custom resource to identify and select target clusters.

## Default labels

Fleet Manager automatically adds service-defined labels to each member cluster. These labels describe the cluster's Azure identity and location, so you can select clusters using information Fleet Manager already maintains.

| Label | Description |
| --- | --- |
| `fleet.azure.com/location` | The Azure region of the cluster, such as `westus`. |
| `fleet.azure.com/resource-group` | The Azure resource group that contains the cluster. |
| `fleet.azure.com/subscription-id` | The Azure subscription ID of the cluster. |
| `fleet.azure.com/cluster-name` | The name of the underlying AKS or Arc-enabled Kubernetes cluster. |
| `fleet.azure.com/member-name` | The name of the member cluster resource in Fleet Manager. |

Service-defined labels are read-only. Add custom labels to describe attributes that aren't covered by the default labels.

## Custom labels

Custom labels describe how you organize and operate your clusters. For example, you might apply the following labels to a member cluster:

| Key | Example value | Purpose |
| --- | --- | --- |
| `environment` | `production` | Distinguish production clusters from test or staging clusters. |
| `team` | `payments` | Identify the team responsible for the cluster. |
| `update-ring` | `canary` | Identify clusters for an early update or rollout stage. |

A member cluster can have multiple labels, so you can select it in different ways for different tasks. Use consistent keys and values across your fleet so that selectors match the clusters you intend to manage.

## Select, group, and order clusters

A label selector matches clusters by their label keys and values. For example, a selector for `environment=production` selects members with that label. Adding a requirement for `team=payments` narrows the selection to production clusters owned by the payments team.

Use labels for the following management tasks:

- **Update orchestration:** Select clusters for stages and groups in an update strategy. Label-based grouping for updates is in preview. For more information, see [Group clusters using member labels](./concepts-update-orchestration.md#group-clusters-using-member-labels-preview).
- **Cross-cluster network membership:** Set member labels to control whether a cluster is a member of a cross-cluster network. For more information, see [Configure and use cross-cluster networking](./howto-configure-use-cross-cluster-networking.md).
- **Resource placement:** Select the member clusters that receive Kubernetes resources. For more information, see [Resource placement](./concepts-resource-placement.md).
- **Staged resource rollouts:** Select clusters for each rollout stage for a resource placement. For more information, see [Resource placement rollout strategies](./concepts-rollout-strategy.md).

For rollouts and strategies, labels don't define an execution order by themselves. Configure the order in your update or rollout strategy, and use labels to identify the clusters in each stage. For example, place clusters labeled `update-ring=canary` in an earlier stage and clusters labeled `update-ring=production` in a later stage.

## Label synchronization with the hub cluster

For fleets with a hub cluster, custom member labels are synchronized between the Azure member resource and the corresponding `MemberCluster` custom resource. Labels you apply through the Azure CLI, portal, or ARM templates are replicated to the `MemberCluster` resource on the hub. You can't manage labels on the `MemberCluster` resource on the hub cluster directly.

## Managing member cluster labels

You can manage custom labels through the Azure portal, Azure CLI, or Azure Resource Manager (ARM) templates and Bicep. 

In the Azure portal, open your Fleet Manager, select **Settings** > **Member clusters**, select a member cluster, and choose **Edit labels**. Add or change the label key-value pairs, and then select **Apply**. 

For scripting and automation, use [`az fleet member create`](/cli/azure/fleet/member#az-fleet-member-create) or [`az fleet member update`](/cli/azure/fleet/member#az-fleet-member-update) with the `--labels` parameter. The following example sets the custom labels introduced earlier. Replace the resource group, fleet, and member names with your own values.

```azurecli-interactive
az fleet member update \
		--resource-group myFleetResourceGroup \
		--fleet-name myFleet \
		--name myMember \
		--labels "environment=production team=payments update-ring=canary"
```

For declarative management, define custom labels in `properties.labels` on the `Microsoft.ContainerService/fleets/members` resource in your ARM template or Bicep file. The following Bicep example sets the same labels for a member of an existing fleet. Deploy it to the fleet's resource group, supplying the fleet name, member name, and full Azure resource ID of the AKS or Arc-enabled Kubernetes cluster. Include any other member properties you manage, such as `group`, in your template. For the resource schema, see the [Fleet member ARM and Bicep reference](/azure/templates/microsoft.containerservice/2026-06-01/fleets/members).

```bicep
param fleetName string
param memberName string
param clusterResourceId string

resource fleet 'Microsoft.ContainerService/fleets@2024-04-01' existing = {
	name: fleetName
}

resource member 'Microsoft.ContainerService/fleets/members@2026-06-01' = {
	parent: fleet
	name: memberName
	properties: {
		clusterResourceId: clusterResourceId
		labels: {
			'environment': 'production'
			'team': 'payments'
			'update-ring': 'canary'
		}
	}
}
```

## Next steps

- [Assign member labels and create an update strategy using member selectors](./update-create-update-strategy.md#create-an-update-strategy-using-member-selectors-preview).
- [Learn how placement policies can use labels to select member clusters](./concepts-resource-placement.md#member-cluster-labels).
