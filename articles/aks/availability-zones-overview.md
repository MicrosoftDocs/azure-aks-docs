---
title: Availability zones in Azure Kubernetes Service (AKS)
description: Learn about using availability zones in Azure Kubernetes Service (AKS) to increase the availability of your applications.
ms.service: azure-kubernetes-service
ms.topic: concept-article
ms.date: 12/12/2024
author: danbosscher
ms.author: dabossch
---

# Availability zones in Azure Kubernetes Service (AKS)
[Availability zones](/azure/reliability/availability-zones-overview) help protect your applications and data from datacenter failures. Zones are unique physical locations within an Azure region. Each zone includes one or more datacenters equipped with independent power, cooling, and networking.

Using AKS with availability zones physically distributes resources across different availability zones within a single region. This improves reliability against the failure of a zone.

![Diagram that shows AKS node distribution across availability zones.](media/availability-zones/aks-availability-zones.png)

If a zone becomes unavailable, AKS adjusts components as required.
This article shows you how to configure AKS components to use Availability Zones.

## AKS Components

> [!NOTE]
> A number of options, i.e. the number of availability zones a nodepool uses, **cannot be changed** after the component is created. Plan your deployment accordingly.

### [AKS Control Plane](/azure/aks/core-aks-concepts#control-plane)
Microsoft hosts the Kubernetes API server and services such as `scheduler` and `etcd` as a managed service. Running in the **Standard** pricing tier replicates the control plane in all zones within the region. The **Free** pricing tier runs in one zone only and is only recommended for testing purposes.

The other components of your cluster will be deployed in a managed resource group in the same subscription. By default, this resource group will be be prefixed with *MC_*, standing for 'Managed Cluster'.

### Node pools
Node pools are created as a Virtual Machine Scale Set in the same Azure Subscription. Each node in a node pool is a Virtual Machine. There are two types of node pools: User Node pools and System Node pools. When creating an AKS cluster, one System Node pool is required and created automatically.

### [System Node pools](/azure/aks/use-system-pools)
 System node pools host critical system pods such as `CoreDNS` and `metrics-server`.

A system node pool will, by default, be created across multiple availability zones. For production workloads, we recommend having a minimum of two nodes in this pool to ensure these critical system pods are highly available. We recommend system node pools are used

For larger deployments, you can create more system node pools and scale them individually per zone, depending on your application requirements.

### [User Node pools](/azure/aks/create-node-pools)
User Node pools host your applications. There are two main ways to deploy node pools to use Availability Zones.

#### One user node pool, spread across all zones
In this deployment, a single node pool is deployed across multiple availability zones. We recommend deploying at least three nodes per node pool to ensure at least one node per Availability Zone. AKS will balance the number of nodes between zones automatically.

#### Multiple user node pools, one per zone
Recommended for customers using the [cluster autoscaler](./cluster-autoscaler-overview.md), a good fit for short-running or bursty workloads. In this deployment, each zone has a single node pool.

We recommend setting `--balance-similar-node-groups` parameter to `true` to maintain a balanced distribution of nodes across zones for your workloads during scale up operations.

> [!NOTE]
> * A number of nodepool options, including the type of SKU used, **cannot be changed** after the nodepool is created.
> * Currently, autoscale balancing happens during scale up only. The cluster autoscaler scales down underutilized nodes regardless of the relative sizes of the node groups, but not below the value set by `--min-count`.

Customers can also use [proximity placement groups](/azure/aks/reduce-latency-ppg) to reduce latency between nodes by physically locating nodes close to each other in a single AZ.


## Deployments

### Pods
Kubernetes is aware of Azure Availability Zones, and balances pods across nodes in different zones. In the event a zone becomes unavailable, Kubernetes moves pods away from impacted nodes automatically.

The 'maxSkew' parameter, which is the maximum delta between pods per zone, is set to 5 by default. For smaller deployments (for example, that only have 2-3 pods total), consider setting 'maxSkew' to 1 like so, to ensure each zone has at least one pod running.

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: myapp
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: DoNotSchedule # or ScheduleAnyway
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.1
```

### Storage and volumes
Kubernetes 1.29 and up by default uses Azure Managed Disks using Zone-Redundant-Storage (ZRS) for persistent volume claims.
These disks can be attached across zones and it's the recommended deployment method for production workloads, as it enhances the resilience of your applications and safeguards your data against datacenter failures.

If cost optimization is a priority, you can create a new storage class with the `skuname` parameter set to LRS (Locally redundant storage). You can then use the new storage class in your Persistent Volume Claim (PVC). Volumes that use Azure managed LRS disks aren't zone-redundant resources, and attaching across zones isn't supported.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-zrs
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_ZRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Virtual Networking
Kubernetes deploys an Azure Standard Load Balancer by default, which spans across multiple Availability Zones.

### Load Balancers
Kubernetes deploys an Azure Standard Load Balancer by default, which will automatically balance inbound traffic across zones.
If a node becomes unavailable, the load balancer reroutes traffic to healthy nodes.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

> [!IMPORTANT]
> On September 30, 2025, Basic Load Balancer will be retired. For more information, see the official announcement. If you're currently using Basic Load Balancer, make sure to [upgrade](/azure/load-balancer/load-balancer-basic-upgrade-guidance) to Standard Load Balancer prior to the retirement date.

## Next steps

* [Create an AKS cluster with availability zones](./availability-zones.md).