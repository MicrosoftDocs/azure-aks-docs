---
title: Identity bindings for AKS (Preview)
description: Learn the concepts of identity bindings on Azure Kubernetes Service (AKS) and how they extend Microsoft Entra workload identity for large scale scenarios that exceed federated identity credential limits.
ms.topic: conceptual
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 11/10/2025
ms.custom: preview
author: shashankbarsin
ms.author: shasb
# Customer intent: As an operator of large AKS environments, I need a scalable way to map a user-assigned managed identity to many clusters and many service accounts without hitting federated identity credential limits so workloads can securely obtain Microsoft Entra tokens.
---

# Identity bindings for Azure Kubernetes Service (AKS) (Preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Context

The existing [workload identity feature for AKS][workload-identity-overview] has scale limitations because a single user-assigned managed identity (UAMI) can't have more than **20 federated identity credentials (FICs)**. Large Kubernetes platform deployments might span more than 20 clusters (each cluster has a unique issuer) or have many `<namespace, service-account>` combinations that require mapping to the same UAMI, exhausting the FIC quota.

Identity binding is an evolution of workload identity on AKS focused on scalability and operational simplicity. For workloads that require Microsoft Entra authentication from AKS, identity bindings are recommended when you need to reuse the same user-assigned managed identity across multiple clusters while staying within the FIC limit.

## Conceptual introduction

An identity binding is a resource mapping between **one user-assigned managed identity (UAMI)** and **one AKS cluster** that has workloads needing Entra authentication with that identity. If the UAMI `MI-1` is needed by workloads running in clusters `AKS-1`, `AKS-2`, `AKS-3`, you create separate identity binding mappings:

- `IB-A` mapping `MI-1` to `AKS-1`
- `IB-B` mapping `MI-1` to `AKS-2`
- `IB-C` mapping `MI-1` to `AKS-3`

Even if the same UAMI is needed across multiple clusters, only **one** federated identity credential is created per UAMI, addressing the previous 20 FIC limitation. When the cluster operator creates an identity binding, AKS automatically creates (or reuses) the single federated identity credential for that UAMI.

:::image type="content" source="media/identity-bindings/identity-bindings-concepts.png" lightbox="media/identity-bindings/identity-bindings-concepts.png" alt-text="Diagram showing identity bindings mapping a UAMI to multiple AKS clusters while using a single FIC." :::

After the binding is created and the UAMI is authorized for the cluster, the cluster operator must define `ClusterRole` and `ClusterRoleBinding` objects that specify the namespaces and service accounts (granularly or collectively) permitted to use that managed identity for Microsoft Entra token acquisition.

## Azure Identity client libraries

To use identity bindings with your application workloads, do the following:

 1. Ensure you're using the minimum required Azure Identity package.
 1. Use `WorkloadIdentityCredential` and opt into the feature. This feature isn't supported in `ManagedIdentityCredential` or `DefaultAzureCredential`.
 

| Language | Package | Minimum Version | How to enable |
|----------|---------|-----------------|-------|
| .NET | [Azure.Identity](/dotnet/api/overview/azure/identity-readme) | **v1.18.0-beta.2** or later | `WorkloadIdentityCredential` identity binding mode is disabled by default. Set `WorkloadIdentityCredentialOptions.IsAzureKubernetesTokenProxyEnabled` to `true`. |
| Go | [azidentity](https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/azidentity) | **v1.14.0-beta.2** or later | Set `WorkloadIdentityCredentialOptions.EnableAzureTokenProxy` to `true`. |
| Java | [azure-identity](/java/api/overview/azure/identity-readme) | **v1.19.0-beta.1** or later | Call `enableAzureTokenProxy()` on `WorkloadIdentityCredentialBuilder`. |
| JavaScript | [@azure/identity](https://www.npmjs.com/package/@azure/identity) | **4.14.0-beta.1** or later | Set `enableAzureKubernetesTokenProxy` to `true` in `WorkloadIdentityCredentialOptions`. |
| Python | [azure-identity](/python/api/overview/azure/identity-readme) | **1.26.0b1** or later | Set `use_token_proxy=True` in `WorkloadIdentityCredential`. |

## FAQ

### Is identity sameness (namespace and service account sameness) required across clusters when the same UAMI is used?

No. Identity bindings don't require namespace/service account sameness. It's up to the cluster operator to explicitly authorize the namespaces and service accounts inside each cluster that are allowed to use the managed identity through RBAC.

### Can multiple identity bindings be created for the same UAMI?

Yes. The OIDC issuer URL maintained by AKS for that UAMI is the same across all identity bindings referencing the same managed identity.

### What permissions are required to create identity bindings?

**Required Azure Resource Manager (ARM) permissions:**

- `Microsoft.ContainerService/managedClusters/identityBindings/*`
- `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/*`

> [!NOTE]
> When an identity binding is created, AKS automatically creates the federated identity credential (FIC) on behalf of the cluster operator. If the caller lacks permission to create FIC resources, the identity binding creation fails.

**Required Kubernetes permissions:** Ability to create `ClusterRole` and `ClusterRoleBinding` objects (cluster admin or equivalent).

### What happens to the auto-created FIC after deleting all identity bindings for a UAMI?

There's no automatic garbage collection of the FIC today when the last identity binding referencing a UAMI is deleted. Operators should manually clean up the FIC only after verifying all identity bindings for that UAMI have been removed to avoid disrupting remaining dependencies.

### What networking prerequisites exist for identity bindings?

Previously, workload identity required egress to `login.microsoftonline.com` so workloads could exchange service account tokens for Microsoft Entra access tokens. With identity bindings, token exchange requests route through a cluster-specific identity binding proxy operated by AKS. Direct egress to `login.microsoftonline.com` for token exchange isn't required.

## Next steps

Proceed to [Set up identity bindings][identity-bindings-how-to] for a step-by-step guide.

<!-- INTERNAL LINKS -->
[identity-bindings-how-to]: identity-bindings.md
[workload-identity-overview]: workload-identity-overview.md

<!-- EXTERNAL LINKS -->
[general-federated-identity-credential-considerations]: /azure/active-directory/workload-identities/workload-identity-federation-considerations#general-federated-identity-credential-considerations
[managed-identities-overview]: /azure/active-directory/managed-identities-azure-resources/overview
