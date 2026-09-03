---
title: Use GPUs for compute-intensive workloads in AKS on Azure Local for multi-rack deployments
description: Learn how to deploy GPU-enabled node pools in AKS enabled by Arc on Azure Local for multi-rack deployments.
ms.topic: how-to
ms.date: 09/01/2026
ms.author: sunnyyuan
ms.custom: multi-rack
author: sunnyyuan

# Intent: As an IT Pro, I want to learn how to deploy GPU-enabled node pools on AKS on Azure Local for multi-rack deployments.
# Keyword: Run GPU workloads on Kubernetes
---

# Use GPUs for compute-intensive workloads in AKS on Azure Local for multi-rack deployments

This article describes how to deploy and configure GPU-enabled node pools in AKS enabled by Azure Arc on Azure Local for multi-rack deployments. _Graphical processing units_ (GPUs) are useful for compute-intensive workloads such as machine learning, deep learning, and AI inferencing.

The Azure Local platform exposes physical GPUs to AKS Arc worker virtual machines (VMs), using discrete device assignment (DDA) with _vfio-pci_ PCI passthrough. Workloads inside the AKS Arc cluster can run directly against the device.

## Supported GPU models and VM sizes

AKS on Azure Local for multi-rack deployments supports the following GPU hardware and SKUs:

| GPU model                              | Supported VM sizes           | vCPU | Memory (GiB) | GPUs per VM |
| -------------------------------------- | ---------------------------- | ---- | ------------ | ----------- |
| NVIDIA RTX Pro 6000 Blackwell (96 GiB) | `Standard_NC16_RTX6000Pro_1` | 16   | 64           | 1           |
| NVIDIA RTX Pro 6000 Blackwell (96 GiB) | `Standard_NC32_RTX6000Pro_1` | 32   | 128          | 1           |

> [!NOTE]
> Multi-GPU SKUs (such as `Standard_NC16_RTX6000Pro_2` and `Standard_NC32_RTX6000Pro_2`) are present in the catalog but aren't yet generally available.

## Before you begin

To create a GPU-enabled node pool, make sure the following requirements are met:

- An Azure Local cluster for multi-rack deployments is deployed and registered with Azure Arc. For more information, see the [multi-rack deployment overview](cluster-architecture.md).
- Ensure the custom location of your Azure Local cluster has physical compute nodes with available NVIDIA RTX Pro 6000 GPUs. Your Azure Local administrator can confirm this from a management node by querying the platform cluster for the `nvidia.com/nvidia-rtx-pro-6000` resource on compute-role nodes:

  ```bash
  kubectl get nodes -l platform.afo-nc.microsoft.com/role=compute -o json \
    | jq -r '.items[] | .metadata.name as $n
             | .status.allocatable | to_entries[]
             | select(.key | test("nvidia|gpu|vfio"; "i"))
             | "\($n)\t\(.key) = \(.value)"'
  ```

  The output lists each compute node and its allocatable GPU-related resources, for example:

  ```output
  nvidia.com/gpu_vfio = 0
  nvidia.com/nvidia-rtx-pro-6000 = 2
  nvidia.com/gpu_vfio = 0
  nvidia.com/nvidia-rtx-pro-6000 = 2
  ```

  At least one compute node must report a nonzero `nvidia.com/nvidia-rtx-pro-6000` value, and the sum across compute nodes must be at least the `--node-count` you plan to request in Step 2. If no nodes appear or all values are `0`, contact your administrator or Microsoft Support before proceeding.

- Install the [latest version of Azure CLI](/cli/azure/install-azure-cli) and the `aksarc` extension.
- Configure either the tenant proxy or the logical network connectivity before proceeding to enable outbound access to NVIDIA software. For BYO proxy instructions, see [Add BYO proxy how-to for AKS on Azure Local multi-rack](aks-customer-proxy.md).
- Ensure the AKS Arc cluster is created with SSH keys at cluster creation time and that you have access to these SSH keys. Steps 3 and 4 in this article require SSH access to each GPU worker VM to verify the NVIDIA driver is installed correctly and to install the NVIDIA Container Toolkit. SSH keys can only be configured during cluster creation.

