---
title: Install and Use the CLI Agent for Azure Kubernetes Service (AKS) (preview)
description: Learn how to install, configure, and use the CLI Agent for AKS to troubleshoot clusters and get intelligent insights using natural language.
ms.topic: how-to
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
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

1. Add the CLI Agent for AKS extension to your Azure CLI installation using the [`az extension add`](/cli/azure/extension#az-extension-add) command, or update to the latest version if you already have it installed using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    # Install the extension
    az extension add --name aks-agent --debug

    # Update the extension
    az extension update --name aks-agent --debug
    ```

1. Verify the installation was successful using the [`az version`](/cli/azure/reference-index#az-version) command.

    ```azurecli-interactive
    az extension list
    ```

    Your output should include an entry for `aks-agent`.

1. Verify the extension is installed using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command with the `--help` parameter.

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

> [!NOTE]
> We recommend using newer models such as GPT-4o, GPT-4o-mini, or Claude Sonnet 4.0 for better performance. Choose a model with a high context size of at least 128,000 tokens or higher.

### [Azure OpenAI (recommended)](#tab/azure-openai)

1. Set up an Azure OpenAI resource by following the steps in [Create an Azure OpenAI in Azure AI Foundry Models resource](/azure/ai-foundry/openai/how-to/create-resource#create-a-resource).

   > [!IMPORTANT]
   > For the deployment name, use the same name as the model's name (such as `gpt-4o` or `gpt-4o-mini`) depending on access. You can use any region where you have access and quota for the model. In the deployment, select the highest possible token limit per minute (TPM). We recommend upwards of 1M TPM for good performance. If you need to increase your quota, see [Manage Azure OpenAI in Azure AI Foundry Models quota](/azure/ai-foundry/openai/how-to/quota).

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

We also support any OpenAI compatible model. For other LLM providers, contact [Microsoft support](https://support.microsoft.com) for assistance.

## Initialize the CLI Agent for AKS

1. Initialize the CLI Agent for AKS using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. This command sets up the necessary configurations and toolsets for the agent.

    ```azurecli-interactive
    az aks agent-init
    ```

1. Select your LLM provider and enter LLM details when prompted. For example:

    ```output
    Welcome to AKS Agent LLM configuration setup. Type '/exit' to exit.
     1. azure
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

    > [!NOTE]
    > The API key will appear as empty as you type, so make sure to use the right API key. You can also skip the `init` experience by providing the values in the config file. The Azure API Base refers to the Azure Open AI endpoint (which usually ends in `openai.azure.com/`), not the target URI of the deployment in Azure AI Foundry. If the LLM configuration fails, please double check your API key and/or the `AZURE_API_BASE`.

## Use the CLI Agent for AKS

You can now start using the CLI Agent for AKS to troubleshoot your clusters and get intelligent insights using natural language queries. The following sections outline key parameters and example queries to get you started.

### CLI Agent for AKS parameters

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

You can specify some of the common parameters in a config file instead of the `init` experience. See the [agentic-cli-for-aks/exampleconfig.yaml](https://github.com/Azure/agentic-cli-for-aks/blob/main/exampleconfig.yaml) for an example configuration file.

The config file currently supports the following parameters:

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

As an alternative to the default toolsets, you can enable the [AKS MCP server](https://github.com/Azure/aks-mcp) with the Agentic CLI for AKS. This experience spins up the AKS MCP server locally and uses it as the source for telemetry.

The following example shows how to start the MCP server and use it with the CLI Agent for AKS:

```azurecli-interactive
az aks agent "why is my node unhealthy" --model=azure/gpt-4o --aks-mcp --name $MCP_SERVER_CLUSTER_NAME --resource-group $MCP_SERVER_RESOURCE_GROUP
Loaded models: ['azure/gpt-4o']                                                                                           
Refreshing available datasources (toolsets)                                                                               
❌ Toolset slab: Environment variable SLAB_API_KEY was not set                                                            
✅ Toolset kubernetes/kube-prometheus-stack                                                                               
❌ Toolset argocd/core: Environment variable ARGOCD_AUTH_TOKEN was not set                                                
❌ Toolset confluence: Environment variable CONFLUENCE_BASE_URL was not set                                               
✅ Toolset core_investigation                                                                                             
❌ Toolset robusta: Integration with Robusta cloud is disabled                                                            
✅ Toolset internet                                                                                                       
❌ Toolset opensearch/status: The toolset is missing its configuration                                                    
❌ Toolset grafana/tempo: The toolset is missing its configuration                                                        
❌ Toolset grafana/loki: Missing Loki configuration. Check your config.                                                   
❌ Toolset newrelic: No configuration provided                                                                            
❌ Toolset grafana/grafana: The toolset is missing its configuration                                                      
❌ Toolset notion: Notion toolset is misconfigured. Authorization header is required.                                     
❌ Toolset kafka/admin: The toolset is missing its configuration                                                          
❌ Toolset datadog/logs: Missing config for dd_api_key, dd_app_key, or site_api_url. For details:                         
https://holmesgpt.dev/data-sources/builtin-toolsets/datadog/                                                              
❌ Toolset datadog/general: Missing config for dd_api_key, dd_app_key, or site_api_url. For details:                      
https://holmesgpt.dev/data-sources/builtin-toolsets/datadog/                                                              
❌ Toolset datadog/metrics: Missing config for dd_api_key, dd_app_key, or site_api_url. For details:                      
https://holmesgpt.dev/data-sources/builtin-toolsets/datadog/                                                              
❌ Toolset datadog/traces: No configuration provided for Datadog Traces toolset                                           
✅ Toolset datadog/rds                                                                                                    
❌ Toolset opensearch/logs: Missing OpenSearch configuration. Check your config.                                          
❌ Toolset opensearch/traces: Missing opensearch traces URL. Check your config                                            
❌ Toolset opensearch/query_assist: Environment variable OPENSEARCH_URL was not set                                       
❌ Toolset coralogix/logs: The toolset is missing its configuration                                                       
❌ Toolset rabbitmq/core: RabbitMQ toolset is misconfigured. 'management_url' is required.                                
❌ Toolset git: Missing one or more required Git configuration values.                                                    
❌ Toolset MongoDBAtlas: Missing config credentials.                                                                      
✅ Toolset runbook                                                                                                        
❌ Toolset azure/sql: The toolset is missing its configuration                                                            
❌ Toolset ServiceNow: Missing config credentials.                                                                        
❌ Toolset aws/security: `aws sts get-caller-identity` returned 127                                                       
❌ Toolset aws/rds: `aws sts get-caller-identity` returned 127                                                            
❌ Toolset docker/core: `docker version` returned 127                                                                     
❌ Toolset cilium/core: `cilium status` returned 127                                                                      
❌ Toolset hubble/observability: `hubble version` returned 127                                                            
**✅ Toolset aks-mcp  **                                                                                                      
❌ Toolset kubernetes/krew-extras: `kubectl version --client && kubectl lineage --version` returned 1                     
✅ Toolset helm/core                                                                                                      
Toolset statuses are cached to /Users/aritraghosh/.azure/toolsets_status.json                                             
✅ Toolset kubernetes/kube-prometheus-stack                                                                               
✅ Toolset internet                                                                                                       
✅ Toolset core_investigation                                                                                             
✅ Toolset datadog/rds                                                                                                    
✅ Toolset runbook                                                                                                        
✅ Toolset aks-mcp                                                                                                        
✅ Toolset helm/core                                                                                                      
NO ENABLED LOGGING TOOLSET                                                                                                
Using model: azure/gpt-4o (128,000 total tokens, 16,384 output tokens)                                                    
This tool uses AI to generate responses and may not always be accurate.
Welcome to AKS AGENT: Type '/exit' to exit, '/help' for commands, '/feedback' to share your thoughts.
User: why is my node unhealthy
..
```

> [!NOTE]
> In the MCP server integration, please provide the name of the cluster and the resource group at the start of the agent experience. Unlike the regular mode where the cluster context is picked up automatically, the MCP server integration currently doesn't support it. This limitation will be fixed in the future.

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
- [CLI Agent for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml) answers common questions about the CLI Agent for AKS.
