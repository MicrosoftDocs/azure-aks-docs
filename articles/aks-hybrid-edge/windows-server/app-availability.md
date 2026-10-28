---
title: Application availability in AKS on Windows Server
description: Learn about application availability in on Windows Server.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: rbaziwane
ms.custom: windows-server

# Intent: As an IT Pro, I need to understand how disruptions can impact the availability of applications on my AKS deployments on Windows Server.
# Keyword: AKS on Windows Server architecture live migration disruption Kubernetes container orchestration
---

# Application availability in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Azure Kubernetes Service (AKS) on Windows Server offers a fully supported container platform that can run cloud-native applications on the [Kubernetes container orchestration platform](https://kubernetes.io/). The architecture supports running virtualized Windows and Linux workloads.

The AKS architecture is built with failover clustering and live migration that is automatically enabled for target (workload) clusters. During various disruption events, virtual machines that host customer workloads are freely moved around without perceived application downtime. This architecture means that a traditional enterprise customer, who's managing a legacy application as a singleton to AKS on Windows Server, gets similar (or better) uptime than what's currently experienced on a legacy VM application.

This article describes some fundamental concepts for users who want to run containerized applications on AKS with live migration enabled in order to ensure applications are available during a disruption. Kubernetes terminology, such as *voluntary disruption* and *involuntary disruption*, is used to refer to downtime of an application running in a pod.

## What is live migration?

[*Live migration*](/windows-server/virtualization/hyper-v/manage/live-migration-overview) is a Hyper-V feature that allows you to transparently move running virtual machines from one Hyper-V host to another without perceived downtime. The primary benefit of live migration is flexibility; running virtual machines is not tied to a single host machine. This allows users to perform actions such as draining a specific host of virtual machines before decommissioning or upgrading the host. When paired with Windows Failover Clustering, live migration enables the creation of highly available and fault tolerant systems.

The current architecture of AKS on Windows Server assumes that you enabled live migration in your Windows Server clustered environment. Therefore, all Kubernetes worker node VMs are created with live migration configured. These nodes can be moved around physical hosts in the event of a disruption to ensure the platform is highly available.

:::image type="content" source="../media/app-availability/cluster-architecture.png" alt-text="Diagram showing AKS on Windows Server with Failover Clustering enabled." lightbox="../media/app-availability/cluster-architecture.png":::

When you run a legacy application as a singleton on top of Kubernetes, this architecture meets your high availability needs. Kubernetes manages the scheduling of pods on available worker nodes while live migration manages the scheduling of worker node VMs on available physical hosts.

:::image type="content" source="../media/app-availability/singleton.png" alt-text="Diagram showing an example legacy application running as a singleton." lightbox="../media/app-availability/singleton.png":::

## Application disruption scenarios

A comparative study of the recovery times for applications running in VMs on AKS on Windows Server clearly shows that there is minimal impact on the application when common disruption events occur. Three example disruption scenarios include:

- Applying an update that results in a reboot of the physical machine.
- Applying an update that involves recreating the worker node.
- Unplanned hardware failure of a physical machine.

> [!NOTE]
> These scenarios assume that the application owner still uses Kubernetes affinity and anti-affinity settings to ensure proper scheduling of pods across worker nodes.

| Disruption event |       Running applications in VMs on Windows Server            |
| ------------------------------------------------------------ | ---------------------------- |
| Apply an update that results in a reboot of the physical machine | No  impact        |
| Apply an update that involves recreating the worker node (or rebooting the VM) | Varies            |
| Unplanned hardware failure of a physical machine            | 6-8 minutes    |

### Apply an update that results in a reboot of the physical machine

During a physical host maintenance event, such as applying an update that results in the reboot of a host machine, no impact is expected for applications running in the cluster. The cluster administrator drains the host and ensures that all VMs are live migrated before applying the update.

### Apply an update that involves recreating the worker node

This scenario involves bringing down a worker node VM to perform routine maintenance. To prepare for the update, the cluster administrator drains and isolates the node, so that all pods are evicted to an available worker node before applying updates. Once the update is completed, the worker node is rejoined and made available for scheduling.

> [!NOTE]
> The availability of an application varies, as it includes the time it takes to download the base container image, especially for larger images stored in the public cloud. Therefore, it's recommended that you use small base container images, and for Windows containers, it's recommended that you use the `nano server` base image.

### Unplanned hardware failure of a physical machine

In this scenario, an involuntary disruption event occurs to a physical machine hosting a legacy application container/pod in one of the worker node VMs. Failover clustering places the host in an isolated state, and then after a period of 6 to 8 minutes, starts the process of live migrating these VMs to surviving hosts. In this case, the application downtime is the equivalent of the time it takes to restart the host and worker node VMs.

## Conclusion

AKS failover clustering technologies are designed to ensure that computing environments in Windows Server are highly available and fault tolerant. However, the application owner still has to configure deployments to use Kubernetes features, such as `Deployments`, `Affinity Mapping`, `RelicaSets`, to ensure that the pods are resilient in disruption scenarios.

## Next steps

[AKS on Windows Server overview](overview.md)
