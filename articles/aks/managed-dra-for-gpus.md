---
title: Use dynamic resource allocation for NVIDIA GPU nodes in Azure Kubernetes Service (AKS)
description: Use Kubernetes dynamic resource allocation in AKS to express GPU requirements, schedule workloads with resource claims, and verify GPU access.
author: sdesai345
ms.author: sachidesai
ms.date: 11/04/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
---

# Use dynamic resource allocation for NVIDIA GPUs in Azure Kubernetes Service (AKS) (preview)

[Dynamic resource allocation (DRA)](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/) is a Kubernetes standard for requesting devices through resource claims. Instead of requesting only a GPU count through an extended resource limit such as `nvidia.com/gpu`, teams can express device requirements and let Kubernetes consider those requirements alongside workload placement and available devices. Azure Kubernetes Service (AKS) provides managed GPU support for using DRA on NVIDIA GPU node pools.

In this article, you add a [managed GPU node pool](./aks-managed-gpu-nodes.md) that uses DRA to an existing AKS cluster, deploy a workload that claims a single GPU, and verify the allocation and GPU access.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Overview

DRA separates an application's device requirements from the selection of a particular device. A `DeviceClass` defines which devices match a class, and a namespace-scoped `ResourceClaim` requests devices from that class. A pod references the claim and identifies which containers need access. Kubernetes coordinates device allocation with scheduling so that the selected node can satisfy the claim and the pod's other placement constraints.

### When to use DRA

| Use case | Benefit for your team |
| --- | --- |
| Provide consistent GPU requests across application teams | Platform teams can define reusable device classes, while application teams reference those classes through standard Kubernetes claims rather than selecting individual GPU machines. |
| Schedule workloads with device requirements beyond a count | Classes and claim selectors can match supported device attributes. Kubernetes can consider those requirements together with node selectors, taints, and other scheduling constraints. Use only attributes advertised and supported by your GPU configuration. |
| Run replicated inference services or parallel GPU jobs | A `ResourceClaimTemplate` can provide an independent claim for each pod, so teams can declare device requirements in the workload's pod template. |
| Diagnose GPU scheduling and allocation | Teams can inspect claims, allocations, and pod events through Kubernetes APIs to distinguish unavailable devices from workload placement constraints. |

## Limitations

- This feature isn't currently supported with AKS node auto provisioning (NAP) or cluster autoscaler.
- `AzureContainerLinux` isn't a supported OS SKU with managed DRA for GPU nodes.
- You must explicitly enable managed GPU with `--enable-managed-gpu=true` when selecting DRA. AKS doesn't support selecting DRA without managed GPU or with managed GPU disabled.
- The NVIDIA DRA driver and Kubernetes device plugin shouldn't manage the same GPU node. Separate `DRA` and `DevicePlugin` node pools can coexist in an AKS cluster when their components and workloads remain isolated to compatible nodes.
- Omitting `--gpu-driver-mode` on a managed GPU node pool selects `DevicePlugin` by default. You must update existing workloads that request `nvidia.com/gpu` to use resource claims before moving to a DRA-compatible node pool.

## Before you begin

