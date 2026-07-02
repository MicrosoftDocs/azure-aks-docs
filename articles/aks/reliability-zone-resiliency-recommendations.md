---
title: Zone Resiliency Recommendations for Azure Kubernetes Service (AKS)
description: Learn recommendations for designing and validating zone resiliency in Azure Kubernetes Service (AKS), including guidance for AKS Automatic and AKS Standard.
ms.topic: concept-article
ms.date: 06/05/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.custom: aks-reliability
# Customer intent: "As a cloud architect, I want to implement zone resiliency in my Kubernetes clusters, so that my applications remain available and performance is maintained during infrastructure failures."
---

# Zone resiliency recommendations for Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

Zone resiliency is a key part of running production-grade Kubernetes clusters. With scalability at its core, Kubernetes takes full advantage of independent infrastructure in data centers without incurring additional costs by provisioning new nodes only when necessary.

> [!IMPORTANT]
> Scaling a cluster in and out by adding or removing nodes isn't enough to ensure application resiliency. You need to understand your application and dependencies to plan for resiliency. AKS supports availability zones (AZs) for clusters and node pools so applications can continue serving traffic even if an entire zone goes down. For more information, see [Reliability in Azure Kubernetes Service (AKS)](/azure/reliability/reliability-aks).

In this article, you learn recommendations for zone resiliency in AKS, including how to:

- Make AKS cluster components zone resilient.
- Design stateless applications for zone failure scenarios.
- Choose storage redundancy options.
- Test application and platform behavior during zonal faults.

## AKS cluster modes and zone resiliency

AKS supports two cluster modes:

- **AKS Automatic**, which provides more preconfigured platform defaults.
- **AKS Standard**, which provides broader direct operator control.

Zone resiliency principles in this article apply to both cluster modes. The key difference is ownership of platform operations.

| Area | AKS Automatic | AKS Standard |
| ---- | ------------- | ------------ |
| Cluster operations | More preconfigured defaults for production readiness | More explicit operator configuration and lifecycle control |
| Node management and scaling | Managed system node pools and node autoprovisioning are preconfigured | Operators explicitly define and manage node pools and scaling strategy |
| Upgrades | Automatic cluster and node OS image upgrades are preconfigured | Operators choose manual upgrades or configured upgrade channels |
| Security baseline | Deployment safeguards and baseline Pod Security Standards are preconfigured in enforce mode | Security and policy controls are optional and explicitly configured |
| Monitoring baseline | Managed Prometheus and Container Insights are default in Azure CLI and Azure portal creation flows | Monitoring components are optional and explicitly enabled |
| Networking baseline | Managed virtual network defaults and managed ingress and egress patterns in supported configurations | Networking model and ingress and egress patterns are selected explicitly |

For full feature behavior by mode, see AKS Automatic and AKS Standard feature comparison.

## Make your AKS cluster components zone resilient

The following sections describe key decision points for zone resiliency in AKS. They aren't exhaustive. You should also validate zone resiliency for dependencies such as data stores, identity systems, and external services.

### Create zone redundant clusters and node pools

AKS lets you select multiple AZs during cluster and node pool creation. In regions that support multiple AZs, the control plane is automatically spread across zones. Node pool nodes are spread across the selected zones. This approach ensures that the control plane and the nodes are distributed across multiple AZs, providing resiliency in case of an AZ failure.

Cluster mode guidance:

- **AKS Automatic**: Many platform defaults are preconfigured. You should still validate that business-critical workloads are intentionally distributed across zones and that failure behavior meets requirements.
- **AKS Standard**: Design node pool topology, scaling settings, and failure-domain behavior explicitly.

The following example shows how to create a cluster with three nodes spread across three AZs using the Azure CLI:

```azurecli-interactive
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --generate-ssh-keys --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --node-count 3 --zones 1 2 3
```

Once the cluster is created, you can use the following command to retrieve the region and availability zone for each agent node from the labels:

```bash
kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
```

The following example output shows the region and availability zone for each agent node:

```output
Name:       aks-nodepool1-28993262-vmss000000
            topology.kubernetes.io/zone=eastus2-1
Name:       aks-nodepool1-28993262-vmss000001
            topology.kubernetes.io/zone=eastus2-2
Name:       aks-nodepool1-28993262-vmss000002
            topology.kubernetes.io/zone=eastus2-3
```

For more information, see [Use availability zones in Azure Kubernetes Service (AKS)](./availability-zones.md).

### Ensure pods are spread across AZs

Pod placement strategy is a workload-level concern in both AKS Automatic and AKS Standard. Platform defaults don't replace workload-level topology requirements.

