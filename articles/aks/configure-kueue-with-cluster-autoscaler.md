---
title: Configure Kueue with the cluster autoscaler on Azure Kubernetes Service (AKS)
description: Learn how to pair Kueue with the AKS cluster autoscaler to autoscale your AI workloads.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/17/2026
author: AaronLiChen
ms.author: lichen5
ms.custom: 'stateful-workloads'
---

# Provision capacity for Kueue batch jobs with the cluster autoscaler on AKS

In this article, you pair [Kueue](https://kueue.sigs.k8s.io/) admission control with the Azure Kubernetes Service (AKS) [cluster autoscaler](./cluster-autoscaler-overview.md) so that batch jobs get the nodes they need *before* they run. Create jobs with `suspend: true` and a queue label. Kueue creates a Kubernetes [ProvisioningRequest](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/provisioningrequest) on their behalf. The cluster autoscaler atomically scales up the node pool to satisfy it, and only then does Kueue admit the job.

| Component | Role |
|-----------|------|
| **Kueue** | Queues the job and gates admission against quota |
| **ProvisioningRequest AdmissionCheck** | Asks the cluster autoscaler for capacity before admission |
| **Cluster autoscaler** | Atomically scales up the node pool to satisfy the request |

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* This article assumes basic knowledge of Kueue. For more information, see [Learn about Kueue for batch scheduling](./kueue-overview.md).
* An AKS cluster with a node pool that has the [cluster autoscaler enabled](./cluster-autoscaler-overview.md). The examples use a pool named `scalepool` with `--min-count 1 --max-count 5`.
* The Azure CLI version 2.70 or later. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* `kubectl` connected to the cluster (`az aks get-credentials`).
* Helm 3.12 or later to install the Kueue controller.

You can find the example manifests used in this article in the [kueue-and-ray-on-aks](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks) directory of the Azure/AKS repository. Clone the repository so you can run them:

```bash
git clone https://github.com/Azure/AKS.git
cd AKS/examples/kueue-and-ray-on-aks
```

## Install Kueue

Install the Kueue controller by using Helm:

```bash
helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version 0.17.1 \
  --namespace kueue-system \
  --create-namespace \
  --wait
```

Verify the controller is running:

```bash
kubectl -n kueue-system get pods
```

## Create the queue configuration

Apply the autoscale queue configuration. The file creates its own `cas-kueue-demo` namespace along with the queue objects, so you don't need a separate namespace step:

```bash
kubectl apply -f 2-kueue-queues/manifests/40-autoscale-queue.yaml
```

The ResourceFlavor targets nodes labeled `agentpool=scalepool`, which AKS applies automatically to that node pool:

```yaml
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: scalepool
spec:
  nodeLabels:
    agentpool: scalepool
```

Verify:

```bash
kubectl get resourceflavor scalepool
```

## Configure the provisioning gate

The same file connects the provisioning gate with three more objects:

* **ProvisioningRequestConfig** `cas-provreq-config` selects the `best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class, so the autoscaler adds the requested capacity as a single atomic increase.
* **AdmissionCheck** `cas-provisioning` uses the `kueue.x-k8s.io/provisioning-request` controller and points at that config.
* **ClusterQueue** `cas-cluster-queue` gates admission on `cas-provisioning` through `admissionChecksStrategy`, so every workload it admits goes through the provisioning gate first.

Verify the objects:

```bash
kubectl get admissioncheck cas-provisioning
kubectl get clusterqueue cas-cluster-queue
kubectl -n cas-kueue-demo get localqueue cas-local-queue
```

Expected output:

```output
NAME               AGE
cas-provisioning   1m

NAME                COHORT   PENDING WORKLOADS
cas-cluster-queue            0

NAME              CLUSTERQUEUE        PENDING WORKLOADS   ADMITTED WORKLOADS
cas-local-queue   cas-cluster-queue   0                   0
```

## Submit a workload

Submit a suspended Job routed through the queue. It requests three pods that can't all fit on the single starting node, which forces a scale-up:

```bash
kubectl apply -f 3-workloads/cas-batch-job/manifests/job.yaml
```

The Job carries the `kueue.x-k8s.io/queue-name: cas-local-queue` label and `suspend: true`, so Kueue takes over admission:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kueue-cas-job
  namespace: cas-kueue-demo
  labels:
    kueue.x-k8s.io/queue-name: cas-local-queue
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      nodeSelector:
        agentpool: scalepool
      containers:
        - name: worker
          image: mcr.microsoft.com/azurelinux/busybox:1.36
          command: ["sh", "-c", "echo running on $(hostname); sleep 30"]
          resources:
            requests:
              cpu: "1800m"
              memory: "256Mi"
      restartPolicy: Never
```

## Watch the provisioning flow

Kueue creates a Workload, then a ProvisioningRequest. The cluster autoscaler satisfies the request and the pool grows:

```bash
# Kueue creates a Workload and a ProvisioningRequest
kubectl -n cas-kueue-demo get workloads
kubectl -n cas-kueue-demo get provisioningrequest

# The autoscaler marks the request Provisioned and adds nodes
kubectl get nodes -l agentpool=scalepool -w

# The Job runs to completion once nodes are Ready
kubectl -n cas-kueue-demo get job kueue-cas-job -w
```

Expected end state:

```output
NAME            STATUS     COMPLETIONS   DURATION   AGE
kueue-cas-job   Complete   3/3           34s        2m
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job stays suspended, no `ProvisioningRequest` | Wrong queue-name label | Verify `kueue.x-k8s.io/queue-name: cas-local-queue` matches the `LocalQueue` name. |
| ProvisioningRequest created but `status.conditions` empty | Autoscaler hasn't processed the request yet | Confirm the node pool has the cluster autoscaler enabled, then recheck after a minute |
| `Provisioned=False` with reason `CapacityIsNotFound` | The pool can't reach the requested size, usually because existing workloads occupy it or the request exceeds `--max-count` | Free capacity or raise `--max-count`. The autoscaler keeps retrying, and the job stays suspended rather than partially scheduling. |
| Pods Pending after admission | Node label mismatch | Confirm `scalepool` nodes carry the `agentpool=scalepool` label with `kubectl get nodes --show-labels` |
| Kueue controller not running | Helm release issue | Check with `kubectl -n kueue-system logs deploy/kueue-controller-manager` |

For the full manifests, see the [kueue-and-ray-on-aks directory](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks) in the Azure/AKS repository.

## Clean up resources

Remove the workload and queue configuration:

```bash
kubectl delete -f 3-workloads/cas-batch-job/manifests/job.yaml
kubectl delete -f 2-kueue-queues/manifests/40-autoscale-queue.yaml
```

## Next steps

To learn more about the components used in this article, see:

* [Learn about Kueue for batch scheduling](./kueue-overview.md)
* [Schedule and deploy batch jobs with Kueue](./deploy-batch-jobs-with-kueue.md)
* [Cluster autoscaler overview](./cluster-autoscaler-overview.md)
