---
title: Create an AKS on bare metal cluster using Bicep (preview)
description: Learn how to deploy an Azure Kubernetes Service (AKS) cluster on bare metal using a Bicep template.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Create an AKS on bare metal cluster using Bicep (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article shows you how to create an Azure Kubernetes Service (AKS) cluster on bare metal using a Bicep template.

## Prerequisites

Complete all [system requirements and prerequisites](aks-bare-metal-system-requirements.md) before you begin.

## Step 1: Download the Bicep parameters file

1. Download a local copy of the [Bicep parameters file](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aks-baremetal-bicep/create.example.bicepparam).
1. Configure the following parameters:

| Parameter | Value | Notes |
|-----------|-------|-------|
| `location` | `eastus` | Only supported region for public preview. |
| `clusterName` | Your cluster name | Name must be 1-27 characters long, start and end with a letter or number, and can only contain letters, numbers, hyphens, or underscores.|
| `kubernetesVersion` | `1.34.2-20260204` or `1.34.3-20260204` | Format: `Major.Minor.Patch-YYYYMMDD`. |
| `controlPlaneIp` | IP address | If omitted, defaults to the host machine's IP address. Only specify a custom IP if you need the control plane to be reachable on a different address than the host. If provided, it must be in the same subnet as the host IP. |
| `adminGroupObjectIds` | Microsoft Entra ID group object ID | Used for cluster admin RBAC. |
| `sshPublicKey` | SSH public key | An SSH key pair was created during Edge Machine creations. Use that public key here. |
| `logAnalyticsWorkspaceId` | `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.OperationalInsights/workspaces/<WORKSPACE_NAME>` | New workspace used for log analytics. |
| `edgeMachineName` | Edge machine name | Must match the provisioned machine in your resource group. |

> [!WARNING]
> If you specify a custom controlPlaneIp and your machine uses DHCP, you must reserve the control plane IP address so it remains permanently assigned to this machine. If the control plane IP changes, the Kubernetes cluster becomes unreachable and must be redeployed.

## Step 2: Download the Bicep template

Save the [Bicep template](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aks-baremetal-bicep/cluster-create.bicep) to the same directory as your parameters file.

## Step 3: Deploy

Run the following command from the directory containing both files:

```azurecli
az deployment group create \
  --resource-group <RESOURCE_GROUP> \
  --template-file cluster-create.bicep \
  --parameters create.example.bicepparam
```

> [!NOTE]
> Deployment typically takes 20 minutes. You can monitor progress in the Azure portal under your resource group > **Deployments**.

## Verify deployment

After the deployment completes, connect to your cluster:

```azurecli
az aksarc get-credentials --name <clusterName> --resource-group <RESOURCE_GROUP>
```

Then in a new terminal:

```bash
kubectl get nodes
```

For detailed connection instructions, see [Connect to your cluster](aks-bare-metal-connect-to-cluster.md).

## Next steps

- [Connect to your cluster](aks-bare-metal-connect-to-cluster.md)
- [Deploy an application](aks-bare-metal-deploy-application.md)
