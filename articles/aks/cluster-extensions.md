---
title: Cluster extensions for Azure Kubernetes Service (AKS)
description: Learn how to deploy and manage the lifecycle of cluster extensions on Azure Kubernetes Service (AKS).
ms.date: 09/09/2025
ms.topic: overview
ms.subservice: aks-developer
author: davidsmatlak
ms.author: davidsmatlak
ai-usage: ai-assisted

# Customer intent: As a Kubernetes administrator, I want to deploy and manage cluster extensions on Azure Kubernetes Service so that I can enhance my cluster's capabilities and streamline the lifecycle management of related applications and services.
---

# Deploy and manage cluster extensions for Azure Kubernetes Service (AKS)

Cluster extensions provide an Azure Resource Manager driven experience for installation and lifecycle management of services like Azure Machine Learning or Kubernetes applications on an AKS cluster. This feature enables:

- Azure Resource Manager-based deployment of extensions, including at-scale deployments across AKS clusters.
- Lifecycle management of the extension (Update, Delete) from Azure Resource Manager.

## Categories of cluster extensions

There are two categories of cluster extensions, _Core_ and _Standard_ that can be deployed onto AKS clusters.

### Core extensions

Core Kubernetes extensions have broader region availability, a more integrated AKS experience, and release alignment to AKS version releases. Azure Backup and Azure Monitoring for Containers are core extensions.

#### AKS native experience

Core extensions can be managed using `az aks` CLI command.

```azurecli
az aks extension create \
  --name <core extension name> \
  --extension-type <type> \
  --cluster-name <name> \
  --resource-group <group>
```

For more information about the commands, see [`az aks`](/cli/azure/aks).

#### Release policy

Minor and major upgrades of core extensions occur alongside AKS minor and major version updates to avoid introducing breaking changes and provide better reliability.

### Add-on to core extension migration

[Azure Monitor](/azure/azure-monitor/containers/kubernetes-monitoring-overview) services, including [Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli), [Managed Prometheus](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli), and [Application Insights](/azure/azure-monitor/containers/kubernetes-codeless?tabs=portal) are transitioning to a cluster extension based backend model. This change updates AKS monitoring [add-ons](/azure/aks/integrations) to an extension‑based management model, with no change to functionality or user experience.

- This backend migration is nondisruptive and doesn't change user experience or require customer action.

- There's no impact to workloads, data collection, or monitoring functionality.

- Azure CLI, Azure portal, and all client experiences continue to work as expected.

