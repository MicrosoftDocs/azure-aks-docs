---
title: "Namespace-scoped resource placement using ResourcePlacement API"
description: This article describes the ResourcePlacement API, which enables fine-grained control over namespace-scoped Kubernetes resources across member clusters.
ms.date: 11/12/2025
author: weiweng
ms.author: weiweng
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As an application developer, I want to propagate specific namespace-scoped resources from a hub cluster to selected member clusters, so that I can manage individual workloads and configurations independently within shared namespaces.
---

# ResourcePlacement API for namespace-scoped resources

This article describes the `ResourcePlacement` API, which enables fine-grained control over namespace-scoped Kubernetes resources across member clusters using Azure Kubernetes Fleet Manager.

## Overview

`ResourcePlacement` is a namespace-scoped API that enables dynamic selection and multi-cluster propagation of namespace-scoped resources. It provides fine-grained control over how specific resources within a namespace are distributed across member clusters in a fleet.

**Key characteristics:**

- **Namespace-scoped**: Both the `ResourcePlacement` object and the resources it manages exist within the same namespace.
- **Selective**: Can target specific resources by type, name, or labels rather than entire namespaces.
- **Declarative**: Uses the same placement patterns as `ClusterResourcePlacement` for consistent behavior.

A `ResourcePlacement` consists of three core components:

- **Resource Selectors**: Define which namespace-scoped resources to include.
- **Placement Policy**: Determine target clusters using `PickAll`, `PickFixed`, or `PickN` strategies.
- **Rollout Strategy**: Control how changes propagate across selected clusters.

## Motivation

In multi-cluster environments, workloads often consist of both cluster-scoped and namespace-scoped resources that need to be distributed across different clusters. While `ClusterResourcePlacement` (CRP) handles cluster-scoped resources effectively, particularly entire namespaces and their contents, there are scenarios where you need more granular control over namespace-scoped resources within existing namespaces.

`ResourcePlacement` (RP) was designed to address this gap by providing:

- **Namespace-scoped resource management**: Target specific resources within a namespace without affecting the entire namespace.
- **Operational flexibility**: Allow teams to manage different resources within the same namespace independently.
- **Complementary functionality**: Work alongside CRP to provide a complete multi-cluster resource management solution.

> [!NOTE]
> `ResourcePlacement` can be used together with `ClusterResourcePlacement` in namespace-only mode. For example, you can use CRP to deploy the namespace, while using RP for fine-grained management of specific resources like environment-specific ConfigMaps or Secrets within that namespace.

### Addressing real-world namespace usage patterns

While CRP assumes that namespaces represent application boundaries, real-world usage patterns are often more complex. Organizations frequently use namespaces as team boundaries rather than application boundaries, leading to several challenges that `ResourcePlacement` directly addresses:

**Multi-application namespaces**: In many organizations, a single namespace contains multiple independent applications owned by the same team. These applications may have:

- Different lifecycle requirements (one application may need frequent updates while another remains stable).
- Different cluster placement needs (development vs. production applications).
- Independent scaling and resource requirements.
- Separate compliance or governance requirements.

**Individual scheduling decisions**: Many workloads, particularly AI/ML jobs, require individual scheduling decisions:

- **AI Jobs**: Machine learning workloads often consist of short-lived, resource-intensive jobs that need to be scheduled based on cluster resource availability, GPU availability, or data locality.
- **Batch Workloads**: Different batch jobs within the same namespace may target different cluster types based on computational requirements.

**Complete application team control**: `ResourcePlacement` provides application teams with direct control over their resource placement without requiring platform team intervention:

- **Self-service operations**: Teams can manage their own resource distribution strategies.
- **Independent deployment cycles**: Different applications within a namespace can have completely independent rollout schedules.
- **Granular override capabilities**: Teams can customize resource configurations per cluster without affecting other applications in the namespace.

