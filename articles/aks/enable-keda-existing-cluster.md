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

[!INCLUDE [Current version callout](./includes/keda/current-version-callout.md)]

> [!NOTE]
> KEDA version 2.15 introduces a breaking change that [removes pod identity support](https://github.com/kedacore/keda/issues/5035). We recommend moving over to workload identity for your authentication if you're using pod identity. While the KEDA managed add-on doesn't currently run KEDA version 2.15, it will begin running it in the AKS preview version 1.31.
>
> For more information on how to securely scale your applications with workload identity, please read our [tutorial][keda-workload-identity]. To view KEDA's breaking change/deprecation policy, please read their [official documentation][keda-support-policy].

## Before you begin

- You need an Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- Ensure you have firewall rules configured to allow access to the Kubernetes API server. For more information, see [Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters][aks-firewall-requirements].

[!INCLUDE [KEDA workload ID callout](./includes/keda/keda-workload-identity-callout.md)]

## Enable the KEDA add-on on an existing AKS cluster

## Verify KEDA is running on your cluster

## Verify the KEDA version on your cluster

## Disable the KEDA add-on on your AKS cluster

## Next steps

<!-- LINKS - internal -->

<!-- LINKS - external -->
