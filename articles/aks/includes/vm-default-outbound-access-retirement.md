---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/14/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> Starting on **March 31, 2026**, Azure Kubernetes Service (AKS) no longer supports default outbound access for virtual machines (VMs). New AKS clusters that use the **AKS-managed virtual network** option will place cluster subnets into [private subnets](/azure/virtual-network/ip-services/default-outbound-access#why-is-disabling-default-outbound-access-recommended) by default (`defaultOutboundAccess = false`). This setting **doesn't impact AKS-managed cluster traffic**, which uses explicitly configured outbound paths. It might affect **unsupported scenarios**, such as deploying other resources into the same subnet. Clusters using **BYO VNets are unaffected** by this change. In supported configurations, no action is required. For more information on this retirement, see [Default outbound access for VMs retirement](https://azure.microsoft.com/updates?id=default-outbound-access-for-vms-in-azure-will-be-retired-transition-to-a-new-method-of-internet-access).