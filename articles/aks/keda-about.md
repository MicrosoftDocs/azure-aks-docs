---
title: Kubernetes Event-Driven Autoscaling (KEDA) in Azure Kubernetes Service (AKS)
description: Learn how to use KEDA for event-driven autoscaling in AKS, including AKS Automatic where KEDA is preconfigured by default and AKS Standard where KEDA is enabled as an add-on.
author: tomkerkhove
ms.topic: concept-article
ms.date: 05/23/2025
ms.service: azure-kubernetes-service
ms.custom: aks-scaling
ms.author: schaffererin
# Customer intent: As a cloud engineer, I want to implement event-driven autoscaling in my Kubernetes environment using KEDA, so that I can optimize my application performance and resource usage while ensuring cost efficiency.
---

# Simplified application autoscaling with Kubernetes Event-driven Autoscaling (KEDA) add-on in Azure Kubernetes Service (AKS)

[!INCLUDE [change value callout](./includes/keda/change-value-callout.md)]

Kubernetes Event-driven Autoscaling (KEDA) is a single-purpose and lightweight component that makes application autoscaling simple. It's a Cloud Native Computing Foundation (CNCF) Graduate project. KEDA uses event-driven autoscaling to scale your application to meet demand in a sustainable and cost-efficient manner with scale-to-zero.

For most production workloads, AKS Automatic is the recommended default AKS experience. AKS Automatic is production ready by default and includes KEDA preconfigured on the cluster. If you use AKS Standard, you can enable KEDA by using the managed KEDA add-on.

To learn more about AKS Automatic, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

