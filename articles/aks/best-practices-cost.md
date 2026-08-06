---
title: Best Practices for Cost Optimization in Azure Kubernetes Service (AKS)
description: Learn best practices for cost optimization in AKS, including using AKS Automatic for built-in cost optimization, FinOps practices, autoscaling, and Azure discounts.
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 05/26/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.custom: biannual, aks-cost
# Customer intent: As a cloud architect, I want to implement cost optimization strategies in Azure Kubernetes Service, so that I can maximize resource efficiency and minimize unnecessary expenses while ensuring performance and reliability for my applications.
---

# Best practices for cost optimization in Azure Kubernetes Service (AKS)

Cost optimization is about maximizing the value of resources while minimizing unnecessary expenses within your cloud environment. This process involves identifying cost-effective configuration options and implementing best practices to improve operational efficiency. An AKS environment can be optimized to minimize cost while taking into account performance and reliability requirements.

In this article, you learn about:

> [!div class="checklist"]
>
> - Starting with AKS Automatic for built-in cost optimization.
> - Holistic monitoring and FinOps practices.
> - Strategic infrastructure selection.
> - Dynamic rightsizing and autoscaling.
> - Leveraging Azure discounts for substantial savings.

## Start with AKS Automatic for built-in cost optimization

[AKS Automatic](intro-aks-automatic.md) is a cluster mode that preconfigures many of the cost optimization practices described in this article. If you're creating a new cluster, consider AKS Automatic to reduce engineering effort, configuration risk, and the ongoing operational overhead that leads to unnecessary cloud spend.

AKS Automatic provides the following cost optimization capabilities by default, without any extra configuration:

| Capability | Cost benefit |
| ---------- | ------------ |
| [Node auto-provisioning (NAP)](node-auto-provisioning.md) | Automatically selects the most cost-efficient VM SKU for each workload based on actual pod resource requests. Eliminates manual node pool management and overprovisioning. |
| Workload autoscaling (VPA, HPA, and KEDA) | All workload autoscalers are enabled by default, so pods and nodes scale dynamically to actual demand rather than peak assumptions. |
| Efficient bin packing | Pods are scheduled to maximize node utilization, reducing the total number of nodes required to serve your workloads. |
| Managed Prometheus | Managed Prometheus is the default metrics platform. You avoid the higher cost of Container Insights metrics without any migration effort. |
| [Deployment safeguards](deployment-safeguards.md) | Azure Policy controls enforce resource requests and limits on all pods in enforcement mode, preventing uncontrolled resource consumption and overprovisioning at the cluster level. |

For workloads that require AKS Standard, the rest of this article describes each of these practices and how to configure them manually. Where AKS Automatic provides a practice by default, a note indicates that no extra steps are needed.

## Embrace FinOps to build a cost saving culture

