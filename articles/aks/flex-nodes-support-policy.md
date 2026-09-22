---
title: Support policy for flex nodes in AKS (preview)
description: Understand Microsoft and customer responsibilities, the documented preview configuration, and how to get help for flex nodes.
author: leslielin-5
ms.author: leslielin
ms.topic: concept-article
ms.date: 09/08/2026
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform operator, I want to understand the flex nodes responsibility model and support boundary."
---

# Support policy for flex nodes in AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Flex nodes run on Linux hosts that you provide and manage. Azure Kubernetes Service (AKS) manages the Kubernetes control plane and provides the flex node integration, while you operate the external host, its operating system, identity, network connectivity, and workloads.

This article explains how the [AKS support policy](support-policies.md) applies to flex nodes during preview.

## Preview support

Flex nodes are a preview feature intended for evaluation and aren't recommended for production workloads. Preview features receive best-effort support as described in [Preview features or feature flags](support-policies.md#preview-features-or-feature-flags). For legal terms, see the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

The deployment series documents the following configuration:

- A new or existing public or private AKS cluster. This deployment walkthrough creates a cluster without a built-in network plugin.
- Unbounded-Net configured across the AKS-managed and flex node network locations.
- Existing Layer 3 connectivity between the two node networks.
- A Linux host prepared according to the published flex node prerequisites.
- Azure VM managed identity, Azure Arc managed identity, or service principal authentication.
- Component versions and lifecycle operations documented in the flex nodes article series.

Other AKSFlexNode repository labs demonstrate additional configurations. A configuration appearing in a lab doesn't by itself change the Microsoft Learn support boundary.

## Limitations

The following limitations apply to flex nodes in AKS:

- You can't [stop a cluster](start-stop-cluster.md) that contains a flex node pool, including a cluster that also contains standard AKS node pools.
- You can't use Azure portal to create or manage flex node pools.

## Shared responsibility

| Area | Microsoft provides | You operate |
| --- | --- | --- |
| AKS control plane | The managed Kubernetes control plane under the AKS support policy. | A supported AKS cluster configuration and version. |
| Flex node integration | The AKS resource-provider integration, flex node agent, bootstrap workflow, Azure Machine operations, and documented management interfaces. | The documented setup and lifecycle commands on your hosts. |
| Host infrastructure | Azure platform operation when the host is an Azure resource. | Host provisioning, capacity, availability, hardware, firmware, storage, and recovery. |
| Host operating system | Published host prerequisites and flex node software requirements. | Operating-system installation, security, patching, monitoring, packages, and privileged host access. |
| Identity and access | Microsoft Entra ID, managed identity, Azure role-based access control, and supported flex node authentication integration. | Identity creation or enablement, credential protection, cluster-scoped role assignment, rotation, and removal. |
| Network connectivity | The AKS API endpoint and documented flex node integration points. | External routing, virtual network peering, firewalls, network security groups, DNS, proxies, address planning, and any VPN or ExpressRoute connection used by your network design. |
| Unbounded-Net | The documented integration used by this deployment series. | Installation, configuration, upgrades, and external network dependencies for the customer-managed networking layer. |
| Workloads | AKS platform behavior within the documented configuration. | Application deployment, configuration, security, monitoring, backup, data protection, and troubleshooting. |
| Host lifecycle | Documented pool and Machine management operations and flex node software. | Scheduling changes, drain readiness, running privileged update or removal commands, and verifying each result. |

Your responsibility for the host or external network doesn't remove Microsoft support for defects in the AKS control plane or the documented flex node integration.

## Host and component requirements

Use the host requirements referenced in [Prepare a flex node host and identity](./prepare-flex-node-host-identity.md), and the supported version published for each flex node component in [Plan flex nodes for AKS](./plan-flex-nodes-deployment.md#component-version-values).

For general AKS version availability, see [Supported Kubernetes versions in AKS](supported-kubernetes-versions.md).

## Network responsibility

The documented workflow requires connectivity among:

- The environment where you run management commands and the AKS API server.
- Each flex node host and the AKS API server.
- AKS-managed nodes and flex node hosts.
- Pods and Kubernetes services across both network locations.
- The AKS control plane and the kubelet on each flex node.

Microsoft provides the AKS endpoints and the documented flex node integration. You configure and operate the external network path, including routing, DNS, firewall rules, gateways, virtual network peering, proxies, and any VPN or ExpressRoute connection used by your design.

The deployment series uses Unbounded-Net to provide pod networking across an existing Layer 3 path. Follow the documented configuration and collect both AKS and Unbounded-Net state when an issue crosses that boundary.

## Host access and changes

Flex node bootstrap and lifecycle commands run with root privileges and change host state. Limit access to approved operators and use the documented commands and component versions.

You can access and maintain the host, but changes to the agent, systemd services, worker environment, container runtime, networking configuration, credentials, or required packages can affect the flex node integration. Record host changes and restore the documented configuration before requesting support when an unrelated customization might be involved.

Microsoft Support doesn't access a customer-managed host without your permission and assistance. Keep a supported management path available so your operators can collect diagnostics.

## Get help

For an active problem with AKS or the documented flex node integration, [create an Azure support request](/azure/azure-portal/supportability/how-to-create-azure-support-request).

Use the [AKSFlexNode issue tracker](https://aka.ms/aks-flex-node/issues) for product feedback and reproducible issues in the public project. Don't include confidential information or credentials in a public issue.

Report security vulnerabilities through the [Microsoft Security Response Center](https://msrc.microsoft.com/create-report), not through a public GitHub issue.

Include the following information when you request help:

- AKS cluster and flex node pool resource IDs.
- AKS, flex node agent, and Unbounded-Net versions.
- Operation name, UTC timestamp, and correlation ID when available.
- Kubernetes Node and Azure Machine names and states.
- Flex node agent, operating-system, and network logs.
- A description of relevant host or network changes.

Run the following commands to collect most of this information:

| Command | Where to run | Provides |
| --- | --- | --- |
| `az aks show` | Bash environment | Cluster name, resource ID, and API server |
| `az aks nodepool show` | Bash environment | Flex node pool version and provisioning state |
| `az aks machine list` | Bash environment | Machine names, node names, versions, and states |
| `kubectl get nodes` | Bash environment | Registered node names, states, and kubelet versions |
| `kubectl unbounded version` | Bash environment | Unbounded-Net version |
| `sudo journalctl -u aks-flex-node-agent --no-pager -n 200` | Flex node host | Flex node agent logs |

These commands appear with their full parameters in the deployment and management articles in this series.

Don't include access tokens, bootstrap data, kubeconfig content, private keys, certificates with private keys, service principal credentials, or other secrets.

## Next steps

- [Plan flex nodes for AKS](./plan-flex-nodes-deployment.md)
- [Manage and remove flex nodes in AKS](./manage-and-remove-flex-nodes.md)
- [Support policies for AKS](support-policies.md)
