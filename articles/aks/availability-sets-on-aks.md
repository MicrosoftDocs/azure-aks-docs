---
title: Availability Sets retirement in Azure Kubernetes Services (AKS)
description: Learn about Availability Sets retirement for AKS clusters.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 01/24/2025
ms.author: wilsondarko
author: wdarko1
#Customer intent: As a cluster operator or developer, I want to learn how to enable my cluster to create node pools with multiple Virtual Machine types.
---

# Availability Sets deprecation - Azure Kubernetes Services

This article will detail how Azure Kubernetes Services (AKS) is phasing out support for Virtual Machine Availability Sets (VMAS). 
Azure Kubernetes Services is moving away from Availability Sets in favor of Virtual Machines.

> [!NOTE]
> We recommend customers use [Virtual Machine Node Pools(Public Preview)](virtual-machines-node-pools.md) for an AKS optimized virtual machine. Virtual Machine Node Pools:
>
> - Allow VM instances to be centrally managed, configured, and updated.
> - Automatically increase or decrease the number of VM instances in response to demand or a defined schedule.
>
> Availability sets offer only high availability.

# Availability Sets Overview
Availability sets are logical groupings of VMs that reduce the chance of correlated failures bringing down related VMs at the same time. Availability sets place VMs in different fault domains for better reliability.

# Phase out of Availablity Sets support
As of 2019, we are no longer adding additional features to Availability Sets in Azure Kubernetes Services. Any features introduced since 2019. such as AKS Backup, will not be available in Availability Set node pools.

# When will VMAS be fully deprecated?
Availability Sets support will be fully deprecated by September 30th, 2025. We recommend all workloads currently on VMAS be migrated to Virtual Machine Node Pools. 

### Automatic migration
Starting September 30th, we will automatically migrate remaining Availability Set node pools to Virtual Machines node pools. 

## Related Content

[More information on Virtual Machine node pools](virtual-machines-node-pools.md)