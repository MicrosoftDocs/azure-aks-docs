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

In this article, you learn how to schedule and deploy sample batch jobs on Azure Kubernetes Service (AKS) using the Kueue controller manager and custom resources. You also learn how to use Kueue to queue up sample general-purpose deployments and track the results with Kueue Prometheus metrics.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

To learn more about Kueue and common uses cases for batch workload administrators and users, see [Kueue overview on AKS](./kueue-overview.md).

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.
* [The latest version of Kueue installed in a dedicated namespace on your cluster](./kueue-overview.md#prerequisites).

In the following examples, we show the difference in scheduling behavior between the AKS native scheduler and the Kueue system for queueing batch workloads.

## Schedule and deploy general-purpose batch jobs with Kueue

- Create a Kueue `ClusterQueue` named `clusterqueue-sample.yaml` and paste in the following manifest:

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

    ```bash
    kubectl get workloads test-batch-2 -o yaml
    ```

    Expected output:

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

## FAQ

### How can I confirm that the Kueue controller is available and running as expected?

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

### One or more of the Kueue CRDs are missing when I install via Helm. How can I ensure all of the custom resources are installed?

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
    > Please note that if you manually install the CRDs, you need to manually delete them once you're finished using the `kubectl delete` command.

## Next steps

In this article, you:

* Installed Kueue on your Azure Kubernetes Service (AKS) cluster using Helm and verified CRDs, controller health, and namespace setup.
* Configured `ClusterQueue` and `LocalQueue` for general-purpose workloads with resource quotas and flavors (e.g., on-demand).
* Submitted two batch jobs to demonstrate queuing: one admitted immediately, the second held due to quota limits, then admitted when resources became available.
* Monitored workload status and controller logs to confirm scheduling behavior and queuing logic.

To learn more about Kueue, visit the following resources:

* [Monitor your Kueue deployments with key Prometheus metrics](./kueue-monitoring.md)
* [Multi-cluster scheduling and resource placement with Kueue and KubeFleet on AKS](https://blog.aks.azure.com/2025/04/02/Scaling-Kubernetes-for-AI-and-Data-intensive-Workloads).
* [Kueue developer tools](https://kueue.sigs.k8s.io/docs/tasks/dev/) official documentation.

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
