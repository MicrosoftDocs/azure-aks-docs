---
title: Train an LLM with Ray on Azure Kubernetes Service (AKS)
description: Learn how to fine-tune Qwen2.5-7B with LLaMA-Factory using distributed Ray training and Kueue on AKS.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Train an LLM with Ray on AKS

In this article, you submit a RayJob that fine-tunes Qwen2.5-7B-Instruct on the viggo NLG dataset using [LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory) and distributed Ray Train. The job uses four workers with one GPU each, reads training data from Azure Blob Storage, and uploads the trained LoRA adapter for downstream inference.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* Infrastructure deployed following [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md).
* Kueue queues configured following [Configure Kueue queues for Ray workloads on AKS](./configure-ray-kueue-queues.md).
* At least four A100 GPUs available in the cluster (this example uses four workers with one GPU each).
* Viggo dataset uploaded to blob storage at `llm-pipeline/data/` (done automatically by the infrastructure Terraform module).
* `envsubst` installed (`gettext` package on Linux, `brew install gettext` on macOS).

## Set environment variables

Navigate to the LLM training example in the cloned repository and configure the required environment variables:

```bash
cd <path-to-cloned-repo>/AKS/examples/kueue-and-ray-on-aks/3-workloads/llm-training
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
source env.example
```

> [!NOTE]
> If you configured team queues (Option B), set `export QUEUE_NAME=team-a` or `export QUEUE_NAME=team-b` before running `source env.example`. The default `QUEUE_NAME=default` only works with the single-queue configuration (Option A).

## Submit the workload

Submit the distributed training RayJob:

```bash
./submit.sh
```

The script creates a ConfigMap from the training script, renders the manifest template with four GPU workers via `envsubst`, and applies it. Kueue admits the job when four GPUs are available in the configured queue.

> [!TIP]
> Run `./submit.sh --dry-run` to validate the rendered manifest without applying it to the cluster.

## Monitor progress

Find and export the job name if you're in a new shell:

```bash
export JOB_NAME=$(kubectl -n ray get rayjob --no-headers -o custom-columns=":metadata.name" | grep llm-training)
```

Watch the RayJob status and Kueue admission:

```bash
kubectl -n ray get rayjob ${JOB_NAME} -w
kubectl -n ray get workload -w
```

Expected output when the job completes:

```output
NAME                      JOB STATUS   DEPLOYMENT STATUS   START TIME             END TIME               AGE
llm-training-xxxxxxxxxx   SUCCEEDED    Complete            2026-01-01T00:00:00Z   2026-01-01T00:19:00Z   19m
```

```output
NAME                                   QUEUE     RESERVED IN     ADMITTED   FINISHED   AGE
rayjob-llm-training-xxxxxxxxxx-xxxxx   default   cluster-queue   True       True       19m
```

Tail the head pod logs:

```bash
kubectl -n ray logs -f -l ray.io/cluster=$(kubectl -n ray get rayjob ${JOB_NAME} -o jsonpath='{.status.rayClusterName}') -c ray-head
```

## Verify results

Check the LoRA adapter upload:

```bash
az storage blob list -c llm-pipeline --prefix lora/ \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login -o table
```

Expected output:

```output
Name                                       Blob Type    Blob Tier    Length    Content Type
-----------------------------------------  -----------  -----------  --------  ------------------------
lora/latest.txt                            BlockBlob    Hot          86        application/octet-stream
lora/<job-name>/rng_state_3.pth            BlockBlob    Hot          14725     application/octet-stream
```

Verify the `latest.txt` pointer was written (used by the batch inference example for auto-discovery):

```bash
az storage blob download -c llm-pipeline -n lora/latest.txt \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login
```

Expected output:

```output
azure://llm-pipeline@<storage-account>.blob.core.windows.net/lora/<job-name>
```

## Configuration reference

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | *(required)* | Storage account from Module 1 |
| `NUM_WORKERS` | `4` | GPU worker replicas (4 x 1 GPU each) |
| `QUEUE_NAME` | `default` | Kueue LocalQueue name |
| `LLM_DATA_CONTAINER` | `llm-pipeline` | Blob container for input data |
| `LLM_LORA_CONTAINER` | `llm-pipeline` | Blob container for LoRA upload |
| `CONFIGMAP_NAME` | `llm-training-scripts` | Name for the ConfigMap holding the training script |

## Clean up resources

Delete the RayJob and its ConfigMap:

```bash
kubectl -n ray delete rayjob ${JOB_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```

## Next steps

> [!div class="nextstepaction"]
> [Run batch inference with the trained adapter](./ray-batch-inference.md)
