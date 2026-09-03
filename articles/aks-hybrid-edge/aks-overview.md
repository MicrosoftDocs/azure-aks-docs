---
title: What is AKS Hybrid and Edge?
description: Learn about AKS Hybrid and Edge and available deployment options.
ms.topic: overview
ms.date: 09/01/2026
ai-usage: ai-assisted
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: srikantsarwa
ms.lastreviewed: 08/12/2026
ms.custom: overview

---

# What is AKS Hybrid and Edge?

Azure Kubernetes Service (AKS) Hybrid and Edge extends AKS beyond Azure regions to infrastructure you own or operate: datacenters, retail stores, manufacturing floors, remote sites, and other locations that need to run Kubernetes on-premises. It's part of Microsoft's **AKS everywhere** strategy: the same AKS engine, APIs, and operational model, available across a range of form factors, management models, and connectivity levels, so you can pick the deployment option that fits each location and scenario without adopting a different Kubernetes stack for each one.

## AKS everywhere

AKS Hybrid and Edge is part of Microsoft's vision for **AKS everywhere**: the same Azure Kubernetes Service you run in Azure regions is the same platform you run in sovereign and private clouds, and on your own hardware. One platform, every substrate, so the skills, tooling, and operational model you already know come with you wherever your applications need to run.

Every AKS Hybrid and Edge deployment option connects to the same Azure management plane, so you can use the same Azure portal, APIs, and policies to manage clusters no matter where they run. This consistency is what lets you standardize operations across cloud, datacenter, and edge locations, while each option is tuned for the infrastructure it targets.

AKS Hybrid and Edge provides the following features:

- Run Kubernetes clusters on-premises, at the edge, or in other cloud environments. This flexibility helps meet specific business or technical needs.
- Get a consistent experience for managing Kubernetes clusters across different infrastructures, similar to AKS in Azure.
- Manage Kubernetes clusters centrally through the Azure portal for deployment options that stay connected to Azure, including monitoring, updating, and scaling clusters.
- Extend Azure security and governance capabilities to Kubernetes clusters running anywhere. Apply Azure Policy for governance and use Microsoft Defender for Cloud for security monitoring and threat detection.
- Integrate with Azure services like Azure Monitor, Azure Policy, and Microsoft Defender for Cloud for a seamless operations and management experience.
- Use GitOps for configuration management and continuous deployment. This approach enables automated and consistent deployment processes.

## When to use AKS Hybrid and Edge

Here are some common use cases for AKS Hybrid and Edge:

- **Hybrid cloud deployments**: Run applications across on-premises and Azure environments with a consistent management layer.
- **Edge computing**: Deploy applications at the edge for low latency and local processing in places like retail stores, manufacturing floors, or remote locations.
- **Regulatory and compliance**: Meet regulatory and compliance requirements by deploying and managing Kubernetes clusters locally.

## AKS Hybrid and Edge deployment options

Here are the available deployment options:

- [**AKS on bare metal (preview)**](bare-metal/aks-bare-metal-overview.md): Managed from Azure, for teams that want to dedicate all server compute to workloads and avoid a virtualization layer.

- [**AKS on Azure Local**](local/aks-local-overview.md): Managed from Azure, for teams running Kubernetes alongside other virtualized workloads on the same infrastructure.

- [**AKS Edge Essentials**](edge-essentials/aks-edge-overview.md): A lightweight, self-managed option for constrained or disconnected devices at the edge, such as retail stores or manufacturing floors.

- [**AKS on Windows Server**](windows-server/overview.md): A self-managed option for teams that want to run Kubernetes independently, without a dependency on Azure connectivity.

> [!TIP]
> For a detailed, feature-by-feature comparison of these deployment options, see [Compare AKS features across cloud, edge, and on-premises platforms](aks-platforms-compare.md).

## Next steps

- [What is AKS on bare metal (preview)?](bare-metal/aks-bare-metal-overview.md)
- [What is AKS on Azure Local?](local/aks-local-overview.md)
- [Compare AKS features across cloud, edge, and on-premises platforms](aks-platforms-compare.md)
