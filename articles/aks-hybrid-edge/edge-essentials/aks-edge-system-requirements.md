---
title: AKS Edge Essentials system requirements 
description: Requirements and supported versions for AKS Edge Essentials. 
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: limits-and-quotas
ms.date: 09/01/2026
ms.custom: template-concept, edge-essentials
---

# AKS Edge Essentials requirements and support matrix

This article describes the requirements for the host machine that runs AKS Edge Essentials.

## Hardware requirements

  | Specs | Local cluster | Arc-connected cluster and GitOps|
  | ---------- | --------- |--------- |
  | Host OS | Windows 10/11 IoT Enterprise/Enterprise/Pro and Windows Server 2019, 2022||
  | Total physical memory | 4 GB with at least 2.5 GB free | 8 GB with at least 4.5 GB free  |
  | CPU | 2 vCPUs, clock speed at least 1.8 GHz |4 vCPUs, clock speed at least 1.8 GHz|
  | Disk space | At least 14 GB free |At least 19 GB free |
  | Disk type| SSD | SSD |

To better understand the concept of vCPUs, [see this article](https://social.technet.microsoft.com/wiki/contents/articles/1234.hyper-v-concepts-vcpu-virtual-processor-q-a.aspx).

To better understand the etcd hardware recommendations, [see this article](https://etcd.io/docs/v3.5/op-guide/hardware/).

You can run AKS Edge Essentials in an Azure VM. You can create a Windows VM with either Windows 10/11 IoT Enterprise/Enterprise/Pro and Windows Server 2019, 2022 SKU, on a VM image that supports nested virtualization such as the [Dv5 and Dsv5-series](/azure/virtual-machines/dv5-dsv5-series) virtual machines. When using an Azure VM, a premium SSD is required, per the [Azure Virtual Machine documentation](/azure/virtual-machines/disks-types#disk-type-comparison). 

You can also run AKS Edge Essentials in a virtual machine on VMware and Hyper-V as described [here.](./aks-edge-howto-setup-nested-environment.md)

### OS requirements

Install Windows 10/11 IoT Enterprise/Enterprise/Pro on your machine and activate Windows. We recommend using the latest [client version 22H2 (OS build 19045)](/windows/release-health/release-information) or [Server 2022 (OS build 20348)](/windows/release-health/windows-server-release-info). You can [download a version of Windows 10 here](https://www.microsoft.com/software-download/windows10) or [Windows 11 here](https://www.microsoft.com/software-download/windows11).

> [!NOTE]
> Windows 10 IoT Enterprise, Windows 11 IoT Enterprise, and Windows Server 2022 IoT Enterprise are binary-equivalent to the non-IoT releases, differing in [licensing and distribution](/windows/iot/iot-enterprise/getting_started).

## Maximum hardware specifications supported

| Parameter | Permissible limit |
| ---------- | --------- |
| Maximum number of VMs per machine  | 1 Linux VM + 1 Windows VM (optional) |
| Maximum number of vCPUs assigned to virtual machines  | 16 vCPUs |
| Maximum number of machines per cluster | 15 machines |

> [!NOTE]
> The vCPU limit is per-host, not per-node.

## GA feature support matrix

- **Supported Kubernetes distribution**: currently supported Kubernetes versions on both K3s and K8s [are described in this table](aks-edge-howto-setup-machine.md#download-aks-edge-essentials).
- **Deployment options**: single-machine clusters and full Kubernetes deployment on single machines only. Full deployment across multiple machines isn't supported in GA.
- **Workloads**: only Linux worker nodes.
- **Network plugins**: Calico on K8s, Flannel on K3s.
- **Secret encryption**: [KMS provider for AKS Edge Essentials](aks-edge-howto-secret-encryption.md).

## Experimental or prerelease features

- **Deployment options**: Full Kubernetes deployment on multiple machines.
- **Workloads**: Windows worker nodes.
- **GPU**: [GPU-PV](aks-edge-gpu.md).
- **Secret Encryption**: [KMS plugin for AKS Edge Essentials](aks-edge-howto-secret-encryption.md).
- **Security**: [Workload identity](aks-edge-workload-identity.md). Workload identity federation is only available for deployment of Azure IoT Operations on top of AKS Edge Essentials.
- **Network plugins**: Calico on K3S (discontinued).

## Next steps

- [Set up your machine](aks-edge-howto-setup-machine.md)
