---
title: Enable autoscaling managed add-on on your Azure Kubernetes Service (AKS) cluster (Preview)
description: This article provides an overview of the add-on autoscaling feature in Azure Kubernetes Service (AKS).
ms.author: schaffererin
author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 01/28/2025
---

# Enable managed add-on autoscaling on your Azure Kubernetes Service (AKS) cluster (Preview)

This article provides an overview of managed add-on autoscaling in Azure Kubernetes Service (AKS). With add-on autoscaling, you can easily manage workloads requiring CPU and memory settings different than the default values by overriding the resource configuration. This feature ensures that resources aren't overly allocated to add-on pods, increasing cost savings and cluster efficiency.

## Overview

Enabling the add-on autoscaling feature in your AKS cluster installs the Vertical Pod Autoscaler (VPA) add-on and VPA custom resources for AKS managed add-ons that support this capability.

This feature allows you to override the resource CPU and memory requests and limits in Deployments and DaemonSets, the maximum and minimum allowed CPU and memory, and the VPA update mode within VPA custom resources. For more information, see [Override the resource configuration for AKS managed add-ons](./override-resource-configuration.md).

### Supported AKS managed add-ons

The following AKS managed add-ons support the add-on autoscaling feature:

| Managed add-on | Enablement behavior | VPA custom resource name | Command to check VPA custom resource |
| -------------- | ------------------- | ------------------------ | ------------------------------------ |
| [CoreDNS](./coredns-custom.md) | Enabled by default on new AKS clusters. | `coredns` | `kubectl get vpa coredns --namespace kube-system` |
| [Workload identity](./workload-identity-deploy-cluster.md)| Optional add-on that requires manual enablement. | `azure-wi-webhook-controller-manager` | `kubectl get vpa azure-wi-webhook-controller-manager --namespace kube-system` |
| [Image Cleaner](./image-cleaner.md) | Optional add-on that requires manual enablement. | `eraser-controller-manager` | `kubectl get vpa eraser-controller-manager --namespace kube-system` |
| [Image Integrity](./image-integrity.md) | Optional add-on that requires manual enablement. | `ratify` | `kubectl get vpa ratify --namespace gatekeeper-system` |
| [Network Observability (Retina)](./container-network-observability-how-to.md) | Optional add-on that requires manual enablement. | `retina-agent` and `retina-operator` | `kubectl get vpa retina-agent --namespace kube-system` and `kubectl get vpa retina-operator --namespace kube-system` |

### Limitations

* The two modes currently supported in the VPA include:
  * *Off*: The VPA provides resource recommendation data but doesn't apply it to the target pod.
  * *Initial*: The VPA applies the resource recommendations to the target pod when pods restart.
* AKS doesn't retain the overridden CPU/memory requests/limits, VPA minimum/maximum allowed CPU/memory, or VPA update mode values. If you delete the Deployment, DaemonSet, or VPA custom resource, the changes revert back to the AKS managed add-on's initial configuration.

> [!NOTE]
> When enabling managed add-on autoscaling, consider the following information:
>
> * The add-on autoscaling feature enables the VPA add-on to autoscale the AKS managed add-ons that support this capability. It doesn't work with the VPA controller or with user-created VPA custom resources.
> * If the cluster doesn't enable the cluster autoscaler to adjust the number of nodes dynamically, it's possible that pod will be unable to be scheduled after VPA adjusts the CPU/memory requests/limits due to lack of resources on the available nodes for the pods.

## Prerequisites

