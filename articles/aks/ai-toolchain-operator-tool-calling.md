---
title: Configure Tool Calling with an AI Inference Service using the AI Toolchain Operator on Azure Kubernetes Service (AKS)
description: Learn how to deploy an AI inference service that supports tool calling in Azure Kubernetes Service (AKS) by using the managed add-on for KAITO.
ms.topic: how-to
ms.author: sachidesai
author: sachidesai
ms.service: azure-kubernetes-service
ms.date: 10/1/2025
# Customer intent: As an AI app developer, I want to integrate tool calling with inference services on Azure Kubernetes Service (AKS), so that my LLM-powered applications can dynamically interact with external APIs and perform real-world tasks at scale in a secure, reliable, and maintainable manner."
---

# Integrate tool calling with LLM Inference with the AI toolchain operator add-on on Azure Kubernetes Service (AKS)

In this article, you configure and deploy an AI toolchain operator (KAITO) inference workspace on Azure Kubernetes Service (AKS) with support for OpenAI-style tool calling. You also learn how to validate tool calling functionality using vLLM metrics and local function mocks.

## What is tool calling?

Tool calling enables large language models (LLMs) to interface with external functions, APIs, or services. Instead of just generating text, an LLM can decide:

- "I need to call a weather API."
- "I need to use a calculator."
- "I should search a database."

It does this by invoking a defined “tool” with parameters it chooses based on the user’s request. Tool calling is useful for:

- Chatbots that book, summarize, or calculate.
- Enterprise LLM applications where hallucination must be minimized.
- Agent frameworks (AutoGen, LangGraph, LangChain, AgentOps, etc.).

In production environments, AI-enabled applications often demand more than natural language generation; they require the ability to take action based on user intent. Tool calling empowers LLMs to extend beyond text responses by invoking external tools, APIs, or custom logic in real time. This bridges the gap between language understanding and execution, enabling developers to build interactive AI assistants, agents, and automation workflows that are both accurate and useful. Instead of relying on static responses, LLMs can now access live data, trigger services, and complete tasks on behalf of users, both safely and reliably.

When deployed on AKS, tool calling becomes scalable, secure, and production ready. Kubernetes provides the flexibility to orchestrate inference workloads using high-performance runtimes like vLLM, while ensuring observability and governance of tool usage. With this pattern, AKS operators and app developers can more seamlessly update models or tools independently and deploy advanced AI features without compromising reliability. 

As a result, tool calling on AKS is now a foundational pattern for building modern AI apps that are context-aware, action-capable, and enterprise-ready.

### Tool calling with KAITO

