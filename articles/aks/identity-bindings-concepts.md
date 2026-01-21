---
title: Identity bindings for Azure Kubernetes Service (AKS) (preview)
description: Learn about identity bindings on AKS and how they extend Microsoft Entra workload identity for large scale scenarios that exceed federated identity credential limits.
ms.topic: concept-article
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 12/13/2025
ms.custom: preview
author: shashankbarsin
ms.author: shasb
ms.reviewer: schaffererin
# Customer intent: "As an operator of large AKS environments, I need a scalable way to map a user-assigned managed identity to many clusters and many service accounts without hitting federated identity credential limits so workloads can securely obtain Microsoft Entra tokens."
---

# Identity bindings for Azure Kubernetes Service (AKS) (preview)

Identity binding is a preview feature for Azure Kubernetes Service (AKS) that extends the existing [workload identity feature][workload-identity-overview] to address scale limitations around federated identity credentials (FICs) on user-assigned managed identities (UAMIs). With [workload identity for AKS][workload-identity-overview], a single UAMI can't have more than **20 FICs**. Large Kubernetes platform deployments might span more than 20 clusters (each cluster has a unique issuer) or have many `<namespace, service-account>` combinations that require mapping to the same UAMI, exhausting the FIC quota.

Identity bindings address this limitation by allowing multiple AKS clusters to share the same UAMI using a single FIC per UAMI. This approach significantly increases scalability and simplifies operations for large-scale AKS environments that require Microsoft Entra authentication.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What is an identity binding?

An identity binding is a resource mapping between **one UAMI** and **one AKS cluster with workloads that need Microsoft Entra authentication with that identity**.

Let's say you have a UAMI, `MI-1`, needed by workloads running in clusters `AKS-cluster-1`, `AKS-cluster-2`, and `AKS-cluster-3`. You can create three identity bindings to map `MI-1` to each of these clusters:

- **Identity binding `IB-A`** mapping `MI-1` to `AKS-cluster-1`.
- **Identity binding `IB-B`** mapping `MI-1` to `AKS-cluster-2`.
- **Identity binding `IB-C`** mapping `MI-1` to `AKS-cluster-3`.

Even if the same UAMI is needed across multiple clusters, only **one** federated identity credential is created per UAMI, addressing the previous 20 FIC limitation. When you create an identity binding, AKS automatically creates (or reuses) the single FIC for that UAMI. The following diagrams illustrate the differences between the previous workload identity model and the new identity bindings model:

:::image type="content" source="media/identity-bindings/identity-binding-vs-workload-identity.png" lightbox="media/identity-bindings/identity-binding-vs-workload-identity.png" alt-text="Screenshot of two diagrams with one showing identity bindings mapping a UAMI to multiple AKS clusters while using a single FIC and the other showing workload identity mappings.":::

After you create the identity binding and the UAMI is authorized for the cluster, you must define `ClusterRole` and `ClusterRoleBinding` objects that specify the namespaces and service accounts (granularly or collectively) permitted to use that managed identity for Microsoft Entra token acquisition.

## Use identity bindings with Azure Identity client libraries

To use identity bindings with your application workloads, follow these steps:

1. Ensure you're using the minimum required Azure Identity package.
1. Use `WorkloadIdentityCredential` and opt into the feature. This feature isn't supported in `ManagedIdentityCredential` or `DefaultAzureCredential`.

The following table outlines the minimum package versions and how to enable identity bindings for each supported language:

| Language | Package | Minimum Version | How to enable |
| -------- | ------- | --------------- | ------------- |
| .NET | [Azure.Identity][dotnet-azure-identity] | **v1.18.0-beta.2** or later | `WorkloadIdentityCredential` identity binding mode is disabled by default. Set `WorkloadIdentityCredentialOptions.IsAzureKubernetesTokenProxyEnabled` to `true`. |
| Go | [azidentity][go-azidentity] | **v1.14.0-beta.2** or later | Set `WorkloadIdentityCredentialOptions.EnableAzureTokenProxy` to `true`. |
| Java | [azure-identity][java-azure-identity] | **v1.19.0-beta.1** or later | Call `enableAzureTokenProxy()` on `WorkloadIdentityCredentialBuilder`. |
| JavaScript | [@azure/identity][javascript-azure-identity] | **4.14.0-beta.1** or later | Set `enableAzureKubernetesTokenProxy` to `true` in `WorkloadIdentityCredentialOptions`. |
| Python | [azure-identity][python-azure-identity] | **1.26.0b1** or later | Set `use_token_proxy=True` in `WorkloadIdentityCredential`. |

## Frequently asked questions (FAQs)

### Is identity sameness (namespace and service account sameness) required across clusters using the same UAMI?

No. Identity bindings don't require namespace/service account sameness. It's up to the cluster operator to explicitly authorize the namespaces and service accounts inside each cluster that are allowed to use the managed identity through role-based access control (RBAC).

### Can I create multiple identity bindings for the same UAMI?

Yes. The OIDC issuer URL maintained by AKS for that UAMI is the same across all identity bindings referencing the same managed identity.

### What permissions are required to create identity bindings?

**Required Azure Resource Manager (ARM) permissions**:

- `Microsoft.ContainerService/managedClusters/identityBindings/*`
- `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/*`

> [!NOTE]
> When you create an identity binding, AKS automatically creates a FIC. If the caller lacks permission to create FIC resources, the identity binding creation fails.

**Required Kubernetes permissions**:

- Ability to create `ClusterRole` and `ClusterRoleBinding` objects (cluster admin or equivalent).

### What happens to the auto-created FIC after deleting all identity bindings for a UAMI?

There's no automatic garbage collection of the FIC today when the last identity binding referencing a UAMI is deleted. Operators should manually clean up the FIC only after verifying all identity bindings for that UAMI have been removed to avoid disrupting remaining dependencies.

### What networking prerequisites exist for identity bindings?

Previously, workload identity required egress to `login.microsoftonline.com` so workloads could exchange service account tokens for Microsoft Entra access tokens. With identity bindings, token exchange requests route through a cluster-specific identity binding proxy operated by AKS. Direct egress to `login.microsoftonline.com` for token exchange isn't required.

### What limitations exist for identity bindings?

Identity bindings aren't yet supported on clusters configured with [API server virtual network integration][api-server-vnet-integration].

## Related content

- [Set up identity bindings for Azure Kubernetes Service (AKS)][identity-bindings-how-to]
- [Workload identity overview for Azure Kubernetes Service (AKS)][workload-identity-overview]

<!-- INTERNAL LINKS -->
[identity-bindings-how-to]: identity-bindings.md
[workload-identity-overview]: workload-identity-overview.md
[dotnet-azure-identity]: /dotnet/api/overview/azure/identity-readme
[java-azure-identity]: /java/api/overview/azure/identity-readme
[javascript-azure-identity]: /javascript/api/overview/azure/identity-readme
[python-azure-identity]: /python/api/overview/azure/identity-readme
[api-server-vnet-integration]: /azure/aks/api-server-vnet-integration

<!-- EXTERNAL LINKS -->
[go-azidentity]: https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/azidentity
