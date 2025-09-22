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

This article provides a conceptual overview of multi-cluster managed namespaces. Previously, AKS Managed Namespaces provided a way to logically isolate workloads within a single AKS cluster via managed namespaces. Multi-cluster managed namespaces now extend this capability to isolate workloads across multiple AKS clusters. Multi-cluster managed namespaces enable platform administrators to delegate resource quotas, enforce network policy, and control access to namespaces across multiple clusters within a fleet.

## Network policies
[Network policies](../aks/concepts-managed-namespaces.md#network-policies) control traffic between pods, namespaces, and external endpoints. In multi‑cluster managed namespaces, jsers may choose a built‑in policy for each direction (ingress or egress traffic) and Azure applies it to the namespace on every selected member cluster. If omitted, no NetworkPolicy resource is created.

- Allow all
- Allow same namespace
- Deny all

## Resource quotas
Use [resource quotas](../aks/concepts-managed-namespaces.md#resource-quotas) to cap CPU and memory consumption at the namespace layer. In multi‑cluster managed namespaces, optionally set quota values once and Azure enforces the same limits on the namespace across selected member clusters.

## Labels and annotations
Add [labels and annotations](../aks/concepts-managed-namespaces.md#labels-and-annotations) to organize namespaces and attach nonidentifying metadata used by tools. In multi‑cluster managed namespaces, the values you specify are placed onto the namespace instance in each selected member cluster. Multi-cluster managed namespaces are created with a l


## Adoption Policy
The adoption policy determines how an existing namespace in Kubernetes is handled when creating a managed namespace. Similar to a [single cluster namespace](../aks/concepts-managed-namespaces.md#adoption-policy), the following options are available:

Never: If the namespace already exists in the cluster, attempts to create that namespace as a managed namespace fails.
IfIdentical: Take over the existing namespace to be managed, provided there are no differences between the existing namespace and the desired configuration.
Always: Always take over the existing namespace to be managed, even if some fields in the namespace might be overwritten.

## Delete policy
Control how the Kubernetes namespace is handled when the managed namespace resource is removed with the [delete policy](../aks/concepts-managed-namespaces.md#delete-policy).

- Keep: Remove only the managed namespace resource; leave the Kubernetes namespace intact and clear the `ManagedByARM` label.
- Delete: Remove both the managed namespace resource and the Kubernetes namespace.

# Cluster Resource Placement
When specifying

# Multi-cluster managed namespace built-in roles
Multi-cluster managed namespaces use the existing ARM RBAC control plane roles to manage and access managed namespaces. The existing 
data plane RBAC roles (TODO link) will be applied to the managed namespace created on the Fleet Manager hub cluster. 

To control access to a managed namespace on member clusters, managed namespaces use the following built-in roles:

| Role | Description |
|------|-------------|
| Azure Kubernetes Fleet Manager Member Cluster RBAC Reader | Read-only access to most objects in the namespace on the member cluster. Cannot view roles or role bindings. Cannot view Secrets (prevents privilege escalation via ServiceAccount credentials). |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Writer | Read and write access to most Kubernetes resources in the namespace. Cannot view or modify roles or role bindings. Can read Secrets (therefore can assume any ServiceAccount in the namespace). |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Admin | Read and write access to Kubernetes resources in the namespace on the member cluster. Cannot modify the `ResourceQuota` object or the namespace object itself. |
| Azure Kubernetes Fleet Manager Member Cluster RBAC Cluster Admin | Full read/write access to all Kubernetes resources on the member cluster. |