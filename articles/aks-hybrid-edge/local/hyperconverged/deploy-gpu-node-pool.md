---
title: Use GPUs for compute-intensive workloads in AKS on Azure Local
description: Learn how to deploy GPU-enabled node pools in AKS Hybrid and Edge on Azure Local.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 03/21/2025
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
# Intent: As an IT Pro, I want to learn how to deploy GPU-enabled node pools
# Keyword: Run GPU workloads on Kubernetes
---

# Use GPUs for compute-intensive workloads in AKS on Azure Local

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

> [!NOTE]
> For information about GPUs in AKS on Windows Server, see [Use GPUs in AKS on Windows Server](../../windows-server/deploy-gpu-node-pool-22h2.md).

*Graphical Processing Units* (GPUs) are useful for compute-intensive workloads such as machine learning, deep learning, and more. This article describes how to use GPUs for compute-intensive workloads in AKS Hybrid and Edge.

[!INCLUDE [supported-gpu-models](../../includes/supported-gpu-models.md)]

## Before you begin

To use GPUs in AKS, make sure you install the necessary GPU drivers before you begin the deployment of the cluster. Follow the steps in this section.

### Step 1: install the OS

Install the Azure Local operating system locally on each server in your Azure Local cluster.

### Step 2: uninstall the NVIDIA host driver

On each host machine, go to **Control Panel > Add or Remove programs**, uninstall the NVIDIA host driver, then reboot the machine. After the machine reboots, confirm that the driver was successfully uninstalled. Open an elevated PowerShell terminal and run the following command:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | where {$_.friendlyname -eq "3D Video Controller"}
```

You should see the GPU devices appear in an error state as shown in this example output:

```output
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 3: Dismount the host driver from the host

When you uninstall the host driver, the physical GPU goes into an error state. You must dismount all the GPU devices from the host.

For each GPU (3D Video Controller) device, run the following commands in PowerShell. Copy the instance ID; for example, `PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000` from the previous command output:

```powershell
$id1 = "<Copy and paste GPU instance id into this string>"
$lp1 = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $id1).Data[0]
Disable-PnpDevice -InstanceId $id1 -Confirm:$false
Dismount-VMHostAssignableDevice -LocationPath $lp1 -Force
```

To confirm that the GPUs are correctly dismounted from the host, run the following command. You should see GPUs in an `Unknown` state:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | where {$_.friendlyname -eq "3D Video Controller"}
```

```output
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 4: Download and install the NVIDIA mitigation driver

The software might include components developed and owned by NVIDIA Corporation or its licensors. The use of these components is governed by the [NVIDIA end user license agreement](https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us).

See the [NVIDIA data center documentation](https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/) to download the NVIDIA mitigation driver. After downloading the driver, expand the archive and install the mitigation driver on each host machine. You can follow this PowerShell script to download the mitigation driver and extract it:

```powershell
Invoke-WebRequest -Uri "https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/nvidia_azure_stack_inf_v2022.10.13_public.zip" -OutFile "nvidia_azure_stack_inf_v2022.10.13_public.zip"
mkdir nvidia-mitigation-driver
Expand-Archive .\nvidia_azure_stack_inf_v2022.10.13_public.zip .\nvidia-mitigation-driver\
```

To install the mitigation driver, go to the folder that contains the extracted files, and select the GPU driver file based on the actual GPU type installed on your Azure Local hosts. For example, if the type is **A2 GPU**, right-click the **nvidia_azure_stack_A2_base.inf** file, and select **Install**.

You can also install the mitigation driver by running the following commands from the command line:

```powershell
pnputil /add-driver nvidia_azure_stack_A2_base.inf /install 
pnputil /scan-devices 
```

