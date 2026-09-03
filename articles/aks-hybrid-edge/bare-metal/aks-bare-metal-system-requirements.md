---
title: System requirements and prerequisites for AKS on bare metal (preview)
description: Hardware, network, and Azure prerequisites for deploying Azure Kubernetes Service on bare metal.
ms.topic: concept-article
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# System requirements and prerequisites (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article describes the hardware, network, and Azure requirements for deploying Azure Kubernetes Service (AKS) on bare metal.

## Hardware requirements

Use one of the [supported devices for small form factor deployments of Azure Local.](/azure/azure-local/small-form-factor/small-form-factor-overview#supported-devices)

## Network requirements

### Outbound internet connectivity

The bare metal host requires outbound internet access to the following endpoints:

| Endpoint | Purpose |
|----------|---------|
| `*.arc.azure.net` | Azure Arc connectivity |
| `management.azure.com` | Azure Resource Manager |
| `login.microsoftonline.com` | Microsoft Entra authentication |
| `mcr.microsoft.com` | Container image pulls |
| `*.data.mcr.microsoft.com` | Container image data |
| `guestnotificationservice.azure.com` | Arc guest notifications |

### IP address planning

You need one IP address planned before deployment:

| IP type | Purpose | Notes |
|---------|---------|-------|
| Control plane IP | Kubernetes API server endpoint | Must be in the same subnet as the host or match the host IP |

## Azure prerequisites

### Subscription and permissions

| Requirement | Details |
|-------------|---------|
| Azure subscription | Active subscription with billing enabled |
| Region | **East US** (only supported region for public preview) |
| Role | **Owner** or **Contributor + User Access Administrator** on the resource group |
| Role assignment status | Must be both **Active** and **Permanent** |
| Resource providers | [`Microsoft.HybridCompute`](/azure/templates/microsoft.hybridcompute/machines?pivots=deployment-language-bicep), [`Microsoft.HybridContainerService`](/azure/templates/microsoft.hybridcontainerservice/provisionedclusters?pivots=deployment-language-bicep), [`Microsoft.Kubernetes`](/azure/templates/microsoft.kubernetes/connectedclusters?pivots=deployment-language-bicep), [`Microsoft.ExtendedLocation`](/azure/templates/microsoft.extendedlocation/customlocations?pivots=deployment-language-bicep) must be registered |

> [!IMPORTANT]
> If your role assignment isn't active and permanent, you might need to temporarily elevate your permissions before running deployment commands.

### Check directory and subscription settings

1. In the Azure portal, select **Settings** > **Directories + subscriptions**.
1. If you have more than one directory, select the directory you're using for this deployment.
1. Make sure your default subscription filter includes the subscription you're using for testing.

For more information, see:

- [Set subscription filters](/azure/azure-portal/set-preferences#subscription-filters)
- [Manage directories and subscriptions](/azure/azure-portal/set-preferences#directories--subscriptions)

### Register feature

```azurecli
az feature register \
  --subscription <subscription_id> \
  --namespace Microsoft.HybridContainerService \
  --name hiddenPreviewAccess

az feature register \
  --subscription <subscription_id> \
  --namespace Microsoft.HybridConnectivity \
  --name hiddenPreviewAccess
```

### Register resource providers

Ensure Azure CLI is installed and signed in.

```azurecli
az provider register --namespace Microsoft.HybridCompute
az provider register --namespace Microsoft.HybridContainerService
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ExtendedLocation
```

### Azure CLI extensions

Install the required CLI extensions:

```azurecli
az extension add --name connectedk8s
```

> [!NOTE]
> The `connectedk8s` extension is required to connect to your cluster after deployment using `az connectedk8s proxy`.

### Arc-enabled machine

Before deploying an AKS cluster, you must have a small form factor Azure Local device set up by following the [Azure Local documentation](/azure/azure-local/small-form-factor/small-form-factor-overview).


## Entra ID requirements

To use Azure RBAC for cluster access:

| Requirement | Details |
|-------------|---------|
| Entra ID group | A security group containing users who need cluster admin access |
| Group object ID | The object ID of the Entra ID group (found in Azure portal → Entra ID → Groups) |

## Next steps

- [Create a Kubernetes cluster using the Azure portal](aks-bare-metal-create-cluster-portal.md)