Starting with Kubernetes version 1.33, the default Kube-Scheduler in AKS is configured to use a `MaxSkew` value of 1 for `topology.kubernetes.io/zone`:

```yml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: "topology.kubernetes.io/zone"
  whenUnsatisfiable: ScheduleAnyway
```

This configuration targets no more than a single pod difference between zones, reducing the chance that a zonal failure causes a deployment outage.

If your deployment has specific topology needs, override these defaults in your pod spec. You can use pod topology spread constraints based on the `zone` and `hostname` labels to spread pods across AZs within a region and across hosts within AZs.

For example, let's say you have a four-node cluster where three pods labeled `app: mypod-app` are located in `node1`, `node2`, and `node3` respectively. If you want the incoming deployment to be hosted on distinct nodes as much as possible, you can use a manifest similar to the following example:

```yml
apiVersion: v1
kind: Deployment
metadata:
  name: mypod-deployment
  labels:
    app: mypod-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mypod-app
  template:
    metadata:
      labels:
        app: mypod-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: "kubernetes.io/hostname"
        whenUnsatisfiable: ScheduleAnyway
      containers:
      - name: pause
        image: registry.k8s.io/pause
```

> [!NOTE]
> If your application has strict zone spread requirements, where the expected behavior would be to leave a pod in pending state if a suitable node isn't found, you can use `whenUnsatisfiable: DoNotSchedule`. This configuration tells the scheduler to leave the pod in pending if a node in the right zone or different host doesn't exist or can't be scaled up.