> [!NOTE]
> - **Azure policy restrictions:** Custom Azure policies that block creation or updates to the [cluster extensions resource type](/rest/api/kubernetesconfiguration/extensions/extensions/create) must be updated or exempted.
> - **Azure resource locks:** Azure resource locks can block management of [cluster extensions resource type](/rest/api/kubernetesconfiguration/extensions/extensions/create).
>
> Refer to the [troubleshooting](https://aka.ms/k8s-extensions-tsg) documentation for mitigation details.

### Standard extensions

For information about the other cluster extensions, see the table in [Currently available extensions](cluster-extensions.md#currently-available-extensions) and the [Kubernetes apps](deploy-marketplace.md) deployed via Azure Marketplace are of the Standard Extension type.

Standard extensions can be managed using the `az k8s-extension` CLI command. For more information, see [Deploy and manage cluster extensions by using Azure CLI](deploy-extensions-az-cli.md).

```azurecli
az k8s-extension create \
  --name <standard extension name> \
  --extension-type <extension-type> \
  --scope cluster \
  --cluster-name <clusterName> \
  --resource-group <resourceGroupName> \
  --cluster-type managedClusters
```

## Cluster extension requirements

The cluster extensions platform is supported in all regions where AKS is deployed. Although the platform is available in all regions, check the region availability for individual extensions.

> [!IMPORTANT]
> Ensure that your AKS cluster is created with a managed identity, as cluster extensions don't work with service principal-based clusters.
>
> For new clusters created with `az aks create`, managed identity is configured by default. For existing service principal-based clusters that need to be switched over to managed identity, it can be enabled by running `az aks update` with the `--enable-managed-identity` flag. For more information, see [Use managed identity][use-managed-identity].

> [!NOTE]
> If you enabled [Microsoft Entra pod-managed identity][use-azure-ad-pod-identity] on your AKS cluster or are considering implementing it,
> we recommend you first review [Workload identity overview][workload-identity-overview] to understand our
> recommendations and options to set up your cluster to use a Microsoft Entra Workload ID (preview).
> This authentication method replaces pod-managed identity (preview), which integrates with the Kubernetes native capabilities
> to federate with any external identity providers.
> The open source Microsoft Entra pod-managed identity (preview) in Azure Kubernetes Service was deprecated as of October 24, 2022.

## Currently available extensions

Extension support for security, identity, networking, and deployment readiness capabilities varies by extension. The following table provides the current support status for each capability. Use it to determine whether an extension meets your organization's operational and governance requirements.

- Federal Information Processing Standard (FIPS) 140-3 is a US government standard that defines minimum security requirements for cryptographic modules in information technology products and systems.
- [Workload Identity][workload-identity-overview] is essential for secure identity management and IMDS restriction, to protect against credential theft.
- [Private Link][private-link-overview] is critical for network isolation, preventing unauthorized access and allowing extensions to function in Network Isolated AKS Clusters.​
- [Deployment Safeguards][deployment-safeguards-overview] enforce best practices on an Azure Kubernetes Service (AKS) cluster.​
- [Pod Security Standards (PSS)][pss-overview] define three different policies to broadly cover the security spectrum. PSS-Baseline provides a minimally restrictive policy which prevents known privilege escalations. 

### Legend
| Symbol | Meaning |
|---------|---------|
| ✅ | Supported |
| ❌ | Not Supported |
| N/R | Not Required |

### Extension capability matrix

| Extension | Description | PSS - Baseline | FIPS | Deployment Safeguards | Workload Identity | Private Link |
|-----------|-------------|:------------:|:----:|:--------------------:|:----------------:|:------------:|
| [Azure App Configuration][app-config-overview] | Centralized management of application settings and feature flags. | ✅ | ❌ | ✅ | ✅ | ✅ |
| [Azure Machine Learning][azure-ml-overview] | Train, deploy, and manage machine learning workloads on AKS. | ❌ | ❌ | ❌ | ❌ | ✅ |
| [Dapr][dapr-overview] | Event-driven application runtime for cloud and edge workloads. | ✅ | ❌ | ❌ | ✅ | ✅ |
| [Azure Backup for AKS](/azure/backup/azure-kubernetes-service-backup-overview) | Backup and restore protection for persistent volumes. **(Core Extension)**| ✅ | ❌ | ✅ | ✅ | ✅ |
| [Flux (GitOps)][gitops-overview] | GitOps-based configuration and application deployment management. | ✅ | ❌ | ✅ | ❌ | ✅ |
| [Azure Container Storage](/azure/storage/container-storage/container-storage-introduction) | Persistent storage for AKS workloads. | ✅ | ❌ | ✅ | N/R | ❌ |
| Service Connector | Simplifies secure connectivity between AKS workloads and Azure services. | ✅ | ❌ | ✅ | ✅ | N/R |
| [Azure Monitor - Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=azure-cli#enable-container-insights-and-logging-on-an-aks-cluster) | Log collection and monitoring for AKS clusters and containers. **(Core Extension)**| ❌ | ❌ | ❌ | ❌ | ✅ |
| [Azure Monitor - Prometheus](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=azure-cli#enable-prometheus-metrics-on-an-aks-cluster) | Prometheus-compatible metrics collection for AKS. **(Core Extension)**| ✅ | ❌ | ✅ | N/R | ✅ |
| [Azure Monitor - App Monitoring](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=azure-cli#enable-container-insights-and-logging-on-an-aks-cluster) | Application performance monitoring and telemetry collection. **(Core Extension)**| ❌ | ❌ | ❌ | ❌ | ❌ |
| [Argo CD][argo-cd-overview] | GitOps-based continuous delivery for Kubernetes applications. | ✅ | ❌ | ✅ | ✅ | ❌ |


You can also [select and deploy Kubernetes applications available through Marketplace](deploy-marketplace.md).

> [!NOTE]
> Cluster extensions provide a platform for different extensions to be installed and managed on an AKS cluster. If you're facing issues while using any of these extensions, open a support ticket with the respective service.

> [!NOTE]
> Not every capability is relevant to every extension. Extensions marked as Not Required continue to follow applicable AKS security requirements. The status simply indicates the capability isn't needed for the extension's intended functionality.

## Next steps

- Learn how to [deploy cluster extensions by using Azure CLI](deploy-extensions-az-cli.md).
- Read about [cluster extensions][arc-k8s-extensions].


<!-- INTERNAL LINKS -->
[arc-k8s-extensions]: /azure/azure-arc/kubernetes/conceptual-extensions
[app-config-overview]: ./azure-app-configuration-quickstart.md
[azure-ml-overview]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[dapr-overview]: ./dapr.md
[gitops-overview]: /azure/azure-arc/kubernetes/conceptual-gitops-flux2
[gitops-support]: /azure/azure-arc/kubernetes/extensions-release#flux-gitops
[gitops-tutorial]: /azure/azure-arc/kubernetes/tutorial-use-gitops-flux2
[k8s-extension-reference]: /cli/azure/k8s-extension
[use-managed-identity]: ./use-managed-identity.md
[workload-identity-overview]: workload-identity-overview.md
[use-azure-ad-pod-identity]: use-azure-ad-pod-identity.md
[container-network-insights-agent-overview]: ./container-network-insights-agent-overview.md
[argo-cd-overview]: /azure/azure-arc/kubernetes/tutorial-use-gitops-argocd
[private-link-overview]: /azure/aks/concepts-network-isolated#how-a-network-isolated-cluster-works​
[deployment-safeguards-overview]: /azure/aks/deployment-safeguards

<!-- EXTERNAL LINKS -->
[arc-k8s-regions]: https://azure.microsoft.com/global-infrastructure/services/?products=azure-arc&regions=all
[pss-overview]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
