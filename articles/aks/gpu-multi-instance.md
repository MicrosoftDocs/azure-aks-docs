---
title: Create a single strategy multi-instance GPU node pool in Azure Kubernetes Service (AKS)
description: Learn how to create a multi-instance GPU node pool in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 11/10/2026
ms.author: sachidesai
author: sdesai345
ms.subservice: aks-nodes
# Customer intent: "As a cloud engineer, I want to create a multi-instance GPU node pool with single strategy in Azure Kubernetes Service, so that I can efficiently utilize GPU resources for parallel processing in my applications."
---

# Create a single strategy multi-instance GPU node pool in Azure Kubernetes Service (AKS)

Certain NVIDIA GPUs can be divided into up to seven independent instances. Each instance has its own Streaming Multiprocessor (SM), which executes instructions in parallel, and GPU memory. For more information about GPU partitioning, see [NVIDIA MIG](https://www.nvidia.com/en-us/technologies/multi-instance-gpu/).

Use single strategy multi-instance GPU (MIG) in your AKS cluster to run workloads on uniformly sized GPU partitions. Each workload requests `nvidia.com/gpu`, where one unit represents one partition rather than an entire physical GPU. AKS installs and configures the NVIDIA driver and device plugin for this path. For strategy selection and resource naming, see [Multi-instance GPU strategies in AKS](./multi-instance-gpu-overview.md). To create different-sized partitions, see [Configure mixed MIG strategy](./mixed-gpu-multi-instance.md).

This article walks you through how to set single strategy with a MIG node pool by using a compatible VM size in an Azure Kubernetes Service (AKS) cluster.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Limitations

- Node pools with `AzureContainerLinux` and `Windows` OS SKUs aren't currently supported with this feature.
- You can't change the profile configuration after MIG node pool creation. Create a replacement pool to change the layout or stop using MIG. Don't try to disable MIG by updating the strategy to `None`.

## Before you begin

- An Azure subscription. If you don't have one, create an [Azure free account](https://azure.microsoft.com/free/).
- Install Azure CLI version `2.85.0` or later and `aks-preview` version `22.0.0b15` or later. Run `az --version` to check your Azure CLI version.
- A [supported MIG-capable GPU VM size](./multi-instance-gpu-overview.md#supported-gpu-vm-sizes) available in your selected AKS region. Ensure that you have enough regional and GPU-family vCPU quota for the VM size and node count you plan to deploy.
- Ensure any existing self-managed NVIDIA device plugin or GPU operator doesn't also manage the new MIG node pool's nodes.

## Choose a uniform GPU profile

Specify exactly one profile for `Single` so that AKS can create the uniform partition layout. The following table lists the profiles for the NVIDIA A100 80 GB GPU. Counts are per physical GPU, not per node. `Standard_NC24ads_A100_v4` has one A100 80 GB GPU, so `MIG3g` gives two partitions on that VM size.

| Profile argument | Partition | Compute fraction | Memory fraction | Partitions per GPU |
| --- | --- | --- | --- | --- |
| **`MIG1g`** | 1g.10gb | 1/7 | 1/8 | 7 |
| **`MIG2g`** | 2g.20gb | 2/7 | 2/8 | 3 |
| **`MIG3g`** | 3g.40gb | 3/7 | 4/8 | 2 |
| **`MIG4g`** | 4g.40gb | 4/7 | 4/8 | 1 |
| **`MIG7g`** | 7g.80gb | 7/7 | 8/8 | 1 |

GPU memory per profile varies by NVIDIA GPU model. Don't apply this table's memory sizes or node counts to a different SKU without confirming its GPU configuration.

## Set environment variables and prepare your Azure subscription

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="<my-resource-group>"
export CLUSTER_NAME="<my-cluster-name>"
export SINGLE_POOL="migsingle"
```

Select the Azure subscription:

```azurecli
az account set --subscription "$SUBSCRIPTION_ID"
```

Connect to your AKS cluster:

```azurecli
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

### Register the preview features

Install or update the required extension:

```azurecli
az extension add --name aks-preview --upgrade --yes
```

Register the `ManagedGPUExperiencePreview` feature:

```azurecli
az feature register \
  --namespace Microsoft.ContainerService \
  --name ManagedGPUExperiencePreview
```

Register the `MixedMIGStrategyPreview` feature:

```azurecli
az feature register \
  --namespace Microsoft.ContainerService \
  --name MixedMIGStrategyPreview
```

Check each registration:

```azurecli
az feature show \
  --namespace Microsoft.ContainerService \
  --name ManagedGPUExperiencePreview \
  --query properties.state --output tsv
```

```azurecli
az feature show \
  --namespace Microsoft.ContainerService \
  --name MixedMIGStrategyPreview \
  --query properties.state --output tsv
```

After both return `Registered`, refresh the provider registration:

```azurecli
az provider register --namespace Microsoft.ContainerService
```

## Enable single strategy MIG on a new node pool

### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-gpu-node-pool)

To use the default OS SKU, create the node pool without specifying an OS SKU. The node pool is configured for the default operating system based on the Kubernetes version of the cluster. Create the uniform pool with `--enable-managed-gpu=true` and exactly one MIG profile:

```azurecli
az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name "$SINGLE_POOL" \
  --node-vm-size Standard_NC24ads_A100_v4 \
  --enable-managed-gpu=true \
  --gpu-mig-strategy Single \
  --gpu-mig-profiles MIG3g \
  --node-count 1
```

### [Azure Linux node pool](#tab/add-azure-linux-gpu-node-pool)

To use Azure Linux, specify the OS SKU by setting `os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default. Create the uniform pool with `--enable-managed-gpu=true` and exactly one MIG profile:

```azurecli
az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name "$SINGLE_POOL" \
  --node-vm-size Standard_NC24ads_A100_v4 \
  --os-sku AzureLinux \
  --enable-managed-gpu=true \
  --gpu-mig-strategy Single \
  --gpu-mig-profiles MIG3g \
  --node-count 1
```

---

## Verify configuration and GPU partition capacity

Check the managed GPU settings, profile list, and AKS node image:

```azurecli
az aks nodepool show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name "$SINGLE_POOL" \
  --query "{state:provisioningState,image:nodeImageVersion,gpu:gpuProfile.nvidia}" \
  --output json
```

In the output, check the following values. The GPU values appear under the `gpu` key.

| Output field | Expected value |
| --- | --- |
| `state` | `Succeeded` |
| `gpu.managementMode` | `Managed` |
| `gpu.driverMode` | `DevicePlugin` |
| `gpu.migStrategy` | `Single` |
| `gpu.migProfiles` | Only the profile you specified (`MIG3g` in this example) |
| `image` | A node image VHD version of `202609.01.0` or later, which is required for `--gpu-mig-profiles` |

Wait for the pool's nodes to become **Ready**.

```bash
kubectl wait --for=condition=Ready node \
  -l agentpool="$SINGLE_POOL" --timeout=600s
```

Check all nodes in the node pool:

```bash
kubectl describe nodes -l agentpool="$SINGLE_POOL"
```

For one `Standard_NC24ads_A100_v4` node with the `MIG3g` profile (one A100 80 GB GPU, which gives two partitions), the `Allocatable` section should include:

```output
Allocatable:
  nvidia.com/gpu:  2
```

Each unit has a capacity of one `3g.40gb` MIG partition.

## Run a workload on one MIG partition

Create `single-strategy-example.yaml` with the following manifest. Update the selector if you changed the node pool name.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nvidia-single
spec:
  restartPolicy: Never
  nodeSelector:
    agentpool: migsingle
  containers:
    - name: gpu-test
      image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: "1"
```

The selector matters because a full-GPU pool can also advertise `nvidia.com/gpu`. Kubernetes treats an omitted request as equal to the extended resource limit. If you set both, use equal whole-number values.

Deploy the pod:

```bash
kubectl apply -f single-strategy-example.yaml
```

Wait for successful completion:

```bash
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded \
  pod/nvidia-single --timeout=300s
```

Read its device information:

```bash
kubectl logs nvidia-single
```

Confirm that `nvidia-smi` runs without errors and reports an assigned MIG device. For an explicit device-list check, change the sample command to `["nvidia-smi", "-L"]`, delete the completed pod, and apply the manifest again. Repeat the completion wait and log check. With `Standard_NC24ads_A100_v4` and the `MIG3g` profile, the logs should list one assigned `3g.40gb` MIG device.

## Understand validation and existing feature compatibility

### Compare ways to configure single strategy MIG

The `--gpu-instance-profile` feature remains available for configuration of your own NVIDIA GPU device plugin. The following options separate GPU layout configuration from device plugin ownership.

| Configuration path | Azure CLI settings at pool creation | Device plugin strategy and owner | API representation |
| --- | --- | --- | --- |
| **Existing profile with a self-configured plugin** | `--gpu-instance-profile <profile>` without enabling the managed GPU experience. | You install and configure the self-managed NVIDIA device plugin with `migStrategy=single`. | `gpuInstanceProfile` specifies the uniform layout. The self-managed device plugin's `migStrategy` setting isn't stored as a new AKS profile-list setting. You remain responsible for the self-managed device plugin lifecycle. |
| **Existing profile with a managed device plugin** | `--enable-managed-gpu=true --gpu-instance-profile <profile>`. | AKS manages the plugin for the uniform single-strategy path and no separate plugin changes are required. | The `--gpu-instance-profile` field remains present. The API doesn't synthesize `migProfiles` or `migStrategy` when only the `--gpu-instance-profile` is supplied. |
| **Profile list with a managed plugin** | `--enable-managed-gpu=true --gpu-mig-strategy Single --gpu-mig-profiles <profile>`. Supply exactly one profile. | AKS configures the managed NVIDIA device plugin plugin for `Single`; no manual configuration is required. | `gpuProfile.nvidia.migStrategy` and `gpuProfile.nvidia.migProfiles` explicitly describe the configuration. |

All three single-strategy paths expose partitions as `nvidia.com/gpu` when configured on an NVIDIA GPU node pool. The resource name alone doesn't identify the partition size or whether AKS manages the plugin.

### Validate the MIG profiles configuration

* Supply exactly one profile value to `--gpu-mig-profiles` for `Single`, not repeated entries to specify a partition count.
* Don't also supply `--gpu-instance-profile` flag. You can't combine `--gpu-instance-profile` and `--gpu-mig-profiles` on the same MIG node pool.

The `--gpu-instance-profile` flag remains supported for the single strategy, and AKS doesn't automatically convert it to `--gpu-mig-profiles`. To verify a new node pool created with `--gpu-mig-strategy` and `--gpu-mig-profiles`, run `az aks nodepool show` and check `gpuProfile.nvidia.migStrategy` and `gpuProfile.nvidia.migProfiles`.

## Migrate to use the managed MIG profiles

1. Inventory the current pool's VM size, `gpuInstanceProfile`, node image, and advertised partition capacity. Record workload selectors, affinity, taints, tolerations, and GPU requests. Check whether the existing NVIDIA device plugin or GPU operator serves other node pools.

1. Ensure that your self-managed NVIDIA device plugin and any GPU operator don't reconcile the replacement MIG pool's nodes. Adjust their node targeting by using the supported configuration for your installation.

1. Create a replacement MIG node pool with a distinct name. For example, to preserve a `MIG3g` layout on `Standard_NC24ads_A100_v4`, use the following command. Substitute the supported SKU and single profile that matches your migration plan. Don't pass `--gpu-instance-profile`.

   ```azurecli
   az aks nodepool add \
     --resource-group "$RESOURCE_GROUP" \
     --cluster-name "$CLUSTER_NAME" \
     --name migreplacement \
     --node-vm-size Standard_NC24ads_A100_v4 \
     --enable-managed-gpu=true \
     --gpu-mig-strategy Single \
     --gpu-mig-profiles MIG3g \
     --node-count 1
   ```

1. Run the configuration, readiness, capacity, and workload checks in this article against `migreplacement`. Update the sample selector to `agentpool: migreplacement`. Confirm the expected partition size and device access before moving application workloads.

1. Move workloads gradually by updating pool selectors or affinity and any required tolerations. Single-strategy workloads continue to request `nvidia.com/gpu`. Verify application behavior, throughput, latency, and memory usage on the replacement pool.

1. After verifying the replacement, drain or retire workloads on the old node pool and delete it. Keep the old pool available until your migration validation is complete when capacity permits. Remove the self-managed NVIDIA device plugin installation only after confirming that no remaining pools need it.

## Troubleshoot and remove the node pool

### Troubleshoot scheduling and partition advertisement

A pod that requests more `nvidia.com/gpu` resources than the eligible nodes can provide remains pending with an insufficient-resource scheduling event. Inspect its status and events:

```bash
kubectl describe pod nvidia-single
```

If nodes don't advertise partitions, inspect node conditions, managed settings, and the selected image and profile. Don't install a second plugin or patch AKS-managed components as a workaround.

The following errors can occur when you create the node pool:

| Error code | Cause | Resolution |
| --- | --- | --- |
| `MIGNotSupportedForVMSize` | The VM size doesn't support MIG. | Use a supported MIG-capable GPU VM size. |
| `InvalidOrNoneMIGProfile` | The profile is invalid, or you specified `None`. | Specify exactly one valid MIG profile for the VM size. |
| `MIGProfilesNodeImageNotSupported` | The AKS node image is older than the minimum supported version. | Use a node image version of `202609.01.0` or later. |

Azure CLI might show `BadRequest` as the top-level code, so also read the validation message.

### Delete the sample pod and MIG node pool

Delete the sample pod:

```bash
kubectl delete pod nvidia-single --ignore-not-found=true
```

Before deleting a node pool that runs other workloads, create replacement capacity, migrate the workloads, and verify application health. Then remove the node pool:

```azurecli
az aks nodepool delete \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name "$SINGLE_POOL"
```

Verify that the MIG node pool is removed:

```azurecli
az aks nodepool list \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --query "[?name=='$SINGLE_POOL'].name" --output json
```

The output should be `[]`. Confirm that no Kubernetes nodes remain for the pool:

```bash
kubectl get nodes -l agentpool="$SINGLE_POOL"
```

## Next steps

- [Compare single and mixed MIG partitioning strategies](./multi-instance-gpu-overview.md) in AKS.
- [Configure mixed MIG strategy (preview)](./mixed-gpu-multi-instance.md).
- Learn more about [managed GPU nodes](./aks-managed-gpu-nodes.md).