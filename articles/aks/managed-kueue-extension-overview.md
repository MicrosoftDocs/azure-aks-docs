---
title: Managed Kueue extension overview
description: Learn the basic concepts for the AKS managed Kueue extension.
ms.topic: overview
ms.date: 10/22/2026
author: colinmixonn
ms.author: colinmixon
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform engineer or cluster administrator, I want to understand Kueue and AKS managed Kueue extension concepts."
---

# Learn about managed Kueue extension on Azure Kubernetes Service (AKS)

[Kueue](https://kueue.sigs.k8s.io/docs/overview/) provides Kubernetes-native job queueing and resource admission for batch and AI workloads. It decides when a workload can start based on available queue quota and configured policies. After admission, the Kubernetes scheduler places the workload's pods on nodes.

On Azure Kubernetes Service (AKS), prefer the **managed Kueue extension (preview)** to install and manage the supported Kueue controller and generate managed resources for your cluster. See [Install the managed Kueue extension on AKS](./install-the-managed-kueue-extension-on-aks.md).

This article explains the basic concepts of Kueue and the managed Kueue extension.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## When to use Kueue

Use Kueue for workloads that can wait for sufficient quota and resources before they run, such as:

- AI and machine learning training.
- GPU-intensive batch jobs.
- Data processing and analytics.
- Hyperparameter tuning and batch inference.
- Media encoding and other finite processing jobs.

Kueue integrates with Kubernetes Jobs and supported workload APIs such as RayJob. The integrations supported by the managed extension are listed in the [managed installation guide](./install-the-managed-kueue-extension-on-aks.md#limitations).

Kueue admission isn't the same as pod scheduling or Azure capacity allocation. Available queue quota doesn't guarantee that a pod can be scheduled immediately. For capacity provisioning before admission, see [Use managed Kueue with the cluster autoscaler](./use-managed-kueue-extension-with-the-cluster-autoscaler-on-aks.md).

<a id="understand-kueue-queues"></a>
<a id="understand-queues-and-resource-flavors"></a>

## Understand Kueue basic concepts

The following resources connect a submitted workload to a quota and admission policy:

| Resource | Purpose |
| --- | --- |
| `ResourceFlavor` | Describes the node characteristics used when assigning resources to workloads. The managed extension generates flavors for eligible user nodes. |
| `ClusterQueue` | Defines cluster-scoped resource quotas, flavor references, and policies such as queueing and preemption. |
| `LocalQueue` | Provides a namespace-scoped submission point that references a `ClusterQueue`. A `LocalQueue` is usually named after a team, business unit, user, or project. |
| `Workload` | Records a workload's resource requests, quota reservation, and admission state. Supported workload integrations create this object. |
| `WorkloadPriorityClass` | Assigns a priority to workloads for admission ordering and applicable preemption policies. The managed extension provides default classes. |

The admission flow is:

**Job or other supported workload → LocalQueue → ClusterQueue → admission checks and quota reservation → workload admission → pod scheduling**

A workload's `kueue.x-k8s.io/queue-name` label identifies a LocalQueue in its namespace. The LocalQueue routes the workload to its ClusterQueue. If the required quota or an admission check isn't ready, the workload waits rather than starting its pods.

A ClusterQueue quota is an admission policy, not a node-pool size or an Azure subscription quota. Queue owners configure quotas according to their capacity and sharing policy.

<a id="understand-managed-resources-and-priorities"></a>

## Understand managed resources and priorities for the AKS managed Kueue extension

The managed extension generates resources such as the `aks-cpu` ResourceFlavor for eligible CPU user nodes and provides `aks-low-priority`, `aks-medium-priority`, and `aks-high-priority` workload priority classes. GPU flavor names depend on the detected GPU hardware. Inspect the resources generated for your cluster rather than assuming a name.

Reference managed resources from your queues and workloads. Don't recreate them with reserved AKS names or change their protection markers. You still own your ClusterQueues, LocalQueues, workload requests, and quota policies.

Priority affects admission ordering. It enables preemption only when the ClusterQueue's preemption policy permits it. A higher priority alone doesn't authorize a workload to evict another workload. See the [low- and high-priority Job example](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md#use-workload-priority-and-preemption).

<a id="configure-optional-kueue-features"></a>

## Kueue features in the managed extension

The managed preview provides the following feature configuration:

| Feature | Managed configuration |
| --- | --- |
| Topology-aware scheduling (`TopologyAwareScheduling`) | Enabled by default. Configure your queues and workloads to use topology-aware placement where supported. |
| LocalQueue metrics (`LocalQueueMetrics`) | Enabled by default. Kueue exposes metrics about LocalQueue activity and admission. |
| ClusterQueue resource metrics | Enabled. Kueue exposes per-ClusterQueue quota and resource-usage metrics. |
| Workload integrations | Kubernetes Job, Pod, Deployment, StatefulSet, JobSet, RayJob, RayService, RayCluster, MPIJob, and Trainer v2 TrainJob are enabled. Legacy Kubeflow Trainer v1 jobs, AppWrapper, and LeaderWorkerSet aren't enabled. |
| MultiKueue | Disabled by default. Azure services manage its configuration for supported multi-cluster scenarios. |

Exposing metrics doesn't configure their collection or storage. Configure monitoring separately.

Feature gates, controller configuration, and workload integrations are managed as part of the extension release. You can't override them through customer-supplied extension configuration settings or Helm values. You can still configure your own ClusterQueues, LocalQueues, quotas, and workload policies through the Kueue APIs.

## Responsibilities

Platform administrators typically:

- Provision and manage AKS node pools.
- Install the managed extension and verify controller health.
- Configure ClusterQueues, quotas, sharing, and preemption policies.
- Provide LocalQueues and monitor admission and cluster capacity.

Workload owners typically:

- Submit supported workloads to a LocalQueue.
- Select an appropriate workload priority class.
- Set resource requests and any required placement constraints.
- Monitor workload admission, pod scheduling, and application results.

## Choose an installation approach

### Recommended: managed Kueue extension

Use the managed extension to manage the supported Kueue version and controller configuration through Azure. AKS also generates managed ResourceFlavors and provides default workload priority classes. Follow [Install the managed Kueue extension on AKS](./install-the-managed-kueue-extension-on-aks.md).

<!-- Preserve published links to installation sections moved to the managed guide. -->
<a id="prerequisites"></a>
<a id="managed-extension-prerequisites"></a>

For cluster and client requirements, see the [managed extension prerequisites](./install-the-managed-kueue-extension-on-aks.md#prerequisites).

<a id="uninstall-the-managed-kueue-extension"></a>

For lifecycle operations, see [Uninstall the managed Kueue extension](./install-the-managed-kueue-extension-on-aks.md#uninstall-the-managed-kueue-extension). Uninstalling deletes Kueue custom resources and queue configuration; it isn't a controller-health workaround.

### Alternative (not recommended)

If you need to select and manage your own Kueue version or controller configuration, you can alternatively install the open-source project, including through Helm. Use the [upstream Kueue installation instructions](https://kueue.sigs.k8s.io/docs/installation/) for that path instead of applying upstream installation commands to a managed extension.

Manage a self-hosted installation's configuration and lifecycle separately. Don't run a self-hosted Kueue controller alongside the managed extension on the same cluster.

## Next steps

- [Install the managed Kueue extension on AKS](./install-the-managed-kueue-extension-on-aks.md).
- [Schedule and deploy batch jobs with the managed Kueue extension](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md).
- [Use managed Kueue with the cluster autoscaler](./use-managed-kueue-extension-with-the-cluster-autoscaler-on-aks.md).
