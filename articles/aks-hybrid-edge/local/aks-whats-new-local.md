---
title: What's new in AKS Hybrid and Edge on Azure Local
description: Learn about what's new in AKS Hybrid and Edge on Azure Local.
ms.topic: overview
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.lastreviewed: 08/13/2026
ms.custom: local

---

# What's new in AKS Hybrid and Edge on Azure Local

[!INCLUDE [hci-applies-to-23h2](../includes/hci-applies-to-23h2.md)]

This article summarizes features, improvements, and important notices for AKS on Azure Local (AKS Hybrid and Edge). It highlights release-specific updates, such as supported Kubernetes versions, platform and tooling changes, security advisories, and notable bug fixes. Use this information to help you plan upgrades and manage clusters. For details about a particular release, see the release sections that follow.

> [!NOTE]
> AKS on Azure Local requires Azure Local version 23H2 or later.

## AKS Hybrid and Edge releases

This section lists the new features and improvements in AKS in each release of Azure Local.

### Release 2607

There are no AKS-specific changes in the 2607 release. Supported Kubernetes versions, features, and deprecations for AKS on Azure Local remain the same as in release 2602.

### Release 2602

#### Kubernetes versions in 2602

The Kubernetes versions included in the 2602 release are: 1.31.12, 1.31.13, 1.32.8, 1.32.9, 1.33.4, 1.33.5.

#### Announcements for 2602

- Kubernetes version 1.30 is no longer supported.

### Release 2510

#### Announcements for 2510