> [!NOTE]
> The NVIDIA driver is preinstalled in the worker VM image, so you don't need to install it manually. You must still install the NVIDIA Container Toolkit and NVIDIA Kubernetes device plugin so that the GPU is schedulable as `nvidia.com/gpu` from pod specs. Step 3 verifies the preinstalled driver, Steps 4 and 5 install the remaining components, and Step 6 verifies end-to-end with a pod workload.

## Step 1: List available GPU-enabled VM sizes

After you deploy the Azure Local cluster, confirm that GPU-enabled SKUs are visible on your custom location:

```azurecli
az aksarc vmsize list --custom-location <custom location ID> --resource-group <resource group name> --output table
```

The output includes the `Standard_NC*_RTX6000Pro_*` SKUs if you're on this release.

## Step 2: Create a cluster with a GPU-enabled node pool

Add GPU node pools to an AKS Arc cluster. The control plane and system node pool use a standard non-GPU VM size. The GPU SKU is only for the user node pool that runs your workloads.

> [!IMPORTANT]
> You can't create an AKS Arc cluster with a GPU-enabled SKU as the initial (system) node pool. You must first create the cluster with a standard non-GPU VM size, then add a GPU-enabled user node pool.

1. Create the AKS Arc cluster (without a GPU node pool). For detailed steps and parameter guidance, see [Create Kubernetes clusters using Azure CLI](../aks-create-clusters-cli.md).

1. Add a GPU-enabled Linux node pool. The following example adds a two-node pool of `Standard_NC16_RTX6000Pro_1` VMs (one NVIDIA RTX Pro 6000 GPU per node):

   ```azurecli
   az aksarc nodepool add \
     --cluster-name <aks cluster name> \
     --resource-group <resource group name> \
     --name <nodepool name> \
     --node-count <node count> \
     --node-vm-size Standard_NC16_RTX6000Pro_1 \
     --os-type Linux
   ```

   The platform validates GPU capacity upon command execution. If the cluster doesn't have enough physical GPUs to back the requested node count, the command fails.

1. (Optional) Connect to the cluster via Azure Arc proxy:

   ```azurecli
   az connectedk8s proxy --name <aks cluster name> --resource-group <resource group name>
   ```

## Step 3: Verify the NVIDIA driver inside the worker VM

The Azure Local platform delivers the physical GPU to the worker VM through PCI passthrough. The worker VM runs Azure Linux 3, and the NVIDIA driver - the Microsoft-signed `cuda-open` package with the open kernel modules required for the Blackwell architecture - is preinstalled in the worker VM image. You don't need to install the driver manually. Use the steps in this section to confirm the GPU and driver are present.

Run the verification steps in this section on each worker VM in the GPU node pool. To open an in-guest shell, use SSH (see [Connect to Windows or Linux worker nodes with SSH](../hyperconverged/ssh-connect-to-windows-and-linux-worker-nodes.md)).

1. Confirm the GPU device is visible to the guest:

   ```bash
   lspci -nn | grep -i nvidia
   ```

   Expect something like:

   ```
   0e:00.0 3D controller [0302]: NVIDIA Corporation Device [10de:2bb5] (rev a1)
   ```

