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
---

# Manage model deployments with AI Manager (preview)

Use the Azure CLI to inspect a model deployment, update its replica settings, or delete that deployment without deleting its namespace or AI Manager.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

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

## Next steps

- [Choose a model and estimate deployment cost](./estimate-cost.md).
- [Grant access to AI Manager](./grant-access.md).
- [Connect an application to a model endpoint](./connect-to-endpoint.md).