* An AKS cluster running Kubernetes version 1.25 or later.
* The Azure CLI version 2.60.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) and [register the add-on autoscaling preview feature](#register-the-add-on-autoscaling-preview-feature).

[!INCLUDE [preview features callout]((~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md))]

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the `az extension add` command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the `az extension update` command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the add-on autoscaling preview feature

1. Register the add-on autoscaling preview feature using the `az feature register` command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKS-AddonAutoscalingPreview"
    ```

    It takes a few minutes for the status to show as *Registered*.

1. Verify the registration status using the `az feature show` command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AKS-AddonAutoscalingPreview"
    ```

1. When the status shows as *Registered*, refresh the registration of the Microsoft.ContainerService provider using the `az provider register` command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Enable add-on autoscaling on an AKS cluster

When enabling the add-on, the AKS cluster automatically installs the VPA add-on. The [AKS managed add-ons that support the add-on autoscaling feature](#supported-aks-managed-add-ons) have different enablement behavior.

### Enable add-on autoscaling on a new cluster

* Enable add-on autoscaling on a new AKS cluster using the [`az aks create`][az-aks-create] command with the `--enable-addon-autoscaling` flag.

    ```azurecli-interactive
    az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --enable-addon-autoscaling
    ```

### Enable add-on autoscaling on an existing cluster

* Enable add-on autoscaling on an existing AKS cluster using the [`az aks update`][az-aks-update] command with the `--enable-addon-autoscaling` flag.

    ```azurecli-interactive
    az aks update --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --enable-addon-autoscaling
    ```

## Disable add-on autoscaling on an AKS cluster

* Disable add-on autoscaling on an AKS cluster using the [`az aks update`][az-aks-update] command with the `--disable-addon-autoscaling` flag.

    ```azurecli-interactive
    az aks update --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --disable-addon-autoscaling
    ```

> [!NOTE]
> Disabling the add-on autoscaling feature doesn't disable the VPA add-on by default. To disable VPA, see [Disable VPA on an AKS cluster](./use-vertical-pod-autoscaler.md#disable-the-vertical-pod-autoscaler-on-an-existing-cluster).

## Apply the VPA recommended values

> [!NOTE]
> Before applying the recommended values, [make sure the VPA update mode is set to *Initial* in the VPA custom resource](./override-resource-configuration.md#override-resource-update-mode). With *Initial* mode, the VPA applies the recommended CPU/memory requests/limits when the pod is created or updated.

1. Check the pod status and CPU/memory utilization to verify that the pod is running as expected.

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

2. Get the VPA recommended value using the `kubectl get vpa` command.

    ```bash
    kubectl get vpa coredns --namespace kube-system
    ```

    The following output shows an example of the VPA recommended value for a CoreDNS pod:

    ```output
    NAME      MODE      CPU   MEM        PROVIDED   AGE
    coredns   Initial   11m   23574998   True       44m
    ```

3. If you want to use the values recommended by VPA, manually delete the pod using the `kubectl delete pod` command to restart the pod with the VPA recommended values.

    ```bash
    kubectl delete pod <coredns-pod-name> --namespace kube-system
    ```

4. After the pod restarts, verify the pod status and CPU/memory updates using the `kubectl get pod` command.

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

## Override default resource configuration

With the add-on autoscaling feature enabled on your cluster, you can override the default CPU/memory settings for the managed add-on resources as well as the default VPA configuration for supported AKS managed add-ons. For more information, see [Override the resource configuration for AKS managed add-ons](./override-resource-configuration.md).

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

1. For each of the three VPA pods, check the logs for any errors using the `kubectl logs` command. Make sure to replace `<pod-name>` with the names of the VPA pods.

    ```bash
    kubectl logs <pod-name> --namespace kube-system | grep -e '^E[0-9]\{4\}'
    ```

1. Confirm the custom resource definition (CRD) was creating using the `kubectl get` command.

    ```bash
    kubectl get customresourcedefinition | grep verticalpodautoscalers
    ```

### Check pod status and CPU/memory utilization

1. Check the pod's status using the `kubectl get pod` command.

    ```bash
    kubectl get pod <pod-name> --namespace=kube-system
    ```

1. If the pod has a status of `Pending`, check the pod's status property to determine the reason the pod isn't running.

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

1. If the output shows that the pod is `Pending` due to insufficient CPU or memory, consider the following actions:

    * Add more nodes so that pods can be scheduled in nodes with lower resource usage.
    * Disable VPA for the target add-on pod by changing the update mode to *Off*, and then [manually update the requests/limits](./override-resource-configuration.md) to the available resource values on the node. Be cautious when setting resource limits to extremely low values, as this may result in the pod encountering OOM kills or CPU throttling if it attempts to use more resources than are available on the node.

<!-- LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-
