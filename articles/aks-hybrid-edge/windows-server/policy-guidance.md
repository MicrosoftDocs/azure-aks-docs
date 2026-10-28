---
title: Azure policy guidance for AKS on Windows Server
description: Learn about best practices and guidance in using Azure policy in AKS on Windows Server.
ms.topic: best-practice
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.lastreviewed: 05/03/2023
ms.reviewer: sulahiri
ms.custom: windows-server

---

# Azure policy in AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article provides guidance on applying Azure policies to management clusters and recommendations for deploying AKS on Windows Server.

## Best practices in using Azure policies

Azure policies are set at the subscription level. By default, the policies apply to both management and target/workload clusters.

### Different subscriptions for different environments

Before launching a policy in production, a best practice is to test it in a preproduction environment. Because policies are set at the subscription level, it's best to keep preproduction and production environments on separate subscriptions.

### Policy testing in audit mode

Before enforcing a policy in preproduction or production environments, verify its functionality in audit mode.

## Considerations for applying Azure policies to Kubernetes management clusters

You shouldn't enable enforcement mode for Azure policy on management clusters, because management clusters don't run customer workloads. Enforcing Azure policies can cause some pods not to start.

### Disable enforcement mode on management clusters

The management cluster and target cluster, being on the same subscription, inherit the same Azure policies by default. To prevent management clusters from running Azure policies in enforcement mode, place the management and target clusters in different resource groups and apply an exclusion policy to the management cluster resource group. For more information about exclusion policy application, see [Azure Policy exemption structure](/azure/governance/policy/concepts/exemption-structure).

### Monitor management clusters

Azure policies are primarily for declarative compliance validation, not behavior-based threat detection. If there's concern about the security posture of the management cluster, a threat monitoring tool to track suspicious activities should be evaluated.

## Next steps

[Security concepts in AKS on Windows Server](concepts-security.md)
