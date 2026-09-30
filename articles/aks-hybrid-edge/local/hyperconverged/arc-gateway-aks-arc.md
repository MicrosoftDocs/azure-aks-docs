---
title: Simplify network configuration requirements with Azure Arc gateway
description: Learn how to enable Arc gateway on AKS on Azure Local clusters to simplify network configuration requirements
ms.topic: how-to
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 04/20/2026
ms.custom: hyperconverged
---

# Simplify network configuration requirements with Azure Arc gateway

If you use enterprise proxies to manage outbound traffic, Azure Arc gateway can help simplify the process of enabling connectivity. Before using Arc gateway with AKS on Azure Local, ensure you complete the [prerequisites for creating AKS clusters on Azure Local](network-system-requirements.md).

The AKS gateway lets you:

- Connect to Azure Arc by opening public network access to only seven fully qualified domain names (FQDNs).
- View and audit all traffic that the Arc agents send to Azure via the Arc gateway.

## How the Azure Arc gateway works

The Arc gateway works by introducing an Azure resource that serves as a common front end for Azure traffic. The gateway resource is served on a specific domain/URL that simplifies network configuration requirements.

For more information, see [how the Azure Arc gateway works](/azure/azure-local/deploy/deployment-azure-arc-gateway-overview).

## Required network endpoints

For the complete list of required URLs and endpoints that must be allowed through your enterprise firewall when using Arc gateway with AKS on Azure Local, see [Azure Local endpoints not redirected through Arc gateway](/azure/azure-local/deploy/deployment-azure-arc-gateway-overview#azure-local-endpoints-not-redirected).

## Using Arc gateway with AKS clusters

If Arc gateway is enabled in your environment, newly created AKS clusters automatically utilize it to simplify network connectivity.

## Other scenarios

Arc gateway covers endpoints required for AKS clusters, and a portion of endpoints required for more Arc-enabled scenarios. Based on the scenarios you adopt, more endpoints must still be allowed in your proxy.

All endpoints listed for the following scenarios must be allowed in your enterprise proxy when Arc gateway is in use:

- [Container insights in Azure Monitor](/azure/azure-monitor/containers/kubernetes-monitoring-firewall):
  - `*.ods.opinsights.azure.com`
  - `*.oms.opinsights.azure.com`
  - `*.monitoring.azure.com`
- [Azure Key Vault](/azure/key-vault/general/access-behind-firewall):
  - `<vault-name>.vault.azure.net`
- [Azure Policy](/azure/governance/policy/concepts/policy-for-kubernetes):
  - `data.policy.core.windows.net`
  - `store.policy.core.windows.net`
- [Microsoft Defender for Containers](/azure/defender-for-cloud/defender-for-containers-enable?pivots=defender-for-container-arc&toc=%2Fazure%2Fazure-arc%2Fkubernetes%2Ftoc.json&bc=%2Fazure%2Fazure-arc%2Fkubernetes%2Fbreadcrumb%2Ftoc.json&tabs=aks-deploy-portal%2Ck8s-deploy-asc%2Ck8s-verify-asc%2Ck8s-remove-arc%2Caks-removeprofile-api):
  - `*.ods.opinsights.azure.com`
  - `*.oms.opinsights.azure.com`
- [Azure Arc-enabled data services](/azure/azure-arc/network-requirements-consolidated?tabs=azure-cloud)
  - `*.ods.opinsights.azure.com`
  - `*.oms.opinsights.azure.com`
  - `*.monitoring.azure.com`

## Next steps

- [Deploy extension for MetalLB for Azure Arc enabled Kubernetes clusters](deploy-load-balancer-cli.md).
