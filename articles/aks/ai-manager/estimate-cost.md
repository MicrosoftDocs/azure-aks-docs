---
title: Choose a model and estimate deployment cost with AI Manager (preview)
description: Find a catalog model for your location, compare feasible GPU plans, and review the cost estimate before deployment.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: how-to
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
---

# Choose a model and estimate deployment cost with AI Manager (preview)

Before you create a model deployment, choose a catalog model that's available to your subscription and location. Run [`az aimanager model list`](/cli/azure/aimanager/model#az-aimanager-model-list) to find models, and run [`az aimanager model calculate-cost`](/cli/azure/aimanager/model#az-aimanager-model-calculate-cost) to compare feasible GPU plans and estimate VM cost.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- An Azure subscription and a location supported during preview. Use the same location for model listing, cost calculation, and deployment. Before listing models, [register the AI Manager preview feature](./quickstart.md#register-the-ai-manager-preview-feature).
- Azure CLI with access to the AI Manager CLI extension for the public preview.
- Permission to read model catalog entries and calculate costs. The **Azure AIManager Model User** role provides these permissions at the subscription scope or another applicable parent scope.

## List available models

1. Sign in to Azure and select the subscription where you have the **Azure AIManager Model User** role.

    ```azurecli-interactive
    az login
    az account set --subscription "<subscription-id>"
    ```

1. List the catalog models available in the selected location.

    ```azurecli-interactive
    az aimanager model list \
      --subscription "<subscription-id>" \
      --location "<supported-region>" \
      --output table
    ```

    The table shows each model's `Name`, `ModelId`, and `Description`. If the table is empty, check the location and your **Azure AIManager Model User** role assignment.

1. Choose a catalog model by its readable `ModelId`. The matching `Name` value is the model's ARM resource name. Use it for the cost calculator and for the ARM resource ID that you use to create a deployment. The `ModelId` isn't the ARM resource name.

## Compare GPU plans and estimates

1. Calculate plans for the selected model. Set `<resource-name>` to the `Name` value that you chose in [List available models](#list-available-models).

    ```azurecli-interactive
    az aimanager model calculate-cost \
      --subscription "<subscription-id>" \
      --location "<supported-region>" \
      --name "<resource-name>" \
      --output table
    ```

    The table lists one plan per row. Feasible plans are listed first, from cheapest to most expensive.

1. Compare the plans. Select a plan where `Feasible` is `True`, and record its `VmSize`. The table includes the following columns:

    | Column | Meaning |
    | --- | --- |
    | `VmSize` | The VM size for the plan. Record this value for a feasible plan. |
    | `Feasible` | Whether you can deploy the model with this plan. Select a plan where the value is `True`. |
    | `VmsPerReplica` | The number of VMs that one model replica requires. |
    | `VmHourlyPrice` | The hourly retail price for one VM. A value of `0` means that no price is available. |
    | `TotalHourlyPrice` | The hourly price for one model replica, which is `VmHourlyPrice` multiplied by `VmsPerReplica`. |
    | `MaxAvailableReplicas` | The number of replicas that your current quota allows for this VM size. |
    | `Quantization` | The quantization applied to the model weights for this plan. |
    | `InfeasibilityReason` | For an infeasible plan, the reason code. See the following table. |

To estimate hourly VM cost for a fixed replica count, multiply `TotalHourlyPrice` by the number of replicas. With autoscaling, the actual hourly VM cost varies with the replica count. The calculator doesn't provide a complete estimate of every Azure charge associated with an AI Manager deployment. To see when prices were captured, run the command with `--output json` and check each plan's `priceAsOf` value.

The `InfeasibilityReason` column shows one of the following codes. For the full explanation, run the command with `--output json` and check each plan's `infeasibilityReason.message` value.

| Code | Meaning |
| --- | --- |
| `InsufficientQuota` | The subscription doesn't have enough quota for the plan. Request quota for the required VM family and location before you deploy. |
| `RegionUnavailable` | The VM size isn't available in the selected location. Choose another feasible plan or supported location. |
| `InefficientDeployment` | The plan's estimated serving performance is below the acceptable threshold for this model. Choose another plan or model. |

## Use the selected plan

Use the model's ARM resource name and the selected `vmSize` when you create a model deployment. For an end-to-end example, see [Deploy a model with AI Manager](./quickstart.md).

## Next steps

- [Manage model deployments](./manage-deployments.md).
- [View the AI Manager resource reference](./reference.md).
