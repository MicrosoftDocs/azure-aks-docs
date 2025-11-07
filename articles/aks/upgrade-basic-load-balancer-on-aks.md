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
> Basic Load Balancer retires on September 30, 2025. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you're currently using Basic Load Balancer, make sure to upgrade to Standard Load Balancer before the retirement date to avoid your cluster being out of support. This article helps guide you through the upgrade process.

> [!NOTE]
> For clusters using both Availability Sets and the Basic Load Balancer, there's a separate `az aks update` command you need to run to perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the [Availability Sets migration][availability-sets] guidance.

## Before you begin

Before you begin the migration, review the following information:

- Downtime occurs during migration. Plan for downtime accordingly.
- Once the migration begins, roll back isn't allowed.
- This process also migrates your Basic IP to a Standard IP, while keeping the inbound IP addresses associated with the load balancer the same. New public IPs are created and associated to the Standard Load Balancer outbound rules to serve cluster egress traffic.

## Prerequisites

Your cluster must meet the following prerequisites before you can perform the migration:

- The minimum Kubernetes version for this script is 1.27. If you need to upgrade your AKS cluster, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md#upgrade-an-aks-cluster).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli). The minimum version you need is 2.76.0.
- If the cluster runs Key Management Service with private key vault, you need to disable Key Management Service before performing the migration. For more information, see [Turn off KMS][turn-off-kms].
- You need to disable any `ValidatingAdmissionWebhooks` or `MutatingAdmissionWebhooks` before performing the migration.

## Upgrade Basic Load Balancer to Standard Load Balancer

1. Upgrade your Basic Load Balancer to Standard Load Balancer using the [`az aks update`](/cli/azure/aks#az-aks-create) command with the `--load-balancer-sku` flag set to `Standard`.

    ```azurecli-interactive
    az aks update \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP \
      --load-balancer-sku=Standard
    ```

1. Verify the migration was successful using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

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

1. Get the resource ID for the outbound IP addresses using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id
    ```

1. Get the new IP address for each resource ID using the [`az network public-ip show`](/cli/azure/network/public-ip#az-network-public-ip-show) command.

    ```azurecli-interactive
    az network public-ip show --ids $IP_RESOURCE_ID --query ipAddress -o tsv
    ```

## FAQ

### Why am I getting `Error: “Load Balancer SKU 'basic' is invalid; must use 'standard'.` when creating a new AKS cluster or upgrading?

Microsoft deprecated Basic Load Balancer SKU for certain AKS operations, and creation is now blocked in some regions.

To resolve this issue, make sure you specify `--load-balancer-sku standard` when creating a new cluster. For example:

```azurecli-interactive
az aks create \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --load-balancer-sku standard
```

### Why can’t I change my Basic Load Balancer to Standard Load Balancer in-place?

The Load Balancer SKU is immutable after creation in AKS, as it's a managed resource owned by the cluster.

You can resolve this using one of the following options:

- **Option 1**: Use the `az aks update run` command to upgrade Basic Load Balancer to Standard. For more information, see [Upgrade Basic Load Balancer on Azure Kubernetes Service (AKS)](./upgrade-basic-load-balancer-on-aks.md).
- **Option 2**: Create a new AKS cluster with Standard Load Balancer (blue-green migration) and move any existing workloads.

### Why can't I find my public IP after upgrading from Basic to Standard Load Balancer?

The Load Balancer object lost the reference to your public IP resource during migration. This can occur if the IP was tied to the Basic SKU Load Balancer and wasn't rebound.

To resolve this issue:

1. Ensure the new Standard public IP exists in the correct resource group.
1. Reassociate it in the service manifest using the following configuration:

    ```yaml
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-ipv4: <your-ip>
    ```

### When migrating the load balancer on a private cluster without a public IP, why is a public IP still created during the migration?

If `outboundType` is `LoadBalancer`, AKS automatically provisions a public IP (PIP), regardless of Load Balancer SKU.

To resolve this issue:

1. Change `outboundType` to `userDefinedRouting` for a fully private cluster.
1. Ensure custom outbound routing is configured via Azure Firewall/NVA.

### Why does migration fail in my internal Load Balancer setup?

Current migration tooling doesn’t support internal virtual network (VNet) Load Balancers with Basic to Standard in-place.

To resolve this issue:

1. Recreate the cluster in the same VNet with Standard Load Balancer.
1. Deploy workloads and validate internal name resolution.

### My node pools are using Availability Sets. Will I still have issues even after Load Balancer migration?

Yes. If your node pools use Availability Sets, they're also deprecated in AKS after September 30, 2025.

To resolve this issue:

1. For clusters using both Availability Sets and the Basic Load Balancer, there's a separate `az aks update` command you must run to perform both migrations at once (Availability Sets to Virtual Machine node pools, and Basic Load Balancer to Standard Load Balancer). For steps on performing this migration, see the [Availability Sets migration](./availability-sets-on-aks.md) guidance.
1. After the upgrade, Azure CLI or REST APIs must be used to perform CRUD operations or manage the pool. Check the [limitations](./virtual-machines-node-pools.md#limitations).

### Do I need to delete default webhooks before upgrading?

No. If no other `ValidatingAdmissionWebhooks` or `MutatingAdmissionWebhooks` are present in the cluster, the default webhooks in the control plane should be fine to keep during the migration.

Default webhooks include:

- `aks-node-mutating-webhook`
- `webhook-admission-controller`
- `node-validating-webhook`

### What access is required to run the migration commands?

To run the migration commands, you need:

- Either the Contributor or Owner role on the subscription or resource group.
- The Azure CLI version must be ≥ 2.72.0.
- The AKS preview extension version must be ≥ 0.5.170.

### How can I see if Key Management Service (KMS) encryption is disabled?

You can check whether KMS encryption is enabled on your AKS cluster using the [`az aks list`](/cli/azure/aks#az-aks-list) command.

```azurecli-interactive
az aks list --query "[].{Name:name, KmsEnabled:securityProfile.azureKeyVaultKms.enabled, KeyId:securityProfile.azureKeyVaultKms.keyId}"
```

- If the output shows `"KmsEnabled": null`, it means KMS encryption isn't enabled for that cluster, and you can skip any steps to disable it. For example:

    ```output
      {
    
        "KeyId": null,
    
        "KmsEnabled": null,
    
        "Name": "myAKSCluster"
    
      },
    ...
    ```

- If KMS is enabled and you want to disable it, see [Turn off KMS encryption][turn-off-kms].

## Next steps

For more information on AKS networking, see [Networking concepts for Azure Kubernetes Service (AKS)](./concepts-network.md).

<!-- LINKS - internal -->

[turn-off-kms]: /azure/aks/use-kms-etcd-encryption#disable-kms-on-an-aks-cluster
[load-balancer-upgrade-guidance]: /azure/load-balancer/load-balancer-basic-upgrade-guidance
[availability-sets]: availability-sets-on-aks.md
