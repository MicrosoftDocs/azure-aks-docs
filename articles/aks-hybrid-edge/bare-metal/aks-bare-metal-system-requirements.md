---
title: System requirements and prerequisites for AKS on bare metal Azure Linux (preview)
description: Review Azure Local hardware, network, and Azure requirements for deploying AKS on bare metal on Azure Linux.
ms.topic: concept-article
ms.date: 09/14/2026
ai-usage: ai-assisted
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# System requirements and prerequisites for AKS on bare metal Azure Linux (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article describes the requirements for deploying Azure Kubernetes Service (AKS) on bare metal on Azure Linux and validated Azure Local small form factor hardware. For customer-provided Ubuntu hardware, see [System requirements and prepare your Ubuntu host](aks-bare-metal-ubuntu-system-requirements.md).

## Hardware requirements

Use one of the [supported devices for small form factor deployments of Azure Local.](/azure/azure-local/small-form-factor/small-form-factor-overview#supported-devices)

## Network requirements

### Outbound internet connectivity

The bare metal host requires outbound internet access to the following endpoints:

| Endpoint | Purpose |
| ---------- | --------- |
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
| ------------- | --------- |
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

- [Create an Azure Linux cluster using the Azure portal](aks-bare-metal-create-cluster-portal.md).
- [Compare Azure Linux and Ubuntu](aks-bare-metal-compare-azure-linux-ubuntu.md).
