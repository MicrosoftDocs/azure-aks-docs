---
title: Customize the Node Configuration for Azure Kubernetes Service (AKS) Node Pools
description: Learn how to customize the configuration on Azure Kubernetes Service (AKS) cluster nodes and node pools.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 08/06/2026
ms.author: davidsmatlak
author: davidsmatlak
ms.subservice: aks-nodes
ai-usage: ai-assisted
# Customer intent: "As a cloud engineer, I want to customize node configurations on my Kubernetes cluster, so that I can optimize performance and resource management for my specific workloads."
---

# Customize the node configuration for Azure Kubernetes Service (AKS) node pools

By customizing your node configuration, you can adjust operating system (OS) settings or kubelet parameters to match the needs of your workloads. When you create an AKS cluster or add a node pool to your cluster, you can customize a subset of commonly used OS and kubelet settings. To configure settings beyond this subset, [use a daemon set to customize your needed configurations without losing AKS support for your nodes](support-policies.md#shared-responsibility).

## Prerequisites

As the service adds support for new settings and kubelet parameters, it might require preview feature flag registration. If a preview flag is required, the [custom node configuration parameters reference][custom-node-configuration-reference] calls it out.

### Preview requirements for `kubeReserved` and `hardEvictionThreshold` kubelet settings

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

#### Install the `aks-preview` Azure CLI extension

1. To install the aks-preview extension, run the following command:

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Run the following command to update to the latest version of the extension:

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

Register the `CustomNodeConfigPreview` feature flag in your Azure subscription before you use the preview `kubeReserved` and `hardEvictionThreshold` kubelet settings.

#### Register the `CustomNodeConfigPreview` feature flag

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

## Create custom node configuration files for AKS node pools

To change the OS and kubelet configuration, create a new configuration file with the parameters and settings you want. If you don't specify a value for a parameter, the default value is used.

> [!NOTE]
> The following examples show common configuration settings. Modify the settings to meet your workload requirements. For the full list of supported custom configuration parameters, see [Custom node configuration parameters for AKS][custom-node-configuration-reference].

### Kubelet configuration

#### [Linux node pools](#tab/linux-node-pools)

Create a `linuxkubeletconfig.json` file with the following contents:

```json
{
 "cpuManagerPolicy": "static",
 "cpuCfsQuota": true,
 "cpuCfsQuotaPeriod": "200ms",
 "imageGcHighThreshold": 90,
 "imageGcLowThreshold": 70,
 "topologyManagerPolicy": "best-effort",
 "allowedUnsafeSysctls": [
  "kernel.msg*",
  "net.*"
],
 "failSwapOn": false
}
```

To use the Node Customization Preview kubelet settings on Linux node pools, add `kubeReserved` and `hardEvictionThreshold` to your kubelet configuration file. The following example reserves CPU and memory for Kubernetes system daemons and configures kubelet hard eviction thresholds:

```json
{
  "cpuManagerPolicy": "static",
  "kubeReserved": {
    "cpuMillicores": 200,
    "memoryMB": 1024
  },
  "hardEvictionThreshold": {
    "memoryAvailable": "20%",
    "nodeFsAvailable": "10%",
    "nodeFsInodesFree": "5%"
  }
}
```

Use `kubeReserved` and `hardEvictionThreshold` only on Linux node pools. Both settings require the `CustomNodeConfigPreview` feature flag.

#### [Windows node pools](#tab/windows-node-pools)

> [!NOTE]
> Windows kubelet custom configuration only supports the parameters `imageGcHighThreshold`, `imageGcLowThreshold`, `containerLogMaxSizeMB`, and `containerLogMaxFiles`.

Create a `windowskubeletconfig.json` file with the following contents:

```json
{
 "imageGcHighThreshold": 90,
 "imageGcLowThreshold": 70,
 "containerLogMaxSizeMB": 20,
 "containerLogMaxFiles": 6
}
```

---

### OS configuration

#### [Linux node pools](#tab/linux-node-pools)

Create a `linuxosconfig.json` file with the following contents:

```json
{
 "transparentHugePageEnabled": "madvise",
 "transparentHugePageDefrag": "defer+madvise",
 "swapFileSizeMB": 1500,
 "sysctls": {
  "netCoreSomaxconn": 163849,
  "netIpv4TcpTwReuse": true,
  "netIpv4IpLocalPortRange": "32000 60000"
 }
}
```

#### [Windows node pools](#tab/windows-node-pools)

Currently unsupported.

---

## Create an AKS cluster using custom configuration files

> [!NOTE]
> Keep the following information in mind when using custom configuration files when creating a new AKS cluster:
>
> - If you specify a configuration when creating a cluster, the configuration applies only to the nodes in the initial node pool. The cluster retains default values for any settings not configured in the JSON file.
> - `CustomLinuxOsConfig` isn't supported for the Windows OS type.
> - The preview `kubeReserved` and `hardEvictionThreshold` kubelet settings are supported only for Linux node pools and require the `CustomNodeConfigPreview` feature flag. Complete the registration steps in [Preview requirements for `kubeReserved` and `hardEvictionThreshold` kubelet settings](#preview-requirements-for-kubereserved-and-hardevictionthreshold-kubelet-settings) before you create the cluster or node pool.

Create a new cluster using custom configuration files by running the [`az aks create`][az-aks-create] command and specifying your configuration files for the `--kubelet-config` and `--linux-os-config` parameters. The following example command creates a new cluster with the custom `./linuxkubeletconfig.json` and `./linuxosconfig.json` files:

```azurecli-interactive
az aks create --name <cluster-name> --resource-group <resource-group-name> --kubelet-config ./linuxkubeletconfig.json --linux-os-config ./linuxosconfig.json
```

## Add a node pool by using custom configuration files

> [!NOTE]
> Keep the following information in mind when using custom configuration files to add a new node pool to an existing AKS cluster:
>
> - When you add a Linux node pool to an existing cluster, you can specify the kubelet configuration, OS configuration, or both. When you add a Windows node pool to an existing cluster, you can only specify the kubelet configuration. If you specify a configuration when adding a node pool, the configuration applies only to the nodes in the new node pool. The node pool retains default values for any settings not configured in the JSON file.
> - `CustomKubeletConfig` is supported for Linux and Windows node pools.
> - The preview `kubeReserved` and `hardEvictionThreshold` kubelet settings are supported only for Linux node pools and require the `CustomNodeConfigPreview` feature flag. Complete the registration steps in [Preview requirements for `kubeReserved` and `hardEvictionThreshold` kubelet settings](#preview-requirements-for-kubereserved-and-hardevictionthreshold-kubelet-settings) before you create the cluster or node pool.

### [Linux node pools](#tab/linux-node-pools)

Create a new Linux node pool by using the [`az aks nodepool add`][az-aks-create] command and specifying your configuration files for the `--kubelet-config` and `--linux-os-config` parameters. The following example command creates a new Linux node pool with the custom `./linuxkubeletconfig.json` file:

```azurecli-interactive
az aks nodepool add --name <node-pool-name> --cluster-name <cluster-name> --resource-group <resource-group-name> --kubelet-config ./linuxkubeletconfig.json
```

### [Windows node pools](#tab/windows-node-pools)

Create a new Windows node pool by using the [`az aks nodepool add`][az-aks-create] command and specifying your configuration file for the `--kubelet-config` parameter. The following example command creates a new Windows node pool with the custom `./windowskubeletconfig.json` file:

```azurecli-interactive
az aks nodepool add --name <node-pool-name> --cluster-name <cluster-name> --resource-group <resource-group-name> --os-type Windows --kubelet-config ./windowskubeletconfig.json
```

---

## Confirm settings were applied

After you apply custom node configuration, you can confirm the settings were applied to the nodes by [connecting to the host][node-access] and verifying `sysctl` or configuration changes were made on the filesystem.

## Review supported custom configuration parameters

For the full list of supported kubelet and Linux OS configuration parameters, allowed values, defaults, and descriptions, see [Custom node configuration parameters for AKS][custom-node-configuration-reference].

## Considerations for custom node configurations

Keep the following considerations in mind when customizing your node configuration:

- Node image upgrades reapply custom node configurations.
- Scale-out operations preserve custom node configurations.
- AKS doesn't perform pre-flight validation for every custom node configuration parameter or value. Ensure that the custom node configuration parameters and values you specify are supported and valid to avoid potential issues with your cluster nodes.
- The preview `kubeReserved` and `hardEvictionThreshold` settings are available only on Linux node pools.
- If you configure `kubeReserved`, the values must be positive and can't exceed the CPU or memory capacity available on the target node pool.
- If you configure `hardEvictionThreshold`, use only the supported units: `Ki`, `Mi`, `Gi`, or `%` for `memoryAvailable` and `nodeFsAvailable`, and a raw number or `%` for `nodeFsInodesFree`.
- Default values for custom node configuration parameters often change with new operating system versions. When applying custom node configurations, review the default values for the parameters you're configuring to ensure that your custom settings are appropriate for the OS version of your cluster nodes.
- Limit the number of people who have permissions to modify the custom node configuration to prevent unintended consequences on cluster stability and performance. Consider using [Microsoft Entra ID authorization for the Kubernetes API](./entra-id-authorization.md) to restrict access to cluster configuration settings.
- Separate node pools with custom configurations from those without custom configurations to prevent unintended consequences on workloads that might be sensitive to certain configuration changes. For example, if you have a critical workload that requires specific kubelet settings, consider isolating that workload to a dedicated node pool with the necessary custom kubelet configuration.

## Related content

- Learn [how to configure your AKS cluster](./concepts-clusters-workloads.md).
- Learn how to [upgrade the node images](node-image-upgrade.md) in your cluster.
- See [Upgrade an Azure Kubernetes Service (AKS) cluster](upgrade-cluster.md) to learn how to upgrade your cluster to the latest version of Kubernetes.
- See the list of [Frequently asked questions about AKS](faq.yml) to find answers to some common AKS questions.

<!-- LINKS - internal -->
[node-access]: node-access.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[custom-node-configuration-reference]: custom-node-configuration-reference.md
