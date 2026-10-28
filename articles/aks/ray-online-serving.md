---
title: Serve a model with Ray Serve on Azure Kubernetes Service (AKS)
description: Learn how to deploy a fine-tuned Aurora model as a persistent HTTP endpoint using Ray Serve on AKS.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Serve a model with Ray Serve on AKS

In this article, you deploy the fine-tuned Aurora weather model as a persistent HTTP endpoint by using Ray Serve on Azure Kubernetes Service (AKS). This method uses a **RayService** resource for long-lived serving and isn't admission-controlled by Kueue.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* Infrastructure deployed following [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md).
* Namespace and service account created following [Configure Kueue queues for Ray workloads on AKS](./configure-ray-kueue-queues.md).
* Aurora fine-tune completed following [Fine-tune the Aurora weather model with Ray on AKS](./ray-finetune-aurora.md) - the LoRA checkpoint must exist at `aurora/checkpoints/<run-id>/last.safetensors` in blob storage.
* `envsubst` installed (`gettext` package on Linux, `brew install gettext` on macOS).

## Set environment variables

Navigate to the online serving example in the cloned repository and configure the required environment variables:

```bash
cd <path-to-cloned-repo>/AKS/examples/kueue-and-ray-on-aks/3-workloads/online-serving
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
export AURORA_RUN_ID=<your-aurora-finetune-job-name>
source env.example
```

> [!NOTE]
> `AURORA_RUN_ID` is the `JOB_NAME` from your completed Aurora fine-tune run. You can find it with:
> ```bash
> az storage blob list -c aurora --prefix checkpoints/ \
>   --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login -o table
> ```

## Deploy the service

Deploy the RayService:

```bash
./submit-service.sh
```

The script creates a ConfigMap from the serving application code, renders the RayService manifest via `envsubst`, and applies it. The KubeRay operator creates the Ray cluster and deploys the Serve application.

> [!TIP]
> Run `./submit-service.sh --dry-run` to validate the rendered manifest without applying it to the cluster.

> [!NOTE]
> RayService is not admission-controlled by Kueue. Serving workloads are long-lived and need dedicated resources rather than batch queue semantics.

## Verify the deployment

Watch until the RayService reports Running:

```bash
kubectl -n ray get rayservice ${SERVICE_NAME} -w
```

Expected output:

```output
NAME           SERVICE STATUS   NUM SERVE ENDPOINTS
aurora-serve   Running          1
```

## Test the endpoint

Port-forward the serve service and send test requests:

```bash
kubectl -n ray port-forward svc/${SERVICE_NAME}-serve-svc 8000:8000
```

Health check:

```bash
curl http://localhost:8000${ROUTE_PREFIX}
```

Expected output:

```output
{"status":"ok","gpu_name":"NVIDIA A100-SXM4-80GB","run_id":"<your-run-id>","adapter":"checkpoints/<your-run-id>/last.safetensors"}
```

Forecast request:

```bash
curl -X POST http://localhost:8000${ROUTE_PREFIX} \
  -H 'Content-Type: application/json' \
  -d '{"init_file": "init-2021-01-01-00z.npz", "lead_hours": 6}'
```

Expected output:

```output
{
  "init_file": "init-2021-01-01-00z.npz",
  "lead_hours": 6,
  "surface_variables": {
    "2t":  {"shape": [1,1,52,100], "mean": 298.76, "min": 272.0, "max": 302.0},
    "10u": {"shape": [1,1,52,100], "mean": -2.21,  "min": -18.0, "max": 15.38},
    "10v": {"shape": [1,1,52,100], "mean": 0.92,   "min": -13.88,"max": 18.88},
    "msl": {"shape": [1,1,52,100], "mean": 101320.07, "min": 100352.0, "max": 101888.0}
  },
  "gpu_name": "NVIDIA A100-SXM4-80GB",
  ...
}
```

The response includes per-variable summary statistics (shape, mean, min, max) for each surface variable in the forecast.

## Configuration reference

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | *(required)* | Storage account from Module 1 |
| `AURORA_RUN_ID` | *(required)* | JOB_NAME from a completed aurora-finetune run |
| `AURORA_INPUT_CONTAINER` | `aurora` | Container with init data |
| `AURORA_ADAPTER_CONTAINER` | `aurora` | Container with the LoRA checkpoint |
| `AURORA_INIT_FILE` | `init-2021-01-01-00z.npz` | Default init file for requests |
| `AURORA_LEAD_HOURS` | `6` | Default forecast lead time (must be a 6h multiple) |
| `AURORA_LORA_RANK` | `8` | LoRA rank (must match training) |
| `AURORA_REQUIRE_GPU_NAME` | `A100` | GPU name check (empty to skip) |
| `SERVICE_NAME` | `aurora-serve` | Name for the RayService resource |
| `ROUTE_PREFIX` | `/aurora` | HTTP route prefix for the serve endpoint |
| `CONFIGMAP_NAME` | `aurora-serve-scripts` | Name for the ConfigMap holding the serving script |

## Clean up resources

Delete the RayService and its ConfigMap:

```bash
kubectl -n ray delete rayservice ${SERVICE_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```

## Next steps

* [Train an LLM with Ray](./ray-train-llm.md)
* [Run batch inference with Ray](./ray-batch-inference.md)
