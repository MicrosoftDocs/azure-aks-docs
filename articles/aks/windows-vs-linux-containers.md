---
title: Windows Container Considerations in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: See the Windows container considerations with Azure Kubernetes Service (AKS).
ms.topic: overview
ms.custom: linux-related-content
ms.date: 07/07/2025
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cloud administrator using Azure Kubernetes Service, I want to understand the differences between Windows and Linux containers, so that I can effectively manage deployments and ensure compatibility in my containerized environment.
---

# Windows container considerations with Azure Kubernetes Service

When you create deployments that use Windows Server containers on Azure Kubernetes Service (AKS), there are a few differences relative to Linux deployments you should keep in mind. For a detailed comparison of the differences between Windows and Linux in upstream Kubernetes, see [Windows containers in Kubernetes](https://kubernetes.io/docs/concepts/windows/intro/).

Some of the major differences include:

- **Identity**: Windows Server uses a larger binary security identifier (SID) that's stored in the Windows Security Access Manager (SAM) database. This database isn't shared between the host and containers or between containers.
- **File permissions**: Windows Server uses an access control list based on SIDs rather than a bitmask of permissions and UID+GID.
- **File paths**: The convention on Windows Server is to use \ instead of /. In pod specs that mount volumes, specify the path correctly for Windows Server containers. For example, rather than a mount point of */mnt/volume* in a Linux container, specify a drive letter and location such as */K/Volume* to mount as the *K:* drive.

> [!NOTE]
>
> - Windows Server 2022 retires after Kubernetes version 1.34 reaches end of support and won't be supported in Kubernetes version 1.35 and above.
> - Windows Server 2019 retires after Kubernetes version 1.32 reaches end of support and won't be supported in Kubernetes version 1.33 and above.
>
> For more information, see [AKS release notes][aks-release-notes]. To stay up to date on the latest Windows Server OS versions and learn more about our roadmap of what's planned for support on AKS, see our [AKS public roadmap](https://github.com/azure/aks/projects/1).

This article covers important considerations to keep in mind when using Windows containers instead of Linux containers in Kubernetes. For an in-depth comparison of Windows and Linux containers, see [Comparison with Linux][comparison-with-linux].

## Considerations

| Feature | Windows considerations |
|-----------|:-----------|
| [Cluster creation][cluster-configuration] | • The first system node pool *must* be Linux.<br/> • The maximum number of nodes per cluster is 5000.<br/> • The Windows Server node pool name has a limit of six characters. |
| [Privileged containers][privileged-containers] | Not supported. The equivalent is **HostProcess Containers (HPC) containers**. |
| [HPC containers][hpc-containers] | • HostProcess containers are the Windows alternative to Linux privileged containers. For more information, see [Create a Windows HostProcess pod](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/). |
| [Azure Network Policy Manager (Azure)][azure-network-policy] | Azure Network Policy Manager doesn't support:<br/> • Named ports<br/> • SCTP protocol<br/> • Negative match labels or namespace selectors (all labels except "debug=true")<br/> • "except" CIDR blocks (a CIDR with exceptions)<br/> • Windows Server 2019<br/> |
| [Node upgrade][node-upgrade] | Windows Server nodes on AKS don't automatically apply Windows updates. Instead, you perform a node pool upgrade or [node image upgrade][node-image-upgrade]. These upgrades deploy new nodes with the latest Window Server 2019 and Windows Server 2022 base node image and security patches. |
| [AKS Image Cleaner][aks-image-cleaner] | Not supported. |
| [BYOCNI][byo-cni] | Not supported. |
| [Open Service Mesh][open-service-mesh] | Not supported. |
| [GPU][gpu] | Supported in preview. |
| [Multi-instance GPU][multi-instance-gpu] | Not supported. |
| [Generation 2 VMs][gen-2-vms] | Supported. Default in Windows Server 2025. |
| [Custom node config][custom-node-config] | • Custom node config has two configurations:<br/> • [kubelet][custom-kubelet-parameters]: Supported.<br/> • OS config: Not supported. |

## Next steps

For more information on Windows containers, see the [Windows Server containers FAQ][windows-server-containers-faq].

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[comparison-with-linux]: https://kubernetes.io/docs/concepts/windows/intro/#compatibility-linux-similarities

<!-- LINKS - internal -->
[cluster-configuration]: quotas-skus-regions.md#cluster-configuration-presets-in-the-azure-portal
[privileged-containers]: use-windows-hpc.md#limitations
[hpc-containers]: use-windows-hpc.md#limitations
[node-upgrade]: ./manage-node-pools.md#upgrade-a-single-node-pool
[aks-image-cleaner]: image-cleaner.md#limitations
[windows-server-containers-faq]: windows-faq.yml
[azure-network-policy]: use-network-policies.md#overview-of-network-policy
[node-image-upgrade]: node-image-upgrade.md
[byo-cni]: use-byo-cni.md
[open-service-mesh]: open-service-mesh-about.md
[gpu]: use-windows-gpu.md
[multi-instance-gpu]: gpu-multi-instance.md
[gen-2-vms]: generation-2-vm.md
[custom-node-config]: custom-node-configuration.md
[custom-kubelet-parameters]: custom-node-configuration.md#kubelet-custom-configuration
