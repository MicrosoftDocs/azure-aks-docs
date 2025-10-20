---
title: Troubleshoot the CLI Agent for Azure Kubernetes Service (AKS)
description: Learn how to troubleshoot the CLI Agent for Azure Kubernetes Service (AKS) to resolve common issues and improve performance.
ms.topic: troubleshooting-general
ms.date: 10/20/2025
author: aritragho
ms.author: aritragho
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to troubleshoot issues with the AI-powered CLI Agent for AKS to ensure it functions correctly and provides accurate insights.
---

# Troubleshoot the CLI Agent for Azure Kubernetes Service (AKS)

This article provides guidance on troubleshooting common issues with the CLI Agent for Azure Kubernetes Service (AKS).

## Common troubleshooting steps

If you run into any issues using the CLI Agent for AKS, verify the following:

- Make sure your API keys and environment variables are set correctly.
- Check if you're using the right model using the `--model` parameter (if needed for Azure OpenAI).
- Confirm cluster connectivity using the `kubectl cluster-info` command.
- If you see requests retrying to `/chat/completions` in the responses, you're throttled by the token per minute (TPM) limits from the LLM. Increase the TPM limit or apply for more quota [here](https://learn.microsoft.com/azure/ai-foundry/openai/quotas-limits?tabs=REST#request-quota-increases)
- If outputs vary, it may be due to LLM response variability or intermittent MCP server connections
- The Azure-specific variables cannot be passed as parameters to the command; they explicitly need to be set as environment variables (AZURE_API_BASE, AZURE_API_VERSION, AZURE_API_KEY). The model can be used as a parameter
- Ensure that the deployment name is the same as the model name in the Azure OpenAI deployments
- If the `aks-agent` installation is failing, try to uninstall and reinstall the latest Azure CLI

### Common errors

**Error: The combined size of system_prompt and user_prompt (6090 tokens) exceeds the maximum context size of 4096 tokens available for input**

This error typically happens for GPT-4 which has a smaller context window. Try using a different model.

**Error: litellm.NotFoundError: AzureException NotFoundError - The API deployment for this resource does not exist**

If you're using Azure OpenAI, it's very likely that the deployment name is different from the model name. Create a new deployment with the same name as the model name.

**Couldn't find model's name azure/<> in litellm's model list**

This likely indicates the deployment name was included in the model parameter and is different from the model name. Create a new deployment with the same name as the model name.

**Error: litellm.llms.azure.common_utils.AzureOpenAIError: Error code: 400 - Unsupported value: 'temperature' does not support 1E-8**

Create an environment variable `TEMPERATURE` and set it to 1:

```bash
export TEMPERATURE=1
```

**ImportError: DLL load failed while importing win32file**

Try reinstalling the Azure CLI client. This is a commonly seen issue.

**Error: litellm.AuthenticationError: AzureException AuthenticationError - Access denied due to invalid subscription key**

This is likely due to an issue with the variables setup for the Azure OpenAI deployment. Check the config file, your environment variables, and the flags you pass while invoking the command. In case of conflict, the tool uses the flags first, the config file next, and the environment variables as fallback.

### Getting help

For questions or issues, document the commands and outputs and open an issue directly on the [GitHub repository](https://github.com/Azure/cli-agent-for-aks/issues).

You can also reach out directly to [aksagentcli@service.microsoft.com](mailto:aksagentcli@service.microsoft.com) with any feedback or questions.