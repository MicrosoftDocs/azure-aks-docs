---
title: Azure Kubernetes Service (AKS) Cloud, Edge, and On-Premises Comparison
description: Learn about Azure Kubernetes Service (AKS) features, capabilities, and pricing across cloud, edge, and on-premises environments to choose the best deployment for your needs.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.reviewer: rmody
ms.custom: overview
---

# Compare AKS features across cloud, edge, and on-premises platforms

Azure Kubernetes Service (AKS) is a fully managed Kubernetes platform that simplifies how organizations deploy, scale, and manage containerized applications in the cloud. As customer needs evolve to span cloud, on-premises, and edge environments, AKS expands its footprint and brings the same trusted Kubernetes capabilities to a broader range of edge and on-premises infrastructure.

With solutions like AKS on bare metal and AKS on Azure Local, organizations can now run AKS clusters closer to where their workloads and data reside, whether directly on edge hardware, in remote edge sites, or within their own datacenters, while maintaining a consistent operational and developer experience. While AKS is delivered differently across environments, the underlying platform stays aligned in its goals, behavior, and experience.

The focus is on delivering a cohesive and adaptable AKS offering that meets customers across cloud and edge, while preserving the simplicity and power that define the AKS experience.

This article describes how AKS extends features across multiple platforms and highlights the unique advantages and capabilities it brings to cloud, on-premises, and edge environments.

## General comparison of AKS across platforms

