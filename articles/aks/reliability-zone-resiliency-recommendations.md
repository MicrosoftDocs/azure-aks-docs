---
title: Zone resiliency recommendations for Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn about the various recommendations for zone resiliency in Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.date: 06/05/2024
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: "As a cloud architect, I want to implement zone resiliency in my Kubernetes clusters, so that my applications remain available and performance is maintained during infrastructure failures."
---

# Zone resiliency recommendations for Azure Kubernetes Service (AKS)

Zone resiliency is a key part of running production-grade Kubernetes clusters. With scalability at its core, Kubernetes takes full advantage of independent infrastructure in data centers without incurring additional costs by provisioning new nodes only when necessary.

>[!IMPORTANT]
> Scaling a cluster in and out, by adding or removing nodes, isn't enough to ensure application resiliency. You must gain a deeper understanding of your application and its dependencies to better plan for resiliency. AKS allows you to set up availability zones (AZs) for your clusters and node pools to ensure that your applications are resilient to failures and can continue to serve traffic even if an entire zone goes down. For more information on availability zone support features in AKS, see [Reliability in Azure Kubernetes Service (AKS)](/azure/reliability/reliability-aks).


In this article, you learn about the various recommendations for zone resiliency in Azure Kubernetes Service (AKS), including how to:

* Make your AKS cluster components zone resilient
* Design a stateless application
* Make your storage disk decision
* Test for availability zone (AZ) resiliency

## Make your AKS cluster components zone resilient

The following sections provide guidance on major decision points for making your AKS cluster components zone resilient, but they aren't exhaustive. You should consider other factors based on your specific requirements and constraints and check your other dependencies to ensure they're configured for zone resiliency.

### Create zone redundant clusters and node pools

AKS allows you to select multiple AZs during cluster and node pool creation. When you create a cluster in a region that has multiple AZs, the control plane is automatically spread across all the AZs in that region. However, the nodes in the node pool are spread across only the selected AZs. This approach ensures that the control plane and the nodes are distributed across multiple AZs, providing resiliency in case of an AZ failure. You can configure AZs by using the Azure portal, Azure CLI, or Azure Resource Manager templates.

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

Starting with Kubernetes version 1.33, the default Kube-Scheduler in AKS is configured to use a `MaxSkew` value of 1 for `topology.kubernetes.io/zone` as outlined below:
```yml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: "topology.kubernetes.io/zone"
  whenUnsatisfiable: ScheduleAnyway
```
This configuration deviates from the upstream default by targeting no more than a single pod difference between zones. As a result, pods are more evenly distributed across zones, reducing the likelihood that a zonal failure results in an outage of the corresponding deployment.

However, if your deployment has specific topology needs, you can override the above default values by adding your own in the pod spec. You can use pod topology spread constraints based on the `zone` and `hostname` labels to spread pods across AZs within a region and across hosts within AZs.

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

