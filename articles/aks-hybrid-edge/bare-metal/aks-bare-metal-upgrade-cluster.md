---
title: Upgrade Kubernetes on AKS on bare metal (preview)
description: Learn how to upgrade the Kubernetes version on your Azure Kubernetes Service on bare metal cluster using the Azure portal.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Upgrade Kubernetes clusters (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article shows you how to upgrade the Kubernetes version on your AKS on bare metal cluster using the Azure portal.

## Overview

AKS on bare metal supports in-place Kubernetes version upgrades. During an upgrade:

- The new Kubernetes binaries are downloaded to the host.
- The control plane components are upgraded.
- The node is cordoned, drained, and upgraded.
- Workloads are rescheduled after the upgrade completes.

> [!NOTE]
> Since AKS on bare metal uses a single-node topology during public preview, **workloads are temporarily unavailable** during the upgrade process.

## Upgrade the cluster

1. Sign in to the [Azure portal](https://portal.azure.com).
1. Navigate to your Kubernetes cluster resource.
1. In the left menu, expand **Settings** and select **Cluster configuration**.

   :::image type="content" source="../media/aks-bare-metal-upgrade-cluster/upgrade-cluster.png" alt-text="Screenshot of the Cluster configuration option for your AKS on bare metal cluster." lightbox="../media/aks-bare-metal-upgrade-cluster/upgrade-cluster.png":::
   
1. Under **Upgrade**, note your current Kubernetes version.
1. Select **Upgrade version**.
1. Select the target Kubernetes version and confirm.

The upgrade begins immediately. You can monitor the provisioning state on the cluster's **Overview** page.

## Supported upgrade paths

During public preview, the following Kubernetes versions are available:

| Version | Status |
|---------|--------|
| 1.34.2 | Supported |
| 1.34.3 | Supported (latest) |

> [!NOTE]
> You can only upgrade to a newer version. Downgrade isn't supported.

## Best practices

- **Schedule upgrades during maintenance windows** — The single-node topology means workloads are temporarily unavailable.
- **Back up critical workloads** — Use persistent storage backups before upgrading.
- **Test in a non-production cluster first** — If you have multiple clusters, upgrade the development cluster first.
- **Verify after upgrade** — Connect to the cluster and confirm the node version: `kubectl get nodes`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Upgrade stuck in `Upgrading` state | Wait up to 30 minutes. If it doesn't complete, check Arc agent connectivity. |
| Pods not rescheduling after upgrade | Verify node is in `Ready` state: `kubectl get nodes`. |
| Target version not available | Check the [supported upgrade paths](#supported-upgrade-paths) table for available versions. |

## Next steps

- [Public preview limitations](aks-bare-metal-preview-limitations.md)
- [Connect to your cluster](aks-bare-metal-connect-to-cluster.md)
