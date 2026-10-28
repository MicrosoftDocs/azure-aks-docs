---
title: Node Hardening (Preview) in Azure Kubernetes Service (AKS)
description: Learn how AKS Node Hardening changes kubelet resource reservations, eviction thresholds, and cgroup enforcement to improve node stability, and how to enable and customize it.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 10/07/2026
ms.author: slibbing
author: stl327
ms.subservice: aks-nodes
ai-usage: ai-assisted
# Customer intent: "As a cluster operator, I want to understand and enable Node Hardening on my AKS cluster, so that my nodes stay stable when workloads put them under resource pressure."
---

# Node Hardening (preview) in Azure Kubernetes Service (AKS)

Node Hardening is an opt-in feature for Linux node pools that protects node stability when workloads put nodes under CPU, memory, or disk pressure. When you enable Node Hardening on a cluster, AKS changes how each node reserves and enforces resources for Kubernetes components and host services, and how the kubelet evicts pods when resources run low.

This article explains what Node Hardening changes, compares the hardened defaults with the standard AKS defaults, and shows you how to enable, verify, customize, and disable the feature.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Benefits of Node Hardening

On busy or bursty nodes, workloads can consume resources that the kubelet, the container runtime, and host services need. When that happens, nodes can become unresponsive, report a `NotReady` status, or terminate pods abruptly. Node Hardening reduces these risks in the following ways:

- **Enforced reservations:** By default, AKS uses kube-reserved values only to calculate how much capacity the scheduler can allocate to pods. By using Node Hardening, the kubelet also enforces kube-reserved and system-reserved capacity through Linux control groups (cgroups). The kubelet and containerd run in a dedicated `kubereserved.slice` cgroup, so they keep their reserved CPU share and memory even when pods saturate the node.
- **Dedicated capacity for host services:** Node Hardening adds a system-reserved allocation for host operating system services, which run in `system.slice`.
- **More memory headroom:** The hard eviction threshold for available memory scales with node memory, so the kubelet evicts pods before the node runs critically low on memory.
- **Graceful eviction:** Soft eviction thresholds let the kubelet evict pods gracefully, with a termination grace period, when memory or disk space runs low. Hard eviction, which terminates pods immediately, then acts as a last resort.
- **Reservations that scale with pod density:** The kube-reserved memory calculation increases with the maximum number of pods per node, which accounts for the kubelet and containerd overhead of running more pods.

## What changes when you enable Node Hardening

The following tables compare the standard defaults for Linux nodes running Kubernetes 1.29 or later with the defaults that AKS applies when Node Hardening is enabled.

### Resource reservations

| Setting | Without Node Hardening | With Node Hardening |
| ------- | ---------------------- | ------------------- |
| Kube-reserved CPU | Based on the number of CPU cores. For more information, see [CPU reservations][cpu-reservations]. | Unchanged |
| Kube-reserved memory | `min(20 × maxPods + 50, 25% of node memory)` MiB | `min(35 × maxPods + max(250, 2% of node memory), 25% of node memory)` MiB |
| Kube-reserved process IDs (PIDs) | `1000` | Not reserved |
| System-reserved CPU | None | `100m` |
| System-reserved memory | None | 200 MiB, plus 100 MiB for each full 32 GiB of node memory, plus 100 MiB for clusters that use Azure CNI |
| System-reserved ephemeral storage | None | `1Gi` |

### Eviction thresholds

| Setting | Without Node Hardening | With Node Hardening |
| ------- | ---------------------- | ------------------- |
| Hard eviction: `memory.available` | `100Mi` | `250Mi` for nodes with 8 GiB of memory or less, `375Mi` for nodes with more than 8 GiB and less than 32 GiB, and `512Mi` for nodes with 32 GiB or more |
| Hard eviction: `nodefs.available` and `nodefs.inodesFree` | `10%` and `5%` | Unchanged |
| Hard eviction: `pid.available` | `2000` | Not set |
| Soft eviction: `memory.available` | None | `500Mi`, `750Mi`, or `1Gi`, using the same node memory tiers as hard eviction, with a 30-second grace period |
| Soft eviction: `nodefs.available` and `nodefs.inodesFree` | None | `12%` and `7%`, each with a 2-minute grace period |
| Maximum pod termination grace period during soft eviction | Not set | 60 seconds |

