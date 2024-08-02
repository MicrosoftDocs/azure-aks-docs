---
title: Enable managed add-on autoscaling on your Azure Kubernetes Service (AKS) cluster
description: This article provides an overview of the add-on autoscaling feature in Azure Kubernetes Service (AKS).
ms.author: schaffererin
author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/02/2024
---

# Enable managed add-on autoscaling on your Azure Kubernetes Service (AKS) cluster (Preview)

This article provides an overview of managed add-on autoscaling in Azure Kubernetes Service (AKS). With add-on autoscaling, you can easily manage workloads requiring CPU and memory settings different than the default values by overriding the resource configuration. This feature ensures that resources aren't overly allocated to add-on pods, increasing cost savings and cluster efficiency.

## Overview

Enabling the add-on autoscaling feature in your AKS cluster installs the Vertical Pod Autoscaler (VPA) add-on and VPA custom resources for AKS managed add-ons that support this capability.

This feature allows you to override the resource CPU and memory requests and limits in Deployments and DaemonSets, the maximum and minimum allowed CPU and memory, and the VPA update mode within VPA custom resources. For more information, see [Override the resource configuration for AKS managed add-ons](./override-resource-configuration.md).

### Supported AKS managed add-ons

The following AKS managed add-ons support the add-on autoscaling feature:

* CoreDNS
* Workload Identity
* Image Cleaner
* Image Integrity
* Network Observability (Retina)

### Limitations

* Currently, the only supported VPA update modes are *Off* and *Initial*.
* AKS doesn't retain the overridden CPU/memory requests/limits, VPA minimum/maximum allowed CPU/memory, or VPA update mode values. If you delete the Deployment, DaemonSet, or VPA custom resource, the changes revert back to the AKS managed add-on's initial configuration.

> [!NOTE]
> When enabling managed add-on autoscaling, keep the following considerations in mind:
>
> * The add-on autoscaling feature enables the VPA add-on to autoscale the AKS managed add-ons that support this capability. It doesn't work with the VPA controller or with user-created VPA custom resources.
> * If the cluster doesn't enable the cluster autoscaler to adjust the number of nodes dynamically, it's possible that pod will be unable to be scheduled after VPA adjusts the CPU/memory requests/limits due to lack of resources on the available nodes for the pods.

## Prerequisites

