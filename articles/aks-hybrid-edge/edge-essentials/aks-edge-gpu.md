---
title: GPU acceleration for AKS Edge Essentials (preview)
description: Learn how to expose a GPU to the virtual machine's Linux module.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 06/05/2024
ms.reviewer: guanghu
ms.custom: edge-essentials

# Intent: As an IT Pro, I want to learn how to expose a GPU to Linux
# Keyword: GPU AKS Edge Essentials
---

# Use GPU acceleration for AKS Edge Essentials (preview)

> [!IMPORTANT]
> GPU acceleration for AKS Edge Essentials is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

GPUs are a popular choice for artificial intelligence computations, because they offer parallel processing capabilities and can often execute vision-based inferencing faster than CPUs. To better support artificial intelligence and machine learning applications, AKS Edge Essentials can expose a GPU to the virtual machine's Linux module.

AKS Edge Essentials supports *GPU-Paravirtualization* (GPU-PV) as the GPU passthrough technology. In other words, the GPU is shared between the Linux virtual machine and the host.

> [!IMPORTANT]
> These features include components developed and owned by NVIDIA Corporation or its licensors. By using GPU acceleration features, you are accepting and agreeing to the terms of the [NVIDIA End-User License Agreement](https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us).

## Prerequisites

The GPU acceleration of AKS Edge Essentials currently supports a specific set of GPU hardware. Additionally, use of this feature requires specific versions of Windows.

The supported GPUs and required Windows versions are as follows:

| Supported GPUs          | GPU passthrough type | Supported Windows versions                  |
|-----------------------------|--------------------------|-------------------------------------------------|
| NVIDIA GeForce, Quadro, RTX | GPU-PV                   | Windows 10/11 (Pro, Enterprise, IoT Enterprise) |

> [!IMPORTANT]
> GPU-PV support might be limited to certain generations of processors or GPU architectures, as determined by the GPU vendor. For more information, see the [NVIDIA CUDA for WSL documentation](https://developer.nvidia.com/cuda/wsl).
>
> Windows 10 users must use the November 2021 update build 19044.1620, or later. After installation, you can verify your build version by running `winver` at the command prompt.
>
> GPU passthrough is not supported with nested virtualization, such as when you run AKS Edge Essentials in a Windows virtual machine.

## System setup and installation

The following sections contain setup and installation information.

- For **NVIDIA GeForce/Quadro/RTX GPUs**, download and install the [NVIDIA CUDA-enabled driver for Windows Subsystem for Linux (WSL)](https://developer.nvidia.com/cuda/wsl) to use with your existing CUDA ML workflows. Originally developed for WSL, the CUDA for WSL drivers is also used for AKS Edge Essentials.
- Windows 10 users must also [install WSL](/windows/wsl/install) because some of the libraries are shared between WSL and AKS Edge Essentials.
- Install or upgrade AKS Edge Essentials to the May 2024 release, or later. For more information, see [Update your AKS Edge Essentials clusters](aks-edge-howto-update.md). The GPU-PV is supported on both k8s and k3s Kubernetes distributions.

## Enable GPU-PV in your AKS Edge Essentials deployment

### Step 1: single machine configuration parameters

You can generate the parameters you need to create a single machine cluster and add the necessary GPU-PV configuration parameters using the following commands.

This script only focuses on the GPU-PV configuration; you should also make other necessary general updates according to your own AKS Edge Essentials deployment:

```powershell
$jsonObj = New-AksEdgeConfig -DeploymentType SingleMachineCluster
$jsonObj.User.AcceptGpuWarning = $true
$machine = $jsonObj.Machines[0]
$machine.LinuxNode.GpuPassthrough.Name = "NVIDIA GeForce GTX 1070"
$machine.LinuxNode.GpuPassthrough.Type = "ParaVirtualization"
$machine.LinuxNode.GpuPassthrough.Count = 1
```

The key parameters to enable GPU-PV are:

- `User.AcceptGpuWarning`: Set this parameter to `true` to automatically accept the confirmation message when you enable GPU-PV on AKS Edge Essentials.
- `LinuxNode.GpuPassthrough.Name`: Describes the GPU model that's deployed in this machine, with proper drivers installed.
- `LinuxNode.GpuPassthrough.Type`: Describes the GPU passthrough type. Only `ParaVirtualization` is currently supported.
- `LinuxNode.GpuPassthrough.Count`: Describes how many GPUs are installed on this machine.

### Step 2: create a single machine cluster

1. You can now run the `New-AksEdgeDeployment` cmdlet to deploy a single-machine AKS Edge cluster with a single Linux control plane node. You can use the JSON object generated in [step 1](#step-1-single-machine-configuration-parameters) and pass it as a string:

   ```powershell
   New-AksEdgeDeployment -JsonConfigString (New-AksEdgeConfig | ConvertTo-Json -Depth 4)
   ```

1. After successful deployment, verify GPU-PV is enabled by running `nvidia-smi`:

   :::image type="content" source="../media/aks-edge-gpu/gpu-pv-enabled.png" alt-text="Screenshot showing NVIDIA smi output." lightbox="../media/aks-edge-gpu/gpu-pv-enabled.png":::

### Step 3: Deploy Nvidia runtimeclass

1. Create a YAML file named **nvidia-runtimeclass.yaml** with the following content:

   ```yaml
   apiVersion: node.k8s.io/v1
   kind: RuntimeClass
   metadata:
     name: nvidia
   handler: nvidia
   ```

1. Deploy the `runtimeclass`:

   ```powershell
   kubectl apply –f nvidia-runtimeclass.yaml
   ```

### Step 4: Install Nvidia GPU device plugin

1. Download **nvidia-deviceplugin.yaml** from [this GitHub location](https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.3/nvidia-device-plugin.yml).
1. Update the container images location in the **nvidia-deviceplugin.yaml** file to the new value, as follows:

   ```yaml
   containers:
   - image: registry.gitlab.com/nvidia/kubernetes/device-plugin/staging/k8s-device-plugin:6a31a868
   ```

1. Install the Nvidia GPU DevicePlugin:

   ```powershell
   kubectl apply –f nvidia-deviceplugin.yaml
   ```

1. Verify that the plugin is running and the NVIDIA GPU is detected by checking the logs of the **deviceplugin** pod using the `kubectl get pods -A` and `kubectl logs $podname -n kube-system` commands:

   :::image type="content" source="../media/aks-edge-gpu/kubectl-logs.png" alt-text="Screenshot showing kubectl logs command output." lightbox="../media/aks-edge-gpu/kubectl-logs.png":::

## Get started with a sample workload

1. Prepare a workload YAML file named **gpu-workload.yaml**:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: gpu-pod
   spec:
     restartPolicy: Never
     containers:
       - name: cuda-container
         image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda10.2
         resources:
           limits:
             nvidia.com/gpu: 1 # requesting 1 GPU
     tolerations:
     - key: nvidia.com/gpu
       operator: Exists
       effect: NoSchedule
   ```

1. Run the sample workload:

   ```powershell
   kubectl apply -f .\gpu-workload.yaml
   ```

1. Verify that the workload ran successfully:

   :::image type="content" source="../media/aks-edge-gpu/workload.png" alt-text="Screenshot showing that the workload ran successfully." lightbox="../media/aks-edge-gpu/workload.png":::

## Next steps

[AKS Edge Essentials overview](aks-edge-overview.md)
