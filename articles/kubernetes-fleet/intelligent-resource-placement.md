---
title: "Intelligent cross-cluster Kubernetes resource placement using Azure Kubernetes Fleet Manager"
description: Learn how to use Kubernetes Fleet to intelligently place your workloads on target member clusters based on cost and resource availability.
ms.topic: how-to
ms.date: 05/13/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - build-2024
---

# Intelligent cross-cluster Kubernetes resource placement using Azure Kubernetes Fleet Manager

Application developers often need to deploy Kubernetes resources into multiple clusters. Fleet operators often need to pick the best clusters for placing the workloads based on heuristics such as cost of compute in the clusters or available resources such as memory and CPU. It's tedious to create, update, and track these Kubernetes resources across multiple clusters manually. This article covers how Azure Kubernetes Fleet Manager (Fleet) allows you to address these scenarios using the intelligent Kubernetes resource placement feature.

## Overview

Fleet provides resource placement capability that can make scheduling decisions based on the following cluster properties:

- Node count
- Cost of compute/memory in target member clusters
- Resource (CPU/Memory) availability in target member clusters

Read the [resource propagation conceptual overview](./concepts-resource-propagation.md) to understand the concepts used in this how-to.

## Prerequisites

* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* You must have a Fleet resource with one or more member cluster. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource with a hub cluster and then join Azure Kubernetes Service (AKS) clusters as members. 

  **Recommendation:** Ensure you have configured your AKS member clusters so that you can test placement using the cluster properties you are interested in (location, node count, resources or cost).

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export MEMBERCLUSTER01=<cluster01>
    export MEMBERCLUSTER02=<cluster02>
    ```

* You need Azure CLI version 2.58.0 or later installed to complete this how-to. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* If you don't have it already, you can install the Kubernetes CLI (kubectl) by using this command:

  ```azurecli-interactive
  az aks install-cli
  ```

* You also need the `fleet` Azure CLI extension, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Authorize kubectl to connect to the fleet hub cluster:

  ```azurecli-interactive
  az fleet get-credentials --resource-group $GROUP --name $FLEET
  ```

## Inspect member cluster properties

Repeat these steps for each member cluster you add.

* Retrieve the labels, propteries and resources for your member cluster by querying the hub cluster. Output as YAML so you can read the results.

  ```azurecli-interactive
  kubectl get membercluster $MEMBERCLUSTER01 –o yaml
  ```

  The resulting YAML file contains details (labels and properties) you can use to build placement policies. 

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

  Repeat this step for each member cluster so you identify the labels and properties you can use in your policy.

## Prepare a workload for placement

Next, we are going to publish a workload to our hub cluster so that we can place it onto member clusters.

* Create a namespace for our workload on the hub cluster.

  ```azurecli-interactive
  kubectl create namespace test-app 
  ```

* We can deploy our workload to the new namespace on the hub cluster. As these Kubernetes resource types don't require [encapsulating](./concepts-resource-propagation.md#encapsulating-resources) they can be deployed 'as-is'. 

  Save the following YAML into a file named `sample-workload.yaml`.

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

  Deploy the workload definition to your hub cluster using the command.

  ```azurecli-interactive
  kubectl apply -f sample-workload.yaml 
  ```

  With the workload defintiion deployed it is now possible to test out fleet's intelligent placement capabilities.

## Test workload placement policies

You can use the following samples, along with the [conceptual documentation](./concepts-resource-propagation.md#introducing-clusterresourceplacement), as guides to writing your own ClusterResourcePlacement.
  
> [!NOTE]
> If you wish to try out each sample policy, make sure to delete the previous ClusterResourcePlacement.

### Placement based on cluster node count

This example shows a property sorter using the `Descending` order which means fleet will prefer clusters with higher node counts. 

The cluster with the highest node count would receive a weight of 20, and the cluster with the lowest would receive 0. Other clusters receive proportional weights calculated using the [weight calculation formula](./concepts-resource-propagation.md#how-property-ranking-works).

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

In this example, a cluster would only receive a weight if it has the label `env=prod`. If it satisfies that label constraint, then the cluster is given proportional weight based on the amount of total CPU in that member cluster.

This example demonstrates how you can use both label selector and property sorter for `preferredDuringSchedulingIgnoredDuringExecution` affinity. A member cluster that fails the label selector won't receive any weight. Member clusters that satisfy the label selector receive proportional weights as specified under property sorter.

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

As the sorter in this example has an `Ascending` order, fleet will prefer clusters with lower memory and CPU core costs. The cluster with the lowest memory and CPU core cost would receive a weight of 20, and the cluster with the highest would receive 0. Other clusters receive proportional weights calculated using the weight calculation formula.

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

## View status of placement 

If you wish to view the status of a placement you can either use the Azure portal or kubectl command.

Details on how to view a placement's progress can be found in the [propagate resources quickstart](./quickstart-resource-propagation.md#use-the-clusterresourceplacement-api-to-propagate-resources-to-member-clusters). 

## Clean up resources

Details on how to remove a cluster resource placement via the Azure portal or kubectl command can be found in the clean up resources section of the [propagate resources quickstart](./quickstart-resource-propagation.md#clean-up-resources). 


## Next steps

To learn more about resource propagation, see the following resources:

* [Open-source Fleet documentation](https://github.com/Azure/fleet/blob/main/docs/concepts/ClusterResourcePlacement/README.md)

<!-- LINKS -->
[fleet-quickstart]: ./quickstart-create-fleet-and-members.md#create-a-fleet-resource
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update