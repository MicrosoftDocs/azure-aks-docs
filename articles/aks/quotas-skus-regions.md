---
title: Limits for resources, SKUs, and regions in Azure Kubernetes Service (AKS)
description: Learn about default quotas, restricted node VM SKU sizes, and regional availability in Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.date: 08/03/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
# Customer intent: "As a cloud architect, I want to understand the quotas, VM size restrictions, and regional availability for Azure Kubernetes Service (AKS), so that I can effectively plan and manage resources for my Kubernetes deployments."
---

# Quotas, virtual machine size restrictions, and region availability in Azure Kubernetes Service (AKS)

Azure services set default limits and quotas for resources and features, including usage restrictions for certain virtual machine (VM) SKUs.

This article describes the default resource limits for Azure Kubernetes Service (AKS) and the availability of AKS in Azure regions.

## Service quotas and limits

[!INCLUDE [container-service-limits](~/reusable-content/ce-skilling/azure/includes/container-service-limits.md)]

> [!NOTE]
> In addition to the Free and Standard tiers listed in the preceding table, AKS offers a Premium tier for production workloads that require an uptime SLA and 24-month Long Term Support (LTS). For a complete comparison, see [AKS pricing tiers](free-standard-pricing-tiers.md).

> [!IMPORTANT]
> The Basic Load Balancer limit in the preceding table applies only to legacy configurations. Starting on September 30, 2025, AKS no longer supports Basic Load Balancer. Use Standard Load Balancer for new deployments and [upgrade existing deployments to Standard Load Balancer](upgrade-basic-load-balancer-on-aks.md).

[!INCLUDE [open service mesh retirement](./includes/open-service-mesh-retirement.md)]

### Quota limits on AKS managed clusters

Use the Azure portal Quotas page to [view quota limits and usage](/azure/quotas/view-quotas) and [request additional quota](/azure/quotas/quickstart-increase-quota-portal).

The following screenshot shows current usage and limits for AKS managed clusters by region and the controls for requesting quota adjustments.

:::image type="complex" source="./media/quotas-skus-regions/portal-quotas-page-inline.png" alt-text="Screenshot of the Azure portal Quotas page." lightbox="./media/quotas-skus-regions/portal-quotas-page-expanded.png":::
Screenshot of the Azure portal Quotas page. The page is filtered to a specific subscription and the Azure Kubernetes Service provider. It shows managed cluster usage and quota limits for each region in the subscription.
:::image-end:::

If you exceed your managed cluster quota, you might see an error message similar to the following:

```
ManagedClusterCountExceedsQuotaLimit: Operation results in exceeding quota limits for managed clusters. Maximum allowed: %d, Current usage: %d, Additional requested: %d. Consider deleting unused clusters or requesting a quota increase. To request a quota increase, follow the instructions here: https://learn.microsoft.com/azure/quotas/quickstart-increase-quota-portal.
```

To resolve this error, [request additional quota on the Azure portal Quotas page](/azure/quotas/view-quotas).

#### AKS managed clusters quota limits

[!INCLUDE [container-quota-limits](~/reusable-content/ce-skilling/azure/includes/container-quota-limits.md)]

### Throttling limits on AKS resource provider APIs