> [!NOTE]
> KEDA version 2.15+ introduces a breaking change that [removes pod identity support](https://github.com/kedacore/keda/issues/5035). We recommend moving over to workload identity for your authentication if you're using pod identity. While the KEDA managed add-on doesn't currently run KEDA version 2.15+, the managed add-on will begin running KEDA 2.15+ in AKS preview version 1.32.
>
> For more information on how to securely scale your applications with workload identity, read our [tutorial][keda-workload-identity]. To view KEDA's breaking change/deprecation policy, read their [official documentation][keda-support-policy].

## KEDA in AKS Automatic and AKS Standard

KEDA is available in both AKS cluster modes, but the setup path is different:

- **AKS Automatic**: KEDA is preconfigured and ready to use.
- **AKS Standard**: Enable KEDA by turning on the AKS managed add-on.

For most production scenarios, start with AKS Automatic to use production-ready defaults and reduce cluster management overhead.

## Architecture

[KEDA][keda] provides two main components:

- **KEDA operator** allows end-users to scale workloads in or out from 0 to N instances with support for Kubernetes Deployments, Jobs, `StatefulSets`, or any custom resource that defines `/scale` subresource.
- **Metrics server** exposes external metrics to Horizontal Pod Autoscaler (HPA) in Kubernetes for autoscaling purposes such as messages in a Kafka topic, or number of events in an Azure event hub. Due to upstream limitations, KEDA must be the only installed external metric adapter.

:::image type="content" source="./media/keda/architecture.png" alt-text="Diagram that shows the architecture of KEDA and how it extends Kubernetes.":::

Learn more about how KEDA works in the [official KEDA documentation][keda-architecture].

## Installation and enablement

### AKS Automatic

KEDA is preconfigured in AKS Automatic. No separate KEDA add-on installation step is required.

### AKS Standard

Enable KEDA on AKS Standard by using one of the following methods:

- [Enable the KEDA add-on with Azure CLI][keda-cli]
- [Enable the KEDA add-on with an ARM template][keda-arm]

The managed KEDA add-on provides a fully supported KEDA installation integrated with AKS.

## Capabilities and features

KEDA provides the following capabilities and features:

- Scale workloads to zero when demand drops.
- Scale application workloads to meet demand using [Azure KEDA scalers][keda-scalers].
- Autoscale applications by using `ScaledObjects`, such as Deployments, `StatefulSets`, or any custom resource that defines the `/scale` subresource.
- Autoscale job-like workloads by using `ScaledJobs`.
- Use production-grade security by decoupling autoscaling authentication from workloads.
- Bring your own external scaler for custom autoscaling logic.
- Integrate with [Microsoft Entra Workload ID][workload-identity] for authentication.

In AKS Automatic, you get these event-driven autoscaling capabilities by default because the cluster is preconfigured with KEDA.

> [!NOTE]
> If you plan to use workload identity on AKS Standard, [enable workload identity][workload-identity-deploy] before enabling the KEDA add-on.

## Production guidance

Use this guidance to choose your cluster mode:

- Choose AKS Automatic when you want a production-ready default experience with KEDA preconfigured.
- Choose AKS Standard when you need deeper cluster-level customization and explicit add-on management.
- Use KEDA in either mode for event-driven autoscaling workloads.

## Add-on limitations

The KEDA AKS add-on has the following limitations:

- KEDA's [HTTP add-on (preview)][keda-http-add-on] to scale HTTP workloads isn't installed with the extension, but can be deployed separately.
- KEDA's [external scaler for Azure Cosmos DB][keda-cosmos-db-scaler] to scale based on Azure Cosmos DB change feed isn't installed with the extension, but can be deployed separately.
- Only one external metric server is allowed in the Kubernetes cluster. Because of that the KEDA add-on should be the only external metrics server inside the cluster.
  - Multiple KEDA installations aren't supported
- It's not recommended to combine KEDA's `ScaledObject` with a Horizontal Pod Autoscaler (HPA) to scale the same workload. They compete with each other because KEDA uses Horizontal Pod Autoscaler (HPA) in the background and results in odd scaling behavior.
  - If an HPA is created first, then a KEDA `ScaledObject` is created and the KEDA `ScaledObject` would fail to be created.
  - If a KEDA `ScaledObject` is created first and then an HPA is created, the HPA creation isn't blocked.

For general KEDA questions, we recommend [visiting the FAQ overview][keda-faq].

[!INCLUDE [Current version callout](./includes/keda/keda-workload-identity-callout.md)]

## Supported Kubernetes and KEDA versions

Your cluster Kubernetes version determines which KEDA version is installed on your AKS cluster. To see which KEDA version maps to each AKS version, see the **AKS managed add-ons** column of the [Kubernetes component version table](./supported-kubernetes-versions.md#aks-components-breaking-changes-by-version).

For GA Kubernetes versions, AKS offers full support of the corresponding KEDA minor version in the table. Kubernetes preview versions and the latest KEDA patch are partially covered by customer support on a best-effort basis. As such, these features aren't meant for production use. For more information, see the following support articles:

- [AKS support policies][support-policies]
- [Azure support FAQ][azure-support-faq]

## Related content

- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Enable the KEDA add-on with an ARM template (AKS Standard)][keda-arm]
- [Enable the KEDA add-on with the Azure CLI (AKS Standard)][keda-cli]
- [Troubleshoot KEDA add-on problems][keda-troubleshoot]
- [Autoscale a .NET Core worker processing Azure Service Bus Queue messages][keda-sample]
- [View the upstream KEDA docs][keda]

<!-- LINKS - internal -->
[keda-cli]: keda-deploy-add-on-cli.md
[keda-arm]: keda-deploy-add-on-arm.md
[keda-troubleshoot]: /troubleshoot/azure/azure-kubernetes/troubleshoot-kubernetes-event-driven-autoscaling-add-on?context=/azure/aks/context/aks-context
[workload-identity]: ./workload-identity-overview.md
[workload-identity-deploy]: ./workload-identity-deploy-cluster.md
[support-policies]: ./support-policies.md
[keda-workload-identity]: ./keda-workload-identity.md

<!-- LINKS - external -->
[keda]: https://keda.sh/
[keda-architecture]: https://keda.sh/docs/latest/concepts/
[keda-faq]: https://keda.sh/docs/2.14/reference/faq/
[keda-sample]: https://github.com/kedacore/sample-dotnet-worker-servicebus-queue
[keda-scalers]: https://keda.sh/docs/scalers/
[keda-http-add-on]: https://github.com/kedacore/http-add-on
[keda-cosmos-db-scaler]: https://github.com/kedacore/external-scaler-azure-cosmos-db
[azure-support-faq]: https://azure.microsoft.com/support/legal/faq/
[keda-support-policy]: https://github.com/kedacore/governance/blob/main/DEPRECATIONS.md
