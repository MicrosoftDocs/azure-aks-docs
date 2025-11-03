---
title: Overview of managed identities in Azure Kubernetes Service (AKS)
description: This article provides an overview of managed identities in Azure Kubernetes Service (AKS), including system-assigned, user-assigned, and pre-created kubelet managed identities. It also explains how they work, role assignments, and AKS-specific managed identity features.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: overview
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - ignite-2023
ms.date: 06/07/2024
# Customer intent: "As a DevOps engineer, I want to understand the different types of managed identities available in AKS and how they can be used to securely access Azure resources."
---

# Overview of managed identities in Azure Kubernetes Service (AKS)

This article provides an overview of system-assigned and user-assigned managed identities in AKS, including how they work, role assignments, and AKS-specific managed identity features.

To enable a managed identity on a new or existing AKS cluster, see [Use a managed identity in Azure Kubernetes Service (AKS)](use-managed-identity.md). For more information about managed identities in Azure, see the [Managed identities for Azure resources documentation](/entra/identity/managed-identities-azure-resources/).

> [!NOTE]
> The system-assigned and user-assigned identity types differ from a [workload identity][workload-identity-overview], which is intended for use by an application running on a pod.

## AKS managed identity authorization flow

AKS clusters use system-assigned or user-assigned [managed identities](/entra/identity/managed-identities-azure-resources/overview) to request tokens from Microsoft Entra. These tokens help authorize access to other resources running in Azure. You assign an [Azure role-based access control (Azure RBAC)](/azure/role-based-access-control/overview) role to the managed identity to grant it permissions to a particular Azure resource. For example, you can grant permissions to a managed identity to access secrets in an Azure key vault for use by the cluster.

### Managed identity behavior in AKS

When you deploy an AKS cluster, a system-assigned managed identity is created for you by default. You can also create the cluster with a user-assigned managed identity, or update an existing cluster to a different type of managed identity.

If your cluster already uses a managed identity and you change the identity type (for example, from system-assigned to user-assigned), there's a delay while control plane components switch to the new identity. Control plane components continue to use the old identity until its token expires. After the token refreshes, they switch to the new identity. This process can take several hours.

> [!NOTE]
> It's also possible to create a cluster with an application [service principal](kubernetes-service-principal.md) rather that a managed identity. However, we recommend using a managed identity over an application service principal for security and ease of use. If you have an existing cluster that uses an application service principal, you can update it to use a managed identity.

### AKS identity and credential management

The Azure platform manages both system-assigned and user-assigned managed identities and their credentials, so you can authorize access from your applications without needing to provision or rotate any secrets.

## System-assigned managed identity

The following table summarizes the key characteristics of a system-assigned managed identity in AKS:

| Creation | Lifecycle | Sharing across resources | Common use cases |
|----------|-----------|--------------------------|------------------|
| Created as part of an Azure resource, such as an AKS cluster | Tied to the lifecycle of the parent resource, so it gets deleted when the parent resource is deleted | Can only be associated with a single resource | • Workloads contained within a single Azure resource <br> • Workloads that require independent identities |

### User-assigned managed identity

The following table summarizes the key characteristics of a user-assigned managed identity in AKS:

| Creation | Lifecycle | Sharing across resources | Common use cases |
|----------|-----------|--------------------------|------------------|
| Created as a standalone Azure resource, and must exist prior to cluster creation | Independent of the lifecycle of any specific resource, so it requires manual deletion if no longer needed | Can be shared across multiple resources | • Workloads that run on multiple resources and can share a single identity <br> • Workloads that require preauthorization to a secure resource as part of a provisioning process <br> • Workloads where resources are recycled frequently but need consistent permissions |

### Pre-created kubelet managed identity

A pre-created kubelet managed identity is an optional user-assigned identity that kubelet can use to access other resources in Azure. This feature enables scenarios such as connection to Azure Container Registry (ACR) during cluster creation. If you don't specify a user-assigned managed identity for kubelet, AKS creates a user-assigned kubelet identity in the node resource group. For a user-assigned kubelet identity outside the default worker node resource group, you need to assign the [Managed Identity Operator][managed-identity-operator] role on the kubelet identity for control plane managed identity.

