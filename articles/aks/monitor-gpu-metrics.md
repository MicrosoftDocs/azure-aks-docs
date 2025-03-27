---
title: Monitor GPU metrics in Azure Kubernetes Service (AKS)
description: Learn how to monitor GPU metrics from NVIDIA DCGM exporter with Azure Managed Prometheus and Managed Grafana on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 03/27/2025
author: schaffererin
ms.author: schaffererin
---

# Monitor GPU metrics from NVIDIA DCGM exporter with Azure Managed Prometheus and Managed Grafana on Azure Kubernetes Service (AKS)

In this article, you learn how to monitor GPU metrics collected by the NVIDIA Data Center GPU Manager (DCGM) exporter in Azure Kubernetes Service (AKS) using Azure Managed Prometheus and Azure Managed Grafana.

## Prerequisites

- An AKS cluster with [NVIDIA GPU-enabled node pool(s)](./gpu-cluster.md) and ensure that the [GPUs are schedulable](./gpu-cluster.md#confirm-that-gpus-are-schedulable).
- A [sample GPU workload](./gpu-cluster.md#run-a-gpu-enabled-workload) deployed to your node pool.
- [Azure Managed Prometheus and Grafana enabled on your AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable).
- [An Azure Container Registry (ACR) integrated with your AKS cluster](./cluster-container-registry-integration.md).
- [Helm version 3 or above installed on your cluster](https://helm.sh/docs/intro/install/).

## Install NVIDIA DCGM Exporter

NVIDIA DCGM Exporter collects and exports GPU metrics. It runs as a pod on your AKS cluster and gathers metrics such as utilization, memory usage, temperature, and power consumption. For more information, see the [NVIDIA DCGM Exporter documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html).

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

### Update default configurations of the NVIDIA DCGM Exporter

1. Clone the [NVIDIA/dcgm-exporter GitHub repository](https://github.com/NVIDIA/dcgm-exporter).

    ```bash
    git clone https://github.com/NVIDIA/dcgm-exporter.git
    ```

2. Navigate to the new `dcgm-exporter` directory.

    ```bash
    cd dcgm-exporter
    ```

3. Open the `service-monitor.yaml` and update the `apiVersion` key to `azmonitoring.coreos.com/v1`. This change allows the NVIDIA DCGM exporter to surface metrics in Azure Managed Prometheus.

    ```yml
    apiVersion: azmonitoring.coreos.com/v1
    ...
    ...
    ```

4. Navigate to the `deployment` directory and open the `values.yaml` file. Update the following fields in this YAML manifest:

    ```yml
    ...
    ...
    serviceMonitor:
        apiVersion: "azmonitoring.coreos.com/v1"
    ...
    ...
    nodeSelector:
        accelerator: "nvidia"

    tolerations:
   - key: "sku"
        operator: "Equal"
        value: "gpu"
        effect: "NoSchedule"
    ...
    ...
    ```

## Push the NVIDIA DCGM exporter Helm chart to your Azure Container Registry

1. Navigate to the `deployment` folder of the cloned repository, and then package the Helm chart using the `helm package` command.

    ```bash
    helm package .
    ```

2. Authenticate Helm with your ACR using the `helm registry login` command. Replace `<acr_url>`, `<user_name>`, and `<password>` with your ACR details. For more detailed instructions, see [Authenticate Helm with Azure Container Registry](/azure/container-registry/container-registry-helm-repos#authenticate-with-the-registry).

    ```bash
    helm registry login <acr_url> --username <user_name> --password <password>
    ```

3. Push the Helm chart to your ACR using the `helm push` command. Replace `<dcgm_exporter_version>` with the version noted in the output of `helm package` command and `<acr_url>` with your ACR URL.

    ```bash
    helm push dcgm-exporter-<dcgm_exporter_version>.tgz oci://<acr_url>/helm
    ```

4. Install the Helm chart on your AKS cluster using the `helm install` command, in the **same namespace as your GPU-enabled node pool**. Replace `<acr_url>` with your ACR URL.

    ```bash
    helm install dcgm-nvidia oci://<acr_url>/helm/dcgm-exporter -n <gpu_namespace>
    ```

5. Check the installation on your AKS cluster using the `helm list` command.

    ```bash
    helm list -n <gpu_namespace>
    ```

6. Verify the NVIDIA DCGM Exporter is running on your GPU node pool using the `kubectl get pods` and `kubectl get ds` commands.

    ```bash
    kubectl get pods -n <gpu_namespace>
    kubectl get ds -n <gpu_namespace>
    ```

## Export GPU Prometheus metrics and configure the NVIDIA Grafana dashboard

Once NVIDIA DCGM Exporter is successfully deployed to your GPU node pool, you need to export the default enabled GPU metrics to Azure Managed Prometheus by deploying a Kubernetes `PodMonitor` resource.

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

4. In the [Azure Portal](https://portal.azure.com), navigate to the **Managed Prometheus** > **Prometheus explorer** section of your Azure Monitor workspace. Select the **Grid** tab and search for an example DCGM GPU metric in the **PromQL** box. For example `DCGM_FI_DEV_SM_CLOCK`:

    :::image type="content" source="./media/monitor-gpu-metrics/dcgm-azure-monitor.png" alt-text="Screenshot of the Metrics section of an Azure Monitor workspace in the Azure portal.":::

5. Import the [dcgm-exporter-dashboard.json](https://github.com/NVIDIA/dcgm-exporter/blob/main/grafana/dcgm-exporter-dashboard.json) into your Managed Grafana instance using the steps in [Create a dashboard in Azure Managed Grafana](/azure/managed-grafana/how-to-create-dashboard). After importing the JSON, the dashboard displaying GPU metrics should be visible in your Grafana instance.

    :::image type="content" source="./media/monitor-gpu-metrics/dcgm-dashboard.png" alt-text="Screenshot of the NVIDIA DCGM Exporter dashboard.":::

## Next steps

- Deploy a [multi-instance GPU (MIG)](./gpu-multi-instance.md) workload on AKS.
- Explore the [AI toolchain operator add-on (preview)](./ai-toolchain-operator.md) for AI inferencing and fine-tuning.
- Learn more about [Ray clusters on AKS](./ray-overview.md).
