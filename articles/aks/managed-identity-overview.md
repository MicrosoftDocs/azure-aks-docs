---
title: Managed Identities in Azure Kubernetes Service (AKS) Overview
description: This article provides an overview of managed identities in Azure Kubernetes Service (AKS), including system-assigned, user-assigned, and pre-created kubelet managed identities. It also explains how they work, role assignments, and AKS-specific managed identity features.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: overview
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - ignite-2023
  - aeo-round-2
ms.date: 08/18/2026
# Customer intent: "As a DevOps engineer, I want to understand the different types of managed identities available in AKS and how they can be used to securely access Azure resources."
---

# Managed identities in Azure Kubernetes Service (AKS) overview

This article provides an overview of system-assigned and user-assigned managed identities in AKS, including how they work, role assignments, and AKS-specific managed identity features.

For more information about managed identities in Azure, see the [Managed identities for Azure resources documentation](/entra/identity/managed-identities-azure-resources/).

> [!NOTE]
> Managed identities cover the **cluster-to-Azure** identity scenario in AKS — how the AKS cluster acts on Azure to manage resources on your behalf. For the other identity scenarios (control-plane authentication and authorization, and pod-to-Azure workload identity), see [Access and identity options for AKS](concepts-identity.md).

> [!NOTE]
> The system-assigned and user-assigned identity types differ from a [workload identity][workload-identity-overview], which is intended for use by an application running on a pod.

## AKS managed identity authorization flow

AKS clusters use system-assigned or user-assigned [managed identities](/entra/identity/managed-identities-azure-resources/overview) to request tokens from Microsoft Entra. These tokens help authorize access to other resources running in Azure. You assign an [Azure role-based access control (Azure RBAC)](/azure/role-based-access-control/overview) role to the managed identity to grant it permissions to a particular Azure resource. For example, you can grant permissions to a managed identity to access secrets in an Azure key vault for use by the cluster.

### Managed identity behavior in AKS

When you deploy an AKS cluster, a system-assigned managed identity is created for you by default. You can also create the cluster with a user-assigned managed identity, or update an existing cluster to a different type of managed identity.

If your cluster already uses a managed identity and you change the identity type (for example, from system-assigned to user-assigned), there's a delay while control plane components switch to the new identity. Control plane components continue to use the old identity until the old identity's token expires. After the token refreshes, they switch to the new identity. This process can take several hours.

> [!NOTE]
> You can also create a cluster with an application [service principal](kubernetes-service-principal.md) rather than a managed identity. However, use a managed identity over an application service principal for security and ease of use. If you have an existing cluster that uses an application service principal, you can update it to use a managed identity.

### AKS identity and credential management

The Azure platform manages both system-assigned and user-assigned managed identities and their credentials, so you can authorize access from your applications without needing to provision or rotate any secrets.

## System-assigned managed identity

The following table summarizes the key characteristics of a system-assigned managed identity in AKS:

| How it's created | Life cycle behavior | Resource sharing | Common use cases in AKS |
| ---------------- | ------------------- | ---------------- | ----------------------- |
| Created as part of an Azure resource, such as an AKS cluster | Tied to the lifecycle of the parent resource, so it gets deleted when the parent resource is deleted | Can only be associated with a single resource | • Workloads contained within a single Azure resource <br> • Workloads that require independent identities |

## User-assigned managed identity

The following table summarizes the key characteristics of a user-assigned managed identity in AKS:

| How it's created | Life cycle behavior | Resource sharing | Common use cases in AKS |
| ---------------- | ------------------- | ---------------- | ----------------------- |
| Created as a standalone Azure resource, and must exist prior to cluster creation | Independent of the lifecycle of any specific resource, so it requires manual deletion if no longer needed | Can be shared across multiple resources | • Workloads that run on multiple resources and can share a single identity <br> • Workloads that require preauthorization to a secure resource as part of a provisioning process <br> • Workloads where resources are recycled frequently but need consistent permissions |

