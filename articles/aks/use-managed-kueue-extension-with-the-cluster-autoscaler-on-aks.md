---
title: Use managed Kueue extension with the cluster autoscaler on Azure Kubernetes Service (AKS)
description: Learn how to use the managed Kueue extension with the AKS cluster autoscaler to autoscale your AI workloads.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 10/28/2026
author: AaronLiChen
ms.author: lichen5
ms.reviewer: josebl
ms.custom: 'stateful-workloads'
ai-usage: ai-assisted
---

# Use managed Kueue extension with the cluster autoscaler on Azure Kubernetes Service (AKS)

In this article, you pair the [managed Kueue extension](./install-the-managed-kueue-extension-on-aks.md) with the Azure Kubernetes Service (AKS) [cluster autoscaler](./cluster-autoscaler-overview.md) to request or provision capacity before batch jobs are admitted. Create jobs with `suspend: true` and a queue label. Kueue creates a Kubernetes [ProvisioningRequest](https://github.com/kubernetes-sigs/cluster-autoscaler/tree/main/pkg/provisioningrequest) on their behalf. The cluster autoscaler can scale up the node pool's virtual machine scale set (VMSS) to satisfy the request.

A `Provisioned=True` condition doesn't guarantee that the Kubernetes nodes are `Ready`. Placement and topology checks can still delay Kueue admission, and pods can remain pending while instances join the cluster.

| Component | Role |
| --- | --- |
| **Kueue** | Queues the job and gates admission against quota |
| **ProvisioningRequest AdmissionCheck** | Asks the cluster autoscaler for capacity before admission |
| **Cluster autoscaler** | Requests or provisions VMSS capacity; doesn't guarantee `Ready` Kubernetes nodes |

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* Basic knowledge of Kueue. For more information, see [Managed Kueue extension overview](./managed-kueue-extension-overview.md).
* An AKS cluster with the [managed Kueue extension installed and verified](./install-the-managed-kueue-extension-on-aks.md#verify-the-extension-installation).
* A CPU user node pool with the [cluster autoscaler enabled](./cluster-autoscaler-overview.md). The examples use a pool named `scalepool` with `--min-count 1 --max-count 5`.
* The Azure CLI version 2.70 or later. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* `kubectl` connected to the cluster (`az aks get-credentials`).

You can find the example manifests used in this article in the [kueue-and-ray-on-aks](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks) directory of the Azure/AKS repository. Clone the repository so you can run them:

```bash
git clone https://github.com/Azure/AKS.git
cd AKS/examples/kueue-and-ray-on-aks
```

## Verify managed Kueue and the provisioning API

The cluster autoscaler provides the shared ProvisioningRequest API when it's enabled for a node pool. Use the managed Kueue installation rather than installing another controller. Check controller readiness and the API:

```bash
kubectl rollout status deployment/kueue-controller-manager --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kueue-extension --namespace kueue-system --timeout=5m
kubectl wait --for=condition=Established \
  crd/provisioningrequests.autoscaling.x-k8s.io --timeout=2m
kubectl get crd provisioningrequests.autoscaling.x-k8s.io --output yaml
```

Confirm that the CRD serves `v1`. If the API is missing, check that the node pool has the cluster autoscaler enabled and use the managed extension support path if the checks still fail. Don't install a second controller or replace a shared CRD as a workaround.

Verify the resources provided by managed Kueue before creating your queue:

```bash
kubectl wait --for=create resourceflavor/aks-cpu --timeout=5m
kubectl wait --for=condition=Active admissioncheck/aks-provisioning-check --timeout=2m
kubectl get resourceflavor aks-cpu
kubectl get provisioningrequestconfig aks-provisioning-config
```

Don't recreate, edit, or delete these managed defaults.

## Create the queue configuration

Apply the autoscale queue configuration. The file creates only customer-owned resources: a `cas-kueue-demo` namespace, a ClusterQueue, and a LocalQueue:

```bash
kubectl apply -f 2-kueue-queues/manifests/40-autoscale-queue.yaml
```

The ClusterQueue references the managed `aks-cpu` ResourceFlavor. That flavor can represent multiple eligible CPU user pools. The example Job's `agentpool: scalepool` node selector restricts its pods and provisioning request to the autoscaling pool.

## Use the managed provisioning gate

The managed extension provides the provisioning gate:

* **ProvisioningRequestConfig** `aks-provisioning-config` selects the `best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class, so the autoscaler adds the requested capacity as a single atomic increase.
* **AdmissionCheck** `aks-provisioning-check` uses the `kueue.x-k8s.io/provisioning-request` controller and references that managed config.
* Your **ClusterQueue** `cas-cluster-queue` gates admission on `aks-provisioning-check` through `admissionChecksStrategy`, so every workload it admits goes through the provisioning gate first.

The queue manifest includes this gate reference:

```yaml
admissionChecksStrategy:
  admissionChecks:
  - name: aks-provisioning-check
    onFlavors: [aks-cpu]
```

Verify your queues:

```bash
kubectl wait --for=condition=Active clusterqueue/cas-cluster-queue --timeout=2m
kubectl wait --for=condition=Active localqueue/cas-local-queue \
  --namespace cas-kueue-demo --timeout=2m
kubectl get clusterqueue cas-cluster-queue
kubectl -n cas-kueue-demo get localqueue cas-local-queue
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

Kueue creates a Workload, then a ProvisioningRequest. The cluster autoscaler can report `Provisioned=True` before all new nodes are `Ready`. Placement checks for the managed `aks-default` hostname topology can delay admission while eligible nodes become `Ready`. Monitor request status, node readiness, and Job progress separately:

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
| --- | --- | --- |
| Job stays suspended, no `ProvisioningRequest` | Wrong queue-name label | Verify `kueue.x-k8s.io/queue-name: cas-local-queue` matches the `LocalQueue` name. |
| ProvisioningRequest created but `status.conditions` empty | Autoscaler hasn't processed the request yet | Confirm the node pool has the cluster autoscaler enabled, then recheck after a minute. |
| `Provisioned=False` with reason `CapacityIsNotFound` | The pool can't reach the requested size, usually because existing workloads occupy it or the request exceeds `--max-count` | Free capacity or raise `--max-count`. The autoscaler keeps retrying, and the job stays suspended rather than partially scheduling. |
| Pods Pending after admission | Nodes aren't `Ready`, or a node label doesn't match | Check node conditions and pod events, then confirm `scalepool` nodes carry the `agentpool=scalepool` label with `kubectl get nodes --show-labels`. |
| Kueue controller not running | Managed extension or controller readiness issue | Check extension status and `kubectl -n kueue-system logs deploy/kueue-controller-manager`; follow the [managed verification steps](./install-the-managed-kueue-extension-on-aks.md#verify-the-extension-installation). |

For the full manifests, see the [kueue-and-ray-on-aks directory](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks) in the Azure/AKS repository.

## Clean up resources

Delete the example workload and customer-owned queue configuration. Keep the managed `aks-cpu` ResourceFlavor, provisioning config, admission check, and extension:

```bash
kubectl delete -f 3-workloads/cas-batch-job/manifests/job.yaml
kubectl delete -f 2-kueue-queues/manifests/40-autoscale-queue.yaml
```

## Next steps

To learn more about the components used in this article, see:

* [Managed Kueue extension overview](./managed-kueue-extension-overview.md).
* [Schedule and deploy batch jobs with the managed Kueue extension](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md).
* [Cluster autoscaler overview](./cluster-autoscaler-overview.md).
