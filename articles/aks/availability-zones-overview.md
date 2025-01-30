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

Using AKS with availability zones physically distributes resources across different availability zones within a single region, improving reliability. There's no extra cost for deploying nodes in multiple zones.

This article shows you how to configure AKS resources to use Availability Zones.

## AKS resources
This diagram shows the Azure resources that are created when you create an AKS cluster:

:::image type="content" source="media/availability-zones/high-level-inl.png" alt-text="Diagram that shows various AKS components, showing AKS components hosted by Microsoft and AKS components in your Azure subscription." lightbox="media/availability-zones/high-level-exp.png":::


### AKS Control Plane
Microsoft hosts the [AKS control plane](/azure/aks/core-aks-concepts#control-plane), the Kubernetes API server, and services such as `scheduler` and `etcd` as a managed service. Microsoft replicates the control plane in multiple zones.

Other resources of your cluster deploy in a managed resource group in your Azure subscription. By default, this resource group is prefixed with *MC_*, for Managed Cluster and contains the following resources:

### Node pools
Node pools are created as a Virtual Machine Scale Set in your Azure Subscription. 

When you create an AKS cluster, one [System Node pool](/azure/aks/use-system-pools) is required and created automatically. It hosts critical system pods such as `CoreDNS` and `metrics-server`. More [User Node pools](/azure/aks/create-node-pools) can be added to your AKS cluster to host your applications.

There are three ways node pools can be deployed: 
- Zone spanning
- Zone aligned
- Regional.

:::image type="content" source="media/availability-zones/az-spanning-inl.png" alt-text="Diagram that shows AKS node distribution across availability zones in the different models." lightbox="media/availability-zones/az-spanning-exp.png":::

For the system node pool, the number of zones used is configured when the cluster is created.

#### Zone spanning
A zone spanning scale set spreads nodes across all selected zones, by specifying these zones with the `--zones` parameter.

```bash
# Create an AKS Cluster, and create a zone spanning System Nodepool in all three AZs, one node in each AZ
az aks create --resource-group example-rg --name example-cluster --node-count 3 --zones 1, 2, 3
# Add one new zone spanning User Nodepool, two nodes in each
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-a  --node-count 6 --zones 1, 2, 3 
```
AKS balances the number of nodes between zones automatically.

If a zonal outage occurs, nodes within the affected zone can be impacted, while nodes in other availability zones remain unaffected.

#### Zone aligned
Each node is aligned (pinned) to a specific zone. To create three node pools for a region with three Availability Zones:

```bash
# # Add three new zone aligned User Nodepools, two nodes in each
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-x  --node-count 2 --zones 1
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-y  --node-count 2 --zones 2
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-z  --node-count 2 --zones 3
```

 This configuration can be used when you need [lower latency between nodes](/azure/aks/reduce-latency-ppg). It also provides more granular control over scaling operations, or when using the [cluster autoscaler](./cluster-autoscaler-overview.md). 

> [!NOTE]
> * If a single workload is deployed across node pools, we recommend setting `--balance-similar-node-groups`  to `true` to maintain a balanced distribution of nodes across zones for your workloads during scale up operations.

#### Regional (not using Availability Zones)
Regional mode is used when the zone assignment isn't set in the deployment template (`"zones"=[] or "zones"=null`).

In this configuration, the node pool creates Regional (not-zone pinned) instances and implicitly places instances throughout the region. There's no guarantee for balance or spread across zones, or that instances land in the same availability zone. 

In the rare case of a full zonal outage, any or all instances within the node pool can be impacted.

To validate node locations, run the following command:

```bash
kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
```

```output
NAME                                REGION   ZONE
aks-nodepool1-34917322-vmss000000   eastus   eastus-1
aks-nodepool1-34917322-vmss000001   eastus   eastus-2
aks-nodepool1-34917322-vmss000002   eastus   eastus-3
```

## Deployments

### Pods
Kubernetes is aware of Azure Availability Zones, and can balance pods across nodes in different zones. In the event a zone becomes unavailable, Kubernetes moves pods away from impacted nodes automatically.

As documented in [Well-Known Labels, Annotations and Taints][kubernetes-well-known-labels], Kubernetes uses the `topology.kubernetes.io/zone` label to automatically distribute pods in a replication controller or service across the different zones available.

To view on which pods nodes are running, run the following command:

```bash
  kubectl describe pod | grep -e "^Name:" -e "^Node:"
```

The 'maxSkew' parameter describes the degree to which Pods might be unevenly distributed.
Assuming three zones and three replicas, setting this value to 1 ensures each zone has at least one pod running:

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: myapp
spec:
  replicas: 3
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: DoNotSchedule # or ScheduleAnyway
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.1
```

### Storage and volumes
By default, Kubernetes versions 1.29 and later use Azure Managed Disks using Zone-Redundant-Storage (ZRS) for persistent volume claims. The recommended deployment method for production workloads is to attach these disks across zones in order to enhance the resilience of your applications and safeguards your data against datacenter failures.

An example of a persistent volume claim that uses Standard SSD in ZRS:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: azure-managed-disk
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-csi
  #storageClassName: managed-csi-premium
  resources:
    requests:
      storage: 5Gi
```

For zone aligned deployments, you can create a new storage class with the `skuname` parameter set to an LRS (Locally redundant storage) disk. You can then use the new storage class in your Persistent Volume Claim (PVC). Volumes that use Azure managed LRS disks aren't zone-redundant resources, and attaching across zones isn't supported. 

An example of an LRS Standard SSD storage class:

```yaml
kind: StorageClass

metadata:
  name: azuredisk-csi-standard-lrs
provisioner: disk.csi.azure.com
parameters:
  skuname: StandardSSD_LRS
  #skuname: PremiumV2_LRS
```

### Load Balancers
Kubernetes deploys an Azure Standard Load Balancer by default, which balances inbound traffic across all zones in a region. If a node becomes unavailable, the load balancer reroutes traffic to healthy nodes.

An example Service that uses the Azure Load Balancer:

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
> On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you're currently using Basic Load Balancer, make sure to [upgrade](/azure/load-balancer/load-balancer-basic-upgrade-guidance) to Standard Load Balancer before the retirement date.

## Limitations

The following limitations apply when using Availability Zones:

* See [Quotas, Virtual Machine size restrictions, and region availability in AKS][aks-vm-sizes].
* The number of Availability Zones used **cannot be changed** after the node pool is created.
* Most regions support Availability Zones. A list can be found [here][zones].

## Next steps

* Learn about [System Node pool](/azure/aks/use-system-pools) 
* Learn about [User Node pools](/azure/aks/create-node-pools)
* Learn about [Load Balancers](/azure/aks/load-balancer-standard)
* [Best practices for business continuity and disaster recovery in AKS][best-practices-multi-region]

<!-- LINKS - external -->
[kubernetes-well-known-labels]: https://kubernetes.io/docs/reference/labels-annotations-taints/

<!-- LINKS - internal -->
[aks-vm-sizes]: ./quotas-skus-regions.md#supported-vm-sizes
[zones]: /azure/reliability/availability-zones-region-support
[best-practices-multi-region]: ./operator-best-practices-storage.md