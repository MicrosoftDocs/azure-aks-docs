---
title: Troubleshoot the Agentic CLI for Azure Kubernetes Service (AKS)
description: Learn how to troubleshoot the agentic CLI for Azure Kubernetes Service (AKS) to resolve common issues and improve performance.
ms.topic: troubleshooting-general
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to troubleshoot issues with the AI-powered CLI agent for AKS to ensure that it functions correctly and provides accurate insights.
---

# Troubleshoot the agentic CLI for Azure Kubernetes Service (AKS)

This article provides guidance on troubleshooting common issues with the agentic CLI for Azure Kubernetes Service (AKS). The troubleshooting steps are organized by deployment mode and common scenarios.

## Common troubleshooting steps

If you run into any issues when you use the agentic CLI for AKS, try the following troubleshooting steps:

- If you see requests retrying to `/chat/completions` in the responses, you're throttled by the token-per-minute (TPM) limits from the LLM. Increase the TPM limit or [apply for more quota](/azure/ai-foundry/openai/how-to/quota).
- If outputs vary, it might be because of LLM response variability or intermittent Model Context Protocol (MCP) server connections.
- Ensure that the deployment name is the same as the model name in the Azure OpenAI deployments.
- If the `aks-agent` installation is failing, try to uninstall the Azure CLI and reinstall the latest version.

## Deployment mode-specific issues

# [Client mode](#tab/client-troubleshoot)

### Docker-related issues

#### Error: Docker daemon not running

```output
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

**Solution:**
1. **On macOS/Windows:**
   - Launch Docker Desktop from your applications
   - Wait for Docker to start (you'll see the Docker icon in your system tray/menu bar)

1. **On Linux:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker  # Enable Docker to start on boot
   ```

1. Verify Docker is running:
   ```bash
   docker info
   ```

#### Error: Docker permission denied

```output
Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
1. **On Linux**, add your user to the docker group:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker  # Apply group changes immediately
   ```

2. **On macOS/Windows**, restart Docker Desktop

#### Error: Docker image pull failures

```output
Error response from daemon: pull access denied for aks-agent, repository does not exist or may require 'docker login'
```

**Solution:**
- Ensure you have internet connectivity
- Check if corporate firewalls are blocking Docker registry access
- Try initializing the agent again with `az aks agent-init`

### Azure credentials issues

#### Error: Azure authentication failed

**Solution:**
- Verify your Azure credentials are properly configured:
  ```azurecli-interactive
  az account show
  ```
- Sign in again if needed:
  ```azurecli-interactive
  az login
  ```

# [Cluster mode](#tab/cluster-troubleshoot)

### Service account and RBAC issues

#### Error: Service account not found

```output
Error: service account "aks-mcp" not found in namespace "default"
```

**Solution:**
1. Verify the service account exists:
   ```bash
   kubectl get serviceaccount aks-mcp -n <YOUR_NAMESPACE>
   ```
2. If not found, follow the [Service account creation guide](./cli-agent-for-aks-service-account-workload-identity-setup.md#step-1-create-the-kubernetes-service-account-mandatory)

#### Error: Permission denied errors

```output
Error: forbidden: User "system:serviceaccount:<namespace>:aks-mcp" cannot get resource "pods" in API group "" in the namespace "<namespace>"
```

**Solution:**
1. Verify RBAC permissions are correctly configured:
   ```bash
   kubectl get role aks-mcp-role -n <YOUR_NAMESPACE>
   kubectl get rolebinding aks-mcp-rolebinding -n <YOUR_NAMESPACE>
   ```
1. Check the RoleBinding associates the correct service account:
   ```bash
   kubectl describe rolebinding aks-mcp-rolebinding -n <YOUR_NAMESPACE>
   ```

### Workload identity issues

#### Error: Workload identity not enabled

```output
Error: workload identity is not enabled on this cluster
```

**Solution:**
1. Check if workload identity is enabled:
   ```azurecli-interactive
   az aks show --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME> --query "securityProfile.workloadIdentity.enabled"
   ```
2. If not enabled, follow the [workload identity setup guide](./cli-agent-for-aks-service-account-workload-identity-setup.md#verify-and-enable-workload-identity)

#### Error: Annotation missing

```output
Error: service account does not have workload identity annotation
```

**Solution:**
1. Check if the annotation exists:
   ```bash
   kubectl describe serviceaccount aks-mcp -n <YOUR_NAMESPACE>
   ```
2. If missing, add the annotation:
   ```bash
   kubectl annotate serviceaccount aks-mcp -n <YOUR_NAMESPACE> azure.workload.identity/client-id="<CLIENT_ID>" --overwrite
   ```

#### Error: Federated credential propagation delay

**Solution:**
- Wait 1-2 minutes for the federated identity credential to propagate across Azure services
- Verify the federated identity credential exists:
  ```azurecli-interactive
  az identity federated-credential list --identity-name <IDENTITY_NAME> --resource-group <RESOURCE_GROUP>
  ```



---

## Initialization issues

### Error: Extension not found

```output
ERROR: The command 'aks agent' is invalid or not supported. Use 'az aks --help' to see available commands
```

**Solution:**
1. Install the aks-agent extension:
   ```azurecli-interactive
   az extension add --name aks-agent --debug
   ```
2. Verify installation:
   ```azurecli-interactive
   az extension list | grep aks-agent
   ```




## Get help

For questions or issues, document the commands and outputs and open an issue directly on the [GitHub repository](https://github.com/Azure/cli-agent-for-aks/issues).

## Related content

- For installation instructions, see [Install and use the agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-install.md).
- For service account and workload identity setup, see [Service account creation and workload identity setup for the Agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-service-account-workload-identity-setup.md).
- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./cli-agent-for-aks-overview.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml).
