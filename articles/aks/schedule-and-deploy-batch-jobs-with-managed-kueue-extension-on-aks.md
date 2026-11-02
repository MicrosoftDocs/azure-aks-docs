---
title: Schedule and deploy batch jobs with managed Kueue extension on AKS
description: Use managed Kueue resource flavors and default workload priority classes to configure queues, run batch Jobs, and demonstrate preemption on AKS.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 10/22/2026
author: colinmixonn
ms.author: colinmixon
ai-usage: ai-assisted
# Customer intent: "As a platform administrator, I want to use managed Kueue resources to configure queues and observe batch Job admission and priority-based preemption."
---

# Schedule and deploy batch jobs with managed Kueue extension on Azure Kubernetes Service (AKS)

In this article, you use the managed Kueue extension's generated ResourceFlavor and default workload priority classes to run batch Jobs on Azure Kubernetes Service (AKS). You create your own ClusterQueue and LocalQueue, reference the managed defaults, and observe one Job waiting while another consumes queue quota. You then use the same queues to demonstrate low- and high-priority preemption.

For concepts, see [Managed Kueue extension overview](./managed-kueue-extension-overview.md). For installation and lifecycle operations, see [Install the managed Kueue extension on AKS](./install-the-managed-kueue-extension-on-aks.md).

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

