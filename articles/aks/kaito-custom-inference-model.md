---
title: Onboard custom models for inferencing with the AI toolchain operator (KAITO) on Azure Kubernetes Service (AKS)
description: Learn how to onboard custom models for inferencing with the AI toolchain operator (KAITO) on AKS.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 03/25/2025
author: schaffererin
ms.author: schaffererin
---

# Onboard custom models for inferencing with the AI toolchain operator (KAITO) on Azure Kubernetes Service (AKS)

As an AI engineer or developer, you might have to prototype and deploy AI workloads with a range of different model weights. AKS provides the option to deploy inferencing workloads using open-source presets supported out-of-box and managed in the KAITO [model registry](https://github.com/kaito-project/kaito/tree/main/presets) or to dynamically download from the [HuggingFace registry](https://huggingface.co/models) at runtime onto your AKS cluster.

In this article, you learn how to onboard a sample HuggingFace model for inferencing with the AI toolchain operator add-on without having to manage custom images on Azure Kubernetes Service (AKS).

## Prerequisites

- An Azure account with an active subscription. If you don't have an account, you can [create one for free](https://azure.microsoft.com/free/).
- An AKS cluster with the AI toolchain operator add-on enabled. For more information, see [Enable KAITO on an AKS cluster](./ai-toolchain-operator.md#enable-the-ai-toolchain-operator-add-on-on-an-aks-cluster).
- This example deployment requires quota for the `Standard_NCads_A100_v4` virtual machine (VM) family in your Azure subscription. If you don't have quota for this VM family, please [request a quota increase](/azure/quotas/quickstart-increase-quota-portal).

## Choose an open-source language model from HuggingFace

In this example, we use the [BigScience Bloom-1B7](https://huggingface.co/bigscience/bloom-1b7) small language model. You can choose from the thousands of text-generation models supported on [HuggingFace](https://huggingface.co/models?pipeline_tag=text-generation).

1. Connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az_aks_get_credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>
    ```

2. Clone the KAITO project GitHub repository using the `git clone` command.

    ```bash
    git clone https://github.com/kaito-project/kaito.git
    ```

3. Confirm that your `kaito-gpu-provisioner` pod is running successfully using the `kubectl get` command.

    ```bash
    kubectl get deployment -n kube-system | grep kaito
    ```

## Deploy your model inferencing workload using the KAITO workspace template

1. Navigate to the `kaito` directory and open the `docs/custom-model-integration/reference_image_deployment.yaml` KAITO template. Replace the default values in the following fields with your model's requirements:

   - `instanceType`: The minimum VM size for this inference service deployment is `Standard_NC24ads_A100_v4`. For larger model sizes you can choose a VM in the [`Standard_NCads_A100_v4`](/azure/virtual-machines/sizes/gpu-accelerated/nca100v4-series) family with higher memory capacity.
   - `MODEL_ID`: Replace with your model's specific HuggingFace identifier, which can be found after `https://huggingface.co/` in the model card URL.
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
            image: ghcr.io/kaito-project/kaito/llm-reference-preset:latest
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
              - "--trust_remote_code"
              - "--allow_remote_files"
              - "--pretrained_model_name_or_path"
              - "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
              - "--torch_dtype"
              - "bfloat16"
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
    kubectl apply -f custom-model-deployment.yaml
    ```

## Test your custom model inferencing service

Monitor and test your model inferencing workload deployment using the following commands:

1. Track the live resource changes in your KAITO workspace using the `kubectl get workspace` command.

    ```bash
    kubectl get workspace workspace-custom-llm -w
    ```

    > [!NOTE]  
    > Note that machine readiness can take *up to 10 minutes*, and workspace readiness *up to 20 minutes*.

2. Check your language model inference service and get the service IP address using the `kubectl get svc` command.

    ```bash
    export SERVICE_IP=$(kubectl get svc workspace-custom-llm -o jsonpath='{.spec.clusterIP}')
    ```

3. Test your custom model inference service with a sample input of your choice using the following `curl` command:

    ```bash
    kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$SERVICE_IP/chat -H "accept: application/json" -H "Content-Type: application/json" -d "{"prompt":"YOUR QUESTION HERE"}"
    ```

## Clean up resources

If you no longer need these resources, you can delete them to avoid incurring extra Azure compute charges.

1. Delete the KAITO inference workspace using the `kubectl delete workspace` command.

    ```bash
    kubectl delete workspace workspace-custom-llm
    ```

2. Delete the GPU node pool created by KAITO in the same namespace as `kaito-gpu-provisioner`.

## Next steps

In this article, you learned how to onboard a HuggingFace model for inferencing with the AI toolchain operator add-on directly to your AKS cluster. To learn more about AI and machine learning on AKS, see the following articles:

- [Fine tune a language model with KAITO on Azure Kubernetes Service (AKS)](./ai-toolchain-operator-fine-tune.md)
- [Deploy a Ray cluster on Azure Kubernetes Service (AKS)](./ray-overview.md)
- [Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)](./best-practices-ml-ops.md)
