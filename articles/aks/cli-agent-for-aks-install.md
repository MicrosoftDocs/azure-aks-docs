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

# Install and use the agentic CLI for Azure Kubernetes Service (AKS) (Preview)

This article shows you how to install, configure, and use the agentic CLI for Azure Kubernetes Service (AKS) to get AI-powered troubleshooting and insights for your AKS clusters. The agentic CLI supports two deployment modes: **client mode** for local execution and **cluster mode** for in-cluster deployment.

For more information, see the [agentic CLI for AKS overview](./cli-agent-for-aks-overview.md).

## Deployment modes

The agentic CLI for AKS supports two deployment modes that you can choose during initialization:

> [!NOTE]
> These two modes are only available from version "1.0.0b16" of the aks-agent extension
> 

### Client mode

- **Deployment**: Runs the agent locally using Docker
- **Authentication**: Uses your local Azure credentials and cluster user credentials
- **Use case**: Ideal for development, testing, and scenarios where you want to run the agent from your local machine
- **Requirements**: Requires Docker to be installed locally

### Cluster mode

- **Deployment**: Deploys the agent as a pod within your AKS cluster using Helm
- **Authentication**: Uses service account and optional workload identity for secure access to cluster and Azure resources
- **Use case**: Recommended for production scenarios, shared environments, and when you want the agent to run closer to your cluster resources
- **Requirements**: Requires existing namespace, service account with RBAC permissions, and workload identity setup for Azure resource access

## Prerequisites

### General requirements

Both deployment modes require the following:

- Use the Azure CLI version 2.76 or later. To verify your Azure CLI version, use the [`az version`](/cli/azure/reference-index#az-version) command.
- Have a large language model (LLM) API key. You must bring your own API key from one of the supported providers:
  - Azure OpenAI (recommended).
  - OpenAI or other LLM providers compatible with OpenAPI specifications.
- Ensure that you're signed in to the proper subscription by using the [`az account set`](/cli/azure/account#az-account-set) command.

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
    "aks-agent": "1.0.0b15",
    }
    ```

## Set up your LLM API key

Before proceeding with installation, you need to set up your LLM API key. We recommend that you use newer models such as GPT-4o, GPT-4o-mini, or Claude Sonnet 4.0 for better performance. Choose a model with a high context size of at least 128,000 tokens or higher.

### Azure OpenAI (recommended)

Set up an Azure OpenAI resource by following the steps in the [Microsoft documentation](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal).

> [!NOTE]
> For the deployment name, use the same name as the model name, such as gpt-4o or gpt-4o-mini, depending on the access. You can use any region where you have access and quota for the model.
> In the deployment, select a token-per-minute (TPM) limit as high as possible. We recommend upward of a 1-million TPM for good performance.

1. [Deploy the model](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal#deploy-a-model) that you plan to use in the Microsoft Foundry portal.
1. After deployment is finished, note your API base URL and API key.

   <img width="1713" height="817" alt="image" src="https://github.com/user-attachments/assets/400021fd-5604-4cd2-9faf-407145c52669" />

The API version isn't the model version. You can use any API version that's available and supported on [this webpage](/azure/ai-foundry/openai/api-version-lifecycle).

The Azure API base refers to the Azure OpenAI endpoint (which usually ends in `openai.azure.com/`), not the target URI of the deployment in Foundry.

### Other LLM providers

We also support any OpenAI-compatible model. Check the documentation of the LLM provider for instructions on how to create an account and retrieve the API key.

## Installation

Choose your deployment mode and follow the corresponding installation guide:

# [Client mode](#tab/client-mode)

Client mode runs the agent locally using Docker and your existing Azure credentials.

### Prerequisites for client mode

- **Docker**: Docker must be installed and running on your local machine. You can download Docker from [docker.com](https://www.docker.com/get-started/).
- **Docker daemon**: Ensure the Docker daemon is started and running before proceeding with the installation.
- **Local Azure credentials**: Ensure your Azure credentials are properly configured and you have the necessary permissions to access cluster resources.

### Verify Docker installation and start Docker daemon

1. Verify that Docker is installed and the Docker daemon is running:

   ```bash
   docker --version
   docker ps
   ```

   If Docker isn't installed, follow the [Docker installation guide](https://docs.docker.com/get-docker/) for your operating system.

2. **Start the Docker daemon** if it's not running:

   **On macOS/Windows:**
   - Launch Docker Desktop from your applications
   - Wait for Docker to start (you'll see the Docker icon in your system tray/menu bar)

   **On Linux:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker  # Enable Docker to start on boot
   ```

3. Verify Docker is running:

   ```bash
   docker info
   ```

   This command should return Docker system information without errors.

### Initialize client mode

1. Initialize the agentic CLI for client mode by using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your AKS cluster's resource group and name.

    ```azurecli-interactive
    az aks agent-init --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME>
    ```

