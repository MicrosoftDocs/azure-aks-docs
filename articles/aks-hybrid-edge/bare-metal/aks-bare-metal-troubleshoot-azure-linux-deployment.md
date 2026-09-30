---
title: Troubleshoot AKS on Bare Metal on Azure Linux
description: Resolve common deployment, upgrade, and deletion issues for AKS on bare metal on Azure Linux and validated Azure Local hardware.
ms.topic: troubleshooting-general
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Troubleshoot Azure Linux deployments

Use this guidance for Azure Kubernetes Service (AKS) on bare metal on Azure Linux and validated Azure Local small form factor hardware.

## Deployment doesn't complete

1. Confirm that all required Azure resource providers and preview features are registered.
1. Verify that the Azure Local host and Azure Arc resources are connected.
1. Confirm that the host can reach the required outbound endpoints.
1. Open the resource group **Deployments** page and review the failed deployment operation.

## Upgrade remains in progress

Wait up to 30 minutes, then confirm that the host remains connected to Azure Arc. Because the preview uses a single-node cluster, workloads are unavailable while the node is cordoned, drained, and upgraded.

## Resource deletion fails

Delete resources in the order documented in [Delete AKS on bare metal cluster resources on Azure Linux](aks-bare-metal-delete-cluster-resources.md). Wait for cluster deletion to finish before deleting dependent resources.

## Next steps

- [Troubleshoot cluster connectivity](aks-bare-metal-troubleshoot-connectivity.md).
