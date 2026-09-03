---
title: Azure Kubernetes Service (AKS) on Azure Local for multi-rack deployments
description: Learn about the architecture of AKS enabled by Azure Arc on Azure Local (multi-rack), including how clusters are deployed, managed, and connected to Azure.
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# AKS on Azure Local for multi-rack deployments

Azure Kubernetes Service (AKS) enabled by Azure Arc on Azure Local allows you to deploy and manage Kubernetes clusters. Clusters run as virtual machines (VM) on the Azure Local platform and are connected to Azure through Azure Arc. That connection gives you a consistent management experience using the Azure portal, Azure CLI, or Azure Resource Manager templates (ARM templates). The goal is to provide a unified deployment and lifecycle management experience.

This article describes the key architectural concepts for AKS on Azure Local for multi-rack deployments. It introduces core components, such as the control plane nodes and node pools.

## Overview

When you deploy an AKS cluster on Azure Local, the platform deploys virtual machines that serve as Kubernetes control plane nodes and worker nodes. The Azure Local platform manages the full lifecycle of these clusters, including creation, scaling, upgrades, and deletion.

:::image type="content" source="./media/cluster-architecture/aks-arc-rack-scale-architecture.png" alt-text="Diagram showing the AKS on Azure Local (multi-rack). Azure Resource Manager communicates through Azure Arc to Azure Local and AKS clusters run as VMs." lightbox="./media/cluster-architecture/aks-arc-rack-scale-architecture.png":::

AKS Arc uses a predefined configuration to deploy Kubernetes clusters effectively and with scalability in mind. A deployment operation creates multiple Linux virtual machines and joins them together to create one or more Kubernetes clusters.

## Key concepts

There are several key concepts for AKS on Azure Local multi-rack deployments.

### Azure Local platform

Azure Local for multi-rack deployments provides the on-premises infrastructure for running AKS clusters. AKS clusters are deployed onto this infrastructure and managed through Azure. The platform is fully managed from Azure and has the following core AKS Arc components:

- **AKS Arc cluster extensions**: A cluster extension is the on-premises equivalent of an Azure Resource Manager resource provider. Just as the Microsoft.ContainerService resource provider manages AKS clusters in Azure, the AKS Arc cluster extension helps manage Kubernetes clusters via Azure.
- **Custom location**: A custom location represents your Azure Local environment in Azure. When you create an AKS cluster, you specify the custom location to target your deployment to the correct infrastructure. when Azure Local is deployed, the Custom Location is automatically created and surfaced to the users to target their AKS cluster deployments.

### AKS clusters

AKS clusters are a high availability deployment of Kubernetes using Linux VMs for running Kubernetes control plane components and Linux node pools. There can be one or more AKS clusters on an Azure Local multi-rack deployment.

An AKS cluster on Azure Local (multi-rack) consists of:

 **Control plane**: Kubernetes uses control plane nodes to ensure every component in the Kubernetes cluster is kept in the desired state. The control plane also manages and maintains the worker node pools that hold the containerized applications. AKS enabled by Arc deploys the KubeVIP load balancer to ensure that the API server IP addresses of the Kubernetes control plane are always available.

 Control plane nodes run the following major components (not an exhaustive list):

- **API server**: Enables interaction with the Kubernetes API. This component provides the interaction for management tools, such as Azure CLI, the Azure portal, or kubectl.
- **Etcd**: A distributed key-value store that stores data required for lifecycle management of the cluster. It stores the control plane state.

**Node pools**: In Kubernetes, a node pool is a group of nodes within a cluster that share the same configuration. Node pools allow you to create and manage sets of nodes that have specific roles, capabilities, or hardware configurations. Node pools enable more granular control over the infrastructure of your AKS cluster. You can deploy Linux node pools in your AKS cluster. Each node pool has a configurable VM size and node count. You need to have at least one Linux node pool to host the Arc agents that maintain connectivity with Azure.

### Kubernetes versions

AKS on Azure Local supports specific Kubernetes versions. You can learn more about the supported Kubernetes versions and upgrade process: [Upgrade AKS on Azure Local for multi-rack deployments](cluster-upgrade.md).

### VM sizes

When you create a cluster, you select VM sizes for control plane and worker nodes from the available SKU catalog. The platform defines the available VM sizes, for more information, see [VM sizes for AKS on Azure Local](scale-requirements.md).

## Cluster lifecycle

You manage the full lifecycle of AKS clusters through Azure:

| Operation | Description |
| --------- | ----------- |
| **Create** | Deploy a new cluster by specifying the custom location, logical network, Kubernetes version, VM sizes, and node counts. |
| **Scale** | Add or remove control plane nodes (as long as number of nodes is odd) or worker nodes in a node pool. Or add new node pools to a cluster. |
| **Upgrade** | Update the cluster to a newer Kubernetes version. Upgrades are performed as rolling updates to minimize downtime. |
| **Delete** | Remove the cluster and release the associated infrastructure resources. |

All operations are available through the Azure portal, Azure CLI (`az aksarc`), ARM templates, and Bicep.

### Azure Arc connectivity

Each AKS cluster is automatically connected to Azure as an Arc-enabled Kubernetes cluster. This connection provides:

- **Azure portal management**: View cluster status, node pools, and workloads in the Azure portal.
- **Azure Monitor**: Enable Container Insights to monitor cluster health, performance, and logs.
- **Azure Policy**: Apply and enforce policies across your clusters.
- **GitOps**: Use Flux v2 to manage cluster configurations from Git repositories.
- **Cluster access**: Connect to the Kubernetes API server using `az connectedk8s proxy` without requiring direct network access.

## Next steps

- [Quickstart: Deploy an AKS cluster using an ARM template](resource-manager-quickstart.md)
- [Network requirements for AKS on Azure Local (multi-rack)](network-system-requirements.md)
- [Plan IP addresses for AKS on Azure Local (multi-rack)](plan-aks-ip-address.md)
