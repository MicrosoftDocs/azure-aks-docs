---
title: Use NVIDIA GPU Operator on Azure Kubernetes Service (AKS)
description: Learn how to install the NVIDIA GPU Operator for advanced GPU deployments on AKS.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 04/18/2025
author: sachidesai
ms.author: schaffererin

# Customer intent: As a cluster administrator or developer, I want to deploy the NVIDIA GPU Operator on my AKS cluster, so that I can efficiently manage GPU resources and optimize workloads for advanced AI and high-performance computing applications.
---

# Use NVIDIA GPU Operator on Azure Kubernetes Service (AKS)

The NVIDIA GPU Operator automates the management and deployment of all NVIDIA software components needed to provision GPU including driver installation, the [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file), the NVIDIA container runtime, and more. Since the NVIDIA GPU Operator handles these components, it's not necessary to separately install the NVIDIA device plugin on your AKS cluster. This also means that the automatic GPU driver installation should be skipped in order to use the NVIDIA GPU Operator on AKS.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.72.2 or later installed to set the `--gpu-driver` field. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Limitations

- NVIDIA GPU Operator isn't supported for the following OS options: Windows Server versions, [Flatcar Container Linux for AKS (preview)][flatcar], and [Azure Linux with OS Guard for AKS (preview)][os-guard].



## Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the cluster `myAKSCluster` in the `myResourceGroup` resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

> [!NOTE]
> The NVIDIA GPU Operator is not compatible with multiple OS versions on the same AKS cluster.

1. Skip automatic GPU driver installation by creating an NVIDIA GPU-enabled node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command and setting the API field `--gpu-driver` to the value `none`. Setting this API field to `none` during node pool creation skips the default GPU driver installation, see [this example](gpu-cluster.md#skip-gpu-driver-installation). Any existing nodes aren't changed. You can scale the node pool to zero and then back up to make the change take effect.

2. Follow the NVIDIA documentation to [Install the GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html).

3. Now that you successfully installed the GPU Operator, you can check that your [GPUs are schedulable](gpu-cluster.md#confirm-that-gpus-are-schedulable) and [run a GPU workload](gpu-cluster.md#run-a-gpu-enabled-workload).

> [!NOTE]
> There might be additional considerations to take when using the NVIDIA GPU Operator and deploying on SPOT instances. Please refer to <https://github.com/NVIDIA/gpu-operator/issues/577>


## Next steps

- [Monitor NVIDIA GPU metrics](monitor-gpu-metrics.md) using Azure Managed Prometheus and Azure Managed Grafana.
- Learn more about [Ray clusters on AKS](ray-overview.md).

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./use-azure-linux-os-guard.md
[azure-pricing]: ./free-standard-pricing-tiers.md
[azure-availability]: ./quotas-skus-regions.md
[install-azure-cli]: /cli/azure/install-azure-cli