## Pre-created kubelet managed identity

A pre-created kubelet managed identity is an optional user-assigned identity that kubelet can use to access other resources in Azure. This feature enables scenarios such as connection to Azure Container Registry (ACR) during cluster creation. If you don't specify a user-assigned managed identity for kubelet, AKS creates a user-assigned kubelet identity in the node resource group. For a user-assigned kubelet identity outside the default worker node resource group, assign the [Managed Identity Operator][managed-identity-operator] role to the cluster's control plane identity, whether system-assigned or user-assigned, with the role assignment scoped to the kubelet identity.

## Role assignments for managed identities in AKS

You can assign an Azure RBAC role to a managed identity to grant the cluster permissions on another Azure resource. Azure RBAC supports both built-in and custom role definitions that specify levels of permissions. To assign a role, see [Steps to assign an Azure role](/azure/role-based-access-control/role-assignments-steps).

When you assign an Azure RBAC role to a managed identity, you must define the scope for the role. In general, it's a best practice to limit the scope of a role to the minimum privileges required by the managed identity. For more information on scoping Azure RBAC roles, see [Understand scope for Azure RBAC](/azure/role-based-access-control/scope-overview).

### Control plane managed identity role assignments

When you create and use your own VNet, attached Azure disks, static IP address, route table, or user-assigned kubelet identity where the resources are outside of the worker node resource group, the Azure CLI adds the role assignment automatically. If you're using an ARM template or another method, use the principal ID of the managed identity to perform a role assignment.

If you're not using the Azure CLI, but you're using your own VNet, attached Azure disks, static IP address, route table, or user-assigned kubelet identity where those resources are outside of the worker node resource group, we recommend using a [user-assigned managed identity for the control plane][bring-your-own-control-plane-managed-identity] and manually performing the required role assignment using the principal ID of that identity.

