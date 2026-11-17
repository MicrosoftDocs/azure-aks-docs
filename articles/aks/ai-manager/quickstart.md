---
title: "Quickstart: Deploy a model with AI Manager (preview)"
description: Create an AI Manager, deploy a model, and send an inference request with the Azure CLI.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: quickstart
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
---

# Quickstart: Deploy a model with AI Manager (preview)

In this quickstart, you create an AI Manager with a managed AKS cluster, add a namespace, deploy a supported model from the regional catalog, and send a chat completion request.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
- A location supported by the AI Manager public preview.
- If you have multiple Azure subscriptions, select the subscription to use by using the [`az account set`](/cli/azure/account#az-account-set) command.
- `curl`, to send an inference request. Azure Cloud Shell includes `curl`.
- The permissions in the following table.

    | Task | Role or permission | Notes |
    | --- | --- | --- |
    | Register preview features and resource providers | **Contributor** or **Owner** at the subscription scope | These roles include the required permissions. |
    | Create an AI Manager and its child resources | A role that can create these resources | For role choices and scopes, see [Grant access to AI Manager](./grant-access.md). |
    | Read model catalog entries and calculate deployment costs | **Azure AIManager Model User** | Assign the role at the subscription scope or another applicable parent scope. |
    | Create and delete the dedicated resource group | Permission to create and delete resource groups | The resource group is used only for this quickstart. |

## Install the AI Manager CLI extension

Install the `aimanager` Azure CLI extension, or update it to the latest version, by using the [`az extension add`](/cli/azure/extension#az-extension-add) command. All published versions of the extension are previews, so include `--allow-preview true`.

```azurecli-interactive
az extension add --name aimanager --upgrade --allow-preview true
```

## Register the AI Manager preview feature

Register the `AIManagerPreview` feature flag by using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name AIManagerPreview
```

Verify the registration status by using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the status to show *Registered*. If the status is *Pending*, the preview requires approval. Don't continue until the status is *Registered*.

```azurecli-interactive
az feature show --namespace Microsoft.ContainerService --name AIManagerPreview --query properties.state --output tsv
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

> [!NOTE]
> If a later `az aimanager create` command reports that the `AIManagerPreview` feature flag isn't registered, wait a few minutes for the resource provider registration to finish, and then try again.

## Define environment variables

Define the following environment variables for use throughout this quickstart. Replace `<supported-region>` with a location supported by the AI Manager public preview.

```bash
export RANDOM_STRING=$(printf '%05d%05d' "$RANDOM" "$RANDOM")
export SUBSCRIPTION_ID=$(az account show --query id --output tsv)
export LOCATION="<supported-region>"
export RESOURCE_GROUP="myAIManagerResourceGroup$RANDOM_STRING"
export MANAGER_NAME="myaimanager$RANDOM_STRING"
export NAMESPACE_NAME="quickstart"
export DEPLOYMENT_NAME="demo-model"
```

The `RANDOM_STRING` variable stores a random 10-digit string. The `RESOURCE_GROUP` and `MANAGER_NAME` values include it to create unique names. The `SUBSCRIPTION_ID` variable stores the ID of your current subscription. AI Manager, namespace, and model deployment names can contain only lowercase letters, numbers, and hyphens.

## Choose a model

List the catalog models that are available in your location by using the [`az aimanager model list`](/cli/azure/aimanager/model#az-aimanager-model-list) command.

```azurecli-interactive
az aimanager model list --location "$LOCATION" --output table
```

Choose a model by its readable `ModelId`. Store its matching `Name` value, which is the model's ARM resource name, in the `MODEL_NAME` variable.

```azurecli-interactive
export MODEL_NAME="<name-from-the-list>"
```

## Choose a GPU VM size

Compare GPU plans for the model by using the [`az aimanager model calculate-cost`](/cli/azure/aimanager/model#az-aimanager-model-calculate-cost) command. The calculator estimates VM cost per model replica, not the full deployment cost. For more information about GPU plans, quota, and what the estimate includes, see [Choose a model and estimate deployment cost](./estimate-cost.md).

```azurecli-interactive
az aimanager model calculate-cost --location "$LOCATION" --name "$MODEL_NAME" --output table
```

Choose a plan where `Feasible` is `True`, and store its `VmSize` value in the `VM_SIZE` variable.

```azurecli-interactive
export VM_SIZE="<vm-size-from-a-feasible-plan>"
```

## Create a resource group

Create a resource group by using the [`az group create`](/cli/azure/group#az-group-create) command.

```azurecli-interactive
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
```

## Create an AI Manager

Create an AI Manager by using the [`az aimanager create`](/cli/azure/aimanager#az-aimanager-create) command. The AI Manager provisions and manages an AKS cluster for your model deployments, so the command can take several minutes to finish.

```azurecli-interactive
az aimanager create --resource-group "$RESOURCE_GROUP" --name "$MANAGER_NAME" --location "$LOCATION"
```

## Create a namespace

Create a namespace in the AI Manager by using the [`az aimanager namespace create`](/cli/azure/aimanager/namespace#az-aimanager-namespace-create) command.

```azurecli-interactive
az aimanager namespace create --resource-group "$RESOURCE_GROUP" --aimanager "$MANAGER_NAME" --name "$NAMESPACE_NAME"
```

## Deploy a model

Create a model deployment that runs one replica by using the [`az aimanager namespace modeldeployment create`](/cli/azure/aimanager/namespace/modeldeployment#az-aimanager-namespace-modeldeployment-create) command. The command waits until the deployment is ready, which can take several minutes or longer.

```azurecli-interactive
az aimanager namespace modeldeployment create \
  --resource-group "$RESOURCE_GROUP" \
  --aimanager "$MANAGER_NAME" \
  --namespace "$NAMESPACE_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --model-resource-id "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.ContainerService/locations/$LOCATION/aiModels/$MODEL_NAME" \
  --vm-size "$VM_SIZE" \
  --replicas 1
```

Verify the deployment by using the [`az aimanager namespace modeldeployment show`](/cli/azure/aimanager/namespace/modeldeployment#az-aimanager-namespace-modeldeployment-show) command. The deployment is ready when `ProvisioningState` is `Succeeded` and `Replicas` is `1/1`. If the state is `Failed` or `Canceled`, run the command without `--output table` to inspect the full resource.

```azurecli-interactive
az aimanager namespace modeldeployment show \
  --resource-group "$RESOURCE_GROUP" \
  --aimanager "$MANAGER_NAME" \
  --namespace "$NAMESPACE_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --output table
```

## Send an inference request

Use the `RESOURCE_GROUP`, `MANAGER_NAME`, `NAMESPACE_NAME`, and `DEPLOYMENT_NAME` variables from the previous sections.

1. Get the namespace endpoint and the primary namespace API key (`primaryKey`). Keep the key secret.

    ```azurecli-interactive
    export ENDPOINT="$(az aimanager namespace list-accesskeys \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --name "$NAMESPACE_NAME" \
      --query endpoint \
      --output tsv)"

    export API_KEY="$(az aimanager namespace list-accesskeys \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --name "$NAMESPACE_NAME" \
      --query primaryKey \
      --output tsv)"
    ```

    Confirm that both values are set. The command prints a message only if neither value is empty.

    ```azurecli-interactive
    test -n "$ENDPOINT" && test -n "$API_KEY" && echo "Endpoint and key retrieved."
    ```

1. Send a chat completion request. The `model` value is the **model deployment name** (`DEPLOYMENT_NAME`), not the catalog model ID.

    ```bash
    curl "$ENDPOINT/chat/completions" \
      --header "Authorization: Bearer $API_KEY" \
      --json @- <<EOF
    {
      "model": "$DEPLOYMENT_NAME",
      "messages": [
        { "role": "user", "content": "What does Kubernetes do?" }
      ]
    }
    EOF
    ```

    A successful request returns a JSON chat completion with a response under `choices[0].message.content`. The response text varies by model. For an OpenAI-compatible Python client, see [Connect an application to a model endpoint](./connect-to-endpoint.md).

## Clean up resources

When you no longer need the resources, delete the resource group by using the [`az group delete`](/cli/azure/group#az-group-delete) command. Deleting the resource group deletes the AI Manager, its namespace and model deployment, and the AKS cluster that the AI Manager manages.

```azurecli-interactive
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```

## Next steps

- [Learn AI Manager concepts](./concepts.md).
- [Manage model deployments](./manage-deployments.md).
- [Grant access to AI Manager](./grant-access.md).
- [View the AI Manager resource reference](./reference.md).
