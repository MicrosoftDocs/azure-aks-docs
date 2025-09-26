---
title: Install Kueue on Azure Kubernetes Service (AKS)
description: Install and configure Kueue on your Azure Kubernetes Service (AKS) cluster, including enabling advanced features and verifying deployment.
ms.topic: how-to
ms.date: 09/26/2025
author: colinmixonn
ms.author: colinmixon
ms.service: azure-kubernetes-service
# Customer intent: "As a platform engineer or cluster admin, I want to install and configure Kueue on my AKS cluster, so I can enable advanced scheduling and resource management for specialized workloads.
---

# Install and Configure Kueue on Azure Kubernetes Service (AKS)

In this article, you learn how to install and configure Kueue to schedule batch workloads on an Azure Kubernetes Service (AKS) cluster. You'll explore different installation methods to enable advanced Kueue features, verify your deployment, and monitor with Prometheus metrics exposed by Kueue.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What are batch workloads?

Batch deployments are typically non-interactive workloads that are retriable, have a finite duration, and might experience spiky or bursty resource usage. These workloads include, but are not limited to:

* Data processing jobs.
* Security vulnerability scans.
* Media encoding or video transcoding.
* Report generation or financial analysis.
* GPU workloads that require all resources to be available and might tolerate a delayed start but can't tolerate partial GPU allocation.