- An existing AKS cluster with minimum Kubernetes version `1.35` or later.
- Azure CLI and `aks-preview` CLI extension installed with minimum version `22.0.0b6`.
- Ensure your Azure subscription has GPU quota and your selected region has capacity for an NVIDIA GPU VM size.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing](https://azure.microsoft.com/pricing/) tool and [region availability](https://azure.microsoft.com/global-infrastructure/services/).


## Set environment variables and prepare your Azure subscription

Replace each placeholder with your own value. Set `GPU_VM_SIZE` to an NVIDIA GPU VM size that's available in your region, for example `Standard_NC24ads_A100_v4`. The `gpu-dra-example` namespace is the one this article uses in later steps.

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="<my-resource-group>"
export CLUSTER_NAME="<my-cluster-name>"
export GPU_VM_SIZE="<supported-gpu-vm-size>"
export GPU_NAMESPACE="gpu-dra-example"
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

### Register the `ManagedGPUExperiencePreview` feature

Install or update the `aks-preview` extension:

```azurecli
az extension add --name aks-preview --upgrade --yes
az version
```

Verify that the extension version is `22.0.0b6` or later.

Register the `ManagedGPUExperiencePreview` feature flag:

```azurecli
az feature register \
    --namespace Microsoft.ContainerService \
    --name ManagedGPUExperiencePreview
```

Feature registration can take a few minutes. Repeat the check until the output is `Registered`:

```azurecli
az feature show \
    --namespace Microsoft.ContainerService \
    --name ManagedGPUExperiencePreview \
    --query properties.state --output tsv
```

After registration finishes, refresh the resource provider registration:

```azurecli
az provider register --namespace Microsoft.ContainerService
```

## Connect to your AKS cluster

Check the AKS cluster and existing node pool versions, and get the cluster credentials:

```azurecli
az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --query '{name:name,location:location,kubernetesVersion:kubernetesVersion}' \
  --output table

az aks nodepool list \
    --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --query '[].{name:name,kubernetesVersion:orchestratorVersion}' \
  --output table

az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME"
```

Confirm that your AKS cluster exposes the stable DRA APIs:

```bash
kubectl cluster-info
kubectl api-resources --api-group=resource.k8s.io --output wide
kubectl explain resourceclaim.spec.devices.requests.exactly \
    --api-version=resource.k8s.io/v1
```

The resource listing should include `DeviceClass`, `ResourceClaim`, and `ResourceSlice`.

## Add a managed GPU node pool with DRA

### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-gpu-node-pool)

To use the default OS SKU, create the node pool without specifying an OS SKU. The node pool is configured for the default operating system based on the Kubernetes version of the cluster. Create the uniform pool with `--enable-managed-gpu=true` and driver mode set to `DRA`:

```azurecli
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gpunp \
    --node-vm-size "$GPU_VM_SIZE" \ \
    --enable-managed-gpu=true \
    --gpu-driver-mode DRA \
    --node-count 1
```

Verify the accepted configuration:

```azurecli
az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gpunp \
    --query '{state:provisioningState,osSku:osSku,driver:gpuProfile.driver,managementMode:gpuProfile.nvidia.managementMode,driverMode:gpuProfile.nvidia.driverMode}' \
    --output json
```

Output should look like the following example:

```json
{
  "state": "Succeeded",
  "osSku": "Ubuntu",
  "driver": "Install",
  "managementMode": "Managed",
  "driverMode": "DRA"
}
```

### [Azure Linux node pool](#tab/add-azure-linux-gpu-node-pool)

To use Azure Linux, specify the OS SKU by setting `os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default. Create the uniform pool with `--enable-managed-gpu=true` and driver mode set to `DRA`:

```azurecli
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gpunp \
    --os-sku AzureLinux
    --node-vm-size "$GPU_VM_SIZE" \ \
    --enable-managed-gpu=true \
    --gpu-driver-mode DRA \
    --node-count 1
```

Verify the accepted configuration:

```azurecli
az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gpunp \
    --query '{state:provisioningState,osSku:osSku,driver:gpuProfile.driver,managementMode:gpuProfile.nvidia.managementMode,driverMode:gpuProfile.nvidia.driverMode}' \
    --output json
```

Output should look like the following example:

```json
{
  "state": "Succeeded",
  "osSku": "AzureLinux",
  "driver": "Install",
  "managementMode": "Managed",
  "driverMode": "DRA"
}
```

---

## Verify node health and GPU device discovery

Wait for the GPU nodes to become ready and list them:

```bash
kubectl wait --for=condition=Ready nodes \
    -l "kubernetes.azure.com/agentpool=gpunp" --timeout=10m
kubectl get nodes \
    -l "kubernetes.azure.com/agentpool=gpunp" -o wide
kubectl describe nodes \
    -l "kubernetes.azure.com/agentpool=gpunp"
```

Verify that every expected node is `Ready` and investigate unhealthy node conditions before running GPU workloads. Confirm that `az aks nodepool show` reports `driverMode` as `DRA` and `managementMode` as `Managed` for the `gpunp` pool.

Inspect the devices available for DRA requests through the Kubernetes `ResourceSlice` API:

```bash
kubectl get resourceslices.resource.k8s.io \
    -o custom-columns='NAME:.metadata.name,DRIVER:.spec.driver,POOL:.spec.pool.name,NODE:.spec.nodeName'
kubectl get resourceslices.resource.k8s.io -o yaml
```

Verify that slices with driver `gpu.nvidia.com` advertise the expected devices on nodes in your AKS node pool. The `POOL` column shows the slice's DRA resource pool, which isn't necessarily the AKS node pool name. A resource slice describes devices, but it doesn't by itself show which devices are free. DRA discovery doesn't rely on an allocatable `nvidia.com/gpu` value on the node.

## Create a device class and GPU claim

Create a class that selects whole NVIDIA GPUs. The example uses the class name `aks-dra-gpu` to avoid replacing an existing class named `gpu.nvidia.com`. If `aks-dra-gpu` already exists, inspect its ownership and selectors before continuing, or choose a new name consistently throughout the example.

```bash
kubectl apply -f - <<'EOF'
apiVersion: resource.k8s.io/v1
kind: DeviceClass
metadata:
  name: aks-dra-gpu
spec:
  selectors:
  - cel:
      expression: "device.driver == 'gpu.nvidia.com' && device.attributes['gpu.nvidia.com'].type == 'gpu'"
EOF

kubectl get deviceclass aks-dra-gpu -o yaml
kubectl create namespace "$GPU_NAMESPACE"
```

Create a claim for one GPU in the workload namespace:

```bash
kubectl apply -f - <<EOF
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: gpu-claim
  namespace: ${GPU_NAMESPACE}
spec:
  devices:
    requests:
    - name: gpu
      exactly:
        deviceClassName: aks-dra-gpu
        allocationMode: ExactCount
        count: 1
EOF
```

A successfully created claim isn't proof of GPU allocation. Allocation can wait until a consuming pod is scheduled. Create the workload before checking for an allocation.

## Run a GPU workload

The following example references the claim at the pod level and grants its container access through `resources.claims`. The node selector keeps it on the intended DRA-enabled node pool. Don't add a legacy `nvidia.com/gpu` limit or set `nodeName`, which bypasses scheduler placement.

Check for intentional taints on the GPU pool before creating the sample workload:

```bash
kubectl get nodes -l "kubernetes.azure.com/agentpool=gpunp" \
    -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'
```

The example tolerates `sku=gpu:NoSchedule` and `nvidia.com/gpu:NoSchedule` if present. Add matching tolerations for other intentional pool taints, but don't tolerate node health problems as a workaround.

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: gpu-dra-validation
  namespace: ${GPU_NAMESPACE}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 600
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.azure.com/agentpool: "gpunp"
      tolerations:
        - key: sku
          operator: Equal
          value: gpu
          effect: NoSchedule
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      resourceClaims:
        - name: gpu
          resourceClaimName: gpu-claim
      containers:
        - name: gpu-test
          image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
          command: ["nvidia-smi"]
          resources:
            claims:
              - name: gpu
EOF

kubectl -n "$GPU_NAMESPACE" wait \
    --for=condition=complete job/gpu-dra-validation --timeout=10m
kubectl -n "$GPU_NAMESPACE" logs job/gpu-dra-validation
kubectl -n "$GPU_NAMESPACE" get pods -l job-name=gpu-dra-validation -o wide
kubectl -n "$GPU_NAMESPACE" get resourceclaim gpu-claim -o yaml
```

Verify all of the following:

- The job completes and its pod has status `Completed`.
- The logs contain NVIDIA-SMI output with the GPU, driver version, and CUDA version, without a driver communication error. Exact versions depend on the node image.
- The pod runs on a node in the `gpunp` AKS node pool.
- The claim's `status.allocation.devices.results` contains a device with driver `gpu.nvidia.com`, a DRA resource pool name, and a device identifier. The DRA resource pool name isn't necessarily the AKS node pool name.

This example verifies scheduling, allocation, and GPU access. It doesn't run a CUDA computation or measure performance. A single job tests one node; to validate every node, repeat with separate claims and jobs and add a `kubernetes.io/hostname` selector alongside the pool selector.

## Manage resource claim lifecycle

A claim referenced by name must be in the same namespace as its consuming pod. For replicated workloads that need independent allocations, use a `ResourceClaimTemplate` to create per-pod claims instead of pointing every replica to one named claim.

For the standalone claim in this example, delete the consuming workload and its pods before deleting the claim. Job completion alone isn't a release check. After both are deleted, recreate the claim and job and repeat validation to confirm that the GPU can be allocated again.

## Migrate from the Kubernetes device plugin to DRA

Moving from the NVIDIA Kubernetes device plugin to the managed DRA driver requires changes to both node pool configuration and workload manifests. Enabling DRA doesn't translate existing `nvidia.com/gpu` requests into claims or move running GPU allocations. Use a replacement pool so that you can validate the new configuration before retiring the original one; this procedure doesn't switch an existing node pool in place.

### Plan the migration

- Inventory workloads that request `nvidia.com/gpu`, including requests generated by Helm charts, operators, and deployment pipelines. Record their GPU counts, node selectors, and tolerations.
- Confirm that DRA supports each workload's GPU configuration. Don't assume that a device-plugin MIG resource or sharing configuration has an equivalent DRA configuration. The whole-GPU example in this article isn't a migration procedure for those configurations.
- Reserve GPU quota and regional capacity for both pools during the transition. Account for replacement replicas and rollout surge when sizing the DRA pool.
- Plan application restarts, traffic changes, and checkpointing for long-running GPU jobs. Review disruption budgets and storage dependencies before draining nodes. This procedure doesn't guarantee a disruption-free migration.
- Keep the original manifests and DevicePlugin pool available until the replacement workloads pass validation. In a mixed cluster, constrain each workload and GPU component to compatible nodes; don't run both allocation mechanisms on the same node.

### Update workload manifests

A device-plugin container typically requests a GPU with:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

For DRA, create a suitable `ResourceClaim` or `ResourceClaimTemplate`, then update the workload's pod specification. The following fragment shows the references for a single pod using the `gpu-claim` from this article:

```yaml
spec:
  resourceClaims:
    - name: gpu
      resourceClaimName: gpu-claim
  containers:
    - name: gpu-test
      image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
      command: ["nvidia-smi"]
      resources:
        claims:
          - name: gpu
```

Remove `nvidia.com/gpu` from both `resources.requests` and `resources.limits` if present, but preserve unrelated CPU and memory settings. Add a node selector for the replacement DRA pool and the appropriate tolerations, as shown in [Run a GPU workload](#run-a-gpu-workload).

For a deployment or other controller, make these changes in its pod template, not only on a running pod. Use per-pod claims from a `ResourceClaimTemplate` when replicas need independent GPUs; one named claim isn't a replacement for a separate GPU allocation per replica. Claims must be created in the consuming workload's namespace.

### Validate and retire the old GPU node pool

1. Create a separate node pool with `--enable-managed-gpu=true` and `--gpu-driver-mode DRA`. Verify the pool configuration, node readiness, and advertised devices. Leave the original device plugin-compatible node pool unchanged.
2. Deploy the updated workload on the replacement pool. Confirm that each consuming container references its claim, that no legacy GPU request remains, and that each claim receives the expected device allocation after scheduling.
3. Verify GPU access and application health, not just `nvidia-smi`. Test representative replica counts, restarts, claim release and reuse, and concurrent allocations.
4. Move traffic or resume processing only after validation succeeds. If validation fails, stop the replacement workloads and restore the original manifests and pool selection.
5. After all workloads have migrated, cordon and drain the original nodes through your normal maintenance process, respecting disruption budgets. Verify that no workloads still depend on the original node pool, then delete it. Don't manually remove AKS-managed device plugin components from pools that still use them.

Delete migration-only claims after their consuming workloads are removed. Keep shared device classes and claim templates that the migrated workloads still need.

## Troubleshoot GPU allocation

The commands in this section use the names from the earlier example: the `gpunp` node pool, the `$GPU_NAMESPACE` namespace, the `gpu-claim` claim, the `gpu-dra-validation` job, and the `aks-dra-gpu` device class. Substitute your own names if you used different ones.

### No GPU devices are available

```bash
kubectl get nodes -l "kubernetes.azure.com/agentpool=${GPU_NODEPOOL_NAME}" -o wide
kubectl describe nodes -l "kubernetes.azure.com/agentpool=${GPU_NODEPOOL_NAME}"
kubectl get nodes -l "kubernetes.azure.com/agentpool=gpunp" -o wide
kubectl describe nodes -l "kubernetes.azure.com/agentpool=gpunp"
kubectl get resourceslices.resource.k8s.io -o yaml
```

Resolve unhealthy node conditions, and then check the intended pool for GPU devices with the driver `gpu.nvidia.com`. If ready nodes still don't advertise any devices, confirm that the pool uses DRA and a supported GPU configuration.

### The pod stays pending or the claim isn't allocated

```bash
kubectl -n "$GPU_NAMESPACE" describe pods -l job-name=gpu-dra-validation
kubectl -n "$GPU_NAMESPACE" describe resourceclaim gpu-claim
kubectl get deviceclass aks-dra-gpu -o yaml
```

Use the pod's scheduling events to correct a missing or mismatched device class, node selector, or toleration. If matching GPUs are already allocated, release unused claims after removing their consumers, or add supported GPU capacity. A claim can remain unallocated until a consuming pod exists. Create the workload before diagnosing allocation failure.

### The workload fails to access its allocated GPU

```bash
kubectl -n "$GPU_NAMESPACE" logs job/gpu-dra-validation
kubectl -n "$GPU_NAMESPACE" get pods -l job-name=gpu-dra-validation -o yaml
kubectl -n "$GPU_NAMESPACE" get resourceclaim gpu-claim -o yaml
```

Confirm that `status.allocation.devices.results` contains the expected GPU. Verify that the pod references the resource claim in the same namespace and that the container references it through `resources.claims`. Remove legacy `nvidia.com/gpu` requests and limits, and check image compatibility with the GPU and driver. After correcting the manifest, recreate the sample job and repeat validation.

## Clean up resources

If you created the example namespace, remove its consuming workload before the resource claim:

```bash
kubectl -n "$GPU_NAMESPACE" delete job gpu-dra-validation --wait=true
kubectl -n "$GPU_NAMESPACE" wait --for=delete pod \
    -l job-name=gpu-dra-validation --timeout=5m
kubectl -n "$GPU_NAMESPACE" delete resourceclaim gpu-claim --wait=true
kubectl delete namespace "$GPU_NAMESPACE"
```

The device class is cluster-scoped. Delete it only if you created it for this example and no other workloads depend on it:

```bash
kubectl delete deviceclass aks-dra-gpu
```

If you added the GPU node pool for this example, first confirm that no other workloads depend on it, and then delete the node pool:

```azurecli
az aks nodepool delete \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name gpunp
```

## Next steps

- Learn about [GPU observability](./monitor-gpu-metrics.md) and [GPU profiling](./gpu-profiling.md) on AKS.
- Understand the default [GPU health signals](./gpu-health-monitoring.md) reported by node problem detector (NPD).