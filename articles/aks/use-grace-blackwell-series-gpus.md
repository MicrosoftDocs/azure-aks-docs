---
title: Use NVIDIA Grace-Blackwell GPUs on Azure Kubernetes Service (AKS)
description: Configure GPU scheduling, cross-node NVLink, and InfiniBand networking for NVIDIA Grace-Blackwell GPU nodes on Azure Kubernetes Service.
author: sdesai345
ms.author: sachidesai
ms.date: 11/11/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
---

# Use NVIDIA Grace-Blackwell GPUs on Azure Kubernetes Service (AKS) (preview)

Azure Kubernetes Service (AKS) can manage the GPU software, cross-node NVLink, and high-performance networking components for NVIDIA Grace Blackwell GB200 and GB300 GPU node pools. Applications use Kubernetes Dynamic Resource Allocation (DRA) to request GPUs and Remote Direct Memory Access (RDMA) network devices.

The AKS managed experience reduces operational work of installing, configuring, and maintaining GPU and networking components. Your team focuses on application resource claims, compute domains, and GPU workload validation. To learn about important GPU and networking concepts for this article, see [GPU concepts for NVIDIA Grace-Blackwell GPU nodes](./grace-blackwell-series-gpu-concepts.md) on AKS.

In this article, you create a node pool with a GB200 or GB300 Azure virtual machine (VM) size, managed DRA for GPUs, managed compute-domain, and managed support for DRANET. You then run a sample application that requests a GPU, joins a cross-node compute domain, and requests both a GPU and InfiniBand devices.

> [!IMPORTANT]
> Confirm the GB200 or GB300 Azure VM size, managed compute-domain availability, and InfiniBand device count for your allocation before using them.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Overview

Choose how AKS manages the GPU software components:

| Configuration | What AKS installs | What you manage |
| --- | --- | --- |
| Managed GPU with DRA | NVIDIA driver, DRA driver, and managed GPU health and metrics components. For a GB300 GPU node pool, AKS also installs the managed compute-domain extension automatically. | Application resource claims and compute domains. |
| Managed support for DRANET | DRANET driver and managed extension for InfiniBand and RDMA devices. | Application claims for network devices. |

The managed configuration in this article enables both options on a single GB-series GPU node pool. 

