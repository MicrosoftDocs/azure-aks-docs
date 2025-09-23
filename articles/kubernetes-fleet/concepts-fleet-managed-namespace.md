---
title: "Multi-cluster Managed Namespaces"
description: This article provides a conceptual overview of multi-cluster managed namespaces (preview) using an Azure Kubernetes Service (AKS) Fleet Manager.
ms.date: 09/16/2025
author: audrastump
ms.author: stumpaudra
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Overview of Multi-cluster Managed Namespaces (preview)

This article provides a conceptual overview of multi-cluster managed namespaces. AKS Managed Namespaces provide a way to logically isolate workloads within a single AKS cluster via managed namespaces. Multi-cluster managed namespaces now extend this capability to isolate workloads across multiple AKS clusters. Using multi-cluster managed namespaces, platform administrators can define resource quotas, enforce network policy, and control access to namespaces resources across multiple clusters within a fleet.

## Network policies
[Network policies](../aks/use-network-policies.md) control traffic between pods, namespaces, and external endpoints. Users may choose between three built-in network policies for ingress and egress traffic. If omitted, no network policy is applied to the namespace.

* Allow all: Allow all network traffic
* Allow same namespace: Allow all network traffic within the same namespace
* Deny all: Denies all network traffic 

## Resource quotas
Platform administrators may use [resource quotas](../aks/concepts-managed-namespaces.md#resource-quotas) to cap CPU and memory consumption at the namespace layer. In multi‑cluster managed namespaces, admins can optionally set boundaries for the minimum and maximum amount of resources used by workloads in a namespace. 
* CPU requests and limits: Define the minimum and maximum amount of CPU resources that workloads in the namespace can request or consume. 
* Memory requests and limits: Define the minimum and maximum amount of memory resources that workloads in the namespace can request or consume. 
## Labels and annotations
Kubernetes [labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) are key/value pairs users can attach to the managed namespace. Labels are used to organize and query subsets of objects, in this case, managed namespaces. By default, each managed namespace has a built-in label indicated it's a managed by ARM.

On the other hand, [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) are used to attach nonidentifying, potentially unstructured metadata to an object. Users may also apply annotations to their managed namespaces.

## Adoption Policy
The adoption policy determines how an existing namespace in Kubernetes is handled when creating a managed namespace. Similar to a [single cluster namespace](../aks/concepts-managed-namespaces.md#adoption-policy), the following options are available:

* Never: Managed namespace creation fails if a namespace with the same name already exists in the cluster.
* IfIdentical: Managed namespace creation fails if a namespace with the same name already exists in the cluster unless the namespaces are identical. If the namespaces are identical, ARM takes over the existing namespace to be managed.
* Always: ARM always takes over the existing namespace to be managed, even if some fields in the namespace might be overwritten.

## Delete policy
The [delete policy](../aks/concepts-managed-namespaces.md#delete-policy) controls how the Kubernetes namespace is handled when the managed namespace resource is deleted. There are two built-in options:

* Keep: Removes only the managed namespace resource. Leaves the Kubernetes namespace intact on the hub and member clusters but removes the `ManagedByARM` label.
* Delete: Removes both the managed namespace resource and the Kubernetes namespace from the hub and member clusters. 

# Cluster Resource Placement
If the user specifies member clusters during namespace creation or update, the managed namespace generates a read-only Cluster Resource Placement (CRP) object that propagates the namespace to the selected member clusters. The placement policy is [PickFixed](./concepts-resource-propagation.md#pickfixed-placement-type). The adoption policy determines whether an unmanaged namespace is taken over when a managed namespace with the same name is propagated to a member cluster.
1. Always: Overwrites existing member cluster namespace with multi-cluster managed namespace using whenToTakeOver property of Always.
2. IfIdentical: Overwrites existing member cluster namespace with multi-cluster managed namespace if there are no configuration differences using whenToTakeOver property of IfNoDiff.
3. Never: Never takes over unmanaged namespace.

# Multi-cluster managed namespace built-in roles
Multi-cluster managed namespaces use the existing ARM Role Based Access Control (RBAC) control plane roles to manage and access managed namespaces. The existing data plane RBAC roles (TODO link) are applied to the managed namespace created on the Fleet Manager hub cluster. 

To control access to a managed namespace on member clusters, managed namespaces use the following built-in roles:

| Role | Description |
|------|-------------|
| Azure Kubernetes Fleet Manager Member Cluster RBAC Reader | Read-only access to most objects in the namespace on the member cluster. Cannot view roles or role bindings. Cannot view Secrets (prevents privilege escalation via ServiceAccount credentials). |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Writer | Read and write access to most Kubernetes resources in the namespace. Cannot view or modify roles or role bindings. Can read Secrets (therefore can assume any ServiceAccount in the namespace). |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Admin | Read and write access to Kubernetes resources in the namespace on the member cluster. Cannot modify the `ResourceQuota` object or the namespace object itself. |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Cluster Admin | Full read/write access to all Kubernetes resources on the member cluster. |

# Next steps
Learn how to [create and use a multi-cluster managed namespace](./howto-managed-namespaces.md).
