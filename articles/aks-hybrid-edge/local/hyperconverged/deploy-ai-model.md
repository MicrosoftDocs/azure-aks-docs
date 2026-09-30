---
title: Deploy an AI model on AKS Hybrid and Edge with the Kubernetes AI toolchain operator (preview)
description: Learn how to deploy an AI model on AKS Hybrid and Edge with the Kubernetes AI toolchain operator (KAITO).
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.reviewer: haojiehang
ms.lastreviewed: 05/27/2025
ms.custom: hyperconverged

---

# Deploy an AI model on AKS Hybrid and Edge with the Kubernetes AI toolchain operator (preview)

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to deploy an AI model on AKS Hybrid and Edge with the *Kubernetes AI toolchain operator* (KAITO). The AI toolchain operator runs as a cluster extension in AKS Hybrid and Edge and makes it easier to deploy and run open source LLM models on your AKS Hybrid and Edge cluster. To enable this feature, follow this workflow:

1. Create a cluster with KAITO.
1. Add a GPU node pool.
1. Model deployment.
1. Validate the model with a test prompt.
1. Clean up resources.
1. Troubleshoot as needed.

> [!IMPORTANT]
> The KAITO Extension for AKS Hybrid and Edge on Azure Local is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

## Prerequisites

Before you begin, make sure you have the following prerequisites:

- Make sure the Azure Local cluster has a supported GPU, such as A2, A16, or T4.
- Make sure the AKS Hybrid and Edge cluster can deploy GPU node pools with the corresponding GPU VM SKU. For more information, see [use GPU for compute-intensive workloads](deploy-gpu-node-pool.md).
- Make sure that **kubectl** is installed on your local machine. If you need to install **kubectl**, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).  
- Install the **aksarc** extension, and make sure the version is at least 1.5.37. To get the list of installed CLI extensions, run `az extension list -o table`.
- If you use a Powershell terminal, make sure the version is at least 7.4.

