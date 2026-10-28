---
title: Run batch inference with Ray on Azure Kubernetes Service (AKS)
description: Learn how to run vLLM batch inference using a trained LoRA adapter with Ray and Kueue on AKS.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Run batch inference with Ray on AKS

In this article, you submit a RayJob that runs vLLM offline batch inference using the LoRA adapter produced by the [LLM training example](./ray-train-llm.md). The job reads the viggo test split and LoRA adapter from Azure Blob Storage, generates predictions on a single GPU, and uploads the results.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* Infrastructure deployed following [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md).
* Kueue queues configured following [Configure Kueue queues for Ray workloads on AKS](./configure-ray-kueue-queues.md).
* At least one A100 GPU available in the cluster.
* LLM training completed following [Train an LLM with Ray on AKS](./ray-train-llm.md) — the LoRA adapter must exist at `llm-pipeline/lora/` in blob storage.
* `envsubst` installed (`gettext` package on Linux, `brew install gettext` on macOS).

## Set environment variables

Navigate to the batch inference example in the cloned repository and configure the required environment variables:

```bash
cd <path-to-cloned-repo>/AKS/examples/kueue-and-ray-on-aks/3-workloads/batch-inference
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
source env.example
```

> [!NOTE]
> If you configured team queues (Option B), set `export QUEUE_NAME=team-a` or `export QUEUE_NAME=team-b` before running `source env.example`. The default `QUEUE_NAME=default` only works with the single-queue configuration (Option A).

## Submit the workload

Submit the batch inference RayJob:

```bash
./submit.sh
```

The script creates a ConfigMap from the inference script, renders the manifest template via `envsubst`, and applies it. Kueue admits the job when 1 GPU is available in the configured queue.

> [!TIP]
> Run `./submit.sh --dry-run` to validate the rendered manifest without applying it to the cluster.

## Monitor progress

Find and export the job name if you're in a new shell:

```bash
export JOB_NAME=$(kubectl -n ray get rayjob --no-headers -o custom-columns=":metadata.name" | grep batch-inference)
```

Watch the RayJob status and Kueue admission:

```bash
kubectl -n ray get rayjob ${JOB_NAME} -w
kubectl -n ray get workload -w
```

Expected output when the job completes:

```output
NAME                         JOB STATUS   DEPLOYMENT STATUS   START TIME             END TIME               AGE
batch-inference-xxxxxxxxxx   SUCCEEDED    Complete            2026-01-01T00:00:00Z   2026-01-01T00:09:00Z   9m
```

```output
NAME                                      QUEUE     RESERVED IN     ADMITTED   FINISHED   AGE
rayjob-batch-inference-xxxxxxxxxx-xxxxx   default   cluster-queue   True       True       9m
```

Tail the worker logs:

```bash
kubectl -n ray logs -l ray.io/cluster=$(kubectl -n ray get rayjob ${JOB_NAME} -o jsonpath='{.status.rayClusterName}') -f --tail=100
```

## Verify results

List prediction files in blob storage:

```bash
az storage blob list -c llm-pipeline --prefix "inference/${JOB_NAME}/" \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login -o table
```

Expected output:

```output
Name                                                 Blob Type    Blob Tier    Length    Content Type
---------------------------------------------------  -----------  -----------  --------  ------------------------
inference/<job-name>/metrics.json                    BlockBlob    Hot          128       application/octet-stream
inference/<job-name>/predictions.jsonl               BlockBlob    Hot          411777    application/octet-stream
```

Download and inspect the predictions:

```bash
az storage blob download -c llm-pipeline \
  -n "inference/${JOB_NAME}/predictions.jsonl" \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login \
  --file /tmp/predictions.jsonl
head -1 /tmp/predictions.jsonl | python3 -m json.tool
```

Expected output:

```output
{
    "input": "I'm wondering, have you played any games you found genuinely shocking?",
    "expected": "request(specifier[shocking])",
    "generated": "request_explanation"
}
```

## Configuration reference

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | *(required)* | Storage account from Module 1 |
| `JOB_NAME` | `batch-inference-<timestamp>` | Unique RayJob name |
| `QUEUE_NAME` | `default` | Kueue LocalQueue name |
| `LLM_DATA_CONTAINER` | `llm-pipeline` | Blob container with viggo test data |
| `LLM_LORA_CONTAINER` | `llm-pipeline` | Blob container with LoRA adapters |
| `CONFIGMAP_NAME` | `batch-inference-scripts` | Name for the ConfigMap holding the inference script |

## Clean up resources

Delete the RayJob and its ConfigMap:

```bash
kubectl -n ray delete rayjob ${JOB_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```

To tear down all infrastructure, see [Deploy infrastructure — Clean up resources](./deploy-ray-infrastructure.md#clean-up-resources).

## Next steps

* [Deploy an application that uses OpenAI on AKS](/azure/aks/open-ai-quickstart)
* [Build and deploy data and machine learning pipelines with Flyte on AKS](/azure/aks/use-flyte)
* [Tune an AI model on AKS with the AI toolchain operator](/azure/aks/ai-toolchain-operator-fine-tune)
