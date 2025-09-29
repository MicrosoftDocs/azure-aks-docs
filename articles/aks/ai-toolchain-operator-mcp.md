---
title: Integrate an MCP Server with the AI Toolchain Operator on Azure Kubernetes Service (AKS)
description: Learn how to connect an AI inference service with MCP in Azure Kubernetes Service (AKS) by using the managed add-on for KAITO.
ms.topic: how-to
ms.author: sachidesai
author: sachidesai
ms.service: azure-kubernetes-service
ms.date: 10/1/2025
# Customer intent: As an application developer, I want to integrate MCP-compliant tools with KAITO inference service(s) on an AKS cluster, so that my LLM-powered applications can securely and reliably invoke external APIs and services through standardized tool calling at scale."
---

# Integrate an MCP server and LLM Inference on Azure Kubernetes Service (AKS) with the AI toolchain operator add-on

In this article, you connect an MCP-compliant tool server with an AI toolchain operator (KAITO) inference workspace on Azure Kubernetes Service (AKS), enabling secure and modular tool calling for LLM applications. You also learn how to validate end-to-end tool invocation by integrating the model with the MCP server and monitoring real-time function execution through structured responses.

## Model Context Protocol (MCP)

As an extension of [KAITO inference with tool calling](./ai-toolchain-operator-tool-calling.md), the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) provides a standardized way to define and expose tools for language models to call. 

Tool calling with MCP makes it easier to connect language models to real services and actions without tightly coupling logic into the model itself. Instead of embedding every function or API call into your application code, MCP lets you run a standalone tool server that exposes standardized tools or APIs that any compatible LLM can use. This clean separation means you can update tools independently, share them across models, and manage them like any other microservice.

You can bring-your-own (BYO) internal or connect external MCP servers seamlessly with your KAITO inference workspace on AKS. 

## MCP with AI toolchain operator (KAITO) on AKS

