---
title: Identity and access concepts for flex nodes on AKS (preview)
description: Learn why flex nodes use different identity options depending on where your host runs, and how AKS authorizes a host to join a cluster.
ms.topic: concept-article
ms.date: 08/28/2026
author: sdesai345
ms.author: sachidesai
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Identity and access concepts for flex nodes in Azure Kubernetes Service (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Before a customer-managed host can join an Azure Kubernetes Service (AKS) cluster as a flex node, it needs a way to prove its identity to Azure and permission to register itself with your cluster. This article explains why flex nodes support more than one identity option, and how to pick the right one based on where your host runs.

## Why a flex node needs an identity

A flex node runs on hardware that you manage or an Azure virtual machine that AKS didn't directly create. Because AKS didn't provision the host, the cluster doesn't automatically recognize that a connection request comes from your host machine and not from somewhere else.

An identity gives the host machine a verifiable mechanism to authenticate to Azure, so that AKS can confirm the request is legitimate before letting the host register itself and join the cluster. The host keeps using that identity after it joins: the agent communicates with Azure to read the node's desired configuration and to report its status. The identity also carries the permissions that authorize the host to read and write for your specific AKS cluster.

Every flex node identity option serves this same purpose. The options differ in *how* the host proves its identity, and that difference depends on the host location.

## Your identity option depends on where your host runs

Azure can only hand a host a built-in, secretless identity, known as a *managed identity*, when Azure already has a trust relationship with that
host. Azure has that relationship with an Azure virtual machine (VM) because Azure created it, and with a server connected to Azure Arc because the Arc
agent established it. Azure has no such relationship with hardware it has never seen, such as an on-premises machine or a third-party host that isn't
connected to Azure Arc.

Flex nodes support three identity options:

| Where your host runs | Identity option | Why |
| --- | --- | --- |
| A server already connected to Azure Arc | Azure Arc managed identity | Azure Arc extends Azure's trust relationship to a non-Azure server, so that server can also get a secretless identity. |
| An Azure virtual machine | System-assigned or user-assigned managed identity | Azure already manages the VM, so it can hand the VM a secretless identity directly. |
| Any other virtual machine or bare-metal host | Service principal | Azure has no existing relationship with the host, so you create and manage an application identity for it yourself. |

### Azure Arc-enabled servers: extending managed identity beyond Azure

By using Azure Arc, a server that doesn't run in Azure, such as an on-premises machine or a VM in another cloud, can register with Azure and receive a managed identity. This identity provides the same secretless benefit that an Azure VM gets. Connecting the server to Azure Arc is a prerequisite: only after the server shows as connected can it use an Arc managed identity for a flex node.

Choose this option when your host already runs outside Azure and either is, or can be, connected to Azure Arc.

### Azure virtual machines: system-assigned or user-assigned

If your flex node host is an Azure VM, you can choose between two forms of managed identity:

- **System-assigned managed identity** is tied to the lifecycle of one VM. Azure creates it when you enable it on the VM and removes it automatically if you delete the VM. Choose this option when the identity only needs to represent this specific machine.
- **User-assigned managed identity** exists as its own Azure resource, independent of any single VM. You create it once and can assign the same identity to multiple machines, or replace a VM without losing the identity. Choose this option when you want to reuse or manage the identity separately from the VM it's attached to.

### Service principal

Some hosts can't get a managed identity at all, either because they run outside Azure and aren't connected to Azure Arc, or because they're bare-metal hardware with no Arc connection. For these hosts, you create a service principal: an application identity in Microsoft Entra ID that represents the host.

A service principal shifts credential management to you. Where a managed identity never exposes a secret, a service principal needs a credential, a certificate, or a client secret that Azure can verify. Because you can more tightly protect and rotate a certificate on your own schedule, prefer a certificate credential over a long-lived secret. You're then responsible for creating the credential and transferring it to the host through a secure channel.

Choose this option only when your host doesn't qualify for either managed identity path.

## Authorize the identity at your AKS cluster

Every identity option ends at the same checkpoint: before a host can join a cluster, its identity needs permission on that specific AKS cluster. You grant this permission by assigning the identity the role that lets it register as a node, scoped to that one cluster instead of your whole subscription. Scoping the permission to a single cluster limits what a compromised or misconfigured host identity could otherwise reach.

This authorization step doesn't depend on which identity option you choose. A managed identity and a service principal both need this same cluster-scoped permission before a host can successfully register.

## Choose the identity option for your host machine

Use the following questions to determine your flex node's identity configuration:

- **Does your host run outside Azure but connect through Azure Arc?** Use the Azure Arc managed identity. Connect the server to Azure Arc first if it isn't already.
- **Is your host any other virtual machine or bare-metal hardware?** Use a service principal, and prefer a certificate credential over a secret.
- **Does your host run as an Azure virtual machine?** Use a managed identity. Pick system-assigned for a single machine, or user-assigned if you want to reuse the identity across machines or manage it independently of the VM.

## Next steps

- [Learn how flex nodes work](flex-nodes-for-aks-overview.md).
- [Learn about networking concepts for flex nodes](flex-nodes-networking-concepts.md).
- [Plan a flex nodes deployment](plan-flex-nodes-deployment.md).