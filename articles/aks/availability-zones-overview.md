---
title: Availability Zones in Azure Kubernetes Service (AKS)
description: Learn how to use availability zones in Azure Kubernetes Service (AKS) to increase the availability of your applications.
ms.service: azure-kubernetes-service
ms.topic: concept-article
ms.date: 02/03/2025
author: danbosscher
ms.author: dabossch
---

# Availability zones in Azure Kubernetes Service (AKS)

[Availability zones](/azure/reliability/availability-zones-overview) help protect your applications and data from datacenter failures. Zones are unique physical locations within an Azure region. Each zone includes one or more datacenters equipped with independent power, cooling, and networking.

Using AKS with availability zones physically distributes resources across different availability zones within a single region, improving reliability. Deploying nodes in multiple zones doesn't incur additional costs.

This article shows you how to configure AKS resources to use availability zones.

## AKS resources

This diagram shows the Azure resources that are created when you create an AKS cluster:

:::image type="content" source="media/availability-zones/high-level-inl.png" alt-text="Diagram that shows various AKS components, including AKS components hosted by Microsoft and AKS components in your Azure subscription." lightbox="media/availability-zones/high-level-exp.png":::

### AKS control plane

Microsoft hosts the [AKS control plane](/azure/aks/core-aks-concepts#control-plane), the Kubernetes API server, and services such as `scheduler` and `etcd` as a managed service. Microsoft replicates the control plane in multiple zones.

Other resources of your cluster deploy in a managed resource group in your Azure subscription. By default, this resource group is prefixed with *MC_*, for managed cluster and contains the following resources:

### Node pools

Node pools are created as virtual machine scale sets in your Azure subscription.

When you create an AKS cluster, one [system node pool](/azure/aks/use-system-pools) is required and is created automatically. It hosts critical system pods such as `CoreDNS` and `metrics-server`. You can add more [user node pools](/azure/aks/create-node-pools) to your AKS cluster to host your applications.

There are three ways node pools can be deployed:

- Zone-spanning scale set
- Zone-aligned scale set
- Regional

:::image type="content" source="media/availability-zones/az-spanning-inl.png" alt-text="Diagram that shows AKS node distribution across availability zones in different models." lightbox="media/availability-zones/az-spanning-exp.png":::

For the system node pool, the number of zones that are used is configured when the cluster is created.

#### Zone-spanning scale set

A zone-spanning scale set spreads nodes across all selected zones. These zones are specified by using the `--zones` parameter.

```bash
# Create an AKS cluster, and create a zone-spanning system node pool in all three AZs, one node in each AZ
az aks create --resource-group example-rg --name example-cluster --node-count 3 --zones 1 2 3
# Add one new zone-spanning user node pool, two nodes in each
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-a  --node-count 6 --zones 1 2 3
```

AKS automatically balances the number of nodes between zones.

If a zonal outage occurs, nodes within the affected zone can be impacted, but nodes in other availability zones remain unaffected.

To validate node locations, run the following command:

```bash
kubectl get nodes -o custom-columns='NAME:metadata.name, REGION:metadata.labels.topology\.kubernetes\.io/region, ZONE:metadata.labels.topology\.kubernetes\.io/zone'
```

```output
NAME                                REGION   ZONE
aks-nodepool1-34917322-vmss000000   eastus   eastus-1
aks-nodepool1-34917322-vmss000001   eastus   eastus-2
aks-nodepool1-34917322-vmss000002   eastus   eastus-3
```

#### Zone-aligned scale set

In this configuration, each node is aligned (pinned) to a specific zone. To create three node pools for a region with three availability zones:

```bash
# # Add three new zone-aligned user node pools, two nodes in each
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-x  --node-count 2 --zones 1
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-y  --node-count 2 --zones 2
az aks nodepool add --resource-group example-rg --cluster-name example-cluster --name userpool-z  --node-count 2 --zones 3
```

This configuration can be used when you need [lower latency between nodes](/azure/aks/reduce-latency-ppg). It also provides more granular control over scaling operations, or when using the [cluster autoscaler](./cluster-autoscaler-overview.md).

> [!NOTE]
> If a single workload is deployed across node pools, we recommend setting `--balance-similar-node-groups`  to `true` to maintain a balanced distribution of nodes across zones for your workloads during scale-up operations.

#### Regional (not using availability zones)

Regional mode is used when the zone assignment isn't set in the deployment template (for example `"zones"=[]` or `"zones"=null`).

In this configuration, the node pool creates regional (not zone-pinned) instances and implicitly places instances throughout the region. There's no guarantee that instances are balanced or spread across zones, or that instances are in the same availability zone.

In the rare case of a full zonal outage, any or all instances within the node pool can be impacted.

To validate node locations, run the following command:

```bash
kubectl get nodes -o custom-columns='NAME:metadata.name, REGION:metadata.labels.topology\.kubernetes\.io/region, ZONE:metadata.labels.topology\.kubernetes\.io/zone'
```

```output
NAME                                REGION   ZONE
aks-nodepool1-34917322-vmss000000   eastus   0
aks-nodepool1-34917322-vmss000001   eastus   0
aks-nodepool1-34917322-vmss000002   eastus   0
```

## Deployments

### Pods

Kubernetes is aware of Azure availability zones, and can balance pods across nodes in different zones. In the event a zone becomes unavailable, Kubernetes moves pods away from impacted nodes automatically.

As documented in the Kubernetes reference [Well-Known Labels, Annotations and Taints][kubernetes-well-known-labels], Kubernetes uses the `topology.kubernetes.io/zone` label to automatically distribute pods in a replication controller or service across the various available zones available.

To see which pods and nodes are running, run the following command:

```bash
  kubectl describe pod | grep -e "^Name:" -e "^Node:"
```

The `maxSkew` parameter describes the degree to which pods might be unevenly distributed. Assuming three zones and three replicas, setting this value to 1 ensures that each zone has at least one pod running:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: my-app
      containers:
      - name: my-container
        image: my-image
```

### Storage and volumes

By default, Kubernetes versions 1.29 and later use Azure Managed Disks by using zone-redundant storage for Persistent Volume Claims.

These disks are replicated between zones, in order to enhance the resilience of your applications. This action helps to safeguard your data against datacenter failures.

The following example shows a Persistent Volume Claim that uses Azure Standard SSD in zone-redundant storage:

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

For zone-aligned deployments, you can create a new storage class with the `skuname` parameter set to **LRS** (locally redundant storage). You can then use the new storage class in your Persistent Volume Claim.

Although locally redundant storage disks are less expensive, they aren't zone-redundant, and attaching a disk to a node in a different zone isn't supported.

The following example shows a locally redundant storage Standard SSD storage class:

```yaml
kind: StorageClass

metadata:
  name: azuredisk-csi-standard-lrs
provisioner: disk.csi.azure.com
parameters:
  skuname: StandardSSD_LRS
  #skuname: PremiumV2_LRS
```

### Load balancers

Kubernetes deploys Azure Standard Load Balancer by default, which balances inbound traffic across all zones in a region. If a node becomes unavailable, the load balancer reroutes traffic to healthy nodes.

An example service that uses Azure Load Balancer:

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
> On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you use Basic Load Balancer, make sure to [upgrade](/azure/load-balancer/load-balancer-basic-upgrade-guidance) to Standard Load Balancer before the retirement date.

## Limitations

The following limitations apply when using availability zones:

* See [Quotas, virtual machine size restrictions, and region availability in AKS][aks-vm-sizes].
* The number of availability zones used *can't be changed* after the node pool is created.
* Most regions support availability zones. A list of regions can be found [here][zones].

## Related content

* Learn about [system node pool](/azure/aks/use-system-pools)
* Learn about [user node pools](/azure/aks/create-node-pools)
* Learn about [load balancers](/azure/aks/load-balancer-standard)
* [Best practices for business continuity and disaster recovery in AKS][best-practices-multi-region]

<!-- LINKS - external -->
[kubernetes-well-known-labels]: https://kubernetes.io/docs/reference/labels-annotations-taints/

<!-- LINKS - internal -->
[aks-vm-sizes]: ./quotas-skus-regions.md#supported-vm-sizes
[zones]: /azure/reliability/availability-zones-region-support
[best-practices-multi-region]: ./operator-best-practices-storage.md
