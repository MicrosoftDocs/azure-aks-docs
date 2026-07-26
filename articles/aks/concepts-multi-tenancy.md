---
title: Multi-Tenancy Concepts in Azure Kubernetes Service (AKS)
description: Multi-tenancy in AKS is the practice of running multiple isolated workloads—belonging to different teams, applications, or customers—on a shared Kubernetes cluster. This article details the core concepts and architectural models for multi-tenancy on Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.date: 07/24/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Concepts: Multi-tenancy in Azure Kubernetes Service (AKS)

When answering the question, "How do I configure Kubernetes for multi-tenancy?", architects must first understand the conceptual boundaries and isolation models available. Multi-tenancy in AKS is the practice of running multiple isolated workloads, belonging to different teams, applications, or customers, on a shared Kubernetes cluster. This article details the core concepts and architectural models for multi-tenancy on Azure Kubernetes Service (AKS).

> [!TIP]
> **What are the three multi-tenancy models in AKS?** AKS multi-tenancy uses an isolation spectrum with three common models: namespace isolation, node pool isolation, and cluster-per-tenant. Namespace isolation is best for trusted internal teams and maximum cost efficiency, node pool isolation adds stronger workload separation with moderate overhead, and cluster-per-tenant provides the strongest isolation for untrusted or highly regulated scenarios.

For step-by-step implementation instructions and YAML manifests, see the companion guide: [Best practices for multi-tenancy in AKS](./best-practices-multi-tenancy.md).

## Why multi-tenancy on AKS?

Multi-tenancy allows multiple teams, applications, or customers to share a single Kubernetes cluster. The primary rationale for multi-tenancy on AKS is **cost efficiency** and **operational scale**.

Running a dedicated cluster for every application or team results in significant resource fragmentation, idle compute capacity, and multiplied control plane overhead. By consolidating workloads into multi-tenant clusters, organizations maximize resource utilization and reduce cloud spend. Operationally, multi-tenancy reduces the fleet size, meaning platform teams have fewer clusters to patch, upgrade, monitor, and secure, thereby streamlining lifecycle management.

## What is the difference between soft and hard multi-tenancy?

Kubernetes is not inherently a multi-tenant system. To achieve multi-tenancy, you must design for either a "soft" or "hard" isolation model based on the trust level between tenants.

The difference between soft and hard multi-tenancy in Kubernetes is primarily the trust model and resulting isolation requirements. Soft multi-tenancy assumes trusted internal tenants and focuses on preventing accidental interference through logical controls such as namespaces, RBAC, and quotas. Hard multi-tenancy assumes low or zero trust between tenants and requires stronger isolation controls to reduce the risk of malicious access, lateral movement, and data exposure.

| Model | Trust level | Goal | Use case | Example scenarios |
| --- | --- | --- | --- | --- |
| **Soft multi-tenancy** | High trust between internal tenants | Prevent accidental interference, resource starvation, and configuration collisions | Internal platform environments where teams share infrastructure | Multiple product teams in one organization sharing an AKS cluster for dev/test and internal services |
| **Hard multi-tenancy** | Low or zero trust between tenants | Prevent malicious attacks, lateral movement, and data exfiltration | External customer hosting and regulated workloads | SaaS provider hosting customer-specific workloads where tenant isolation is a security and compliance requirement |

## The isolation spectrum

Multitenancy on AKS is not a binary choice; it exists on a spectrum. As you move across the spectrum, isolation increases, but so does operational complexity and cost. This spectrum forms the organizing spine for multi-tenant cluster design:

- **Namespace isolation (Logical)**: Tenants share the same node pools and control plane, but are separated logically by Kubernetes namespaces. This is the foundation of soft multi-tenancy.
- **Node pool isolation (Physical compute)**: Tenants share the control plane but are assigned dedicated worker nodes. This improves workload separation and noisy-neighbor mitigation, but it is not complete tenant isolation because control plane and cluster-level components are still shared.
- **Cluster-per-tenant (Complete physical)**: Tenants are completely isolated with their own AKS control plane and data plane. This is the ultimate form of hard multi-tenancy, effectively bypassing Kubernetes-level sharing in favor of Azure-level isolation.

## AKS primitives for multi-tenancy