AKS uses the [token bucket](https://en.wikipedia.org/wiki/Token_bucket) throttling algorithm to limit certain AKS [resource provider](/azure/azure-resource-manager/management/resource-providers-and-types) APIs. Throttling helps maintain service performance and promotes fair usage.

The token buckets have a fixed size (also known as a burst rate) and refill over time at a fixed rate (also known as a sustained rate). Each throttling limit applies to the specified resource in each region. For example, a subscription can call `ListManagedClusters` up to 60 times at once for each resource group (burst rate) and then continue to make one call per second (sustained rate).

| API request | Bucket size | Refill rate | Scope |
|---|---|---|---|
| LIST `ManagedClusters` | 500 requests | 1 request per second | Subscription |
| LIST `ManagedClusters` | 60 requests | 1 request per second | Resource group |
| PUT `AgentPool` | 20 requests | 1 request per minute | Agent pool |
| PUT `ManagedCluster` | 20 requests | 1 request per minute | Managed cluster |
| GET `ManagedCluster` | 60 requests | 1 request per second | Managed cluster |
| GET operation status | 200 requests | 2 requests per second | Subscription |
| All other APIs | 60 requests | 1 request per second | Subscription |

> [!NOTE]
> The `ManagedClusters` and `AgentPools` buckets are counted separately for the same AKS cluster.

When AKS throttles a request, it returns HTTP status code `429` (Too Many Requests) and the `Throttled` error code. The response includes a `Retry-After` header that specifies the number of seconds to wait before retrying. If your client uses a bursty API call pattern, configure it to handle the `Retry-After` value. For more information, see the [`Retry-After` header](https://developer.mozilla.org/docs/Web/HTTP/Headers/Retry-After). AKS uses `delay-seconds` to specify the retry interval.

## Provisioned infrastructure

All other network, compute, and storage limitations apply to the provisioned infrastructure. For the relevant limits, see [Azure subscription and service limits](/azure/azure-resource-manager/management/azure-subscription-service-limits).

> [!IMPORTANT]
> When you upgrade an AKS cluster, the upgrade temporarily consumes extra resources. These resources include available IP addresses in a virtual network subnet or virtual machine vCPU quota.
>
> For Windows Server containers, upgrade the node pool to apply the latest node updates. If you don't have enough IP address space or vCPU quota for these temporary resources, the cluster upgrade fails. For more information, see [Upgrade a node pool in AKS][nodepool-upgrade].

## Supported VM sizes in AKS

Azure Kubernetes Service (AKS) support for VM sizes changes as Azure releases new VM versions. For updates about supported versions, see the [AKS release notes](https://github.com/Azure/AKS/releases).

## Restricted VM sizes in AKS

Each node in an AKS cluster contains a fixed amount of compute resources, such as vCPU and memory. Because Kubernetes requires specific compute resources to operate correctly, AKS restricts certain VM versions by default. These restrictions help ensure that pods can be scheduled and function correctly on the nodes.

### User node pools

For user node pools, you might not be able to use VM versions with fewer than two vCPUs and 2 GB of memory.

### System node pools

For system node pools, you might not be able to use VM versions with fewer than two vCPUs and 4 GB of memory. To help ensure reliable scheduling for the required _kube-system_ pods and your applications, AKS doesn't support [B series VMs][b-series-vm] for system node pools and doesn't recommend [Av1 series VMs][a-series-vm].

For more information on VM types and their compute resources, see [Sizes for virtual machines in Azure][vm-skus].

## Supported container image sizes in AKS

AKS doesn't set a service-level limit on container image size. Large images can increase pull latency and consume more node disk space, disk I/O, and network bandwidth. If a node doesn't have sufficient disk space, the kubelet might not be able to pull the image. For optimization guidance, see [Improve container image pull performance in AKS](/troubleshoot/azure/azure-kubernetes/availability-performance/container-image-pull-performance).

Runtime memory use depends on workload behavior rather than image artifact size. Set container memory requests and limits based on measured runtime requirements. For more information, see [Resource management for pods and containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).

## Region availability

AKS availability varies by Azure region. Even in supported regions, regional capacity, VM version availability, and subscription quota can affect deployment.

For the latest list of where you can deploy and run clusters, see [AKS region availability][region-availability].

## Smart VM defaults in AKS

Before May 2025, the default AKS VM SKU was `Standard_DS2_v2`. For deployments created since May 2025, if you don't specify a VM SKU, AKS dynamically selects a default based on available capacity and quota. This selection improves deployment reliability and resource utilization.

## Cluster configuration presets in the Azure portal

When you create a cluster in the Azure portal, select a preset to quickly configure the cluster for your scenario. You can modify the preset values during cluster creation. The settings that you can modify after deployment vary.

| Preset                      | Description                                                            |
|-----------------------------|------------------------------------------------------------------------|
| Production Standard         | Best for most applications serving production traffic with AKS-recommended best practices. |
| Dev/Test                    | Best for developing new workloads or testing existing workloads. |
| Production Economy          | Best for serving production traffic cost-effectively if your workloads can tolerate interruptions. |
| Production Enterprise       | Best for serving production traffic with rigorous permissions and hardened security. |

| Configuration setting        | Production Standard |Dev/Test|Production Economy|Production Enterprise|
|------------------------------|---------|--------|--------|--------|
|**System node pool node size**|Standard_D8ds_v5|Standard_D4ds_v5|Standard_D8ds_v5|Standard_D16ds_v5|
|**System node pool autoscaling range**|2-5 nodes|2-5 nodes|2-5 nodes|2-5 nodes|
|**User node pool node size**|Standard_D8ds_v5|-|Standard_D8as_v4|Standard_D8ds_v5|
|**User node pool autoscaling range**|2-100 nodes|-|0-25 nodes|2-100 nodes|
|**Private cluster**|-|-|-|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|
|**Availability zones**|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|-|-|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|
|**Azure Policy**|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|-|-|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|
|**Azure Monitor**|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|-|-|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|
|**Secrets store CSI driver**|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|-|-|:::image type="icon" source="./media/quotas-skus-regions/yes-icon.svg":::|
|**Network configuration**|Azure CNI Overlay|Azure CNI Overlay|Azure CNI Overlay|Azure CNI Overlay|
|**Network policy**|None|None|None|None|
|**Authentication and authorization**|Local accounts with Kubernetes role-based access control (RBAC)|Local accounts with Kubernetes RBAC|Microsoft Entra ID authentication with Azure role-based access control (Azure RBAC)|Microsoft Entra ID authentication with Azure RBAC|


## Next steps

For limits and quotas that support increases, submit an [Azure support request][azure-support] and select **Quota** for **Issue type**.

<!-- LINKS - External -->
[azure-support]: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade/newsupportrequest
[region-availability]: https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service

<!-- LINKS - Internal -->
[vm-skus]: /azure/virtual-machines/sizes
[nodepool-upgrade]: upgrade-node-pools.md#upgrade-a-single-node-pool
[b-series-vm]: /azure/virtual-machines/sizes-b-series-burstable
[a-series-vm]: /azure/virtual-machines/sizes/retirement/av1-series-retirement

