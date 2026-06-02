---
title: Availability Sets Deprecation in Azure Kubernetes Services (AKS)
description: Learn about the deprecation of Availability Sets and how to migrate from Availability Sets to Virtual Machines node pools in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.date: 03/30/2026
ms.author: wilsondarko
author: wdarko1

# Customer intent: As a Kubernetes administrator, I want to migrate my workloads from Virtual Machine Availability Sets to Virtual Machine node pools, so that I can ensure ongoing support and take advantage of enhanced management features before the deprecation deadline.
---

# Migrate from Availability Sets in Azure Kubernetes Service (AKS)

This article details how Azure Kubernetes Service (AKS) is phasing out support for Virtual Machine Availability Sets (VMAS) in favor of Virtual Machines (VMs). We recommend using [Virtual Machine node pools](virtual-machines-node-pools.md) for AKS-optimized VMs.

Virtual Machine node pools:

- Allow VM instances to be centrally managed, configured, and updated.
- Allow an increase or decrease of the number of virtual machine instances in response to demand or a defined schedule.
- Allow single node-level controls and same-family mixing of different sized nodes, which increases flexibility and improves consistency.

[!INCLUDE [availability-sets-retirement](./includes/availability-sets-retirement.md)]

## Availability Sets overview

Availability sets are logical groupings of virtual machines (VM) that reduce the chance of correlated failures bringing down related VMs at the same time. Availability sets place VMs in different fault domains for better reliability.

### Phase out of Availability Sets

As of 2019, we're no longer adding other features to Availability Sets in AKS. Any features introduced since 2019, such as AKS Backup, aren't supported in Availability Sets.

## Migrate from Availability Sets to Virtual Machines node pools

There's now a way to use a script to migrate your AKS cluster from using Availability Sets to Virtual Machines node pools. This script also automatically upgrades the Basic-tier load balancers in your cluster to Standard-tier.

>[!IMPORTANT]
>This process also migrates your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. During this process, a new public IP is created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic.
>
> For more information and an FAQ about the upgrade from Basic Load Balancer to Standard Load Balancer, see [Upgrade from Basic Load Balancer on Azure Kubernetes Service](upgrade-basic-load-balancer-on-aks.md).

### Before You Begin

**Requirements**
- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the version 2.76.0 [Azure CLI installed](/cli/azure/install-azure-cli).
- If the cluster is running Key Management Service with private key vault, Key Management Service must be [disabled][turn-off-kms] during the entire migration.
- If the cluster is using any `ValidatingAdmissionWebhooks` or `MutatingAdmissionWebhooks`, these webhooks must be disabled before the migration. Control plane default webhooks shouldn't be disabled. For example `aks-node-mutating-webhook`, `webhook-admission-controller`, and `aks-node-validating-webhook`.

**Preparing for Migration**
- Create a migration plan for planned downtime.
- Once the migration is started, roll back isn't allowed.

### Run Migration Script for Availability Set Migration

In the following commands, replace `<myResourceGroup>` and `<myAKSCluster>` with your resource group name and AKS cluster name.

1. The following command initiates a script to migrate a cluster from using Availability Sets to Virtual Machines node pools using the `az aks update` command, and setting `--migrate-vmas-to-vms`. This script also upgrades the Basic Load Balancer and Basic IP to Standard Load Balancer and Standard IP, if applicable.

    ```azurecli-interactive
    az aks update \
      --name <myAKSCluster> \
      --resource-group <myResourceGroup> \
      --migrate-vmas-to-vms \
    ```

1. Verify that the migration was successful using the `az aks show` command. The command's output shows the cluster details.

    ```azurecli-interactive
    az aks show \
      --name <myAKSCluster> \
      --resource-group <myResourceGroup>
    ```

    A successful migration can be verified when the cluster details using the `az aks show` command include a `type` set to `VirtualMachines`, and `loadbalancerSku` set to `Standard`.

    ```azurecli-interactive
      "type": "VirtualMachines"
      "loadBalancerSku": "standard",
    ```

1. Verify that all pods and services are running successfully using the `kubectl get pods` and `kubectl get svc` commands:

    ```azurecli-interactive
    kubectl get svc -A \
    kubectl get pods -A
    ```

1. You can confirm the new IP addresses associated with outbound rules by listing the outbound IP addresses. This step is done by confirming the Resource IDs for the IP addresses, then listing the IP addresses.

    Use the following command to get the Resource ID for the outbound IP addresses:

    ```azurecli-interactive
    # Get the outbound IP Resource ID
    az aks show \
      --resource-group <myResourceGroup> \
      --name <myAKSCluster> \
      --query networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id
    ```

    Use the following command to get each IP address for the Resource ID and replace `<IPResourceID>` with the Resource ID from the previous command:

    ```azurecli-interactive
    # get the new IP for each IP Resource ID
    az network public-ip show --ids <IPResourceID> --query ipAddress -o tsv
    ```

### Related content

- [More information on Virtual Machine node pools](virtual-machines-node-pools.md)
- [Upgrade from Basic Load Balancer on Azure Kubernetes Service](upgrade-basic-load-balancer-on-aks.md)

<!-- LINKS - internal -->

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#turn-off-kms
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update


<!-- LINKS - External -->
[file-support-ticket]: https://azure.microsoft.com/support/create-ticket
