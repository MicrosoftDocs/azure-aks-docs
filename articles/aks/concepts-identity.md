---
title: Concepts - Access and Identity in Azure Kubernetes Service (AKS)
description: Learn the five identity scenarios in Azure Kubernetes Service (AKS), how they map to AKS Automatic and AKS Standard, and where to find the right deep-dive documentation.
ms.topic: concept-article
ms.subservice: aks-security
ms.date: 04/18/2026
author: shashankbarsin
ms.author: shasb
ai-usage: ai-assisted
ms.service: azure-kubernetes-service
# Customer intent: As a Kubernetes administrator, I want a clear orientation to the identity scenarios in AKS so that I can pick the right authentication and authorization model for each one.
---

# Access and identity options for Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

AKS uses identity in five distinct scenarios. Each scenario answers a different question and has its own configuration model.

For most production AKS workloads, AKS Automatic is the recommended default because it starts with a production-ready platform baseline, including identity-related defaults, while preserving the same AKS identity model described in this article.

This article gives a brief introduction to each scenario, explains how the guidance maps to AKS Automatic and AKS Standard, and points to the deep-dive documentation.

## The five identity scenarios in AKS

| Scenario | Question it answers | Deep-dive docs |
| -------- | ------------------- | -------------- |
| **A. Kubernetes control-plane authentication** | Who is the caller hitting the Kubernetes API? | [Cluster authentication concepts](concepts-cluster-authentication.md), [external identity providers](external-identity-provider-authentication-overview.md) |
| **B. Kubernetes control-plane authorization** | What is the caller allowed to do once authenticated to the Kubernetes API? | [Cluster authorization concepts](concepts-cluster-authorization.md) |
| **C. AKS resource authorization (Azure Resource Manager)** | Who can perform Azure-level operations on the AKS resource, such as pulling `kubeconfig`? | [Limit access to cluster configuration file](control-kubeconfig-access.md), [Azure built-in roles](/azure/role-based-access-control/built-in-roles#containers) |
| **D. Cluster identity (cluster → Azure)** | How does the AKS cluster act on Azure to manage resources on your behalf? | [Managed identities in AKS](use-managed-identity.md) |
| **E. Workload identity (pod → Azure)** | How do pods authenticate to Azure services such as Key Vault or Storage? | [Microsoft Entra Workload ID overview](workload-identity-overview.md) |

## Identity posture in AKS Automatic and AKS Standard

The five identity scenarios in this article apply to both AKS Automatic and AKS Standard. The main difference is operational posture:

- AKS Automatic provides more preconfigured identity and security defaults.
- AKS Standard provides more manual control and requires more setup choices.

Use AKS Automatic as the default starting point for most production workloads, and use AKS Standard when you need deeper custom platform configuration.

For an overview of AKS Automatic, see [Introduction to Azure Kubernetes Service (AKS) Automatic](intro-aks-automatic.md).

### AKS Automatic and AKS Standard identity posture comparison

| Identity area | AKS Automatic posture | AKS Standard posture | Learn more |
| ------------- | --------------------- | -------------------- | ---------- |
| Kubernetes API authentication | Production-oriented defaults with Microsoft Entra integration as the recommended model | Configurable, including local accounts and Entra integration choices | [Cluster authentication concepts](concepts-cluster-authentication.md) |
| Kubernetes API authorization | Azure RBAC for Kubernetes authorization is preconfigured | Local-account-first and authorization model selected by cluster configuration | [Cluster authorization concepts](concepts-cluster-authorization.md) |
| AKS resource authorization | Uses standard Azure RBAC model on AKS resource operations | Uses standard Azure RBAC model on AKS resource operations | [Control kubeconfig access](control-kubeconfig-access.md) |
| Cluster identity | Uses managed identity model with production baseline defaults | Uses managed identity model with operator-selected setup | [Managed identities in AKS](use-managed-identity.md) |
| Workload identity | Workload identity and OIDC issuer are preconfigured | Optional and configured by operator | [Workload identity overview](workload-identity-overview.md) |

The rest of this article gives a brief orientation to each scenario.

## A. Kubernetes control-plane authentication

Kubernetes control-plane authentication establishes the identity of a user or service principal calling the Kubernetes API server. AKS supports:

- **Microsoft Entra ID (recommended)**: Use Entra ID identities and groups to sign in to the cluster. Microsoft Entra integration provisions and rotates the integration on your behalf. To enable, see [Use Microsoft Entra integration](entra-id-control-plane-authentication.md).
- **Local accounts**: A built-in cluster admin certificate that bypasses Entra ID. We recommend disabling local accounts in production. See [Manage local accounts](local-accounts.md).
- **External identity providers**: Use an OIDC-compliant identity provider other than Microsoft Entra ID. See [External identity provider authentication](external-identity-provider-authentication-overview.md).

For most production workloads, start with AKS Automatic and Microsoft Entra integration.

For an in-depth look at how AKS authenticates Kubernetes API requests, see [Cluster authentication concepts](concepts-cluster-authentication.md).

## B. Kubernetes control-plane authorization

After a caller is authenticated to the Kubernetes API, AKS authorizes the request using one (or both) of two models:

- **Kubernetes RBAC**: The native Kubernetes `Role`, `ClusterRole`, and `RoleBinding` model evaluated by the API server. Permissions live in the cluster as Kubernetes objects.
- **Microsoft Entra ID authorization**: An AKS authorization webhook delegates authorization decisions to Microsoft Entra ID using Azure role assignments. Azure RBAC role assignments with `dataActions` are supported for all standard Kubernetes API resources, and role assignments with Azure ABAC conditions are supported for custom resources. Manage permissions centrally in Microsoft Entra ID to govern many clusters from a single role assignment at subscription, management group, or resource group scope.

In AKS Automatic, Azure RBAC for Kubernetes authorization is preconfigured as part of the production-ready default posture.

For a comparison and guidance on when to use each model, see [Cluster authorization concepts](concepts-cluster-authorization.md).

<a name='kubernetes-rbac'></a>
<a name='azure-rbac-for-kubernetes-authorization'></a>
<a name='azure-rbac-to-authorize-access-to-the-aks-resource'></a>

## C. AKS resource authorization (Azure Resource Manager)

In addition to authorizing calls to the Kubernetes API, you also need to authorize Azure-level operations on the AKS resource itself. The most common example is controlling who can pull a cluster's `kubeconfig`, which is a standalone Azure Resource Manager operation that you can govern granularly with Azure RBAC. This operation uses standard Azure RBAC against the `Microsoft.ContainerService` resource provider, is separate from Kubernetes API authorization, and applies the same way to AKS Automatic and AKS Standard. For more information, see [Limit access to the cluster configuration file](control-kubeconfig-access.md) and the built-in roles in [Azure built-in roles](/azure/role-based-access-control/built-in-roles#containers).

## D. Cluster identity (cluster → Azure)

AKS clusters use Azure managed identities to act on Azure resources on your behalf — for example, to create load balancers, attach disks, or pull images from Azure Container Registry. The main identities are:

- **Control-plane identity**: Used by the cluster control plane to manage Azure resources for the cluster.
- **Kubelet identity**: Used by the kubelet on each node to authenticate to services such as Azure Container Registry.
- **Add-ons/extensions identity**: Some AKS add-ons and extensions use their own managed identities.

AKS Automatic keeps this same identity model while reducing setup friction through preconfigured production defaults.

For details on each identity type and how to use system-assigned vs user-assigned identities, see [Managed identities in AKS](use-managed-identity.md).

## E. Workload identity (pod → Azure)

Workload identity lets pods running in your AKS cluster authenticate to Microsoft Entra–protected Azure services (such as Key Vault, Storage, or Cosmos DB) without storing secrets in the cluster. AKS uses [Microsoft Entra Workload ID](workload-identity-overview.md), which projects a Kubernetes service account token federated to a Microsoft Entra application or user-assigned managed identity.

AKS Automatic includes workload identity and OIDC issuer as preconfigured defaults. In AKS Standard, these capabilities are optional and configured by the operator.

Don't use the deprecated [Microsoft Entra pod-managed identity](use-azure-ad-pod-identity.md) for new workloads.

## Decision guide

| Goal | Use these docs |
| ---- | -------------- |
| Start with a production-ready identity baseline for most workloads | [Introduction to AKS Automatic](intro-aks-automatic.md) |
| Sign users into the cluster with Microsoft Entra ID | [Enable Microsoft Entra integration](entra-id-control-plane-authentication.md) |
| Govern who can do what in the Kubernetes API across many clusters | [Use Microsoft Entra ID authorization for the Kubernetes API](entra-id-authorization.md) |
| Restrict access to specific custom resource types | [ABAC conditions in Entra ID authorization](entra-id-authorization.md#restrict-custom-resource-access-using-abac-conditions-preview) |
| Author per-cluster, per-namespace permissions as Kubernetes objects | [Use Kubernetes RBAC with Entra integration](kubernetes-rbac-entra-id.md) |
| Let the cluster pull from ACR or attach disks | [Managed identities in AKS](use-managed-identity.md) |
| Let pods reach Key Vault or Storage without secrets | [Microsoft Entra Workload ID overview](workload-identity-overview.md) |
| Restrict who can download the cluster `kubeconfig` | [Limit access to cluster configuration file](control-kubeconfig-access.md) |
| Create a production-ready cluster with default identity posture | [Create an AKS Automatic cluster](automatic/quick-automatic-managed-network.md) |

<a name='aks-service-permissions'></a>

## AKS service permissions reference

For the Azure permissions that AKS uses (the identity that creates the cluster, the cluster identity at runtime, additional cluster identity permissions, and AKS node access), see [AKS service permissions reference](aks-service-permissions.md).

## Related content

- [Introduction to Azure Kubernetes Service (AKS) Automatic](intro-aks-automatic.md)
- [Create an Azure Kubernetes Service (AKS) Automatic cluster](automatic/quick-automatic-managed-network.md)
- [Cluster authentication concepts](concepts-cluster-authentication.md)
- [Cluster authorization concepts](concepts-cluster-authorization.md)
- [Use Microsoft Entra ID authorization for the Kubernetes API](entra-id-authorization.md)
- [Managed identities in AKS](use-managed-identity.md)
- [Microsoft Entra Workload ID overview](workload-identity-overview.md)

For more information on core Kubernetes and AKS concepts, see the following articles:

- [Kubernetes / AKS clusters and workloads][aks-concepts-clusters-workloads]
- [Kubernetes / AKS security][aks-concepts-security]
- [Kubernetes / AKS virtual networks][aks-concepts-network]
- [Kubernetes / AKS storage][aks-concepts-storage]
- [Kubernetes / AKS scale][aks-concepts-scale]

<!-- LINKS - Internal -->
[aks-concepts-clusters-workloads]: concepts-clusters-workloads.md
[aks-concepts-security]: concepts-security.md
[aks-concepts-scale]: concepts-scale.md
[aks-concepts-storage]: concepts-storage.md
[aks-concepts-network]: concepts-network.md
