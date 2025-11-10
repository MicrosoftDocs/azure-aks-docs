---
title: Troubleshoot the Agentic CLI for Azure Kubernetes Service (AKS)
description: Learn how to troubleshoot the agentic CLI for Azure Kubernetes Service (AKS) to resolve common issues and improve performance.
ms.topic: troubleshooting-general
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to troubleshoot issues with the AI-powered CLI Agent for AKS to ensure it functions correctly and provides accurate insights.
---

# Troubleshoot the agentic CLI for Azure Kubernetes Service (AKS)

This article provides guidance on troubleshooting common issues with the agentic CLI for Azure Kubernetes Service (AKS).

## Common troubleshooting steps

If you run into any issues using the agentic CLI for AKS, try the following troubleshooting steps:

- Check that your LLM provider is configured correctly. If you used `az aks agent-init` to set your LLM parameters, check your config file at `path/to/aksAgent.yaml`. If you're using a custom config file, ensure that your parameters are set correctly.
- Check if you're using the right model using the `--model` parameter (if needed for Azure OpenAI).
- Confirm cluster connectivity using the `kubectl cluster-info` command.
- If you see requests retrying to `/chat/completions` in the responses, you're throttled by the token per minute (TPM) limits from the LLM. Increase the TPM limit or [apply for more quota](/azure/ai-foundry/openai/how-to/quota).
- If outputs vary, it might be due to LLM response variability or intermittent MCP server connections.
- Ensure that the deployment name is the same as the model name in the Azure OpenAI deployments.
- If the `aks-agent` installation is failing, try to uninstall and reinstall the latest Azure CLI.

## Common issues and solutions

### Error: The combined size of system_prompt and user_prompt (6090 tokens) exceeds the maximum context size of 4096 tokens available for input

This error typically happens for GPT-4, which has a smaller context window. Try using a different model.

### Error: litellm.NotFoundError: AzureException NotFoundError - The API deployment for this resource doesn't exist

If you're using Azure OpenAI, it's likely that the deployment name is different from the model name. Create a new deployment with the same name as the model name.

### Error: Couldn't find model's name azure/<> in litellm's model list

This error likely indicates the deployment name was included in the model parameter and is different from the model name. Create a new deployment with the same name as the model name.

### Error: litellm.llms.azure.common_utils.AzureOpenAIError: Error code: 400 - Unsupported value: 'temperature' doesn't support 1E-8

Create an environment variable `TEMPERATURE` and set it to _1_. For example:

```bash
export TEMPERATURE=1
```

### ImportError: DLL load failed while importing win32file

Try reinstalling the Azure CLI client.

### Error: litellm.AuthenticationError: AzureException AuthenticationError - Access denied due to invalid subscription key

This error is likely due to an issue with the variables setup for the Azure OpenAI deployment. Check the config file, your environment variables, and the flags you pass while invoking the command. In the event of conflict, the tool uses the flags first, the config file next, and the environment variables as fallback.

## Get help

For questions or issues, document the commands and outputs and open an issue directly on the [GitHub repository](https://github.com/Azure/cli-agent-for-aks/issues).

## Related content

- For an overview of the agentic CLI for AKS, see [About the agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-overview.md).
- [Agentic CLI for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml) answers common questions about the agentic CLI for AKS.