1. Verify the driver is loaded and can detect the GPU. The first `nvidia-smi` invocation must be run as root so the driver can create the required `/dev/nvidia*` device nodes. After the initial run, you can use `nvidia-smi` without elevated privileges.

   ```bash
   lsmod | grep '^nvidia'
   sudo nvidia-smi
   ```

   Successful output from `sudo nvidia-smi` lists the NVIDIA RTX Pro 6000 with the installed driver version, which confirms the preinstalled driver is working. On an idle GPU worker VM, the output looks like this:

   ```
   +-----------------------------------------------------------------------------------------+
   | NVIDIA-SMI 580.105.08             Driver Version: 580.105.08     CUDA Version: 13.0     |
   +-----------------------------------------+------------------------+----------------------+
   | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
   | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
   |                                         |                        |               MIG M. |
   |=========================================+========================+======================|
   |   0  NVIDIA RTX PRO 6000 Blac...    Off |   00000000:0E:00.0 Off |                    0 |
   | N/A   24C    P0             55W /  600W |       0MiB /  97887MiB |      3%      Default |
   |                                         |                        |             Disabled |
   +-----------------------------------------+------------------------+----------------------+

   +-----------------------------------------------------------------------------------------+
   | Processes:                                                                              |
   |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
   |        ID   ID                                                               Usage      |
   |=========================================================================================|
   |  No running processes found                                                             |
   +-----------------------------------------------------------------------------------------+
   ```

   If `lsmod` shows no `nvidia` modules, load them manually and rerun `nvidia-smi`:

   ```bash
   sudo modprobe nvidia
   sudo modprobe nvidia_uvm
   sudo modprobe nvidia_drm
   ```

## Step 4: Install the NVIDIA Container Toolkit on each GPU worker VM

The driver makes the GPU usable from the worker VM's host OS, but containers still need a runtime hook to see `/dev/nvidia*` and the matching user-space libraries (`libcuda.so`, `libnvidia-ml.so`). The `nvidia-container-toolkit` package provides that hook and registers it with `containerd`.

The `nvidia-container-toolkit` package is installed from `packages.microsoft.com`, so the worker VM needs outbound HTTPS access. If your environment requires an HTTPS proxy for outbound traffic, configure `tdnf` to use it before installing. Replace `<proxy-url>` with the proxy that's permitted to reach `packages.microsoft.com`:

```bash
echo 'proxy=<proxy-url>' | sudo tee -a /etc/tdnf/tdnf.conf
```

> [!NOTE]
> `tdnf` reads its proxy from `/etc/tdnf/tdnf.conf`. The same proxy is required for any future package updates on the worker VM.

Run on each GPU worker VM:

```bash
sudo tdnf install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=containerd --set-as-default
sudo systemctl restart containerd
```

Verify that the package is installed and that the `nvidia` runtime is registered with `containerd`:

```bash
rpm -q nvidia-container-toolkit
grep -A3 'runtimes.nvidia' /etc/containerd/config.toml
```

The `grep` command should print a `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]` block whose `runtime_type` is `io.containerd.runc.v2` and whose `BinaryName` points at `/usr/bin/nvidia-container-runtime`. If the block is missing, re-run `sudo nvidia-ctk runtime configure --runtime=containerd --set-as-default` and restart `containerd`.

## Step 5: Install the NVIDIA Kubernetes device plugin in the AKS Arc cluster

The device plugin advertises GPUs to the AKS Arc cluster's scheduler as the `nvidia.com/gpu` resource. Without it, pods that request `nvidia.com/gpu: 1` stay `Pending`.

The following manifest uses the device-plugin image mirrored on Microsoft Container Registry (MCR). You can also find it on GitHub or Nvidia websites.

