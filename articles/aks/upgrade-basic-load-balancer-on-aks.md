---
title: Upgrading from Basic Load Balancer on AKS
description: Upgrade guidance for migrating Basic Load Balancer to Standard Load Balancer on AKS.
author: wdarko1
ms.author: wilsondarko
ms.topic: how-to
ms.date: 08/5/2025
# Customer intent: As an cloud engineer with Basic Load Balancer services, I need guidance and direction on migrating my workloads off Basic to Standard SKUs
---

# Upgrading from Basic Load Balancer on AKS (preview)

>[!Important]
>On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you are currently using Basic Load Balancer, make sure to upgrade to Standard Load Balancer prior to the retirement date to avoid a forced migration and unscheduled downtime. This article will help guide you through the upgrade process. 

In this article, we discuss AKS-specific guidance for upgrading your Basic Load Balancer instances to Standard Load Balancer. Standard Load Balancer is recommended for all production instances and provides many [key differences](/azure/load-balancer/load-balancer-basic-upgrade-guidance#basic-load-balancer-sku-vs-standard-load-balancer-sku) to your infrastructure.
This process will also migrate your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. New public IPs will be created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic. For guidance on upgrading your Basic Load Balancer instances to Standard Load Balancer, see the [official guidance for Basic load balancer upgrade][load-balancer-upgrade-guidance]

>[!Note]
>For clusters using both Availability Sets and the Basic Load Balancer, there is a separate script that must be used that will perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the guidance for [Availability Sets migration][availability-sets].

### Before You Begin

>[!Important]
>Downtime occurs during migration. We recommend you test the migration in a development or test environment before trying it out with a production cluster.


**Requirements**
- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli). Minimum version 2.72.0
- [Install the `aks-preview` Azure CLI extension.  Minimum version 0.5.170](#install-the-aks-preview-cli-extension).
- If the cluster is running Key Management Service with private key vault, this must be disabled for the duration of the migration
- If the cluster is using any ValidatingAdmissionWebhooks or MutatingAdmissionWebhooks, these must be disabled for the duration of the migration.

**Preparing for Migration**
- Create a migration plan for planned downtime.
- Once the migration is started, roll back is not allowed.

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

### Run Command to Upgrade Basic load Balancer to Standard

1. The following command initiates a script to upgrade your Basic load balancer to Standard using the `az aks update` command, and setting `--load-balancer-sku` to `Stanadard` and enabling the preview feature flag `BasicLBMigrationToStandardPreview`.

```azurecli-interactive
az aks update \
    --name $clusterName \
    --resource-group $resourceGroup \
    --load-balancer-sku=Standard 
```

2. Verify that the migration was successful using the `az aks show` command, and confirm the load-balancer type is set to Standard:
```azurecli-interactive
az aks show \
    --name $clusterName \
    --resource-group $resourceGroup
```

3. Verify that all pods and services are running successfully using the `kubectl get pods` and `kubectl get svc` commands:
```azurecli-interactive
  kubectl get svc -A \
  kubectl get pods -A
```

4. You can confirm the new IP addresses associated with outbound rules by listing the outbound IP addresses. This is done by confirming the Resource IDs for the IP addresses, then listing the IP addresses. 

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

[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[load-balancer-upgrade-guidance]: /azure/load-balancer/load-balancer-basic-upgrade-guidance
[load-balancer-basic-vs-standard]: azure/load-balancer/load-balancer-basic-upgrade-guidance#basic-load-balancer-sku-vs-standard-load-balancer-sku
[availability-sets]: availability-sets-on-aks.md
[More information on Virtual Machine node pools]: virtual-machines-node-pools.md
