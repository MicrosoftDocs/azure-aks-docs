---
title: Troubleshoot the Agentic CLI for Azure Kubernetes Service (AKS) (preview)
description: Learn how to troubleshoot the agentic CLI for Azure Kubernetes Service (AKS) to resolve common issues and improve performance.
ms.topic: troubleshooting-general
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
zone_pivot_groups: agentic-cli-deployment-mode
# Customer intent: As a cluster administrator or SRE, I want to troubleshoot issues with the AI-powered CLI agent for AKS to ensure that it functions correctly and provides accurate insights.
---

# Troubleshoot the agentic CLI for Azure Kubernetes Service (AKS) (preview)

This article provides guidance on troubleshooting common issues with the agentic CLI for Azure Kubernetes Service (AKS).

## Common troubleshooting steps

If you run into any issues when you use the agentic CLI for AKS, try the following troubleshooting steps:

- If you see requests retrying to `/chat/completions` in the responses, you might be throttled by the token-per-minute (TPM) limits from the LLM. Increase the TPM limit or [apply for more quota](/azure/ai-foundry/openai/how-to/quota).
- If outputs vary, it might be because of LLM response variability or intermittent Model Context Protocol (MCP) server connections.
- Ensure that the deployment name is the same as the model name in the Azure OpenAI deployments.
- If the `aks-agent` installation is failing, try to uninstall the Azure CLI and reinstall the latest version.

:::zone pivot="client-mode"

## Docker-related issues

### Error: Docker daemon not running

```output
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
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

### Error: Docker permission denied

```output
Got permission denied while trying to connect to the Docker daemon socket
```

To resolve Docker permission issues, ensure your user has the necessary permissions to access the Docker daemon using the steps for your operating system:

- **macOS / Windows**:
  - Restart Docker Desktop to ensure it has the necessary permissions.
- **Linux**:
  - Add your user to the docker group to allow non-root access to Docker using the following commands:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker  # Apply group changes immediately
   ```

### Error: Docker image pull failures

```output
Error response from daemon: pull access denied for aks-agent, repository does not exist or may require 'docker login'
```

To resolve Docker image pull failures, try the following steps:

- Ensure you have internet connectivity.
- Check if corporate firewalls are blocking Docker registry access.
- Try initializing the agent again with `az aks agent-init`.

## Azure credentials issues

### Error: Azure authentication failed

To resolve Azure authentication issues, ensure your Azure CLI is properly authenticated and has access to the necessary resources using the following steps:

1. Verify your Azure credentials are properly configured using the [`az account show`](/cli/azure/account#az-account-show) command.

   ```azurecli-interactive
   az account show
   ```

1. If needed, sign in again using the [`az login`](/cli/azure/authenticate-azure-cli#az-login) command.

   ```azurecli-interactive
   az login
   ```

:::zone-end

:::zone pivot="cluster-mode"

## Service account and RBAC issues

### Error: Service account not found

```output
Error: service account "aks-mcp" not found in namespace "default"
```

To resolve service account issues, ensure the Kubernetes service account is properly created and configured using the following steps:

1. Verify the service account exists using the following command:

   ```bash
   kubectl get serviceaccount aks-mcp --namespace $NAMESPACE
   ```

1. If the service account isn't found, create one using the steps in [Create a service account and configure workload identity for the agentic CLI for Azure Kubernetes Service (AKS) (preview)](./agentic-cli-for-aks-service-account-workload-identity-setup.md)

### Error: Permission denied errors

```output
Error: forbidden: User "system:serviceaccount:<namespace>:aks-mcp" cannot get resource "pods" in API group "" in the namespace "<namespace>"
```

To resolve permission denied errors, ensure the Kubernetes service account has the necessary RBAC permissions using the following steps:

1. Verify RBAC permissions are correctly configured using the following commands:

   ```bash
   kubectl get role aks-mcp-role --namespace $NAMESPACE
   kubectl get rolebinding aks-mcp-rolebinding --namespace $NAMESPACE
   ```

1. Check the RoleBinding associates the correct service account with the Role using the following command:

   ```bash
   kubectl describe rolebinding aks-mcp-rolebinding --namespace $NAMESPACE
   ```

## Workload identity issues

### Error: Workload identity not enabled

```output
Error: workload identity is not enabled on this cluster
```

If you receive an error indicating that workload identity isn't enabled, verify that your AKS cluster has workload identity enabled using the following steps:

1. Check if workload identity is enabled on your AKS cluster using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

   ```azurecli-interactive
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "securityProfile.workloadIdentity.enabled"
   ```

1. If workload identity isn't enabled, follow the steps in [Create a service account and configure workload identity for the agentic CLI for Azure Kubernetes Service (AKS) (preview)](./agentic-cli-for-aks-service-account-workload-identity-setup.md) to enable workload identity on your cluster.

### Error: Annotation missing

```output
Error: service account does not have workload identity annotation
```

To resolve missing annotation errors, ensure the Kubernetes service account has the correct workload identity annotation using the following steps:

1. Check if the annotation exists on the service account using the following command:

   ```bash
   kubectl describe serviceaccount aks-mcp --namespace $NAMESPACE
   ```

1. If the annotation is missing, add it using the following command. Make sure to replace `$CLIENT_ID` with the actual client ID of the federated identity credential.

   ```bash
   kubectl annotate serviceaccount aks-mcp --namespace $NAMESPACE azure.workload.identity/client-id="$CLIENT_ID" --overwrite
   ```

### Error: Federated credential propagation delay

If you receive errors related to the federated identity credential not being found or authentication failures, it might be due to propagation delays after creating the federated identity credential in Azure. To resolve this issue, try the following steps:

1. Wait a few minutes for the federated identity credential to propagate across Azure services.
1. Verify the federated identity credential exists using the [`az identity federated-credential list`](/cli/azure/identity/federated-credential#az-identity-federated-credential-list) command.

  ```azurecli-interactive
  az identity federated-credential list --identity-name $IDENTITY_NAME --resource-group $RESOURCE_GROUP
  ```

:::zone-end

## Initialization issues

### Error: Extension not found

```output
ERROR: The command 'aks agent' is invalid or not supported. Use 'az aks --help' to see available commands
```

To resolve extension not found errors, ensure the `aks-agent` extension is properly installed and loaded using the following steps:

1. Install the `aks-agent` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

   ```azurecli-interactive
   az extension add --name aks-agent --debug
   ```

1. Verify successful installation using the [`az extension list`](/cli/azure/extension#az-extension-list) command.

    ```azurecli-interactive
    az extension list
    ```

    Your output should include an entry for `aks-agent`.

## Related content

- For installation instructions, see [Install and use the agentic CLI for AKS](./agentic-cli-for-aks-install.md).
- For service account and workload identity setup, see [Create a service account and configure workload identity for the agentic CLI for AKS](./agentic-cli-for-aks-service-account-workload-identity-setup.md).
- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./agentic-cli-for-aks-overview.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS FAQ](./agentic-cli-for-aks-faq.yml).
