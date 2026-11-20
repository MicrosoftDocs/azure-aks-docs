---
title: Manage model deployments with AI Manager (preview)
description: Check a model deployment's status, change its scaling settings, or delete the deployment.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: how-to
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
zone_pivot_groups: azure-portal-azure-cli
---

# Manage model deployments with AI Manager (preview)

Use the Azure CLI or the Azure portal to inspect a model deployment, update its replica settings, or delete that deployment without deleting its namespace or AI Manager.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

:::zone pivot="azure-cli"

## Before you begin

- An AI Manager with a namespace and model deployment.
- Azure CLI with access to the AI Manager CLI extension for the public preview.
- The **Azure AIManager Contributor** role at the model deployment, namespace, or AI Manager scope. To list deployments, assign the role at the namespace or a parent scope. At deployment scope, use `show` with the deployment name.

Set variables for your existing resources:

```bash
export RESOURCE_GROUP="<resource-group>"
export MANAGER_NAME="<ai-manager-name>"
export NAMESPACE_NAME="<namespace-name>"
export DEPLOYMENT_NAME="<deployment-name>"
```

## Check a model deployment

1. List the model deployments in a namespace. The table shows each deployment's provisioning state, replica counts as current/desired, model ID, and endpoint. This command requires the role at the namespace scope or a parent scope.

    ```azurecli-interactive
    az aimanager namespace modeldeployment list \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --namespace "$NAMESPACE_NAME" \
      --output table
    ```

1. Show one model deployment, including its endpoint and runtime status, by using its name. This command also works when the role is assigned at the deployment scope.

    ```azurecli-interactive
    az aimanager namespace modeldeployment show \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --namespace "$NAMESPACE_NAME" \
      --name "$DEPLOYMENT_NAME" \
      --output json
    ```

Wait until `provisioningState` is `Succeeded`. If the state is `Failed` or `Canceled`, stop checking. Inspect the full resource from the show command before you retry. For the full list of states, see [Provisioning states](./reference.md#provisioning-states). For the meanings of runtime status fields, see the [AI Manager resource reference](./reference.md).

## Change scaling settings

Use the variables that you set in [Before you begin](#before-you-begin).

The [`az aimanager namespace modeldeployment update`](/cli/azure/aimanager/namespace/modeldeployment#az-aimanager-namespace-modeldeployment-update) command supports either a fixed replica count or an autoscale range. It also exposes a performance mode option.

| Option | Purpose | Notes |
| --- | --- | --- |
| `--replicas` | Sets a fixed replica count. | Don't combine with `--min-replicas` or `--max-replicas`. |
| `--min-replicas` | Sets the minimum replica count for autoscaling. | Provide together with `--max-replicas`. |
| `--max-replicas` | Sets the maximum replica count for autoscaling. | Provide together with `--min-replicas`. |
| `--performance-mode` | Sets the performance mode: `Balanced`, `Latency`, or `Throughput`. | For the meaning of each mode, see the [AI Manager resource reference](./reference.md). |

The update command changes scaling and performance mode only. To use a different catalog model or VM size, create a new model deployment.

To set a fixed replica count, run:

```azurecli-interactive
az aimanager namespace modeldeployment update \
  --resource-group "$RESOURCE_GROUP" \
  --aimanager "$MANAGER_NAME" \
  --namespace "$NAMESPACE_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --replicas 2
```

To set an autoscale range, provide both its minimum and maximum:

```azurecli-interactive
az aimanager namespace modeldeployment update \
  --resource-group "$RESOURCE_GROUP" \
  --aimanager "$MANAGER_NAME" \
  --namespace "$NAMESPACE_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --min-replicas 1 \
  --max-replicas 3
```

After the update completes, run `az aimanager namespace modeldeployment show` again. For manual scaling, `desiredReplicas` reflects the replica count that you requested; for autoscaling, it reflects the autoscaler’s current target. The `currentReplicas` field reports the number of ready replicas. For a fixed replica count, confirm that `desiredReplicas` matches the requested count and that `currentReplicas` matches `desiredReplicas`. For autoscaling, check that the configured minimum and maximum replica counts match the requested range.

## Delete a model deployment

Use the variables that you set in [Before you begin](#before-you-begin).

1. Check the resource group, AI Manager, namespace, and model deployment name before you delete the model deployment.
1. Delete only the model deployment.

    ```azurecli-interactive
    az aimanager namespace modeldeployment delete \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --namespace "$NAMESPACE_NAME" \
      --name "$DEPLOYMENT_NAME" \
      --yes
    ```

This command targets the model deployment. It doesn't delete the namespace or AI Manager. To confirm the deletion, run the list command from [Check a model deployment](#check-a-model-deployment), which requires access to list deployments at the namespace or a parent scope. If your access is limited to the model deployment, ask an operator with namespace-level list access to perform this check. While the deletion is in progress, the state can show `Deleting`. When it finishes, the deployment no longer appears in the output.

:::zone-end

:::zone pivot="azure-portal"

## Before you begin

- An AI Manager with a namespace and model deployment.
- The **Azure AIManager Contributor** role at the model deployment, namespace, or AI Manager scope. To learn more about roles and access, visit [Grant access to AI Manager](./grant-access.md).

## View model deployments

Go to **AI/ML** > **Deployments** to view your model deployments. When a model's provisioning status is `Succeeded`, you can verify its current endpoint or inference status by selecting **Check status**, as shown in the following image. For the full list of states, see [Provisioning states](./reference.md#provisioning-states).

:::image type="content" source="../media/ai-manager/deployment-grid.png" alt-text="A screenshot of the deployment tab in AI/ML in Kubernetes center." lightbox="../media/ai-manager/deployment-grid.png":::

Each deployment's **Overview** contains more information such as its endpoint, GPU size, associated nodes, and related events.

:::image type="content" source="../media/ai-manager/model-overview.png" alt-text="A screenshot of a sample model overview." lightbox="../media/ai-manager/model-overview.png":::

## Change settings

To change scaling settings on a model deployment, go to its **Overview** and select **Change** next to **Scaling method**. Select **Manual** or **Autoscale** and set the replica counts.

:::image type="content" source="../media/ai-manager/scaling.png" alt-text="A screenshot of scaling options for a model deployment." lightbox="../media/ai-manager/scaling.png":::

## Delete a model deployment

Go to **Overview** and select **Delete** in the toolbar. You need to confirm before the model deployment is deleted.

> [!NOTE]
> Deleting a model deployment doesn't delete the underlying namespace or AI Manager. To delete the AI Manager or namespace, go to the resource and delete it there.

:::zone-end

## Next steps

- [Choose a model and estimate deployment cost](./estimate-cost.md).
- [Grant access to AI Manager](./grant-access.md).
- [Connect an application to a model endpoint](./connect-to-endpoint.md).
