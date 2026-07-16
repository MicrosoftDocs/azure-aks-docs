---
title: "How to move a Kubernetes workload between clusters using Azure Kubernetes Fleet Manager resource placement"
description: Learn how to take over a Kubernetes workload on one cluster and move it to another cluster by using Azure Kubernetes Fleet Manager resource placement.
ms.topic: how-to
ms.date: 07/14/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a cloud architect, I want to move a Kubernetes workload between clusters using Fleet Manager resource placement, so that I can safely take over and migrate workloads already running on member clusters."
---

# Move a Kubernetes workload between clusters by using Azure Kubernetes Fleet Manager resource placement

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

This article shows how to move a Kubernetes workload on one cluster to another cluster by using Fleet Manager resource placement. It also explains how [resource placement](./intelligent-resource-placement.md) can safely take over an existing workload already running on a member cluster.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* An Azure Kubernetes Fleet Manager with a hub cluster. If you don't have one, see [Create an Azure Kubernetes Fleet Manager and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).

* Two member clusters named `aks-member-1` and `aks-member-2`, with the sample workload directly deployed on `aks-member-1`. These member clusters can be AKS or Azure Arc-enabled Kubernetes clusters.

* The user completing the configuration has permissions to perform Azure role assignments and to access the Fleet Manager hub cluster Kubernetes API. For more information, see [Access the Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).

* Set the following environment variables:

    ```bash
    export SUBSCRIPTION_ID=<subscription>
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export MEMBER_CLUSTER_1=aks-member-1
    export MEMBER_CLUSTER_2=aks-member-2
    ```

## Sample workload

For this article, use [kuard](https://github.com/kubernetes-up-and-running/kuard) as the sample workload. 

Start by saving the following manifest to a file named `kuard-workload.yaml`. Deploy the manifest directly to the member cluster `aks-member-1` by using `kubectl`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kuard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuard
  namespace: kuard
  labels:
    app: kuard
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kuard
  template:
    metadata:
      labels:
        app: kuard
    spec:
      containers:
        - name: kuard
          image: blauwelucht/kuard-amd64:blue
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kuard
  namespace: kuard
spec:
  selector:
    app: kuard
  ports:
    - port: 8080
      targetPort: 8080
```

Now that the workload is running on a single cluster, you can migrate the workload to being managed by Fleet Manager and then distribute it to another cluster.

## Stage the workload on Fleet Manager hub cluster

Get the credentials to access the Fleet Manager hub cluster:

```azurecli-interactive
az fleet get-credentials \
    --resource-group ${GROUP} \
    --name ${FLEET}
```

Use the same manifest from the previous step and apply it to the Fleet Manager hub cluster:

```bash
kubectl apply -f kuard-workload.yaml
```

The applied workload isn't scheduled on the hub cluster, but is now ready for Fleet Manager to distribute.

The original workload is still running on `aks-member-1` and isn't yet under Fleet Manager's control.

## Take over workload with Fleet Manager

For this sample, use a `PickFixed` placement policy to explicitly target clusters by name.

By defining an `applyStrategy`, you control how Fleet Manager treats matching workloads on member clusters. In this example, you take over the existing workload when there are no differences between the properties of the target workload and those properties on the Fleet Manager hub cluster.

To understand take over behavior, see [Taking over existing workloads with Azure Kubernetes Fleet Manager resource placement](concepts-placement-takeover.md).

Save the following content to the file `deploy-kuard-fleet.yaml`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
    name: deploy-kuard-fleet
spec:
    resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1
          name: "kuard"
    policy:
        placementType: PickFixed
        clusterNames:
        - aks-member-1
    strategy:
        applyStrategy:
            whenToTakeOver: IfNoDiff
            comparisonOption: PartialComparison
```
 
Apply the manifest on the Fleet Manager hub cluster to start the placement process and take over the existing cluster workload.

```bash
kubectl apply -f deploy-kuard-fleet.yaml
```

Monitor the placement by using the following command.

```bash
kubectl get clusterresourceplacement deploy-kuard-fleet
```

When the placement finishes, Fleet Manager is now responsible for the workload on the `aks-member-1` cluster.

## Move workload to a new cluster

Modify the `deploy-kuard-fleet.yaml` file by adding `aks-member-2` to the `clusterNames` array.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
    name: deploy-kuard-fleet
spec:
    resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1
          name: "kuard"
    policy:
        placementType: PickFixed
        clusterNames:
        - aks-member-1
        - aks-member-2
    strategy:
        applyStrategy:
            whenToTakeOver: IfNoDiff
            comparisonOption: PartialComparison
```

Reapply the manifest to the hub cluster, and watch as the workload rolls out to the newly added member cluster.

```bash
kubectl apply -f deploy-kuard-fleet.yaml
```

At this stage, you can manage the distribution of the workload across member clusters entirely through Fleet Manager, making it substantially easier to deal with outages and problematic clusters.

By using the `applyStrategy` available with Fleet Manager's resource placement, you don't have to disrupt your existing running workload to arrive at this setup.

## Next steps

* [Use Resource Overrides to customize deployed resources](./howto-use-overrides-customize-resources-placement.md).
* [Understanding the status of resource placements](./howto-understand-placement.md).
* [Intelligent cross-cluster Kubernetes resource placement](./intelligent-resource-placement.md).
* [Fleet Manager Frequently Asked Questions (FAQs)](./faq.md).
