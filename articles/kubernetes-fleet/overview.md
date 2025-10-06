---
title: "Overview of Azure Kubernetes Fleet Manager"
services: kubernetes-fleet
ms.service: azure-kubernetes-fleet-manager
ms.date: 09/15/2025
ms.topic: overview
author: sjwaight
ms.author: simonwaight
description: "This article provides an overview of Azure Kubernetes Fleet Manager."
keywords: "Kubernetes, Azure, multi-cluster, multi, containers"
# Customer intent: "As a cloud administrator, I want to manage multiple Kubernetes clusters, so that I can streamline upgrades, deployments, and resource allocation across my organization's infrastructure."
---

# What is Azure Kubernetes Fleet Manager?

Azure Kubernetes Fleet Manager enables at-scale management of multiple Azure Kubernetes Service (AKS) clusters. Fleet Manager provides platform administrators with access to automated safe multi-cluster updates, intelligent Kubernetes resource placement, and a centralized location to access monitoring data for their clusters.

:::image type="content" source="./media/overview/fleet-manager-portal-overview.png" alt-text="A screenshot of the Azure Kubernetes Fleet Manager overview page in the Azure portal. The overview shows there are five Kubernetes clusters running a supported Kubernetes version. There are 78 completed update runs with 29 failures and 49 successes. Across the five Kubernetes clusters there is a spread of node images." lightbox="./media/overview/fleet-manager-portal-overview.png":::

Fleet Manager supports the following scenarios:

* Join AKS clusters or Arc-Enabled Kubernetes clusters (preview) across Azure regions and subscriptions as member clusters. Read [Azure Fleet Manager member cluster types](./concepts-member-cluster-types.md) to understand more.

* Use [Fleet Manager managed namespaces](./concepts-fleet-managed-namespace.md) to enforce resource quotas, network policies, and assign role based access at the namespace level across multiple clusters.

* Safely and consistently apply Kubernetes version and node image upgrades across multiple clusters with [update runs](./concepts-update-orchestration.md), attaching reusable update strategies to control the order and timing of cluster updates.

* Include optional manual or automated approvals for update groups and stages to provide more fine-grained control over when updates are applied (preview).

* Automatically trigger version upgrades when new Kubernetes or node image versions are published by defining one or more [auto-upgrade profile](./concepts-update-orchestration.md#understanding-auto-upgrade-profiles).

* Deploy a hub cluster to enable intelligent placing of Kubernetes resources across member clusters based on cluster labels and properties using Fleet Manager [cluster resource placement](./concepts-resource-propagation.md).

* Stage Kubernetes resources from Git repositories to Fleet Manager's hub cluster using [Automated Deployments](./concepts-automated-deployments.md) (preview).

* Load balance incoming traffic across service endpoints on multiple clusters using [DNS-based load balancing](./concepts-dns-load-balancing.md) (preview).

## Next steps

* [Conceptual overview of Fleets and member clusters](./concepts-fleet.md).
* [Conceptual overview of Update orchestration across multiple member clusters](./concepts-update-orchestration.md).
* [Conceptual overview of Kubernetes resource placement from hub cluster to member clusters](./concepts-resource-propagation.md).
* [Conceptual overview of DNS load balancing (preview)](./concepts-l4-load-balancing.md).
* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
