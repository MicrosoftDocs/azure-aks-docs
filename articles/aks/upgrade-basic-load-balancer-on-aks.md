---
title: Upgrade from Basic Load Balancer on Azure Kubernetes Service (AKS)
description: Upgrade guidance for migrating Basic Load Balancer to Standard Load Balancer on AKS.
author: wdarko1
ms.author: wilsondarko
ms.topic: how-to
ms.date: 08/29/2025
ms.service: azure-kubernetes-service
# Customer intent: As an cloud engineer with Basic Load Balancer services, I need guidance and direction on migrating my workloads off Basic to Standard SKUs
---

# Upgrade from Basic Load Balancer on Azure Kubernetes Service (AKS)

In this article, you learn how to upgrade your Basic Load Balancer instances to Standard Load Balancer on Azure Kubernetes Services (AKS). We recommend using Standard Load Balancer for all production instances. It provides many [key differences](/azure/load-balancer/load-balancer-basic-upgrade-guidance#basic-load-balancer-sku-vs-standard-load-balancer-sku) to your infrastructure. For guidance on upgrading from Basic Load Balancer to Standard Load Balancer outside of AKS, see the [official guidance for Basic Load Balancer upgrade][load-balancer-upgrade-guidance].

> [!IMPORTANT]
> On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you are currently using Basic Load Balancer, make sure to upgrade to Standard Load Balancer prior to the retirement date to avoid your cluster being out of support. This article will help guide you through the upgrade process.

> [!NOTE]
> For clusters using both Availability Sets and the Basic Load Balancer, there's a separate `az aks update` command you need to run to perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the [Availability Sets migration][availability-sets] guidance.

## Before you begin

Before you begin the migration, be aware of the following:

- Downtime occurs during migration. Plan for downtime accordingly.
- Once the migration begins, roll back isn't allowed.
- This process also migrates your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. New public IPs are created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic.

## Prerequisites

If your cluster doesn't meet the following requirements, the migration tool will be blocked from running:

- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli). The minimum version you need is 2.76.0.
- If the cluster runs Key Management Service with private key vault, you need to disable Key Management Service before performing the migration. For more information, see [Turn off KMS][turn-off-kms].
- You need to disable any `ValidatingAdmissionWebhooks` or `MutatingAdmissionWebhooks` before performing the migration.

## Upgrade Basic Load Balancer to Standard Load Balancer

1. Upgrade your Basic Load Balancer to Standard Load Balancer using the [`az aks update`](/cli/azure/aks#az_aks_create) command with the `--load-balancer-sku` flag set to `Standard`.

    ```azurecli-interactive
    az aks update \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP \
      --load-balancer-sku=Standard
    ```

1. Verify the migration was successful using the [`az aks show`](/cli/azure/aks#az_aks_show) command.

    ```azurecli-interactive
    az aks show \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP
    ```

    In the output, confirm the `load-balancer` type is set to `Standard`.

1. Verify that all pods and services are running successfully using the `kubectl get pods` and `kubectl get svc` commands.

    ```bash
    kubectl get svc -A
    kubectl get pods -A
    ```

### Confirm new outbound IP addresses

You can confirm the new IP addresses associated with outbound rules by confirming the resource IDs for the IP addresses and then listing the IP addresses.

1. Get the resource ID for the outbound IP addresses using the [`az aks show`](/cli/azure/aks#az_aks_show) command.

    ```azurecli-interactive
    az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id
    ```

1. Get the new IP address for each resource ID using the [`az network public-ip show`](/cli/azure/network/public-ip#az_network_public_ip_show) command.

    ```azurecli-interactive
    az network public-ip show --ids $IP_RESOURCE_ID --query ipAddress -o tsv
    ```

## FAQ

### Why am I getting `Error: “Load Balancer SKU 'basic' is invalid; must use 'standard'.` when creating a new AKS cluster or upgrading?

Microsoft deprecated Basic Load Balancer SKU for certain AKS operations, and creation is now blocked in some regions.

To resolve this, make sure you specify `--load-balancer-sku standard` when creating a new cluster. For example:

```azurecli-interactive
az aks create \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --load-balancer-sku standard
```

### Why can’t I simply change my Basic Load Balancer to Standard Load Balancer in-place?

The Load Balancer SKU is immutable after creation in AKS, as it's a managed resource owned by the cluster.

You can resolve this using one of the following options:

- **Option 1**: Use the `az aks update run` command to upgrade Basic Load Balancer to Standard. For more information, see [Upgrade Basic Load Balancer on Azure Kubernetes Service (AKS)](./upgrade-basic-load-balancer-on-aks.md).
- **Option 2**: Create a new AKS cluster with Standard Load Balancer (blue-green migration) and move any existing workloads.

### After changing to Standard Load Balancer, why can't I find my public IP?

The Load Balancer object lost the reference to your public IP resource during migration. This can occur if the IP was tied to the Basic SKU Load Balancer and wasn't rebound.

To resolve this:

1. Ensure the new Standard public IP exists in the correct resource group.
2. Reassociate it in the service manifest using the following configuration:

    ```yaml
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-ipv4: <your-ip>
    ```

### When migrating the load balancer on a private cluster without a public IP, why is a public IP still created during the migration?

If `outboundType` is `LoadBalancer`, AKS automatically provisions a public IP (PIP), regardless of Load Balancer SKU.

To resolve this:

1. Change `outboundType` to `userDefinedRouting` for a fully private cluster.
2. Ensure custom outbound routing is configured via Azure Firewall/NVA.

### Why does migration fail in my internal Load Balancer setup?

Current migration tooling doesn’t support internal virtual network (VNet) Load Balancers with Basic to Standard in-place.

To resolve this:

1. Recreate the cluster in the same VNet with Standard Load Balancer.
2. Deploy workloads and validate internal name resolution.

### My node pools are using Availability Sets. Will I still have issues even after Load Balancer migration?

Yes. If your node pools use Availability Sets, they're also deprecated in AKS after September 30, 2025.

To resolve this:

1. For clusters using both Availability Sets and the Basic Load Balancer, there's a separate `az aks update` command you must run to perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the [Availability Sets migration](./availability-sets-on-aks.md) guidance.
2. After the upgrade, Azure CLI or REST APIs must be used to perform CRUD operations or manage the pool. Check the [limitations](./virtual-machines-node-pools.md#limitations).

## Next steps

For more information on AKS networking, see [Networking concepts for Azure Kubernetes Service (AKS)](./concepts-network.md).

<!-- LINKS - internal -->

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#turn-off-kms
[load-balancer-upgrade-guidance]: /azure/load-balancer/load-balancer-basic-upgrade-guidance
[availability-sets]: availability-sets-on-aks.md