### Cgroup enforcement

| Setting | Without Node Hardening | With Node Hardening |
| ------- | ---------------------- | ------------------- |
| Enforced node allocatable | `pods` | `pods`, `kube-reserved`, and `system-reserved` |
| Kubelet and containerd cgroup | `system.slice`, without limits | `kubereserved.slice`, with memory limited to the kube-reserved memory and a CPU share proportional to the kube-reserved CPU |
| Host services cgroup | `system.slice`, without limits | `system.slice`, with memory limited to the system-reserved memory and a CPU share proportional to the system-reserved CPU |

Because Node Hardening reserves more capacity, nodes report less allocatable capacity for pods. For example, on a node with 4 vCPUs and 16 GiB of memory that uses Azure CNI, enabling Node Hardening reduces allocatable capacity as follows:

- With the default maximum of 250 pods per node, by about 570 MiB of memory, 100 millicores of CPU, and 1 GiB of ephemeral storage.
- With a maximum of 30 pods per node, by about 1.3 GiB of memory, 100 millicores of CPU, and 1 GiB of ephemeral storage.

Soft eviction thresholds don't reduce allocatable capacity. They only change when the kubelet starts to evict pods.

## Considerations

Keep the following considerations in mind before you enable Node Hardening:

- You enable Node Hardening at the cluster level, and it applies to all Linux node pools in the cluster. You can't enable it for individual node pools, and it doesn't affect Windows node pools.
- Nodes report less allocatable capacity, so pods that fit on a node before you enable Node Hardening might not fit afterward. Review your pod resource requests and node pool sizes.
- Host services in `system.slice` share a hard memory limit equal to the system-reserved memory. If you run your own agents on nodes as systemd services, such as security, monitoring, or log-forwarding agents, those agents count against this limit. Validate their memory usage and stability before you use Node Hardening in production.
- Values that you set in a node pool's custom kubelet configuration override the corresponding Node Hardening defaults. For more information, see [Customize Node Hardening settings](#customize-node-hardening-settings).
- If you disable Node Hardening later, existing node pools keep the hardened soft eviction settings, even after their nodes are reimaged. To remove these settings, you need to create new node pools. For more information, see [Disable Node Hardening](#disable-node-hardening).
- Default values might change while the feature is in preview. Start with a nonproduction cluster, and validate your workloads under representative node-pressure conditions.

## Prerequisites

- An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/).
- An AKS cluster with Linux node pools, or permissions to create one.
- The `aks-preview` Azure CLI extension and the `CustomNodeConfigPreview` feature flag, as described in the following sections.

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension by using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension by using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `CustomNodeConfigPreview` feature flag

1. Register the `CustomNodeConfigPreview` feature flag by using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "CustomNodeConfigPreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status by using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "CustomNodeConfigPreview"
    ```

1. When the status shows _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

## Enable Node Hardening

During preview, Node Hardening isn't enabled by default.

### Enable Node Hardening on a new cluster

Create a cluster with Node Hardening enabled by using the [`az aks create`][az-aks-create] command with the `--enable-node-hardening` parameter.

This command requires the `aks-preview` extension and the `CustomNodeConfigPreview` feature flag. For more information, see [Prerequisites](#prerequisites).

```azurecli-interactive
az aks create \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --enable-node-hardening \
    --generate-ssh-keys
```

To confirm the change, see [Verify Node Hardening settings](#verify-node-hardening-settings).

### Enable Node Hardening on an existing cluster

Enable Node Hardening on an existing cluster by using the [`az aks update`][az-aks-update] command with the `--enable-node-hardening` parameter.

This command requires the `aks-preview` extension and the `CustomNodeConfigPreview` feature flag. For more information, see [Prerequisites](#prerequisites).

```azurecli-interactive
az aks update \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --enable-node-hardening
```

To confirm the change, see [Verify Node Hardening settings](#verify-node-hardening-settings).

## Verify Node Hardening settings

1. Get the credentials for your cluster by using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
    ```

