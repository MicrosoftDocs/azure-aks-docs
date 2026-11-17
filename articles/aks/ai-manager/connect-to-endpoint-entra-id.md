---
title: Connect an application to an AI Manager model endpoint by using Microsoft Entra ID (preview)
description: Use a Microsoft Entra ID token and an OpenAI-compatible client to send chat completion requests to an AI Manager model deployment.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: how-to
ms.date: 10/20/2026
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
---

# Connect an application to an AI Manager model endpoint by using Microsoft Entra ID (preview)

Use a Microsoft Entra ID token instead of a namespace API key to send requests to a model deployment through the namespace endpoint. Azure role assignments control access, so you don't need to store or rotate API keys. This article shows how to send a request with `curl` and with the OpenAI Python client.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- A model deployment whose `provisioningState` is `Succeeded`. To check the state, see [Manage model deployments](./manage-deployments.md).
- The AI Manager extension for the Azure CLI. To install it or update an older version, run `az extension add --name aimanager --upgrade --allow-preview true`.
- The **Azure AIManager Inference User** role for the user or application that sends requests, at the namespace scope or at the AI Manager scope to cover all its namespaces. This role grants the inference data action that Microsoft Entra ID requests require. **Azure AIManager User** and **Azure AIManager Contributor** don't grant it. To assign the role, see [Grant access to AI Manager](./grant-access.md).
- For the Python example, Python and the `openai` and `azure-identity` packages.

## Get the endpoint

1. Sign in with the account that has the **Azure AIManager Inference User** role, and select the subscription that contains the AI Manager. The token must come from that subscription's Microsoft Entra tenant.

    ```azurecli-interactive
    az login
    az account set --subscription "<subscription-id>"
    ```

1. Set variables for your resources.

    ```azurecli-interactive
    export RESOURCE_GROUP="<resource-group>"
    export MANAGER_NAME="<ai-manager-name>"
    export NAMESPACE_NAME="<namespace-name>"
    export DEPLOYMENT_NAME="<model-deployment-name>"
    ```

1. Get the namespace endpoint by using the [`az aimanager namespace list-accesskeys`][az-aimanager-namespace-list-accesskeys] command. The command also returns the namespace API keys, and the `--query` option keeps only the endpoint.

    ```azurecli-interactive
    export ENDPOINT=$(az aimanager namespace list-accesskeys \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --name "$NAMESPACE_NAME" \
      --query endpoint \
      --output tsv)
    ```

## Send a request with curl

1. Get an access token by using the [`az account get-access-token`][az-account-get-access-token] command. By default, the command returns a token for Azure Resource Manager (`https://management.core.windows.net/`), which is the audience that the endpoint accepts.

    ```azurecli-interactive
    export ACCESS_TOKEN=$(az account get-access-token --query accessToken --output tsv)
    ```

1. Send a chat completion request. Set the `model` field to the model deployment name, not the catalog model ID.

    ```azurecli-interactive
    curl "$ENDPOINT/chat/completions" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --json @- <<EOF
    {
      "model": "$DEPLOYMENT_NAME",
      "messages": [
        { "role": "user", "content": "What does Kubernetes do?" }
      ]
    }
    EOF
    ```

    A successful request returns a JSON chat completion with the response under `choices[0].message.content`.

## Send a request with the OpenAI Python client

1. Install the `openai` and `azure-identity` packages.

    ```azurecli-interactive
    python -m pip install openai azure-identity
    ```

1. Get a token with `DefaultAzureCredential`, and pass it to the OpenAI client as the API key. On your computer, `DefaultAzureCredential` uses your Azure CLI sign-in. In Azure, it can use a managed identity that has the **Azure AIManager Inference User** role.

    ```python
    import os

    from azure.identity import DefaultAzureCredential
    from openai import OpenAI

    credential = DefaultAzureCredential()
    token = credential.get_token("https://management.core.windows.net//.default")

    client = OpenAI(
        api_key=token.token,
        base_url=os.environ["ENDPOINT"],
    )

    response = client.chat.completions.create(
        model=os.environ["DEPLOYMENT_NAME"],
        messages=[
            {"role": "user", "content": "What does Kubernetes do?"},
        ],
    )

    print(response.choices[0].message.content)
    ```

Access tokens expire, typically after about an hour. In a long-running application, get a new token before the current one expires, and create a new client with it.

## Troubleshoot authentication

If the endpoint rejects the request, check the following:

- **Token audience:** Get the token for `https://management.core.windows.net/`. A token for another resource, such as `https://management.azure.com/`, isn't accepted.
- **Tenant:** Get the token from the Microsoft Entra tenant of the subscription that contains the AI Manager.
- **Role assignment:** Confirm that the caller has **Azure AIManager Inference User** at the namespace or a parent scope. A new role assignment can take several minutes to take effect.

## Next steps

- [Connect an application to an AI Manager model endpoint by using an API key](./connect-to-endpoint.md).
- [Grant access to AI Manager](./grant-access.md).
- [View the AI Manager resource reference](./reference.md).

<!-- LINKS -->
[az-aimanager-namespace-list-accesskeys]: /cli/azure/aimanager/namespace#az-aimanager-namespace-list-accesskeys
[az-account-get-access-token]: /cli/azure/account#az-account-get-access-token