These workloads are often modeled using a Kubernetes Job, CronJob, or custom resource definition (CRD) like [RayJob](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/rayjob-quick-start.html) or [Kubeflow MPIJob](https://www.kubeflow.org/docs/components/trainer/legacy-v1/user-guides/mpi/). Batch deployments present the following set of distinct requirements from general purpose deployments:

* Scheduling logic beyond selecting the first available node.
* Fairness, queueing, and resource awareness.
* Lifecycle awareness of jobs and pods.

The default AKS scheduler satisfies the requirements of Kubernetes services but provides limited configuration for batch workloads that require a job queueing system.

## What is Kueue?

[Kueue](https://kueue.sigs.k8s.io/docs/overview/) is an open-source Kubernetes-native job queueing project designed to manage batch workloads and ensure efficient, fair, and policy-driven scheduling in Kubernetes clusters. Kueue integrates with the [Kubernetes scheduling](https://github.com/kubernetes/community/blob/master/sig-scheduling/README.md) ecosystem to coordinate resource allocation, prioritization, and capacity control for batch jobs.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

Kueue introduces a two-level queuing model:

- A `ClusterQueue` represents shared resource pools (such as CPU, memory, GPU quotas).
- A `LocalQueue` represents a tenant-facing queue in a namespace (where users submit their batch jobs).

Workloads submitted to a `LocalQueue` are matched to a `ClusterQueue` to determine if they can be admitted.

> [!NOTE]
> A `LocalQueue` is always needed for users to submit batch workloads, and the `LocalQueue` tells Kueue about which ClusterQueue to assign the job to. The `ClusterQueue` determines if sufficient resources are available for the job to be admitted and run.

## Who can use Kueue?

Batch workload administrators (including platform or cluster administrators and DevOps engineers) and batch users (data scientists, developers, and ML engineers) can benefit from deploying workloads with Kueue on AKS.

A batch admin focuses on configuring, managing, and securing the platform-level infrastructure to support batch workloads, and have the following responsibilities:

* Provision and manage AKS node pools.
* Define resource quotas, ClusterQueues, and policies for workload isolation.
* Tune autoscaling and cost-efficiency (e.g., Cluster Autoscaler, Kueue quotas).
* Monitor cluster and queue health.
* Create and maintain templates and reusable workflows.

A batch user runs compute-intensive or parallel jobs using the platform-level infrastructure configured by a batch admin, and typically:

* Submit batch jobs (e.g., Job, Workload, or custom controller CRDs) and monitor job status and outputs
* Select appropriate queue or resource flavor for jobs (based on guidance from batch admins)
* Optimize job specs for resource and performance needs

| Queue Type | Scope | Created By | Used For |
| -------- | -------- | --------- | ------- |
| **ClusterQueue** | Cluster-wide | Platform admin | Define shared compute capacity and quota management |
| **LocalQueue** | Namespace | Namespace owner | Enable workload submission, mapped to ClusterQueue |

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.

## Install Kueue with Helm

While most features and scheduling policies that you may require are enabled by default, some are not like `TopologyAwareScheduling`. If needed, reconfigure your Kueue installation by changing the default [Feature Gates](https://kueue.sigs.k8s.io/docs/installation/#feature-gates-for-alpha-and-beta-features) or by configuring [Kueue paramater values](https://github.com/kubernetes-sigs/kueue/blob/main/charts/kueue/README.md#configuration) in the `values.yaml` file of the Helm chart.

Kueue supports multiple workload [Frameworks](https://kueue.sigs.k8s.io/docs/tasks/run/) that need to be explicitly enabled to leverage Kueue’s scheduling and resource management capabilities when running [MPI Operator](https://www.kubeflow.org/docs/components/training/mpi/) MPIJobs, [KubeRay's](https://github.com/ray-project/kuberay) [RayJob](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/rayjob-quick-start.html) and more.

In this guide, Kueue is configured to include `LocalQueueMetrics` and `Topology Aware Scheduling` and frameworks from Kubeflow, Ray, and [JobSet](https://jobset.sigs.k8s.io/docs/concepts/).

- `LocalQueueMetrics` provides detailed Prometheus metrics specific to the state and activity of LocalQueues, enabling fine-grained monitoring of workload admission, quota reservation, and resource utilization. 
- `TopologyAwareScheduling` allows scheduling of pods based on the topology of nodes in a pool or cluster to improve available bandwidth between the pods.

> [!NOTE]
> Update version as needed: [kueue/releases](https://github.com/kubernetes-sigs/kueue/releases)

1. Create and save a `values.yaml` file to optionally customize your Kueue configuration. 

    ```bash
    cat <<EOF > values.yaml
    controllerManager:
      featureGates:
        - name: TopologyAwareScheduling
          enabled: true
        - name: LocalQueueMetrics
          enabled: true
      managerConfig:
        controllerManagerConfigYaml: |
          apiVersion: config.kueue.x-k8s.io/v1beta1
          kind: Configuration
          integrations:
            frameworks:
              - batch/job
              - kubeflow.org/mpijob
              - ray.io/rayjob
              - ray.io/raycluster
              - jobset.x-k8s.io/jobset
              - kubeflow.org/paddlejob
              - kubeflow.org/pytorchjob
              - kubeflow.org/tfjob
              - kubeflow.org/xgboostjob
              - kubeflow.org/jaxjob
    EOF
    ```

2. Install the latest version of the Kueue controller and CRDs in a dedicated namespace using the `helm install` command.

    ```bash
    LATEST_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kueue/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')

    helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
     --version=${LATEST_VERSION} \
    --create-namespace --namespace=kueue-system \
    --values values.yaml
    ```

3. Confirm the deployment status using the `helm list` command.

    ```bash
    helm list --namespace kueue-system
    ```

    Your output should include a `Status` of `deployed` and look like:

    ```output
    Pulled: registry.k8s.io/kueue/charts/kueue:0.13.4
    Digest: -
    NAME: kueue
    LAST DEPLOYED: -
    NAMESPACE: kueue-system
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    ```

## Confirm deployment status

1. Verify that controller pods are running properly.

    ```bash
    kubectl get deploy -n kueue-system
    ```

    Your output should look similar to the following:

    ```output
    NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
    kueue-controller-manager       1/1     1            1           7s
    ```

2. Confirm the installation of Kueue resources on your AKS cluster:

    ```bash
    kubectl get crds | grep kueue
    ```

    Your output should include the following Kueue CRDs, as shown below:

    ```output
    admissionchecks.kueue.x-k8s.io                   2025-09-11T18:20:48Z
    clusterqueues.kueue.x-k8s.io                     2025-09-11T18:20:48Z
    cohorts.kueue.x-k8s.io                           2025-09-11T18:20:48Z
    localqueues.kueue.x-k8s.io                       2025-09-11T18:20:48Z
    multikueueclusters.kueue.x-k8s.io                2025-09-11T18:20:48Z
    multikueueconfigs.kueue.x-k8s.io                 2025-09-11T18:20:48Z
    provisioningrequestconfigs.kueue.x-k8s.io        2025-09-11T18:20:48Z
    resourceflavors.kueue.x-k8s.io                   2025-09-11T18:20:48Z
    topologies.kueue.x-k8s.io                        2025-09-11T18:20:48Z
    workloadpriorityclasses.kueue.x-k8s.io           2025-09-11T18:20:48Z
    workloads.kueue.x-k8s.io                         2025-09-11T18:20:48Z
    ```

## Uninstall Kueue

If you no longer need to use the Kueue controller manager or Kueue custom resources in your AKS cluster, you can uninstall the Helm repository and remove the dedicated namespace and resources.  

1. Uninstall the Kueue Helm repository using the `helm uninstall` command.  

    ```bash  
    helm uninstall kueue --namespace kueue-system  
    ```  

2. Remove the dedicated namespace and resources using the `kubectl delete` command.  

    ```bash  
    kubectl delete namespace kueue-system  
    ```  

## Next steps

* [Deploy sample batch jobs with Kueue on your AKS cluster](./deploy-batch-jobs-with-kueue.md).
* [Monitor your Kueue deployments with key Prometheus metrics](./kueue-monitoring.md).
* [Deploy multi-cluster scheduling and resource placement with Kueue and KubeFleet on AKS](https://blog.aks.azure.com/2025/04/02/Scaling-Kubernetes-for-AI-and-Data-intensive-Workloads).

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
