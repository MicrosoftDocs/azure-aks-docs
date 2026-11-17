---
title: "Multi-cluster identity binding management with Azure Kubernetes Fleet Manager"
description: This article provides a conceptual overview of how you can manage identity binding resources across multiple clusters using Azure Kubernetes Fleet Manager.
ms.date: 10/06/2026
author: nibooy
ms.author: yoobinshin
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform engineer, I want to create an identity binding and distribute it to my member clusters via Fleet Manager, so that I can centrally manage workload identity across multiple clusters."
---

# Multi-cluster identity binding management with Azure Kubernetes Fleet Manager (preview)

**Applies to**: :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Fleet Manager identity binding profiles let you centrally manage workload identity across multiple clusters.

[Identity bindings for Azure Kubernetes Service (AKS)][aks-identity-bindings-concepts] solve the scaling limitation of the existing [workload identity feature][workload-identity-overview] by creating a single federated identity credential (FIC) per user-assigned managed identity (UAMI), allowing multiple AKS clusters to reuse the FIC. An identity binding maps one UAMI to one AKS cluster. If workloads on multiple clusters need to use the same UAMI, you need to create an identity binding for each cluster.

Identity binding profiles address this limitation by allowing you to define an identity binding once at the fleet level and distribute it across multiple clusters.

In this article, we introduce key concepts for managing identity bindings across multiple clusters by using Azure Kubernetes Fleet Manager and identity binding profiles.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites and limitations

[!INCLUDE [identity-binding-prerequisites.md](./includes/identity-binding/identity-binding-prerequisites.md)]

## What is an identity binding profile?

An identity binding profile defines the identity binding that each selected member cluster should have. It holds two things:

* The **managed identity** that workloads use for Microsoft Entra token acquisition. Every selected cluster binds the same identity.
* An optional list of **allowed subjects** defined by a JSON array of label selectors that match the namespaces and service accounts on the clusters that are authorized to use the identity.

> [!NOTE]
> The `allowedSubjects` field of AKS Identity Binding is in preview.
>
> If you omit this field, the system uses `ClusterRole` and `ClusterRoleBinding` objects on the member cluster for authorization, and you must define them manually. See [authorize namespaces and service accounts][aks-identity-bindings-authorize]. On a fleet with a hub cluster, you can distribute these objects to multiple clusters by using workload placement with a [ClusterResourceEnvelope][fleet-envelope-objects].

When you apply the identity binding profile, Fleet Manager creates and manages the identity binding resource on each selected member cluster by using the profile's configuration. Every selected cluster gets the same configuration.

Identity binding profiles select member clusters with [member cluster labels][fleet-member-labels] in the same way [resource placement][fleet-resource-placement] does. Use the same labels for both so that your workloads target the clusters where the identity is configured. When you add a cluster to the selection, apply the profile and confirm that the binding is created before you place workloads on it.

## Next steps

* Learn how to [configure and distribute identity bindings with Fleet Manager](./howto-identity-binding-profiles.md).
* To understand the single-cluster feature, read the [identity bindings concepts for AKS][aks-identity-bindings-concepts].

<!-- INTERNAL LINKS -->
[aks-identity-bindings-concepts]: ../aks/identity-bindings-concepts.md
[aks-identity-bindings-authorize]: ../aks/identity-bindings.md#authorize-namespaces-and-service-accounts
[fleet-member-labels]: ./concepts-member-cluster-labels.md
[fleet-resource-placement]: ./concepts-resource-placement.md
[fleet-envelope-objects]: ./quickstart-envelope-reserved-resources.md
[workload-identity-overview]: ../aks/workload-identity-overview.md
