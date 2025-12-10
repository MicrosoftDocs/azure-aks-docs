---
title: "Azure Kubernetes Fleet Manager fleets and member clusters"
description: This article provides a conceptual overview of Azure Kubernetes Fleet Manager and member clusters.
ms.date: 12/10/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a cloud administrator, I want to manage multiple Kubernetes clusters as a single entity using a fleet resource, so that I can orchestrate updates and maintain consistency across clusters."
---

# Azure Kubernetes Fleet Manager fleets and member clusters

This article provides a conceptual overview of fleets and member clusters in Azure Kubernetes Fleet Manager.

## What are fleets?

A fleet is a group for Kubernetes clusters that can be managed via a single Fleet Manager resource.

A Fleet Manager, depending on the selected configuration, supports safe multi-cluster updates (Kubernetes and node images), Kubernetes resource propagation, and multi-tenancy with Managed Fleet Namespaces.

For more information about the configuration options for Fleet Manager see [choosing an Azure Kubernetes Fleet Manager option](concepts-choosing-fleet.md).

## What are member clusters?

You can join [supported Kubernetes clusters](./concepts-member-cluster-types.md) as members. Member clusters must reside in the same Microsoft Entra tenant as the Fleet Manager, but they can be in different Azure regions, resource groups, or subscriptions.

When Fleet Manager is configured with a hub cluster, a `MemberCluster` Kubernetes resource is created on the hub cluster to represent each member cluster. The API for this resource offers a dependable way for multi-cluster application placements to identify registered clusters within a fleet. It also facilitates querying a list of clusters managed by the Fleet Manager or in observing cluster statuses for placement management actions.

### Labels

When Fleet Manager is configured with a hub cluster, Member clusters can have service-defined and user-defined labels associated with them, which are used to select clusters for workload placement. When you define a [ClusterResourcePlacement](./concepts-resource-propagation.md#using-clusterresourceplacement-to-deploy-cluster-scoped-resources), you can use label selectors to target specific member clusters based on their labels. This allows you to deploy workloads only to clusters that match certain criteria, such as region, environment, team, or other custom attributes.

By default, Fleet populates these [service-defined labels](./concepts-resource-propagation.md#labels) on each member cluster.

Member labels should be modified using the Azure CLI or REST API. They may not be modified directly on the `MemberCluster` resource on the hub cluster.

### Taints

When Fleet Manager is configured with a hub cluster, member clusters support the specification of taints, which apply to the `MemberCluster` resource on the hub cluster. Each taint object consists of the following fields:

* `key`: The key of the taint.
* `value`: The value of the taint.
* `effect`: The effect of the taint, such as `NoSchedule`.

Once a `MemberCluster` is tainted, it lets the [KubeFleet scheduler](./concepts-scheduler-scheduling-framework.md) know that the cluster shouldn't receive resources as part of the [resource propagation](./concepts-resource-propagation.md) from the hub cluster. The `NoSchedule` effect is a signal to the scheduler to avoid scheduling resources from a [`ClusterResourcePlacement`](./concepts-resource-propagation.md#using-clusterresourceplacement-to-deploy-cluster-scoped-resources) or [ResourcePlacement](./concepts-namespace-scoped-resource-propagation.md) to the `MemberCluster`.

## Next steps

* [Choosing a fleet type](./concepts-choosing-fleet.md).
* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
* [Fleet Manager hub cluster overview](./concepts-lifecycle.md).
* [Supported Kubernetes clusters](./concepts-member-cluster-types.md).
* [KubeFleet components documentation](https://kubefleet.dev/docs/concepts/components/).
* [Fleet Manager Frequently Asked Questions](./faq.md).