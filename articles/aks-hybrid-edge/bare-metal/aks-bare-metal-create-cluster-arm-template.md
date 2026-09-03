---
title: Create an AKS on bare metal cluster using ARM template (preview)
description: Learn how to deploy an Azure Kubernetes Service (AKS) cluster on bare metal using an ARM template.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Create an AKS on bare metal cluster using an ARM template (preview)

 > [!IMPORTANT]
 > Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

 This article shows you how to create an Azure Kubernetes Service (AKS) cluster on bare metal using an Azure Resource Manager template (ARM template).

 ## Prerequisites

 Complete all [system requirements and prerequisites](aks-bare-metal-system-requirements.md) before you begin.

 ## Step 1: Download the ARM template parameters file

 1. Download a local copy of the [ARM template parameters file](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aks-baremetal-arm/aks-baremetal-arm.parameteres.json).
 1. Configure the following required parameters:
  
    | Parameter | Value | Notes |
    |-----------|-------|-------|
    | `edgeMachineName` | Edge machine name | Must match the provisioned machine in your resource group. |
    | `adminGroupObjectIds` | Microsoft Entra ID group object ID | Used for cluster admin RBAC. Must be a valid GUID. |
    | `sshPublicKey` | SSH public key | An SSH key pair was created during Edge Machine creation. Use that public key. |
 
 1. Optionally configure additional parameters:

    | Parameter | Default | Notes |
    |-----------|---------|-------|
    | `clusterName` | `my-aks-on-baremetal-cluster` | Name must be 1-27 characters long, start and end with a letter or number, and can only contain letters, numbers, hyphens, or underscores. |
    | `kubernetesVersion` | `1.34.3-20260204` | Format: `Major.Minor.Patch-YYYYMMDD`. |
    | `controlPlaneIp` | (auto-assigned as host IP) | If specified, must be in the same subnet as the host IP **but cannot be the same as the host IP**. If no IP is provided, it defaults to the host IP. |
    | `enableAzurePolicy` | `true` | Set to `false` to skip Azure Policy extension installation. |
    | `enableContainerMonitoring` | `true` | Set to `false` to skip Container Monitoring extension installation. |
    | `logAnalyticsWorkspaceId` | (empty) | Required if `enableContainerMonitoring` is `true`. Format: `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.OperationalInsights/workspaces/<WORKSPACE_NAME>` |

   > [!WARNING]
   > If your machine uses DHCP and you specify a control plane IP, you must reserve that IP address so it remains permanently assigned to this machine. If the control plane IP changes, the Kubernetes cluster becomes unreachable and must be redeployed.

 ## Step 2: Download the ARM template

 Save the [ARM template](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aks-baremetal-arm/aks-baremetal-arm.json) to the same directory as your parameters file.

 ## Step 3: Deploy

 Run the following command from the directory containing both files:

 ```azurecli
 az deployment group create \
   --resource-group <RESOURCE_GROUP> \
   --template-file aks-baremetal-arm.json \
   --parameters aks-baremetal-arm.parameteres.json
```

> [!NOTE]
> Deployment typically takes 20 minutes. You can monitor progress in the Azure portal under your resource group > **Deployments**.

## Verify deployment

After the deployment finishes, connect to your cluster:

```azurecli
az aksarc get-credentials --name <clusterName> --resource-group <RESOURCE_GROUP>
```

Then, in a new terminal:

```bash
kubectl get nodes
```

For detailed connection instructions, see [Connect to your cluster](aks-bare-metal-connect-to-cluster.md).

## Next steps

- [Connect to your cluster](aks-bare-metal-connect-to-cluster.md)
- [Deploy an application](aks-bare-metal-deploy-application.md)

