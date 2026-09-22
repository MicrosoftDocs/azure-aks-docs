---
title: Troubleshoot AKS on Bare Metal on Ubuntu
description: Resolve Azure Arc, extension, permission, network, and deployment issues for AKS on bare metal on Ubuntu.
ms.topic: troubleshooting-general
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Troubleshoot Ubuntu deployments

Use this guidance for Azure Kubernetes Service (AKS) on bare metal on Ubuntu.

## The Arc-enabled server is disconnected

Check the Azure Connected Machine agent:

```bash
sudo azcmagent check
sudo systemctl status himdsd
```

Verify the Azure resource status:

```azurecli
az connectedmachine show \
  --resource-group <resource-group> \
  --name <host-name> \
  --query status \
  --output tsv
```

If the status is `Disconnected`, check DNS, proxy, firewall, and outbound endpoint access. For detailed Azure Arc guidance, see [Troubleshoot Azure Arc-enabled servers agent connection issues](/azure/azure-arc/servers/troubleshoot-agent-onboard).

## The aksarc command isn't available

Update Azure CLI, then install or update the public extension:

```azurecli
az upgrade
az extension add --name aksarc --upgrade --allow-preview true
```

The `deploy` and `undeploy` commands require the public-preview release of the extension.

## Deployment fails with an authorization error

Confirm that your role assignment is active and permanent. You need Owner, or Contributor plus User Access Administrator, on the resource group. Also verify that all six required resource providers and both public-preview features are registered.

## Deployment can't resolve the Microsoft.AzureStackHCI service principal

The deployment can fail with the following error:

```output
Could not resolve the Microsoft.AzureStackHCI resource provider service
principal through Microsoft Graph. Supply its tenant-specific object ID with
--hci-rp-object-id or the HCI_RP_OBJECT_ID environment variable. Original
error: AADSTS53003: Access has been blocked by Conditional Access policies.
The access policy does not allow token issuance.
```
To resolve the issue, get the tenant-specific object ID of the `Microsoft.AzureStackHCI` resource provider service principal:

```azurecli
HCIRP_OBJECT_ID=$(az ad sp show \
  --id 1412d89f-b8a8-4111-b4fd-e82905cbd85d \
  --query id \
  --output tsv)
```
If your session can't run the Microsoft Graph query because of Conditional Access, ask your Microsoft Entra administrator to run the command and provide the object ID.
Pass the object ID to the deployment command:

```azurecli
az aksarc deploy \
  --resource-group <resource-group> \
  --arc-machine-names <host-name> \
  --hci-rp-object-id "$HCIRP_OBJECT_ID"
```

## Deployment times out

Confirm that the host meets the minimum CPU, memory, and disk requirements and can reach `mcr.microsoft.com`, `*.data.mcr.microsoft.com`, and Azure management endpoints over HTTPS. Keep the Azure Arc connection active throughout deployment.

## Retry a failed deployment

Remove the incomplete cluster before you retry:

```azurecli
az aksarc undeploy \
  --resource-group <resource-group> \
  --arc-machine-names <host-name> \
  --yes
```

Then run the deployment command again.

## Next steps

- [Review Ubuntu requirements](aks-bare-metal-ubuntu-system-requirements.md).
- [Troubleshoot cluster connectivity](aks-bare-metal-troubleshoot-connectivity.md).
