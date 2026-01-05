---
title: Capacity and cost planning for Azure Kubernetes Service (AKS) upgrades
description: Learn how to plan for capacity and costs when upgrading Azure Kubernetes Service (AKS) clusters, including surge node requirements, quota management, and IP address planning.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 12/09/2025
author: kaarthis
ms.author: schaffererin
# Customer intent: "As a cluster operator, I want to understand capacity and cost implications of AKS upgrades so that I can plan resources appropriately and avoid upgrade failures."
---

# Capacity and cost planning for Azure Kubernetes Service (AKS) upgrades

When planning an upgrade for your Azure Kubernetes Service (AKS) cluster, it's essential to consider the capacity and cost implications. Proper planning ensures successful upgrades while minimizing unexpected costs and resource constraints. This article outlines key considerations for capacity and cost planning during AKS upgrades, including surge node requirements, quota management, and IP address planning.

## AKS upgrade requirements

AKS upgrades require extra compute capacity for surge nodes, which are temporary nodes created during the upgrade process. The number of surge nodes needed depends on the size of your cluster and the upgrade strategy you choose. Understanding these requirements is crucial for effective capacity planning and helps you:

- Avoid upgrade failures due to capacity constraints.
- Plan for quota and subnet IP requirements.
- Optimize upgrade settings to balance cost and performance.
- Manage costs associated with temporary resources.

## Surge node capacity planning

During an upgrade, AKS creates surge nodes to maintain workload availability. The number of surge nodes depends on your `maxSurge` configuration, which defines how many extra nodes can be created during the upgrade. The following table outlines the surge node behavior based on different `maxSurge` settings:

| `maxSurge` setting | Surge nodes created | Capacity impact |
|--------------------|---------------------|-----------------|
| 1 (default) | _One_ extra node | • Minimal impact <br> • Suitable for small clusters |
| 33% | ~1/3 of node pool size | • Moderate impact <br> • Balances cost and performance <br> • Recommended for production clusters |
| 50% | ~1/2 of node pool size | • Higher impact <br> • Faster upgrades <br> • Increased cost due to more temporary nodes |

### Quota considerations for surge nodes

Before initiating an upgrade, ensure that your Azure subscription has sufficient quota to accommodate the surge nodes. Key quotas to monitor include:

- **Virtual machine (VM) cores**: Current nodes + surge nodes must not exceed your VM core quota.
- **Public IP addresses**: Each surge node might require a public IP address, depending on your network configuration.
- **Load balancer resources**: Ensure enough backend pool capacity for surge nodes.

#### Check your current quotas

You can check your current quotas using the [`az vm list-usage`](/cli/azure/vm#az-vm-list-usage) Azure CLI command:

```azurecli-interactive
az vm list-usage --location <your-region> --output table
```

### Calculate IP address requirements

Surge nodes require extra IP addresses in your subnet. To calculate the total IP address requirement during an upgrade, use the following formula:

```
Total IPs needed = (Current nodes + `maxSurge` nodes) × (1 + `maxPods` per node)
```

For AKS clusters using [Azure CNI](./concepts-network-azure-cni-overlay.md), ensure your subnet has capacity for all nodes, surge nodes, and their associated pods.

## Common capacity planning scenarios and solutions

The following scenarios illustrate common capacity planning challenges during AKS upgrades and their solutions:

### Scenario 1: Capacity constraints due to insufficient VM core quota

If your cluster is limited by VM SKU availability, regional capacity, or quota limits, upgrades might fail when surge nodes can't be provisioned. Common errors include:

- `SKUNotAvailable`
- `AllocationFailed`
- `OverconstrainedAllocationRequest`
- `QuotaExceeded`

Solutions include:

- **Use `maxUnavailable` instead of `maxSurge`**: Upgrade using existing node capacity without provisioning new nodes. You can update this setting using the [`az aks nodepool update`](/cli/azure/aks/nodepool#az-aks-nodepool-update) command. For example:

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --max-surge 0 \
      --max-unavailable 1
    ```

- **Lower `maxSurge` value**: Reduce extra capacity requirements by setting a lower `maxSurge` percentage. You can update this setting using the [`az aks nodepool update`](/cli/azure/aks/nodepool#az-aks-nodepool-update) command. For example:

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --max-surge 10%
    ```

- **Request quota increase**: For persistent capacity needs, request a [quota increase](/azure/azure-portal/supportability/regional-quota-requests).

### Scenario 2: IP exhaustion in subnet

When your subnet lacks sufficient IP addresses for surge nodes and pods, node provisioning fails with errors like `SubnetIsFull`. Solutions include:

- **Calculate IP needs**: Use the [IP calculation formula](#calculate-ip-address-requirements) to determine required subnet size.
- **Reclaim unused IPs**: Clean up unused resources in the subnet.
- **Expand subnet size**: Increase the subnet's address space to accommodate extra IPs. For example, from `/24` to `/22`.
- **Lower `maxSurge` value**: Reduce the number of surge nodes to decrease IP requirements.
- **Reduce `maxPods` per node**: Free up IP addresses by lowering the maximum number of pods per node. You can update this setting using the [`az aks nodepool update`](/cli/azure/aks/nodepool#az-aks-nodepool-update) command. For example:

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --max-pods 50
    ```

## Cost optimization strategies for AKS upgrades

The following sections outline strategies to optimize costs during AKS upgrades:

### Minimize surge costs

- **Use lower `maxSurge` values**: Reduces temporary node costs but might increase upgrade duration.
- **Schedule upgrades during off-peak hours**: Take advantage of lower compute costs during off-peak times. Faster upgrades mean fewer hours of surge node billing.
- **Use spot instances for non-production workloads**: If applicable, configure node pools with spot instances to reduce costs during upgrades.

### Balance upgrade speed and cost

The following table outlines priorities for different upgrade strategies, recommended settings, and trade-offs:

| Priority | Recommended settings | Trade-offs |
|----------|----------------------|------------|
| Minimize cost | `maxSurge=1`, longer upgrade window | Slower upgrades |
| Balance cost and speed | `maxSurge=33%`, [Planned Maintenance](./planned-maintenance.md) | Moderate costs and speed |
| Maximize speed | `maxSurge=50%` or higher | Higher temporary costs due to more surge nodes |

### Monitor upgrade costs

Track the cost associated with AKS upgrades using the following methods:

- **Tag surge resources**: AKS automatically tags surge nodes. Use these tags to filter and analyze costs in Azure Cost Management.
- **Use [Azure Cost Management](/azure/cost-management-billing/costs/overview-cost-management)**: Monitor and analyze costs related to AKS upgrades, focusing on surge node expenses.
- **Set up budgets and alerts**: Create budgets in Azure Cost Management to monitor upgrade-related expenses and receive alerts when approaching budget limits.

## Planning checklist for AKS upgrades

Before initiating an AKS upgrade, use the following checklist to ensure proper capacity and cost planning:

- [ ] **Quota**: Sufficient VM cores for current + surge nodes.
- [ ] **Subnet IPs**: Enough addresses for all nodes and pods.
- [ ] **SKU availability**: Target VM size available in region.
- [ ] **Budget**: Allocated for temporary surge resources.
- [ ] **Maintenance window**: Scheduled for optimal capacity availability.

## Related content

- [Upgrade options and recommendations](./upgrade-cluster.md)
- [Upgrade cluster control plane](./upgrade-aks-control-plane.md)
- [Configure node pool rolling upgrades](./upgrade-aks-node-pools-rolling.md)