Follow the managed GPU node pool instructions through cleanup. The [optional driver-only path](#optional-install-only-the-gpu-driver) is an alternative for teams that want to manage their own Kubernetes GPU software.

## Prerequisites

- Understand key GPU and networking concepts explained in [GPU concepts for NVIDIA Grace-Blackwell GPU nodes](./grace-blackwell-series-gpu-concepts.md) on AKS.
- An Azure subscription with access to compatible Grace-Blackwell series rack capacity, such as the [ND GB200-v6 sizes series](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb200-v6-series) or [ND GB300-v6 sizes series](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb300-v6-series), in your AKS deployment region.
- Azure CLI with the `aks-preview` extension version `22.0.0b12` or later.
- An existing AKS cluster with AKS version `v20261025` or later, Kubernetes version `1.36` or later, and Azure Container Networking Interface (CNI) networking enabled, in a region with access to your allocated GPU capacity.
- Available capacity for at least 18 compatible GB-series nodes. The cross-node NVLink example uses two nodes in the same rack within that pool.

## Limitations

- Grace-Blackwell GPU node pools require 18 nodes or a larger multiple of 18, such as 36 or 54. A node pool created with any other node count won't provision successfully. This requirement applies to both the managed GPU and optional driver-only configurations.
- AKS cluster autoscaler (CAS) and node autoprovisioning (NAP) don't currently support Grace-Blackwell series GPU node pools.
- [ND GB200-v6 series](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb200-v6-series) and [ND GB300-v6 series](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb300-v6-series) VM sizes don't support Windows node pools on AKS.
- NVIDIA GB200 and GB300 use ARM64 Grace-Blackwell machines and only support ARM64-based node images on AKS. For node pools with the default `Ubuntu` OS SKU, use the Ubuntu 24.04 AKS image.

## Plan rack-based capacity

Cross-node NVLink requires physical connections between machines in the same rack. Confirm that your allocated capacity supports this arrangement; choosing the same VM size alone doesn't guarantee those connections.

Create the pool with 18 nodes or a larger multiple of 18, without exceeding your available capacity. The node count represents VMs, not GPUs, and application claims and compute domains use resources on those VMs.

## Prepare your Azure environment

Sign in to your Azure account and replace the placeholders with your Azure subscription and resource values:

```azurecli-interactive
az login
az account set --subscription "<subscription-id>"
```

### Register the GPU preview features

Install or update the `aks-preview` extension:

```azurecli-interactive
az extension add --name aks-preview --upgrade --yes
```

Register the `ManagedGPUExperiencePreview` and `GraceBlackwellManagedGPUPreview` feature flags.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview
az feature register --namespace Microsoft.ContainerService --name GraceBlackwellManagedGPUPreview
```

Confirm the registration state of each feature:

```azurecli-interactive
az feature show --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview --query properties.state --output tsv
az feature show --namespace Microsoft.ContainerService --name GraceBlackwellManagedGPUPreview --query properties.state --output tsv
```

When all three features report `Registered`, refresh the resource provider registration:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

### Set environment variables

Set the environment variables to your existing AKS cluster and resource group for your allocated GPU capacity. The example requests 18 nodes. You can increase `GPU_NODE_COUNT` to a larger multiple of 18 if you have sufficient capacity. The two-node compute-domain example uses only a subset of this pool. For a GB200 GPU node pool, also replace `GPU_VM_SIZE` with the associated VM size name.

```bash
export SUBSCRIPTION_ID="<azure-subscription-id>"
export RESOURCE_GROUP="<my-resource-group-name>"
export CLUSTER_NAME="<my-aks-cluster-name>"
export GPU_VM_SIZE="Standard_ND128isr_GB300_v6"
export GPU_NODE_COUNT=18

az account set --subscription "$SUBSCRIPTION_ID"
```

## Connect to your AKS cluster

Check your cluster configuration before creating the GB-series GPU node pool:

```azurecli-interactive
az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
  --query '{state:provisioningState,kubernetesVersion:currentKubernetesVersion,location:location,networkPlugin:networkProfile.networkPlugin}' \
  --output json

az aks nodepool list \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --query '[].{name:name,state:provisioningState,kubernetesVersion:currentOrchestratorVersion}' \
  --output table
```

Confirm the following items before continuing:

- The cluster reports `Succeeded`, runs Kubernetes `1.36` or later, and has `networkPlugin` set to `azure`.
- The cluster location matches your allocation, and sufficient GB-series rack capacity is available.
- Existing node pools in the AKS cluster are healthy.

Get credentials to your AKS cluster:

```azurecli-interactive
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl api-resources --api-group=resource.k8s.io --output wide
```

Verify that the expected nodes are `Ready` and that the DRA resource listing includes `DeviceClass`, `ResourceClaim`, and `ResourceClaimTemplate`.

## Create a managed GB300 GPU node pool

> [!WARNING]
> Don't run a self-managed NVIDIA device plugin or DRA driver against GPUs managed by the AKS GPU DRA driver. If you previously installed GPU Operator or NVIDIA's DRA driver for the optional driver-only procedure, remove those components and their test resources before creating this pool. Deleting their node pool alone doesn't remove Helm releases or cluster-scoped objects.

Enable managed DRA and managed support for DRANET in `az aks one nodepool add` operation:

```azurecli-interactive
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gbnp \
    --node-vm-size "$GPU_VM_SIZE" \
    --os-sku Ubuntu2404 \
    --enable-managed-gpu=true \
    --gpu-driver-mode DRA \
    --enable-managed-dranet \
    --node-count "$GPU_NODE_COUNT"
```

For this GB300 managed DRA configuration, AKS automatically installs the `aks-managed-compute-domain` extension for cross-node NVLink. It also configures managed support for DRANET for network devices.

Inspect the pool configuration:

```azurecli-interactive
az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gbnp \
    --query '{state:provisioningState,driver:gpuProfile.driver,managementMode:gpuProfile.nvidia.managementMode,driverMode:gpuProfile.nvidia.driverMode,dranet:networkProfile.dranet.mode}' \
    --output json
```

The expected output is:

```json
{
  "state": "Succeeded",
  "driver": "Install",
  "managementMode": "Managed",
  "driverMode": "DRA",
  "dranet": "Managed"
}
```

Wait for the nodes to become ready:

```bash
kubectl wait --for=condition=Ready node \
    -l "agentpool=gbnp" --timeout=900s
kubectl get nodes -l "agentpool=gbnp" -o wide
```

## Verify managed GPU allocation

The managed GPU DRA driver runs directly on each node, not in a Kubernetes pod. Check the `ResourceSlices` it publishes to confirm that Kubernetes can discover the GPUs:

```bash
kubectl get resourceslices.resource.k8s.io \
    -o custom-columns='NAME:.metadata.name,DRIVER:.spec.driver,NODE:.spec.nodeName'
kubectl get deviceclass gpu.nvidia.com
```

Confirm that ResourceSlices with driver `gpu.nvidia.com` include the nodes in your pool.

> [!IMPORTANT]
> Currently, the managed DRA stack publishes ResourceSlices but doesn't install the `gpu.nvidia.com` DeviceClass. If this DeviceClass is missing, apply the following workaround before submitting GPU claims. Without it, claims don't allocate and pods remain pending. Don't replace an existing DeviceClass without checking its configuration.

Apply the following manifest only if the device class check returns `NotFound`. If the class already exists and selects `gpu.nvidia.com` devices, skip this command.

```bash
kubectl apply -f - <<'EOF'
apiVersion: resource.k8s.io/v1
kind: DeviceClass
metadata:
  name: gpu.nvidia.com
spec:
  selectors:
  - cel:
      expression: device.driver == 'gpu.nvidia.com'
EOF
```

### Run a single-GPU application

Create a namespace, a claim for one GPU, and a pod that uses the claim:

```bash
kubectl create namespace gpu-dra-test --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: gpu-claim
  namespace: gpu-dra-test
spec:
  devices:
    requests:
    - name: gpu
      exactly:
        deviceClassName: gpu.nvidia.com
        count: 1
        allocationMode: ExactCount
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-dra-workload
  namespace: gpu-dra-test
spec:
  restartPolicy: Never
  nodeSelector:
    agentpool: gbnp
  resourceClaims:
  - name: gpu
    resourceClaimName: gpu-claim
  containers:
  - name: gpu-check
    image: mcr.microsoft.com/mirror/docker/library/ubuntu:24.04
    env:
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: utility
    command: ["nvidia-smi"]
    resources:
      claims:
      - name: gpu
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded \
    pod/gpu-dra-workload -n gpu-dra-test --timeout=300s
kubectl logs gpu-dra-workload -n gpu-dra-test
kubectl get resourceclaim gpu-claim -n gpu-dra-test -o yaml
```

The samples use an ARM64-compatible Ubuntu image and the managed NVIDIA stack supplies the driver utility `nvidia-smi` to the GPU container; `NVIDIA_DRIVER_CAPABILITIES=utility` requests that utility support. No CUDA toolkit installation is needed for these device-access checks.

The pod should complete successfully and display the GPU information. In the claim, `status.allocation.devices.results[0].driver` should be `gpu.nvidia.com`.

## Configure cross-node NVLink with a compute domain

Managed compute domain provides the controller and NVIDIA Internode Memory Exchange (IMEX) components used to form a multinode NVLink (MNNVL) fabric. You must create a `ComputeDomain` and schedule applications that claim its channel.

Verify the controller and cluster-scoped resources:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=compute-domain
kubectl get crd computedomains.resource.nvidia.com computedomaincliques.resource.nvidia.com
kubectl get deviceclasses.resource.k8s.io
```

The controller should be running. Both custom resource definitions (CRDs), which add compute-domain resource types to Kubernetes, and the `compute-domain-daemon.nvidia.com` and `compute-domain-default-channel.nvidia.com` DeviceClasses should exist.

### Create a two-node compute domain

Create a domain with two nodes and name its channel claim template. The controller creates the template:

```bash
kubectl apply -f - <<'EOF'
apiVersion: resource.nvidia.com/v1beta1
kind: ComputeDomain
metadata:
  name: gb-cd-managed
  namespace: default
spec:
  numNodes: 2
  channel:
    resourceClaimTemplate:
      name: gb-cd-managed-channel
EOF
```

Create two application replicas that each claim the channel. The pod anti-affinity rule requires them to run on different nodes:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cd-imex-managed
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cd-imex-managed
  template:
    metadata:
      labels:
        app: cd-imex-managed
    spec:
      nodeSelector:
        agentpool: gbnp
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: cd-imex-managed
            topologyKey: kubernetes.io/hostname
      resourceClaims:
      - name: cd-channel
        resourceClaimTemplateName: gb-cd-managed-channel
      containers:
      - name: box
        image: mcr.microsoft.com/mirror/docker/library/ubuntu:24.04
        command: ["sleep", "infinity"]
        resources:
          claims:
          - name: cd-channel
EOF

kubectl rollout status deploy/cd-imex-managed -n default --timeout=300s
kubectl get computedomain gb-cd-managed -n default -o yaml
kubectl get computedomaincliques.resource.nvidia.com -A -o wide
```

The deployment should reach two ready replicas, the domain should report `Ready`, and the clique information should include the two participating nodes. A clique is the group of nodes prepared for this domain. If setup fails, pods can remain in `Pending` or `ContainerCreating`.

Use the ComputeDomain `Ready` status and confirm that the clique information includes the expected participating nodes to verify domain setup.

This sample checks channel preparation and clique formation. Its containers run `sleep`; they don't perform a GPU computation or measure cross-node NVLink performance.

## Use GPUs and InfiniBand in the same application

Verify that managed support for DRANET labels and components is present:

```bash
kubectl get nodes -l "agentpool=gbnp" -L network-dra
kubectl get daemonset -n kube-system -l app.kubernetes.io/name=dranet
kubectl get pods -n kube-system -l app.kubernetes.io/name=dranet -o wide
kubectl get deviceclasses.resource.k8s.io
```

Each pool node should have the `network-dra` label and a running DRANET pod. Verify that the extension-created `rdma.kubernetes.azure.com` DeviceClass selects RDMA devices from driver `dra.net` with the expression `device.driver == "dra.net" && device.attributes["dra.net"].rdma == true`. If the class is missing or DRANET pods aren't running, resolve the managed component issue before submitting the network claim.

Create an InfiniBand claim template, a GPU claim, and one pod that requests both resources. The network claim requests all four InfiniBand NICs on the default GB300 size:

```bash
kubectl apply -f - <<EOF
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: ib-dranet-template
  namespace: default
spec:
  spec:
    devices:
      requests:
      - name: ib-interfaces
        exactly:
          deviceClassName: rdma.kubernetes.azure.com
          count: 4
          allocationMode: ExactCount
          selectors:
          - cel:
              expression: 'device.driver == "dra.net" && device.attributes["dra.net"].rdma == true'
---
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: gpu-claim-full
  namespace: default
spec:
  devices:
    requests:
    - name: gpu
      exactly:
        deviceClassName: gpu.nvidia.com
        count: 1
        allocationMode: ExactCount
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-ib-workload
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    agentpool: gbnp
  resourceClaims:
  - name: gpu
    resourceClaimName: gpu-claim-full
  - name: ib-nics
    resourceClaimTemplateName: ib-dranet-template
  containers:
  - name: trainer
    image: mcr.microsoft.com/mirror/docker/library/ubuntu:24.04
    env:
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: utility
    command: ["bash", "-c", "nvidia-smi && ls -l /dev/infiniband && sleep 3600"]
    resources:
      claims:
      - name: gpu
      - name: ib-nics
EOF

kubectl wait --for=condition=Ready pod/gpu-ib-workload -n default --timeout=300s
kubectl get resourceclaim -n default -o wide
kubectl logs gpu-ib-workload -n default
```

Both claims should allocate for the same pod on the same node. The logs should show the GPU and the devices in `/dev/infiniband`.

## Node pool scaling considerations

If you change the node pool size, keep the total at 18 or a larger multiple of 18 within your available capacity. New nodes receive the managed DRA and DRANET components automatically.

> [!WARNING]
> Scaling down removes nodes and can disrupt applications. Confirm available capacity before scaling up.

After scaling, check node readiness, GPU `ResourceSlices`, and DRANET placement:

```bash
kubectl wait --for=condition=Ready node \
    -l "agentpool=gbnp" --timeout=900s
kubectl get resourceslices.resource.k8s.io \
    -o custom-columns='NAME:.metadata.name,DRIVER:.spec.driver,NODE:.spec.nodeName'
kubectl get nodes -l "agentpool=gbnp" -L network-dra
kubectl get pods -n kube-system -l app.kubernetes.io/name=dranet -o wide
kubectl rollout status deploy/cd-imex-managed -n default --timeout=300s
kubectl get computedomaincliques.resource.nvidia.com -A -o wide
```

Confirm that added nodes publish GPU resources and receive DRANET networking. For compute-domain applications, check application readiness and clique membership.

## Optional: Install only the GPU driver

Use the driver-only configuration if you want to manage the Kubernetes GPU components yourself instead of using the managed stack. This configuration is an alternative pool, not an additional step for the managed pool.

> [!IMPORTANT]
> If you already ran the managed samples, follow the managed cleanup steps in the next section before creating this alternative pool. This cleanup removes their workloads and releases the pool's capacity. Don't uninstall AKS-managed components manually.

Use the same node-count requirement for this pool: `GPU_NODE_COUNT` must be 18 or a larger multiple of 18. Skip the managed samples in the previous section when using this alternative.

```azurecli-interactive
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
    --name gbdriver --node-vm-size "$GPU_VM_SIZE" \
    --os-sku Ubuntu2404 --gpu-driver install \
    --node-count "$GPU_NODE_COUNT"
```

AKS installs the driver and container runtime, but your team supplies the Kubernetes GPU allocation software and any compute-domain or GPU metrics components it needs.

The driver alone doesn't advertise `nvidia.com/gpu` to Kubernetes. To use legacy GPU resource requests, install NVIDIA GPU Operator with driver and toolkit management disabled. Set the operator's runtime class to `nvidia-container-runtime`, the name AKS registers, instead of the operator's default `nvidia`.

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
kubectl create namespace gpu-operator --dry-run=client -o yaml | kubectl apply -f -

helm install gpu-operator nvidia/gpu-operator \
    --namespace gpu-operator \
    --set driver.enabled=false \
    --set toolkit.enabled=false \
    --set operator.runtimeClass=nvidia-container-runtime \
    --wait

kubectl get pods -n gpu-operator
kubectl get nodes -l agentpool=gbdriver \
    -o custom-columns='NAME:.metadata.name,GPUS:.status.capacity.nvidia\.com/gpu'
```

When the device plugin is running, the nodes should advertise GPU capacity. Applications can then request `nvidia.com/gpu: 1` under container resource limits and select `agentpool: gbdriver`.

Alternatively, you can use a self-managed NVIDIA DRA driver against the AKS-installed driver, with `nvidiaDriverRoot=/` and `resources.gpus.enabled=true`. Its compute-domain functionality can be enabled with `resources.computeDomains.enabled=true`. Don't run the device plugin and DRA driver against the same GPUs; uninstall the operator before switching to the self-managed DRA path.

> [!IMPORTANT]
> The following workaround applies only when you install the NVIDIA DRA driver yourself and enable compute domains with `resources.computeDomains.enabled=true`. You don't need it for the AKS-managed compute-domain controller.

The self-managed controller sets up compute domains, but its default placement rule allows it to run only on control-plane nodes. After installing the self-managed driver, remove this restriction so the controller can run on an eligible AKS node. The second command checks that it becomes available. Adjust the deployment and namespace names if your installation uses different names:

```bash
kubectl patch deployment nvidia-dra-driver-gpu-controller \
  -n nvidia-dra-driver-gpu --type=json \
  -p '[{"op":"remove","path":"/spec/template/spec/affinity"}]'

kubectl rollout status deployment/nvidia-dra-driver-gpu-controller \
  -n nvidia-dra-driver-gpu --timeout=300s
```

Wait for a successful rollout before checking your domains. The patch removes all affinity rules from the deployment; if you added rules you need to keep, change only the control-plane restriction instead.

> [!NOTE]
> A Helm upgrade can restore the original placement restriction. Save the corrected placement settings in your Helm configuration if the chart supports them, or reapply the patch after an upgrade that restores the restriction.

## Clean up resources

For the managed path, remove the sample workloads and claims before deleting `gbnp`. If you used only the driver-only path, skip to its cleanup commands in the next section.

```bash
kubectl delete pod gpu-ib-workload -n default --ignore-not-found
kubectl delete resourceclaim gpu-claim-full -n default --ignore-not-found
kubectl delete resourceclaimtemplate ib-dranet-template -n default --ignore-not-found
kubectl delete deployment cd-imex-managed -n default --ignore-not-found
kubectl delete computedomain gb-cd-managed -n default --ignore-not-found
kubectl delete namespace gpu-dra-test --ignore-not-found
```

Delete the node pool when you no longer need it:

```azurecli-interactive
az aks nodepool delete \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name "gbnp"
```

AKS removes managed extensions and their components when no remaining pool requires them. Don't manually uninstall the managed controller or its `DeviceClasses`. Compute-domain CRDs can remain after extension removal. Leave shared definitions in place unless you've confirmed that nothing else uses them.

If you created `gpu.nvidia.com` for the workaround, remove it only when no other applications or pools require it.

```bash
kubectl delete deviceclass gpu.nvidia.com --ignore-not-found
```

For the driver-only path, uninstall GPU Operator only if you installed it, while the nodes still exist:

```bash
helm uninstall gpu-operator -n gpu-operator
kubectl delete namespace gpu-operator --ignore-not-found
```

If you used self-managed DRA instead, remove its workloads and compute domains, then uninstall its Helm release while the nodes still exist. Review any remaining cluster-scoped `DeviceClasses` and CRDs before removing them because other applications might depend on them.

After removing the self-managed software, delete the driver-only pool:

```azurecli-interactive
az aks nodepool delete \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name gbdriver
```

## Next steps

* Revisit [important GPU and networking concepts](./grace-blackwell-series-gpu-concepts.md) for Grace-Blackwell GPU nodes on AKS.
* Learn about real-time [GPU observability](./monitor-gpu-metrics.md) in Prometheus and Grafana with Azure Monitor.
* Schedule batch workloads on your GPU nodes with the managed [Kueue extension](./managed-kueue-extension-overview.md) on AKS.