---
title: Use NVIDIA GPU Operator on Azure Kubernetes Service (AKS)
description: Learn how to install the NVIDIA GPU Operator for advanced GPU deployments on AKS.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 04/18/2025
author: sachidesai

#Customer intent: As a cluster administrator or developer, I want to create an AKS cluster that can use high-performance GPU-based VMs and configure them for advanced AI or HPC workload deployments using the NVIDIA GPU Operator.
---

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.0.64 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the *myAKSCluster* in the *myResourceGroup* resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Use NVIDIA GPU Operator with AKS

The NVIDIA GPU Operator automates the management of all NVIDIA software components needed to provision GPU including driver installation, the [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file), the NVIDIA container runtime, and more. Since the GPU Operator handles these components, it's not necessary to manually install the NVIDIA device plugin. This also means that the automatic GPU driver installation on AKS is not required to use the NVIDIA GPU Operator.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

> [!NOTE]
> The NVIDIA GPU Operator is not compatible with multiple OS versions on the same AKS cluster.

1. Skip automatic GPU driver installation (preview) by creating an NVIDIA GPU-enabled node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with `--skip-gpu-driver-install`. Adding the `--skip-gpu-driver-install` flag during node pool creation skips the automatic GPU driver installation, see [this example](gpu-cluster.md#skip-gpu-driver-installation-preview). Any existing nodes aren't changed. You can scale the node pool to zero and then back up to make the change take effect.

2. Follow the NVIDIA documentation to [Install the GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html).

3. Now that you successfully installed the GPU Operator, you can check that your [GPUs are schedulable](gpu-cluster.md#confirm-that-gpus-are-schedulable) and [run a GPU workload](gpu-cluster.md#run-a-gpu-enabled-workload).

> [!NOTE]
> There might be additional considerations to take when using the NVIDIA GPU Operator and deploying on SPOT instances. Please refer to <https://github.com/NVIDIA/gpu-operator/issues/577>


## Next steps

- [Monitor NVIDIA GPU metrics](monitor-gpu-metrics.md) using Azure Managed Prometheus and Azure Managed Grafana.
- Learn more about [Ray clusters on AKS](ray-overview.md).