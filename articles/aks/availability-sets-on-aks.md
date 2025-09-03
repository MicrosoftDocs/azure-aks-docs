---
title: About the Availability Sets deprecation in Azure Kubernetes Services (AKS)
description: Learn about the deprecation of Availability Sets in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.date: 08/29/2025
ms.author: wilsondarko
author: wdarko1
# Customer intent: As a Kubernetes administrator, I want to migrate my workloads from Virtual Machine Availability Sets to Virtual Machine Node Pools, so that I can ensure ongoing support and take advantage of enhanced management features before the deprecation deadline.
---

#  Migrate from Availability Sets in Azure Kubernetes Service (AKS)

This article details how Azure Kubernetes Service (AKS) is phasing out support for Virtual Machine Availability Sets (VMAS) in favor of Virtual Machines (VMs).

> [!NOTE]
> We recommend using [Virtual Machine Node Pools (Preview)](virtual-machines-node-pools.md) for AKS-optimized VMs.
>
> Virtual Machine Node Pools:
>
> - Allow VM instances to be centrally managed, configured, and updated.
> - Allow an increase or decrease of the number of virtual machine instances in response to demand or a defined schedule.
> - Allow single node-level controls and same-family mixing of different sized nodes, increasing flexibility and improving consistency.
>

## Availability Sets overview

Availability sets are logical groupings of virtual machines(VM) that reduce the chance of correlated failures bringing down related VMs at the same time. Availability sets place VMs in different fault domains for better reliability.

### Phase out of Availability Sets

As of 2019, we're no longer adding other features to Availability Sets in AKS. Any features introduced since 2019, such as AKS Backup, aren't supported in Availability Sets.

### Availability Sets Retirement Date

Availability Sets support will be **fully deprecated by September 30, 2025**. We recommend that you migrate all workloads currently on VMAS to Virtual Machine Node Pools. After September 30th, the feature will no longer be supported. A cluster with Availability Sets after this date is considered out of support.

## Migrate from Availability Sets to Virtual Machines node pools

There is now a way to use a script to migrate your AKS cluster from using Availability Sets to Virtual Machines node pools. This script also automatically upgrades the Basic-tier load balancers in your cluster to Standard-tier.

>[!IMPORTANT]
>This process also migrates your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. During this process, a new public IPs is created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic.

### Before You Begin

**Requirements**
- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the version 2.76.0 [Azure CLI installed](/cli/azure/install-azure-cli).
- If the cluster is running Key Management Service with private key vault, Key Management Service must be [disabled][turn-off-kms] for the duration of the migration.
- If the cluster is using any ValidatingAdmissionWebhooks or MutatingAdmissionWebhooks, these web hooks must be disabled before the migration.

**Preparing for Migration**
- Create a migration plan for planned downtime.
- Once the migration is started, roll back is not allowed.
- While in preview, we recommend you start using this migration CLI command on your test environments. Should any issues arise, [file a support ticket][file-support-ticket].

### Run Migration Script for Availability Set Migration

1. The following command initiates a script to migrate a cluster from using Availability Sets to Virtual Machines node pools using the `az aks update` command, and setting `--migrate-vmas-to-vms`. This script will also upgrade the Basic load Balancer and Basic IP to Standard Load Balancer and Standard IP, if applicable.

```azurecli-interactive
az aks update \
    --name $clusterName \
    --resource-group $resourceGroup \
    --migrate-vmas-to-vms \
```

2. Verify that the migration was successful using the `az aks show` command. The output of this command will show the cluster details.

```azurecli-interactive
az aks show \
    --name $clusterName \
    --resource-group $resourceGroup
```

A successful migration can be verified when the cluster details using the `az aks show` command include a `type` set to `VirtualMachines`, and `loadbalancerSku` set to `Standard`. 

```azurecli-interactive
    "type": "VirtualMachines"
    "loadBalancerSku": "standard",
```

3. Verify that all pods and services are running successfully using the `kubectl get pods` and `kubectl get svc` commands:

```azurecli-interactive
  kubectl get svc -A \
  kubectl get pods -A
```

4. You can confirm the new IP addresses associated with outbound rules by listing the outbound IP addresses. This step is done by confirming the Resource IDs for the IP addresses, then listing the IP addresses. 

Use the following command to get the Resource ID for the outbound IP addresses:

```azurecli-interactive
  # Get the outbound IP Resource ID
  az aks show -g <myResourceGroup> -n <myAKSCluster> --query networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id
```

Use the following command to get each IP address for the Resource ID:

```azurecli-interactive
  # get the new IP for each IP Resource ID
  az network public-ip show --ids <IPResourceID> --query ipAddress -o tsv
```

### Related content

<!-- LINKS - internal -->

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#turn-off-kms
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[More information on Virtual Machine node pools](virtual-machines-node-pools.md)

<!-- LINKS - External -->
[file-support-ticket]: https://azure.microsoft.com/support/create-ticket

