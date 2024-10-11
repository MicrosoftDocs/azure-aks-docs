---
title: Enable the Kubernetes Event-driven Autoscaling (KEDA) add-on on an existing AKS cluster
description: Use the Azure portal to enable the Kubernetes Event-driven Autoscaling (KEDA) add-on on an existing Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.date: 09/19/2024
ms.service: azure-kubernetes-service
---

# Enable the Kubernetes Event-driven Autoscaling (KEDA) add-on on an existing AKS cluster using the Azure portal

This article shows you how to enable the Kubernetes Event-driven Autoscaling (KEDA) add-on on an existing Azure Kubernetes Service (AKS) cluster using the Azure portal.

[!INCLUDE [Current version callout](./includes/keda/current-version-callout.md)]

> [!NOTE]
> KEDA version 2.15 introduces a breaking change that [removes pod identity support](https://github.com/kedacore/keda/issues/5035). We recommend moving over to workload identity for your authentication if you're using pod identity. While the KEDA managed add-on doesn't currently run KEDA version 2.15, it will begin running it in the AKS preview version 1.31.
>
> For more information on how to securely scale your applications with workload identity, please read our [tutorial][keda-workload-identity]. To view KEDA's breaking change/deprecation policy, please read their [official documentation][keda-support-policy].

## Before you begin

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- An existing AKS cluster. If you don't have an AKS cluster, create one using the steps in [Deploy an Azure Kubernetes Service (AKS) cluster](./learn/quick-kubernetes-deploy-portal.md).
- Ensure you have firewall rules configured to allow access to the Kubernetes API server. For more information, see [Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters][aks-firewall-requirements].

[!INCLUDE [KEDA workload ID callout](./includes/keda/keda-workload-identity-callout.md)]

## Enable the KEDA add-on on an existing AKS cluster

1. Sign in to the [Azure portal](https://portal.azure.com/) and navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Application scaling** > **Enable KEDA add-on**.

    It may take a few minutes for the changes to take effect.

1. Once the KEDA add-on is enabled, you can [verify KEDA is running on your cluster](#verify-keda-is-running-on-your-cluster).

## Verify KEDA is running on your cluster

1. From the service menu of your AKS cluster resource, under **Kubernetes resources**, select **Workloads**.
1. Select the **Pods** tab, and look for the `keda` pods. If they're listed, KEDA is successfully running on your cluster.

    :::image type="content" source="./media/enable-keda-existing-cluster/keda-pods.png" alt-text="Screenshot of the KEDA pods running on the existing AKS cluster.":::

1. Once you verify that KEDA is running, you can [check the KEDA version on your cluster](#check-the-keda-version-on-your-cluster).

## Check the KEDA version on your cluster

1. From the service menu of your AKS cluster resource, under **Kubernetes resources**, select **Custom resources**.
1. Find the **keda.sh** resource. From there, you can view the KEDA version running on your cluster.

    :::image type="content" source="./media/enable-keda-existing-cluster/keda-version.png" alt-text="Screenshot of the KEDA CRD that shows the KEDA version running on the AKS cluster.":::

## Disable the KEDA add-on on an existing cluster

To disable the KEDA add-on, see [Disable the KEDA add-on on your AKS cluster](./keda-deploy-add-on-cli.md#disable-the-keda-add-on-on-your-aks-cluster).

## Next steps

In this article, you learned how to enable the KEDA add-on on an existing AKS cluster using the Azure portal. With the KEDA add-on installed on your cluster, you can [deploy a sample application][keda-sample] to start scaling apps.

For information on KEDA troubleshooting, see [Troubleshoot the Kubernetes Event-driven Autoscaling (KEDA) add-on][keda-troubleshoot]. For more information on KEDA, see the [upstream KEDA docs][keda].

<!-- LINKS - internal -->
[keda-troubleshoot]: /troubleshoot/azure/azure-kubernetes/troubleshoot-kubernetes-event-driven-autoscaling-add-on?context=/azure/aks/context/aks-context
[aks-firewall-requirements]: outbound-rules-control-egress.md#azure-global-required-network-rules
[keda-workload-identity]: ./keda-workload-identity.md

<!-- LINKS - external -->
[keda-sample]: https://github.com/kedacore/sample-dotnet-worker-servicebus-queue
[keda]: https://keda.sh/docs/2.12/
[keda-support-policy]: https://github.com/kedacore/governance/blob/main/DEPRECATIONS.md