1. Connect to your AKS Arc cluster by using `az connectedk8s proxy`. For step-by-step guidance, see [Connect to the cluster](resource-manager-quickstart.md#step-7-connect-to-the-cluster). Use the `--file` option to write a dedicated kubeconfig (for example, `./<aks cluster name>.kubeconfig`), leave the proxy running, and point `kubectl` at that kubeconfig in a second terminal for the remaining steps.

1. Save the following manifest as **nvidia-device-plugin.yaml**:

   ```yaml
   apiVersion: apps/v1
   kind: DaemonSet
   metadata:
     name: nvidia-device-plugin-daemonset
     namespace: kube-system
   spec:
     selector:
       matchLabels:
         name: nvidia-device-plugin-ds
     updateStrategy:
       type: RollingUpdate
     template:
       metadata:
         labels:
           name: nvidia-device-plugin-ds
       spec:
         tolerations:
           - key: nvidia.com/gpu
             operator: Exists
             effect: NoSchedule
         priorityClassName: "system-node-critical"
         containers:
           - image: mcr.microsoft.com/oss/v2/nvidia/k8s-device-plugin:v0.19.1
             name: nvidia-device-plugin-ctr
             env:
               - name: FAIL_ON_INIT_ERROR
                 value: "false"
             securityContext:
               allowPrivilegeEscalation: false
               capabilities:
                 drop: ["ALL"]
             volumeMounts:
               - name: device-plugin
                 mountPath: /var/lib/kubelet/device-plugins
         volumes:
           - name: device-plugin
             hostPath:
               path: /var/lib/kubelet/device-plugins
   ```

1. Apply the manifest:

   ```bash
   kubectl apply -f nvidia-device-plugin.yaml
   ```

Verify the DaemonSet is running and the GPU is advertised:

```bash
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds -o wide

kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}'
```

GPU-enabled nodes should report `1` under `nvidia.com/gpu`. When they do, continue to Step 6. Check your GPU availability or contact Microsoft Support if it doesn't show expected value.

## Step 6: (Optional) Run a GPU-enabled pod workload

To confirm the GPU is usable end-to-end from a Kubernetes pod, deploy a small CUDA workload and check that it completes against the GPU. This step assumes Steps 4 and 5 are complete (container toolkit installed and `nvidia.com/gpu` advertised on the node).

> [!NOTE]
> Run the following `kubectl` commands in the same shell to which you pointed the kubeconfig file in Step 5.

1. First, list the nodes in your cluster using `kubectl get nodes`. The output looks like the following example:

   ```output
   NAME             STATUS  ROLES                 AGE   VERSION
   moc-l9qz36vtxzj  Ready   control-plane,master  6m14s  v1.29.0
   moc-lhbkqoncefu  Ready   <none>                3m19s  v1.29.0
   moc-li87udi8l9s  Ready   <none>                3m5s   v1.29.0
   ```

1. Use `kubectl describe node` to confirm that the GPU is schedulable on your worker node. Under the **Capacity** section, the GPU appears as `nvidia.com/gpu: 1`:

   ```bash
   kubectl describe <node> | grep -i gpu
   ```

   The output displays the GPUs from the worker node and looks similar to the following example:

   ```output
   Capacity:
     cpu:                16
     ephemeral-storage:  103110508Ki
     memory:             65536000Ki
     nvidia.com/gpu:     1
     pods:               110
   ```

1. Create a new file named **gpupod.yaml** with the following content:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: cuda-vector-add
   spec:
     restartPolicy: OnFailure
     containers:
       - name: cuda-vector-add
         image: "k8s.gcr.io/cuda-vector-add:v0.1"
         resources:
           limits:
             nvidia.com/gpu: 1
   ```

1. Apply the manifest to deploy the sample application:

   ```bash
   kubectl apply -f gpupod.yaml
   ```

1. Verify that the pod started, completed running, and the GPU is assigned:

   ```bash
   kubectl describe pod cuda-vector-add | grep -i gpu
   ```

   The previous command should show one GPU assigned:

   ```output
   nvidia.com/gpu: 1
   nvidia.com/gpu: 1
   ```

1. Check the log file of the pod to see if the test passed:

   ```bash
   kubectl logs cuda-vector-add
   ```

   The following is example output from the previous command:

   ```output
   [Vector addition of 50000 elements]
   Copy input data from the host memory to the CUDA device
   CUDA kernel launch with 196 blocks of 256 threads
   Copy output data from the CUDA device to the host memory
   Test PASSED
   Done
   ```

## Next steps

- [Supported SKU sizes and scale requirements](scale-requirements.md)
- [Create an AKS Arc cluster with an ARM template](resource-manager-quickstart.md)
- [Upgrade a Kubernetes cluster](cluster-upgrade.md)