This granular approach ensures that `ResourcePlacement` can adapt to diverse organizational structures and workload patterns while maintaining the simplicity and power of the Fleet scheduling framework.

## Key differences between ResourcePlacement and ClusterResourcePlacement

The following table highlights the key differences between `ResourcePlacement` and `ClusterResourcePlacement`:

| Aspect | ResourcePlacement (RP) | ClusterResourcePlacement (CRP) |
|--------|------------------------|--------------------------------|
| **Scope** | Namespace-scoped resources only | Cluster-scoped resources (especially namespaces and their contents) |
| **Resource** | Namespace-scoped API object | Cluster-scoped API object |
| **Selection Boundary** | Limited to resources within the same namespace as the RP | Can select any cluster-scoped resource |
| **Typical Use Cases** | AI/ML Jobs, individual workloads, specific ConfigMaps/Secrets that need independent placement decisions | Application bundles, entire namespaces, cluster-wide policies |
| **Team Ownership** | Can be managed by namespace owners/developers | Typically managed by platform operators |

## Similarities between ResourcePlacement and ClusterResourcePlacement

Both RP and CRP share the same core concepts and capabilities:

- **Placement Policies**: Same three placement types (`PickAll`, `PickFixed`, `PickN`) with identical scheduling logic.
- **Resource Selection**: Both support selection by group/version/kind, name, and label selectors.
- **Rollout Strategy**: Identical rolling update mechanisms for zero-downtime deployments.
- **Scheduling Framework**: Use the same multi-cluster scheduler with filtering, scoring, and binding phases.
- **Override Support**: Both integrate with `ClusterResourceOverride` and `ResourceOverride` for resource customization.
- **Status Reporting**: Similar status structures and condition types for placement tracking.
- **Tolerations**: Same taints and tolerations mechanism for cluster selection.
- **Snapshot Architecture**: Both use immutable snapshots (`ResourceSnapshot` vs `ClusterResourceSnapshot`) for resource and policy tracking.

This design allows teams familiar with one placement object to easily understand and use the other, while providing the appropriate level of control for different resource scopes.

## When to use ResourcePlacement

`ResourcePlacement` is ideal for scenarios requiring granular control over namespace-scoped resources:

- **Selective resource distribution**: Deploy specific ConfigMaps, Secrets, or Services without affecting the entire namespace.
- **Multi-tenant environments**: Allow different teams to manage their resources independently within shared namespaces.
- **Configuration management**: Distribute environment-specific configurations across different cluster environments.
- **Compliance and governance**: Apply different policies to different resource types within the same namespace.
- **Progressive rollouts**: Safely deploy resource updates across clusters with zero-downtime strategies.

## Working with ClusterResourcePlacement

`ResourcePlacement` is designed to work in coordination with `ClusterResourcePlacement` (CRP) to provide a complete multi-cluster resource management solution. Understanding this relationship is crucial for effective fleet management.

### Namespace prerequisites

> [!IMPORTANT]
> `ResourcePlacement` can only place namespace-scoped resources to clusters that already have the target namespace. This creates a fundamental dependency on `ClusterResourcePlacement` for namespace establishment.

**Typical workflow**:

1. **Fleet Admin**: Uses `ClusterResourcePlacement` to deploy namespaces across the fleet.
2. **Application Teams**: Use `ResourcePlacement` to manage specific resources within those established namespaces.

The following example shows how to coordinate CRP and RP:

```yaml
# Fleet admin creates namespace using CRP
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: app-namespace-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
      selectionScope: NamespaceOnly # only namespace itself is placed, no resources within the namespace
  policy:
    placementType: PickAll
---
# Application team manages resources using RP
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: app-configs-rp
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickFixed
    clusterNames: ["prod-cluster-1", "prod-cluster-2"]
```

### Best practices

When using `ResourcePlacement` with `ClusterResourcePlacement`, follow these best practices:

