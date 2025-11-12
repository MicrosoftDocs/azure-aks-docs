---
title: "Use Managed Fleet Namespaces with Azure Kubernetes Fleet Manager for multi-cluster multi-tenancy"
description: This article provides a conceptual overview of multi-cluster managed namespaces using Azure Kubernetes Fleet Manager.
ms.date: 11/12/2025
author: audrastump
ms.author: stumpaudra
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Managed Fleet Namespaces for multi-cluster multi-tenancy (preview)

**Applies to** :heavy_check_mark: Fleet Manager with hub cluster

This article provides a conceptual overview of Azure Kubernetes Fleet Manager's Managed Fleet Namespaces that provide a centrally managed multi-cluster muti-tenancy solution.
 
[!INCLUDE [preview_features_note](./includes/preview/preview-callout.md)]

## What are Managed Fleet Namespaces?

When deployed on target member clusters, Managed Fleet Namespaces allow platform administrators to apply resource quotas, network policies, labels, annotations, and control access to namespace resources on each cluster. Managed Fleet Namespaces extend the capability of [Managed Kubernetes Namespace](../aks/concepts-managed-namespaces.md), which provide a way to logically isolate workloads within a single AKS cluster. 

Managed Fleet Namespaces use a generated, read-only, Fleet Manager [Cluster Resource Placement](concepts-resource-propagation.md) (CRP) to propagate the centrally defined namespace to selected member clusters. 

When creating a Fleet Managed Namespace, you can also control: 

* Adoption Policy: Defines how conflicts are resolved when a Managed Fleet Namespace is placed on a member cluster where an unmanaged namespace or Managed Kubernetes Namespace exists with the same name.
* Delete Policy: Defines whether Kubernetes resources are deleted upon Managed Fleet Namespace Azure resource deletion.

## Setting resource quotas

Platform administrators can use [resource quotas](../aks/concepts-managed-namespaces.md#resource-quotas) to cap CPU and memory consumption at the namespace level. If omitted, no resource quota is applied to the namespace.

- **CPU requests and limits**: Set the minimum and maximum CPU resources that workloads in the namespace can request or consume.
- **Memory requests and limits**: Set the minimum and maximum memory resources that workloads in the namespace can request or consume.

> [!NOTE]
> The quotas set for a namespace are applied to each individual member cluster independently, not shared across all clusters running the namespace.

## Setting network policies

[Network policies](../aks/use-network-policies.md) control allowed traffic for pods within a namespace. You can independently select one of three built-in network policies for ingress and egress traffic. If omitted, no network policy is applied to the namespace.

Network policies are applied to each cluster individually and don't control cross-cluster network traffic for the namespace. Each member cluster enforces its own network policy independently within its local namespace instance. Network policies include:

- **Allow all**: Allow all network traffic, including traffic between pods and external endpoints.
- **Allow same namespace**: Allow all network traffic between pods within the same namespace.
- **Deny all**: Deny all network traffic, including traffic between pods and external endpoints.

> [!NOTE]
> Managed Fleet Namespaces set default network policies, but namespace users with sufficient permissions can add extra policies that relax the overall network policy for the namespace. This behavior matches the standard additive behavior of Kubernetes network policies.

## Labels and annotations

You can apply both Kubernetes [labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) and annotations to the Managed Fleet Namespace. By default, each managed namespace has a built-in label indicating it's managed by ARM.

## Adoption policy

When a Managed Fleet Namespace is created, the adoption policy determines how existing unmanaged or Managed Kubernetes Namespaces are handled if they already exist on the target cluster. The following options are available:

- **Never**: Managed namespace creation fails if a namespace with the same name already exists in the cluster.
- **IfIdentical**: Managed namespace creation fails if a namespace with the same name already exists in the cluster, unless the namespaces are identical. If the namespaces are identical, Fleet Manager takes over the existing namespace to be managed.
- **Always**: The managed namespace always takes over the existing namespace, even if some resources in the namespace are overwritten.

During adoption a Managed Fleet Namespace can take over fields on an existing namespace on a member cluster, but it doesn't remove resources from the namespace.

## Delete policy

The [delete policy](../aks/concepts-managed-namespaces.md#delete-policy) controls how the Kubernetes namespace is handled when the Managed Fleet Namespace Azure resource is deleted. There are two built-in options:

* **Keep**: Leaves the Kubernetes namespace intact on member clusters, but removes the `ManagedByARM` label.
* **Delete**: Removes the Kubernetes namespace and all resources within it from member clusters.

> [!WARNING]
> A delete policy of **Delete** completely removes the Kubernetes namespace resource and the resources within it from the target member clusters, even if it previously existed and was adopted by the Managed Fleet Namespace.

## Managed Fleet Namespace built-in roles

Managed Fleet Namespaces use existing Azure Role Based Access Control (RBAC) [control plane roles](./concepts-rbac.md#control-plane) to manage and access managed namespaces. The existing [data plane RBAC roles](./concepts-rbac.md#data-plane) are applied to interact with the Managed Fleet Namespace instance created on the Fleet Manager hub cluster. 

To control access to a Managed Fleet Namespace on member clusters, use the following built-in roles, which can be applied at the namespace scope:

| Role | Description |
|------|-------------|
| Azure Kubernetes Fleet Manager RBAC Reader for Member Clusters | • Read-only access to most objects in the namespace on the member cluster.<br> • Can't view roles or role bindings.<br> • Can't view secrets (prevents privilege escalation via `ServiceAccount` credentials). |
| Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters | • Read and write access to most Kubernetes resources in the namespace.<br> • Can't view or modify roles or role bindings.<br> • Can read secrets (and can assume any `ServiceAccount` in the namespace). |
| Azure Kubernetes Fleet Manager RBAC Admin for Member Clusters | • Read and write access to Kubernetes resources in the namespace on the member cluster. |
| Azure Kubernetes Fleet Manager RBAC Cluster Admin for Member Clusters | • Full read/write access to all Kubernetes resources on the member cluster. |

For example, a developer in `team-A` which uses the `team-A` Managed Fleet Namespace would need to read and write Kubernetes resources in the namespace on the Fleet Manager hub cluster. The developer would also need to read Kubernetes objects in the `team-A` namespace on the member clusters on which it exists. So, the platform administrator would assign them **Azure Kubernetes Fleet Manager RBAC Writer** at the fleet scope and **Azure Kubernetes Fleet Manager RBAC Reader for Member Clusters** at the Managed Fleet Namespace scope for these respective requirements.

## Next steps

- Learn how to [create and use a Managed Fleet Namespace](./howto-managed-namespaces.md).
- Learn how to [view and access Managed Fleet namespaces you have access to](./howto-managed-namespaces-access.md)
