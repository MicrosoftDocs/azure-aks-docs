---
title: Monitor Kueue Deployments and Queues on Azure Kubernetes Service (AKS)
description: Monitor key resource and performance metrics for batch workloads scheduled with Kueue on an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.date: 09/17/2025
author: sachidesai
ms.author: sachidesai
ms.service: azure-kubernetes-service
# Customer intent: "As a platform engineer or cluster admin, I want to monitor Kueue deployments and queues to gain visibility into job scheduling, resource utilization, and queue health. By integrating Kueue with Prometheus, I can track key metrics such as pending workloads, admitted jobs, quota usage, and scheduling delays.
---

# Monitor Kueue deployments and queues with Prometheus metrics on Azure Kubernetes Service (AKS)

In this article, you learn how to install and configure Kueue to schedule batch workloads on an Azure Kubernetes Service (AKS) cluster. You'll explore different installation methods to enable advanced Kueue features, verify your deployment, and monitor with Prometheus metrics exposed by Kueue.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

To learn more about installation and common use cases, see [Kueue overview on AKS](./kueue-overview.md) and try out sample deployments with [Deploy batch jobs with Kueue on AKS](./deploy-batch-jobs-with-kueue.md) guidance.

## Kueue observability with Prometheus

Kueue [exposes Prometheus metrics](https://kueue.sigs.k8s.io/docs/reference/metrics/) for the controller manager service at `http://<kueue-controller-manager-service>:9090/metrics`.

The most commonly used Kueue Prometheus metrics provide insight into queue length, resource availability, and admission status, such as:

* **`kueue_workload_admitted_total`**: Total number of workloads admitted (scheduled to run) by Kueue since the controller started. This metric helps track how many jobs Kueue allows to move from `Pending` to `Running`.
* **`kueue_workload_pending_total`**: Current number of workloads waiting in queues (i.e., pending due to lack of resources or quota). This is a useful indicator for alerting on backlogs or diagnosing scheduling delays.
* **`kueue_clusterqueue_available_resources`**: Amount of available resources (such as CPU, GPU, memory) in each `ClusterQueue`, after accounting for admitted workloads, to indicate how much headroom remains for new jobs.
* **`kueue_clusterqueue_used_resources`**: Amount of resources currently in use by admitted workloads in a given `ClusterQueue`. This metric helps correlate actual usage versus quota.

For a comprehensive list of Prometheus metrics, see the [official Kueue monitoring documentation](https://kueue.sigs.k8s.io/docs/reference/metrics/).

## Prerequisites

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI installed on your local machine. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
* [Helm version 3 or above](https://helm.sh/docs/intro/install/) installed.
* [The latest version of Kueue installed in a dedicated namespace on your cluster](./kueue-overview.md#prerequisites).
* [Sample batch workloads scheduled and deployed with Kueue](./deploy-batch-jobs-with-kueue.md).

## Confirm that Kueue metrics are available

Kueue exposes metrics via its controller pod. Run the following command to confirm that the pod is running:

```bash
kubectl get pods -n kueue-system -l app=kueue
```

## Port-forward and curl the metrics endpoint

1. Expose the metrics endpoint locally using the `kubectl port-forward` command and specifying the `<kueue-controller-pod-name>` from the previous step.

    ```bash
    kubectl port-forward -n kueue-system pod/<kueue-controller-pod-name> 8080:8080
    ```

2. With port-forwarding running, check the Kueue `/metrics` endpoint using `curl`.

    ```bash
    curl http://localhost:8080/metrics
    ```

    If metrics are exposed correctly, your output should resemble the following example output:

    ```output
    # HELP kueue_admitted_workloads_total Number of workloads admitted
    # TYPE kueue_admitted_workloads_total gauge
    kueue_admitted_workloads_total{cluster_queue="sample-jobs"} 3

    # HELP kueue_pending_workloads_total Number of pending workloads
    # TYPE kueue_pending_workloads_total gauge
    kueue_pending_workloads_total{cluster_queue="sample-jobs"} 2
    ```

## Common Prometheus queries for Kueue

If you set up self-hosted Prometheus or [Azure Managed Prometheus](/azure/azure-monitor/containers/prometheus-exporters) to scrape Kueue metrics on AKS, you can use the following PromQL queries to get workload information:

* **Pending workloads**: `sum(kueue_workload_pending_total)`
* **Admitted workloads**: `sum(kueue_workload_admitted_total)`
* **Resource usage**: `kueue_clusterqueue_used_resources{clusterqueue="sample-jobs"}`

## Next steps

* Learn about [multi-cluster scheduling and resource placement with Kueue and KubeFleet on AKS](https://blog.aks.azure.com/2025/04/02/Scaling-Kubernetes-for-AI-and-Data-intensive-Workloads).
* Visit [Kueue on AKS frequently asked questions](./deploy-batch-jobs-with-kueue.md#faq).
* Catch up on the latest [Kueue community talks and presentations](https://kueue.sigs.k8s.io/docs/talks_and_presentations/).

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
