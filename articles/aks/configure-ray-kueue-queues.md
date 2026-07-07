---
title: Configure Kueue queues for Ray workloads on Azure Kubernetes Service (AKS)
description: Learn how to configure Kueue ResourceFlavors, ClusterQueues, and LocalQueues to manage admission control for Ray workloads on AKS.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Configure Kueue queues for Ray workloads on AKS

In this article, you configure Kueue admission control for Ray workloads on Azure Kubernetes Service (AKS). Kueue gates RayJob submissions: jobs are created with `suspend: true` and a queue label. Kueue admits them when quota is available by setting `suspend: false`, which triggers the KubeRay operator to create the Ray cluster.

Two queue configurations are provided. Choose the one that fits your use case:

| Configuration | What it demonstrates |
|---------------|------|
| **Single queue** | One ClusterQueue with backpressure - one workload runs, the next waits |
| **Team queues** | Two ClusterQueues in a shared cohort with per-team quotas, borrowing, and preemption |

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* Infrastructure deployed following [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md).
* `kubectl` connected to the cluster.
* Kueue controller running (verify with `kubectl -n kueue-system get pods`).

## Create the namespace and service account

Navigate to the queue configuration module in the cloned repository:

```bash
cd <path-to-cloned-repo>/AKS/examples/kueue-and-ray-on-aks/2-kueue-queues
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f <(terraform -chdir=../1-infrastructure/terraform output -raw ray_workload_sa_yaml)
```

Verify the service account has workload identity annotations:

```bash
kubectl -n ray get serviceaccount ray-workload -o yaml
```

The output should include `azure.workload.identity/client-id` and `azure.workload.identity/tenant-id` annotations that allow Ray pods to access Azure Blob Storage without credentials.

## Create ResourceFlavors

ResourceFlavors describe types of nodes available in the cluster. Create two flavors - `default` (any node) and `gpu` (NVIDIA accelerator nodes):

```bash
kubectl apply -f manifests/10-resource-flavors.yaml
```

Verify:

```bash
kubectl get resourceflavors
```

Expected output:

```output
NAME      AGE
default   1m
gpu       1m
```

The `gpu` flavor targets nodes with label `accelerator=nvidia`, which AKS automatically applies to GPU node pools.

## Option A: Configure a single queue

The single-queue configuration creates one ClusterQueue with quotas sized for one workload at a time. When quota is fully consumed, the next submission stays Pending until the first completes.

```bash
kubectl apply -f manifests/20-single-queue.yaml
```

Verify the ClusterQueue and LocalQueue:

```bash
kubectl get clusterqueue cluster-queue
kubectl -n ray get localqueue default
```

Expected output:

```output
NAME            COHORT   PENDING WORKLOADS
cluster-queue            0
```

```output
NAME      CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
default   cluster-queue   0                   0
```

Check the configured quotas:

```bash
kubectl get clusterqueue cluster-queue -o jsonpath='{.spec.resourceGroups}' | python3 -m json.tool
```

Default quotas are sized to admit one workload from this solution at a time: 96 CPU, 768 Gi memory, 8 GPUs.

## Option B: Configure team queues with borrowing

The team-queue configuration splits the GPU node across two teams, each with their own ClusterQueue, connected via a shared cohort:

```bash
kubectl apply -f manifests/30-team-queues.yaml
```

> [!IMPORTANT]
> Choose Option A or Option B, not both. To switch between them, delete the active configuration first:
> ```bash
> kubectl delete -f manifests/20-single-queue.yaml
> ```

Verify:

```bash
kubectl get clusterqueues
kubectl -n ray get localqueues
```

Expected output:

```output
NAME        COHORT          PENDING WORKLOADS
team-a-cq   shared-cohort   0
team-b-cq   shared-cohort   0
```

```output
NAME     CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
team-a   team-a-cq       0                   0
team-b   team-b-cq       0                   0
```

> [!NOTE]
> The workload examples default to `QUEUE_NAME=default`, which matches Option A. If you chose Option B, set `export QUEUE_NAME=team-a` or `export QUEUE_NAME=team-b` **before** running `source env.example` in each workload directory.

Each team gets 4 GPUs guaranteed with a `borrowingLimit` of 4, so a team can use up to 8 GPUs total when the other team is idle. Key behaviors:

| Scenario | What happens |
|----------|-------------|
| Team A submits, Team B idle | Team A gets all 8 GPUs (4 own + 4 borrowed) |
| Team B submits while Team A uses 8 | Kueue preempts Team A's borrowed GPUs, Team B gets its guaranteed 4 |
| Both teams busy | Each team uses its guaranteed 4 GPUs |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Workload stays Pending | Quota exhausted | Wait for the running workload to finish, or increase `nominalQuota` in the ClusterQueue |
| `LocalQueue not found` | Wrong queue-name label | Verify the `kueue.x-k8s.io/queue-name` label matches an existing LocalQueue name |
| ResourceFlavor not matching nodes | Missing node label | Check GPU nodes have `accelerator=nvidia` label with `kubectl get nodes --show-labels` |
| Kueue controller not running | Helm release issue | Check with `kubectl -n kueue-system logs deploy/kueue-controller-manager` |

For the full manifest details, see the [2-kueue-queues directory](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks/2-kueue-queues) in the repository.

## Clean up resources

To remove the Kueue queue configuration (keeps the cluster and operators):

```bash
kubectl delete -f manifests/20-single-queue.yaml   # or 30-team-queues.yaml
kubectl delete -f manifests/10-resource-flavors.yaml
kubectl delete -f manifests/00-namespace.yaml
```

> [!NOTE]
> Deleting the `ray` namespace removes all workloads, LocalQueues, and the ServiceAccount in that namespace. ClusterQueues and ResourceFlavors are cluster-scoped and must be deleted separately. To tear down the entire infrastructure, see [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md#clean-up-resources).

## Next steps

Run the workload examples on your configured queues. Steps 1–2 and steps 3–4 are independent pairs:

1. [Fine-tune the Aurora weather model](./ray-finetune-aurora.md)
2. [Serve the fine-tuned Aurora model with Ray Serve](./ray-online-serving.md) (requires step 1)
3. [Train an LLM with Ray](./ray-train-llm.md)
4. [Run batch inference with Ray](./ray-batch-inference.md) (requires step 3)
