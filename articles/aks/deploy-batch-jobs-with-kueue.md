---
title: Schedule and Deploy Batch Jobs with Kueue on Azure Kubernetes Service (AKS)
description: Learn how to define Kueue deployments and efficiently schedule batch workloads on your Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 9/26/2025
author: colinmixonn
ms.author: colinmixon
# Customer intent: "As a platform admin, I want to quickly schedule and deploy batch jobs to ensure efficient resource utilization and cost optimization on AKS cluster(s), enabling platform developers to run bursty workloads to completion without impacting the performance of other services."
---

# Schedule and deploy batch jobs with Kueue on Azure Kubernetes Service (AKS)

In this article, you learn how to schedule and deploy sample batch jobs on Azure Kubernetes Service (AKS) using Kueue. Also, this guide covers installing Kueue, configuring ResourceFlavors and ClusterQueues for fine-grained resource management, and submitting jobs via LocalQueues. You also learn how to use Kueue to queue up a sample batch job and track the results across Pending, Running, and Finished states.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

To learn more about Kueue and common uses cases for batch workload administrators and users, see [Kueue overview on AKS](./kueue-overview.md).

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.
* [The latest version of Kueue installed in a dedicated namespace on your cluster](./kueue-overview.md#prerequisites).

## Define a ResourceFlavor object

In Kueue, a ResourceFlavors enables fine-grained resource management by associating workloads with specific nodes, taints, tolerations, or availability zones. For nodes, `ResourceFlavors` can define the characteristics like pricing, availability, brands, models, and architecture (that is, x86 versus ARM CPUs). A `ClusterQueue` uses these flavors to manage quotas and admission policies for workloads.

This configuration defines a `ResourceFlavor` without any labels or taints, known as an empty `ResourceFlavor`. This configuration is perfect when quotas for different flavors don't need to be managed.

1. Create and save a `ResourceFlavor` in a file named `resourceflavor-sample.yaml` with the following manifest:
      ```bash
     cat << EOF > resourceflavor-sample.yaml
     apiVersion: kueue.x-k8s.io/v1beta1
     kind: ResourceFlavor
     metadata:
       name: on-demand
     EOF
     ```
2. apply
     ```bash
     kubectl apply -f resourceflavor-sample.yaml
     ```
3. verify
     ```bash
     kubectl get resourceflavors
     ```
     
     Example output
   
     ```output
     NAME        AGE
     on-demand   5m32s
     ```

## Create a ClusterQueue

A ClusterQueue is a cluster-scoped resource that governs a pool of resources, defining usage limits and Fair Sharing rules. Where applicable, Fair Sharing rules allow another ClusterQueue in the **same** cohort to unused quota for pending jobs. Each ClusterQueue specifies which flavors it supports and how much quota is available for each. 

This sample `ClusterQueue` defines:

* **`namespaceSelector: {}`**: Indicates that `sample-jobs` accepts workloads from any namespace that references this `ClusterQueue` via a `LocalQueue` (you can restrict usage (for example, to only team A's namespace) with a label selector).
* **`coveredResources: ["cpu", "memory"]` in `resourceGroups`**: Defines the standard CPU and memory resource types managed by this `ClusterQueue`.
* **`flavor` of `on-demand` nodes with `4` CPUs, `8Gi` memory**: Only workloads scheduled on `on-demand` nodes consume this quota. If the cluster uses up this quota, it doesn't admit any other workloads using this flavor (unless you allow borrowing from the `cohort`).

1. Create and save a Kueue `ClusterQueue` in a file named `clusterqueue-sample.yaml` with the following manifest:

    ```batch
    cat <<EOF > clusterqueue-sample.yaml
    apiVersion: kueue.x-k8s.io/v1beta1
    kind: ClusterQueue
    metadata:
       name: sample-jobs
    spec:
       cohort: general
      namespaceSelector: {} # Accept workloads from any namespace
      resourceGroups:
       - coveredResources: ["cpu", "memory"]
         flavors:
           - name: on-demand
             resources:
               - name: "cpu"
                 nominalQuota: 4
               - name: "memory"
                 nominalQuota: 8Gi
    EOF
    ```
2. Apply the `ClusterQueue` manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f clusterqueue-sample.yaml
    ```
3. Verify the ClusterQueue` manifest was applied

   ```bash
   kubectl get clusterqueues
   ```
   
   Example output
   
   ```output
   NAME          COHORT    PENDING WORKLOADS
   sample-jobs   general   0
   ```
> [!NOTE]
> The `ClusterQueue` isn't ready for use until a `ResourceFlavor` object is configured. If you create a `ClusterQueue` without any existing `ResourceFlavor`, workloads referencing it are marked as `Inadmissible`.

## Create a LocalQueue

A LocalQueue is a namespace-scoped resource that acts as a gateway for users to submit jobs. A `LocalQueue` is assigned to one `ClusterQueue` from which resources are allocated to run its workloads.

This sample `LocalQueue` configures the following settings:

* Enables users in the `batch-jobs` namespace to submit batch workloads to Kueue.
* Route the batch workloads to the `sample-jobs` `ClusterQueue`, which manages the actual compute resource quotas and scheduling policies.
    
1. Create a namespace named *batch-jobs* using the `kubectl create` command.

    ```bash
    kubectl create ns batch-jobs
    ```

2. Create and save a `LocalQueue` in a file named `localqueue-sample.yaml` with the following YAML manifest:

    ```bash
    cat <<EOF > localqueue-sample.yaml
    apiVersion: kueue.x-k8s.io/v1beta1
    kind: LocalQueue
    metadata:
      name: sample-queue
      namespace: batch-jobs
    spec:
      clusterQueue: sample-jobs
    EOF
    ```

3. Apply the `LocalQueue` manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f localqueue-sample.yaml
    ```

4. Verify the `LocalQueue` manifest was applied
   ```bash
   kubectl get localqueues --all-namespaces
   ```
   Exampmle output
   
   ```output
   NAMESPACE    NAME           CLUSTERQUEUE   PENDING WORKLOADS   ADMITTED WORKLOADS
   batch-jobs   sample-queue   sample-jobs    0                   0
   ```

## Create 2 batch jobs

This configuration defines two Kubernetes batch jobs submitted to the batch-jobs namespace and assigned to the sample-queue managed by Kueue. Both jobs are single-instance (parallelism: 1, completions: 1) and are configured with `Never` restart policy. The fields `parallelism` and `completions` control how many pods are run and how the job is considered complete. So `parallelism` and `completions` of 1 means that one pod can run at once, and the job is marked as complete once one pod finishes successfully, per batch job.

* Job test-batch-1: Requests one CPU and 500Mi memory
* Job test-batch-2: Requests two CPUs and 1Gi memory

1. Create two sample batch jobs to deploy in the *batch-jobs* namespace using the following YAML manifest named `batch-workloads.yaml`:

    ```bash
    cat <<EOF > batch-workloads.yaml
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
            - name: dummy-job
              image: registry.k8s.io/e2e-test-images/agnhost:2.53
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
            - name: dummy-job
              image: registry.k8s.io/e2e-test-images/agnhost:2.53
              command: ["sh", "-c", "echo Waiting in queue for CPUs...; sleep 30"]
              resources:
                requests:
                  cpu: "2"
                  memory: "1Gi"
                limits:
                  cpu: "2"
                  memory: "1Gi"
          restartPolicy: Never
    EOF
    ```

2. Apply the manifest for the batch jobs using the `kubectl apply` command.

    ```bash
    kubectl apply -f batch-workloads.yaml
    ```
## Verify Batch Jobs are Submitted to `LocalQueue`
1. View the status of the batched workloads using the `kubectl get` command.

    ```bash
    kubectl get workloads --namespace batch-jobs
    ```

    Example output
   
    ```output
    NAME            ADMITTED    AGE
    test-batch-1    True        10s
    test-batch-2    False       5s
    ```
    
2. Run the following command for `test-batch-2` while it is in a `Pending` state

    ```bash
    kubectl get workloads test-batch-2 -o yaml
    ```

    Expected output
   
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

    Now, the output should look like the following example output:
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
3. View the final status of the `batch-jobs` namespace using the `kubectl get` command.

    ```bash
    kubectl get job,deploy,rs,pod,workload --namespace batch-jobs
    ```

    Example output

    ```output
    NAME                     STATUS     COMPLETIONS   DURATION   AGE
    job.batch/test-batch-1   Complete   1/1           97s        3m15s
    job.batch/test-batch-2   Complete   1/1           35s        3m15s
    
    NAME                     READY   STATUS      RESTARTS   AGE
    pod/test-batch-1-hb8zl   0/1     Completed   0          3m15s
    pod/test-batch-2-dx9hk   0/1     Completed   0          3m15s
    
    NAME                                             QUEUE          RESERVED IN   ADMITTED   FINISHED   AGE
    workload.kueue.x-k8s.io/job-test-batch-1-6fb85   sample-queue   sample-jobs   True       True       3m15s
    workload.kueue.x-k8s.io/job-test-batch-2-84f49   sample-queue   sample-jobs   True       True       3m15s
    ```

## FAQ

### Question 1: How can I confirm that the Kueue controller is available and running as expected?

1. Confirm the Kueue controller manager pod is running using the `kubectl get` command.
    
    ```bash
    kubectl get pods --namespace kueue-system
    ```
    
    The Kueue controller manager pod should be in a `Running` state with `1/1` containers ready, as shown in the following example output:
    
    ```output
    NAME                                                 READY   STATUS      RESTARTS    AGE
    kueue-controller-manager-xxxxxxx    1/1        Running     0                  2m
    ```

2. If the `Status` shows `CrashLoopBackOff` or `Pending`, check the deployment logs using the `kubectl logs` command.
    
    ```bash
    kubectl logs --namespace kueue-system deployment/kueue-controller-manager
    ```

### Question 2: One or more of the Kueue custom resources (CRDs) are missing when I install via Helm. How can I ensure all of the CRDs are installed?

1. After installing Kueue with the [Kueue overview on AKS](./kueue-overview.md) guidance, confirm that all of the CRDs are installed using the `kubectl get` command.
    
    ```bash
    kubectl get crds | grep kueue
    ```
    These CRDs should be listed, as shown in the following example output:

    ```output
    admissionchecks.kueue.x-k8s.io
    clusterqueues.kueue.x-k8s.io
    cohorts.kueue.x-k8s.io
    localqueues.kueue.x-k8s.io
    multikueueclusters.kueue.x-k8s.io
    multikueueconfigs.kueue.x-k8s.io
    provisioningrequestconfigs.kueue.x-k8s.io
    resourceflavors.kueue.x-k8s.io
    topologies.kueue.x-k8s.io
    workloadpriorityclasses.kueue.x-k8s.io
    workloads.kueue.x-k8s.io
    ```

2. If one or more of the CRDs are missing, you might see errors in controller logs, failed job queuing, `CrashLoopBackOff` for the controller, or inability to admit or schedule workloads. In this case, you can manually reinstall the Kueue CRDs using the `kubectl apply` command.

    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/kueue/releases/latest/download/kueue-crds.yaml
    ```

    > [!NOTE]
    > Note that if you manually install the CRDs, you need to manually delete them once you're finished using the `kubectl delete` command.
### Question 3: What's the difference between a LocalQueue and a ClusterQueue

A ClusterQueue is a cluster-scoped resource that defines and governs a pool of compute resources like CPU, memory, pods, and accelerators across the entire Kubernetes cluster. A LocalQueue is a namespace-scoped resource that acts as a gateway for users to submit jobs within the defined Kubernetes cluster. This separation allows for fine-grained control over resource allocation and multi-tenant scheduling without exposing cluster-wide quotas directly to users. 

How they work together:


1. A user submits a job to a LocalQueue in their namespace.
2. Kueue routes the job to the referenced ClusterQueue.
3. The ClusterQueue checks resource availability and quota limits.
4. If admitted, the job is unsuspended and scheduled.

## Next steps

In this article, you:

* Installed Kueue on your Azure Kubernetes Service (AKS) cluster using Helm and verified CRDs, controller health, and namespace setup.
* Configured `ClusterQueue` and `LocalQueue` for general-purpose workloads with resource quotas and flavors (such as on-demand).
* Submitted two batch jobs to demonstrate queuing: one admitted immediately, the second held due to quota limits, then admitted when resources became available.
* Monitored workload status and controller logs to confirm scheduling behavior and queuing logic.

To learn more about Kueue, visit the following resources:

* [Multi-cluster scheduling and resource placement with Kueue and KubeFleet on AKS](https://blog.aks.azure.com/2025/04/02/Scaling-Kubernetes-for-AI-and-Data-intensive-Workloads).
* [Kueue developer tools](https://kueue.sigs.k8s.io/docs/tasks/dev/) official documentation.

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
