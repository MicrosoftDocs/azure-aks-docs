---
title: Use GPUs for compute-intensive workloads in AKS on Windows Server
description: Learn how to deploy GPU-enabled node pools in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 03/21/2023
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to deploy GPU-enabled node pools
# Keyword: Run GPU workloads on Kubernetes
---

# Use GPUs for compute-intensive workloads in AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Graphical Processing Units (GPU) are used for compute-intensive workloads such as machine learning, deep learning, and more. This article describes how to use GPUs for compute-intensive workloads in AKS on Windows Server.

## Before you begin

If you are updating AKS from a preview version older than October 2022 that is running GPU-enabled node pools, make sure you remove all workload clusters running GPUs before you begin. Follow the steps in this section.

### Step 1: Uninstall the Nvidia host driver

On each host machine, navigate to **Control Panel > Add or Remove programs**, uninstall the NVIDIA host driver, then reboot the machine. After the machine reboots, confirm that the driver was successfully uninstalled. Open an elevated PowerShell terminal and run the following command:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"3d video" 
```

You should see the GPU devices appear in an error state as shown in this example output:

```output
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 2: Dismount the host driver from the host

When you uninstall the host driver, the physical GPU goes into an error state. You must dismount all the GPU devices from the host.

For each GPU (3D Video Controller) device, run the following commands in PowerShell. Copy the instance ID; for example, `PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000` from the previous command output:

```powershell
$id1 = "<Copy and paste GPU instance id into this string>"
$lp1 = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $id1).Data[0]
Disable-PnpDevice -InstanceId $id1 -Confirm:$false
Dismount-VMHostAssignableDevice -LocationPath $lp1 -Force
```

To confirm that the GPUs were correctly dismounted from the host, run the following command. You should put GPUs in an `Unknown` state:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"3d video"
```

```output
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 3: Download and install the NVIDIA mitigation driver

The software might include components developed and owned by NVIDIA Corporation or its licensors. The use of these components is governed by the [NVIDIA end user license agreement](https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us).

See the [NVIDIA data center documentation](https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/) to download the NVIDIA mitigation driver. After downloading the driver, expand the archive and install the mitigation driver on each host machine.

```powershell
Invoke-WebRequest -Uri "https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/nvidia_azure_stack_inf_v2022.10.13_public.zip" -OutFile "nvidia_azure_stack_inf_v2022.10.13_public.zip"
mkdir nvidia-mitigation-driver
Expand-Archive .\nvidia_azure_stack_inf_v2022.10.13_public.zip .\nvidia-mitigation-driver\
```

To install the mitigation driver, navigate to the folder containing the extracted files, right-click the **nvidia_azure_stack_T4_base.inf** file, and select **Install**. Check that you have the correct driver; AKS currently supports only the NVIDIA Tesla T4 GPU.

You can also install using the command line by navigating to the folder and running the following commands to install the mitigation driver:

```powershell
pnputil /add-driver nvidia_azure_stack_T4_base.inf /install 
pnputil /scan-devices 
```

After you install the mitigation driver, the GPUs are listed in the **OK** state under **Nvidia T4_base - Dismounted**:

```powershell
Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"nvidia"
```

```output
OK       Nvidia T4_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
OK       Nvidia T4_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000
```

### Step 4: Repeat steps 1 to 3

Repeat steps 1 to 3 for each node in your failover cluster.

> [!IMPORTANT]
> GPU-enabled virtual machines are not added to failover clustering in Windows Server 2019 and Windows Server 2022.

## Install or update AKS

See the AKS quickstart using [PowerShell](kubernetes-walkthrough-powershell.md) or using [Windows Admin Center](setup.md) to install or update AKS on Windows Server.

## Create a new workload cluster with a GPU-enabled node pool

Currently, using GPU-enabled node pools is only available for Linux node pools.

```powershell
New-AksHciCluster -Name "gpucluster" -nodePoolName "gpunodepool" -nodeCount 2 -osType linux -nodeVmSize Standard_NK6 
```

After installing the workload cluster, run the following command to get your Kubeconfig:

```powershell
Get-AksHciCredential -Name gpucluster
```

## Confirm you can schedule GPUs

With your GPU node pool created, confirm that you can schedule GPUs in Kubernetes. First, list the nodes in your cluster using the [kubectl get nodes](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command:

```powershell
kubectl get nodes
```

```output
NAME             STATUS  ROLES                 AGE   VERSION
moc-l9qz36vtxzj  Ready   control-plane,master  6m14s  v1.22.6
moc-lhbkqoncefu  Ready   <none>                3m19s  v1.22.6
moc-li87udi8l9s  Ready   <none>                3m5s  v1.22.6
```

Now use the [kubectl describe node](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe) command to confirm that the GPUs can be scheduled. Under the **Capacity** section, the GPU should appear as **nvidia.com/gpu: 1**.

```powershell
kubectl describe <node> | findstr "gpu" 
```

The output should display the GPU(s) from the worker node and look something like this:

```output
         nvidia.com/gpu.compute.major=7
         nvidia.com/gpu.compute.minor=5
         nvidia.com/gpu.count=1
         nvidia.com/gpu.family=turing
         nvidia.com/gpu.machine=Virtual-Machine
         nvidia.com/gpu.memory=16384
         nvidia.com/gpu.product=Tesla-T4
Annotations:    cluster.x-k8s.io/cluster-name: gpucluster
                cluster.x-k8s.io/machine: gpunodepool-md-58d9b96dd9-vsdbl
                cluster.x-k8s.io/owner-name: gpunodepool-md-58d9b96dd9
         nvidia.com/gpu:   1
         nvidia.com/gpu:   1
ProviderID:         moc://gpunodepool-97d9f5667-49lt4
kube-system         gpu-feature-discovery-gd62h       0 (0%)    0 (0%)   0 (0%)      0 (0%)     7m1s
         nvidia.com/gpu   0     0
```

## Run a GPU-enabled workload

Once you complete the previous steps, create a new YAML file for testing; for example, **gpupod.yaml**. Copy and paste the following YAML into the new file named **gpupod.yaml**, then save it:

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

Upgrading GPU-enabled node pools follows the same rolling upgrade pattern that's used for regular node pools. For GPU-enabled node pools in a new VM to be successfully created on the physical host machine, it requires one or more physical GPUs to be available for successful device assignment. This availability ensures that your applications can continue running when Kubernetes schedules pods on this upgraded node.

Before you upgrade:

1. Plan for downtime during the upgrade.
2. Have one extra GPU per physical host if you are running the **Standard_NK6** or 2 extra GPUs if you are running **Standard_NK12**. If you are running at full capacity and don't have an extra GPU, we recommend scaling down your node pool to a single node before the upgrade, then scaling up after upgrade succeeds.

### What happens if I don't have extra physical GPUs on my physical machine during an upgrade?

If an upgrade is triggered on a cluster without extra GPU resources to facilitate the rolling upgrade, the upgrade process hangs until a GPU is available. If you run at full capacity and don't have an extra GPU, we recommend scaling down your node pool to a single node before the upgrade, then scaling up after the upgrade succeeds.

## Next steps

- [AKS on Windows Server overview](overview.md)