## Role assignments for managed identities in AKS

You can assign an Azure RBAC role to a managed identity to grant the cluster permissions on another Azure resource. Azure RBAC supports both built-in and custom role definitions that specify levels of permissions. To assign a role, see [Steps to assign an Azure role](/azure/role-based-access-control/role-assignments-steps).

When you assign an Azure RBAC role to a managed identity, you must define the scope for the role. In general, it's a best practice to limit the scope of a role to the minimum privileges required by the managed identity. For more information on scoping Azure RBAC roles, see [Understand scope for Azure RBAC](/azure/role-based-access-control/scope-overview).

### Control plane managed identity role assignments

When you create and use your own VNet, attached Azure disks, static IP address, route table, or user-assigned kubelet identity where the resources are outside of the worker node resource group, the Azure CLI adds the role assignment automatically. If you're using an ARM template or another method, use the principal ID of the managed identity to perform a role assignment.

If you're not using the Azure CLI, but you're using your own VNet, attached Azure disks, static IP address, route table, or user-assigned kubelet identity that's outside of the worker node resource group, we recommend using a [user-assigned managed identity for the control plane][bring-your-own-control-plane-managed-identity].

When the control plane uses a system-assigned managed identity, the identity is created at the same time as the cluster, so the role assignment can't be performed until after cluster creation.

## Summary of managed identities used by AKS

AKS uses several managed identities for built-in services and add-ons. The following table summarizes the managed identities used by AKS, their use cases, default permissions, and whether you can bring your own identity:

| Identity | Name | Use case | Default permissions | Bring your own identity |
|----------|------|----------|---------------------|-------------------------|
| Control plane | <aks-cluster-name> | Used by AKS control plane components to manage cluster resources including ingress load balancers and AKS-managed public IPs, Cluster Autoscaler, Azure Disk, File, Blob CSI drivers | Contributor role for Node resource group | Supported |
| Kubelet | <aks-cluster-name>-agentpool | Authentication with Azure Container Registry (ACR) | N/A for Kubernetes version 1.15 and later | Supported |
| Add-on | AzureNPM | No identity required | N/A | Unsupported |
| Add-on | AzureCNI network monitoring | No identity required | N/A | Unsupported |
| Add-on | azure-policy (gatekeeper) | No identity required | N/A | Unsupported |
| Add-on | Calico | No identity required | N/A | Unsupported |
| Add-on | application-routing | Manages Azure DNS and Azure Key Vault certificates | Key Vault Secrets User role for Key Vault, DNS Zone Contributor role for DNS zones, Private DNS Zone Contributor role for private DNS zones | Unsupported |
| Add-on | HTTPApplicationRouting | Manages required network resources | Reader role for node resource group, contributor role for DNS zone | Unsupported |
| Add-on | Ingress application gateway | Manages required network resources | Contributor role for node resource group | Unsupported |
| Add-on | omsagent | Used to send AKS metrics to Azure Monitor | Monitoring Metrics Publisher role | Unsupported |
| Add-on | Virtual-Node (ACIConnector) | Manages required network resources for Azure Container Instances (ACI) | Contributor role for node resource group | Unsupported |
| Add-on | Cost analysis | Used to gather cost allocation data | N/A | Supported |
| Workload identity | Microsoft Entra Workload ID | Enables applications to access cloud resources securely with Microsoft Entra Workload ID | N/A | Unsupported |

## Next step: Enable managed identities in AKS

To learn how to enable managed identities on a new or existing AKS cluster, see [Use a managed identity in Azure Kubernetes Service (AKS)](use-managed-identity.md).

<!-- LINKS -->
[workload-identity-overview]: workload-identity-overview.md
[managed-identity-operator]: /azure/role-based-access-control/built-in-roles#managed-identity-operator
[bring-your-own-control-plane-managed-identity]: use-managed-identity.md#enable-a-user-assigned-managed-identity
