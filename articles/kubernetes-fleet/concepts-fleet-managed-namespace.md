---
title: "Use Managed Namespaces to control user access and resource quotas across multiple clusters (preview)"
description: This article provides a conceptual overview of multi-cluster managed namespaces (preview) using Azure Kubernetes Service (AKS) Fleet Manager.
ms.date: 09/16/2025
author: audrastump
ms.author: stumpaudra
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Managed Namespaces to control user access and resource quotas across multiple clusters (preview)

This article provides a conceptual overview of multi-cluster managed namespaces. AKS managed namespaces provide a way to logically isolate workloads within a single cluster. Multi-cluster managed namespaces extend this capability across multiple AKS clusters in a fleet. 

Using multi-cluster managed namespaces, platform administrators can define resource quotas, network policies, and control access to namespace resources, then specify which member clusters should receive the namespace. Fleet Manager automatically places the namespace and its associated resources on the hub cluster and designated member clusters.

If the user specifies member clusters during namespace creation or update, the managed namespace generates a read-only Cluster Resource Placement (CRP) object, with a [PickFixed](./concepts-resource-propagation.md#pickfixed-placement-type) placement policy, to propagate the namespace to the selected member clusters. 

## Resource quotas

Platform administrators may use [resource quotas](../aks/concepts-managed-namespaces.md#resource-quotas) to cap CPU and memory consumption at the namespace layer.
* CPU requests and limits: Set the minimum and maximum CPU resources that workloads in the namespace can request or consume.
* Memory requests and limits: Set the minimum and maximum memory resources that workloads in the namespace can request or consume.

> [!NOTE]
> The quotas set for a namespace are applied to each individual member cluster independently, not shared across all clusters in the namespace.

## Network policies

[Network policies](../aks/use-network-policies.md) control allowed traffic for pods within a namespace. Users may independently select one of three built-in network policies for ingress and egress traffic. If omitted, no network policy is applied to the namespace.

* *Allow all*: Allow all network traffic, including traffic between pods and external endpoints.
* *Allow same namespace*: Allow all network traffic between pods within the same namespace.
* *Deny all*: Deny all network traffic, including traffic between pods and external endpoints.

> [!NOTE]
> While platform administrators can set default network policies through the managed namespace configuration, users with sufficient permissions can create additional policies that relax the overall network policy for the namespace.

> [!NOTE]
> Network policies are applied to each cluster individually and do not control cross-cluster network traffic for the namespace. Each member cluster enforces its own network policy independently within its local namespace instance.

## Labels and annotations
Platform administrators may apply both Kubernetes [labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) and annotations to the managed namespace. By default, each managed namespace has a built-in label indicating it's managed by ARM.

## Adoption Policy
When a managed namespace is created, the adoption policy determines how existing unmanaged namespaces are handled if they already exist on the target cluster. Similar to a [single cluster namespace](../aks/concepts-managed-namespaces.md#adoption-policy), the following options are available:

* *Never*: Managed namespace creation fails if a namespace with the same name already exists in the cluster.
* *IfIdentical*: Managed namespace creation fails if a namespace with the same name already exists in the cluster, unless the namespaces are identical. If the namespaces are identical, ARM takes over the existing namespace to be managed.
* *Always*: The managed namespace always takes over the existing namespace, even if some fields in the namespace are overwritten.

During adoption a managed namespace may take over fields on a namespace on a member cluster, but it doesn't remove the resources from the namespace.

> [!NOTE] 
> Currently takeover behavior is limited to AKS cluster fleet members

## Delete policy
The [delete policy](../aks/concepts-managed-namespaces.md#delete-policy) controls how the Kubernetes namespace is handled when the managed namespace resource is deleted. There are two built-in options:

* *Keep*: Leaves the Kubernetes namespace intact on the member clusters, but removes the `ManagedByARM` label.
* *Delete*: Removes the Kubernetes namespace and all resources within it from the member clusters.

> [!NOTE]
> A delete policy of **Delete** completely removes the Kubernetes namespace resource and the resources within it from the target member clusters, even if it existed prior to, and was adopted by the multi-cluster managed namespace.

## Multi-cluster managed namespace built-in roles
Multi-cluster managed namespaces use the existing ARM Role Based Access Control (RBAC) [control plane roles](./concepts-rbac.md#control-plane) to manage and access managed namespaces. The existing [data plane RBAC roles](./concepts-rbac.md#data-plane) are applied to interact with the managed namespace created on the Fleet Manager hub cluster. 

To control access to a managed namespace on member clusters, managed namespaces use the following built-in roles, applied at the namespace scope:

| Role | Description |
|------|-------------|
| Azure Kubernetes Fleet Manager RBAC Reader for Member Clusters | Read-only access to most objects in the namespace on the member cluster. Cannot view roles or role bindings. Cannot view Secrets (prevents privilege escalation via ServiceAccount credentials). |
| Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters | Read and write access to most Kubernetes resources in the namespace. Cannot view or modify roles or role bindings. Can read Secrets (therefore can assume any ServiceAccount in the namespace). |
| Azure Kubernetes Fleet Manager RBAC Admin for Member Clusters | Read and write access to Kubernetes resources in the namespace on the member cluster. |
| Azure Kubernetes Fleet Manager RBAC Cluster Admin for Member Clusters | Full read/write access to all Kubernetes resources on the member cluster. |

## Next steps
Learn how to [create and use a multi-cluster managed namespace](./howto-managed-namespaces.md).
Learn how to [view managed namespaces you have access to](./howto-managed-namespaces-access.md).
