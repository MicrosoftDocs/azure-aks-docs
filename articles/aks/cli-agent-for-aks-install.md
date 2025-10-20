---
title: Install and Use the CLI Agent for Azure Kubernetes Service (AKS) (preview)
description: Learn how to install, configure, and use the CLI Agent for AKS to troubleshoot clusters and get intelligent insights using natural language.
ms.topic: how-to
ms.date: 10/20/2025
author: aritragho
ms.author: aritragho
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to install and configure the Agentic CLI for AKS so I can start troubleshooting my clusters using natural language queries.
---

# Install and use the CLI Agent for Azure Kubernetes Service (AKS) (preview)

This article shows you how to install, configure, and use the CLI Agent for AKS to get AI-powered troubleshooting and insights for your Azure Kubernetes Service (AKS) clusters.

For more information, see [CLI Agent for Azure Kubernetes Service (AKS) overview](./cli-agent-for-aks-overview.md).

## Prerequisites

- The Azure CLI version 2.76 or higher. To verify your Azure CLI version, use the [`az version`](/cli/azure/reference-index#az-version) command.
- An LLM API key. You must bring your own API key from one of the supported providers:
  - Azure OpenAI (recommended)
  - OpenAI or other LLM providers compatible with OpenAPI specifications
- Ensure you're logged in to the proper subscription using the [`az account set`](/cli/azure/account#az-account-set) command.
- Configure access to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
    ```

- [Install the CLI Agent for AKS extension](#install-the-cli-agent-for-aks-extension).

### Install the CLI Agent for AKS extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Add the CLI Agent for AKS extension to your Azure CLI installation using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    ```azurecli-interactive
    az extension add --name aks-agent --debug
    ```

1. Verify the extension is installed using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command with the `--help` parameter.

    ```azurecli-interactive
    az aks agent --help
    ```

    Your output should display the available commands under the `az aks agent` command group.

## Set up your LLM API key

> [!NOTE]
> We recommend using newer models such as GPT-4o, GPT-4o-mini, or Claude Sonnet 4.0 for better performance. Choose a model with a high context size of at least 128,000 tokens or higher.

### [Azure OpenAI (recommended)](#tab/azure-openai)

1. Set up an Azure OpenAI resource by following the steps in [Create an Azure OpenAI in Azure AI Foundry Models resource](/azure/ai-foundry/openai/how-to/create-resource#create-a-resource).

   > [!IMPORTANT]
   > For the deployment name, use the same name as the model's name (such as `gpt-4o` or `gpt-4o-mini`) depending on access. You can use any region where you have access and quota for the model. In the deployment, select the highest possible token limit per minute (TPM). We recommend upwards of 1M TPM for good performance.

1. Deploy the model by following the steps in [Deploy an Azure OpenAI in Azure AI Foundry Models resource](/azure/ai-foundry/openai/how-to/create-resource#deploy-a-model).
1. Set environment variables with your API base URL and API key, as shown in the following examples:

    ```bash
    # Linux/Mac
    export AZURE_API_BASE="https://<your-endpoint>.openai.azure.com/"
    export AZURE_API_VERSION="2025-04-01-preview"
    export AZURE_API_KEY="<your-api-key>"

    # Windows
    $env:AZURE_API_VERSION="2025-04-01-preview"
    $env:AZURE_API_BASE="https://<your-endpoint>.openai.azure.com"
    $env:AZURE_API_KEY="<your-api-key>"
    ```

    > [!NOTE]
    > - The API version isn't the model version. You can use any available and supported API version.
    > - The Azure API Base refers to the Azure OpenAI endpoint, not the target URI of the deployment in Azure AI Foundry.
    > - You must specify the model when using Azure OpenAI using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command with the `--model` parameter.

### [Other supported providers](#tab/other-providers)

1. Step 1?
1. Steps 2?
1. Set environment variables with your API base URL and API key, as shown in the following examples:

    ```bash
    # OpenAI
    export OPENAI_API_KEY="<your-openai-api-key>"
    
    # Anthropic
    export ANTHROPIC_API_KEY="<your-anthropic-api-key>"
    
    # Gemini
    export GEMINI_API_KEY="<your-gemini-api-key>"
    
    # Ollama
    export OLLAMA_API_BASE="<your-ollama-api-key>"
    ```

We also support any OpenAI compatible model. For other LLM providers, contact [Microsoft support](https://support.microsoft.com) for assistance.

## Use the CLI Agent for AKS

You can now start using the CLI Agent for AKS to troubleshoot your clusters and get intelligent insights using natural language queries. The following sections outline key parameters and example queries to get you started.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `--api-key` | API key to use for the LLM (if not given, uses environment variables `AZURE_API_KEY`, `OPENAI_API_KEY`). |
| `--config-file` | Path to configuration file. Default: `/Users/<>/.azure/aksAgent.config`. |
| `--max-steps` | Maximum number of steps the LLM can take to investigate the issue. Default: _10_. |
| `--model` | Model to use for the LLM. |
| `--name`, `-n` | Name of the managed cluster. |
| `--no-echo-request` | Disable echoing back the question provided to AKS Agent in the output. |
| `--no-interactive` | Disable interactive mode. When set, the agent doesn't prompt for input and runs in batch mode. |
| `--refresh-toolsets` | Refresh the toolsets status. |
| `--resource-group`, `-g` | Name of the resource group. |
| `--show-tool-output` | Show the output of each tool that was called during the analysis. |

### Model specification

The `--model` parameter determines which LLM and provider analyzes your cluster.

- **For OpenAI**, use the model name directly (for example, `gpt-4o`).
- **For Azure OpenAI**, use `azure/<deployment name>` (for example, `azure/gpt-4o`).
- **For Anthropic**, use `anthropic/claude-sonnet-4`.

### Configuration file

You can specify common parameters in a config file rather than specifying them every time. The following parameters are supported in the config file:

- Model
- API key  
- Custom toolsets
- Azure environment variables

You can use your config file by specifying the `--config-file` parameter with the path to your config file when using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command.

```azurecli-interactive
az aks agent "Check kubernetes pod resource usage" --config-file exampleconfig.yaml
```

### Basic queries

You can use the following example queries to get started with the CLI Agent for AKS:

```azurecli-interactive
az aks agent "How many nodes are in my cluster?" --model=azure/gpt-4o
az aks agent "What is the Kubernetes version on the cluster?" --model=azure/gpt-4o
az aks agent "Why is coredns not working on my cluster?" --model=azure/gpt-4o
az aks agent "Why is my cluster in a failed state?" --model=azure/gpt-4o
```

By default, the experience uses interactive mode where you can continue asking questions with retained context until you want to exit. To quit the experience, type `/exit`.

### Interactive commands

The `az aks agent` has a set of subcommands that aid the troubleshooting experience. You can access them by typing `/` inside the interactive mode experience:

| Command | Description |
|---------|-------------|
| `/exit` | Exit interactive mode. |
| `/help` | Show help message with all commands. |
| `/clear` | Clear screen and reset conversation context. |
| `/tools` | Show available toolsets and their status. |
| `/auto` | Toggle auto-display of tool outputs after responses. |
| `/last` | Show all tool outputs from last response. |
| `/run` | Run a bash command and optionally share with LLM. |
| `/shell` | Drop into interactive shell, then optionally share session with LLM. |
| `/context` | Show conversation context size and token count. |
| `/show` | Show specific tool output in scrollable view. |

### Disable interactive mode

To opt out of the default interactive mode, use the `--no-interactive` flag. For example:

```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --model=azure/gpt-4o --no-interactive --show-tool-output
```

### Toolsets

The CLI Agent for AKS includes pre-built integrations for popular monitoring and observability tools through toolsets. Some integrations work automatically with Kubernetes, while others require API keys or configuration.

For AKS, there are specific toolsets that help with the troubleshooting experience. These toolsets appear in the output at the start of the experience:

```output
...
✅ Toolset kubernetes/kube-prometheus-stack
✅ Toolset internet
✅ Toolset bash
✅ Toolset runbook
✅ Toolset kubernetes/logs
✅ Toolset kubernetes/core
✅ Toolset kubernetes/live-metrics
✅ Toolset aks/core
✅ Toolset aks/node-health
Using 37 datasources (toolsets). To refresh: use flag `--refresh-toolsets`
```

## AKS MCP server integration

You have an option to integrate with AKS MCP server. In this mode, the AKS MCP server is run locally and the CLI Agent for AKS uses the MCP server tools to drive all the insights rather than the default toolsets.

To check the status of the MCP server, you can use the `--status` flag:

```azurecli-interactive
az aks-agent --status
```

## Remove the CLI Agent for AKS extension

- Remove the CLI Agent for AKS extension using the [`az extension remove`](/cli/azure/extension#az-extension-remove) command.

    ```azurecli-interactive
    az extension remove --name aks-agent --debug
    ```

## Next steps

- For an overview of the CLI Agent for AKS, see [About the CLI Agent for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-overview.md).
- To troubleshoot any issues with the CLI Agent for AKS, see [Troubleshoot the CLI Agent for AKS](./cli-agent-for-aks-troubleshoot.md).
- [CLI Agent for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.md) answers common questions about the CLI Agent for AKS.
