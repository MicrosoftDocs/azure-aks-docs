---
title: Connect an application to an AI Manager model endpoint by using an API key (preview)
description: Use an OpenAI-compatible Python client and a namespace API key to send chat completion requests.
ai-usage: ai-assisted
author: asabbour
ms.author: asabbour
ms.topic: how-to
ms.date: 10/13/2026
ms.service: azure-kubernetes-service
---

# Connect an application to an AI Manager model endpoint by using an API key (preview)

Use an OpenAI-compatible client to send requests to a model deployment through the namespace endpoint. This article uses the OpenAI Python client and a namespace API key. To use Microsoft Entra ID instead, see [Connect an application to an AI Manager model endpoint by using Microsoft Entra ID](./connect-to-endpoint-entra-id.md). For Azure RBAC role assignment, see [Grant access to AI Manager](./grant-access.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- A model deployment whose `provisioningState` is `Succeeded` and that has at least one ready replica (`currentReplicas` greater than `0`). To check readiness, see the [quickstart](./quickstart.md). For state meanings, see [Provisioning states](./reference.md#provisioning-states).
- Azure CLI with access to the AI Manager CLI extension for the public preview.
- An Azure sign-in for a subscription that contains the AI Manager.
- Python and the `openai` package.
- Permission to list namespace API keys. **Azure AIManager Inference User** grants this permission with the least privilege. **Azure AIManager User** and **Azure AIManager Contributor** also include it. Assign the role at the namespace or a parent scope.

## Get the endpoint and key

1. Set variables for your resource group, AI Manager, and namespace.

    ```azurecli-interactive
    az login
    az account set --subscription "<subscription-id>"

    export RESOURCE_GROUP="<resource-group>"
    export MANAGER_NAME="<ai-manager-name>"
    export NAMESPACE_NAME="<namespace-name>"
    ```

1. Retrieve the namespace endpoint and the primary namespace API key (`primaryKey`). The namespace also has a `secondaryKey` that works the same way.

    ```bash
    export AI_MANAGER_ENDPOINT="$(az aimanager namespace list-accesskeys \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --name "$NAMESPACE_NAME" \
      --query endpoint \
      --output tsv)"

    export AI_MANAGER_API_KEY="$(az aimanager namespace list-accesskeys \
      --resource-group "$RESOURCE_GROUP" \
      --aimanager "$MANAGER_NAME" \
      --name "$NAMESPACE_NAME" \
      --query primaryKey \
      --output tsv)"
    ```

1. Confirm that both values are set. The command prints a message only if neither value is empty.

    ```bash
    test -n "$AI_MANAGER_ENDPOINT" && test -n "$AI_MANAGER_API_KEY" && echo "Endpoint and key retrieved."
    ```

The `endpoint` value is the OpenAI-compatible base URL. Use it as returned, including any path component.

## Send a request with the OpenAI Python client

1. Install the `openai` package if it isn't already installed.

    ```bash
    python -m pip install openai
    ```

1. Set the `model` value to your model deployment name. Then use `AI_MANAGER_ENDPOINT` and `AI_MANAGER_API_KEY` from [Get the endpoint and key](#get-the-endpoint-and-key) to send a chat completion request.

    ```bash
    export AI_MANAGER_DEPLOYMENT="<model-deployment-name>"
    ```

    ```python
    import os

    from openai import OpenAI

    client = OpenAI(
        api_key=os.environ["AI_MANAGER_API_KEY"],
        base_url=os.environ["AI_MANAGER_ENDPOINT"],
    )

    response = client.chat.completions.create(
        model=os.environ["AI_MANAGER_DEPLOYMENT"],
        messages=[
            {"role": "user", "content": "What does Kubernetes do?"},
        ],
    )

    print(response.choices[0].message.content)
    ```

The request uses the following values:

- **`model` field:** The model deployment name. Don't use the model catalog's `modelId` value.
- **`Authorization: Bearer` header:** Carries the namespace API key. The OpenAI client sends it automatically.
- **`api-key` header:** Carries the namespace API key for clients that set headers directly.

A successful request prints the response text from `choices[0].message.content`. The text varies by model. For a request using `curl`, see the [AI Manager quickstart](./quickstart.md).

## Next steps

- [View the AI Manager resource reference](./reference.md).
- [Connect an application to an AI Manager model endpoint by using Microsoft Entra ID](./connect-to-endpoint-entra-id.md).