You can register an external MCP server in a uniform, schema-driven format and serve it to any compatible inference endpoint, including those [deployed with a KAITO workspace](https://kaito-project.github.io/kaito/docs/tool-calling/#model-context-protocol-mcp). This approach allows for externalizing business logic, decoupling model behavior from tool execution, and reusing tools across agents, models, and environments.

In this guide, you register a pre-defined MCP server, test real calls issued by an LLM running in a KAITO inference workspace, and confirm the entire tool execution path (from model prompt to MCP function invocation) works as intended. You have flexibility to scale or swap tools independent of your model.

## Prerequisites

- This article assumes that you have an existing AKS cluster. If you don't have a cluster, create one by using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- Your AKS cluster is running on Kubernetes version `1.33` or higher. To upgrade your cluster, see [Upgrade your AKS cluster](./upgrade-aks-cluster.md).
- Install and configure Azure CLI version `2.77.0` or later. To find your version, run `az --version`. To install or update, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- You have the [AI toolchain operator add-on enabled](./ai-toolchain-operator.md) on your cluster and a [KAITO workspace with tool calling support](./ai-toolchain-operator-tool-calling.md) deployed on your cluster.
- An external MCP server available at an accessible URL (e.g., `https://mcp.example.com/mcp`) that returns valid `/list_tools` and has `stream` transport.

## Connect to a reference MCP server

In this example, we'll use a reference [Time MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/time#time-mcp-server), which provides time zone conversion capabilities and enables LLMs to get current time information and perform conversions using standardized names.

## Port-forward the KAITO inference service

1. Confirm that your KAITO workspace is ready and retrieve the inference service endpoint using the `kubectl get` command.

    ```bash
    kubectl get svc workspace‑phi‑4-mini-toolcall
    ```

    > [!NOTE]
    > The output might be a `ClusterIP` or internal address. Check which port(s) the service listens on. The default KAITO inference API is on port `80` for HTTP. If it's only internal, you can port‑forward locally.

2. Port-forward the inference service for testing using the `kubectl port-forward` command.

    ```bash
    kubectl port-forward svc/workspace‑phi‑4‑mini-toolcall 8000:80
    ```

3. Check `/v1/models` endpoint to confirm that `Phi-4-mini-instruct` LLM is available using `curl`.

    ```bash
    curl http://localhost:8000/v1/models
    ```

    Your `Phi-4-mini-instruct` OpenAI-compatible inference API will be available at:

    ```output
    http://localhost:8000/v1/chat/completions
    ```

### Confirm the Reference MCP Server is Valid

This example assumes that the Time MCP server is hosted at `https://mcp.example.com`.  Run the following `curl` command to confirm that it returns tools:

```bash
curl https://mcp.example.com/mcp/list_tools
```

Expected output:

```json
{
  "tools": [
    {
      "name": "get_current_time",
      "description": "Get the current time in a specific timezone",
      "arguments": {
        "timezone": "string"
      }
    },
    {
      "name": "convert_time",
      "description": "Convert time between two timezones",
      "arguments": {
        "source_timezone": "string",
        "time": "string",
        "target_timezone": "string"
      }
    }
  ]
}
```

### Connect MCP Server to the KAITO Workspace Using API

KAITO automatically fetches tool definitions from **tools declared in API requests** or registered dynamically inside the inference runtime (vLLM + MCP tool loader).

We'll create a Python virtual environment to send a tool-calling request to the `Phi-4-mini-instruct` inference endpoint using the MCP definition and pointing to the server.

Define a new working directory for this test project:

```bash
mkdir kaito-mcp
cd kaito-mcp
```

Create a Python virtual environment and activate it so that all packages are local to your test project:

```bash
uv venv
source .venv/bin/activate
```

Use the open-source [Autogen](https://microsoft.github.io/autogen/stable//index.html) framework to test the tool calling functionality and install its dependencies:

```bash
uv pip install "autogen-ext[openai]" "autogen-agentchat" "autogen-ext[mcp]"
```

4. Create a test file named `test.py` that:

    - Connects to the Time MCP server and loads `get_current_time` tool.
    - Connects to your KAITO inference service running at `localhost:8000`.
    - Sends an example query like “What time is it in Europe/Paris?”
    - Enables automatic selection and calling of the `get_current_time` tool.

    ```python
    import asyncio

    from autogen_agentchat.agents import AssistantAgent
    from autogen_agentchat.ui import Console
    from autogen_core import CancellationToken
    from autogen_core.models import ModelFamily, ModelInfo
    from autogen_ext.models.openai import OpenAIChatCompletionClient
    from autogen_ext.tools.mcp import (StreamableHttpMcpToolAdapter,
                                    StreamableHttpServerParams)
    from openai import OpenAI


    async def main() -> None:
        # Create server params for the Time MCP service
        server_params = StreamableHttpServerParams(
            url="https://mcp.example.com/mcp",
            timeout=30.0,
            terminate_on_close=True,
        )

        # Load the get_current_time tool from the server
        adapter = await StreamableHttpMcpToolAdapter.from_server_params(server_params, "get_current_time")

        # Fetch model name from KAITO's local OpenAI-compatible API
        model = OpenAI(base_url="http://localhost:8000/v1", api_key="dummy").models.list().data[0].id

        model_info: ModelInfo = {
            "vision": False,
            "function_calling": True,
            "json_output": True,
            "family": ModelFamily.UNKNOWN,
            "structured_output": True,
            "multiple_system_messages": True,
        }

        # Connect to the KAITO inference workspace
        model_client = OpenAIChatCompletionClient(
            base_url="http://localhost:8000/v1",
            api_key="dummy",
            model=model,
            model_info=model_info
        )

        # Define the assistant agent
        agent = AssistantAgent(
            name="time-assistant",
            model_client=model_client,
            tools=[adapter],
            system_message="You are a helpful assistant that can provide time information."
        )

        # Run a test task that invokes the tool
        await Console(
            agent.run_stream(
                task="What time is it in Europe/Paris?",
                cancellation_token=CancellationToken()
            )
        )

    if __name__ == "__main__":
        asyncio.run(main())
    ```

5. Run the test script in your virtual environment.

    ```bash
    uv run test.py
    ```

    In the output of this test, you should expect the following:

    - The model correctly generates a tool call using the MCP name and expected arguments.
    - Autogen sends the tool call to the MCP server, the MCP server runs the logic and returns a result.
    - The `Phi-4-mini-instruct` LLM interprets the raw tool output and provides a natural language response.

    ```output
    ---------- TextMessage (user) ----------
    What time is it in Europe/Paris?
    
    ---------- ToolCallRequestEvent (time-assistant) ----------
    [FunctionCall(id='chatcmpl-tool-xxxx', arguments='{"timezone": "Europe/Paris"}', name='get_current_time')]
    
    ---------- ToolCallExecutionEvent (time-assistant) ----------
    [FunctionExecutionResult(content='{"timezone":"Europe/Paris","datetime":"2025-09-17T17:43:05+02:00","is_dst":true}', name='get_current_time', call_id='chatcmpl-tool-xxxx', is_error=False)]
    
    ---------- ToolCallSummaryMessage (time-assistant) ----------
    The current time in Europe/Paris is 5:43 PM (CEST).
    ```

## Experiment with more MCP tools

You can test the various tools available to this MCP server, such as `convert_time`.

1. In your `test.py` file from the previous step, update your `adapter` definition to the following:

    ```python
    adapter = await StreamableHttpMcpToolAdapter.from_server_params(server_params, "convert_time")
    ```

2. Update your `task` definition to invoke the new tool. For example:

    ```bash
    task="Convert 9:30 AM New York time to Tokyo time."
    ```

3. Save and run the Python script.

    ```bash
    uv run test.py
    ```

    Expected output:

    ```output
    9:30 AM in New York is 10:30 PM in Tokyo.
    ```

## Troubleshooting

The following table outlines common errors when testing KAITO inference with an external MCP server and how to resolve them:

| Error | How to resolve |
| ----- | ----------------- |
| `Tool not found` | Ensure that your tool name matches the one declared in `/mcp/list_tools`. |
| `401 Unauthorized` | If your MCP server requires an Auth token, make sure to update `server_params` to include headers with the Auth token. |
| `connection refused` | Ensure the KAITO inference service is port-forwarded properly (e.g. to `localhost:8000`). |
| `tool call ignored` | Review the [KAITO tool calling documentation](https://kaito-project.github.io/kaito/docs/tool-calling/#supported-models) to find vLLM models that support tool calling. |

## Next steps

In this article, you learned how to connect a KAITO workspace to an external reference MCP server using Autogen to enable tool calling through the OpenAI-compatible API. You also validated that the LLM could discover, invoke, and integrate results from MCP-compliant tools on AKS. To learn more, see the following resources:

- [Deploy and monitor tool calls](./ai-toolchain-operator-tool-calling.md) with the AI toolchain operator add-on on AKS.
- KAITO tool calling and [MCP official documentation](https://kaito-project.github.io/kaito/docs/tool-calling).

<!-- Links -->

[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md