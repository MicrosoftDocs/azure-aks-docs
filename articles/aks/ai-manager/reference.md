---
title: AI Manager resource reference (preview)
description: Reference AI Manager resource paths, selected properties, scaling values, provisioning states, and endpoint details.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: reference
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
---

# AI Manager resource reference (preview)

This article lists ARM resource paths, properties, and defaults for AI Manager, namespace, and model deployment resources. It also lists provisioning states, runtime status fields, and the `az aimanager namespace list-accesskeys` output. These details apply to the AI Manager public-preview guides. The API version represented by the current generated types is `2026-09-02-preview`.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

For procedures, see [Deploy a model with AI Manager](./quickstart.md), [Manage model deployments](./manage-deployments.md), and [Choose a model and estimate deployment cost](./estimate-cost.md). To inspect command options in your installed extension, run `az aimanager --help` or `az aimanager namespace modeldeployment --help`.

## AI Manager resource relationships

| Resource | ARM resource path | Scope |
|---|---|---|
| AI Manager | `Microsoft.ContainerService/aiManagers/{aiManagerName}` | Resource group |
| Namespace | `Microsoft.ContainerService/aiManagers/{aiManagerName}/namespaces/{namespaceName}` | Child of an AI Manager |
| Model deployment | `Microsoft.ContainerService/aiManagers/{aiManagerName}/namespaces/{namespaceName}/modeldeployments/{deploymentName}` | Child of a namespace |
| AI model | `Microsoft.ContainerService/locations/{location}/aiModels/{modelName}` | Subscription and location |

An AI model (catalog model) isn't nested under an AI Manager or resource group. The readable `modelId` identifies a catalog model. Its ARM resource name, the `name` value, is different.

## AI Manager properties

| Property | Description and values | Default or mutability |
|---|---|---|
| `location` | Required Azure location for the AI Manager. | Required when creating the resource. |
| `properties.deletePolicy` | Controls what happens to the underlying cluster resources when you delete the AI Manager. `Keep` retains those resources; `Delete` deletes both the underlying cluster resources and the AI Manager resource together. | Defaults to `Delete` when omitted. |
| `properties.provisioningState` | Read-only state of the last AI Manager operation. | Read-only. See [Provisioning states](#provisioning-states). |
| `properties.managedResourceGroupName` | Read-only name of the managed resource group created by AI Manager to hold underlying infrastructure resources. | Read-only. |

## AI Manager namespace properties

| Property | Description |
|---|---|
| `properties.labels` | Optional map of labels applied to the Kubernetes namespace. |
| `properties.annotations` | Optional map of annotations applied to the Kubernetes namespace. |
| `properties.provisioningState` | Read-only state of the last namespace operation. See [Provisioning states](#provisioning-states). |

## AI Manager model deployment properties

| Property | Description and values | Update behavior |
|---|---|---|
| `properties.modelResourceId` | Full ARM resource ID of the catalog model used by the deployment. | Immutable after creation. Create a new deployment to use a different catalog model. |
| `properties.vmSize` | VM SKU used by the deployment. Choose a feasible plan from `az aimanager model calculate-cost`. | Immutable after creation. Create a new deployment to use a different VM size. |
| `properties.scale.manual.replicas` | Desired fixed replica count. | Change with `az aimanager namespace modeldeployment update --replicas`. |
| `properties.scale.autoscale.minReplicas` and `properties.scale.autoscale.maxReplicas` | Minimum and maximum replica counts for autoscaling. | Change with `--min-replicas` and `--max-replicas`. Don't combine these options with `--replicas`. |
| `properties.performanceMode` | Performance mode. Values are `Balanced` (default balance between latency and throughput), `Latency` (optimize for low request latency), and `Throughput` (optimize for aggregate throughput). | The CLI update command exposes `--performance-mode`. |
| `properties.status` | Read-only runtime status. | Read-only. See [Runtime status](#runtime-status). |

The CLI update command exposes scaling and performance mode options. To change a deployment's catalog model or VM size, create a new model deployment.

## Select an AI Manager model from the catalog

Before using the catalog, [register the AI Manager preview feature](./quickstart.md#register-the-ai-manager-preview-feature). Run [`az aimanager model list`](/cli/azure/aimanager/model#az-aimanager-model-list) for the subscription and location where you plan to deploy. Choose a catalog model by its readable `modelId`. Use its matching `name` value as the ARM resource name for the cost calculator and when building the deployment's `modelResourceId`.

```azurecli-interactive
az aimanager model list \
  --subscription "<subscription-id>" \
  --location "<location>" \
  --output table
```

For model selection and cost planning, see [Choose a model and estimate deployment cost](./estimate-cost.md).

## Provisioning states

The AI Manager, namespace, and model deployment resources use these provisioning state values:

| State | Description |
|---|---|
| `Creating` | The resource is being created. |
| `Updating` | The resource is being updated. |
| `Deleting` | The resource is being deleted. |
| `Succeeded` | The last operation completed successfully. |
| `Failed` | The last operation failed. |
| `Canceled` | The last operation was canceled. |

## Runtime status

`properties.status` is read-only. Each field in the following table is under that path, for example `properties.status.currentReplicas`. Current model deployment API types include these fields:

| Field | Description |
|---|---|
| `endpoint` | Serving endpoint of the model deployment, reported by the runtime. Full path: `properties.status.endpoint`. |
| `currentReplicas` | Number of ready replicas currently serving traffic. |
| `desiredReplicas` | Desired replica count reported by the controller. For manual scaling, this matches `properties.scale.manual.replicas`; for autoscaling, it is the current target derived by the autoscaler. |
| `engine` and `engineVersion` | Inference engine name and version. |
| `maxModelLen` | Maximum model context length, in tokens, configured for the deployment. |
| `quantization` | Quantization level applied to the model weights. |
| `peakTokensPerMinute` | Peak tokens per minute measured by a live stress test. |
| `estimatedProvisionTimeSeconds` | Estimated total time, in seconds, for the deployment to become ready, including VM provisioning, image and model-weight pulls, and engine warm-up. |

Separately from `properties.status`, the `az aimanager namespace list-accesskeys` command returns the following namespace access information:

| Field | Description |
|---|---|
| `endpoint` | In the `list-accesskeys` output, the OpenAI-compatible base URL for the namespace inference endpoint. Use it as returned by the command. |
| `primaryKey` and `secondaryKey` | API keys for the endpoint. Treat both values as secrets. |
| `lastRotatedAt` | UTC timestamp of the last key rotation. Absent until a rotation occurs. |

## Next steps

- [Grant access to AI Manager](./grant-access.md).
- [Connect an application to a model endpoint](./connect-to-endpoint.md).