1. When prompted to select a deployment mode, choose **Option 2** for client mode:

    ```output
    🚀 Welcome to AKS Agent initialization!

    Please select the mode you want to use:
      1. Cluster mode - Deploys agent as a pod in your AKS cluster
         Uses service account and workload identity for secure access to cluster and Azure resources
      2. Client mode - Runs agent locally using Docker
         Uses your local Azure credentials and cluster user credentials for access
    
    Enter your choice (1 or 2): 2
    ```

1. Configure your LLM provider when prompted. For example:

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

    > [!NOTE]
    > The API key appears empty as you type for security. Make sure to enter the correct API key.

4. Verify the initialization was successful. The agent will automatically pull the necessary Docker images when you run your first command.

# [Cluster mode](#tab/cluster-mode)

Cluster mode deploys the agent as a pod within your AKS cluster using workload identity for secure authentication.

### Prerequisites for cluster mode

> [!IMPORTANT]
> **Mandatory setup**: Before initializing cluster mode, you **must** create a service account with RBAC permissions. Workload identity setup is optional.

**Complete the required setup first:**
- Follow the **mandatory** [Service account creation](./cli-agent-for-aks-service-account-workload-identity-setup.md#step-1-create-the-kubernetes-service-account-mandatory) guide. This includes:
  - Creating the Kubernetes service account with RBAC permissions (**required**)
- **Optional**: Complete the [workload identity setup](./cli-agent-for-aks-service-account-workload-identity-setup.md#workload-identity-setup-optional) for enhanced Azure resource access security

**Additional cluster requirements:**
- **Namespace**: You must have a write access to deploy to the Kubernetes namespace where the agent will be deployed

> [!IMPORTANT]
> Before proceeding with cluster mode initialization, ensure you have completed the [Service account creation](./cli-agent-for-aks-service-account-workload-identity-setup.md#step-1-create-the-kubernetes-service-account-mandatory). Workload identity setup is optional but recommended for enhanced security.

### Initialize cluster mode

1. Initialize the agentic CLI for cluster mode by using the [`az aks agent-init`](/cli/azure/aks#az-aks-agent-init) command. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your AKS cluster's resource group and name.

    ```azurecli-interactive
    az aks agent-init --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME>
    ```

1. When prompted to select a deployment mode, choose **Option 1** for cluster mode:

    ```output
    🚀 Welcome to AKS Agent initialization!

    Please select the mode you want to use:
      1. Cluster mode - Deploys agent as a pod in your AKS cluster
         Uses service account and workload identity for secure access to cluster and Azure resources
      2. Client mode - Runs agent locally using Docker
         Uses your local Azure credentials and cluster user credentials for access
    
    Enter your choice (1 or 2): 1
    ```

1. **Specify the target namespace** when prompted. Use the namespace where you created the service account:

    ```output
    ✅ Cluster mode selected. This will set up the agent deployment in your cluster.

    Please specify the namespace where the agent will be deployed.

    Enter namespace (e.g., 'kube-system'): <YOUR_NAMESPACE>
    ```

1. **Configure your LLM provider** when prompted:

    ```output
    📦 Using namespace: <YOUR_NAMESPACE>
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

1. **Provide service account details** when prompted. Use the service account you created during the [mandatory setup](./cli-agent-for-aks-service-account-workload-identity-setup.md):

    ```output
    👤 Service Account Configuration
    The AKS agent requires a service account with appropriate permissions in the '<YOUR_NAMESPACE>'
    namespace.
    Please ensure you have created the necessary Role and RoleBinding in your namespace for 
    this service account.

    Enter service account name: aks-mcp
    ```

    > [!NOTE]
    > If you followed the setup guide, use `aks-mcp` as the service account name.


1. **Wait for deployment completion**. The initialization will deploy the agent using Helm:

    ```output
    🚀 Deploying AKS agent (this typically takes less than 2 minutes)...
    ✅ AKS agent deployed successfully!
    Verifying deployment status...
    ✅ AKS agent is ready and running!

    🎉 Initialization completed successfully!
    ```

1. Verify the deployment was successful:

    ```azurecli-interactive
    az aks agent --status --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <YOUR_NAMESPACE>
    ```

    You should see output similar to:

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

    You can also verify using kubectl:

    ```bash
    kubectl get pods -n <YOUR_NAMESPACE> | grep aks-
    kubectl get deployment -n <YOUR_NAMESPACE> | grep aks-
    ```

---

## Use the agentic CLI for AKS

Once initialized, you can use the agentic CLI for AKS to troubleshoot your clusters and get intelligent insights by using natural language queries. The command syntax and functionality are the same regardless of whether you selected client mode or cluster mode during initialization.

### Required parameters

All agent commands require the following parameters:
- `-n` or `--name`: The name of your AKS cluster
- `-g` or `--resource-group`: The resource group containing your AKS cluster

Additional parameters based on deployment mode:

**For client mode:**
- `--mode client`: Specifies client mode execution (default mode is cluster)

**For cluster mode:**
- `--namespace`: The Kubernetes namespace where the agent is deployed (required for cluster mode)

> [!NOTE]
> The default mode is `cluster`. You only need to specify `--mode client` when using client mode.

### Basic queries

You can use the following example queries to get started with the agentic CLI for AKS. Replace `<RESOURCE_GROUP>` and `<CLUSTER_NAME>` with your actual values.

> [!NOTE]
> If you have multiple models set up, you can specify the model to use for each query by using the `--model` parameter. For example, `--model=azure/gpt-4o`.

**Client mode examples:**

```azurecli-interactive
az aks agent "How many nodes are in my cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client
az aks agent "What is the Kubernetes version on the cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client
az aks agent "Why is coredns not working on my cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client
az aks agent "Why is my cluster in a failed state?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client
```

**Cluster mode examples:**

```azurecli-interactive
az aks agent "How many nodes are in my cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE>
az aks agent "What is the Kubernetes version on the cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE>
az aks agent "Why is coredns not working on my cluster?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE>
az aks agent "Why is my cluster in a failed state?" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE>
```

By default, the experience uses interactive mode, where you can continue asking questions with retained context until you want to leave. To leave the experience, enter `/exit`.

### Agentic CLI for AKS parameters

| Parameter | Description |
|-----------|-------------|
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

### Configuration file

The LLM configuration and deployment mode selection are stored in a configuration file through the `az aks agent-init` experience. If the `init` command doesn't work, you can still use the configuration file by adding the variables manually. For an example configuration file, see [agentic-cli-for-aks/exampleconfig.yaml](https://github.com/Azure/agentic-cli-for-aks/blob/main/exampleconfig.yaml). You can find the default configuration file path through the `az aks agent --help` command.

The configuration file currently supports the following parameters:

- Model
- API key
- Deployment mode (client or cluster)
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

To opt out of the default interactive mode, use the `--no-interactive` flag:

**Client mode:**
```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client --model=azure/gpt-4o --no-interactive --show-tool-output
```

**Cluster mode:**
```azurecli-interactive
az aks agent "How many pods are in the kube-system namespace" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE> --model=azure/gpt-4o --no-interactive
az aks agent "Why are the pods in Crashloopbackoff in the kube-system namespace" --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE> --model=azure/gpt-4o --no-interactive --show-tool-output
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

The [AKS Model Context Protocol (MCP) server](https://github.com/Azure/aks-mcp) is enabled by default with the agentic CLI for AKS. This experience spins up the AKS MCP server locally (or in the cluster with cluster mode) and uses it as the source for telemetry.



## Clean up agentic CLI deployment

You can clean up the agentic CLI deployment based on the mode you selected during initialization.

### Command parameters

All cleanup commands require the following parameters:
- `-n` or `--name`: The name of your AKS cluster
- `-g` or `--resource-group`: The resource group containing your AKS cluster

# [Client mode](#tab/client-cleanup)

For client mode, the cleanup process removes the local configuration and any downloaded Docker images:

```azurecli-interactive
az aks agent-cleanup --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --mode client
```

This command:
- Removes the local configuration file
- Resets the agent configuration

### Verify client mode cleanup

To verify that the cleanup was successful:

```bash
# Check if configuration file was removed
ls ~/.azure/aksAgent.config

# Check for remaining Docker images
docker images | grep aks-agent
```

# [Cluster mode](#tab/cluster-cleanup)

For cluster mode, the cleanup process removes the deployed resources from your AKS cluster:

**Additional parameter required:**
- `--namespace`: The Kubernetes namespace where the agent is deployed

```azurecli-interactive
az aks agent-cleanup --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --namespace <NAMESPACE>
```

This command:
- Removes the agent pod from the specified namespace
- Deletes the LLM configuration stored on the cluster

Replace `<NAMESPACE>` with the namespace where the agent was deployed (default is usually `aks-agent`).

### Verify cluster mode cleanup

To verify that the cleanup was successful:

```azurecli-interactive
# Check if agent pod was removed
kubectl get pods -n <NAMESPACE>

# Check if service account was removed
kubectl get serviceaccount -n <NAMESPACE>

# Check if namespace was removed (if it was created during init)
kubectl get namespace <NAMESPACE>
```

---

## Remove the agentic CLI for AKS extension

Remove the agentic CLI for AKS extension by using the [`az extension remove`](/cli/azure/extension#az-extension-remove) command.

```azurecli-interactive
az extension remove --name aks-agent --debug
```

## Related content

- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./cli-agent-for-aks-overview.md).
- To troubleshoot any issues with the agentic CLI for AKS, see [Troubleshoot the agentic CLI for AKS](./cli-agent-for-aks-troubleshoot.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml).
