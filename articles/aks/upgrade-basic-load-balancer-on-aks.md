---
title: Upgrading from Basic Load Balancer on AKS
description: Upgrade guidance for migrating Basic Load Balancer to Standard Load Balancer on AKS.
author: wdarko1
ms.author: wilsondarko
ms.topic: how-to
ms.date: 08/29/2025
# Customer intent: As an cloud engineer with Basic Load Balancer services, I need guidance and direction on migrating my workloads off Basic to Standard SKUs
---

# Upgrading from Basic Load Balancer on Azure Kubernetes Service

On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you are currently using Basic Load Balancer, make sure to upgrade to Standard Load Balancer prior to the retirement date to avoid your cluster being out of support. This article will help guide you through the upgrade process. 

In this article, we discuss AKS-specific guidance for upgrading your Basic Load Balancer instances to Standard Load Balancer on Azure Kubernetes Services (AKS). Standard Load Balancer is recommended for all production instances and provides many [key differences](/azure/load-balancer/load-balancer-basic-upgrade-guidance#basic-load-balancer-sku-vs-standard-load-balancer-sku) to your infrastructure. For guidance on upgrading your Basic Load Balancer instances to Standard Load Balancer outside of AKS, see the [official guidance for Basic load balancer upgrade][load-balancer-upgrade-guidance]

>[!Note]
>For clusters using both Availability Sets and the Basic Load Balancer, there is a separate `az aks update` command that must be run to perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the guidance for [Availability Sets migration][availability-sets].

### Before You Begin

- Downtime occurs during migration. 
- This process will also migrate your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. New public IPs are created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic.

**Requirements**

If a cluster does not meet these requirements, the migration tool will be blocked from running: 
- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli). Minimum version 2.76.0
- If the cluster is running Key Management Service with private key vault, Key Management Service must be disabled during the migration. For more information, visit [Turn Off KMS][turn-off-kms].
- If the cluster is using any ValidatingAdmissionWebhooks or MutatingAdmissionWebhooks, these must be disabled during the migration.

**Preparing for Migration**
- Create a migration plan for planned downtime.
- Once the migration is started, roll back is not allowed.

### Run Command to Upgrade Basic load Balancer to Standard

1. The following command initiates a script to upgrade your Basic load balancer to Standard using the `az aks update` command, and setting `--load-balancer-sku` to `Standard`.

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

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#turn-off-kms
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[load-balancer-upgrade-guidance]: /azure/load-balancer/load-balancer-basic-upgrade-guidance
[load-balancer-basic-vs-standard]: azure/load-balancer/load-balancer-basic-upgrade-guidance#basic-load-balancer-sku-vs-standard-load-balancer-sku
[availability-sets]: availability-sets-on-aks.md
[More information on Virtual Machine node pools]: virtual-machines-node-pools.md