For all hosted model preset images and default resource configuration, see the [KAITO GitHub repository](https://github.com/kaito-project/kaito/tree/main/presets). All the preset models are originally from HuggingFace, and we do not change the model behavior during the redistribution. See the [content policy from HuggingFace](https://huggingface.co/content-policy).

The AI toolchain operator extension currently supports KAITO version 0.4.5. Make a note of this in considering your choice of model from the KAITO model repository.

## Create a cluster with KAITO

To create an AKS Hybrid and Edge cluster on Azure Local with KAITO, follow these steps:

1. Gather [all required parameters](../aks-create-clusters-cli.md) and include the `--enable-ai-toolchain-operator` parameter to enable KAITO as part of the cluster creation.

   ```azurecli
   az aksarc create --resource-group <Resource_Group_name> --name <Cluster_Name> --custom-location <Custom_Location_Name> --vnet-ids <VNet_ID> --enable-ai-toolchain-operator
   ```

1. After the command succeeds, make sure the KAITO extension is installed correctly and the KAITO operator under the `kaito` namespace is in a running state.

## Update an existing cluster with KAITO

If you want to enable KAITO on an existing AKS Hybrid and Edge cluster with a GPU, you can run the following command to install the KAITO operator on the existing node pool:

```azurecli
az aksarc update --resource-group <Resource_Group_name> --name <Cluster_Name> --enable-ai-toolchain-operator
```

## Add a GPU node pool

1. Before you add a GPU node pool, make sure that Azure Local is enabled with a supported GPU such as A2, T4, or A16, and that the GPU drivers are installed on all the host nodes. To add a GPU node pool, follow these steps:

   ### [Azure portal](#tab/portal)

   Sign in to the Azure portal and find your AKS Hybrid and Edge cluster. Under **Settings > Node pools**, select **Add**. Fill in the other required fields, then create the node pool.

   :::image type="content" source="../../media/deploy-ai-model/add-gpu-node-pool.png" alt-text="Screenshot of portal showing add GPU node pool." lightbox="../../media/deploy-ai-model/add-gpu-node-pool.png":::

   ### [Azure CLI](#tab/azurecli)

   To create a GPU node pool using Azure CLI, run the following command. The GPU VM SKU used in the following example is for the **A16** model. For the full list of VM SKUs, see [Supported VM sizes](deploy-gpu-node-pool.md#supported-gpu-vm-sizes).

   ```azurecli
   az aksarc nodepool add --name "samplenodepool" --cluster-name "samplecluster" --resource-group "sample-rg" --node-vm-size "Standard_NC16_A16" --os-type "Linux"
   ```

   ---

2. After the node pool is provisioned, you can confirm whether the node is successfully provisioned using the node pool name:

   ```azurecli
   kubectl get nodes --show-labels | grep "msft.microsoft/nodepool-name=.*<Node_Pool_Name>" | awk '{print $1}'
   ```

   For PowerShell, you can use the following command:

   ```powershell
   kubectl get nodes --show-labels | Select-String "msft.microsoft/nodepool-name=.*<Node_Pool_Name>" | ForEach-Object { ($_ -split '\s+')[0] }
   ```

3. Label the newly provisioned GPU node so the inference workspace can be deployed to the node in the next step. You can make sure the label is applied using `kubectl get nodes`.

   ```powershell
   kubectl label node moc-l36c6vu97d5 apps=llm-inference
   ```

## Model deployment

To deploy the AI model, follow these steps:

1. Create a YAML file with the following sample file. In this example, we use the Phi 3.5 Mini model by specifying the preset name as **phi-3.5-mini-instruct**. If you want to use other LLMs, use the preset name from the KAITO repo. You should also make sure that the LLM can deploy on the VM SKU based on the matrix table in the "Model VM SKU Matrix" section.

   ```yaml
   apiVersion: kaito.sh/v1beta1
   kind: Workspace
   metadata:
     name: workspace-llm
   resource:
     instanceType: <GPU_VM_SKU> # Update this value with GPU VM SKU
     labelSelector:
       matchLabels:
         apps: llm-inference
     preferredNodes:
       - moc-l36c6vu97d5 # Update the value with GPU VM name
   inference:
     preset:
       name: phi-3.5-mini-instruct # Update preset name as needed
     config: "ds-inference-params"
   ---
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: ds-inference-params
   data:
     inference_config.yaml: |
       max_probe_steps: 6 # Maximum number of steps to find the max available seq len fitting in the GPU memory.
       vllm:
         cpu-offload-gb: 0
         swap-space: 4
         gpu-memory-utilization: 0.9
         max-model-len: 4096
   ```

1. Apply the YAML and wait until the deployment completes. Make sure that internet connectivity is good so that the model can be downloaded from the Hugging Face website within a few minutes. When the inference workspace is successfully provisioned, both **ResourceReady** and **InferenceReady** become **True**. See the "Troubleshooting" section if you encounter any failures in the workspace deployment.

   ```azurecli
   kubectl apply -f sampleyamlfile.yaml
   ```

1. Validate that the workspace deployment succeeded:

   ```azurecli
   kubectl get workspace -A
   ```

## Validate the model with a test prompt

After the resource and inference states become ready, the inference service is exposed internally via a Cluster IP. You can test the model with the following prompt:

```bash
export CLUSTERIP=$(kubectl get svc workspace-llm  -o jsonpath="{.spec.clusterIPs[0]}") 

kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$CLUSTERIP/v1/completions
  -H "Content-Type: application/json"
  -d '{
    "model": "phi-3.5-mini-instruct",
    "prompt": "What is kubernetes?",
    "max_tokens": 20,
    "temperature": 0
  }' 
```

```powershell
$CLUSTERIP = $(kubectl get svc workspace-llm -o jsonpath="{.spec.clusterIPs[0]}" )
$jsonContent = '{"model":"phi-3.5-mini-instruct","prompt":"What is kubernetes","max_tokens":200,"temperature":0}' | ConvertTo-Json

kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$CLUSTERIP/v1/completions -H "accept: application/json" -H "Content-Type: application/json" -d $jsonContent
```

## Clean up resources

To clean up the resources, remove both the inference workspace and the extension:

```azurecli
kubectl delete workspace workspace-llm

az aksarc update --resource-group <Resource_Group_name> --name <Cluster_Name> --disable-ai-toolchain-operator
```

## Model VM SKU Matrix

The following table shows the supported GPU models and their corresponding VM SKUs. The GPU model is used to determine the VM SKU when you create a node pool. For more information about the GPU models, see [Supported GPU models](scale-requirements.md#supported-gpu-models).

|     Type                            |     T4              |     A2 or A16                     |     A2 or A16                       |
|-------------------------------------|---------------------|-----------------------------------|-------------------------------------|
|     Model VM SKU Matrix             |     Standard_NK6    |     Standard_NC4, Standard_NC8    |     Standard_NC32, Standard_NC16    |
|     phi-3-mini-4k-instruct          |     Y               |     Y                             |     Y                               |
|     phi-3-mini-128k-instruct        |     N               |     Y                             |     Y                               |
|     phi-3.5-mini-instruct           |     N               |     Y                             |     Y                               |
|     phi-4-mini-instruct             |     N               |     N                             |     Y                               |
|     mistral-7b/mistral-7b-instruct  |     N               |     N                             |     Y                               |
|     qwen2.5-coder-7b-instruct       |     N               |     N                             |     Y                               |

## Troubleshooting

1. If you want to deploy an LLM and see the error **OutOfMemoryError: CUDA out of memory**, please raise an issue in the [KAITO repo](https://github.com/kaito-project/kaito/).
1. If you see the error **(ExtensionOperationFailed) The extension operation failed with the following error: Unable to get a response from the Agent in time** during extension installation, [see this TSG](/troubleshoot/azure/azure-kubernetes/extensions/cluster-extension-deployment-errors#error-unable-to-get-a-response-from-the-agent-in-time) and ensure the extension agent in the AKS Hybrid and Edge cluster can connect to Azure.
1. If you see an error during prompt testing such as **{"detail":[{"type":"json_invalid","loc":["body",1],"msg":"JSON decode error","input":{},"ctx":{"error":"Expecting property name enclosed in double quotes"}}]}**, it's possible that your PowerShell terminal version is 5.1. Make sure the terminal version is at least 7.4.

## Next steps

* [Monitor the inference metrics](/azure/aks/ai-toolchain-operator-monitoring) in Managed Prometheus and Managed Grafana
* For more information about KAITO, see [KAITO GitHub Repo](https://github.com/kaito-project/kaito)
