---
title: Install and Use the Agentic CLI for Azure Kubernetes Service (AKS) (Preview)
description: Learn how to install, configure, and use the agentic CLI for AKS to troubleshoot clusters and get intelligent insights by using natural language.
ms.topic: how-to
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
zone_pivot_groups: agentic-cli-deployment-mode
# Customer intent: As a cluster administrator or SRE, I want to install and configure the agentic CLI for AKS so that I can start troubleshooting my clusters by using natural language queries.
---

# Install and use the agentic CLI for Azure Kubernetes Service (AKS) (preview)

This article shows you how to install, configure, and use the agentic CLI for Azure Kubernetes Service (AKS) in [client mode](./agentic-cli-for-aks-overview.md#deployment-modes) or [cluster mode](./agentic-cli-for-aks-overview.md#deployment-modes) to get AI-powered troubleshooting and insights for your AKS clusters.

For more information, see the [Agentic CLI for AKS overview](./agentic-cli-for-aks-overview.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Azure CLI version 2.76 or later. Check your version using the `az version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- Have a large language model (LLM) API key. You must bring your own API key from one of the supported providers:
  - Azure OpenAI (recommended)
  - OpenAI or other LLM providers compatible with OpenAPI specifications
- Set your active Azure subscription using the [`az account set`](/cli/azure/account#az-account-set) command.

    ```azurecli-interactive
    az account set --subscription "your-subscription-id-or-name"
    ```

- Version 1.0.0b16 or later of the `aks-agent` Azure CLI extension, which provides the agentic CLI for AKS functionality. You can install or update the extension using the Azure CLI.

:::zone pivot="client-mode"

- Docker installed and running on your local machine. For installation instructions, see [Get Started with Docker](https://www.docker.com/get-started/).
- Ensure the Docker daemon is started and running before proceeding with the installation.
- Ensure your Azure credentials are properly configured and you have the necessary permissions to access cluster resources.

:::zone-end

:::zone pivot="cluster-mode"

- Before installing, you need to [Create a required Kubernetes service account with RBAC permissions](./agentic-cli-for-aks-service-account-workload-identity-setup.md). (Workload identity setup is optional.)
- You need write access to deploy to the Kubernetes namespace where the agent will be deployed.

:::zone-end

### Install the agentic CLI for AKS extension

1. Install the agentic CLI for AKS extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command. If the extension is already installed, you can update to the latest version with the [`az extension update`](/cli/azure/extension#az-extension-update) command. This step might take 5 to 10 minutes to complete.

    ```azurecli-interactive
    # Install the extension
    az extension add --name aks-agent --debug

    # Update the extension
    az extension update --name aks-agent --debug
    ```

1. Verify successful installation using the [`az extension list`](/cli/azure/extension#az-extension-list) command.

    ```azurecli-interactive
    az extension list
    ```

    Your output should include an entry for `aks-agent`.

1. Verify the agentic CLI for AKS commands are available using the [`az aks agent`][/cli/azure/aks#az-aks-agent] command with the `--help` parameter.

    ```azurecli-interactive
    az aks agent --help
    ```

    Your output should show the `aks-agent` with its version information in the `extensions` section. For example:

    ```output
    ...
    "extensions": {
    "aks-agent": "1.0.0b17",
    }
    ```

## Set up your LLM API key

Before proceeding with installation, you need to set up your LLM API key. We recommend using newer models such as _GPT-5_ or _Claude Opus MINI_ for better performance. Make sure to select a model with a high context size of at least _128,000 tokens_ or higher.

### Azure OpenAI (recommended)

1. [Create an Azure OpenAI resource](/azure/foundry-classic/openai/how-to/create-resource?pivots=web-portal#create-a-resource).
1. [Deploy the model](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal#deploy-a-model). For the deployment name, use the same name as the model name, such as _gpt-4o_ or _gpt-4o-mini_, depending on the access. You can use any region where you have access and quota for the model. In the deployment, select a token-per-minute (TPM) limit as high as possible. We recommend upward of _1-million TPM_ for good performance.
1. After the deployment completes, note your API base URL and API key. The API version isn't the model version. You can use any API version that's available and supported in [Azure OpenAI in Microsoft Foundry Models v1 API](/azure/ai-foundry/openai/api-version-lifecycle). The Azure API base refers to the Azure OpenAI endpoint (which usually ends in `openai.azure.com/`), not the target URI of the deployment in Foundry.

### Azure OpenAI with Microsoft Entra ID (keyless authentication)

When you select "Azure Open AI (Microsoft Entra ID)" as your LLM provider, you can configure keyless authentication using Microsoft Entra ID. With this option, you don't need to provide an API key. Instead, this authentication method requires the following role assignments:

- **Client mode**: The local Azure CLI credentials must be assigned the **Cognitive Services User** or **Azure AI User** role on the Azure OpenAI resource.
- **Cluster mode**: The workload identity must be assigned the **Cognitive Services User** or **Azure AI User** role on the Azure OpenAI resource.

### Other LLM providers

If you're using another OpenAI-compatible provider, follow their documentation for instructions on how to create an account and retrieve the API key.

:::zone pivot="client-mode"

## Verify Docker installation and start Docker daemon

1. Verify that Docker is installed and the Docker daemon is running using the following commands:

    ```bash
    docker --version
    docker ps
    ```

1. If you receive an error indicating that the Docker daemon isn't running, start the Docker service using the appropriate steps for your operating system:

    - **macOS / Windows**:
      - Launch Docker Desktop from your applications.
      - Wait for Docker to start.

    - **Linux**:
      - Start the Docker service using the following commands:

        ```bash
        sudo systemctl start docker
        sudo systemctl enable docker  # Enable Docker to start on boot
        ```

1. Verify Docker is running using the following command:

    ```bash
    docker info
    ```

    This command should return Docker system information without errors.

## Initialize client mode

1. Initialize the agentic CLI with client mode using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. Make sure to replace the placeholder values with your actual resource group and cluster name.

    ```azurecli-interactive
    az aks agent-init --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. When prompted to select a deployment mode, enter **2** for client mode.

    ```output
    🚀 Welcome to AKS Agent initialization!

    Please select the mode you want to use:
      1. Cluster mode - Deploys agent as a pod in your AKS cluster
         Uses service account and workload identity for secure access to cluster and Azure resources
      2. Client mode - Runs agent locally using Docker
         Uses your local Azure credentials and cluster user credentials for access
    
    Enter your choice (1 or 2): 2
    ```

1. Configure your LLM provider details. For example:

    ```output
    Welcome to AKS Agent LLM configuration setup. Type '/exit' to exit.
     1. Azure Open AI (API Key)
     1. Azure Open AI (Microsoft Entra ID)
     3. OpenAI
     4. Anthropic
     5. Gemini
     6. Openai Compatible
    Enter the number of your LLM provider: 1
    Your selected provider: azure
    Enter value for MODEL_NAME:  (Hint: should be consistent with your deployed name, e.g., gpt-4.1) gpt-4.1
    Enter your API key: 
    Enter value for AZURE_API_BASE:  (Hint: https://{your-custom-endpoint}.openai.azure.com/) https://test-example.openai.azure.com
    Enter value for AZURE_API_VERSION:  (Default: 2025-04-01-preview)
    LLM configuration setup successfully.
    ```

    > [!NOTE]
    > The API key appears empty as you type for security. Make sure to enter the correct API key.

1. Verify the initialization was successful. The agent automatically pulls the necessary Docker images when you run your first command.

:::zone-end

:::zone pivot="cluster-mode"

## Initialize cluster mode

1. Initialize the agentic CLI with cluster mode using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. Make sure to replace the placeholder values with your actual resource group and cluster name.

    ```azurecli-interactive
    az aks agent-init --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. When prompted to select a deployment mode, enter **1** for cluster mode.

    ```output
    🚀 Welcome to AKS Agent initialization!

    Please select the mode you want to use:
      1. Cluster mode - Deploys agent as a pod in your AKS cluster
         Uses service account and workload identity for secure access to cluster and Azure resources
      2. Client mode - Runs agent locally using Docker
         Uses your local Azure credentials and cluster user credentials for access
    
    Enter your choice (1 or 2): 1
    ```

1. When prompted to specify the target namespace, enter the namespace where you created the service account. The following example uses `your-namespace` as a placeholder. Make sure to replace it with the actual namespace you used.

    ```output
    ✅ Cluster mode selected. This will set up the agent deployment in your cluster.

    Please specify the namespace where the agent will be deployed.

    Enter namespace (e.g., 'kube-system'): your-namespace
    ```

1. Configure your LLM provider details. For example:

    ```output
    📦 Using namespace: your-namespace
    No existing LLM configuration found. Setting up new configuration...
    Please provide your LLM configuration. Type '/exit' to exit.
     1. Azure OpenAI
     2. OpenAI
     3. Anthropic
     4. Gemini
     5. OpenAI Compatible
     6. For other providers, see https://aka.ms/aks/agentic-cli/init
    Please choose the LLM provider (1-5): 1
    ```

1. Provide service account details using the [Kubernetes service account](./agentic-cli-for-aks-service-account-workload-identity-setup.md) you created for the agent deployment. The following example uses `aks-mcp` as a placeholder for the service account name. Make sure to replace it with the actual name of your service account.

    ```output
    👤 Service Account Configuration
    The AKS agent requires a service account with appropriate permissions in the 'your-namespace'
    namespace.
    Please ensure you have created the necessary Role and RoleBinding in your namespace for 
    this service account.

    Enter service account name: aks-mcp
    ```

1. Wait for deployment completion. The initialization deploys the agent using Helm.

    ```output
    🚀 Deploying AKS agent (this typically takes less than 2 minutes)...
    ✅ AKS agent deployed successfully!
    Verifying deployment status...
    ✅ AKS agent is ready and running!

    🎉 Initialization completed successfully!
    ```

1. Verify successful deployment and check the status of the agent using the [`az aks agent`](/cli/azure/aks#az-aks-agent) command with the `--status` parameter.

    ```azurecli-interactive
   az aks agent \
    --status \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --namespace $NAMESPACE
    ```

    Your output should indicate that the agent is ready and running, similar to the following:

    ```output
    📊 Checking AKS agent status...

    ✅ Helm Release: deployed

    📦 Deployments:
      • aks-agent: 1/1 ready
      • aks-mcp: 1/1 ready

    🐳 Pods:
      • aks-agent-xxxxx-xxxxx: Running ✓
      • aks-mcp-xxxxx-xxxxx: Running ✓

    📋 LLM Configurations:
      • azure/gpt-4o
        API Base: https://your-service.openai.azure.com/
        API Version: 2025-04-01-preview

    ✅ AKS agent is ready and running!
    ```

    > [!NOTE]
    > You can also verify successful deployment by checking the pods and deployments in the target namespace using `kubectl`:
    >
    > ```bash
    > kubectl get pods --namespace $NAMESPACE | grep aks-
    > kubectl get deployment --namespace $NAMESPACE | grep aks-
    > ```

:::zone-end

## Use the agentic CLI for AKS

Once initialized, you can use the agentic CLI for AKS to troubleshoot your clusters and get intelligent insights by using natural language queries. The command syntax and functionality are the same for both client mode and cluster mode, except for the `--mode` and `--namespace` parameters. Cluster mode is the default deployment mode, so you only need to specify `--mode client` when using client mode. For cluster mode, you need to specify the `--namespace` parameter with the namespace where the agent is deployed.

### Basic queries

> [!NOTE]
> If you have multiple models set up, you can specify the model to use for each query using the `--model` parameter. For example, `--model=azure/gpt-4o`.

:::zone pivot="client-mode"

The following are examples of basic queries you can run with the agentic CLI for AKS in client mode:

```azurecli-interactive
az aks agent "How many nodes are in my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client
az aks agent "What is the Kubernetes version on the cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client
az aks agent "Why is coredns not working on my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client
az aks agent "Why is my cluster in a failed state?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client
```

:::zone-end

:::zone pivot="cluster-mode"

The following are examples of basic queries you can run with the agentic CLI for AKS in cluster mode:

```azurecli-interactive
az aks agent "How many nodes are in my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "What is the Kubernetes version on the cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "Why is coredns not working on my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
az aks agent "Why is my cluster in a failed state?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
```

:::zone-end

The experience uses interactive mode by default, so you can continue asking questions with retained context until you want to leave. To leave the experience, enter `/exit`.

### Command parameters

The `az aks agent` command has several parameters that allow you to customize the troubleshooting experience. The following table describes the key parameters you can use when running your queries:

| Parameter | Description |
| ----------|------------ |
| `--max-steps` | Maximum number of steps the LLM can take to investigate the issue. Default: 40. |
| `--mode` | The mode decides how the agent is deployed. Allowed values: `client`, `cluster`. Default: `cluster`. |
| `--model` | Specify the LLM provider and model or deployment to use for the AI assistant. |
| `--name`, `-n` | Name of the managed cluster. (Required) |
| `--namespace` | The Kubernetes namespace where the AKS Agent is deployed. Required for cluster mode. |
| `--no-echo-request` | Disable echoing back the question provided to AKS Agent in the output. |
| `--no-interactive` | Disable interactive mode. When set, the agent will not prompt for input and will run in batch mode. |
| `--refresh-toolsets` | Refresh the toolsets status. |
| `--resource-group`, `-g` | Name of resource group. (Required) |
| `--show-tool-output` | Show the output of each tool that was called. |
| `--status` | Show AKS agent configuration and status information. |

### Model specification

The `--model` parameter determines which LLM and provider analyzes your cluster. For example:

- **OpenAI**: Use the model name directly (for example, `gpt-4o`).
- **Azure OpenAI**: Use `azure/<deployment name>` (for example, `azure/gpt-4o`).
- **Anthropic**: Use `anthropic/claude-sonnet-4`.

### Interactive commands

The `az aks agent` has a set of subcommands that aid the troubleshooting experience. To access them, enter `/` inside the interactive mode experience.

The following table describes the available interactive commands:

| Command | Description |
| ------- |------------ |
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

You can disable interactive mode using the `--no-interactive` flag with your command. For example:

:::zone pivot="client-mode"

```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client --model=azure/gpt-4o --no-interactive --show-tool-output
```

:::zone-end

:::zone pivot="cluster-mode"

```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE --model=azure/gpt-4o --no-interactive --show-tool-output
```

:::zone-end

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

The [AKS Model Context Protocol (MCP) server](https://github.com/Azure/aks-mcp) is enabled by default with the agentic CLI for AKS. This experience spins up the AKS MCP server locally (or in the cluster with cluster mode) and uses it as the source for telemetry.

## Clean up agentic CLI deployment

:::zone pivot="client-mode"

Clean up your client mode deployment using the [`az aks agent-cleanup`](/cli/azure/aks#az-aks-agent-cleanup) command with the `--mode client` parameter. This command removes the local configuration file and resets the agent configuration.

```azurecli-interactive
az aks agent-cleanup --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --mode client
```

:::zone-end

:::zone pivot="cluster-mode"

Clean up your cluster mode deployment using the [`az aks agent-cleanup`](/cli/azure/aks#az-aks-agent-cleanup) command. Make sure to specify the `--namespace` parameter with the namespace where the agent is deployed. This command removes the agent pod from the specified namespace and deletes the LLM configuration stored on the cluster.

```azurecli-interactive
az aks agent-cleanup --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace $NAMESPACE
```

:::zone-end

### Verify successful cleanup

:::zone pivot="client-mode"

Check that the local configuration file and Docker images were removed using the following commands:

```bash
# Check if configuration file was removed
ls ~/.azure/aksAgent.config

# Check for remaining Docker images
docker images | grep aks-agent
```

:::zone-end

:::zone pivot="cluster-mode"

Check that the agent pod and related resources were removed from the cluster using the following commands with the appropriate namespace:

```bash
# Check if agent pod was removed
kubectl get pods --namespace $NAMESPACE

# Check if service account was removed
kubectl get serviceaccount --namespace $NAMESPACE

# Check if namespace was removed (if it was created during init)
kubectl get namespace $NAMESPACE
```

:::zone-end

## Remove the agentic CLI for AKS extension

Remove the agentic CLI for AKS extension using the [`az extension remove`](/cli/azure/extension#az-extension-remove) command.

```azurecli-interactive
az extension remove --name aks-agent --debug
```

## Related content

- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./agentic-cli-for-aks-overview.md).
- To troubleshoot any issues with the agentic CLI for AKS, see [Troubleshoot the agentic CLI for AKS](./agentic-cli-for-aks-troubleshoot.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS FAQ](./agentic-cli-for-aks-faq.yml).