- An AKS cluster with the [managed Kueue extension installed and verified](./install-the-managed-kueue-extension-on-aks.md#verify-the-extension-installation).
- A CPU user node pool with enough available resources for a pod requesting two CPUs and 1 Gi of memory. If needed, follow [Add a CPU user node pool](#add-a-cpu-user-node-pool).
- The [Azure CLI](/cli/azure/install-azure-cli) and a compatible [kubectl](https://kubernetes.io/docs/tasks/tools/) connected to your cluster.
- Permissions to manage the example namespace, queues, and Jobs and to read the managed ResourceFlavor and priority classes.

## Add a CPU user node pool

Skip pool creation if an existing CPU user pool has sufficient available resources. Otherwise, set your cluster details and add an example pool:

```bash
RESOURCE_GROUP="<resource-group>"
CLUSTER_NAME="<aks-cluster-name>"

az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name cpupool \
  --node-count 1 \
  --node-vm-size Standard_D4s_v6 \
  --mode User

kubectl wait --for=condition=Ready nodes \
  --selector kubernetes.azure.com/agentpool=cpupool --timeout=10m
```

## Use the managed ResourceFlavor

A ResourceFlavor describes node characteristics that Kueue uses when assigning resources to a workload. The managed extension generates `aks-cpu` for eligible CPU user nodes. You reference it from a ClusterQueue rather than creating an empty replacement flavor.

Verify that the generated flavor exists:

```bash
kubectl wait --for=create resourceflavor/aks-cpu --timeout=5m
kubectl get resourceflavor aks-cpu --output yaml
```

The flavor covers eligible CPU user nodes, not necessarily one particular node pool. To target a particular pool, review your workload's placement constraints and capacity. Don't change the managed flavor's labels to implement customer policy.

If the flavor is missing, check the user node pool, node readiness, and extension controller before creating queues. Don't create a ResourceFlavor named `aks-cpu` yourself.

## Use a default workload priority class

The managed extension provides these workload priority classes:

| Class | Value | Example use |
| --- | --- | --- |
| `aks-low-priority` | `100` | Workloads that can wait behind more important work. |
| `aks-medium-priority` | `500` | Workloads with standard priority requirements. |
| `aks-high-priority` | `1000` | Workloads that need higher admission priority. |

Inspect the existing classes:

```bash
kubectl get workloadpriorityclasses aks-low-priority aks-medium-priority aks-high-priority
```

Set `kueue.x-k8s.io/priority-class` on a Job to reference one of these classes. It isn't a pod `priorityClassName`, and it doesn't enable preemption without an appropriate queue policy. The first two Jobs use `aks-medium-priority` to demonstrate queueing without preempting each other. Later, you use low- and high-priority Jobs to demonstrate preemption with the same queue configuration.

## Create a ClusterQueue and LocalQueue

A ClusterQueue defines quotas and flavor references. A LocalQueue provides a submission point in a namespace and routes workloads to a ClusterQueue.

Save the following manifest as `batch-queues.yaml`. It creates:

- The example `batch-jobs` namespace.
- A `sample-jobs` ClusterQueue that references the existing managed `aks-cpu` ResourceFlavor, with three CPUs and 2 Gi of memory of nominal quota. Its `LowerPriority` policy permits preemption only by a higher-priority workload in the queue.
- A `sample-queue` LocalQueue in the example namespace.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: batch-jobs
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: sample-jobs
spec:
  namespaceSelector: {}
  queueingStrategy: BestEffortFIFO
  preemption:
    withinClusterQueue: LowerPriority
  resourceGroups:
  - coveredResources:
    - cpu
    - memory
    flavors:
    - name: aks-cpu
      resources:
      - name: cpu
        nominalQuota: "3"
      - name: memory
        nominalQuota: 2Gi
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: sample-queue
  namespace: batch-jobs
spec:
  clusterQueue: sample-jobs
```

Apply the configuration and wait for queue readiness:

```bash
kubectl apply -f batch-queues.yaml
kubectl wait --for=condition=Active clusterqueue/sample-jobs --timeout=2m
kubectl wait --for=condition=Active localqueue/sample-queue \
  --namespace batch-jobs --timeout=2m
```

The example accepts submissions from any namespace whose LocalQueue references this ClusterQueue. In a shared cluster, use a namespace selector appropriate for your isolation policy.

The queue's three-CPU quota is an admission limit. It doesn't reserve physical nodes or change your Azure subscription quota.

## Submit the first batch Job

Save the following manifest as `batch-job-1.yaml`. The Job starts suspended so Kueue can control admission. Its queue label references the LocalQueue in the same namespace, and its priority label references the managed default class:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-batch-1
  namespace: batch-jobs
  labels:
    kueue.x-k8s.io/queue-name: sample-queue
    kueue.x-k8s.io/priority-class: aks-medium-priority
spec:
  suspend: true
  parallelism: 1
  completions: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: mcr.microsoft.com/azurelinux/busybox:1.36
        command: ["sh", "-c", "echo first batch job; sleep 300"]
        resources:
          requests:
            cpu: "2"
            memory: 1Gi
```

Apply the first Job and wait until its pod is ready before submitting the second:

```bash
kubectl apply -f batch-job-1.yaml
kubectl wait --for=jsonpath='{.status.ready}'=1 job/test-batch-1 \
  --namespace batch-jobs --timeout=5m
```

If the Job doesn't run, inspect the Workload and pod events before continuing. The next step assumes the first Job is still running and consuming the queue's quota.

## Submit a second job to the queue

Save the following manifest as `batch-job-2.yaml`. It requests the same two CPUs and the same priority as the first job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-batch-2
  namespace: batch-jobs
  labels:
    kueue.x-k8s.io/queue-name: sample-queue
    kueue.x-k8s.io/priority-class: aks-medium-priority
spec:
  suspend: true
  parallelism: 1
  completions: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: mcr.microsoft.com/azurelinux/busybox:1.36
        command: ["sh", "-c", "echo second batch job; sleep 30"]
        resources:
          requests:
            cpu: "2"
            memory: 1Gi
```

Apply the second job:

```bash
kubectl apply -f batch-job-2.yaml
kubectl get jobs,pods,workloads --namespace batch-jobs
```

While the first job holds two of the queue's three CPUs of quota, the second job can't reserve another two CPUs. The jobs have equal priority, so the `LowerPriority` policy doesn't let them preempt each other. The second job waits for quota instead of starting its pod. If the first job finishes before you submit the second, the second can be admitted immediately; that isn't a queue failure.

## Verify workload admission and completion

List workloads and inspect their conditions and owner references:

```bash
kubectl get workloads --namespace batch-jobs
kubectl get events --namespace batch-jobs --sort-by=.metadata.creationTimestamp
kubectl describe clusterqueue sample-jobs
```

Workload names are generated by the job integration and aren't necessarily equal to job names. To inspect one, use the actual name returned by the list command:

```bash
WORKLOAD_NAME="<workload-name-from-list>"
kubectl describe workload "$WORKLOAD_NAME" --namespace batch-jobs
```

After the first job completes, Kueue releases its quota. The second job then becomes eligible for admission. Wait for both jobs to finish:

```bash
kubectl wait --for=condition=Complete job/test-batch-1 \
  --namespace batch-jobs --timeout=10m
kubectl wait --for=condition=Complete job/test-batch-2 \
  --namespace batch-jobs --timeout=10m
kubectl get jobs,pods,workloads --namespace batch-jobs
```

A workload that is admitted can still have pending pods if node capacity or placement constraints aren't satisfied. Distinguish Kueue admission from Kubernetes scheduling by examining workload conditions and pod events.

## Use workload priority and preemption

After the two medium-priority jobs complete, use the same ClusterQueue and LocalQueue for this example. Each new job requests two CPUs against the queue's three-CPU quota, so both can't reserve quota at the same time.

Preemption can stop a running workload and discard work that it hasn't checkpointed. Use disposable Jobs for this example and configure checkpointing for production workloads that need to resume safely.

### Start a low-priority Job

Save the following manifest as `low-priority-job.yaml`. It uses the managed `aks-low-priority` class:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: low-priority-job
  namespace: batch-jobs
  labels:
    kueue.x-k8s.io/queue-name: sample-queue
    kueue.x-k8s.io/priority-class: aks-low-priority
spec:
  suspend: true
  parallelism: 1
  completions: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: mcr.microsoft.com/azurelinux/busybox:1.36
        command: ["sh", "-c", "echo low-priority job; sleep 600"]
        resources:
          requests:
            cpu: "2"
            memory: 512Mi
```

Submit the Job and wait for its pod to become ready before proceeding:

```bash
kubectl apply -f low-priority-job.yaml
kubectl wait --for=jsonpath='{.status.ready}'=1 job/low-priority-job \
  --namespace batch-jobs --timeout=5m
```

If the Job doesn't run, inspect its Workload conditions and pod events instead of submitting the high-priority Job yet.

### Submit a high-priority job

Save the following manifest as `high-priority-job.yaml`. It uses the managed `aks-high-priority` class:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: high-priority-job
  namespace: batch-jobs
  labels:
    kueue.x-k8s.io/queue-name: sample-queue
    kueue.x-k8s.io/priority-class: aks-high-priority
spec:
  suspend: true
  parallelism: 1
  completions: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: mcr.microsoft.com/azurelinux/busybox:1.36
        command: ["sh", "-c", "echo high-priority job; sleep 60"]
        resources:
          requests:
            cpu: "2"
            memory: 512Mi
```

Submit the high-priority job and check the admission and pod states:

```bash
kubectl apply -f high-priority-job.yaml
kubectl get jobs,pods,workloads --namespace batch-jobs
kubectl get events --namespace batch-jobs --sort-by=.metadata.creationTimestamp
```

The expected sequence is:

1. The low-priority job uses two of the queue's three CPUs of quota.
1. The high-priority job doesn't fit in the remaining one CPU of quota. The `LowerPriority` policy lets Kueue preempt the low-priority workload.
1. Kueue suspends the low-priority job and admits the high-priority job. Check Workload conditions and events to confirm preemption instead of assuming that every pending pod was preempted.
1. After the high-priority job finishes, the low-priority job becomes eligible for admission again. Its replacement pod restarts the example command.

Workload names come from their owning resources. List Workloads and check their owner references instead of assuming a Workload has the same name as its job.

```bash
kubectl wait --for=condition=Complete job/high-priority-job \
  --namespace batch-jobs --timeout=5m
kubectl get jobs,pods,workloads --namespace batch-jobs
```

## Troubleshooting

| Symptom | Next action |
| --- | --- |
| `aks-cpu` is missing. | Confirm an eligible CPU user node is Ready and inspect the managed extension controller. Don't create a replacement with the managed name. |
| A ClusterQueue isn't active. | Check that its referenced flavor exists and inspect its conditions. |
| A Job remains suspended. | Verify its LocalQueue label, namespace, queue readiness, quota, and admission checks. |
| A pod is pending after admission. | Inspect pod scheduling events, node labels, taints, tolerations, and available CPU and memory. |
| A higher-priority Job doesn't preempt the running Job. | Check both priority labels, the queue's `LowerPriority` policy, and the Workload conditions and events. Priority alone doesn't enable preemption. |
| A managed controller or CRD is missing. | Repeat the managed extension's [verification steps](./install-the-managed-kueue-extension-on-aks.md#verify-the-extension-installation). Don't apply CRDs from an arbitrary upstream release to a managed installation. |

For controller logs:

```bash
kubectl get deployment,pods --namespace kueue-system
kubectl logs deployment/kueue-controller-manager --namespace kueue-system --tail=200
kubectl logs deployment/kueue-extension --namespace kueue-system --tail=200
```

## Clean up resources

Delete the example Jobs first, and then the example namespace and queue configuration:

```bash
kubectl delete -f batch-job-1.yaml -f batch-job-2.yaml \
  -f low-priority-job.yaml -f high-priority-job.yaml
kubectl delete -f batch-queues.yaml
```

This cleanup removes only the resources created by this walkthrough. Keep the managed `aks-cpu` ResourceFlavor, default workload priority classes, and managed extension. If you created `cpupool` only for this example, check its remaining workloads before [deleting that node pool](./delete-node-pool.md#delete-a-node-pool).

## Next steps

- [Review managed Kueue concepts and features](./managed-kueue-extension-overview.md).
- [Use managed Kueue with the cluster autoscaler](./use-managed-kueue-extension-with-the-cluster-autoscaler-on-aks.md).
- [Run Ray AI workloads with Kueue](./ray-overview.md).
