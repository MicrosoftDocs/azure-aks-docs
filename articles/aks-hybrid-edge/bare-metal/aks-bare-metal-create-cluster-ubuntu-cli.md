---
title: Create an AKS on bare metal cluster on Ubuntu with Azure CLI
description: Connect an Ubuntu host to Azure Arc and create an Azure Kubernetes Service on bare metal cluster by using an automated script or Azure CLI.
ms.topic: how-to
ms.date: 09/17/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Create an AKS on bare metal cluster on Ubuntu with Azure CLI (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Review the [Ubuntu host system requirements](aks-bare-metal-ubuntu-system-requirements.md) and ensure your host meets them.
- Get the ID of the Azure subscription where you want to deploy the cluster.
- Get your Microsoft Entra tenant ID.

## Deploy the cluster

You can deploy an AKS cluster on your bare metal Ubuntu machine in two ways. You can download a script that runs the deployment commands for you, or you can execute the commands yourself in a step-by-step process.

### Option 1: Connect and deploy with one command

The easiest way to deploy an AKS cluster is through a script maintained by the AKS team. The command downloads the script by using `curl` and pipes it to `bash` to connect your machine to Azure Arc and deploy the AKS cluster.


Replace the placeholder values with your subscription and tenant IDs. Run the command on your Ubuntu machine:

```bash
curl -sSL https://aka.ms/aksbm | bash -s -- \
  -s <subscription-id> \
  -t <tenant-id>
```

> [!NOTE]
> To inspect the script before you run it, download the script from `https://aka.ms/aksbm` and review the file locally.

### Option 2: Connect and deploy step by step

If you prefer a step-by-step installation process, complete the following steps to install the AKS cluster.

1. Complete the steps to [prepare and connect your Ubuntu host](aks-bare-metal-ubuntu-system-requirements.md#prepare-and-connect-the-ubuntu-host).
1. Use Azure CLI version 2.90.0 or later.
1. Verify that the Arc-enabled server has a `Connected` status.
1. Sign in and select the subscription that contains the Arc-enabled server.

   ```azurecli
   az login
   az account set --subscription <subscription-id>
   ```

1. Install or update the public `aksarc` extension.

   ```azurecli
   az extension add --name aksarc --upgrade --allow-preview true
   ```

1. Deploy the cluster.

   ```azurecli
   az aksarc deploy \
     --resource-group <resource-group> \
     --arc-machine-names <host-name>
   ```

## Supported Kubernetes versions

If you don't specify `--kubernetes-version`, AKS deploys Kubernetes version
`1.33.3`. To deploy another supported version, pass the corresponding version
string to `--kubernetes-version`.

| Kubernetes version | `--kubernetes-version` value |
| --- | --- |
| 1.33.3 | `1.33.3-20251001` |
| 1.34.2 | `1.34.2-20260204` |
| 1.34.3 | `1.34.3-20260204` |
| 1.34.4 | `1.34.4-20260323` |

The following example deploys Kubernetes `1.34.3`:

```azurecli
az aksarc deploy \
  --resource-group <resource-group> \
  --arc-machine-names <host-name> \
  --kubernetes-version 1.34.3-20260204
```

Deployment takes approximately 40 minutes. Keep the host connected to Azure and the required outbound endpoints throughout deployment.

## Verify the deployment

After deployment completes, you can verify the cluster status by running the following command:

```azurecli
az aksarc show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query properties.provisioningState \
  --output tsv
```

You can also view the cluster in the Azure portal under **Kubernetes Center** > **Clusters**. The portal experience for Ubuntu is read-only during the preview.

## Next steps

- [Connect to the cluster](aks-bare-metal-connect-to-cluster.md).
- [Deploy an application](aks-bare-metal-deploy-application.md).
