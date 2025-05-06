---
title: About the Availability Sets deprecation in Azure Kubernetes Services (AKS)
description: Learn about the deprecation of Availability Sets in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.date: 04/04/2025
ms.author: wilsondarko
author: wdarko1
---

# Availability Sets deprecation in Azure Kubernetes Service (AKS)

This article details how Azure Kubernetes Service (AKS) is phasing out support for Virtual Machine Availability Sets (VMAS) in favor of Virtual Machines (VMs).

> [!NOTE]
> We recommend using [Virtual Machine Node Pools (Preview)](virtual-machines-node-pools.md) for AKS-optimized VMs.
>
> Virtual Machine Node Pools:
>
> - Allow VM instances to be centrally managed, configured, and updated.
> - Allow an increase or decrease of the number of virtual machine instances in response to demand or a defined schedule.
> - Allow single node-level controls and same-family mixing of different sized nodes to lift restrictions from a single model and improve consistency.
>

## Availability Sets overview

Availability sets are logical groupings of VMs that reduce the chance of correlated failures bringing down related VMs at the same time. Availability sets place VMs in different fault domains for better reliability.

### Phase out of Availability Sets

As of 2019, we're no longer adding other features to Availability Sets in AKS. Any features introduced since 2019, such as AKS Backup, aren't supported in Availability Sets node pools.

### When will Availability Sets be fully deprecated?

Availability Sets support will be **fully deprecated by September 30, 2025**. We recommend that you migrate all workloads currently on VMAS to Virtual Machine Node Pools. 

### Automatic migration

Starting September 30, 2025, we'll automatically migrate remaining Availability Sets node pools to Virtual Machines node pools. 

### Related content

[More information on Virtual Machine node pools](virtual-machines-node-pools.md)
