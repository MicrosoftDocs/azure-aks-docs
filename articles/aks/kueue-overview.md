---
title: Install Kueue on Azure Kubernetes Service (AKS)
description: Learn how to install and configure Kueue on Azure Kubernetes Service (AKS) using the AKS managed Kueue extension or the open-source Kueue Helm chart.
ms.topic: how-to
ms.date: 09/26/2025
author: colinmixonn
ms.author: colinmixon
zone_pivot_groups: helm-or-extension
ms.service: azure-kubernetes-service
# Customer intent: "As a platform engineer or cluster admin, I want to install and configure Kueue on my AKS cluster so I can manage workload queueing and resource admission for batch and AI workloads."
---

# Install and Configure Kueue on Azure Kubernetes Service (AKS)

Kueue provides Kubernetes-native job queueing and resource admission for batch and AI workloads running on Azure Kubernetes Service (AKS). This article describes two ways to install Kueue on AKS:

- AKS managed Kueue extension (preview): Use the Azure-managed extension experience to deploy Kueue on your AKS cluster.
- Open-source Kueue with Helm: Install and configure Kueue directly from the upstream Kueue Helm chart.

After installation, use Kueue APIs such as ClusterQueue, LocalQueue, and ResourceFlavor to control how workloads are admitted to cluster resources.

## What is Kueue?