- Kubernetes version 1.29 is no longer supported.
- KMS v2 is now used to encrypt the Kubernetes secret store for all new clusters created on Azure Local 2510 and later. KMS v1 continues to be used by existing clusters. For more information, see [secrets encryption](hyperconverged/encrypt-etcd-secrets.md).
- Support for [Windows Server 2019 SKU](https://techcommunity.microsoft.com/blog/containers/announcing-the-3-year-retirement-of-windows-server-2019-on-azure-kubernetes-serv/3777341) for node pools ends in March 2026.

#### Kubernetes versions in 2510

Kubernetes version 1.32 is introduced in 2510. The versions included in the 2510 release are: 1.30.13, 1.30.14, 1.31.9, 1.31.10, 1.32.5, 1.32.6.

#### Features

- The KMS v2 provider is introduced for new cluster deployments in Azure Local 2510. [KMS v2](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/) brings many improvements in performance, scalability, health check and status, and observability. These enhancements provide a reliable solution to encrypt all resources in Kubernetes clusters. When you create a new cluster after upgrading to 2510, the Kubernetes cluster is configured to use KMS v2 by default. For more information, [see the instructions here](hyperconverged/encrypt-etcd-secrets.md).

### Release 2509

#### Announcements for 2509

- Support for Kubernetes minor version 1.29 ends with this 2509 release.
- KMS v1 will be deprecated soon. We are adding support for KMS v2 in an upcoming Azure Local release. Please plan on upgrading your clusters once KMS v2 is available.
- Support for [Windows Server 2019 SKU](https://techcommunity.microsoft.com/blog/containers/announcing-the-3-year-retirement-of-windows-server-2019-on-azure-kubernetes-serv/3777341) for node pools ends in March 2026.

#### Kubernetes versions in 2509

No new Kubernetes versions were added in 2509. The versions included in the 2509 release are: 1.29.12, 1.29.13, 1.30.8, 1.30.9, 1.31.4, 1.31.5.

#### Features

- Starting with the Azure Local 2509 release, we disable the download of the Windows VHDs by default. This change helps save on bandwidth usage and reduces deployment times for customers who need only Linux-based containers. Customers who need to use Windows node pools can continue to do so by [enabling the Windows node pool feature](hyperconverged/howto-enable-windows-node-pools.md), and then performing Windows node pool-based operations.
- Increased the default OS disk size on virtual machines used as AKS nodes to 200 GB. These VMs are dynamically expanding virtual hard disks and you should [ensure sufficient physical disk space is available](/windows-server/virtualization/hyper-v/best-practices-analyzer/ensure-sufficient-physical-disk-space-is-available-when-virtual-machines-use-dynamically?source=recommendations) for the node pools that you create on AKS.

### Release 2508

#### Announcements for 2508

- Support for Kubernetes minor version 1.29 ends with the 2509 release.
- KMS v1 is deprecated. We're adding support for KMS v2 in an upcoming Azure Local release. Plan on upgrading your clusters when KMS v2 is available.

#### Kubernetes versions in 2508

The Kubernetes versions included in the 2508 release are: 1.29.12, 1.29.13, 1.30.8, 1.30.9, 1.31.4, 1.31.5.

#### Bug fixes

- Fixed an issue where cluster creation failed after kubeadm installation in the default node pool failed, due to a tdnf cache issue.

### Release 2507

> [!IMPORTANT]
> Azure Linux 2.0 (formerly CBL-Mariner) reaches its official end of life (EOL) on July 31, 2025. After this date, Azure Linux no longer receives updates, security patches, or support from the Azure Linux team. Starting with the [Azure Local 2507 release](/azure/azure-local/whats-new), AKS on Azure Local releases Azure Linux 3.0 images for all supported Kubernetes versions. To maintain security compliance and ensure continued support, migrate to [Azure Linux 3.0](/azure/azure-linux/intro-azure-linux#whats-new-with-azure-linux-30) as soon as possible by upgrading Azure Local instances to the 2507 release.
>
> Support for Kubernetes minor version 1.28 ends on August 31, 2025. Kubernetes 1.31 is introduced in the next Azure Local release.

The following Kubernetes cluster deployment and management capabilities are available:

- **Disk space exhaustion**: Fixed [issues due to disk space exhaustion on control plane VMs caused by accumulation of kube-apiserver audit logs](hyperconverged/kube-apiserver-log-overflow.md).  
- **Cluster upgrade**: Fixed AKS cluster and node pool create, scale, and upgrade issues due to unavailability of AKS VM images.
- **AKS Telemetry pod issue**: Fixed an issue in which the AKS telemetry pod consumed excess CPU and memory.
- **New checks**: Added new checks during cluster and node pool operations. These improvements allow the system to proactively detect and handle scenarios where there are insufficient IP addresses in the IP pool.
- **GPU resource allocation**: Added pre-checks for resource allocation for GPUs during Kubernetes cluster create operation.
- **Node pool improvements**: Accurate representation of node pool count and status on the Azure portal. This release also includes improvements to node pool creation and update flows to ensure that the Kubernetes cluster status accounts for corresponding node pool status.
- **Improvements to autoscaler capabilities**:
  - Fixed an issue in which secrets were updated repeatedly when the autoscaler was enabled. The fix ensures that the provider checks for an existing secret and only creates it if it's missing.
  - Fixed an issue in which you couldn't disable the autoscaler at the Kubernetes cluster level.
  - Improved conflict handling logic during cluster delete operations when the autoscaler or cluster controller tried to update or remove resources that were being changed simultaneously by another process.
  - Fixed an issue in which the node pools' minimum and maximum counts didn't get updated when the autoscaler was enabled.

#### Kubernetes versions in 2507

The Kubernetes versions supported in the 2507 release are: 1.28.12, 1.28.14, 1.29.7, 1.29.9, 1.30.3, and 1.30.4.  

### Release 2503

The following Kubernetes cluster deployment and management capabilities are available:

- **Large VM SKUs for Kubernetes node pools**: Added two new VM SKUs - `Standard_D32s_v3`: 32 vCPU, 128 GiB and `Standard_D16s_v3`: 16 vCPU, 64 GiB - to support larger node pools on an AKS cluster. For more information about supported VM sizes, see [supported scale options](hyperconverged/scale-requirements.md).
- **Improved log collection experience**: Improved log collection for AKS control plane node VMs and node pool VMs, with support for passing multiple IP addresses and SSH key or directory path. For more information, see [on-demand log collection](hyperconverged/get-on-demand-logs.md) and [az aksarc get-logs CLI](/cli/azure/aksarc#az-aksarc-get-logs).
- **Improved diagnosability**: The [Diagnostic Checker tool](hyperconverged/aks-arc-diagnostic-checker.md) automatically runs if the Kubernetes cluster creation fails, and added new test cases.
- **Improved Kubernetes cluster delete**: Fixed deletion issues; for example, due to pod disruption budgets.
- **Improved AKS image download**: Fixed issues with AKS image downloads.
- **Improved GPU support**: Improved error handling for Kubernetes cluster creation with GPU enabled node pools. Fixed known issues with attaching persistent volumes on GPU enabled node pools.

To get started with these features in the 2503 release, update your [AKSArc CLI extension](/cli/azure/aksarc) to version 1.5.37 or higher.

#### Kubernetes versions in 2503

The Kubernetes versions supported in the 2503 release are: 1.28.12, 1.28.14, 1.29.7, 1.29.9, 1.30.3, and 1.30.4.

### Release 2411

The following Kubernetes cluster deployment and management capabilities are available:

- **Workload Identity (preview)**. You can now deploy AKS clusters with workload identity enabled and deploy application pods with the workload identity label to access Microsoft Entra ID protected resources, such as Azure Key Vault. For more information, see [Deploy and configure Workload Identity](hyperconverged/workload-identity.md).
- **Arc Gateway integration (preview)**. You can now deploy AKS clusters with pod-level Arc Proxy and communicate with the Arc gateway, reducing the list of outbound URLs to configure in an isolated network environment. For more information, see [Simplify network configuration requirements with Azure Arc Gateway](hyperconverged/arc-gateway-aks-arc.md).
- **Control Plane IP**. You can now deploy AKS clusters without specifying the control plane IP. The IP address is assigned automatically. For more information, see [this section in the network system requirements article](hyperconverged/network-system-requirements.md#logical-networks-for-aks-vms-and-control-plane-ip).
- **Disable Windows image download**. You can now disable Windows image downloads by disabling the Windows node pool after cluster creation, reducing network traffic over HTTP connections and providing better support for low bandwidth environments. For more information, see [Disable Windows nodepool feature on Azure Local](hyperconverged/disable-windows-nodepool.md).
- **Terraform (preview)**. You can now create AKS clusters with Terraform modules and smart defaults. For more information, see [Create clusters using Terraform](create-clusters-terraform.md).
- **Error handling**. Error handling is now improved to prevent logical network deletions with dependent cluster resources, GPU misconfigurations, and more.

To get started with these features in the 2411 release, update your [AKSArc CLI extension](/cli/azure/aksarc) to version 1.4.23 or higher.

#### Kubernetes versions in 2411

The Kubernetes versions supported in the 2411 release are 1.27.7, 1.27.9, 1.28.5, 1.28.9, 1.29.2, and 1.29.4.

### Release 2408

The following Kubernetes cluster deployment and management capabilities are available:

- **High availability improvements**. You can now deploy nodes with anti-affinity on specific physical hosts on Azure Local clusters. For more information, see [Availability sets](hyperconverged/availability-sets.md).
- **PowerShell**. You can now use PowerShell cmdlets to manage your AKS clusters on Azure Local with CRUD support. For more information, see the [PowerShell reference documentation](/powershell/module/az.aksarc/?view=azps-12.1.0&preserve-view=true).
- **Error report improvements**. You can now get improved error case reporting with prechecks; for example, a check for incorrect Kubernetes versions and available GPU capacity.
- **Support for NVIDIA T4**. You can now create node pools in new VM sizes with GPU NVIDIA T4. For more information, see [Use GPUs](hyperconverged/deploy-gpu-node-pool.md).
- **Arc Gateway**. You can now use the Arc Gateway to configure a few of the outbound URLs to use AKS clusters on Azure Local.
- **Support pod CIDR**. You can now create an AKS cluster with a user-specified pod CIDR IP range.

#### Supported component versions for 2408

| Component           | Version                                       |
|---------------------|--------------------------------------------------|
| AKS             | 1.3.218                                     |
| Kubernetes versions | 1.27.7, 1.27.9, 1.28.5, 1.28.9, 1.29.2, 1.29.4 |

### Release 2405

The following Kubernetes cluster deployment and management capabilities are available:

- **Azure RBAC support**. You can now enable Azure RBAC for Kubernetes while creating AKS clusters by using Azure CLI and Azure Resource Manager templates.
- **Taints and labels update**. You can now update taints and labels during an AKS node pool update operation by using Azure CLI and Azure Resource Manager templates.
- **AKS cluster platform metrics and alerts**. You can now view AKS cluster metrics (platform metrics) and create metric-based alerts.
- **Auto cert repair**. You can now automatically repair certificates, managed by cert-tattoo, that expired when the cluster was shut down.
- **Download VHDs manually (offline download)**. This feature, now available only in private preview, enables you to download virtual machine images and upload them to the target center by using a manual process. This feature can help in environments in which downloading large files is inconvenient. If you're interested in using it, contact your Microsoft Account representative.

#### Supported component versions for 2405

The following component versions are supported in release 2405:

| Component           | Version                                       |
|---------------------|--------------------------------------------------|
| AKS             | 1.0.23.10605                                     |
| Kubernetes versions | 1.26.10, 1.26.12, 1.27.7, 1.27.9, 1.28.3, 1.28.5 |

### Release 2402

The following Kubernetes cluster deployment and management capabilities are available:

- **Autoscaling**. You can now enable the autoscaling feature when you create or update Kubernetes clusters and node pools.
- **Support for NVIDIA A16**. You can now create node pools in new VM sizes with GPU NVIDIA A16. For more information, see [Use GPUs for compute-intensive workloads](hyperconverged/deploy-gpu-node-pool.md).
- **Diagnostic settings**. You can export audit logs and other control plane logs to one or more destinations. For more information, see [Diagnostic settings in Azure Monitor](/azure/azure-monitor/essentials/diagnostic-settings).
- **Certificate expiration**. You can now shut down Kubernetes clusters for up to seven days without any certificate expiration issues.
- **Update status**. You can now view the status of ongoing Kubernetes cluster upgrades.

<!-- ### Release 2311.2

AKS Hybrid and Edge on Azure Local is generally available starting with this release.

The following Kubernetes cluster deployment and management capabilities are available:

- **New CLI extension and Azure portal experience**. The new GA version of the Azure CLI extension starting with this release is [**az aksarc**](/cli/azure/aksarc). For more information, see [Create Kubernetes clusters using Azure CLI](aks-create-clusters-cli.md). You can also see the new portal cluster creation experience in [Create Kubernetes clusters using the Azure portal](aks-create-clusters-portal.md).  
- **Support for logical networks**. Starting with this release, creating Kubernetes clusters on Azure Local requires [logical networks](/azure/azure-local/manage/create-logical-networks?tabs=azurecli) as a prerequisite. For more information, see [How to create logical networks](hyperconverged/aks-networks.md).
- **Available K8S versions and VM sizes**. You can use [`az aksarc get-versions`](/cli/azure/aksarc#az-aksarc-get-versions) and [`az aksarc vmsize list`](/cli/azure/aksarc/vmsize#az-aksarc-vmsize-list) to get the available Kubernetes versions and VM sizes on your system.
- **Support for Taints and labels**. See [Manage node pools](hyperconverged/manage-node-pools.md) for a cluster, and [Use cluster labels](hyperconverged/cluster-labels.md) to set the taints and labels for node pools.
- **Support for upgrading a Kubernetes cluster using Azure CLI**. You can use the Azure CLI to upgrade a Kubernetes cluster to a newer version and apply the OS version updates. For more information, see [Upgrade a Kubernetes cluster](hyperconverged/cluster-upgrade.md).
- **Support for both disks and files for persistent volumes**. To support stateful applications, you can use the default storage class for disks, or a custom storage class that points to a specific storage path. See [Use persistent volumes](../windows-server/persistent-volume.md) and [Use Container Storage Interface (CSI) disk drivers](hyperconverged/container-storage-interface-disks.md). You can also create persistent volumes on file shares, in either SMB or NFS. For more information, see [Use Container Storage Interface (CSI) file drivers](hyperconverged/container-storage-interface-files.md).
- **Support for NVIDIA A2**. You can now create node pools with new VM sizes with GPU NVIDIA A2. For more information, see [Use GPUs for compute-intensive workloads](hyperconverged/deploy-gpu-node-pool.md).

### Release 2311

Starting with this release, you can run Azure Kubernetes Service (AKS) workloads on your Azure Local instance. AKS on Azure Local uses Azure Arc to create new Kubernetes clusters on Azure Local directly from Azure.

The following Kubernetes cluster deployment and management capabilities are available:

- **Simplified infrastructure deployment on Azure Local**. In this release, the infrastructure components of AKS, including the Arc Resource Bridge, Custom Location, and the Kubernetes Extension for the AKS operator, are all deployed as part of the Azure Local deployment. For more information, see [Deploy an Azure Local instance using the Azure portal](/azure/azure-local/deploy/deploy-via-portal).
- **Integrated infrastructure upgrade on Azure Local**. The whole lifecycle management of AKS infrastructure follows the same approach as the other components on Azure Local. For more information, see [Infrastructure component updates](../infrastructure-components.md).
- **New CLI consistent with Azure**. Starting with this release, a new consistent command-line experience is available to create and manage Kubernetes clusters.
- **Cloud-based management**. You can now create and manage Kubernetes clusters on Azure Local with familiar tools such as the Azure portal and Azure CLI. For more information, see [Create Kubernetes clusters using Azure CLI](aks-create-clusters-cli.md).
- **Support for Azure Container Registry to deploy container images**. In this release, you can deploy container images from a private container registry using Azure Container Registry to your Kubernetes clusters running on Azure Local. For more information, see [Deploy from private container registry to on-premises Kubernetes](hyperconverged/deploy-container-registry.md).
- **Support for managing and scaling the node pools**. For more information, see [Manage multiple node pools in AKS](hyperconverged/manage-node-pools.md).
- **Support for Linux and Windows Server containers**. For more information, see [Create Windows Server containers](../aks-create-containers.md). -->

## Next steps

- [Review AKS on Azure Local prerequisites](hyperconverged/network-system-requirements.md)
