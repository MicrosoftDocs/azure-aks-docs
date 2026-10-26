---
title: Delete AKS on Bare Metal on Ubuntu (Preview)
description: Delete an AKS on bare metal cluster from an Ubuntu host in the correct dependency order by using Azure CLI.
ms.topic: how-to
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Delete an AKS on bare metal cluster on Ubuntu (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Use `az aksarc undeploy` to delete the Kubernetes cluster and its dependent resources from an Ubuntu host in the correct order.

> [!IMPORTANT]
> Don't delete an AKS on bare metal cluster on Ubuntu through the Azure portal. Use `az aksarc undeploy` so that AKS removes the cluster and its dependent resources from the host in the correct order.

> [!WARNING]
> Don't delete the resource group before you undeploy the cluster. Deleting resources out of order can leave components on the Ubuntu host. Undeploying permanently deletes the cluster and its workloads. Back up any data that you need to keep.

## Delete the cluster

Install or update the public-preview version of the `aksarc` extension:

```azurecli
az extension add --name aksarc --upgrade --allow-preview true
```

- Sign in and select the subscription that contains the Arc-enabled server.

```azurecli
az login
az account set --subscription <subscription-id>
```

Undeploy the cluster:

```azurecli
az aksarc undeploy \
  --resource-group <resource-group> \
  --arc-machine-names <host-name> \
  --yes
```

## Verify deletion

Confirm that the cluster no longer appears in the resource group:

```azurecli
az aksarc list \
  --resource-group <resource-group> \
  --output table
```

The Ubuntu host remains connected to Azure Arc. Disconnect or delete the Arc-enabled server only if you no longer need Azure management for that host. For more information, see [Manage the Azure Connected Machine agent](/azure/azure-arc/servers/manage-agent).

## Next steps

- [Create an AKS on bare metal cluster on Ubuntu](aks-bare-metal-create-cluster-ubuntu-cli.md).
- [Troubleshoot Ubuntu deployments](aks-bare-metal-troubleshoot-ubuntu-deployment.md).
