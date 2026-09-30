---
title: Kubernetes cluster architecture for AKS on Windows Server
description: Learn the basic cluster and workload components of Kubernetes and how they relate to features of AKS on Windows Server.
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.lastreviewed: 03/28/2025
ms.topic: concept-article
ms.custom: windows-server


# Intent: As an IT Pro, I want to learn about the basic cluster and workload components of Kubernetes and how they relate to features of AKS on Windows Server.
# Keyword: Kubernetes cluster architecture

---

# Kubernetes cluster architecture and workloads for AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Azure Kubernetes Service (AKS) on Windows Server is an enterprise-grade Kubernetes container platform. It includes Microsoft-supported core Kubernetes, a purpose-built Windows container host, and a Microsoft-supported Linux container host, with a goal to have a simple deployment and life cycle management experience.

This article introduces the core Kubernetes infrastructure components, such as the control plane, nodes, and node pools. Workload resources such as pods, deployments, and sets are also introduced, along with how to group resources into namespaces.

## Kubernetes cluster architecture

Kubernetes is the core component of AKS on Windows Server. AKS uses a set of predefined configurations to deploy Kubernetes cluster(s) effectively and with scalability in mind.

The deployment operation creates multiple Linux or Windows virtual machines and joins them together to create Kubernetes cluster(s).

> [!NOTE]
> To help improve the reliability of the system, if you are running multiple Cluster Shared Volumes (CSVs) in your cluster, by default virtual machine data is automatically spread out across all available CSVs in the cluster. This ensures that applications survive in the event of CSV outages. This applies to only new installations (not upgrades).

The deployed system is ready to receive standard Kubernetes workloads, scale these workloads, or even scale the number of virtual machines and the number of clusters up and down as needed.

An Azure Kubernetes Service cluster has the following components:

- **Management cluster** (also known as the AKS host) provides the core orchestration mechanism and interface for deploying and managing one or more workload clusters.
- **Workload clusters** (also known as target clusters) are where containerized applications are deployed.

:::image type="content" source="../media/kubernetes-concepts/hci-architecture.png" alt-text="Illustration showing the technical architecture of Azure Kubernetes Service on Windows Server." lightbox="../media/kubernetes-concepts/hci-architecture.png":::

## Manage AKS on Windows Server

You can manage AKS using the following management options:

- **Windows Admin Center** offers an intuitive UI for the Kubernetes operator to manage the lifecycle of clusters.
- A **PowerShell module** makes it easy to download, configure, and deploy AKS. The PowerShell module also supports deploying and configuring other workload clusters and reconfiguring existing ones.

## The management cluster

When you create a Kubernetes cluster, a management cluster is automatically created and configured. This management cluster is responsible for provisioning and managing workload clusters where workloads run. A management cluster includes the following core Kubernetes components:

- **API server**: the API server is how the underlying Kubernetes APIs are exposed. This component provides the interaction for management tools, such as Windows Admin Center, PowerShell modules, or `kubectl`.
- **Load balancer**: the load balancer is a single dedicated Linux VM with a load-balancing rule for the API server of the management cluster.

## The workload cluster

The workload cluster is a highly available deployment of Kubernetes using Linux VMs for running Kubernetes control plane components and Linux worker nodes. Windows Server Core-based VMs are used for establishing Windows worker nodes. There can be one or more workload cluster(s) managed by one management cluster.

### Workload cluster components

The workload cluster has many components, which are described in the following sections.

#### Control plane

- **API Server**: the API server allows interaction with the Kubernetes API. This component provides the interaction for management tools, such as Windows Admin Center, PowerShell modules, or `kubectl`.
- **Etcd**: Etcd is a distributed key-value store that stores data required for lifecycle management of the cluster. It stores the control plane state.

#### Load balancer

The load balancer is a virtual machine running Linux and HAProxy + KeepAlive to provide load balanced services for the workload clusters deployed by the management cluster. For each workload cluster, AKS adds at least one load balancer virtual machine. Any Kubernetes service of type `LoadBalancer` that's created on the workload cluster eventually creates a load-balancing rule in the VM.

#### Worker nodes

To run your applications and supporting services, you need a *Kubernetes node*. An AKS workload cluster has one or more *worker nodes*. Worker nodes act as virtual machines (VMs) that run the Kubernetes node components, and host the pods and services that make up the application workload.

