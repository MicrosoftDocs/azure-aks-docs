---
title: "Intelligent Cross-Cluster Kubernetes Resource Placement Using Azure Kubernetes Fleet Manager"
description: Learn how to use Azure Kubernetes Fleet Manager to intelligently place your workloads on target member clusters based on cost and resource availability.
ms.topic: how-to
ms.date: 05/13/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - build-2024
---

# Intelligent cross-cluster Kubernetes resource placement using Azure Kubernetes Fleet Manager

Application developers often need to deploy Kubernetes resources into multiple clusters. Fleet operators often need to pick the best clusters for workloads based on heuristics (such as cost of compute) or available resources (such as memory and CPU). It's tedious to create, update, and track these Kubernetes resources across multiple clusters manually. This article covers how you can address these scenarios by using the intelligent Kubernetes resource placement capability in Azure Kubernetes Fleet Manager (Kubernetes Fleet).

The resource placement capability of Kubernetes Fleet can make scheduling decisions based on the following cluster properties:

* Node count
* Cost of compute/memory in target member clusters
* Resource (CPU/memory) availability in target member clusters

For more information about the concepts in this article, see [Kubernetes resource placement from hub cluster to member clusters](./concepts-resource-propagation.md).

## Prerequisites

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* You must have a Kubernetes Fleet resource with one or more member clusters. If you don't have one, follow the [quickstart][fleet-quickstart] to create a Kubernetes Fleet resource with a hub cluster. Then, join Azure Kubernetes Service (AKS) clusters as members.

  > [!TIP]
  > Ensure that your AKS member clusters are configured so that you can test placement by using the cluster properties that interest you (location, node count, resources, or cost).

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export MEMBERCLUSTER01=<cluster01>
    export MEMBERCLUSTER02=<cluster02>
    ```

* You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* If you don't have the Kubernetes CLI (kubectl) already, you can install it by using this command:

  ```azurecli-interactive
  az aks install-cli
  ```

* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Authorize kubectl to connect to the Kubernetes Fleet hub cluster:

  ```azurecli-interactive
  az fleet get-credentials --resource-group $GROUP --name $FLEET
  ```

## Inspect member cluster properties

Retrieve the labels, properties, and resources for your member cluster by querying the hub cluster. Output as YAML so you can read the results.

```azurecli-interactive
kubectl get membercluster $MEMBERCLUSTER01 –o yaml
```

The resulting YAML file contains details (labels and properties) that you can use to build placement policies. Here's an example:

```yaml
apiVersion: cluster.kubernetes-fleet.io/v1
kind: MemberCluster
metadata:
  annotations:
    ...
  labels:
    fleet.azure.com/location: eastus2
    fleet.azure.com/resource-group: resource-group
    fleet.azure.com/subscription-id: 8xxxxxxx-dxxx-4xxx-bxxx-xxxxxxxxxxx8
  name: cluster01
  resourceVersion: "123456"
  uid: 7xxxxxxx-5xxx-4xxx-bxxx-xxxxxxxxxxx4
spec:
  ...
status:
  ...
  properties:
    kubernetes-fleet.io/node-count:
      observationTime: "2024-09-19T01:33:54Z"
      value: "2"
    kubernetes.azure.com/per-cpu-core-cost:
      observationTime: "2024-09-19T01:33:54Z"
      value: "0.073"
    kubernetes.azure.com/per-gb-memory-cost:
      observationTime: "2024-09-19T01:33:54Z"
      value: "0.022"
  resourceUsage:
    allocatable:
      cpu: 3800m
      memory: 10320392Ki
    available:
      cpu: 2740m
      memory: 8821256Ki
    capacity:
      cpu: "4"
      memory: 14195208Ki
