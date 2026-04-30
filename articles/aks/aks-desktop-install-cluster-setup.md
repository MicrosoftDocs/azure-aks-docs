---
title: Configure an Azure Kubernetes Service (AKS) Cluster for AKS Desktop
description: Learn how to set up a compatible Azure Kubernetes Service (AKS) cluster for AKS desktop.
ms.subservice: aks-developer
ms.service: azure-kubernetes-service
ms.reviewer: schaffererin
author: danielsollondon
ms.topic: how-to
ms.date: 04/16/2026
ms.author: danis
# Customer intent: As a devops engineer or cluster operator or platform engineer, I want to set up a compatible AKS cluster and configure Projects for AKS desktop, so that I can delegate to developers who can deploy and/or manage applications without needing deep Kubernetes expertise.
---

# Configure an Azure Kubernetes Service (AKS) cluster for AKS desktop

AKS desktop supports Standard and Automatic (recommended) AKS clusters. However, there are some differences in setup and features available between the two tiers. This article covers recommended Azure Kubernetes Service (AKS) cluster configurations and add-ons for AKS desktop.

> [!TIP]
> If you want to get started with AKS desktop as quickly as possible, we recommend:
>
> - Creating an AKS Automatic cluster, which has all required features pre-enabled.
> - Attaching an Azure Container Registry (ACR) with your application images.
> - [Installing the latest version of AKS desktop](https://github.com/Azure/aks-desktop/releases).

## Prerequisites

- An Azure subscription. If you don't have one, create a [free Azure account](https://azure.microsoft.com/free).
- Azure CLI version 2.64.0 or later. Check your version with [`az --version`](/cli/azure/reference-index#az-version) and [install or upgrade](/cli/azure/install-azure-cli) as needed.
- The `aks-preview` Azure CLI extension. You can install the extension using the `az extension add --name aks-preview` command.
- Permissions to create resources in Azure (Contributor role or Owner role on the target resource group).
- **Azure Kubernetes Service RBAC Cluster Admin** role on the target AKS cluster to grant users access to Projects.

## AKS Automatic clusters

[AKS Automatic clusters](intro-aks-automatic.md) are the easiest way to get started with AKS desktop. They come with all required features pre-enabled, so you can start using AKS desktop right away without needing to configure your cluster. With an AKS Automatic cluster, you get a streamlined experience for creating Projects, deploying applications, and managing resources in AKS desktop.

See the [official feature comparison](intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison) for a complete breakdown of differences between AKS Automatic and AKS Standard.

If you have an existing AKS Automatic cluster, you can [deploy an application](aks-desktop-app.md) or import an existing namespace that includes your application. If you want to create a new AKS Automatic cluster and get started with AKS desktop, see [Quickstart: Deploy and managed applications using AKS desktop](aks-desktop-quickstart-auto.md).

## AKS Standard clusters

You can use AKS desktop with Standard AKS clusters, but you must ensure certain features are enabled for the best experience. Some features are required for basic functionality, while others are optional but recommended for full AKS desktop capabilities.

### Minimum requirements for AKS Standard clusters

The following table outlines the minimum required features for an AKS Standard cluster to be compatible with AKS desktop:

| Requirement | Why it's needed | How to check | How to enable |
| --- | --- | --- | --- |
| **Microsoft Entra ID (AAD) authentication** | Required for Azure RBAC and managed namespace role assignments. Clusters without Entra ID authentication enabled don't appear in the AKS desktop cluster picker. | `az aks show --resource-group <resource-group-name> --name <cluster-name> --query aadProfile` (Must not be `null`) | Must be set at cluster creation using `--enable-aad --enable-azure-rbac` |
| **Azure RBAC for Kubernetes authorization** | Required for assigning users to Projects with Admin, Writer, or Reader roles. | `az aks show --resource-group <resource-group-name> --name <cluster-name> --query aadProfile.enableAzureRbac` (Must be `true`) | Must be set at cluster creation using `--enable-azure-rbac` |

### Recommended configuration for AKS Standard clusters

The following table outlines recommended features for an AKS Standard cluster to unlock the full potential of AKS desktop:

| Feature | What it enables in AKS desktop | Can be enabled after cluster creation? | How to enable |
| --- | --- | --- | --- |
| **Network policy engine** (Cilium recommended) | Ingress and egress network policies on managed namespaces. Without a network policy engine, policies are silently ignored. | **No**. Must be set at cluster creation. | `--network-plugin azure --network-policy cilium` |
| **Azure Monitor Metrics** (Managed Prometheus) | Metrics tab (CPU, memory, and request-rate charts) and the Scaling chart (CPU %). | Yes | `az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-azure-monitor-metrics` |
| **Managed Grafana** | Visualization for metrics dashboards. | Yes | Enabled alongside Azure Monitor Metrics when using the Azure portal. When using Azure CLI, link a Grafana workspace with `--enable-azure-monitor-metrics --azure-monitor-workspace-resource-id <id>`. |
| **KEDA** | Kubernetes Event-Driven Autoscaling in the Scaling tab. | Yes | `az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-keda` |
| **VPA** (Vertical Pod Autoscaler) | Vertical pod autoscaling recommendations in the Scaling tab. | Yes | `az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-vpa` |

## Create a fully compatible AKS Standard cluster

The following [`az aks create`](/cli/azure/aks#az-aks-create) command creates a new AKS Standard cluster with all recommended features enabled for AKS desktop. Make sure to replace the placeholder values with your own.

```azurecli-interactive
az aks create \
  --resource-group <resource-group-name> \
  --name <cluster-name> \
  --location <location> \
  --tier standard \
  --enable-aad \
  --enable-azure-rbac \
  --network-plugin azure \
  --network-policy cilium \
  --enable-azure-monitor-metrics \
  --enable-keda \
  --enable-vpa \
  --enable-hpa \
  --generate-ssh-keys
```

If you want to attach an existing Azure Container Registry (ACR) to the cluster after creation, you can use the following [`az aks update`](/cli/azure/aks#az-aks-update) command:

```azurecli-interactive
az aks update \
  --resource-group <resource-group-name> \
  --name <cluster-name> \
  --attach-acr <acr-name>
```

## Enable features on an existing AKS Standard cluster

There are some features you can enable after cluster creation. There are other features that you can only enable at cluster creation time. For more information, see the [AKS desktop feature availability matrix](#aks-desktop-feature-availability-matrix).

These commands might take several minutes to complete. Each add-on might incur extra Azure costs. For more information, see [AKS pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).

### Enable Azure Monitor metrics (Managed Prometheus)

Enable Azure Monitor metrics on an existing AKS Standard cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-azure-monitor-metrics` flag. This add-on enables the Metrics tab and the Scaling chart (CPU %) in AKS desktop.

```azurecli-interactive
az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-azure-monitor-metrics
```

### Enable KEDA

Enable Kubernetes Event-Driven Autoscaling (KEDA) on an existing AKS Standard cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-keda` flag. This add-on enables the Scaling tab in AKS desktop, which provides recommendations for scaling your workloads based on custom metrics.

```azurecli-interactive
az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-keda
```

### Enable VPA

Enable the Vertical Pod Autoscaler (VPA) on an existing AKS Standard cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-vpa` flag. This add-on enables vertical pod autoscaling recommendations in the Scaling tab of AKS desktop, which provides insights into how to optimize resource requests and limits for your workloads.

```azurecli-interactive
az aks update --resource-group <resource-group-name> --name <cluster-name> --enable-vpa
```

## AKS desktop feature availability matrix

The following table outlines which AKS desktop features require specific cluster add-ons and whether those add-ons can be enabled after cluster creation:

| AKS desktop feature | Works without add-on? | Required add-on | Can be enabled after cluster creation? |
| --- | --- | --- | --- |
| Project creation | Yes | Azure RBAC + Entra ID | No (Creation-time only) |
| Network policies | No (Silently ignored) | Cilium, Calico, or Azure network policy | No (Creation-time only) |
| Metrics tab | No (Shows error) | Managed Prometheus | Yes |
| Scaling chart (CPU %) | No (Shows error) | Managed Prometheus | Yes |
| HPA (Horizontal scaling) | Yes | `metrics-server` (Included by default) | Yes |
| KEDA scaling | No | KEDA add-on | Yes |
| VPA scaling | No | VPA add-on | Yes |

## Related content

- [Overview of Projects in AKS desktop](aks-desktop-projects.md)
- [Deploy an application with AKS desktop](aks-desktop-app.md)
- [Set up permissions for AKS desktop](aks-desktop-permissions.md)
