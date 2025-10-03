---
title: "Use Managed Namespaces to control user access and resource quotas across multiple clusters (preview)"
description: This article provides a conceptual overview of multi-cluster managed namespaces (preview) using an Azure Kubernetes Service (AKS) Fleet Manager.
ms.date: 09/16/2025
author: audrastump
ms.author: stumpaudra
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Managed Namespaces to control user access and resource quotas across multiple clusters (preview)

This article provides a conceptual overview of multi-cluster managed namespaces. AKS managed namespaces provide a way to logically isolate workloads within a single cluster. Multi-cluster managed namespaces extend this capability across multiple AKS clusters in a fleet. Using multi-cluster managed namespaces, platform administrators can define resource quotas, enforce network policy, and control access to namespace resources across multiple clusters within a fleet.

## Network policies

[Network policies](../aks/use-network-policies.md) control traffic between pods, namespaces, and external endpoints. Users may independently select one of three built-in network policies for ingress and egress traffic. If omitted, no network policy is applied to the namespace.

* *Allow all*: Allow all network traffic
* *Allow same namespace*: Allow all network traffic within the same namespace
* *Deny all*: Deny all network traffic

While platform administrators can set default network policies through the managed namespace configuration, users with sufficient permissions can modify or relax these policies directly on the member clusters.
For example, anyone with "Azure Kubernetes Service RBAC Writer" role on the namespace can modify NetworkPolicy resources.

> [!NOTE]
> Network policies are applied to each cluster individually and do not control cross-cluster network traffic for the namespace. Each member cluster enforces its own network policy independently within its local namespace instance.

## Resource quotas
Platform administrators may use [resource quotas](../aks/concepts-managed-namespaces.md#resource-quotas) to cap CPU and memory consumption at the namespace layer. In multi-cluster managed namespaces, admins can optionally set minimum and maximum boundaries for resources used by workloads in a namespace.
* CPU requests and limits: Set the minimum and maximum CPU resources that workloads in the namespace can request or consume.
* Memory requests and limits: Set the minimum and maximum memory resources that workloads in the namespace can request or consume.

## Labels and annotations
Kubernetes [labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) are key/value pairs users can attach to the managed namespace. Labels are used to organize and query subsets of objects, in this case, managed namespaces. By default, each managed namespace has a built-in label indicating it is managed by ARM.

Annotations, on the other hand, are used to attach nonidentifying, potentially unstructured metadata to an object. Users may also apply annotations to their managed namespaces.

## Adoption Policy
The adoption policy determines how an existing namespace in Kubernetes is handled when you create a managed namespace. Similar to a [single cluster namespace](../aks/concepts-managed-namespaces.md#adoption-policy), the following options are available:

* *Never*: Managed namespace creation fails if a namespace with the same name already exists in the cluster.
* *IfIdentical*: Managed namespace creation fails if a namespace with the same name already exists in the cluster, unless the namespaces are identical. If the namespaces are identical, ARM takes over the existing namespace to be managed.
* *Always*: ARM always takes over the existing namespace, even if some fields in the namespace are overwritten.

> [!NOTE]
> During adoption, ARM may take over a fields on a namespace on a member cluster, but it will not remove the resources from the namespace.

## Delete policy
The [delete policy](../aks/concepts-managed-namespaces.md#delete-policy) controls how the Kubernetes namespace is handled when the managed namespace resource is deleted. There are two built-in options:

* *Keep*: Removes only the managed namespace resource, leaving the Kubernetes namespace intact on the hub and member clusters, but removes the `ManagedByARM` label.
* *Delete*: Removes both the managed namespace resource and the Kubernetes namespace from the hub and member clusters.

> [!NOTE]
> A delete policy of **Delete** will completely remove the Kubernetes namespace resource, even if it existed prior to, and was adopted by the multi-cluster managed namespace.

## Cluster Resource Placement
If the user specifies member clusters during namespace creation or update, the managed namespace generates a read-only Cluster Resource Placement (CRP) object to propagate the namespace to the selected member clusters. The placement policy used is [PickFixed](./concepts-resource-propagation.md#pickfixed-placement-type). The adoption policy determines whether an unmanaged namespace is taken over when a managed namespace with the same name is propagated to a member cluster.
1. *Always*: Overwrites the existing member cluster namespace with the multi-cluster managed namespace.
2. *IfIdentical*: Overwrites the existing member cluster namespace with the multi-cluster managed namespace if there are no configuration differences.
3. *Never*: Never takes over an unmanaged namespace.

## Multi-cluster managed namespace built-in roles
Multi-cluster managed namespaces use the existing ARM Role Based Access Control (RBAC) [control plane roles](./concepts-rbac.md#control-plane) to manage and access managed namespaces. The existing [data plane RBAC roles](./concepts-rbac.md#data-plane) are applied to interact with the managed namespace created on the Fleet Manager hub cluster. 

To control access to a managed namespace on member clusters, managed namespaces use the following built-in roles:

| Role | Description |
|------|-------------|
| Azure Kubernetes Fleet Manager RBAC Reader for Member Clusters | Read-only access to most objects in the namespace on the member cluster. Cannot view roles or role bindings. Cannot view Secrets (prevents privilege escalation via ServiceAccount credentials). |
| Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters | Read and write access to most Kubernetes resources in the namespace. Cannot view or modify roles or role bindings. Can read Secrets (therefore can assume any ServiceAccount in the namespace). |
| Azure Kubernetes Fleet Manager RBAC Admin for Member Clusters | Read and write access to Kubernetes resources in the namespace on the member cluster. |
| Azure Kubernetes Fleet Manager RBAC Cluster Admin for Member Clusters | Full read/write access to all Kubernetes resources on the member cluster. |

## Next steps
Learn how to [create and use a multi-cluster managed namespace](./howto-managed-namespaces.md).
Learn how to [view managed namespaces you have access to](./howto-managed-namespaces-access.md).
