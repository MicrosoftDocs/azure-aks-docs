---
title: Monitor GPU metrics in Azure Kubernetes Service (AKS) (preview)
description: Learn how to monitor GPU metrics from NVIDIA DCGM exporter with Azure Managed Prometheus and Managed Grafana on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 10/30/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to monitor GPU metrics using NVIDIA DCGM Exporter with Managed Prometheus and Grafana, so that I can optimize resource utilization and ensure the performance of GPU-enabled workloads in my AKS cluster."
---

# Monitor NVIDIA GPU metrics with Azure Managed Prometheus and Managed Grafana on Azure Kubernetes Service (AKS) (preview)

Efficient placement and optimization of GPU workloads often requires visibility into resource utilization and performance. Managed GPU metrics on AKS (preview) provide automated collection and exposure of GPU utilization, memory, and performance data across NVIDIA GPU-enabled node pools.This enables platform administrators to optimize cluster resources and developers to tune and debug workloads with limited manual instrumentation.

In this article, you learn how to monitor GPU metrics collected by the NVIDIA Data Center GPU Manager [(DCGM) exporter](https://github.com/NVIDIA/dcgm-exporter/tree/main) in Azure Kubernetes Service (AKS) using Azure Managed Prometheus and Azure Managed Grafana.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An AKS cluster with [a fully managed GPU-enabled node pool (preview)](./aks-managed-gpu-nodes.md) and ensure that the [GPUs are schedulable](./use-nvidia-gpu.md#confirm-that-gpus-are-schedulable).
- A [sample GPU workload](./use-nvidia-gpu.md#run-a-gpu-enabled-workload) deployed to your node pool.
- [Azure Managed Prometheus and Grafana enabled on your AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable).

## Verify that NVIDIA DCGM exporter is running

Verify the NVIDIA DCGM Exporter is running on your GPU node pool using the `kubectl get pods` command.

```bash
kubectl get pods -n default
```

Your output should include a running pod similar to the following:

  ```output
  NAME                         READY   STATUS    RESTARTS   AGE
  ...
  ...
  nvidia-dcgm-exporter-0001    1/1     Running   0          2m
  ...
  ...
  ```

## Export GPU Prometheus metrics and configure the NVIDIA Grafana dashboard

Export the default enabled GPU metrics to Azure Managed Prometheus by deploying a Kubernetes `PodMonitor` resource.

1. Create a file named `pod-monitor.yaml` and add the following configuration to it:

    ```yml
    apiVersion: azmonitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: nvidia-dcgm-exporter
      labels:
        app.kubernetes.io/name: nvidia-dcgm-exporter
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/name: nvidia-dcgm-exporter
      podMetricsEndpoints:
      - port: metrics
        interval: 30s
      podTargetLabels:
    ```

2. Apply this PodMonitor configuration to your AKS cluster using the `kubectl apply` command **in the `kube-system` namespace**.

    ```bash
    kubectl apply -f pod-monitor.yaml -n kube-system
    ```

3. Verify the PodMonitor was successfully created using the `kubectl get podmonitor` command.

    ```bash
    kubectl get podmonitor -n kube-system
    ```

4. In the [Azure portal](https://portal.azure.com), navigate to the **Managed Prometheus** > **Prometheus explorer** section of your Azure Monitor workspace. Select the **Grid** tab and search for an example DCGM GPU metric in the **PromQL** box. For example `DCGM_FI_DEV_SM_CLOCK`:

    :::image type="content" source="./media/monitor-gpu-metrics/dcgm-azure-monitor.png" alt-text="Screenshot of the Metrics section of an Azure Monitor workspace in the Azure portal.":::

5. Import the [dcgm-exporter-dashboard.json](https://github.com/NVIDIA/dcgm-exporter/blob/main/grafana/dcgm-exporter-dashboard.json) into your Managed Grafana instance using the steps in [Create a dashboard in Azure Managed Grafana](/azure/managed-grafana/how-to-create-dashboard). After importing the JSON, the dashboard displaying GPU metrics should be visible in your Grafana instance.

    :::image type="content" source="./media/monitor-gpu-metrics/dcgm-dashboard.png" alt-text="Screenshot of the NVIDIA DCGM Exporter dashboard.":::

## Next steps

- Track your [GPU node health](./gpu-health-monitoring.md) with Node Problem Detector (NPD)
- [Autoscale your GPU workloads](./autoscale-gpu-workloads-with-keda.md) with GPU metrics and Kubernetes Event-Driven Autoscaling (KEDA).
- Explore the [AI toolchain operator add-on](./ai-toolchain-operator.md) for AI inferencing and fine-tuning.