After you install the mitigation driver, the GPUs are listed in the **OK** state under **Nvidia A2_base - Dismounted**:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | where {$_.friendlyname -match "Nvidia"}"
```

```output
OK       Nvidia A2_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
OK       Nvidia A2_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000
```

### Step 5: repeat steps 1 to 4

Repeat steps 1 to 4 for each server in your Azure Local cluster.

### Step 6: continue deployment of the Azure Local cluster

Continue the deployment of the Azure Local cluster by following the steps in [Azure Local deployment](/azure/azure-local/deploy/deployment-introduction).

### Get a list of available GPU-enabled VM SKUs

When the Azure Local cluster deployment finishes, run the following CLI command to show the available VM SKUs on your deployment. If you install your GPU drivers correctly, the command lists the corresponding GPU VM SKUs:

```azurecli
az aksarc vmsize list --custom-location <custom location ID> -g <resource group name>
```

## Create a new workload cluster with a GPU-enabled node pool

Currently, you can only use GPU-enabled node pools for Linux node pools. To create a new Kubernetes cluster:

```azurecli
az aksarc create -n <aks cluster name> -g <resource group name> --custom-location <custom location ID> --vnet-ids <vnet ID>
```

The following example adds a node pool with two GPU-enabled (NVIDIA A2) nodes with a **Standard\_NC4\_A2** VM SKU:

```azurecli
az aksarc nodepool add --cluster-name <aks cluster name> -n <node pool name> -g <resource group name> --node-count 2 --node-vm-size Standard_NC4_A2 --os-type Linux
```

## Confirm you can schedule GPUs

After you create your GPU node pool, confirm that you can schedule GPUs in Kubernetes. First, list the nodes in your cluster using the [kubectl get nodes](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command:

```powershell
kubectl get nodes
```

```output
NAME             STATUS  ROLES                 AGE   VERSION
moc-l9qz36vtxzj  Ready   control-plane,master  6m14s  v1.22.6
moc-lhbkqoncefu  Ready   <none>                3m19s  v1.22.6
moc-li87udi8l9s  Ready   <none>                3m5s  v1.22.6
```

Now use the [kubectl describe node](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe) command to confirm that you can schedule the GPUs. Under the **Capacity** section, the GPU appears as **nvidia.com/gpu: 1**.

```powershell
kubectl describe <node> | findstr "gpu" 
```

The output displays the GPUs from the worker node and looks similar to the following example:

```output
Capacity: 
  cpu:                4 
  ephemeral-storage:  103110508Ki 
  hugepages-1Gi:      0 
  hugepages-2Mi:      0 
  memory:             7865020Ki 
  nvidia.com/gpu:     1 
  pods:               110
```

## Run a GPU-enabled workload

After you complete the previous steps, create a new YAML file for testing, such as **gpupod.yaml**. Copy and paste the following YAML into the new file named **gpupod.yaml**, then save it:

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

Run the following command to deploy the sample application:

```powershell
kubectl apply -f gpupod.yaml
```

Verify that the pod started, completed running, and the GPU is assigned:

```powershell
kubectl describe pod cuda-vector-add | findstr 'gpu'
```

The previous command should show one GPU assigned:

```output
nvidia.com/gpu: 1
nvidia.com/gpu: 1
```

Check the log file of the pod to see if the test passed:

```powershell
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

If you receive a version mismatch error when calling into drivers, such as "CUDA driver version is insufficient for CUDA runtime version," review the [NVIDIA driver matrix compatibility chart](https://docs.nvidia.com/deploy/cuda-compatibility/index.html).

## FAQ

### What happens during upgrade of a GPU-enabled node pool?

Upgrading GPU-enabled node pools follows the same rolling upgrade pattern that's used for regular node pools. For the upgrade to succeed, Kubernetes needs to create new VMs on the physical host machine that have one or more physical GPUs available for device assignment. This availability ensures that your applications can continue running when Kubernetes schedules pods on this upgraded node.

Before you upgrade:

1. Plan for downtime during the upgrade.
1. Have one extra GPU per physical host if you're running the **Standard_NK6** or two extra GPUs if you're running **Standard_NK12**. If you're running at full capacity and don't have an extra GPU, scale down your node pool to a single node before the upgrade, then scale up after the upgrade succeeds.

### What happens if I don't have extra physical GPUs on my physical machine during an upgrade?

If you trigger an upgrade on a cluster without extra GPU resources to facilitate the rolling upgrade, the upgrade process hangs until a GPU is available. If you run at full capacity and don't have an extra GPU, scale down your node pool to a single node before the upgrade, then scale up after the upgrade succeeds.

## Next steps

- [Supported VM sizes](scale-requirements.md)
- [Use GPUs in AKS on Windows Server](../../windows-server/deploy-gpu-node-pool-22h2.md)
- [AKS overview](../../aks-overview.md)
