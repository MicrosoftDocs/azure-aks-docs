---
title: Limits for resources, SKUs, and regions in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn about the default quotas, restricted node VM SKU sizes, and region availability of the Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.date: 01/12/2024
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: "As a cloud architect, I want to understand the quotas, VM size restrictions, and regional availability for Azure Kubernetes Service (AKS), so that I can effectively plan and manage resources for my Kubernetes deployments."
---

# Quotas, virtual machine size restrictions, and region availability in Azure Kubernetes Service (AKS)

All Azure services set default limits and quotas for resources and features, including usage restrictions for certain virtual machine (VM) SKUs.

This article details the default resource limits for Azure Kubernetes Service (AKS) resources and the availability of AKS in Azure regions.

## Service quotas and limits

[!INCLUDE [container-service-limits](~/reusable-content/ce-skilling/azure/includes/container-service-limits.md)]

### Throttling limits on AKS resource provider APIs

AKS uses the [token bucket](https://en.wikipedia.org/wiki/Token_bucket) throttling algorithm to limit certain AKS [resource provider](/azure/azure-resource-manager/management/resource-providers-and-types) APIs. This ensures the performance of the service and promotes fair usage of the service for all customers.

The buckets have a fixed size (also known as a burst rate) and refill over time at a fixed rate (also konwn as a sustained rate). Each throttling limit is in effect at the regional level for the specified resource in that region. For example, in the below table, a Subscription can call ListManagedClusters a maximum of 60 times (burst rate) at once for each ResourceGroup, but can continue to make 1 call every second thereafter (sustained rate).

| API request | Bucket size | Refill rate | Scope |
|---|---|---|---|
| LIST ManagedClusters | 500 requests | 1 requests / 1 second | Subscription |
| LIST ManagedClusters | 60 requests | 1 request / 1 second | ResourceGroup |
| PUT AgentPool | 20 requests | 1 request / 1 minute | AgentPool |
| PUT ManagedCluster | 20 requests | 1 request / 1 minute | ManagedCluster |
| GET ManagedCluster | 60 requests | 1 request / 1 second | Managed Cluster |
| GET Operation Status | 200 requests | 2 requests / 1 second | Subscription |
| All Other APIs | 60 requests | 1 request / 1 second | Subscription |

> [!NOTE]
> The ManagedClusters and AgentPools buckets are counted separately for the same AKS cluster.

If a request is throttled, the request will return HTTP response code `429` (Too Many Requests) and the error code will show as `Throttled` in the response. Each throttled request includes a `Retry-After` in the HTTP response header with the interval to wait before retrying, in seconds. Clients that use a bursty API call pattern should ensure that the Retry-After can be handled appropriately. To learn more about Retry-After, please see the [following article](https://developer.mozilla.org/docs/Web/HTTP/Headers/Retry-After). Specifically, AKS will use ```delay-seconds``` to specify the retry.

## Provisioned infrastructure

All other network, compute, and storage limitations apply to the provisioned infrastructure. For the relevant limits, see [Azure subscription and service limits](/azure/azure-resource-manager/management/azure-subscription-service-limits).

> [!IMPORTANT]
> When you upgrade an AKS cluster, extra resources are temporarily consumed. These resources include available IP addresses in a virtual network subnet or virtual machine vCPU quota.
>
> For Windows Server containers, you can perform an upgrade operation to apply the latest node updates. If you don't have the available IP address space or vCPU quota to handle these temporary resources, the cluster upgrade process will fail. For more information on the Windows Server node upgrade process, see [Upgrade a node pool in AKS][nodepool-upgrade].

## Supported VM sizes

The list of supported VM sizes in AKS is evolving with the release of new VM SKUs in Azure. Please follow the [AKS release notes](https://github.com/Azure/AKS/releases) to stay informed of new supported SKUs.

## Restricted VM sizes

Each node in an AKS cluster contains a fixed amount of compute resources such as vCPU and memory. Due to the required compute resources needed to run Kubernetes correctly, certain VM SKU sizes are restricted by default in AKS. These restrictions are to ensure that pods can be scheduled and function correctly on these nodes.

### User nodepools
For user nodepools, VM sizes with fewer than two vCPUs and two GBs of RAM (memory) may not be used.

### System nodepools
For system nodepools, VM sizes with fewer than two vCPUs and four GBs of RAM (memory) may not be used. To ensure that the required *kube-system* pods and your applications can reliably be scheduled, it is recommonded to **not use any [B series VMs][b-series-vm] and [Av1 series VMs][a-series-vm]**.

For more information on VM types and their compute resources, see [Sizes for virtual machines in Azure][vm-skus].

## Supported container image sizes

AKS doesn't set a limit on the container image size. However, it's important to understand that the larger the container image, the higher the memory demand. This could potentially exceed resource limits or the overall available memory of worker nodes. By default, memory for VM size Standard_DS2_v2 for an AKS cluster is set to 7 GiB.

When a container image is very large (1 TiB or more), kubelet might not be able to pull it from your container registry to a node due to lack of disk space.

## Region availability

For the latest list of where you can deploy and run clusters, see [AKS region availability][region-availability].

## Smart VM Defaults

As of May 2025, AKS will automatically select the optimal default VM SKU based on available capacity and quota if the parameter is unspecified during deployment. This ensures that deployments are matched with the best possible SKU, enhancing performance and reliability while optimizing resource utilization. Previously, the default AKS VM SKU was Standard_DS2_V2, but there are now dynamic outcomes in default provisioning based on SKU availability. This affects all new VM create operations.

## Cluster configuration presets in the Azure portal

When you create a cluster using the Azure portal, you can choose a preset configuration to quickly customize based on your scenario. You can modify any of the preset values at any time.

| Preset                      | Description                                                            |
|-----------------------------|------------------------------------------------------------------------|
| Production Standard         | Best for most applications serving production traffic with AKS recommended best practices. |
| Dev/Test                    | Best for developing new workloads or testing existing workloads. |
| Production Economy          | Best for serving production traffic in a cost conscious way if your workloads can tolerate interruptions. |
| Production Enterprise       | Best for serving production traffic with rigorous permissions and hardened security. |

|                              | Production Standard |Dev/Test|Production Economy|Production Enterprise|
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
|**Authentication and Authorization**|Local accounts with Kubernetes RBAC|Local accounts with Kubernetes RBAC|Microsoft Entra ID Authentication with Azure RBAC|Microsoft Entra ID authentication with Azure RBAC|


## Next steps

You can increase certain default limits and quotas. If your resource supports an increase, request the increase through an [Azure support request][azure-support] (for **Issue type**, select **Quota**).

<!-- LINKS - External -->
[azure-support]: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade/newsupportrequest
[region-availability]: https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service

<!-- LINKS - Internal -->
[vm-skus]: /azure/virtual-machines/sizes
[nodepool-upgrade]: use-multiple-node-pools.md#upgrade-a-node-pool
[b-series-vm]: /azure/virtual-machines/sizes-b-series-burstable
[a-series-vm]: /azure/virtual-machines/sizes/retirement/av1-series-retirement

