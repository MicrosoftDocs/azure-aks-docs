---
title: About the Availability Sets deprecation in Azure Kubernetes Services (AKS)
description: Learn about the deprecation of Availability Sets in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.date: 06/30/2025
ms.author: wilsondarko
author: wdarko1
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
> - Allow single node-level controls and same-family mixing of different sized nodes to lift restrictions from a single model and improve consistency.
>

## Availability Sets overview

Availability sets are logical groupings of VMs that reduce the chance of correlated failures bringing down related VMs at the same time. Availability sets place VMs in different fault domains for better reliability.

### Phase out of Availability Sets

As of 2019, we're no longer adding other features to Availability Sets in AKS. Any features introduced since 2019, such as AKS Backup, aren't supported in Availability Sets node pools.

### When will Availability Sets be fully deprecated?

Availability Sets support will be **fully deprecated by September 30, 2025**. We recommend that you migrate all workloads currently on VMAS to Virtual Machine Node Pools. 

### Automatic migration

Starting September 30, 2025, we'll automatically migrate remaining Availability Sets node pools to Virtual Machines node pools. We recommend a planned migration using the Azure CLI command to minimize downtime for your workloads.

## Migrate from Availability Sets to Virtual Machines node pools (Preview)

There is now a way to use a script to migrate your AKS cluster from using Availability Sets to Virtual Machines node pools. This script will also automatically upgrade the Basic-tier load balancers in your cluster to Standard, as well as the Basic IPs to Standard, while keeping the Public IP addresses the same. While

### Before You Begin

**Requirements**
- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli).
- [Install the `aks-preview` Azure CLI extension.  Minimum version 0.5.170](#install-the-aks-preview-cli-extension).
- If the cluster is running Key Management Service with private key vault, this must be [disabled][turn-off-kms] for the duration of the migration
- If the cluster is using any ValidatingAdmissionWebhooks or MutatingAdmissionWebhooks, these must be disabled for the duration of the migration.

**Preparing for Migration**
- Create a migration plan for planned downtime.
- Once the migration is started, roll back is not allowed.
- While in preview, we recommend you start using this migration CLI command on your test environments. Should any issues arise, [file a support ticket][file-support-ticket].

### Install the `aks-preview` CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Install the `aks-preview` CLI extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update the extension to ensure you have the latest version installed using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `BasicLBMigrationToStandardLBPreview` feature flag

1. Register the `BasicLBMigrationToStandardLBPreview` feature flag using the `az feature register` command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "BasicLBMigrationToStandardLBPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the `az feature show` command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "BasicLBMigrationToStandardLBPreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the `az provider register` command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Run Migration Script for Availability Set Migration

1. The following command initiates a script to migrate a cluster from using Availability Sets to Virtual Machines node pools using the `az aks update` command, and setting `--migrate-vmas-to-vms`and enabling the preview feature flag `BasicLBMigrationToStandardPreview`.

```azurecli-interactive
az aks update \
    --name $clusterName \
    --resource-group $resourceGroup \
    --migrate-vmas-to-vms \
```

2. Verify that the migration was successful using the `az aks show` command, which will show the cluster details.
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
   

### Related content

<!-- LINKS - internal -->

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#turn-off-kms
[file-support-ticket]: azure/azure-portal/supportability/how-to-create-azure-support-request
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[More information on Virtual Machine node pools](virtual-machines-node-pools.md)