* An AKS cluster running Kubernetes version 1.25 or later.
* The Azure CLI installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) and [register the add-on autoscaling preview feature](#register-the-add-on-autoscaling-preview-feature).

[!INCLUDE [preview features callout]((~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md))]

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the `az extension add` command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the `az extension update` command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the add-on autoscaling preview feature

1. Register the add-on autoscaling preview feature using the `az feature register` command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKS-AddonAutoscalingPreview"
    ```

    It takes a few minutes for the status to show as *Registered*.

2. Verify the registration status using the `az feature show` command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AKS-AddonAutoscalingPreview"
    ```

3. When the status shows as *Registered*, refresh the registration of the Microsoft.ContainerService provider using the `az provider register` command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Enable add-on autoscaling on an AKS cluster

Enable add-on autoscaling on a new AKS cluster using the [`az aks create`][az-aks-create] command with the `--enable-addon-autoscaling` flag.

```azurecli-interactive
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --enable-addon-autoscaling
```

Enable add-on autoscaling on an existing AKS cluster using the [`az aks update`][az-aks-update] command with the `--enable-addon-autoscaling` flag.

```azurecli-interactive
az aks update --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --enable-addon-autoscaling
```

## Disable add-on autoscaling on an AKS cluster

Disable add-on autoscaling on an AKS cluster using the [`az aks update`][az-aks-update] command with the `--disable-addon-autoscaling` flag.

```azurecli-interactive
az aks update --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --disable-addon-autoscaling
```

> [!NOTE]
> Disabling the add-on autoscaling feature doesn't disable the VPA add-on by default. To disable VPA, see [Disable VPA on an AKS cluster](./use-vertical-pod-autoscaler.md#disable-the-vertical-pod-autoscaler-on-an-existing-cluster).

## Apply the VPA recommended values

1. Make sure the VPA update mode is set to *Initial* in the VPA custom resource. With *Initial* mode, the VPA applies the recommended CPU/memory requests/limits when the pod is created or updated.
2. Check the pod status and CPU/memory utilization to verify that the pod is running as expected.

    The following example uses the `kubectl get pod` command to check a CoreDNS pod status:

    ```bash
    kubectl get pod <coredns-pod-name> --namespace kube-system -o yaml
    ```

    The following output shows an example status of a CoreDNS pod:

    ```output
    apiVersion: v1
    kind: Pod
    metadata:
      name: <coredns-pod-name>
      namespace: kube-system
    spec:
      ...
      containers:
      - name: coredns
        resources:
          limits:
            cpu: "3"
            memory: "500Mi"
          requests:
            cpu: "100m"
            memory: "70Mi"
    ```

3. Get the VPA recommended value using the `kubectl get vpa` command.

    ```bash
    kubectl get vpa coredns --namespace kube-system
    ```

    The following output shows an example of the VPA recommended value for a CoreDNS pod:

    ```output
    NAME      MODE      CPU   MEM        PROVIDED   AGE
    coredns   Initial   11m   23574998   True       44m
    ```

4. If you want to use the values recommended by VPA, manually delete the pod using the `kubectl delete pod` command to restart the pod with the VPA recommended values.

    ```bash
    kubectl delete pod <coredns-pod-name> --namespace kube-system
    ```

5. After the pod restarts, verify the pod status and CPU/memory updates using the `kubectl get pod` command.

    ```bash
    kubectl get pod <coredns-pod-name> --namespace kube-system -o yaml
    ```

    The following output shows an example status of a CoreDNS pod after applying the VPA recommended values:

    ```output
    apiVersion: v1
    kind: Pod
    metadata:
      name: <coredns-pod-name>
      namespace: kube-system
    spec:
      ...
      containers:
      - name: coredns
        resources:
          limits:
            cpu: "330m"
            memory: "168392842"
          requests:
            cpu: "11m"
            memory: "23574998"
    ```

## Next steps

Now that your cluster is enabled with the add-on autoscaling feature, you can override the resource configuration for AKS managed add-ons. For more information, see [Override the resource configuration for AKS managed add-ons](./override-resource-configuration.md).

## Troubleshooting

If your autoscaling enabled managed add-on pods are in a pending state, or you don't see any VPA recommendations for autoscaling enabled managed add-ons, follow these steps to troubleshoot the issue.

### Check AKS-managed VPA add-on status

1. Check if all VPA system components are running using the `kubectl get pods` command.

    ```bash
    kubectl get pods --namespace kube-system | grep vpa
    ```

    The output should show three pods (vpa-admission-controller, vpa-recommender, and vpa-updater) running in the `kube-system` namespace, similar to the following example:

    ```output
    vpa-admission-controller   2/2     2            2           4m11s
    vpa-recommender            1/1     1            1           4m11s
    vpa-updater                1/1     1            1           4m11s
    ```

2. For each of the three VPA pods, check the logs for any errors using the `kubectl logs` command. Make sure to replace `<pod-name>` with the names of the VPA pods.

    ```bash
    kubectl logs <pod-name> --namespace kube-system | grep -e '^E[0-9]\{4\}'
    ```

3. Confirm the custom resource definition (CRD) was creating using the `kubectl get` command.

    ```bash
    kubectl get customresourcedefinition | grep verticalpodautoscalers
    ```

### Check pod status and CPU/memory utilization

1. Check the pod's status using the `kubectl get pod` command.

    ```bash
    kubectl get pod <pod-name> --namespace=kube-system
    ```

2. If the pod has a status of `Pending`, check the pod's status property to determine the reason the pod isn't running.

    ```bash
    kubectl describe pod <pod-name> --namespace kube-system -o yaml
    ```

    The following output shows an example status of a pod with a status of `Pending`:

    ```output
    apiVersion: v1
    kind: Pod
    ...
    status:
      conditions:
      - lastProbeTime: null
        lastTransitionTime: "2023-05-03T17:05:26Z"
        message: '0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
          preemption: 0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory..'
        reason: Unschedulable
        status: "False"
        type: PodScheduled
      phase: Pending
      qosClass: Guaranteed
    ```

3. If the output shows that the pod is `Pending` due to insufficient CPU or memory, consider the following actions:

    * Add more nodes so that pods can be scheduled in nodes with lower resource usage.
    * Disable VPA for the target add-on pod by changing the update mode to *Off*, and then [manually update the requests/limits](./override-resource-configuration.md) to the available resource values on the node. With this approach, keep in mind that the pod might experience OOM kill or CPU throttling issues later due to the pod trying to consume more resources than the available resources on the node.

<!-- LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update