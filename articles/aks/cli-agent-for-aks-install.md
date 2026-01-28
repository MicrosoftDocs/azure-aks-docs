---
title: Install and Use the Agentic CLI for Azure Kubernetes Service (AKS) (Preview)
description: Learn how to install, configure, and use the agentic CLI for AKS to troubleshoot clusters and get intelligent insights by using natural language.
ms.topic: how-to
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to install and configure the agentic CLI for AKS so that I can start troubleshooting my clusters by using natural language queries.
---

# Install and use the agentic CLI for Azure Kubernetes Service (AKS) (preview)

This article shows you how to install, configure, and use the agentic CLI for Azure Kubernetes Service (AKS) to get AI-powered troubleshooting and insights for your AKS clusters.

For more information, see the [agentic CLI for AKS overview](./cli-agent-for-aks-overview.md).

## Prerequisites

- Use the Azure CLI version 2.76 or later. To verify your Azure CLI version, use the [`az version`](/cli/azure/reference-index#az-version) command.
- Have a large language model (LLM) API key. You must bring your own API key from one of the supported providers:
  - Azure OpenAI (recommended).
  - OpenAI or other LLM providers compatible with OpenAPI specifications.
- Ensure that you're signed in to the proper subscription by using the [`az account set`](/cli/azure/account#az-account-set) command.
- Configure access to your AKS cluster by using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your AKS cluster's resource group and name.

    ```azurecli-interactive
    az aks get-credentials --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --overwrite-existing
    ```

- [Install the agentic CLI for AKS extension](#install-the-agentic-cli-for-aks-extension).

### Install the agentic CLI for AKS extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Add the agentic CLI for AKS extension to your Azure CLI installation by using the [`az extension add`](/cli/azure/extension#az-extension-add) command. If the extension is already installed, you can update to the latest version with the [`az extension update`](/cli/azure/extension#az-extension-update) command. This step might take 5 to 10 minutes to complete.

    ```azurecli-interactive
    # Install the extension
    az extension add --name aks-agent --debug

    # Update the extension
    az extension update --name aks-agent --debug
    ```

1. Verify that the installation was successful by using the [`az version`](/cli/azure/reference-index#az-version) command.

    ```azurecli-interactive
    az extension list
    ```

    Your output should include an entry for `aks-agent`.

1. Verify that the extension is installed by using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command with the `--help` parameter.

    ```azurecli-interactive
    az aks agent --help
    ```

    Your output should show the `aks-agent` with its version information in the `extensions` section, as shown in the following condensed example output:

    ```output
    ...
    "extensions": {
    "aks-agent": "1.0.0b1",
    }
    ```

## Set up your LLM API key

We recommend that you use newer models such as GPT-4o, GPT-4o-mini, or Claude Sonnet 4.0 for better performance. Choose a model with a high context size of at least 128,000 tokens or higher.

### Azure OpenAI (recommended)

Set up an Azure OpenAI resource by following the steps in the [Microsoft documentation](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal).

> [!NOTE]
> For the deployment name, use the same name as the model name, such as gpt-4o or gpt-4o-mini, depending on the access. You can use any region where you have access and quota for the model.
> In the deployment, select a token-per-minute (TPM) limit as high as possible. We recommend upward of a 1-million TPM for good performance.
1. [Deploy the model](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal#deploy-a-model) that you plan to use in the Microsoft Foundry portal.
1. After deployment is finished, note your API base URL and API key.<br>

   <img width="1713" height="817" alt="image" src="https://github.com/user-attachments/assets/400021fd-5604-4cd2-9faf-407145c52669" />

The API version isn't the model version. You can use any API version that's available and supported on [this webpage](/azure/ai-foundry/openai/api-version-lifecycle).

The Azure API base refers to the Azure OpenAI endpoint (which usually ends in `openai.azure.com/`), not the target URI of the deployment in Foundry.

### Other LLM providers

We also support any OpenAI-compatible model. Check the documentation of the LLM provider for instructions on how to create an account and retrieve the API key.

## Initialize the agentic CLI for AKS

1. Initialize the agentic CLI for AKS by using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. This command sets up the necessary configurations and toolsets for the agent. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your AKS cluster's resource group and name.

    ```azurecli-interactive
    az aks agent-init --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME>
    ```

1. Select your LLM provider, and enter LLM details when prompted. For example:

    ```output
    Welcome to AKS Agent LLM configuration setup. Type '/exit' to exit.
     1. Azure Open AI
     2. openai
     3. anthropic
     4. gemini
     5. openai_compatible
    Enter the number of your LLM provider: 1
    Your selected provider: azure
    Enter value for MODEL_NAME:  (Hint: should be consistent with your deployed name, e.g., gpt-4.1) gpt-4.1
    Enter your API key: 
    Enter value for AZURE_API_BASE:  (Hint: https://{your-custom-endpoint}.openai.azure.com/) https://test-example.openai.azure.com
    Enter value for AZURE_API_VERSION:  (Default: 2025-04-01-preview)
    LLM configuration setup successfully.
    ```

    The API key appears empty as you type, so make sure to use the correct API key. You can also skip the `init` experience by providing the values in the configuration file. The Azure API base refers to the Azure OpenAI endpoint (which usually ends in `openai.azure.com/`), not the target URI of the deployment in Foundry. If the LLM configuration fails, double-check your API key or `AZURE_API_BASE`.

    The `init` experience must be successfully completed for you to use the agentic CLI. If `init` fails, check the configuration file option or the troubleshooting documentation.

---

## Use the agentic CLI for AKS

You can now start using the agentic CLI for AKS to troubleshoot your clusters and get intelligent insights by using natural language queries. The following sections outline key parameters and example queries to get you started.

### Basic queries

You can use the following example queries to get started with the agentic CLI for AKS.

> [!NOTE]
> If you have multiple models set up, you can specify the model to use for each query by using the `--model` parameter. For example, `--model=azure/gpt-4o`.

```azurecli-interactive
az aks agent "How many nodes are in my cluster?"
az aks agent "What is the Kubernetes version on the cluster?"
az aks agent "Why is coredns not working on my cluster?"
az aks agent "Why is my cluster in a failed state?"
```

By default, the experience uses interactive mode, where you can continue asking questions with retained context until you want to leave. To leave the experience, enter `/exit`.

### Agentic CLI for AKS parameters

| Parameter | Description |
|-----------|-------------|
| `--api-key` | API key to use for the LLM. (If not given, uses the environment variables `AZURE_API_KEY` and `OPENAI_API_KEY`.) |
| `--config-file` | Path to the configuration file. Default: `/Users/<>/.azure/aksAgent.config`. |
| `--max-steps` | Maximum number of steps that the LLM can take to investigate the issue. Default: 10. |
| `--model` | Model to use for the LLM. |
| `--name`, `-n` | Name of the managed cluster. |
| `--no-echo-request` | Disable echoing back the question provided to the AKS agent in the output. |
| `--no-interactive` | Disable interactive mode. When set, the agent doesn't prompt for input and runs in batch mode. |
| `--refresh-toolsets` | Refresh the toolsets status. |
| `--resource-group`, `-g` | Name of the resource group. |
| `--show-tool-output` | Show the output of each tool that was called during the analysis. |

### Model specification

The `--model` parameter determines which LLM and provider analyzes your cluster. For example:

- **OpenAI**: Use the model name directly (for example, `gpt-4o`).
- **Azure OpenAI**: Use `azure/<deployment name>` (for example, `azure/gpt-4o`).
- **Anthropic**: Use `anthropic/claude-sonnet-4`.

### Configuration file

The LLM configuration is stored in a configuration file through the `az aks agent-init` experience. If the `init` command doesn't work, you can still use the configuration file by adding the variables manually. For an example configuration file, see [agentic-cli-for-aks/exampleconfig.yaml](https://github.com/Azure/agentic-cli-for-aks/blob/main/exampleconfig.yaml). You can find the default configuration file path through the `az aks agent --help` command.

The configuration file currently supports the following parameters:

- Model
- API key
- Custom toolsets
- Azure environment variables

You can also use your configuration file by specifying the `--config-file` parameter with the path to your configuration file when you use the [`az aks agent`](/cli/azure/aks#az-aks-agent) command.

```azurecli-interactive
az aks agent "Check kubernetes pod resource usage" --config-file exampleconfig.yaml
```

### Interactive commands

The `az aks agent` has a set of subcommands that aid the troubleshooting experience. To access them, enter `/` inside the interactive mode experience.

| Command | Description |
|---------|-------------|
| `/exit` | Leave the interactive mode. |
| `/help` | Show help messages with all commands. |
| `/clear` | Clear the screen and reset the conversation context. |
| `/tools` | Show available toolsets and their status. |
| `/auto` | Switch the display of tool outputs after responses. |
| `/last` | Show all tool outputs from the last response. |
| `/run` | Run a Bash command and optionally share it with LLM. |
| `/shell` | Drop into the interactive shell and then optionally share the session with LLM. |
| `/context` | Show the conversation context size and token count. |
| `/show` | Show the specific tool output in a scrollable view. |
| `/feedback` | Provide feedback on the agent's response. |

### Disable interactive mode

To opt out of the default interactive mode, use the `--no-interactive` flag. For example:

```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --model=azure/gpt-4o --no-interactive --show-tool-output
```

### Toolsets

The agentic CLI for AKS includes prebuilt integrations for popular monitoring and observability tools through toolsets. Some integrations work automatically with Kubernetes. Other integrations require API keys or configuration.

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

As an alternative to the default toolsets, you can enable the [AKS Model Context Protocol (MCP) server](https://github.com/Azure/aks-mcp) with the agentic CLI for AKS. This experience spins up the AKS MCP server locally and uses it as the source for telemetry.

The following example shows how to start the MCP server and use it with the agentic CLI for AKS. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your AKS cluster's resource group and name.

```azurecli-interactive
az aks agent "why is my node unhealthy" --model=azure/gpt-4o --aks-mcp --name <CLUSTER_NAME> --resource-group <RESOURCE_GROUP>
Loaded models: ['azure/gpt-4o']                                                                                           
Refreshing available datasources (toolsets)                                                                               
..                                                                                                                       
**✅ Toolset aks-mcp  **                                                                                                      
..                                                                                                   
NO ENABLED LOGGING TOOLSET                                                                                                
Using model: azure/gpt-4o (128,000 total tokens, 16,384 output tokens)                                                    
This tool uses AI to generate responses and may not always be accurate.
Welcome to AKS AGENT: Type '/exit' to exit, '/help' for commands, '/feedback' to share your thoughts.
User: why is my node unhealthy
..
```

> [!NOTE]
> In the MCP server integration, provide the name of the cluster and the resource group at the start of the agent experience. Unlike the regular mode where the cluster context is picked up automatically, the MCP server integration currently doesn't support it.

To check the status of the MCP server, you can use the `--status` flag:

```azurecli-interactive
az aks-agent --status
```

## Remove the agentic CLI for AKS extension

Remove the agentic CLI for AKS extension by using the [`az extension remove`](/cli/azure/extension#az-extension-remove) command.

```azurecli-interactive
az extension remove --name aks-agent --debug
```

## Related content

- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./cli-agent-for-aks-overview.md).
- To troubleshoot any issues with the agentic CLI for AKS, see [Troubleshoot the agentic CLI for AKS](./cli-agent-for-aks-troubleshoot.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml).