- **Establish namespaces first**: Always ensure namespaces are deployed via CRP before creating `ResourcePlacement` objects.
- **Monitor dependencies**: Use Fleet monitoring to ensure namespace-level CRPs are healthy before deploying dependent RPs.
- **Coordinate policies**: Align CRP and RP placement policies to avoid conflicts (for example, if CRP places namespace on clusters A, B, C, RP can target any subset of those clusters).
- **Team boundaries**: Use CRP for platform-managed resources (namespaces, RBAC) and RP for application-managed resources (app configs, secrets).

This coordinated approach ensures that `ResourcePlacement` provides the flexibility teams need while maintaining the foundational infrastructure managed by platform operators.

## Placement types

`ResourcePlacement` supports the same placement types as `ClusterResourcePlacement`. For detailed information about each placement type, see the [ClusterResourcePlacement placement types documentation](./concepts-resource-propagation.md#placement-types).

The following placement types are available:

- **[PickFixed](./concepts-resource-propagation.md#pickfixed-placement-type)**: Places resources onto a specific list of member clusters by name.
- **[PickAll](./concepts-resource-propagation.md#pickall-placement-type)**: Places resources onto all member clusters, or all member clusters that meet criteria.
- **[PickN](./concepts-resource-propagation.md#pickn-placement-type)**: Flexible placement option with selection based on affinity or topology spread constraints.

## Resource selection

`ResourcePlacement` supports selecting namespace-scoped resources using the following criteria:

- **Group, Version, Kind (GVK)**: Specify the exact type of Kubernetes resource.
- **Name**: Target specific resources by name.
- **Label selectors**: Select resources based on labels.

The following example shows selecting ConfigMaps with specific labels:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: config-placement
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          environment: production
          component: frontend
  policy:
    placementType: PickAll
```

## Rollout strategy

`ResourcePlacement` uses the same rolling update strategy as `ClusterResourcePlacement` to control how updates are rolled out across clusters. For detailed information, see the [rollout strategy documentation](./concepts-rollout-strategy.md).

The following example shows a rolling update configuration:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: app-deployment-rp
  namespace: my-app
spec:
  resourceSelectors:
    - group: apps
      kind: Deployment
      version: v1
      name: frontend
  policy:
    placementType: PickN
    numberOfClusters: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
      unavailablePeriodSeconds: 60
```

## Status and observability

`ResourcePlacement` provides comprehensive status reporting to track deployment progress:

- **Overall status**: High-level conditions indicating scheduling, rollout, and availability states.
- **Per-cluster status**: Individual status for each target cluster showing detailed progress.
- **Events**: Timeline of placement activities and any issues encountered.

You can view the status using the `kubectl describe` command:

```bash
kubectl describe resourceplacement <name> -n <namespace>
```

The output includes:

- Placement conditions (scheduled, synchronized, applied)
- Per-cluster placement status
- Selected resources
- Events and state transitions

For more information on understanding placement status, see the [placement status documentation](./howto-understand-placement.md).

## Advanced features

`ResourcePlacement` supports the same advanced features as `ClusterResourcePlacement`:

- **[Tolerations](./use-taints-tolerations.md)**: Use tolerations to control which clusters can receive placements.
- **[Resource overrides](./resource-override.md)**: Customize namespace-scoped resources per cluster.
- **[Topology spread constraints](./concepts-resource-propagation.md#pickn-with-topology-spread-constraints)**: Distribute resources across topology boundaries.
- **[Affinity and anti-affinity](./concepts-resource-propagation.md#pickn-with-affinities)**: Control resource placement based on cluster properties.

## Next steps

- [Introduction to ClusterResourcePlacement API](./concepts-resource-propagation.md)
- [Multi-cluster resource placement using cluster resource placement](./quickstart-resource-propagation.md)
- [Use overrides to customize namespace-scoped resources](./resource-override.md)
- [Defining a rollout strategy for resource placement](./concepts-rollout-strategy.md)
- [Cluster esource placement FAQs](./faq.md#cluster-resource-placement-faqs)
