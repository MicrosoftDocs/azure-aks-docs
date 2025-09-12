---
title: Schedule and deploy batch jobs with Kueue on Azure Kubernetes Service (AKS)
description: Learn how to define Kueue deployments and efficiently schedule batch workloads on your Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 9/17/2025
author: sachidesai
ms.author: sachidesai
# Customer intent: "As a platform admin, I want to quickly schedule and deploy batch jobs to ensure efficient resource utilization and cost optimization on AKS cluster(s), enabling platform developers to run bursty workloads to completion without impacting the performance of other services."
---

# Schedule and deploy batch jobs with Kueue on Azure Kubernetes Service (AKS)

In this article, you learn how to schedule and deploy batch jobs on Azure Kubernetes Service (AKS) using the Kueue controller manager and custom resource definitions (CRDs). You also learn how to use Kueue to queue up sample general-purpose deployments and track the results with Kueue Prometheus metrics.

## What are batch deployments?

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

[Kueue](https://kueue.sigs.k8s.io/docs/overview/) is an open-source Kubernetes-native job queueing project designed to manage batch workloads and ensure efficient, fair, and policy-driven scheduling in Kubernetes clusters. Kueue integrates with the [Kubernetes SIG Scheduling](https://github.com/kubernetes/community/blob/master/sig-scheduling/README.md) ecosystem to coordinate resource allocation, prioritization, and capacity control for batch jobs.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

### Queuing model

Kueue introduces a two-level queuing model:

* A `ClusterQueue` represents shared resource pools (such as CPU, memory, GPU quotas).
* A `LocalQueue` represents a tenant-facing queue in a namespace (where users submit their batch jobs).

Workloads submitted to a `LocalQueue` are matched to a `ClusterQueue` to determine if they can be admitted.

> [!NOTE]
> A `LocalQueue` is always needed for users to submit batch workloads. The `LocalQueue` tells Kueue which `ClusterQueue` to assign the job to. The `ClusterQueue` determines if sufficient resources are available to admit and run the job.

## Who can use Kueue?

Batch workload administrators (including platform or cluster administrators and DevOps engineers) and batch users (data scientists, developers, and ML engineers) can benefit from deploying with Kueue on AKS. The following table outlines the focus and responsibilities for batch admins and users:

| Role | Focus | Job responsibilities |
|------|--------|----------------------|
| **Batch admin** | Configuring, managing, and securing the platform-level infrastructure to support batch workloads. | • Provision and manage AKS node pools. <br> • Define resource quotas, ClusterQueues, and policies for workload isolation. <br> • Tune autoscaling and cost-efficiency (e.g., Cluster Autoscaler, Kueue quotas). <br> • Monitor cluster and queue health. <br> • Create and maintain templates and reusable workflows. |
| **Batch user** | Running compute-intensive or parallel jobs using the platform-level infrastructure configured by a batch admin. | • Submit batch jobs (e.g., Job, Workload, or custom controller CRDs) and monitor job status and outputs. <br> • Select appropriate queue or resource flavor for jobs based on guidance from batch admins. <br> • Optimize job specs for resource and performance needs. |

The following table outlines the scope, owner, and use for ClusterQueues and LocalQueues:

| Queue type | Scope | Created by | Use |
| -------- | -------- | --------- | ------- |
| **ClusterQueue** | Cluster-wide | Platform admin | Define shared compute capacity and quota management |
| **LocalQueue** | Namespace | Namespace owner | Enable workload submission, mapped to ClusterQueue |

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.

## Install Kueue

1. Add the Kueue Helm repository and update it to the latest version using the `helm repo add` and `helm repo update` commands.

    ```bash
    helm repo add kueue https://kubernetes-sigs.github.io/kueue
    helm repo update
    ```

2. Install the Kueue controller and CRDs in a dedicated namespace using the `helm install` command.

    ```bash
    helm install kueue kueue/kueue \
      --namespace kueue-system \
      --create-namespace
    ```

3. Confirm the deployment status using the `helm list` command.

    ```bash
    helm list --namespace kueue-system
    ```

    Your output should include a `Status` of `deployed`, as shown in the following example output:

    ```output
    NAME    NAMESPACE     REVISION   UPDATED   STATUS      CHART          APP VERSION
    kueue	  kueue-system 	1       	       ...               deployed   kueue-0.5.0   0.5.0
    ```

4. Check the installation of the Kueue CRDs on your AKS cluster using the `kubectl get` command.

    ```bash
    kubectl get crds | grep kueue
    ```

    Your output should include all four Kueue CRDs, as shown in the following example output:

    ```output
    clusterqueues.kueue.x-k8s.io         1234-56-78T00:00:00Z
    localqueues.kueue.x-k8s.io            1234-56-78T00:00:00Z
    resourceflavors.kueue.x-k8s.io       1234-56-78T00:00:00Z
    workloads.kueue.x-k8s.io               1234-56-78T00:00:00Z
    ```

In the following examples, we show the difference in scheduling behavior between the AKS native scheduler and the Kueue system for queueing batch workloads.

## Schedule and deploy general-purpose batch jobs with Kueue

### Create a `ClusterQueue`

1. Create a Kueue `ClusterQueue` named `clusterqueue-sample.yaml` and paste in the following YAML manifest:

    ```yaml
   apiVersion: kueue.x-k8s.io/v1beta1
   kind: ClusterQueue
   metadata:
     name: sample-jobs
   spec:
     cohort: general
     namespaceSelector: {}  # Accept workloads from any namespace
     resourceGroups:
       - coveredResources: ["cpu", "memory"]
         flavors:
           - name: on-demand
             resources:
               - name: "cpu"
                 nominalQuota: 4
               - name: "memory"
                 nominalQuota: 8Gi
    ```

    This sample `ClusterQueue` defines:

    * A general **`cohort`**: Used to group multiple `ClusterQueues` together to allow resource borrowing. If one `ClusterQueue` has unused quota, another in the **same** cohort can borrow it for pending jobs.
    * **`namespaceSelector: {}`**: Indicates that `sample-jobs` accepts workloads from any namespace that references this `ClusterQueue` via a `LocalQueue` (you can restrict usage (for example, to only team A's namespace) with a label selector).
    * **`coveredResources: ["cpu", "memory"]` in `resourceGroups`**: Defines the standard CPU and memory resource types managed by this `ClusterQueue`.
    * **`flavor` of `on-demand` nodes with `4` CPUs, `8Gi` memory**: Only workloads scheduled on `on-demand` nodes consume this quota. If the cluster uses up this quota, it won't admit any additional workloads using this flavor (unless you allow borrowing from the `cohort`).

2. Apply the `ClusterQueue` manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f clusterqueue-sample.yaml
    ```


### Create a `LocalQueue`

1. Create a namespace named *batch-jobs* using the `kubectl create` command.

    ```bash
    kubectl create ns batch-jobs
    ```

2. Create a `LocalQueue` named `localqueue-sample.yaml` and paste in the following YAML manifest:

    ```yaml
    apiVersion: kueue.x-k8s.io/v1beta1
    kind: LocalQueue
    metadata:
      name: sample-queue
      namespace: batch-jobs
    spec:
      clusterQueue: sample-jobs
    ```

    This sample `LocalQueue` configures the following settings:

    * Enables users in the `batch-jobs` namespace to submit batch workloads to Kueue.
    * Route the batch workloads to the `sample-jobs` `ClusterQueue`, which manages the actual compute resource quotas and scheduling policies.

3. Apply the `LocalQueue` manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f localqueue-sample.yaml
    ```


### Create batch jobs

1. Create two sample batch jobs to deploy in the *batch-jobs* namespace using the following YAML manifest named `batch-workloads.yaml`:

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: batch-jobs
    ---
    apiVersion: kueue.x-k8s.io/v1beta1
    kind: LocalQueue
    metadata:
      name: sample-queue
      namespace: batch-jobs
    spec:
      clusterQueue: sample-jobs
    ---
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: test-batch-1
      namespace: batch-jobs
      labels:
        kueue.x-k8s.io/queue-name: sample-queue
    spec:
      parallelism: 1
      completions: 1
      template:
        spec:
          containers:
            - name: [insert my container name]
              image: [insert my container image path]
              command: ["sh", "-c", "echo Running test-batch-1; sleep 60"]
              resources:
                requests:
                  cpu: "1"
                  memory: "500Mi"
                limits:
                  cpu: "1"
                  memory: "500Mi"
          restartPolicy: Never
    ---
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: test-batch-2
      namespace: batch-jobs
      labels:
        kueue.x-k8s.io/queue-name: sample-queue
    spec:
      parallelism: 1
      completions: 1
      template:
        spec:
          containers:
            - name: [insert my container name]
              image: [insert my container image path]
              command: ["sh", "-c", "echo Waiting in queue for CPUs...; sleep 30"]
              resources:
                requests:
                  cpu: "2"
                  memory: "1Gi"
                limits:
                  cpu: "2"
                  memory: "1Gi"
          restartPolicy: Never
    ```

2. Apply the manifest for the batch jobs using the `kubectl apply` command.

    ```bash
    kubectl apply -f batch-workloads.yaml
    ```

3. View the status of the batched workloads using the `kubectl get` command.

    ```bash
    kubectl get workloads --namespace batch-jobs
    ```

    Your output should resemble the following example output:

    ```output
    NAME             ADMITTED   AGE
    test-batch-1    True             10s
    test-batch-2    False            5s
    ```


If you run the following command for `test-batch-2` while it is in `Pending` state, you should see an output which includes:

```output
...
...
Status:
  Conditions:
    Type:              Admitted
    Status:            False
    Reason:            QuotaUnavailable
    Message:           Insufficient quota in ClusterQueue sample-jobs 
    (flavor on-demand): requested 2 CPUs, available 1
...
...
```

After `test-batch-1` completes, `test-batch-2` will be admitted and run.

Now, the output should look like the following:

```output
Status:
  Conditions:
    Type:              Admitted
    Status:            True
    Last Transition Time:  1234-56-78T00:00:00Z
  Admission:
    ClusterQueue:      sample-jobs
    PodSetAssignments:
      Name:            main
      Flavors:
        cpu:           on-demand
        memory:        on-demand
      ResourceUsage:
        cpu:           2
        memory:        1Gi
```

## Monitor Kueue deployments and queues via Prometheus metrics

Kueue [exposes Prometheus metrics](https://kueue.sigs.k8s.io/docs/reference/metrics/) for the controller manager service at `http://<kueue-controller-manager-service>:9090/metrics`.

The most commonly used Kueue Prometheus metrics provide insight into queue length, resource availability, and admission status, such as:

* `kueue_workload_admitted_total`: Total number of workloads that have been admitted (scheduled to run) by Kueue since the controller started. This metric helps track how many jobs Kueue has allowed to move from `Pending` to `Running`.
* `kueue_workload_pending_total`: Current number of workloads waiting in queues (i.e., pending due to lack of resources or quota). This is a useful indicator for alerting on backlogs or diagnosing scheduling delays.
* `kueue_clusterqueue_available_resources`: Amount available resources (such as CPU, GPU, memory) in each `ClusterQueue`, after accounting for admitted workloads, to indicate how much headroom remains for new jobs.
* `kueue_clusterqueue_used_resources`: Amount of resources currently in use by admitted workloads in a given `ClusterQueue` and helps correlate actual usage versus quota.

Additional Prometheus metrics can be found in the [official Kueue monitoring documentation](https://kueue.sigs.k8s.io/docs/reference/metrics/).

If you have set up Kueue metrics to be scraped via self-hosted Prometheus or [Azure Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-exporters), the following PromQL queries are helpful for:

Pending workloads:
```promql
sum(kueue_workload_pending_total)
```

Admitted workloads:
```promql
sum(kueue_workload_admitted_total)
```

Resource usage:
```promql
kueue_clusterqueue_used_resources{clusterqueue="sample-jobs"}
```

## Uninstall Kueue

If you no longer need to use the Kueue controller manager or Kueue custom resources in your AKS cluster, you can uninstall the Helm repository, remove the dedicated namespace and resources:

```bash
helm uninstall kueue -n kueue-system
kubectl delete namespace kueue-system
```

## FAQ

### How can I confirm that the Kueue controller is available and running as expected?

Confirm that the Kueue controller manager pod is running:

```bash
kubectl get pods -n kueue-system
```

The Kueue controller manager pod should be in a `Running` state with `1/1` containers ready, as shown in the output below:

```output
NAME                                READY   STATUS      RESTARTS    AGE
kueue-controller-manager-xxxxxxx    1/1     Running     0           2m
```

> [!NOTE]
> If the `Status` shows `CrashLoopBackOff` or `Pending`, check the deployment logs:

> ```bash
> kubectl logs -n kueue-system deployment/kueue-controller-manager
> ```

### One or more of the Kueue CRDs are missing when I install via Helm. How can I ensure all of the custom resources are installed?

After installing Kueue, confirm that all 4 of the following CRDs are present:

```bash
kubectl get crds | grep kueue
```

Expected CRDs:

```bash
clusterqueues.kueue.x-k8s.io
localqueues.kueue.x-k8s.io
resourceflavors.kueue.x-k8s.io
workloads.kueue.x-k8s.io
```

If one or more of the CRDs are missing, you may see errors in controller logs, failed job queuing, `CrashLoopBackOff` for the controller, or inability to admit or schedule workloads. In this case, you can reinstall the Kueue CRDs manually:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/kueue/releases/latest/download/kueue-crds.yaml
```

Please note that if the CRDs were installed manually, then they should also be removed manually:

```bash
kubectl delete crd clusterqueues.kueue.x-k8s.io \
  localqueues.kueue.x-k8s.io \
  workloads.kueue.x-k8s.io \
  resourceflavors.kueue.x-k8s.io
```

In this article, you:
* Installed Kueue on your Azure Kubernetes Service (AKS) cluster using Helm and verified CRDs, controller health, and namespace setup.
* Configured `ClusterQueue` and `LocalQueue` for general-purpose workloads with resource quotas and flavors (e.g., on-demand).
* Submitted two batch jobs to demonstrate queuing: one admitted immediately, the second held due to quota limits, then admitted when resources became available.
* Monitored workload status and controller logs to confirm scheduling behavior and queuing logic.
* Enabled observability via Prometheus metrics to track queue depth, resource usage, and admission events.

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md