Azure Load Balancer supports both internal and external load balancing, and you can configure it to use a *Standard SKU* for zone-redundant load balancing. The Standard SKU is the default SKU in AKS, and it supports regional resiliency with [availability zones](/azure/reliability/reliability-load-balancer#availability-zone-support) to ensure your application isn't impacted by a region failure. In the event of a zone failure scenario, a zone-redundant Standard SKU load balancer isn't impacted by the failure and enables your deployments to continue serving traffic from the remaining zones. You can use a global load balancer, such as [Front Door](/azure/frontdoor/front-door-overview) or [Traffic Manager](/azure/traffic-manager/traffic-manager-overview), or you can use [cross-region load balancers](/azure/reliability/reliability-load-balancer#cross-region-disaster-recovery-and-business-continuity) in front of your regional AKS clusters to ensure that your application isn't impacted by regional failures. To create a Standard SKU load balancer in AKS, see [Use a standard load balancer in Azure Kubernetes Service (AKS)](./load-balancer-standard.md).

To ensure that your application's network traffic is resilient to failures, you should configure AZ-aware networking for your AKS workloads. Azure offers various networking services that support AZs:

* [Azure VPN Gateway](/azure/vpn-gateway/vpn-gateway-about-vpngateways): You can deploy VPN and [ExpressRoute](/azure/expressroute/designing-for-high-availability-with-expressroute) gateways in Azure AZs to enable better resiliency, scalability, and availability to virtual network gateways. For more information, see [Create a zone-redundant virtual network gateways in availability zones](/azure/vpn-gateway/create-zone-redundant-vnet-gateway).
* [Azure Application Gateway v2](/azure/application-gateway/overview-v2): Azure Application Gateway provides a regional L7 load balancer with availability zone support. For more information, see [Direct web traffic with Azure Application Gateway](/azure/application-gateway/quick-create-cli).
* [Azure Front Door](/azure/frontdoor/front-door-overview): Azure Front Door provides a global L7 load balancer and leverages points of presence (POPs) or Azure Content Delivery Network (CDN). For more information, see [Azure Front Door POP locations](/azure/frontdoor/edge-locations-by-region).

> [!IMPORTANT]
> With [Azure NAT Gateway](/azure/nat-gateway/nat-overview), you can create NAT gateways in specific AZs or use a zonal deployment for isolation to specific zones. NAT Gateway supports zonal deployments but not zone-redundant deployments. This might be an issue if you configure an AKS cluster with the outbound type equal to the NAT gateway and the NAT gateway is in a single zone. In this case, if the zone hosting your NAT gateway goes down, your cluster loses outbound connectivity. For more information, see [NAT Gateway and availability zones](/azure/nat-gateway/nat-overview#availability-zones).

### Set up a zone-redundant, geo-replicated container registry

To ensure that your container images are highly available and resilient to failures, you should set up a zone-redundant container registry. The [Azure Container Registry (ACR)](/azure/container-registry/container-registry-intro) Premium SKU supports [geo-replication](/azure/container-registry/container-registry-geo-replication) and optional [zone redundancy](/azure/container-registry/zone-redundancy). These features provide availability and reduce latency for regional operations.

### Ensure availability and redundancy for keys and secrets

[Azure Key Vault](/azure/key-vault/general/overview) provides multiple layers of redundancy to make sure your keys and secrets remain available to your application even if individual components of the service fail, or if Azure regions or AZs are unavailable. For more information, see [Azure Key Vault availability and redundancy](/azure/key-vault/general/disaster-recovery-guidance).

### Leverage autoscaling features

You can improve application availability and resiliency in AKS using autoscaling features, which help you achieve the following goals:

* Optimize resource utilization and cost efficiency by scaling up or down based on the CPU and memory usage of your pods.
* Enhance fault tolerance and recovery by adding more nodes or pods when a zone failure occurs.

You can use the [Horizontal Pod Autoscaler (HPA)](./concepts-scale.md#horizontal-pod-autoscaler) and [Cluster Autoscaler](./cluster-autoscaler-overview.md) to implement autoscaling in AKS. The HPA automatically scales the number of pods in a deployment based on observed CPU utilization, memory utilization, custom metrics, and metrics of other services. The Cluster Autoscaler automatically adjusts the number of nodes in a node pool based on pending pods and the resource requests on the pending pods.

The AKS Karpenter Provider feature enables node autoprovisioning using [Karpenter](https://karpenter.sh/) on your AKS cluster. For more information, see the [AKS Karpenter Provider feature overview](https://github.com/Azure/karpenter-provider-azure?tab=readme-ov-file#features-overview).

The [Kubernetes Event-driven Autoscaling (KEDA)](https://keda.sh/) add-on for AKS applies event-driven autoscaling to scale your application based on metrics of external services to meet demand. For more information, see [Install the KEDA add-on in Azure Kubernetes Service (AKS)](./keda-deploy-add-on-cli.md).

### Cluster Autoscaler and Availability Zones

When implementing **availability zones with the cluster autoscaler**, we recommend using a single node pool for each zone. You can set the `--balance-similar-node-groups` parameter to `True` to maintain a balanced distribution of nodes across zones for your workloads during scale up operations. When this approach isn't implemented, pods can remain in a pending state during scale ups. 

> [!NOTE]
> **The Cluster Autoscaler is not zone-aware, and zone allocation is handled by the underlying Virtual Machine Scale Sets and not by AKS**. The above best practice becomes even more relevant when using zone-based  **[pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)** on a single multi-az node pool, as restrictive constraints may leave pods in a pending state, especially in capacity-constrained regions or during zone-down scenarios.

The reason for the above recommendation is that:
  - Cluster Autoscaler performs scheduling simulations to determine whether adding a new node in a node pool can accommodate pending pods. It treats all nodes in a node pool as identical, so in a multi-AZ node pool, it cannot predict which zone the underlying Virtual Machine Scale Sets will provision the new node in. **Cluster Autoscaler cannot request nodes based on specific zones**. If the pending pod can be scheduled in the node pool, Cluster Autoscaler will scale up; however, if the new node is provisioned in a zone that violates strict topology spread constraints, the pods will remain pending and autoscaler will not continue scaling-up for the same pod.
  
  - AKS uses best-effort zone balancing on the underlying Virtual Machine Scale Sets (VMSS). However, in cases of zonal capacity constraints or zone-down scenarios in one AZ, VMSS will retry provisioning in another zone. If allocation fails in more than one availability zone, VMSS will not create a new node in that node pool, causing the scale-up operation to fail. Cluster Autoscaler will then place the node pool in a [backoff](./cluster-autoscaler-overview.md#node-pool-in-backoff) state.
  
  - Also, since the zone balancing of nodes is handled by underlying Virtual Machine Scale Sets, AKS will not automatically rebalance running workloads.
    
Using one node pool per availability zone helps overcome these limitations. Cluster Autoscaler treats each node pool as an independent entity, giving users greater flexibility to manage zone-specific scaling behavior. With single‑zone node pools, workloads remain schedulable on node pools in other zones during a zone failure, except when users explicitly define a strict zone‑based **[pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)**.

## Design a stateless application

When an application is *stateless*, the application logic and data are decoupled, and the pods don't store any persistent or session data on their local disks. This design allows the application to be easily scaled up or down without worrying about data loss. Stateless applications are more resilient to failures because they can be easily replaced or rescheduled on a different node in case of a node failure.

When designing a stateless application with AKS, you should use managed Azure services, such [Azure Databases](https://azure.microsoft.com/products/category/databases/), [Azure Cache for Redis](/azure/azure-cache-for-redis/cache-overview), or [Azure Storage](https://azure.microsoft.com/products/category/storage/) to store the application data. Using these services ensures your traffic can be moved across nodes and zones without risking data loss or impacting the user experience. You can use Kubernetes [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/), [Services](https://kubernetes.io/docs/concepts/services-networking/service/), and [Health Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) to manage stateless pods and ensure even distribution across zones.

## Make your storage disk decision

### Choose the right disk type based on application needs

Azure offers two types of disks for persistent storage: locally redundant storage (LRS) and zone redundant storage (ZRS). LRS replicates your data within a single AZ. ZRS replicates your data across multiple AZs within a region. Starting from AKS version 1.29, the default storage class uses ZRS disks for persistent storage. For more information, see [AKS built-in storage classes](./azure-csi-disk-storage-provision.md#built-in-storage-classes).

The way your application replicates data can influence your choice of disk. If your application is located in multiple zones and replicates the data from within the application, you can achieve resiliency with an LRS disk in each AZ because if one AZ goes down, the other AZs would have the latest data available to them. If your application layer doesn't handle such replication, ZRS disks are a better choice, as Azure handles the replication in the storage layer.

The following table outlines pros and cons of each disk type:

| Disk type | Pros | Cons |
| --------- | ---- | ---- |
| LRS | * Lower cost <br> * Supported for all disk sizes and regions <br> * Easy to use and provision | * Lower availability and durability <br> * Vulnerable to zonal failures <br> * Doesn't support zone or geo-replication |
| ZRS | * Higher availability and durability <br> * More resilient to zonal failures <br> * Supports zone replication for intra-region resiliency | * Higher cost <br> * Not supported for all disk sizes and regions <br> * Requires extra configuration to enable |

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
| * Mimics a realistic failure scenario and tests the recovery process <br> * Allows you to verify the availability and durability of your data across regions <br> * Helps you identify any potential issues or bottlenecks in your cluster configuration or application design | * Might cause temporary disruption or degradation of service for your users <br> * Requires manual intervention and coordination to drain and restore the node <br> * Might incur extra costs due to increased network traffic or storage replication |

### Method 2: Simulate an AZ failure using Azure Chaos Studio

Another way to test your AKS cluster for AZ resiliency is to inject faults into your cluster and observe the impact on your application using Azure Chaos Studio. Azure Chaos Studio is a service that allows you to create and manage chaos experiments on Azure resources and services. You can use Chaos Studio to simulate an AZ failure by creating a fault injection experiment that targets a specific zone and stops or restarts the virtual machines (VMs) in that zone. You can then measure the availability, latency, and error rate of your application using metrics and logs.

The following table outlines pros and cons of this method:

| Pros | Cons |
| ---- | ---- |
| * Provides a controlled and automated way to inject faults and monitor the results <br> * Supports various types of faults and scenarios, such as network latency, CPU stress, disk failure, etc. <br> * Integrates with Azure Monitor and other tools to collect and analyze data | * Might require extra configuration and setup to create and run experiments <br> * Might not cover all possible failure modes and edge zones that could occur during a real outage <br> * Might have limitations or restrictions on the scope and/or duration of the experiments |

For more information, see [What is Azure Chaos Studio?](/azure/chaos-studio/chaos-studio-overview).

## Next steps

For more implementation details, see the [Guide to zone redundant AKS clusters and storage](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/a-practical-guide-to-zone-redundant-aks-clusters-and-storage/ba-p/4036254).
