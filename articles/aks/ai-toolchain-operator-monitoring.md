---
title: Monitor your AI inference service with the AI toolchain operator
description: Learn how to collect and visualize inference service metrics with Azure Managed Prometheus and Azure Managed Grafana
ms.topic: how-to
author: sachidesai
ms.service: azure-kubernetes-service
ms.date: 3/25/2025
---

# Monitor and visualize AI inference metrics on Azure Kubernetes Service (AKS) with the AI toolchain operator (Preview)

Monitoring and observability play a key role in maintaining high performance and low cost of your AI workload deployments on AKS. Visibility into system and performance metrics can indicate the limits of your underlying infrastructure and motivate real-time adjustments and optimizations to reduce workload interruptions. Monitoring also provides valuable insights into resource utilization, enabling cost-effective management of computational resources and avoiding over-provisioning or under-provisioning. 

The AI toolchain operator (KAITO) is a managed add-on for AKS that simplifies the deployment and operations for AI models on your AKS cluster. Starting with [KAITO version 0.4.4](https://github.com/kaito-project/kaito/releases/tag/v0.4.4), the vLLM inference runtime is enabled by default in the AKS managed add-on. vLLM surfaces key system performance, resource usage, and request processing [Prometheus metrics](https://docs.vllm.ai/en/latest/design/v1/metrics.html) that can be used to evaluate your KAITO inference deployments.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

In this article, you'll learn how to monitor and visualize vLLM inference metrics using the AI toolchain operator add-on (preview) with Azure Managed Prometheus and Azure Managed Grafana on your AKS cluster.

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Azure CLI version 2.47.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Prerequisites

* The Kubernetes command-line client, kubectl, installed and configured. For more information, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
* Enable the [AI toolchain operator add-on](./ai-toolchain-operator.md) on your AKS cluster.
   * If you already have the AI toolchain operator add-on enabled, update your AKS cluster to the latest version to run **KAITO v0.4.4 or above**.
* Enable [Azure Managed Prometheus and Azure Managed Grafana](/azure/azure-monitor/containers/kubernetes-monitoring-enable) on your AKS cluster.

## Deploy a KAITO inference service

1. In this example, you collect metrics for the [Qwen-2.5-coder-7B-instruct language model](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml). Start by applying the following KAITO workspace CRD on your cluster:

    ```azurecli-interactive
        kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml
    ```

2. Track the live resource changes in your KAITO workspace using the `kubectl get` command.

    ```azurecli-interactive
    kubectl get workspace workspace-qwen-2-5-coder-7b-instruct -w
    ```

    > [!NOTE]
    > As you track the KAITO inference service deployment, note that machine readiness can take up to 10 minutes, and workspace readiness up to 20 minutes depending on the size of your model.

3. Confirm that your inference service is running and get the service IP address using the `kubectl get svc` command.

    ```azurecli-interactive
    export SERVICE_IP=$(kubectl get svc workspace-qwen-2-5-coder-7b-instruct -o jsonpath='{.spec.clusterIP}')

    echo $SERVICE_IP
    ```

## Surface KAITO inference metrics to Azure Managed Prometheus

1. Prometheus metrics are collected by default at the KAITO [`/metrics` endpoint](https://github.com/kaito-project/kaito/blob/main/docs/inference/Monitoring.md#prometheus-metrics).

2. Add the following label to your KAITO inference service so that it can be detected by a Kubernetes `ServiceMonitor` deployment:

    ```azurecli-interactive
        kubectl label svc workspace-qwen-2-5-coder-7b-instruct App=qwen-2-5-coder 
    ```

3. Create a `ServiceMonitor` resource to define the inference service endpoints and configurations needed to scrape the vLLM Prometheus metrics. Export these metrics to Azure Managed Prometheus by deploying the following `ServiceMonitor` YAML manifest in the `kube-system` namespace :

    ```azurecli-interactive
        cat <<EOF | kubectl apply -n kube-system -f 
        apiVersion: azmonitoring.coreos.com/v1
        kind: ServiceMonitor
        metadata:
          name: prometheus-kaito-monitor
        spec:
          selector:
            matchLabels:
              App: qwen-2-5-coder
          endpoints:
          - port: http
            interval: 30s
            path: /metrics
            scheme: http
        EOF 
    ```

4. You should see the following message once the `ServiceMonitor` is created:

    ```bash
	    servicemonitor.azmonitoring.coreos.com/prometheus-kaito-monitor created
    ```

5. Confirm that your `ServiceMonitor` deployment is running successfully:

    ```azurecli-interactive
	    kubectl get servicemonitor prometheus-kaito-monitor -n kube-system
    ```

6.	Confirm that vLLM metrics are successfully collected in Azure Managed Prometheus on your Azure Portal by navigating to the "Prometheus explorer" page under “Managed Prometheus” in your Azure Monitor Workspace.
    - Navigate to the “Grid” tab and search for your metrics item associated with the job name `workspace-qwen-2-5-coder-7b-instruct`.

    > [!NOTE]
    > The `up` value of this item should be 1, indicating that Prometheus metrics are successfully being scraped from your AI inference service endpoint.


## Visualize KAITO inference metrics in Azure Managed Grafana

1. The vLLM project provides a Grafana dashboard configuration named [grafana.json](https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html#import-dashboard) for inference workload monitoring. Navigate to the bottom of this [page](https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html#import-dashboard) and copy the entire contents of the `grafana.json` file. 

:::image type="content" source="./media/ai-toolchain-operator/vllm-grafana-config.png" alt-text="Screenshot of vLLM Grafana dashboard configuration." lightbox="./media/ai-toolchain-operator/vllm-grafana-config.png":::

2. Follow [these steps](/azure/managed-grafana/how-to-create-dashboard#import-a-json-dashboard) to import the Grafana configurations into a new dashboard in Azure Managed Grafana.
3. Navigate to your Managed Grafana endpoint, view the available dashboards and select the new dashboard named `vLLM`.

:::image type="content" source="./media/ai-toolchain-operator/available-grafana-dashboards.png" alt-text="Screenshot of available dashboards in Azure Managed Grafana" lightbox="./media/ai-toolchain-operator/available-grafana-dashboards.png":::

4. To begin collecting data for your selected model deployment, confirm that the `datasource` shown at the top left of the Grafana dashboard is your Azure Managed Prometheus instance created for this example. 

5. Copy the inference preset name defined in your KAITO workspace into the `model_name` field in the Grafana dashboard. For this example, the model name is [qwen2.5-coder-7b-instruct](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml).

6. In a few moments, the metrics for your KAITO inference service will populate in the vLLM Grafana dashboard. 

:::image type="content" source="./media/ai-toolchain-operator/example-grafana-dashboard.png" alt-text="Screenshot of vLLM Grafana dashboard for example inference service deployment." lightbox="./media/ai-toolchain-operator/example-grafana-dashboard.png":::

   > [!NOTE]
   > The value of these inference metrics will remain 0 until the requests are submitted to the model inference server.


## Next steps

- [Monitor and visualize](./monitor-aks.md) your AKS deployments at scale.
- [Fine-tune an AI model](./ai-toolchain-operator-fine-tune.md) using the AI toolchain operator add-on on AKS.
- Learn about AKS GPU workload deployment options on [Linux](./gpu-cluster.md) and [Windows](./use-windows-gpu.md)


<!-- Links -->

[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md