---
title: "Azure Kubernetes Fleet Manager resource management across multiple clusters using hub cluster as the control plane"
description: "This article describes the concept of Kubernetes resource management using hub clusters as the control plane with Azure Kubernetes Fleet Manager."
ms.date: 07/08/2025
author: zhangryan
ms.author: zhangryan
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---

# Azure Kubernetes Fleet Manager resource management across multiple clusters using hub cluster as the control plane

This article describes the concept of Kubernetes resource management using hub clusters as the control plane with Azure Kubernetes Fleet Manager.

## Overview

Managing Kubernetes resources across multiple clusters presents significant challenges for both platform administrators and application developers. As organizations scale their Kubernetes infrastructure beyond a single cluster, they often encounter complexities related to resource distribution, consistency maintenance, and manual management overhead. The traditional approach of managing each cluster independently creates operational silos that become increasingly difficult to maintain as the fleet size grows.

## Multi-cluster management challenges

The transition from a few clusters to multi-cluster Kubernetes infrastructure introduces a new category of operational challenges that extend beyond traditional container orchestration. These challenges manifest differently for various stakeholder groups within an organization, each with distinct requirements and constraints.

**Platform administrators** often need to deploy Kubernetes resources onto multiple clusters for various reasons, for example:

- **Running infrastructure applications**: Critical system components such as monitoring solutions (Prometheus, Grafana), continuous deployment tools (Flux, ArgoCD), network policies, security scanners, and logging aggregators must be consistently deployed across all clusters to maintain operational visibility and compliance.
- **Resource optimization**: Organizations want to have better utilization of clusters with different characteristics including varying cost profiles (spot instances vs. on-demand), specialized hardware capabilities (GPU-enabled nodes, high-memory instances), and performance tiers to optimize workload placement based on requirements and budget constraints.
- **Compliance and governance**: Regulatory frameworks mandate specific data residency requirements, security controls, and audit capabilities that necessitate careful cluster selection and resource placement strategies.

Similarly, **Application developers** often need to deploy Kubernetes resources onto multiple clusters for various reasons, for example:

- **Geographic distribution**: Modern applications often prefer proximity to end users to minimize latency, comply with data sovereignty requirements, and provide optimal user experiences. The proximity preference necessitates deploying application components across multiple geographic regions while maintaining consistency and coordination.
- **High availability**: Business-critical applications must maintain service availability even during regional outages, infrastructure failures, or planned maintenance windows. Cross-region deployments with automated failover capabilities ensure business continuity and meet stringent Service Level Agreement (SLA) requirements.

The complexity of manual multi-cluster management becomes apparent when organizations attempt to scale beyond a few clusters. Manual processes that work for small cluster fleets quickly become bottlenecks as the infrastructure grows.

### Manual multi-cluster management challenges

- **Operational complexity**: The administrative burden of creating, updating, and tracking resources individually across multiple clusters grows exponentially with fleet size. Each cluster requires separate authentication, context switching, and manual verification, leading to increased time investment and higher probability of human error.
- **Configuration drift**: Without centralized control mechanisms, manual processes inevitably lead to inconsistencies between clusters over time. These inconsistencies can manifest as different resource versions, varying configurations, or missing components, creating unpredictable behavior and debugging challenges.
- **Scalability limitations**: Manual processes that function adequately for small fleets become increasingly impractical as organizations scale to dozens or hundreds of clusters. The linear increase in management overhead eventually exceeds available administrative capacity.
- **Lack of visibility**: Comprehensive tracking of resources versions, resource health, and operational metrics across multiple clusters requires significant coordination and custom tooling. Without centralized observability, teams struggle to maintain situational awareness and respond effectively to issues.

## Overall architecture for multi-cluster resource management

Azure Kubernetes Fleet Manager addresses the fundamental challenges of multi-cluster resource management through a comprehensive platform that is built on an [open source cloud-native project][kubefleet] and Kubernetes-native APIs. The solution utilizes the power and flexibility of Custom Resource Definitions (CRDs) to extend Kubernetes' declarative model to multi-cluster scenarios. This approach maintains the familiar Kubernetes operational model while extending its capabilities to handle fleet-scale operations. Here are some of the key principles and advantages of the solution:

### Hub-and-spoke control plane

The hub-and-spoke architecture designates a centralized hub cluster as the control plane, eliminating the need to manage each cluster independently. This architectural pattern provides:
- **Centralized Management**: A single point of control for fleet-wide operations, reducing administrative overhead.
- **Consistent API Experience**: Uniform interaction across the entire infrastructure, ensuring ease of use.
- **Enhanced Observability**: Centralized monitoring and management capabilities for better situational awareness and faster issue resolution.

### Kubernetes-native extension model

Built on the [CNCF project][kubefleet], the solution extends Kubernetes' declarative model through Custom Resource Definitions (CRDs) rather than replacing it. This ensures:
- **Familiarity**: Kubernetes practitioners can leverage existing knowledge and tools.
- **Compatibility**: Seamless integration with existing Kubernetes workflows and tooling.
- **Cloud-Native Alignment**: Adherence to cloud-native principles and compatibility with the CNCF ecosystem.

### Advanced scheduling and rollout strategies

The solution incorporates advanced scheduling mechanisms and progressive rollout strategies, enabling:
- **Declarative Placement Policies**: Placement of workloads based on cluster characteristics such as cost, resource availability, and geographic location.
- **Progressive Rollouts**: Controlled deployment of updates with safety mechanisms to minimize risks.
- **Drift Management**: Ensures consistent resource versions and configurations across clusters, reducing operational inconsistencies.

### Key advantages

By adopting Azure Kubernetes Fleet Manager, organizations can achieve:
- **Scalability**: Efficiently manage fleets of any size, from a few clusters to hundreds.
- **Operational Efficiency**: Reduce manual effort and human error through automation and centralized control.
- **Resilience**: Ensure high availability and disaster recovery through intelligent resource placement and failover strategies.

An example YAML file of how one can use Azure Kubernetes Fleet Manager API to manage multi-cluster workloads is shown in the following diagram.

[![Diagram that shows how Kubernetes resource are propagated to member clusters.](./media/conceptual-resource-propagation.png)](./media/conceptual-resource-propagation.png#lightbox)

## Next steps

* [Use cluster resource placement to manage workloads across multiple clusters](./concepts-resource-propagation.md).

<!-- LINKS - external -->
[kubefleet]: https://github.com/kubefleet-dev/kubefleet