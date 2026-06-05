---
title: Onboard custom models for inferencing with the AI toolchain operator (KAITO) on Azure Kubernetes Service (AKS)
description: Learn how to onboard custom models for inferencing with the AI toolchain operator (KAITO) on AKS.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 03/27/2026
author: schaffererin
ms.author: schaffererin

# Customer intent: As an AI engineer, I want to onboard custom models for inferencing on Azure Kubernetes Service using the AI toolchain operator, so that I can efficiently deploy and manage AI workloads without having to maintain custom images.
---

# Onboard custom models for inferencing with the AI toolchain operator (KAITO) on Azure Kubernetes Service (AKS)

As an AI engineer or developer, you might have to prototype and deploy AI workloads with a range of different model weights. AKS provides the option to deploy inferencing workloads using open-source presets supported out-of-box and managed in the KAITO [model registry](https://github.com/kaito-project/kaito/tree/main/presets) or to dynamically download from the [HuggingFace registry](https://huggingface.co/models) at runtime onto your AKS cluster.

In this article, you learn how to onboard a sample HuggingFace model for inferencing with the AI toolchain operator add-on without having to manage custom images on Azure Kubernetes Service (AKS).

## Prerequisites

- An Azure account with an active subscription. If you don't have an account, you can [create one for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- An AKS cluster with the AI toolchain operator add-on enabled. For more information, see [Enable KAITO on an AKS cluster](./ai-toolchain-operator.md#enable-the-ai-toolchain-operator-add-on-on-an-aks-cluster).
- This example deployment requires quota for the `Standard_NCads_A100_v4` virtual machine (VM) family in your Azure subscription. If you don't have quota for this VM family, please [request a quota increase](/azure/quotas/quickstart-increase-quota-portal).

    > [!NOTE]
    > Currently, only the HuggingFace runtime supports inference with the KAITO custom model deployment template.

## Choose an open-source language model from HuggingFace

In this example, we use the [HuggingFaceTB SmolLM2-1.7B-Instruct](https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct) small language model. Alternatively, you can choose from thousands of text-generation models supported on [HuggingFace](https://huggingface.co/models?pipeline_tag=text-generation).

1. Connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>
    ```

2. Clone the KAITO project GitHub repository using the `git clone` command.

    ```bash
    git clone https://github.com/kaito-project/kaito.git
    ```

## Deploy your model inferencing workload using the KAITO workspace template

1. Navigate to the `kaito` directory and copy the [sample deployment YAML](https://github.com/kaito-project/kaito/tree/main/examples/custom-model-integration/custom-model-deployment.yaml) manifest. Replace the default values in the following fields with your model's requirements:

   - `instanceType`: The VM size for your inference service deployment. For larger model sizes you can choose a VM in the [`Standard_NCads_A100_v4`](/azure/virtual-machines/sizes/gpu-accelerated/nca100v4-series) family with higher memory capacity.
   - `MODEL_ID`: Your model's specific HuggingFace identifier, which can be found after `https://huggingface.co/` in the model card URL.
   - `"--torch_dtype"`: Set to `"float16"` for compatibility with V100 GPUs. For A100, H100 or newer GPUs, use `"bfloat16"`.
   - For this example, we use `Standard_NC24ads_A100_v4` as the instance type and the [HuggingFaceTB SmolLM2-1.7B-Instruct](https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct) model.

    ```yml
    apiVersion: kaito.sh/v1beta1
    kind: Workspace
    metadata:
      name: workspace-custom-llm
    resource:
      instanceType: "Standard_NC24ads_A100_v4" # Required VM SKU based on model requirements
      labelSelector:
        matchLabels:
          apps: custom-llm
    inference:
      template:
        spec:
          containers:
            - name: custom-llm-container
              image: mcr.microsoft.com/aks/kaito/kaito-base:0.2.0 # KAITO base image which includes hf runtime
              livenessProbe:
                failureThreshold: 3
                httpGet:
                  path: /health
                  port: 5000
                  scheme: HTTP
                initialDelaySeconds: 600
                periodSeconds: 10
                successThreshold: 1
                timeoutSeconds: 1
              readinessProbe:
                failureThreshold: 3
                httpGet:
                  path: /health
                  port: 5000
                  scheme: HTTP
                initialDelaySeconds: 30
                periodSeconds: 10
                successThreshold: 1
                timeoutSeconds: 1
              resources:
                requests:
                  nvidia.com/gpu: 1  # Request 1 GPU; adjust as needed
                limits:
                  nvidia.com/gpu: 1  # Optional: Limit to 1 GPU
              command:
                - "accelerate"
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
                - "HuggingFaceTB/SmolLM2-1.7B-Instruct" # The model's HuggingFace identifier
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

2. Save these changes to your `custom-model-deployment.yaml` file.
3. Run the deployment in your AKS cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f custom-model-deployment.yaml
    ```

## Test your custom model inferencing service

1. Track the live resource changes in your KAITO workspace using the `kubectl get workspace` command.

    ```bash
    kubectl get workspace workspace-custom-llm -w
    ```

    > [!NOTE]
    > Note that machine readiness can take *up to 10 minutes*, and workspace readiness *up to 20 minutes*. Proceed to the next step only once the workspace status shows `Ready`.

2. Once the workspace is ready, port forward the inference service to your local machine in a separate terminal.

    ```bash
    kubectl port-forward svc/workspace-custom-llm 5000:80
    ```

3. Install the OpenAI Python client.

    ```bash
    pip install openai
    ```

4. Save the following script as `test_inference.py` and run it using `python test_inference.py`:

    ```python
    from openai import OpenAI

    client = OpenAI(
        base_url="http://127.0.0.1:5000/v1",
        api_key="unused",
    )

    response = client.chat.completions.create(
        model="workspace-custom-llm",
        messages=[{"role": "user", "content": "What sport should I play in rainy weather?"}],
        max_tokens=400,
        stream=True,
    )

    print("".join(chunk.choices[0].delta.content or "" for chunk in response))
    ```

## Clean up resources

If you no longer need these resources, you can delete them to avoid incurring extra Azure compute charges.

Delete the KAITO inference workspace using the `kubectl delete workspace` command.

```bash
kubectl delete workspace workspace-custom-llm
```

## Next steps

In this article, you learned how to onboard a HuggingFace model for inferencing with the AI toolchain operator add-on directly to your AKS cluster. To learn more about AI and machine learning on AKS, see the following articles:

- [Fine tune a language model with KAITO on Azure Kubernetes Service (AKS)](./ai-toolchain-operator-fine-tune.md)
- [Deploy a Ray cluster on Azure Kubernetes Service (AKS)](./ray-overview.md)
- [Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)](./best-practices-ml-ops.md)
