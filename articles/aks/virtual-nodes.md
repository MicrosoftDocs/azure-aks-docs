---
title: Use virtual nodes with Azure Kubernetes Service (AKS)
description: How to create and configure an Azure Kubernetes Service (AKS) cluster to use virtual nodes.
ms.topic: how-to
ms.date: 11/06/2023
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
# Customer intent: "As a DevOps engineer, I want to configure virtual nodes in my Kubernetes cluster, so that I can quickly scale application workloads without waiting for VM deployment."
---

# Create and configure an Azure Kubernetes Services (AKS) cluster to use virtual nodes

To rapidly scale application workloads in an AKS cluster, you can use virtual nodes. With virtual nodes, you have quick provisioning of pods, and only pay per second for their execution time. You don't need to wait for Kubernetes cluster autoscaler to deploy VM compute nodes to run more pods. Virtual nodes are only supported with Linux pods and nodes.

The virtual nodes add on for AKS is based on the open source project [Virtual Kubelet][virtual-kubelet-repo].

This article gives you an overview of the region availability and networking requirements for using virtual nodes, and the known limitations.

## Regional availability

All regions, where ACI supports VNET SKUs, are supported for virtual nodes deployments. For more information, see [Resource availability for Azure Container Instances in Azure regions](/azure/container-instances/container-instances-region-availability).

For available CPU and memory SKUs in each region, review [Azure Container Instances Resource availability for Azure Container Instances in Azure regions - Linux container groups](/azure/container-instances/container-instances-region-availability#linux-container-groups)

## Network requirements

Virtual nodes enable network communication between pods that run in Azure Container Instances (ACI) and the AKS cluster. To support this communication, a virtual network subnet is created and delegated permissions are assigned. Virtual nodes only work with AKS clusters created using *advanced* networking (Azure CNI). By default, AKS clusters are created with *basic* networking (kubenet).

Pods running in Azure Container Instances (ACI) need access to the AKS API server endpoint, in order to configure networking.

## Limitations

Virtual nodes functionality is heavily dependent on ACI's feature set. In addition to the [quotas and limits for Azure Container Instances](/azure/container-instances/container-instances-quotas), the following are scenarios not supported with virtual nodes or are deployment considerations:

* Using service principal to pull ACR images. [Workaround](https://github.com/virtual-kubelet/azure-aci/blob/master/README.md#private-registry) is to use [Kubernetes secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line).

    > [!IMPORTANT]
    > Secrets built according to the Kubernetes documentation (for standard nodes) will not work with virtual nodes. A specific server format is required, as detailed in [`ImageRegistryCredential`- Azure Container Instances](/azure/templates/microsoft.containerinstance/2022-10-01-preview/containergroups?pivots=deployment-language-bicep#imageregistrycredential).

* [Virtual Network Limitations](/azure/container-instances/container-instances-vnet) including VNet peering, Kubernetes network policies, and outbound traffic to the internet with network security groups.
* Init containers.
* [Host aliases](https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/).
* [Arguments](/azure/container-instances/container-instances-exec#restrictions) for exec in ACI.
* [DaemonSets](concepts-clusters-workloads.md#statefulsets-and-daemonsets) won't deploy pods to the virtual nodes.
* To schedule Windows Server containers to ACI, you need to manually install the open source [Virtual Kubelet ACI](https://github.com/virtual-kubelet/azure-aci) provider.
* Virtual nodes require AKS clusters with Azure CNI networking.
* Using API server authorized ip ranges for AKS.
* Volume mounting Azure Files share support [General-purpose V2](/azure/storage/common/storage-account-overview#types-of-storage-accounts) and [General-purpose V1](/azure/storage/common/storage-account-overview#types-of-storage-accounts). However, virtual nodes currently don't support [Persistent Volumes](concepts-storage.md#persistent-volumes) and [Persistent Volume Claims](concepts-storage.md#persistent-volume-claims). Follow the instructions for mounting [a volume with Azure Files share as an inline volume](azure-csi-files-storage-provision.md#mount-file-share-as-an-inline-volume).
* Using IPv6 isn't supported.
* Virtual nodes don't support the [Container hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) feature.

## Next steps

Configure virtual nodes for your clusters:

- [Create virtual nodes using Azure CLI](virtual-nodes-cli.md)
- [Create virtual nodes using the portal in Azure Kubernetes Services (AKS)](virtual-nodes-portal.md)

Virtual nodes are often one component of a scaling solution in AKS. For more information on scaling solutions, see the following articles:

- [Use the Kubernetes horizontal pod autoscaler][aks-hpa]
- [Use the Kubernetes cluster autoscaler][aks-cluster-autoscaler]
- [Read more about the Virtual Kubelet open source library][virtual-kubelet-repo]

<!-- LINKS - external -->
[aks-hpa]: tutorial-kubernetes-scale.md
[aks-cluster-autoscaler]: ./cluster-autoscaler.md
[virtual-kubelet-repo]: https://github.com/virtual-kubelet/virtual-kubelet