| Feature | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Supported infrastructure for Kubernetes cluster | Azure cloud | Azure Local, version 23H2 or later | - Windows 10/11 IoT Enterprise<br>- Windows 10/11 Enterprise<br>- Windows 10/11 Pro<br>- Windows Server 2019/2022 | - Windows Server 2019<br>- Windows Server 2022 |
| CNCF conformant | Yes | Yes | Yes | Yes |
| Kubernetes cluster lifecycle management tools (create, scale, upgrade, and delete clusters) | - Azure CLI<br>- Azure PowerShell<br>- Azure portal<br>- Azure Resource Manager (ARM) templates<br>- Bicep<br>- Bicep Kubernetes Provider<br>- Azure Developer CLI | - Azure portal<br>- Azure CLI<br>- ARM templates<br>- Bicep templates | PowerShell | - PowerShell<br>- Windows Admin Center |
| Kubernetes cluster management plane | AKS is a managed Kubernetes offering. The AKS control plane is hosted and managed by Microsoft. AKS worker nodes are created in customer subscriptions. | Kubernetes clusters are managed through a lightweight management appliance that's automatically created when Azure Local gets deployed. | Kubernetes clusters are self-managed, to preserve resources. | Kubernetes clusters are managed using a *management cluster* that's installed using PowerShell before you can create Kubernetes workload clusters. |
| Support for Kubectl or other open source Kubernetes tool | Yes | Yes | Yes | Yes |
| Supported K8s versions | Continuous updates to supported Kubernetes versions. For the latest version support, run [az aks get-versions](/cli/azure/aks#az_aks_get_versions). | Supports K8s only.<br>For the latest version support, run [az aksarc get-versions](/cli/azure/aks#az_aks_get_versions). | Supports K3s and K8s. For the latest K8s version support, see [steps to prepare your machine for AKS Edge Essentials](edge-essentials/aks-edge-howto-setup-machine.md#download-aks-edge-essentials). | - Supports K8s only.<br>- Continuous updates to supported Kubernetes versions. For the latest version support, see [AKS hybrid releases on GitHub](https://github.com/Azure/aksArc/releases). |
| Azure Fleet Manager integration | Yes | No | No | No |
| Terraform integration | Yes | Yes (Preview) | No | No |
| Support for Taints and Labels | Yes | Yes | Not validated. These settings don't persist when cluster is upgraded. | Yes |
| AKS automatic | Yes | No | No | No |

## Monitoring and diagnostic capabilities

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
|     Azure Monitor Container Insights     |     Yes    |     Yes, via Arc extensions    |     Yes, via Arc extensions    |     Yes, via Arc extensions    |
|     Azure Monitor Managed Prometheus and control plane metrics scraping     |     Yes    |     Yes, via Arc extensions    |     Yes, via Arc extensions    |     Yes, via Arc extensions    |
|     Control plane audit logs    |     Yes    |     Yes, via Arc extensions    |     No    |     No    |
|     Platform/Shoebox metrics     |     Yes    |     Yes, via Arc extensions          |     No    |     No    |
|     Diagnostics log collection (local)    |     Yes    |     Yes    |     Yes    |     Yes    |

## Node pool capabilities

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Windows node pool support      | - Yes<br>- Windows Server 2019 Datacenter<br>- Windows Server 2022 Datacenter | - Yes<br>- Windows Server 2019 Datacenter<br>- Windows Server 2022 Datacenter | - Yes<br>- Windows Server 2022 Datacenter (Core) | - Yes<br>- Windows Server 2019 Datacenter<br>- Windows Server 2022 Datacenter |
| Linux OS offerings            | - Ubuntu 18.04<br>- Azure Linux | [Azure Linux](https://github.com/microsoft/azurelinux) | [Azure Linux](https://github.com/microsoft/azurelinux) | [Azure Linux](https://github.com/microsoft/azurelinux) |
| Container runtime             | Containerd for Linux and Windows nodes | Containerd for Linux and Windows nodes | Containerd for Linux and Windows nodes | Containerd for Linux and Windows nodes |
| Node pool auto-scaler         | - Manual<br>- Auto-scaler<br>- Horizontal pod scaler | - Manual<br>- Auto-scaler | Manual | - Manual<br>- Auto-scaler<br>- Horizontal pod scaler |
|     Azure Container Registry    |     Yes    |     Yes    |     Yes    |     Yes    |
|     Azure Container Instance     |     Yes    |     Yes    |     No    |     No    |
|     Start/stop a Kubernetes cluster    |     Yes     |     Yes    |     Yes    |     Yes    |
|     Virtual nodes     |     Yes    |     Yes    |     Yes    |     Yes    |
|     Private cluster    |     Yes    |     No    |     No    |     No    |
|     Node pool snapshot     |     Yes    |     No    |     No    |     No    |
|     Custom node configuration at deployment    |     Yes    |     Yes    |     Yes    |     Yes    |
|     SSH to nodes    |     Yes    |     Yes    |     Yes    |     Yes    |
|     Availability zones    |     Yes    |     No    |     No    |     No    |
|     Proximity placement groups    |     Yes    |     No    |     No    |     No    |

## Networking capabilities

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Network creation and management | By default, Azure creates a virtual network and subnet for you. You can also choose an existing virtual network in which to create your AKS clusters. | Setting up networking parameters is a required prerequisite to deploy AKS on Azure Local. Network must have connectivity and IP address availability for successful operation of the cluster. | You must provide the IP address range for node IPs and service IPs that are available and have the right connection. The network configuration needed for the cluster is handled by AKS. See [AKS Edge Essentials networking](edge-essentials/aks-edge-concept-networking.md). | You must create the network in Windows Server before creating an AKS cluster. Network must have connectivity and IP address availability for successful operation of the cluster. |
| Supported networking option    | Bring your own Azure virtual network for AKS clusters. | Static IP networks with or without VLAN ID. | Static IP address or use reserved IPs when using DHCP. | - DHCP networks with or without VLAN ID.<br>- Static IP networks with or without VLAN ID. |
| SDN support                   | Not applicable since the cluster runs on Azure. | No                    | No                                              | Yes                  |
| Support for Arc Gateway        | N/A (works with Azure Application Gateway) | Yes                        | Yes – support for Azure IoT Operations only                    | No                   |
| Supported CNIs                | - Azure CNI<br>- Calico<br>- Azure CNI overlay (Cillium)<br>- Bring your own CNI | Calico                     | - Calico (K8s)<br>- Flannel (K3s)                   | Calico               |
| Service Mesh                  | Istio add-on      | Open Service Mesh, via Arc extensions. | Open Service Mesh, via Arc extensions.           | Open Service Mesh, via Arc extensions. |
| Load Balancer                 | - Azure load balancer – Basic SKU or Standard SKU<br>- Internal load balancer<br>- Bring your own load balancer (BYOLB) | - Bring your own load balancer (BYOLB)<br>- MetalLB Arc Extension | - KubeVIP<br>- Bring your own load balancer (BYOLB) | - HAProxy<br>- SDN load balancer<br>- Bring your own load balancer (BYOLB) |

## Storage features

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Types of supported persistent volumes | - Read Write Once<br>- Read Write Many                                         | - VHDX – Read Write Once<br>- SMB or NFS – Read Write Many<br>- ACSA - Read Write Many                             | - PVC using local storage<br>- ACSA                 | - VHDX – Read Write Once<br>- SMB or NFS - Read Write Many |
| Container storage interface (CSI) support | Yes                                                                      | Yes                                                                                                    | Yes                                             | Yes                                         |
| CSI drivers                       | - Azure Storage<br>- Azure Files and Azure Disk<br>- Premium CSI drivers deployed by default. | Disk and file (SMB and NFS) drivers installed by default.                                             | Support for SMB and NFS storage drivers.        | Support for SMB and NFS storage drivers.     |
| Dynamic provisioning support      | Yes                                                                      | Yes                                                                                                    | Yes                                             | Yes                                         |
| Volume resizing support           | Yes                                                                      | Yes                                                                                                    | Yes                                             | Yes                                         |
| Volume snapshots support          | Yes                                                                      | No                                                                                                     | No                                              | No                                          |

## Security and authentication options

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Access to Kubernetes cluster             | Kubectl         | Kubectl                   | Kubectl                                         | Kubectl              |
| Kubernetes cluster authorization (RBAC)  | - Kubernetes RBAC<br>- Azure RBAC | - Kubernetes RBAC<br>- Azure RBAC | Kubernetes RBAC                                 | Kubernetes RBAC      |
| Kubernetes cluster authentication        | - Certificate-based Kubeconfig<br>- Microsoft Entra ID | - Certificate-based Kubeconfig<br>- Microsoft Entra ID | Certificate-based Kubeconfig<br>- Microsoft Entra ID | - Certificate-based Kubeconfig<br>- Microsoft Entra ID |
| Support for network policies      | Yes             | No                        | No                                              | Yes – only for Linux containers |
| Support for workload identity     | Yes             | Yes                       | Yes - (Support for AIO only)                    | Yes                  |
| Limit source networks that can access API server | Yes | Yes | Yes | Yes |
| Encrypt etcd secrets              | Yes             | Yes                       | Yes                                             | Yes                  |
| Certificate rotation and encryption | Yes           | Yes                       | Yes                                             | Yes                  |
| Secrets store CSI driver          | Yes             | Yes                       | Yes                                             | Yes                  |
| gMSA support                      | Yes             | No                        | Yes                                             | Yes                  |
| Azure Policy                      | Yes             | Yes, via Arc extensions   | Yes, via Arc extensions                         | Yes, via Arc extensions |
| Azure Defender                    | Yes             | Yes, via Arc extensions (preview) | Yes, via Arc extensions (preview)         | Yes, via Arc extensions (preview) |

## Pricing and SLA details

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| Pricing                           | - Unlimited free clusters, pay for on-demand compute of worker node VMs.<br>- Paid tier available with uptime SLA, support for 5k nodes. | Included in Azure Local at no extra cost.  | Cost is per device per month.                        | Pricing is based on the number of workload cluster vCPUs. Control plane nodes and load balancer VMs are free. |
| Azure Hybrid Benefit support       | Not applicable                                                                            | Not applicable - AKS already included at no extra cost. | No                                              | Yes                                                               |
| SLA                               | Paid uptime SLA clusters for production with fixed cost on the API + worker node compute, storage and networking costs. | No SLA offered as the Kubernetes cluster is running on premises. | No SLA offered as the Kubernetes cluster is running on premises. | No SLA offered as the Kubernetes cluster is running on premises.           |

### AI and machine learning capabilities offered in each platform

|   Feature       | Azure (Cloud) | Azure Local (Edge/On-premises) | Edge Essentials (Edge/On-premises, Windows IoT client/server) | Windows Server (Edge/On-premises) |
| --- | --- | --- | --- | --- |
| GPU support                       | Yes             | Yes                       | Yes                                             | Yes                  |
| KAITO (Kubernetes AI toolchain operator) | Yes             | Yes, via Arc extensions   | No                                              | No                   |
| Edge RAG                          | Yes             | Yes                       | No                                              | No                   |

## Next steps

- Overview of [Azure Kubernetes Service (AKS)](aks-overview.md)
- [What is AKS on bare metal (preview)?](bare-metal/aks-bare-metal-overview.md)
- [What is AKS on Azure Local?](local/aks-local-overview.md)
- [Deploy a Linux application on a Kubernetes cluster](windows-server/deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](windows-server/deploy-windows-application.md)
