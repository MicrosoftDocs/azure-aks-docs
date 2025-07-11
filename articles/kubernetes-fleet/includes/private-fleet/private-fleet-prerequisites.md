---
ms.author: alimuhammad
ms.topic: include
ms.date: 06/26/2025
ms.service: azure-kubernetes-fleet-manager
---

When you create a Fleet Manager with a private hub cluster, take these additional considerations into account:
- Fleet Manager requires you to provide the subnet on which the Fleet Manager hub cluster's node Virtual Machine (VM) is placed. This can be done by setting `subnetId` in the `agentProfile` within the Fleet Manager's `hubProfile`.
-  The address prefix of the vnet **vnetName** must not overlap with the Azure Kubernetes Service's (AKS) default service range of `10.0.0.0/16`.
- Private access mode doesn't allow configuring domain names.
- Private access mode requires a `Network Contributor` role assignment on the agent subnet for Fleet Manager's first party service principal (Fleet Manager's first party service principal ID varies across different Entra tenants). This role assignment is **NOT** needed when creating private Fleet Manager using the `az fleet create` command because the CLI automatically creates the role assignment.