```

Repeat this step for each member cluster that you add, to identify the labels and properties that you can use in your policy.

## Prepare a workload for placement

Next, publish a workload to the hub cluster so that it can be placed onto member clusters:

1. Create a namespace for the workload on the hub cluster:

   ```azurecli-interactive
   kubectl create namespace test-app 
   ```

1. The sample workload can be deployed to the new namespace on the hub cluster. Because these Kubernetes resource types don't require [encapsulating](./concepts-resource-propagation.md#encapsulating-resources), you can deploy them without change.

   1. Save the following YAML into a file named `sample-workload.yaml`:

      ```yaml
      apiVersion: v1
      kind: Service
      metadata:
        name: nginx-service
        namespace: test-app
      spec:
        selector:
          app: nginx
        ports:
        - protocol: TCP
          port: 80
          targetPort: 80
        type: LoadBalancer
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: nginx-deployment
        namespace: test-app
      spec:
        selector:
          matchLabels:
            app: nginx
        replicas: 2
        template:
          metadata:
            labels:
              app: nginx
          spec:
            containers:
            - name: nginx
              image: nginx:1.16.1 
              ports:
              - containerPort: 80
      ```

   1. Deploy the workload definition to your hub cluster:

      ```azurecli-interactive
      kubectl apply -f sample-workload.yaml
      ```

With the workload definition deployed, it's now possible to test the intelligent placement capability of Kubernetes Fleet.

## Test workload placement policies

You can use the following samples, along with the [conceptual documentation](./concepts-resource-propagation.md#introducing-clusterresourceplacement), as guides to writing your own `ClusterResourcePlacement` object.
  
> [!NOTE]
> If you want to try out each sample policy, be sure to delete the previous `ClusterResourcePlacement` object.

### Placement based on cluster node count

This example shows a property sorter that uses the `Descending` order. This order means that Kubernetes Fleet prefers clusters with higher node counts.

The cluster with the highest node count receives a weight of 20, and the cluster with the lowest receives a weight of 0. Other clusters receive proportional weights calculated via the [weight calculation formula](./concepts-resource-propagation.md#how-property-ranking-works).

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-demo
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-app
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 10
    affinity:
        clusterAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 20
              preference:
                metricSorter:
                  name: kubernetes-fleet.io/node-count
                  sortOrder: Descending
```

### Placement with label selector and property sorter

In this example, a cluster receives a weight only if it has the label `env=prod`. If the cluster satisfies that label constraint, it's given proportional weight based on the amount of total CPU in that member cluster.

This example demonstrates how you can use both the label selector and the property sorter for `preferredDuringSchedulingIgnoredDuringExecution` affinity. A member cluster that fails the label selector doesn't receive any weight. Member clusters that satisfy the label selector receive proportional weights, as specified under the property sorter.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-demo
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-app
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 10
    affinity:
        clusterAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 20
              preference:
                labelSelector:
                  matchLabels:
                    env: prod
                metricSorter:
                  name: resources.kubernetes-fleet.io/total-cpu
                  sortOrder: Descending
```

### Placement based on memory and CPU core cost

Because the sorter in this example has an `Ascending` order, Kubernetes Fleet prefers clusters with lower memory and CPU core costs. The cluster with the lowest memory and CPU core cost receives a weight of 20, and the cluster with the highest receives a weight of 0. Other clusters receive proportional weights calculated via the weight calculation formula.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-demo
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-app
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 2
    affinity:
      clusterAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 20
            preference:
              propertySorter:
                name: kubernetes.azure.com/per-gb-memory-core-cost
                sortOrder: Ascending
          - weight: 20
            preference:
              propertySorter:
                name: kubernetes.azure.com/per-cpu-core-cost
                sortOrder: Ascending
```

## View the status of a placement

If you want to view the status of a placement, you can use either the Azure portal or the kubectl command.

You can find details on how to view a placement's progress in [Use the ClusterResourcePlacement API to propagate resources to member clusters](./quickstart-resource-propagation.md#use-the-clusterresourceplacement-api-to-propagate-resources-to-member-clusters).

## Clean up resources

For details on how to remove a cluster resource placement via the Azure portal or the kubectl command, see [Clean up resources](./quickstart-resource-propagation.md#clean-up-resources) in the article about propagating resources.

## Related content

* To learn more about resource propagation, see the [open-source Kubernetes Fleet documentation](https://github.com/Azure/fleet/blob/main/docs/concepts/ClusterResourcePlacement/README.md).

<!-- LINKS -->
[fleet-quickstart]: ./quickstart-create-fleet-and-members.md#create-a-fleet-resource
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