To streamline this deployment model, the AI toolchain operator (KAITO) add-on for AKS provides a managed solution for running inference services with [tool calling support](https://kaito-project.github.io/kaito/docs/tool-calling/). By leveraging KAITO inference workspaces, you can quickly spin up scalable, GPU-accelerated model endpoints with built-in support for tool calling and OpenAI-compatible APIs. This eliminates the operational overhead of configuring runtimes, managing dependencies, or scaling infrastructure manually.

## Prerequisites

- This article assumes that you have an existing AKS cluster. If you don't have a cluster, create one by using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- Your AKS cluster is running on Kubernetes version `1.33` or higher. To upgrade your cluster, see [Upgrade your AKS cluster](./upgrade-aks-cluster.md).
- Install and configure Azure CLI version `2.77.0` or later. To find your version, run `az --version`. To install or update, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- The [AI toolchain operator add-on enabled](./ai-toolchain-operator.md) on your cluster.
- A deployed KAITO inference workspace that supports tool calling. Refer to the official [KAITO tool calling](https://kaito-project.github.io/kaito/docs/tool-calling/) documentation for the tool calling supported models with vLLM.
- You deployed the `workspace‑phi‑4-mini-toolcall` [KAITO workspace](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_tool_calling.yaml) with the default configuration.

## Confirm that the KAITO inference workspace is running

This tutorial assumes that you have deployed the `workspace‑phi‑4-mini-toolcall` [KAITO workspace](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_tool_calling.yaml) with default configuration.

Monitor workspace deployment with the following command:

```bash
kubectl get workspace workspace‑phi‑4‑mini-toolcall -w
```

You want to see that all 3 conditions become ready: `ResourceReady`, `InferenceReady`, and eventually `WorkspaceSucceeded` being `true`.

### Confirm the Inference API is Ready to Serve

Once the workspace is ready, find the service endpoint:

```bash
kubectl get svc workspace‑phi‑4-mini-toolcall
```

> [!NOTE]
> The output may be a `ClusterIP` or internal address. Check which port(s) the service listens on; default KAITO inference API is on port `80` for HTTP. If it is only internal, you can port‑forward locally:

```bash
kubectl port-forward svc/workspace‑phi‑4‑mini-toolcall 8000:80
```

Also check `/v1/models` endpoint to confirm that LLM is available:

```bash
curl http://localhost:8000/v1/models
```

To ensure the LLM is deployed and API is working, your output should be similar to the following:

```bash
...
{
  "object": "list",
  "data": [
    {
      "id": "phi‑4‑mini‑instruct",
      ...
      ...
    }
  ]
}
...
``` 

## Test the Named Function Tool‐Calling

In this example, the `workspace‑phi‑4‑mini-toolcall` workspace supports named function tool-calling by default, so we can confirm that the LLM accepts a “tool” spec in OpenAI‑style requests, and returns back a “function call” structure.

Below is a simple Python snippet from [KAITO documentation](https://kaito-project.github.io/kaito/docs/tool-calling/#examples) using an OpenAI‑compatible client:

```python
from openai import OpenAI
import json

# local server
client = OpenAI(base_url="http://localhost:8000/v1", api_key="dummy")

def get_weather(location: str, unit: str) -> str:
    return f"Getting the weather for {location} in {unit}..."

tool_functions = {"get_weather": get_weather}

tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {"type": "string"},
                "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
            },
            "required": ["location", "unit"]
        }
    }
}]

response = client.chat.completions.create(
    model="phi‑4‑mini‑instruct",   # or client.models.list().data[0].id
    messages=[{"role": "user", "content": "What's the weather like in San Francisco?"}],
    tools=tools,
    tool_choice="auto"
)

# Inspect response
tool_call = response.choices[0].message.tool_calls[0].function
args = json.loads(tool_call.arguments)
print("Function called:", tool_call.name)
print("Arguments:", args)
print("Result:", tool_functions[tool_call.name](**args))
```

In the above example, we:

* Initialize the OpenAI-compatible client to talk to a local inference server. The server is assumed to be running at http://localhost:8000/v1 and accepts OpenAI-style API calls.
* Simulate the backend logic for a tool called get_weather. (In a real scenario, this would call a weather API)
* Describe the tool interface - the `Phi-4-mini` LLM will see this tool and decide whether to use it based on the user's input.
* Send a sample chat message to the model and provides the tool spec. The setting `tool_choice="auto"` allows the LLM to decide if it should call a tool based on the prompt.
* In this case, the user's request was relevant to the `get_weather` tool, so we simulate the execution of the tool, calling the local function with the model's chosen arguments.

Your output should look similar to the following:

```python
Function called: get_weather  
Arguments: {"location": "San Francisco, CA", "unit": "fahrenheit"}  
Result: Getting the weather for San Francisco, CA in fahrenheit...
```

The “tool_calls” field comes back, meaning the `Phi-4-mini` LLM decided to invoke the function. Now, a sample tool call has been successfully parsed and executed based on the model’s decision to confirm end-to-end tool calling behavior with the KAITO inference deployment.

## Monitor Tool Calling with AI Toolchain Operator

To understand the effectiveness of tool calling when using vLLM inference in KAITO, you can monitor specific vLLM inference metrics exposed via the KAITO `/metrics` endpoint. These metrics provide visibility into how often tool calling is used, how well it's performing, and whether tool calling improves the responsiveness and accuracy of your AI-enabled application. Relevant tool calling vLLM metrics include:

* `vllm_tool_call_count`: High counts indicate that tool calling is actively used and invoked by the LLM in response to user inputs.
* `vllm_tool_call_success_count`: Compare successful tool executions with total tool calls to understand tool call reliability or failure rate.
* `vllm_tool_call_latency_seconds`:	Track the time taken to generate tool calls for performance bottlenecks to help identify if tools are causing slow inference.
* `vllm_tool_choice_rate{name="auto"}`: Frequency of "auto" tool choice usage can confirm whether the model is autonomously choosing to use tools (versus forced invocation).
* `vllm_function_call_parse_error_total`: High quantity of failed or malformed tool call parses indicate schema mismatch, LLM hallucination, or function description issues.
* `vllm_completion_tokens_total`: Compare token count(with and without tool calling) generation lengths, as tool usage may reduce tokens needed per response if external logic is used.

## Access Tool Calling Metrics in KAITO

### Prometheus/Grafana Dashboards: 

If KAITO is set up with monitoring, vLLM exposes metrics via Prometheus. You can scrape and visualize them in Grafana.

Port forward to the KAITO `/metrics` endpoint: You can access the raw metrics from the inference service:

```bash
kubectl port-forward svc/<workspace-service-name> 8000:80
curl http://localhost:8000/metrics
```

Azure Monitor Integration: If you’ve configured Azure Monitor for your AKS cluster, you can ingest these metrics for long-term analysis and alerting.

## Tool Calling Observability Recommendations

### Measure Tool Calling Usage

Monitor `vllm_tool_call_count` vs. `total completions` to understand how frequently tool calling is being triggered. This shows whether your LLM is identifying relevant tasks for tool invocation.

### Assess Tool Execution Reliability

Track `vllm_tool_call_success_count` alongside errors like `vllm_function_call_parse_error_total`. A high failure rate might indicate malformed tool specifications, incorrect parameter handling, or LLM misunderstanding.

### Evaluate Inference Performance Impact

Use `vllm_tool_call_latency_seconds` and overall latency metrics to analyze the cost of tool calling on response time. This helps optimize tool server performance or decide when to inline results.

### Understand Model Autonomy

Check `vllm_tool_choice_rate{name="auto"}` to see how often the LLM is autonomously choosing tools, which is a sign of effective prompting and integration with the tool calling interface.

Monitoring the metrics specific to tool calling with LLM inference allows you to:

* Quantify the value tool calling adds to your app (e.g., more accurate or actionable responses).
* Detect tool call failures early, before they affect production behavior.
* Optimize for performance, reliability, and cost, especially when tools are external APIs or slow-running services.

## Troubleshooting

### Model preset doesn’t support tool calling: 

If you pick a model not on the supported list, tool calling may not work. KAITO docs explicitly list which presets do. (Kaito Project)

### Misaligned runtime

KAITO inference must be using vLLM runtime for tool calling (transformers runtime generally doesn’t support tool calling in KAITO). (Kaito Project)

### Network / endpoint issues

If port forwarding, ensure service ports are correctly forwarded. If MCP server unreachable, will error out.

### Timeouts

MCP server calls might take time; make sure the adapter / client timeout is sufficiently high.

### Authentication

If the MCP server requires auth (API key, header, etc.), ensure you supply correct credentials.

## Next Steps

* Set up [vLLM monitoring in the AI toolchain operator add-on](./ai-toolchain-operator-monitoring.md) with Prometheus and Grafana on AKS.
* Learn about [MCP server support with KAITO](./ai-toolchain-operator-mcp.md) and test standardized tool calling examples on your AKS cluster.

<!-- Links -->

[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md