---
title: Onboard custom models for inferencing with the AI toolchain operator (KAITO) and ACR on AKS
description: Learn how to onboard custom models for inferencing with the AI toolchain operator (KAITO) and ACR on AKS.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 02/21/2025
author: schaffererin
ms.author: schaffererin
---

# Onboard custom models for inferencing with the AI toolchain operator (KAITO) and ACR on Azure Kubernetes Service (AKS)

As an AI engineer or developer, you might have to build and deploy AI workloads that have private/custom model weights or open-source weights. AKS provides the option to deploy inferencing workloads using open-source presets supported out-of-box in the KAITO [model registry](https://github.com/kaito-project/kaito/tree/main/presets) or to containerize your private/custom model weights and deploy a workload securely onto your AKS cluster.

In this article, you learn how to onboard a custom model for inferencing with the AI toolchain operator add-on and Azure Container Registry (ACR) on Azure Kubernetes Service (AKS).

## Prerequisites

- An Azure account with an active subscription. If you don't have an account, you can [create one for free](https://azure.microsoft.com/free/).
- An AKS cluster with the AI toolchain operator add-on enabled. For more information, see [Enable KAITO on an AKS cluster](./ai-toolchain-operator.md#enable-the-ai-toolchain-operator-add-on-on-an-aks-cluster).
- An Azure container registry integrated with your AKS cluster. For more information, see [Authenticate with ACR from AKS](./cluster-container-registry-integration.md).

> [!NOTE]
> The ACR runner virtual machine disk space has a limit of 120 G. This might not be sufficient for building larger language models. You can use ACR build for small language model (14B parameters or less) container images. For larger models (more than 14B), we recommend using Docker build.

## Build your custom Docker image

In this example, we use the [Meta Llama-3.1-8B model](https://huggingface.co/meta-llama/Llama-3.1-8B) weights from HuggingFace. You can use any other private model weights that you have access to.

1. Download your private/custom model weights. You can download the Meta Llama model using the steps in [Download Llama model weights](https://github.com/meta-llama/llama-models?tab=readme-ov-file#download)

2. Clone the KAITO project GitHub repository using the `git clone` command.

    ```bash
    git clone https://github.com/kaito-project/kaito.git
    ```

3. Log in to your container registry using one of the following commands:

    ```bash
    # Azure Container Registry (ACR)
    az acr login --name <ACR_NAME>

    # Docker Hub
    docker login <REGISTRY_URL>
    ```

4. Before building the Docker image, set the relevant environment variables for the image name, version, and weights paths. Make sure you replace the placeholder values with your own.

    ```bash
    export IMAGE_NAME="image-name"
    export VERSION="image-version"
    export WEIGHTS_PATH="image-weights-path"
    ```

5. Build and push the Docker image to your private container registry using one of the following commands:

    ```bash
    # Azure Container Registry (ACR)
    az acr build --image custom-llm:0.0.1 --registry <ACR_NAME> --file Dockerfile .

    # Docker Hub
    docker build -t <IMAGE_NAME> --file Dockerfile --build-arg WEIGHTS_PATH=<WEIGHTS_PATH> --build-arg MODEL_TYPE=text-generation --build-arg VERSION=<VERSION> .

    docker push <IMAGE_NAME>
    ```

## Deploy your model inferencing workload using the KAITO workspace template

1. Create a file named `kaito-model.yaml` using the following sample YAML manifest template. Replace the default values in the following fields with your private model's requirements:

   - `instanceType`: The minimum Azure VM SKU size required for an inference workload using your private model. You should have available quota for this VM size in your Azure subscription before deploying the inferencing workload.
   - `image`: ACR path to your private model weights image.
   - `"--torch_dtype"`: Set to `"float16"` for compatibility with V100 GPUs. For A100, H100 or newer GPUs, use `"bfloat16"`.

    ```yml
    apiVersion: kaito.sh/v1alpha1
    kind: Workspace
    metadata:
      name: workspace-custom-llm
    resource:
      instanceType: "Standard_NC24ads_A100_v4"
      labelSelector:
        matchLabels:
          apps: custom-llm
    inference:
      template: 
        spec:
          containers:
          - name: custom-llm-container
            image: modelsregistry.azurecr.io/custom-llm:0.0.1
            command: ["accelerate"]
            args:
              - "launch"
              - "--num_processes"
              - "1"
              - "--num_machines"
              - "1"
              - "--gpu_ids"
              - "all"
              - "tfs/inference_api.py"
              - "--pipeline"
              - "text-generation"
              - "--torch_dtype"
              - "float16"
            volumeMounts:
            - name: dshm
              mountPath: /dev/shm
          volumes:
          - name: dshm
            emptyDir:
              medium: Memory
    ```

2. Connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az_aks_get_credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>
    ```

3. Run the deployment in your AKS cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f kaito-model.yaml
    ```

4. Monitor the deployment using the `kubectl get` command.

    ```bash
    kubectl get pods
    ```

## Test your model inferencing service

After monitoring the deployment, you can test the model inferencing workload using the following commands:

1. Get the external IP address of the workspace using the `kubectl get` command.

    ```bash
    kubectl get workspace workspace-custom-llm -w
    ```

2. Set an environment variable for the external IP address using the following command:

    ```bash
    export SERVICE_IP=$(kubectl get svc workspace-custom-llm -o jsonpath='{.spec.clusterIP}')
    ```

3. Test the model inferencing service using the following `kubectl run` and `curl` commands:

    ```bash
    kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$SERVICE_IP/chat -H "accept: application/json" -H "Content-Type: application/json" -d "{"prompt":"YOUR QUESTION HERE"}"
        ```

## Next steps

In this article, you learned how to onboard a custom model for inferencing with the AI toolchain operator add-on and Azure Container Registry (ACR) on Azure Kubernetes Service (AKS). To learn more about AI and machine learning on AKS, see the following articles:

- [Build and deploy data and machine learning pipelines with Flyte on Azure Kubernetes Service (AKS)](./use-flyte.md)
- [Deploy a Ray cluster on Azure Kubernetes Service (AKS)](./ray-overview.md)
- [Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)](./best-practices-ml-ops.md)