[Kueue](https://kueue.sigs.k8s.io/docs/overview/) is an open-source Kubernetes-native job queueing project designed to manage batch workloads and ensure efficient, fair, and policy-driven scheduling in Kubernetes clusters. Kueue integrates with the [Kubernetes scheduling](https://github.com/kubernetes/community/blob/master/sig-scheduling/README.md) ecosystem to coordinate resource allocation, prioritization, and capacity control for workloads. Kueue controls whether workloads are admitted based on configured resource quotas and policies. After a workload is admitted, the Kubernetes scheduler places the workload's pods onto nodes.

Kueue is useful for workloads such as:

- AI and machine learning training
- GPU-intensive jobs
- Data processing
- Security vulnerability scans
- Media encoding and video transcoding
- Report generation and financial analysis
- Other batch workloads that can wait for sufficient resources to become available

Model these workloads by using a Kubernetes Job, CronJob, or custom resource definition (CRD) like [RayJob](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/rayjob-quick-start.html) or [Kubeflow MPIJob](https://www.kubeflow.org/docs/components/trainer/legacy-v1/user-guides/mpi/) and admit them according to their `ClusterQueue` and `LocalQueue`

## Understand Kueue queues
Before you submit workloads with Kueue, configure queues that control workload admission.

Kueue uses two primary queue resources:

- `ClusterQueue` defines cluster-wide resource quotas for shared resource pools (such as CPU, memory, GPU quotas) and policies that determine which workloads can be admitted.
- `LocalQueue` provides a namespace-scoped queue where users submit workloads and references a ClusterQueue.

The following flow shows how Kueue evaluates a workload before Kubernetes schedules its pods: **Workload (Pod, Job, etc.) → LocalQueue → ClusterQueue → workload admission → Kubernetes scheduling**

A `LocalQueue` identifies the `ClusterQueue` that should evaluate the workload. The `ClusterQueue` determines whether sufficient quota is available for the workload to be admitted. Platform administrators typically configure cluster-level resources and policies, while workload owners submit jobs through a `LocalQueue`.

> [!NOTE]
> A `LocalQueue` is always needed for users to submit batch workloads, and the `LocalQueue` tells Kueue about which ClusterQueue to assign the job to. The `ClusterQueue` determines if sufficient resources are available for the job to be admitted and run.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## When to use Kueue

Batch and AI workloads can have scheduling and resource-management requirements that differ from long-running Kubernetes services. Batch workload administrators (including platform or cluster administrators and DevOps engineers) and batch users (data scientists, developers, and ML engineers) can benefit from deploying workloads with Kueue on AKS. 

A batch admin focuses on configuring, managing, and securing the platform-level infrastructure to support batch workloads, and have the following responsibilities:

* Provision and manage AKS node pools.
* Define resource quotas, ClusterQueues, and policies for workload isolation.
* Tune autoscaling and cost-efficiency (such as the Cluster Autoscaler or Kueue quotas).
* Monitor cluster and queue health.
* Create and maintain templates and reusable workflows.

A batch user runs compute-intensive or parallel jobs using the platform-level infrastructure configured by a batch admin, and typically:

* Submit batch jobs (such as Job, Workload, or custom controller CRDs) and monitor job status and outputs
* Select appropriate queue or resource flavor for jobs (based on guidance from batch admins)
* Optimize job specs for resource and performance needs

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.

Additional prerequisites depend on the installation method you choose.


## Choose how to install Kueue
AKS supports two installation approaches for Kueue. Choose the option that best matches how you want to install and configure Kueue on your cluster. The Kueue Kubernetes APIs and queueing concepts remain the same regardless of the installation method. The primary difference is how the Kueue components are installed and configured.

| Installation Path | Description | 
| ----------------- | ----------- |
| AKS managed Kueue extension (preview) | You want to deploy Kueue through the AKS cluster extension experience and use the Kueue version and configuration supported by the extension. |
| Open-source Kueue with Helm | You want to install Kueue directly from the upstream project and control the Kueue version, feature gates, integrations, and Helm configuration. |

::: zone pivot="extension"
## Install and configure managed Kueue extension on Azure Kubernetes Service (preview)

The AKS managed Kueue extension provides an Azure-native installation path for deploying Kueue on an AKS cluster. Use this installation method if you want to deploy Kueue through the AKS cluster extension experience instead of installing the upstream Helm chart directly.

### Managed extension prerequisites

Before you begin, make sure you have the following tools:

- AKS version v1.34 or later
- Azure CLI version 2.56 or later
- kubectl version 1.21.0 or later
- Azure CLI k8s-extension version 1.9.3
- Permissions to create and delete: resource groups, AKS clusters, AKS node pools, and cluster extensions

### Limitations
- The AKS managed Kueue extension is currently available in the following Azure regions: centralus, westus, westus2, and eastus
- The AKS managed Kueue extension currently only supports Cluster Autoscaler with support for Node Autoprovisioning planned

### Install the managed Kueue extension

Set environment variables for your Azure subscription, resource group, and AKS cluster:

```bash
SUBSCRIPTION_ID="<subscription-id>"
RESOURCE_GROUP="<resource-group-name>"
CLUSTER_NAME="<aks-cluster-name>"
```
Install the Kueue cluster extension:
```bash
az k8s-extension create \
--resource-group "$RESOURCE_GROUP" \
--cluster-name "$CLUSTER_NAME" \
--cluster-type managedClusters \
--name kueue \
--extension-type microsoft.kueue \
--scope cluster \
--release-namespace kueue-system \
--version 0.19.6-aks.0.4.4 \
--auto-upgrade-mode none
```

### Verify the extension installation

Get the provisioning state and installed version of the Kueue extension. After the extension finishes provisioning, continue to #verify-your-kueue-installation.

```bash
az k8s-extension show \
--resource-group "$RESOURCE_GROUP" \
--cluster-name "$CLUSTER_NAME" \
--cluster-type managedClusters \
--name kueue \
--output json
```

### Uninstall the managed Kueue extension

If you want to remove managed Kueue without deleting the AKS cluster, delete the extension:

```bash
az k8s-extension delete \
--resource-group "$RESOURCE_GROUP" \
--cluster-name "$CLUSTER_NAME" \
--cluster-type managedClusters \
--name kueue \
--yes
```
::: zone-end

::: zone pivot="helm"

## Install Kueue with Helm

### Helm prerequisites

Before you begin, make sure you have the following tools:

- Helm v3.0.0 or later
- Permissions to create and delete: resource groups, AKS clusters, AKS node pools, and cluster extensions

### Configure optional Kueue features
While most features and scheduling policies that you might require are enabled by default, some aren't like `TopologyAwareScheduling`. If needed, reconfigure your Kueue installation by changing the default [Feature Gates](https://kueue.sigs.k8s.io/docs/installation/#feature-gates-for-alpha-and-beta-features) or by configuring [Kueue paramater values](https://github.com/kubernetes-sigs/kueue/blob/main/charts/kueue/README.md#configuration) in the `values.yaml` file of the Helm chart.

Kueue supports multiple workload [Frameworks](https://kueue.sigs.k8s.io/docs/tasks/run/) that you need to explicitly enable to use Kueue’s scheduling and resource management capabilities when running [MPI Operator](https://www.kubeflow.org/docs/components/training/mpi/) MPIJobs, [KubeRay's](https://github.com/ray-project/kuberay) [RayJob](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/rayjob-quick-start.html) and more.

The following example enables:
- `LocalQueueMetrics` provides detailed Prometheus metrics specific to the state and activity of LocalQueues, enabling fine-grained monitoring of workload admission, quota reservation, and resource utilization. 
- `TopologyAwareScheduling` allows scheduling of pods based on the topology of nodes in a pool or cluster to improve available bandwidth between the pods.
- Integrations for batch and AI workload frameworks including Kubeflow, Ray, and [JobSet](https://jobset.sigs.k8s.io/docs/concepts/).

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
> [!NOTE]
> Update version as needed: [kueue/releases](https://github.com/kubernetes-sigs/kueue/releases)

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

### Uninstall Kueue

If you no longer need the Kueue controller manager or Kueue custom resources in your AKS cluster, uninstall the Helm repository and remove the dedicated namespace and resources.  

1. Uninstall the Kueue Helm repository by using the `helm uninstall` command.  

    ```bash  
    helm uninstall kueue --namespace kueue-system  
    ```  

2. Remove the dedicated namespace and resources by using the `kubectl delete` command.  

    ```bash  
    kubectl delete namespace kueue-system  
    ```  
::: zone-end

## Confirm deployment status

Regardless of which installation method you use, verify that the Kueue components are running before configuring queues or submitting workloads.

1. Verify that controller pods are running properly.

    ```bash
    kubectl get deploy -n kueue-system
    ```

    Your output should look similar to the following example output:

    ```output
    NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
    kueue-controller-manager       1/1     1            1           7s
    ```

2. Confirm the installation of Kueue resources on your AKS cluster:

    ```bash
    kubectl get crds | grep kueue
    ```

    Your output should include the following Kueue CRDs:

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
The exact set of CRDs can vary depending on the installed Kueue version.

After Kueue is running, configure queues, resource quotas, and workload admission policies before submitting workloads.

## Next steps

* [Deploy sample batch jobs with Kueue on your AKS cluster](./deploy-batch-jobs-with-kueue.md).
* [Deploy multi-cluster scheduling and resource placement with Kueue and KubeFleet on AKS](https://blog.aks.azure.com/2025/04/02/Scaling-Kubernetes-for-AI-and-Data-intensive-Workloads).

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