[Financial operations (FinOps)](https://www.finops.org/introduction/what-is-finops/) is a discipline that combines financial accountability with cloud management and optimization. It focuses on driving alignment between finance, operations, and engineering teams to understand and control cloud costs. The FinOps foundation has several notable projects, such as the [**FinOps Framework**](https://finops.org/framework) and the [**FOCUS Specification**](https://focus.finops.org/).

For more information, see [What is FinOps?](/azure/cost-management-billing/finops/)

## Select cost-efficient infrastructure and cluster configuration

### Evaluate SKU family

> [!NOTE]
> If you use AKS Automatic, [node auto-provisioning (NAP)](node-auto-provisioning.md) automatically selects the most cost-efficient VM SKU for each workload based on its resource requests. You don't need to manually evaluate, create, or manage node pools.

It's important to evaluate the resource requirements of your application before deployment. Small development workloads have different infrastructure needs than large production-ready workloads. While a combination of CPU, memory, and networking capacity configurations heavily influences the cost effectiveness of a SKU, consider the following virtual machine (VM) types:

| SKU family | Description | Best for |
| ---------- | ----------- | -------- |
| [**Azure Spot Virtual Machines**](/azure/virtual-machines/spot-vms) | Azure Spot Virtual machine scale sets back [Spot node pools](./spot-node-pool.md) and are deployed to a single fault domain with no high availability or service-level agreement (SLA) guarantees. Spot VMs let you take advantage of unutilized Azure capacity with significant discounts (up to 90% compared to pay-as-you-go prices). If Azure needs capacity back, the Azure infrastructure evicts the Spot nodes. | Dev/test environments, workloads that can handle interruptions such as batch processing jobs, and workloads with flexible execution time. |
| [**Arm-based processors (Arm64)**][cobalt-arm64-vm] | Arm64 VMs are power-efficient and cost-effective without compromising on performance. With [Arm64 node pool support in AKS](./use-arm64-vms.md), you can create Arm64 Ubuntu agent nodes and mix Intel and Arm architecture nodes within a cluster. These VMs are engineered to efficiently run dynamic, scalable workloads and can deliver up to 50% better price-performance than comparable x86-based VMs for scale-out workloads. | Web or application servers, open-source databases, cloud-native applications, gaming servers, and more. |
| [**GPU optimized SKUs**](/azure/virtual-machines/sizes) | Depending on the nature of your workload, consider using compute-optimized, memory-optimized, storage-optimized, or GPU-optimized VM SKUs. GPU VM sizes are specialized VMs available with single, multiple, and fractional GPUs. | [GPU-enabled Linux node pools on AKS](./gpu-cluster.md) are best for compute-intensive workloads like graphics rendering, large model training, and inferencing. |

> [!NOTE]
> The cost of compute varies across regions. When picking a less expensive region to run workloads, be conscious of the potential impact of latency as well as data transfer costs. To learn more about VM SKUs and their characteristics, see [Sizes for virtual machines in Azure](/azure/virtual-machines/sizes).

### Review storage options

For more information on storage options and related cost considerations, see the following articles:

- [Best practices for storage and backups in Azure Kubernetes Service (AKS)](./operator-best-practices-storage.md)
- [Storage options for applications in Azure Kubernetes Service (AKS)](./concepts-storage.md)

### Use cluster preset configurations

It can be difficult to pick the right VM SKU, regions, number of nodes, and other configuration options. [Cluster preset configurations](quotas-skus-regions.md#cluster-configuration-presets-in-the-azure-portal) in the Azure portal offload this initial challenge by providing recommended configurations for different application environments that are cost-conscious and performant. The Dev/Test preset is best for developing new workloads or testing existing workloads. The Production Economy preset is best for serving production traffic in a cost-conscious way if your workloads can tolerate interruptions. Noncritical features are off by default, and you can modify the preset values at any time.

For a more comprehensive approach that goes beyond static presets, consider [AKS Automatic](intro-aks-automatic.md). AKS Automatic fully manages node pools using [node auto-provisioning (NAP)](node-auto-provisioning.md), which continuously right-sizes infrastructure to your actual workload demands. It also enables all workload autoscalers by default and enforces resource governance through deployment safeguards, which are extra benefits that cluster presets don't provide.

### Consider multitenancy

AKS offers flexibility in how you run multitenant clusters and isolate resources. For friendly multitenancy, you can share clusters and infrastructure across teams and business units through [_logical isolation_](./operator-best-practices-cluster-isolation.md#logically-isolated-clusters). Kubernetes [Namespaces](./concepts-clusters-workloads.md#namespaces) form the logical isolation boundary for workloads and resources. Sharing infrastructure reduces cluster management overhead while also improving resource utilization and pod density within the cluster. To learn more about multitenancy on AKS and to determine if it's right for your organizational needs, see [AKS considerations for multitenancy](/azure/architecture/guide/multitenant/service/aks) and [Design clusters for multitenancy](./operator-best-practices-cluster-isolation.md#design-clusters-for-multi-tenancy).

> [!WARNING]
> Kubernetes environments aren't entirely safe for hostile multitenancy. If any tenant on the shared infrastructure can't be trusted, more planning is needed to prevent tenants from impacting the security of other services.
>
> Consider [_physical isolation_](./operator-best-practices-cluster-isolation.md#physically-isolated-clusters) boundaries. In this model, teams or workloads are assigned to their own cluster. Added management and financial overhead is a tradeoff.

## Reduce resource waste through application and cluster configuration

### Make your container as lean as possible

A lean container refers to optimizing the size and resource footprint of the containerized application. Check that your base image is minimal and only contains the necessary dependencies. Remove any unnecessary libraries and packages. A smaller container image accelerates deployment times and increases the efficiency of scaling operations. [Artifact Streaming on AKS](./artifact-streaming.md) lets you stream container images from Azure Container Registry (ACR). It pulls only the necessary layer for initial pod startup, reducing the pull time for larger images from minutes to seconds.

### Enforce resource quotas

> [!NOTE]
> [AKS Automatic](intro-aks-automatic.md) clusters enforce resource requests and limits on all pods automatically through [deployment safeguards](deployment-safeguards.md), which are enabled in enforcement mode by default. This prevents uncontrolled resource consumption and overprovisioning without requiring manual policy configuration. For AKS Standard clusters, configure resource quotas at the namespace level as described in this section.

[Resource quotas](./operator-best-practices-scheduler.md#enforce-resource-quotas) provide a way to reserve and limit resources across a development team or project. Quotas are defined on a namespace and can be set on compute resources, storage resources, and object counts. When you define resource quotas, individual namespaces are prevented from consuming more resources than allocated. Resource quotas are useful for multitenant clusters where teams are sharing infrastructure.

### Use cluster start/stop

When left unattended, small development and test clusters can accrue unnecessary costs. You can turn off clusters that don't need to run at all times using the [cluster start and stop](./start-stop-cluster.md?tabs=azure-cli) feature. This feature shuts down all system and user node pools so you don't pay for extra compute. The state of your cluster and objects is maintained when you start the cluster again.

### Use capacity reservations

Capacity reservations let you reserve compute capacity in an Azure region or availability zone for any duration of time. Reserved capacity is available for immediate use until the reservation is deleted. [Associating an existing capacity reservation group to a node pool](./manage-node-pools.md#associate-capacity-reservation-groups-to-node-pools) guarantees allocated capacity for your node pool and helps you avoid potential on-demand pricing spikes during periods of high compute demand.

## Monitor your environment and spend

### Increase visibility with Microsoft Cost Management

[Microsoft Cost Management](/azure/cost-management-billing/cost-management-billing-overview) offers a broad set of capabilities to help with cloud budgeting, forecasting, and visibility for costs both inside and outside of the cluster. Proper visibility is essential for deciphering spending trends, identifying optimization opportunities, and increasing accountability among application developers and platform teams. Enable the [AKS Cost Analysis add-on](./cost-analysis.md) for granular cluster cost breakdown by Kubernetes constructs along with Azure Compute, Network, and Storage categories.

### Azure Monitor

> [!NOTE]
> [AKS Automatic](intro-aks-automatic.md) clusters use managed Prometheus as the default metrics platform. Container Insights metrics aren't enabled by default. If you use AKS Automatic, this cost optimization is already in place and no migration steps are needed.

If you're ingesting metric data via Container insights, we recommend migrating to managed Prometheus, which offers a significant cost reduction. You can [disable Container insights metrics using the data collection rule (DCR)](/azure/azure-monitor/containers/container-insights-data-collection-dcr?tabs=portal) and deploy the [managed Prometheus add-on](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana), which supports configuration via Azure Resource Manager, Azure CLI, Azure portal, and Terraform.

For more information, see [Azure Monitor best practices](/azure/azure-monitor/best-practices-containers#cost-optimization) and [managing costs for Container insights](/azure/azure-monitor/containers/container-insights-cost).

### Log Analytics

For control plane logs, consider disabling the categories you don't need and/or using the Basic Logs API when applicable to reduce Log Analytics costs. For more information, see [Azure Kubernetes Service (AKS) control plane/resource logs](./monitor-aks.md#aks-control-plane-resource-logs). For data plane logs, or application logs, consider adjusting the [cost optimization settings](./monitor-aks.md#aks-data-plane-container-insights-logs).

You can also use [Transformations in Azure Monitor](/azure/azure-monitor/data-collection/data-collection-transformations) to filter or modify control plane and data plane logs before they are sent to a Log Analytics workspace. For more information on how to create a transformation see [Create a transformation in Azure Monitor](/azure/azure-monitor/data-collection/data-collection-transformations-create?tabs=portal).

### Azure Advisor cost recommendations

AKS cost recommendations in Azure Advisor provide recommendations to help you achieve cost-efficiency without sacrificing reliability. Advisor analyzes your resource configurations and recommends optimization solutions. For more information, see [Get Azure Kubernetes Service (AKS) cost recommendations in Azure Advisor](./cost-advisors.md).

## Optimize workloads through autoscaling

### Establish a baseline

Before configuring your autoscaling settings, you can use [Azure Load Testing](/azure/load-testing/overview-what-is-azure-load-testing) to establish a baseline for your application. Load testing helps you understand how your application behaves under different traffic conditions and identify performance bottlenecks. Once you have a baseline, you can configure autoscaling settings to ensure your application can handle the expected load.

### Enable application autoscaling

#### Vertical pod autoscaling

> [!NOTE]
> [AKS Automatic](intro-aks-automatic.md) clusters have VPA enabled by default. If you use AKS Standard, see [Use the Vertical Pod Autoscaler in Azure Kubernetes Service (AKS)](./vertical-pod-autoscaler.md) to enable and configure VPA.

Requests and limits that are higher than actual usage can result in overprovisioned workloads and wasted resources. In contrast, requests and limits that are too low can result in throttling and workload issues due to lack of memory. The [Vertical Pod Autoscaler (VPA)](./vertical-pod-autoscaler.md) allows you to fine-tune CPU and memory resources required by your pods. VPA provides recommended values for CPU and memory requests and limits based on historical container usage, which you can set manually or update automatically. **Best for applications with fluctuating resource demands**. VPA’s recommendation-only _off mode_ allows teams to review resource suggestions without enforcing them automatically. This mode can be enabled during testing, and VPA recommendations can be used to set the CPU and memory request and limits for production environments.

#### Horizontal pod autoscaling

> [!NOTE]
> [AKS Automatic](intro-aks-automatic.md) clusters have HPA enabled by default. If you use AKS Standard, configure HPA on your workloads as described in [Horizontal pod autoscaling](./concepts-scale.md#horizontal-pod-autoscaler).

The [Horizontal Pod Autoscaler (HPA)](./concepts-scale.md#horizontal-pod-autoscaler) dynamically scales the number of pod replicas based on observed metrics, such as CPU or memory utilization. During periods of high demand, HPA scales out, adding more pod replicas to distribute the workload. During periods of low demand, HPA scales in, reducing the number of replicas to conserve resources. **Best for applications with predictable resource demands**.

> [!WARNING]
> You shouldn't use the VPA with the HPA on the same CPU or memory metrics. This combination can lead to conflicts, as both autoscalers attempt to respond to changes in demand using the same metrics. However, you can use the VPA for CPU or memory with the HPA for custom metrics to prevent overlap and ensure that each autoscaler focuses on distinct aspects of workload scaling.

#### Kubernetes event-driven autoscaling

> [!NOTE]
> [AKS Automatic](intro-aks-automatic.md) clusters have KEDA enabled by default. If you use AKS Standard, see [Install the KEDA add-on using Azure CLI](./keda-deploy-add-on-cli.md) to enable KEDA.

The [Kubernetes Event-driven Autoscaler (KEDA) add-on](./keda-about.md) provides extra flexibility to scale based on various event-driven metrics that align with your application behavior. For example, for a web application, KEDA can monitor incoming HTTP request traffic and adjust the number of pod replicas to ensure the application remains responsive. For processing jobs, KEDA can scale the application based on message queue length. Managed support is provided for all [Azure Scalers](https://keda.sh/docs/2.13/scalers/). KEDA also allows you to scale down to 0 replicas, especially helpful for sporadic event-driven workloads, periodic machine learning (ML) or GPU workloads, and dev/test or low traffic environments.

### Enable infrastructure autoscaling

#### Cluster autoscaling

> [!NOTE]
> In [AKS Automatic](intro-aks-automatic.md), node scaling is handled by node auto-provisioning (NAP), which is preconfigured by default. For AKS Standard without NAP, configure the Cluster Autoscaler as described in this section.

To keep up with application demand, the [Cluster Autoscaler](./cluster-autoscaler-overview.md) watches for pods that can't be scheduled due to resource constraints and scales the number of nodes in the node pool accordingly. When nodes don't have running pods, the Cluster Autoscaler scales down the number of nodes. The Cluster Autoscaler profile settings apply to all autoscaler-enabled node pools in a cluster. For more information, see [Cluster Autoscaler best practices and considerations](./cluster-autoscaler-overview.md#best-practices-and-considerations).

#### Node auto-provisioning

> [!NOTE]
> In [AKS Automatic](intro-aks-automatic.md), node auto-provisioning (NAP) is preconfigured by default. AKS selects the optimal VM SKU for each workload automatically, with no manual node pool creation or SKU selection required. For AKS Standard clusters, follow the steps in [Enable or disable NAP in AKS](./use-node-auto-provisioning.md) to enable NAP.

Complicated workloads might require several node pools with different VM size configurations to accommodate CPU and memory requirements. Accurately selecting and managing several node pool configurations adds complexity and operational overhead. [Node auto-provisioning (NAP)](./node-autoprovision.md?tabs=azure-cli) simplifies the SKU selection process and decides the optimal VM configuration based on pending pod resource requirements to run workloads in the most efficient and cost effective manner.

> [!NOTE]
> For more information on scaling best practices, see [Performance and scaling for small to medium workloads in Azure Kubernetes Service (AKS)](./best-practices-performance-scale.md) and [Performance and scaling best practices for large workloads in Azure Kubernetes Service (AKS)](./best-practices-performance-scale-large.md).

## Save with Azure discounts

### Azure Reservations

If your workload is predictable and exists for an extended period of time, consider purchasing an [Azure Reservation](/azure/cost-management-billing/reservations/save-compute-costs-reservations) to further reduce your resource costs. Azure Reservations operate on a one-year or three-year term, offering up to 72% discount as compared to pay-as-you-go prices for compute. Reservations automatically apply to matching resources. **Best for workloads that are committed to running in the same SKUs and regions over an extended period of time**.

### Azure Savings Plan

If you have consistent spend, but your use of disparate resources across SKUs and regions makes Azure Reservations infeasible, consider purchasing an [Azure Savings Plan](/azure/cost-management-billing/savings-plan/savings-plan-overview). Like Azure Reservations, Azure Savings Plans operate on a one-year or three-year term and automatically apply to any resources within benefit scope. You commit to spend a fixed hourly amount on compute resources irrespective of SKU or region. **Best for workloads that utilize different resources and/or different data center regions**.

### Azure Hybrid Benefit

[Azure Hybrid Benefit for Azure Kubernetes Service (AKS)](./azure-hybrid-benefit.md) allows you to maximize your on-premises licenses at no extra cost. Use any qualifying on-premises licenses that also have an active Software Assurance (SA) or a qualifying subscription to get Windows VMs on Azure at a reduced cost.

## Next steps

Cost optimization is an ongoing and iterative effort. Learn more by reviewing the following recommendations and architecture guidance:

- [What is AKS Automatic?](./intro-aks-automatic.md) - Get cost optimization built in by default with a fully managed cluster experience.
- [Microsoft Azure Well-Architected Framework for AKS: Cost optimization design principles](/azure/architecture/framework/services/compute/azure-kubernetes-service/azure-kubernetes-service#cost-optimization)
- [Baseline architecture guide for AKS](/azure/architecture/reference-architectures/containers/aks/baseline-aks)
- [Optimize compute costs on AKS](/training/modules/aks-optimize-compute-costs/)
- [AKS cost optimization techniques](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/azure-kubernetes-service-aks-cost-optimization-techniques/ba-p/3652908)

<!-- LINKS - Internal -->
[cobalt-arm64-vm]: /azure/virtual-machines/sizes/cobalt-overview
