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

This article provides guidance on troubleshooting common issues with the agentic CLI for Azure Kubernetes Service (AKS).

## Common troubleshooting steps

If you run into any issues when you use the agentic CLI for AKS, try the following troubleshooting steps:

- Check that your large language model (LLM) provider is configured correctly. If you used `az aks agent-init` to set your LLM parameters, check your configuration file at `path/to/aksAgent.yaml`. If you use a custom configuration file, ensure that your parameters are set correctly.
- Check if you're using the right model by using the `--model` parameter (if needed for Azure OpenAI).
- Confirm cluster connectivity by using the `kubectl cluster-info` command.
- If you see requests retrying to `/chat/completions` in the responses, you're throttled by the token-per-minute (TPM) limits from the LLM. Increase the TPM limit or [apply for more quota](/azure/ai-foundry/openai/how-to/quota).
- If outputs vary, it might be because of LLM response variability or intermittent Model Context Protocol (MCP) server connections.
- Ensure that the deployment name is the same as the model name in the Azure OpenAI deployments.
- If the `aks-agent` installation is failing, try to uninstall the Azure CLI and reinstall the latest version.

## Common issues and solutions

### Error: The combined size of system_prompt and user_prompt (6090 tokens) exceeds the maximum context size of 4096 tokens available for input

This error typically happens for GPT-4, which has a smaller context window. Try using a different model.

### Error: litellm.NotFoundError: AzureException NotFoundError - The API deployment for this resource doesn't exist

If you're using Azure OpenAI, it's likely that the deployment name is different from the model name. Create a new deployment with the same name as the model name.

### Error: Couldn't find model's name azure/<> in litellm's model list

This error likely indicates that the deployment name was included in the model parameter and is different from the model name. Create a new deployment with the same name as the model name.

### Error: litellm.llms.azure.common_utils.AzureOpenAIError: Error code: 400 - Unsupported value: 'temperature' doesn't support 1E-8

Create an environment variable `TEMPERATURE` and set it to `1`. For example:

```bash
export TEMPERATURE=1
```

### ImportError: DLL load failed while importing win32file

Try reinstalling the Azure CLI client.

### Error: litellm.AuthenticationError: AzureException AuthenticationError - Access denied due to invalid subscription key

This error is likely because of an issue with the variables setup for the Azure OpenAI deployment. Check the configuration file, your environment variables, and the flags that you pass when you invoke the command. If there's a conflict, the tool uses the flags first, the configuration file next, and the environment variables as fallback.

## Get help

For questions or issues, document the commands and outputs and open an issue directly on the [GitHub repository](https://github.com/Azure/cli-agent-for-aks/issues).

## Related content

- For an overview of the agentic CLI for AKS, see [About the agentic CLI for AKS](./cli-agent-for-aks-overview.md).
- For answers to common questions about the agentic CLI for AKS, see [Agentic CLI for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml).