For more information on configuring pod distribution and understanding the implications of `MaxSkew`, see the [Kubernetes Pod Topology documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#topologyspreadconstraints-field). For example, how `nodeTaintsPolicy: Honor` affects pod distribution.

### Configure AZ-aware networking

If you have pods that serve network traffic, you should load balance traffic across multiple AZs to ensure that your application is highly available and resilient to failures. You can use [Azure Load Balancer](/azure/load-balancer/load-balancer-overview) to distribute incoming traffic across the nodes in your AKS cluster.

Azure Load Balancer supports both internal and external load balancing, and you can configure it to use a _Standard SKU_ for zone-redundant load balancing. The Standard SKU is the default SKU in AKS, and it supports regional resiliency with [availability zones](/azure/reliability/reliability-load-balancer#availability-zone-support) to ensure your application isn't impacted by a region failure. In the event of a zone failure scenario, a zone-redundant Standard SKU load balancer isn't impacted by the failure and enables your deployments to continue serving traffic from the remaining zones. You can use a global load balancer, such as [Front Door](/azure/frontdoor/front-door-overview) or [Traffic Manager](/azure/traffic-manager/traffic-manager-overview), or you can use [cross-region load balancers](/azure/reliability/reliability-load-balancer#cross-region-disaster-recovery-and-business-continuity) in front of your regional AKS clusters to ensure that your application isn't impacted by regional failures. To create a Standard SKU load balancer in AKS, see [Use a standard load balancer in Azure Kubernetes Service (AKS)](./load-balancer-standard.md).

To ensure that your application's network traffic is resilient to failures, you should configure AZ-aware networking for your AKS workloads. Azure offers various networking services that support AZs:

- [Azure VPN Gateway](/azure/vpn-gateway/vpn-gateway-about-vpngateways): You can deploy VPN and [ExpressRoute](/azure/expressroute/designing-for-high-availability-with-expressroute) gateways in Azure AZs to enable better resiliency, scalability, and availability to virtual network gateways. For more information, see [Create a zone-redundant virtual network gateways in availability zones](/azure/vpn-gateway/create-zone-redundant-vnet-gateway).
- [Azure Application Gateway v2](/azure/application-gateway/overview-v2): Azure Application Gateway provides a regional L7 load balancer with availability zone support. For more information, see [Direct web traffic with Azure Application Gateway](/azure/application-gateway/quick-create-cli).
- [Azure Front Door](/azure/frontdoor/front-door-overview): Azure Front Door provides a global L7 load balancer and leverages points of presence (POPs) or Azure Content Delivery Network (CDN). For more information, see [Azure Front Door POP locations](/azure/frontdoor/edge-locations-by-region).

> [!IMPORTANT]
> With [Azure NAT Gateway](/azure/nat-gateway/nat-overview), you can create NAT gateways in specific AZs or use a zonal deployment for isolation to specific zones. NAT Gateway supports zonal deployments but not zone-redundant deployments. This might be an issue if you configure an AKS cluster with the outbound type equal to the NAT gateway and the NAT gateway is in a single zone. In this case, if the zone hosting your NAT gateway goes down, your cluster loses outbound connectivity. For more information, see [NAT Gateway and availability zones](/azure/nat-gateway/nat-overview#availability-zones).

### Set up a zone-redundant, geo-replicated container registry

To ensure that your container images are highly available and resilient to failures, you should set up a zone-redundant container registry. The [Azure Container Registry (ACR)](/azure/container-registry/container-registry-intro) Premium SKU supports [geo-replication](/azure/container-registry/container-registry-geo-replication) and optional [zone redundancy](/azure/container-registry/zone-redundancy). These features provide availability and reduce latency for regional operations.

### Ensure availability and redundancy for keys and secrets

[Azure Key Vault](/azure/key-vault/general/overview) provides multiple layers of redundancy to make sure your keys and secrets remain available to your application even if individual components of the service fail, or if Azure regions or AZs are unavailable. For more information, see [Azure Key Vault availability and redundancy](/azure/key-vault/general/disaster-recovery-guidance).

### Use autoscaling features

You can improve application availability and resiliency in AKS using autoscaling features, which help you achieve the following goals:

- Optimize resource utilization and cost efficiency by scaling up or down based on the CPU and memory usage of your pods.
- Enhance fault tolerance and recovery by adding more nodes or pods when a zone failure occurs.

You can use the [Horizontal Pod Autoscaler (HPA)](./concepts-scale.md#horizontal-pod-autoscaler) and [Cluster Autoscaler](./cluster-autoscaler-overview.md) to implement autoscaling in AKS. The HPA automatically scales the number of pods in a deployment based on observed CPU utilization, memory utilization, custom metrics, and metrics of other services. The Cluster Autoscaler automatically adjusts the number of nodes in a node pool based on pending pods and the resource requests on the pending pods.

Cluster mode guidance:

- **AKS Automatic**: Focus on workload requests and limits, pod distribution policies, and disruption controls so preconfigured platform scaling can recover service during zonal stress.
- **AKS Standard**: Explicitly design node pool boundaries, scaling policy, and autoscaler settings to align with zone-aware scheduling constraints.

The AKS Karpenter Provider feature enables node autoprovisioning using [Karpenter](https://karpenter.sh/) on your AKS cluster. For more information, see the [AKS Karpenter Provider feature overview](https://github.com/Azure/karpenter-provider-azure?tab=readme-ov-file#features-overview).

The [Kubernetes Event-driven Autoscaling (KEDA)](https://keda.sh/) add-on for AKS applies event-driven autoscaling to scale your application based on metrics of external services to meet demand. For more information, see [Install the KEDA add-on in Azure Kubernetes Service (AKS)](./keda-deploy-add-on-cli.md).

### Zone scaling strategy by AKS cluster mode

For zone-aware scale-up behavior, align your node pool model with scheduler constraints and your cluster mode.

#### AKS Standard

When using Cluster Autoscaler with availability zones, a common best practice is one node pool per zone. You can set `--balance-similar-node-groups` to `True` to maintain balanced node distribution across zones during scale-up.

Why this matters:

- Cluster Autoscaler simulates scheduling by node pool, not by specific zone placement.
- In a multi-zone node pool, scale-up can place a new node in a zone that still violates strict topology spread constraints, leaving pods pending.
- Virtual Machine Scale Sets uses best-effort zone balancing. During zone capacity constraints or zone-down events, allocation can fail and place the node pool in backoff.
- Using one node pool per zone improves control of zone-specific scaling behavior.

**The Cluster Autoscaler isn't zone-aware, and zone allocation is handled by the underlying Virtual Machine Scale Sets and not by AKS**. This best practice becomes even more relevant when using zone-based **[pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)** on a single multi-zone node pool, as restrictive constraints may leave pods in a pending state, especially in capacity-constrained regions or during zone-down scenarios.

#### AKS Automatic

AKS Automatic uses preconfigured managed node behavior and node autoprovisioning defaults. You can't assume critical workloads are zone-resilient without workload-level policy.

For critical services, validate:

- Pod topology spread behavior across zones.
- Recovery behavior during zonal pressure.
- Scheduling outcomes when strict constraints are used.
- Application behavior when one zone becomes unavailable.

## Design a stateless application

When an application is _stateless_, the application logic and data are decoupled, and the pods don't store any persistent or session data on their local disks. This design allows the application to be easily scaled up or down without worrying about data loss. Stateless applications are more resilient to failures because they can be easily replaced or rescheduled on a different node in case of a node failure.

When designing a stateless application with AKS, you should use managed Azure services, such [Azure Databases](https://azure.microsoft.com/products/category/databases/), [Azure Managed Redis](/azure/redis/overview), or [Azure Storage](https://azure.microsoft.com/products/category/storage/) to store the application data. Using these services ensures your traffic can be moved across nodes and zones without risking data loss or impacting the user experience. You can use Kubernetes [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/), [Services](https://kubernetes.io/docs/concepts/services-networking/service/), and [Health Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) to manage stateless pods and ensure even distribution across zones.

## Make your storage disk decision

### Choose the right disk type based on application needs

Azure offers two types of disks for persistent storage: locally redundant storage (LRS) and zone redundant storage (ZRS). LRS replicates your data within a single AZ. ZRS replicates your data across multiple AZs within a region. Starting from AKS version 1.29, the default storage class uses ZRS disks for persistent storage. For more information, see [AKS built-in storage classes](./azure-csi-disk-storage-provision.md#built-in-storage-classes).

The way your application replicates data can influence your choice of disk. If your application is located in multiple zones and replicates the data from within the application, you can achieve resiliency with an LRS disk in each AZ because if one AZ goes down, the other AZs would have the latest data available to them. If your application layer doesn't handle such replication, ZRS disks are a better choice, as Azure handles the replication in the storage layer.

The following table outlines pros and cons of each disk type:

| Disk type | Pros | Cons |
| --------- | ---- | ---- |
| LRS | • Lower cost <br> • Supported for all disk sizes and regions <br> • Easy to use and provision | • Lower availability and durability <br> • Vulnerable to zonal failures <br> • Doesn't support zone or geo-replication |
| ZRS | • Higher availability and durability <br> • More resilient to zonal failures <br> • Supports zone replication for intra-region resiliency | • Higher cost <br> • Not supported for all disk sizes and regions <br> • Requires extra configuration to enable |

For more information on the LRS and ZRS disk types, see [Azure Storage redundancy](/azure/storage/common/storage-redundancy#redundancy-in-the-primary-region). To provision storage disks in AKS, see [Provision Azure Disks storage in Azure Kubernetes Service (AKS)](./azure-csi-files-storage-provision.md).

### Monitor disk performance

To ensure optimal performance and availability of your storage disks in AKS, you should monitor key metrics, such as IOPS, throughput, and latency. These metrics can help you identify any issues or bottlenecks that might impact your application's performance. If you notice any consistent performance issues, you might want to reconsider your storage disk type or size. You can use Azure Monitor to collect and visualize these metrics and set up alerts to notify you of any performance issues.

For more information, see [Monitor Azure Kubernetes Service (AKS) with Azure Monitor](./monitor-aks.md).

## Test for AZ resiliency

### Method 1: Cordon and drain nodes in a single AZ

One way to test your AKS cluster for AZ resiliency is to drain a node in one zone and see how it affects traffic until it fails over to another zone. This method simulates a real-world scenario where an entire zone is unavailable due to a disaster or outage. To test this scenario, you can use the `kubectl drain` command to gracefully evict all pods from a node and mark it as unschedulable. You can then monitor cluster traffic and performance using tools such as Azure Monitor or Prometheus.

The following table outlines pros and cons of this method:

| Pros | Cons |
| ---- | ---- |
| • Mimics a realistic failure scenario and tests the recovery process <br> • Allows you to verify the availability and durability of your data across regions <br> • Helps you identify any potential issues or bottlenecks in your cluster configuration or application design | • Might cause temporary disruption or degradation of service for your users <br> • Requires manual intervention and coordination to drain and restore the node <br> • Might incur extra costs due to increased network traffic or storage replication |

### Method 2: Simulate an AZ failure using Azure Chaos Studio

Another way to test your AKS cluster for AZ resiliency is to inject faults into your cluster and observe the impact on your application using Azure Chaos Studio. Azure Chaos Studio is a service that allows you to create and manage chaos experiments on Azure resources and services. You can use Chaos Studio to simulate an AZ failure by creating a fault injection experiment that targets a specific zone and stops or restarts the virtual machines (VMs) in that zone. You can then measure the availability, latency, and error rate of your application using metrics and logs.

The following table outlines pros and cons of this method:

| Pros | Cons |
| ---- | ---- |
| • Provides a controlled and automated way to inject faults and monitor the results <br> • Supports various types of faults and scenarios, such as network latency, CPU stress, disk failure, etc. <br> • Integrates with Azure Monitor and other tools to collect and analyze data | • Might require extra configuration and setup to create and run experiments <br> • Might not cover all possible failure modes and edge zones that could occur during a real outage <br> • Might have limitations or restrictions on the scope and/or duration of the experiments |

For more information, see [What is Azure Chaos Studio?](/azure/chaos-studio/chaos-studio-overview).

## Related content

- [What is AKS Automatic?](./intro-aks-automatic.md)
- [Guide to zone redundant AKS clusters and storage](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/a-practical-guide-to-zone-redundant-aks-clusters-and-storage/ba-p/4036254)
