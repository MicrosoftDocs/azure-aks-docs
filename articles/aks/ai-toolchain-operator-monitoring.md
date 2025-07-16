---
title: Monitor Inference Metrics via the AI Toolchain Operator 
description: Learn how to collect and visualize AI inference service metrics in Azure Kubernetes Service (AKS) by using the managed service for Prometheus and Azure Managed Grafana.
ms.author: schaffererin
ms.topic: how-to
author: sachidesai
ms.service: azure-kubernetes-service
ms.date: 3/25/2025
---

# Monitor and visualize AI inference metrics on Azure Kubernetes Service (AKS) with the AI toolchain operator add-on

Monitoring and observability play a key role in maintaining high performance and low cost of your AI workload deployments in Azure Kubernetes Service (AKS). Visibility into system and performance metrics can indicate the limits of your underlying infrastructure and motivate real-time adjustments and optimizations to reduce workload interruptions. Monitoring also provides valuable insights into resource utilization for cost-effective management of computational resources and accurate provisioning.

The Kubernetes AI Toolchain Operator (KAITO) is a managed add-on for AKS that simplifies deployment and operations for AI models in your AKS cluster.

In [KAITO version 0.4.4](https://github.com/kaito-project/kaito/releases/tag/v0.4.4) and later versions, the vLLM inference runtime is enabled by default in the AKS managed add-on. [vLLM](https://docs.vllm.ai/en/latest/) is a library for language model inference and serving. It surfaces key system performance, resource usage, and request processing for [Prometheus metrics](https://docs.vllm.ai/en/latest/design/v1/metrics.html) that you can use to evaluate your KAITO inference deployments.

In this article, you'll learn how to monitor and visualize vLLM inference metrics using the AI toolchain operator add-on with Azure Managed Prometheus and Azure Managed Grafana on your AKS cluster.


## Before you begin

* This article assumes that you have an existing AKS cluster. If you don't have a cluster, create one by using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Install and configure Azure CLI version 2.47.0 or later. To find your version, run `az --version`. To install or update, see [Install the Azure CLI](/cli/azure/install-azure-cli).

## Prerequisites

* Install and configure kubectl, the Kubernetes command-line client. For more information, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
* Enable the [AI toolchain operator add-on](./ai-toolchain-operator.md) in your AKS cluster.
* If you already have the AI toolchain operator add-on enabled, update your AKS cluster to the latest version to run KAITO v0.4.4 or later.
* Enable [the managed service for Prometheus and Azure Managed Grafana](/azure/azure-monitor/containers/kubernetes-monitoring-enable) in your AKS cluster.
* Have permissions to [create or update Azure Managed Grafana instances](/azure/managed-grafana/how-to-manage-access-permissions-users-identities) in your Azure subscription.

## Deploy a KAITO inference service

In this example, you collect metrics for the [Qwen-2.5-coder-7B-instruct language model](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml).

1. Start by applying the following KAITO workspace custom resource to your cluster:

    ```azurecli
    kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml
    ```

1. Track the live resource changes in your KAITO workspace:

    ```azurecli
    kubectl get workspace workspace-qwen-2-5-coder-7b-instruct -w
    ```

    > [!NOTE]
    > Machine readiness can take up to 10 minutes, and workspace readiness can take up to 20 minutes depending on the size of your language model.

1. Confirm that your inference service is running and get the service IP address:

    ```azurecli
    export SERVICE_IP=$(kubectl get svc workspace-qwen-2-5-coder-7b-instruct -o jsonpath='{.spec.clusterIP}')

    echo $SERVICE_IP
    ```

## Surface KAITO inference metrics to the managed service for Prometheus

Prometheus metrics are collected by default at the KAITO [`/metrics` endpoint](https://github.com/kaito-project/kaito/blob/main/docs/inference/Monitoring.md#prometheus-metrics).

1. Add the following label to your KAITO inference service so that a Kubernetes `ServiceMonitor` deployment can detect it:

    ```azurecli
    kubectl label svc workspace-qwen-2-5-coder-7b-instruct App=qwen-2-5-coder 
    ```

1. Create a `ServiceMonitor` resource to define the inference service endpoints and the required configurations to scrape the vLLM Prometheus metrics. Export these metrics to the managed service for Prometheus by deploying the following `ServiceMonitor` YAML manifest in the `kube-system` namespace:

    ```azurecli
    cat <<EOF | kubectl apply -n kube-system -f -
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

    Check for the following output to verify that `ServiceMonitor` is created:

    ```output
    servicemonitor.azmonitoring.coreos.com/prometheus-kaito-monitor created
    ```

1. Verify that your `ServiceMonitor` deployment is running successfully:

    ```azurecli
    kubectl get servicemonitor prometheus-kaito-monitor -n kube-system
    ```

1. In the Azure portal, verify that vLLM metrics are successfully collected in the managed service for Prometheus.

   1. In your Azure Monitor workspace, go to **Managed Prometheus** > **Prometheus explorer**.

   1. Select the **Grid** tab and confirm that a metrics item is associated with the job named `workspace-qwen-2-5-coder-7b-instruct`.

      > [!NOTE]
      > The `up` value of this item should be    `1`. A value of `1` indicates that Prometheus metrics are successfully being scraped from your AI inference service endpoint.

## Visualize KAITO inference metrics in Azure Managed Grafana

1. The vLLM project provides a Grafana dashboard configuration named [grafana.json](https://docs.vllm.ai/en/stable/examples/online_serving/prometheus_grafana.html#example-materials) for inference workload monitoring. Navigate to the bottom of this [page](https://docs.vllm.ai/en/stable/examples/online_serving/prometheus_grafana.html#example-materials) and copy the entire contents of the `grafana.json` file. 

1. Go to the bottom of the [examples page](https://docs.vllm.ai/en/stable/examples/online_serving/prometheus_grafana.html#example-materials) and copy the entire contents of the `grafana.json` file:

    :::image type="content" source="./media/ai-toolchain-operator/vllm-grafana-config.png" alt-text="Screenshot of vLLM Grafana dashboard configuration." lightbox="./media/ai-toolchain-operator/vllm-grafana-config.png":::

1. Complete the steps to [import the Grafana configurations into a new dashboard](/azure/managed-grafana/how-to-create-dashboard#import-a-json-dashboard) in Azure Managed Grafana.

1. Go to your Managed Grafana endpoint, view the available dashboards, and select the **vLLM** dashboard.

    :::image type="content" source="./media/ai-toolchain-operator/available-grafana-dashboards.png" alt-text="Screenshot of available dashboards in Azure Managed Grafana." lightbox="./media/ai-toolchain-operator/available-grafana-dashboards.png":::

1. To begin collecting data for your selected model deployment, confirm that the **datasource** value shown at the top left of the Grafana dashboard is your instance of the managed service for Prometheus you created for this example.

1. Copy the inference preset name defined in your KAITO workspace to the **model_name** field in the Grafana dashboard. In this example, the model name is [qwen2.5-coder-7b-instruct](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_qwen_2.5_coder_7b-instruct.yaml).

1. In a few moments, verify that the metrics for your KAITO inference service appear in the vLLM Grafana dashboard.

    :::image type="content" source="./media/ai-toolchain-operator/example-grafana-dashboard.png" alt-text="Screenshot of a vLLM Grafana dashboard and an example inference service deployment." lightbox="./media/ai-toolchain-operator/example-grafana-dashboard.png":::

    > [!NOTE]
    > The value of these inference metrics remains **0** until the requests are submitted to the model inference server.

## Related content

* [Monitor and visualize](./monitor-aks.md) your AKS deployments at scale.
* [Fine-tune an AI model](./ai-toolchain-operator-fine-tune.md) by using the AI toolchain operator add-on in AKS.
* Learn about AKS GPU workload deployment options on [Linux](./gpu-cluster.md) and [Windows](./use-windows-gpu.md).

<!-- Links -->

[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
