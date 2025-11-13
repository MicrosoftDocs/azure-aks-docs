---
title: "Using ResourcePlacement to deploy namespace-scoped resources (preview)"
titleSuffix: Azure Kubernetes Fleet Manager
description: This article describes the ResourcePlacement API, which enables fine-grained control over namespace-scoped Kubernetes resources across member clusters.
ms.date: 11/12/2025
author: weiweng
ms.author: weiweng
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As an application developer, I want to propagate specific namespace-scoped resources from a hub cluster to selected member clusters, so that I can manage individual workloads and configurations independently within shared namespaces.
---

# Using ResourcePlacement to deploy namespace-scoped resources (preview)

This article describes the `ResourcePlacement` API, which enables fine-grained control over namespace-scoped Kubernetes resources across member clusters using Azure Kubernetes Fleet Manager.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Overview

`ResourcePlacement` is a namespace-scoped API that enables dynamic selection and multi-cluster propagation of namespace-scoped resources. It provides fine-grained control over how specific resources within a namespace are distributed across member clusters in a fleet.

> [!IMPORTANT]
> `ResourcePlacement` uses the `placement.kubernetes-fleet.io/v1beta1` API version and is currently in preview. Some features demonstrated in this article, such as `selectionScope` in `ClusterResourcePlacement`, are also part of the v1beta1 API and isn't available in the v1 API.

**Key characteristics:**

- **Namespace-scoped**: Both the `ResourcePlacement` object and the resources it manages exist within the same namespace.
- **Selective**: Can target specific resources by type, name, or labels rather than entire namespaces.
- **Declarative**: Uses the same placement patterns as `ClusterResourcePlacement` for consistent behavior.

A `ResourcePlacement` consists of three core components:

- **Resource Selectors**: Define which namespace-scoped resources to include.
- **Placement Policy**: Determine target clusters using `PickAll`, `PickFixed`, or `PickN` strategies.
- **Rollout Strategy**: Control how changes propagate across selected clusters.

## When to use ResourcePlacement

`ResourcePlacement` is ideal for scenarios requiring granular control over namespace-scoped resources:

- **Selective resource distribution**: Deploy specific ConfigMaps, Secrets, or Services without affecting the entire namespace.
- **Multi-tenant environments**: Allow different teams to manage their resources independently within shared namespaces.
- **Configuration management**: Distribute environment-specific configurations across different cluster environments.
- **Compliance and governance**: Apply different policies to different resource types within the same namespace.
- **Progressive rollouts**: Safely deploy resource updates across clusters with zero-downtime strategies.

In multi-cluster environments, workloads often consist of both cluster-scoped and namespace-scoped resources that need to be distributed across different clusters. While `ClusterResourcePlacement` (CRP) handles cluster-scoped resources effectively, entire namespaces and their contents, there are scenarios where you need more granular control over namespace-scoped resources within existing namespaces.

`ResourcePlacement` (RP) was designed to address this gap by providing:

- **Namespace-scoped resource management**: Target specific resources within a namespace without affecting the entire namespace.
- **Operational flexibility**: Allow teams to manage different resources within the same namespace independently.
- **Complementary functionality**: Work alongside CRP to provide a complete multi-cluster resource management solution.

> [!NOTE]
> `ResourcePlacement` can be used together with `ClusterResourcePlacement` in namespace-only mode. For example, you can use CRP to deploy the namespace, while using RP for fine-grained management of specific resources like environment-specific ConfigMaps or Secrets within that namespace.

### Real-world namespace usage patterns

While CRP assumes that namespaces represent application boundaries, real-world usage patterns are often more complex. Organizations frequently use namespaces as team boundaries rather than application boundaries, leading to several challenges that `ResourcePlacement` directly addresses:

**Multi-application namespaces**: In many organizations, a single namespace contains multiple independent applications owned by the same team. These applications might have:

- Different lifecycle requirements (one application might need frequent updates while another remains stable).
- Different cluster placement needs (development vs. production applications).
- Independent scaling and resource requirements.
- Separate compliance or governance requirements.

**Individual scheduling decisions**: Many workloads, particularly AI/ML jobs, require individual scheduling decisions:

- **AI Jobs**: Machine learning workloads often consist of short-lived, resource-intensive jobs that need to be scheduled based on cluster resource availability, GPU availability, or data locality.
- **Batch Workloads**: Different batch jobs within the same namespace might target different cluster types based on computational requirements.

**Complete application team control**: `ResourcePlacement` provides application teams with direct control over their resource placement without requiring platform team intervention:

- **Self-service operations**: Teams can manage their own resource distribution strategies.
- **Independent deployment cycles**: Different applications within a namespace can have independent rollout schedules.
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

Both `ResourcePlacement` and `ClusterResourcePlacement` share the same core capabilities for all other aspects not listed in the differences table.

## Working with ClusterResourcePlacement

`ResourcePlacement` is designed to work in coordination with `ClusterResourcePlacement` (CRP) to provide a complete multi-cluster resource management solution. Understanding this relationship is crucial for effective fleet management.

### Namespace prerequisites

> [!IMPORTANT]
> `ResourcePlacement` can only place namespace-scoped resources to clusters that already have the target namespace. We recommend using `ClusterResourcePlacement` for namespace establishment.

**Typical workflow**:

1. **Platform Admin**: Uses `ClusterResourcePlacement` to deploy namespaces across the fleet.
2. **Application Teams**: Use `ResourcePlacement` to manage specific resources within those established namespaces.

The following examples show how to coordinate CRP and RP:

> [!NOTE]
> The following examples use the `placement.kubernetes-fleet.io/v1beta1` API version. The `selectionScope: NamespaceOnly` field is a preview feature available in v1beta1 and isn't available in the v1 API.

**Platform Admin**: First, create the namespace using `ClusterResourcePlacement`:

```yaml
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
    placementType: PickAll # If placement type is not PickAll, the application teams needs to know what are the clusters they can place their applications.
```

**Application Team**: Then, manage specific resources within the namespace using `ResourcePlacement`:

```yaml
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

## Resource selection, placement, and rollout

`ResourcePlacement` uses the same placement patterns as `ClusterResourcePlacement`:

- **[Placement types](./concepts-resource-propagation.md#placement-types)**: `PickAll`, `PickFixed`, and `PickN` strategies work identically for both APIs.
- **[Rollout strategy](./concepts-rollout-strategy.md)**: Control how updates propagate across clusters with the same rolling update mechanisms.
- **[Status and observability](./howto-understand-placement.md)**: Monitor deployment progress using `kubectl describe resourceplacement <name> -n <namespace>`.
- **[Advanced features](./concepts-resource-propagation.md)**: Use tolerations, resource overrides, topology spread constraints, and affinity rules.

The key difference is in **resource selection** scope. While `ClusterResourcePlacement` typically selects entire namespaces and their contents, `ResourcePlacement` provides fine-grained control over individual namespace-scoped resources.

For complete details on these capabilities, refer to the [ClusterResourcePlacement documentation](./concepts-resource-propagation.md#resource-selection).

## Next steps

- [Using ClusterResourcePlacement to deploy cluster-scoped resources](./concepts-resource-propagation.md)
- [Multi-cluster resource placement using cluster resource placement](./quickstart-resource-propagation.md)
- [Use overrides to customize namespace-scoped resources](./resource-override.md)
- [Defining a rollout strategy for resource placement](./concepts-rollout-strategy.md)
- [Cluster resource placement FAQs](./faq.md#cluster-resource-placement-faqs)
