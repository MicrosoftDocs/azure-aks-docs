---
title: "Overview of Azure Kubernetes Fleet Manager"
services: kubernetes-fleet
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - ignite-2023
ms.date: 04/28/2025
ms.topic: overview
author: sjwaight
ms.author: simonwaight
description: "This article provides an overview of Azure Kubernetes Fleet Manager."
keywords: "Kubernetes, Azure, multi-cluster, multi, containers"
---

# What is Azure Kubernetes Fleet Manager?

Azure Kubernetes Fleet Manager enables at-scale management of multiple Azure Kubernetes Service (AKS) clusters. Fleet Manager supports the following scenarios:

* Create a Fleet Manager resource and join AKS clusters across regions and subscriptions as member clusters.

* Orchestrate Kubernetes version upgrades and node image upgrades across multiple clusters by using update runs, stages, and groups.

* Automatically trigger version upgrades when new Kubernetes or node image versions are published.

* Use Automated Deployments to stage Kubernetes workloads from Git repositories to Fleet Manager's hub cluster, ready for placement (preview).

* Intelligently place Kubernetes resources across member clusters based on cluster labels and properties.

* Export and import services between member clusters, and load balance incoming traffic across service endpoints on multiple clusters (preview).

## Next steps

* [Conceptual overview of Fleets and member clusters](./concepts-fleet.md).
* [Conceptual overview of Update orchestration across multiple member clusters](./concepts-update-orchestration.md).
* [Conceptual overview of Kubernetes resource placement from hub cluster to member clusters](./concepts-resource-propagation.md).
* [Conceptual overview of Multi-cluster layer-4 load balancing](./concepts-l4-load-balancing.md).
* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