1. Review the effective kubelet reservation and eviction settings on a node by querying the kubelet configuration endpoint.

    ```bash
    kubectl get --raw "/api/v1/nodes/<node-name>/proxy/configz" | jq '.kubeletconfig | {kubeReserved, systemReserved, evictionHard, evictionSoft, evictionSoftGracePeriod, evictionMaxPodGracePeriod, enforceNodeAllocatable}'
    ```

    On a hardened node, `systemReserved` and `evictionSoft` contain values, and `enforceNodeAllocatable` includes `kube-reserved` and `system-reserved`.

1. Compare the node's capacity with its allocatable resources.

    ```bash
    kubectl get node <node-name> -o jsonpath='{.status.capacity}{"\n"}{.status.allocatable}{"\n"}'
    ```

    On a hardened node, allocatable CPU, memory, and ephemeral storage are lower than capacity. The difference equals the kube-reserved and system-reserved values in [Resource reservations](#resource-reservations), plus the hard eviction thresholds in [Eviction thresholds](#eviction-thresholds). For example, on a node with 4 vCPUs and 16 GiB of memory that uses Azure CNI, allocatable CPU is 240 millicores lower than capacity: 140 millicores of kube-reserved CPU and 100 millicores of system-reserved CPU.

## Customize Node Hardening settings

You can override the kube-reserved and eviction defaults for a Linux node pool by using a [custom kubelet configuration][custom-node-configuration]. These settings require the `CustomNodeConfigPreview` feature flag. You can use them whether or not Node Hardening is enabled on the cluster. AKS manages system-reserved values and cgroup enforcement, and you can't customize them.

Each setting overrides a row in the [Resource reservations](#resource-reservations) or [Eviction thresholds](#eviction-thresholds) tables. Kube-reserved rows correspond to the `kubeReserved` settings. Hard eviction rows correspond to the `hardEvictionThreshold` settings. Soft eviction rows correspond to the `softEvictionThreshold` and `softEvictionGracePeriod` settings. The maximum pod termination grace period corresponds to `evictionMaxPodGracePeriodInSeconds`.

You can configure the following settings:

| Setting | Overrides | Description |
| ------- | --------- | ----------- |
| `kubeReserved.cpuMillicores` | Kube-reserved CPU | CPU reserved for Kubernetes system daemons, in millicores. |
| `kubeReserved.memoryMB` | Kube-reserved memory | Memory reserved for Kubernetes system daemons, in MiB. |
| `hardEvictionThreshold.memoryAvailable` | Hard eviction: `memory.available` | Hard eviction threshold for available memory. |
| `hardEvictionThreshold.nodeFsAvailable` | Hard eviction: `nodefs.available` | Hard eviction threshold for available node filesystem space. |
| `hardEvictionThreshold.nodeFsInodesFree` | Hard eviction: `nodefs.inodesFree` | Hard eviction threshold for free node filesystem inodes. |
| `softEvictionThreshold.memoryAvailable` | Soft eviction: `memory.available` | Soft eviction threshold for available memory. |
| `softEvictionThreshold.nodeFsAvailable` | Soft eviction: `nodefs.available` | Soft eviction threshold for available node filesystem space. |
| `softEvictionThreshold.nodeFsInodesFree` | Soft eviction: `nodefs.inodesFree` | Soft eviction threshold for free node filesystem inodes. |
| `softEvictionGracePeriod.memoryAvailable` | Soft eviction: `memory.available` grace period | How long available memory must stay below its soft threshold before the kubelet evicts pods. |
| `softEvictionGracePeriod.nodeFsAvailable` | Soft eviction: `nodefs.available` grace period | How long available node filesystem space must stay below its soft threshold before the kubelet evicts pods. |
| `softEvictionGracePeriod.nodeFsInodesFree` | Soft eviction: `nodefs.inodesFree` grace period | How long free node filesystem inodes must stay below their soft threshold before the kubelet evicts pods. |
| `evictionMaxPodGracePeriodInSeconds` | Maximum pod termination grace period during soft eviction | Maximum number of seconds that the kubelet allows pods to terminate during a soft eviction. |

- For allowed values, minimums, and validation rules for each setting, see [Custom node configuration parameters for AKS][custom-node-configuration-reference].
- For each eviction signal, set both the soft eviction threshold and its matching grace period, and ensure each soft eviction threshold is greater than the hard eviction threshold for the same signal.

1. Create a kubelet configuration file, such as `nodehardening-kubelet.json`, with the settings that you want to customize. The following example sets every configurable value. It sets kube-reserved to 200 millicores of CPU and 1,024 MiB of memory. It sets hard eviction thresholds of `512Mi` of available memory, `10%` of available filesystem space, and `5%` of free inodes. It sets soft eviction thresholds of `1Gi`, `12%`, and `7%` with grace periods of 30 seconds, 2 minutes, and 2 minutes. It also sets a 60-second maximum pod termination grace period.

    ```json
    {
      "kubeReserved": {
        "cpuMillicores": 200,
        "memoryMB": 1024
      },
      "hardEvictionThreshold": {
        "memoryAvailable": "512Mi",
        "nodeFsAvailable": "10%",
        "nodeFsInodesFree": "5%"
      },
      "softEvictionThreshold": {
        "memoryAvailable": "1Gi",
        "nodeFsAvailable": "12%",
        "nodeFsInodesFree": "7%"
      },
      "softEvictionGracePeriod": {
        "memoryAvailable": "30s",
        "nodeFsAvailable": "2m",
        "nodeFsInodesFree": "2m"
      },
      "evictionMaxPodGracePeriodInSeconds": 60
    }
    ```

1. Create a Linux node pool that uses the configuration file by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--kubelet-config` parameter.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --kubelet-config ./nodehardening-kubelet.json
    ```

    You can also use the `--kubelet-config` parameter with the [`az aks create`][az-aks-create] command to apply the configuration to the cluster's initial node pool.

## Disable Node Hardening

Disable Node Hardening by using the [`az aks update`][az-aks-update] command with the `--disable-node-hardening` parameter.

This command requires the `aks-preview` extension and the `CustomNodeConfigPreview` feature flag. For more information, see [Prerequisites](#prerequisites).

```azurecli-interactive
az aks update \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --disable-node-hardening
```

Disabling Node Hardening turns off the cluster-level setting, but it doesn't immediately change existing nodes. Existing nodes keep all hardened settings until they're reimaged, for example, during a node image upgrade. After a node is reimaged, the following changes apply:

- **Reverted to the standard AKS defaults:** Kube-reserved and system-reserved resources, hard eviction thresholds, and cgroup enforcement. The node's allocatable capacity increases accordingly.
- **Retained:** The soft eviction thresholds, the soft eviction grace periods, and the maximum pod termination grace period during soft eviction.

You can set a custom kubelet configuration only when you create a cluster or node pool, so you can't remove the retained soft eviction settings from an existing node pool. To remove them, create a new node pool that explicitly unsets them, move your workloads to the new node pool, and then delete the old node pool.

1. Create a kubelet configuration file, such as `remove-soft-eviction.json`. The following example sets every soft eviction threshold and grace period to an empty string, which turns off soft eviction for that signal. It also sets the maximum pod termination grace period to `0`, which is the standard AKS default.

    ```json
    {
      "softEvictionThreshold": {
        "memoryAvailable": "",
        "nodeFsAvailable": "",
        "nodeFsInodesFree": ""
      },
      "softEvictionGracePeriod": {
        "memoryAvailable": "",
        "nodeFsAvailable": "",
        "nodeFsInodesFree": ""
      },
      "evictionMaxPodGracePeriodInSeconds": 0
    }
    ```

1. Create a Linux node pool that uses the configuration file by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--kubelet-config` parameter.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --kubelet-config ./remove-soft-eviction.json
    ```

1. Move your workloads to the new node pool, and then delete the old node pool. For more information, see [Resize node pools in AKS][resize-node-pool].

To confirm the settings on a node, see [Verify Node Hardening settings](#verify-node-hardening-settings). On nodes in the new node pool, `evictionSoft` is empty.

## Related content

- [Node resource reservations in AKS][node-resource-reservations]
- [Customize the node configuration for AKS node pools][custom-node-configuration]
- [Custom node configuration parameters for AKS][custom-node-configuration-reference]
- [Node-pressure eviction in Kubernetes](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)
- [Reserve compute resources for system daemons in Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/)

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[cpu-reservations]: node-resource-reservations.md#cpu-reservations
[custom-node-configuration]: custom-node-configuration.md
[custom-node-configuration-reference]: custom-node-configuration-reference.md
[node-resource-reservations]: node-resource-reservations.md
[resize-node-pool]: resize-node-pool.md
