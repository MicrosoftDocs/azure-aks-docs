---
title: What are flex nodes for AKS? (preview)
description: Learn how flex nodes extend Azure Kubernetes Service to external virtual machines and bare metal hosts for Kubernetes workloads.
ms.topic: concept-article
ms.date: 08/28/2026
author: sdesai345
ms.author: sachidesai
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Attach external compute as flex nodes for Azure Kubernetes Service (AKS) (preview)

Flex nodes extend Azure Kubernetes Service (AKS) to user-managed virtual
machines and bare metal hosts. Use flex nodes to add existing compute capacity
to an AKS cluster without moving that compute into a standard AKS node pool.
This capability is useful when you need to access capacity outside the AKS
cluster's Azure region. It lets you manage these nodes through AKS lifecycle
operations while retaining control of the underlying machines.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## How flex nodes work

A flex node runs on a virtual machine (VM) or bare metal host machine that you manage. 
The flex node agent prepares the machine, joins it to an AKS cluster, and keeps its
node configuration aligned with the state requested by AKS. The agent runs the
node in an isolated environment so that it can update the node
without replacing the underlying machine.

The agent creates an isolated Kubernetes node environment on the host. After
the node joins the cluster, Kubernetes can schedule workloads to it according
to the scheduling configuration that you define. 

## Flex node components

Flex nodes use the following components:

- **User-managed host**: A virtual machine or bare metal host that provides
  compute capacity and runs the flex node agent.
- **Flex node agent**: Software on the host that bootstraps the node
  environment, joins the host to the cluster, and keeps the node
  aligned with the configuration requested by AKS. The agent is open
  source in the [AKSFlexNode repository](https://aka.ms/aks-flex-node/github).
- **AKS cluster**: The cluster control plane schedules and manages Kubernetes
  workloads across standard node pools and connected flex nodes.
- **ARM machine resource**: An Azure Resource Manager (ARM) resource that stores the
  authoritative desired state for one flex node instance, including its
  desired Kubernetes version.
- **AKS management APIs**: Lifecycle operations that you use to manage a pool of flex nodes.

## Authentication options for flex nodes

Flex nodes support multiple authentication methods for different host and
connectivity models.

| Authentication method | When to use it |
| --- | --- |
| Azure Arc managed identity | Azure Arc extends Azure's trust relationship to a non-Azure server, so that server can also get a secretless identity. |
| System-assigned or user-assigned managed identity | Azure already manages the VM, so it can hand the VM a secretless identity directly. |
| Service principal | Azure has no existing relationship with the host, so you create and manage an application identity for it yourself. |

Choose an authentication method that matches how you manage host identity and
access in your environment.

The flex node agent uses two separate identities with limited permissions. One identity communicates with Azure to get the node's desired configuration and report its status. The other identity communicates with Kubernetes to monitor the node and remove it from the cluster after a reset or delete operation.

## Workload scenarios for flex nodes

Flex nodes are useful for scenarios in which standard AKS node pools might not provide the
required host location or regional capacity, or when selected jobs need to run
on your own infrastructure to support your data residency strategy.

### Capacity outside the AKS region

Connect your virtual machines or bare metal hosts located outside
the AKS cluster's Azure region. Flex nodes make this capacity available to the
cluster and let you schedule selected jobs on your own infrastructure when
needed for data residency.

### Lab and test environments

Use available virtual machines or physical hosts as AKS nodes in lab and
test environments. Support for both `amd64` and `arm64` hosts lets you evaluate
workloads across processor architectures.

## Flex nodes and standard AKS node pools

Standard AKS node pools use Azure virtual machines that AKS provisions and
manages as part of the cluster. Flex nodes use virtual machines or bare metal
hosts that you manage outside standard AKS node pools.

Use standard node pools for workloads that fit the AKS-managed Azure virtual
machine model. Consider flex nodes when selected jobs need to run on your own
infrastructure to support data residency, when you need to connect bare metal hardware,
or when you need capacity outside the cluster's Azure region.

Flex nodes don't replace standard node pools. A cluster can use standard node
pools for general workloads and flex nodes for workloads that need a different
host model.

## Next steps

- [Learn about identity and access for flex nodes](flex-nodes-identity-access-concepts.md).
- [Learn about networking concepts for flex nodes](flex-nodes-networking-concepts.md).
- [Plan a flex nodes deployment](plan-flex-nodes-deployment.md).