When the control plane uses a system-assigned managed identity, you create the identity at the same time as the cluster, so you can't perform the role assignment until after cluster creation. After you create the cluster, get the identity's principal ID and [add the required role assignment](system-assigned-managed-identity.md#add-a-role-assignment-for-a-system-assigned-managed-identity).

## Summary of managed identities used by AKS

AKS uses several managed identities for built-in services and add-ons. The following table summarizes the managed identities used by AKS, their use cases, default permissions, and whether you can bring your own identity:

| Identity | Name | Use case | Default permissions | Bring your own identity |
| -------- | ---- | -------- | ------------------- | ----------------------- |
| Control plane | AKS cluster name | Used by AKS control plane components to manage cluster resources including ingress load balancers and AKS-managed public IPs, Cluster Autoscaler, Azure Disk, File, Blob CSI drivers | Contributor role for node resource group | Supported |
| Kubelet | AKS cluster name-agentpool | Authentication with Azure Container Registry (ACR) | None; requires an ACR pull role based on the registry permission mode | Supported |
| Add-on | AzureNPM | No identity required | N/A | Unsupported |
| Add-on | AzureCNI network monitoring | No identity required | N/A | Unsupported |
| Add-on | azure-policy (gatekeeper) | No identity required | N/A | Unsupported |
| Add-on | Calico | No identity required | N/A | Unsupported |
| Add-on | application-routing (NGINX) | Manages Azure DNS and Azure Key Vault certificates | Key Vault Certificate User role for Key Vault, DNS Zone Contributor role for DNS zones | Unsupported |
| Add-on | ingressapplicationgateway-*AKS cluster name* | Manages required network resources for Application Gateway ingress controller (AGIC) | Depends on the deployment topology | Unsupported |
| Add-on | Container Insights | Collects container logs and inventory data and sends it to a Log Analytics workspace | Uses the cluster managed identity; no Monitoring Metrics Publisher role required | Uses the cluster identity |
| Add-on | Virtual-Node (ACIConnector) | Manages required network resources for Azure Container Instances (ACI) | Contributor role for node resource group | Unsupported |
| Add-on | cost-analysis-identity | Collects Azure Resource Manager identifiers for cost allocation | Read access to the node resource group | Unsupported |
| Workload identity | User-configured Microsoft Entra identity | Enables applications to access cloud resources securely with Microsoft Entra Workload ID | Depends on the resources that the workload accesses | Required |

> [!NOTE]
> The kubelet identity requires an ACR pull role. For registries in RBAC Registry Permissions mode, use the `AcrPull` role. For registries in RBAC Registry + ABAC Repository Permissions mode, use the `Container Registry Repository Reader` role. Add the `Container Registry Repository Catalog Lister` role only if the identity needs to list repositories. For more information, see [AKS node mapped identity](aks-service-permissions.md#aks-node-mapped-identity).
>
> The application routing row describes the NGINX-based experience. Microsoft provides support for critical security patches for application routing add-on NGINX Ingress resources through November 2026. Migrate to the [Application Routing Gateway API](app-routing-gateway-api.md), or another supported implementation, by November 2026. The [Gateway API DNS and TLS integration](app-routing-gateway-api-dns-tls.md) uses Microsoft Entra Workload ID instead of the add-on's managed identity. For Gateway API, create a user-assigned managed identity, grant it the required Azure DNS and Azure Key Vault roles, and create federated identity credentials for the Kubernetes service accounts.
>
> AGIC permissions depend on how you deploy Application Gateway. When the add-on creates a new Application Gateway, it usually assigns the required permissions automatically. If you need to assign permissions manually, grant the add-on identity Network Contributor on the Application Gateway subnet. For an existing Application Gateway in a different resource group than the AKS cluster, grant the add-on identity Network Contributor and Reader on the Application Gateway resource group. For more information, see [Enable AGIC with a new Application Gateway](/azure/application-gateway/tutorial-ingress-controller-add-on-new#enable-the-add-on-for-the-existing-aks-cluster) and [enable AGIC with an existing Application Gateway](/azure/application-gateway/tutorial-ingress-controller-add-on-existing#enable-the-agic-add-on-in-existing-aks-cluster-through-azure-portal).
>
> Container Insights defaults to managed identity authentication and uses the cluster managed identity to send data to Azure Monitor. Legacy authentication, which required the Monitoring Metrics Publisher role, retires on September 30, 2026. Container Insights collects logs and inventory data in a Log Analytics workspace; [Azure Monitor managed service for Prometheus](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-metrics-on-an-aks-cluster) separately collects Prometheus metrics in an Azure Monitor workspace. For more information, see [Container Insights authentication](/azure/azure-monitor/containers/container-insights-authentication).
>
> AKS creates the `cost-analysis-identity` with read access to the node resource group and assigns it to the cluster's node pools when you enable cost analysis. You can't provide a different identity for the add-on. For more information, see [Enable AKS cost analysis](cost-analysis.md#enable-cost-analysis-on-your-aks-cluster).
>
> Microsoft Entra Workload ID is a pod-to-Azure identity model, not a cluster or add-on managed identity. You configure the Microsoft Entra identity that each workload uses, annotate the Kubernetes service account with the identity's client ID, and create a federated identity credential. For more information, see [Deploy and configure Microsoft Entra Workload ID](workload-identity-deploy-cluster.md).

## Next step

Enable your desired managed identity type on a new or existing AKS cluster using the following guides:

- [Use a system-assigned managed identity in AKS](./system-assigned-managed-identity.md)
- [Use a user-assigned managed identity in AKS](./user-assigned-managed-identity.md)
- [Use a pre-created kubelet managed identity in AKS](./pre-created-kubelet-managed-identity.md)

<!-- LINKS -->
[workload-identity-overview]: workload-identity-overview.md
[managed-identity-operator]: /azure/role-based-access-control/built-in-roles#managed-identity-operator
[bring-your-own-control-plane-managed-identity]: user-assigned-managed-identity.md