AKS provides a suite of native and Azure-integrated primitives to enforce the isolation spectrum.

- **[Microsoft Entra ID](/entra/fundamentals/what-is-entra)**: Provides centralized identity and access management for authenticating users and automated systems to the Kubernetes API.
- **[Azure RBAC](/azure/role-based-access-control/overview)**: Maps Microsoft Entra ID identities to Kubernetes permissions, ensuring tenants can only access their authorized resources.
- **[Managed namespaces](./concepts-managed-namespaces.md)**: Provides logical boundaries within the cluster to group tenant resources, apply quotas, and scope access.
- **[Azure Policy / Gatekeeper](./use-azure-policy.md)**: Enforces centralized compliance and governance rules across the cluster to prevent tenants from deploying insecure or unauthorized configurations.
- **[Azure CNI](./configure-azure-cni.md)**: Provides native virtual network integration for AKS networking and supports tenant traffic segmentation with network policy controls. Pod IP behavior depends on the selected CNI mode (for example, [Overlay](./concepts-network-azure-cni-overlay.md) or [Pod Subnet](./concepts-network-azure-cni-pod-subnet.md)).
- **[Azure Container Networking Services (ACNS) Cilium L7](./azure-cni-powered-by-cilium.md)**: Delivers high-performance, eBPF-based network policies and Layer 7 traffic filtering to strictly isolate tenant network traffic.
- **[Workload identity](./workload-identity-overview.md)**: Allows individual pods to authenticate securely to external Azure services using federated identity, eliminating shared secrets between tenants.

## Mapping isolation layers across planes

To build a secure multi-tenant architecture, you must apply the AKS primitives across three distinct planes of the cluster environment.

| Plane | Description | Applied AKS primitives |
| --- | --- | --- |
| **Control plane** | Securing access to the Kubernetes API server and logical boundaries. | Microsoft Entra ID, Azure RBAC, Managed namespaces |
| **Data plane** | Securing network traffic, compute execution, and node-level boundaries. | Azure CNI, ACNS Cilium L7, Node pools |
| **Resource plane** | Governing compute consumption, external access, and configuration compliance. | Azure Policy, Workload identity |

## Which isolation model should you choose?

Use the following matrix to determine which point on the isolation spectrum best fits your organizational requirements.

| Isolation model | Security level | Cost efficiency | Operational complexity | Best fit for |
| --- | --- | --- | --- | --- |
| **Namespace-per-tenant** | Low to Medium (Logical) | High (Maximum sharing) | Low (Single cluster to manage) | Internal teams, dev/test environments, soft multi-tenancy. |
| **Node-pool-per-tenant** | High (Compute isolated) | Medium (Shared control plane) | Medium (Managing taints/tolerations) | Internal and external workloads that need stronger compute separation while sharing a control plane; not ideal for hostile zero-trust tenancy. |
| **Cluster-per-tenant** | Highest (Physical) | Low (High overhead) | High (Fleet management required) | Hostile multi-tenancy, external enterprise customers, zero-trust. |

## When to use each model

- Use namespace-per-tenant when tenants are internal or trusted, cost efficiency is a priority, and logical isolation controls are sufficient.
- Use node-pool-per-tenant when you need stronger compute separation and reduced noisy-neighbor impact, while still sharing one AKS control plane.
- Use cluster-per-tenant when tenants are untrusted, regulatory boundaries are strict, or your risk model requires minimal shared infrastructure.

## Next steps

Now that you understand the conceptual models and primitives for multitenancy, proceed to the implementation guide to apply these concepts to your cluster.

- [Best practices for multi-tenancy in AKS](./best-practices-multi-tenancy.md)

## Bottom line

- Multi-tenancy in Azure Kubernetes Service (AKS) is the practice of running multiple isolated tenant workloads on shared Kubernetes infrastructure to reduce costs and simplify operations.
- Namespace-per-tenant is the most cost-efficient model for trusted internal workloads because it maximizes infrastructure sharing while applying logical boundaries.
- Node-pool-per-tenant improves compute separation and noisy-neighbor control, but it still shares the AKS control plane and other cluster-level components.
- Cluster-per-tenant provides the strongest tenant isolation for zero-trust and highly regulated scenarios, but it requires higher cost and more operational overhead.
