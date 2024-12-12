---
title: Availability zones in Azure Kubernetes Service (AKS)
description: Learn about using availability zones in Azure Kubernetes Service (AKS) to increase the availability of your applications.
ms.service: azure-kubernetes-service
ms.topic: concept-article
ms.date: 12/12/2024
author: dabossch
ms.author: dabossch
---

# Availability zones in Azure Kubernetes Service (AKS)
[Availability zones](/azure/reliability/availability-zones-overview) help protect your applications and data from datacenter failures. Zones are unique physical locations within an Azure region. Each zone includes one or more datacenters equipped with independent power, cooling, and networking.

Using AKS with availability zones physically distributes resources across different availability zones within a single region. For example, a cluster in the *East US 2* region can create resources in all three availability zones in *East US 2*. This distribution improves reliability against the failure of a zone.

![Diagram that shows AKS node distribution across availability zones.](media/availability-zones/aks-availability-zones.png)

If a zone becomes unavailable, your applications continue to run on clusters configured to spread across multiple zones. AKS will automatically adjust components as required. This article shows you how to configure AKS components and update your deployment to leverage Availability Zones.

## AKS Components

> [!NOTE]
> A number of cluster options, including the number of availability zones used, **cannot be changed** after the cluster is created. Plan your deployment accordingly. For most production workloads, we recommend deploying to **all** zones within the region of your choosing.

### [AKS Control Plane](/azure/aks/core-aks-concepts#control-plane)
Microsoft hosts the Kubernetes API server and services such as `scheduler` and `etcd` as a managed service. Running in the default **Standard** pricing tier will replicate the control plane in all zones within the region. The **Free** pricing tier will run in one zone only and is only recommended for testing purposes.

### Nodepools
Nodepools are created as a Virtual Machine Scale Set in the same Azure Subscription. Each node in a nodepool is a Virtual Machine. There are two types of nodepools: User Nodepools and System Nodepools.

### [User Nodepools](/azure/aks/create-node-pools)
User Nodepools host your applications. There are two main ways to deploy nodepools to leverage Availability Zones.

#### One user nodepool, spread across all zones
This is the recommended deployment method for long-running workloads. 
In this deployment, a single nodepool is deployed across multiple availability zones. We recommend deploying at least three nodes per nodepool to ensure at least one node per Availability Zone.

#### Multiple user nodepools, one per zone
This is the recommended deployment method for customers using the [cluster autoscaler](./cluster-autoscaler-overview.md), a good fit for short-running or bursty workloads. In this deployment, each zone has a single nodepool.

We recommend to set `--balance-similar-node-groups` parameter to `true` to maintain a balanced distribution of nodes across zones for your workloads during scale up operations.

> [!NOTE]
> * Currently, balancing happens during scale up operations only. The cluster autoscaler scales down underutilized nodes regardless of the relative sizes of the node groups.

Customers can also leverage [proximity placement groups](/azure/aks/reduce-latency-ppg) per nodepool/availability zone, to reduce latency between nodes by physically locating nodes close to each other.

### [System Nodepools](/azure/aks/use-system-pools)
 System nodepools hosts critical system pods such as `CoreDNS` and `metrics-server`. A system nodepool will, by default, be created across multiple availability zones. For most production workloads, we recommend having a minimum of three nodes in this pool to ensure these critical system pods are highly available.

For smaller or test deployments, applications can be deployed to system nodepools to reduce cost.
For larger deployments, you can create additional system nodepools and scale them individually per zone, depending on your application requirements.

## Deployments

### Pods
Kubernetes is aware of Azure Availability Zones, and will balance pods across nodes in different zones. In the event a zone becomes unavailable, Kubernetes will move pods away from impacted nodes automatically.

The 'maxSkew' parameter, which is the maximum number of difference between pods per zone, is set to 5 by default. For smaller deployments (for example, that only have 2-3 pods total), consider setting 'maxSkew' to 1 like so, to ensure each zone has at least 1 pod running.

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
  labels:
    foo: bar
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: DoNotSchedule # or ScheduleAnyway
    labelSelector:
      matchLabels:
        foo: bar
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.1
```

### Volumes
Kubernetes 1.29 and up by default uses Azure Managed Disks using Zone-Redundant-Storage (ZRS) for persistent volume claims. These disks can be attached across zones and it is the recommended deployment method for production workloads, as it enhances the resilience of your applications and safeguards your data against datacenter failures.

If cost optimization is a priority, you can create a new storage class with the `skuname` parameter set to LRS. You can then use the new storage class in your Persistent Volume Claim (PVC). Volumes that use Azure managed LRS disks aren't zone-redundant resources, and attaching across zones isn't supported.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-zrs
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Load Balancers
Kubernetes deploys Azure Standard Load Balancers by default, which span across multiple Availability Zones.

> [!IMPORTANT]
> On September 30, 2025, Basic Load Balancer will be retired. For more information, see the official announcement. If you're currently using Basic Load Balancer, make sure to [upgrade](/azure/load-balancer/load-balancer-basic-upgrade-guidance) to Standard Load Balancer prior to the retirement date.

## Next steps

* [Create an AKS cluster with availability zones](./availability-zones.md).