There are core Kubernetes workload components that can be deployed on AKS workload clusters, such as pods and deployments.

#### Pods

Kubernetes uses *pods* to run an instance of your application. A pod represents a single instance of your application. Typically, pods have a 1:1 mapping with a container, although there are advanced scenarios in which a pod can contain multiple containers. These multi-container pods are scheduled together on the same node and allow containers to share related resources. For more information, see [Kubernetes pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) and [Kubernetes pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/).

#### Deployments

A *deployment* represents one or more identical pods, managed by the Kubernetes Deployment Controller. A deployment defines the number of *replicas* (pods) to create, and the Kubernetes scheduler ensures that if pods or nodes encounter problems, additional pods are scheduled on healthy nodes. For more information, see [Kubernetes deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

#### StatefulSets and DaemonSets

The Deployment Controller uses the Kubernetes scheduler to run a given number of replicas on any available node with available resources. This approach of using deployments might be sufficient for stateless applications, but not for applications that require a persistent naming convention or storage. For applications that require a replica to exist on each node (or selected nodes) within a cluster, the Deployment Controller doesn't look at how replicas are distributed across the nodes.

- **StatefulSets**: a StatefulSet is similar to a deployment in that one or more identical pods are created and managed. **Replicas** in a StatefulSet follow a graceful, sequential approach to deployment, scale, upgrades, and terminations. With a StatefulSet (as replicas are rescheduled) the naming convention, network names, and storage persist. Replicas in a StatefulSet are scheduled and run across any available node in a Kubernetes cluster. If you need to ensure that at least one pod in your set runs on a node, you can instead use a DaemonSet. For more information, see [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).
- **DaemonSets**: for specific log collection or monitoring needs, you might need to run a given pod on all, or selected, nodes. A *DaemonSet* is again used to deploy one or more identical pods, but the DaemonSet controller ensures that each node specified runs an instance of the pod. For more information, see [Kubernetes DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

#### Namespaces

Kubernetes resources, such as pods and deployments, are logically grouped into a *namespace*. These groupings provide a way to logically divide workload clusters and restrict access to create, view, or manage resources. For example, you can create namespaces to separate business groups. Users can only interact with resources within their assigned namespaces. For more information, see [Kubernetes namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

When you create an Azure Kubernetes Service cluster on AKS on Windows Server, the following namespaces are available:

- **default**: a namespace where pods and deployments are created by default when none is provided. In smaller environments, you can deploy applications directly into the default namespace without creating additional logical separations. When you interact with the Kubernetes API, such as with `kubectl get pods`, the default namespace is used when none is specified.
- **kube-system**: a namespace where core resources exist, such as network features such as DNS and proxy, or the Kubernetes dashboard. You typically don't deploy your own applications into this namespace.
- **kube-public**: a namespace typically not used, but can be used for resources to be visible across the whole cluster, and can be viewed by any user.

#### Secrets

Kubernetes *secrets* enable you to store and manage sensitive information, such as passwords, OAuth tokens, and Secure Shell (SSH) keys. By default, Kubernetes stores secrets as unencrypted base64-encoded strings, and they can be retrieved as plain text by anyone with API access. For more information, see [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/).

#### Persistent volumes

A *persistent volume* is a storage resource in a Kubernetes cluster that has either been provisioned by the administrator or dynamically provisioned using storage classes. To use persistent volumes, pods request access using a **PersistentVolumeClaim**. For more information, see [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

## Mixed-OS deployments

If a given workload cluster consists of both Linux and Windows worker nodes, it needs to be scheduled onto an OS that can support provisioning the workload. Kubernetes offers two mechanisms to ensure that workloads land on nodes with a target operating system:

- **Node Selector** is a simple field in the pod spec that constrains pods to only be scheduled onto healthy nodes matching the operating system.
- **Taints and tolerations** work together to ensure that pods are not scheduled onto nodes unintentionally. A node can be "tainted" such that it doesn't accept pods that do not explicitly tolerate its taint through a "toleration" in the pod spec.

For more information, see [node selectors](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) and [taints and tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

## Next steps

In this article, you learned about the cluster architecture of AKS on Windows Server, and the workload cluster components. For more information about these concepts, see the following articles:

- [Security](./concepts-security.md)
- [Container networking](./concepts-container-networking.md)
- [Storage](../local/hyperconverged/concepts-storage.md)
