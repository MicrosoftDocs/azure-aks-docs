---
title: Delete AKS on bare metal cluster resources (preview)
description: Learn how to delete Azure Kubernetes Service on bare metal cluster resources and edge machine resources from Azure in the correct order.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Delete AKS on bare metal cluster resources (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in PREVIEW. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article shows you how to delete AKS on bare metal cluster and edge machine resources from Azure. You **must** follow the deletion order described in this article. Deleting resources out of order results in orphaned resources or failed deletions.

> [!WARNING]
> Some steps require waiting for completion before proceeding. Don't skip ahead.

## Deletion order

| Step | Resource | Wait required | Notes |
|------|----------|:---:|-------|
| 1 | AKS cluster | ✅ **Yes** | Must fully complete before continuing. |
| 1b (optional) | Data Collection Rule | No | Only if you created a data collection rule during cluster creation. |
| 2 | Logical Network (LNET) | No | — |
| 3 | Device Pool | ✅ **Yes** | Automatically deletes the Custom Location. Must fully complete before continuing. |

## Step 1: Delete the AKS cluster

1. In the [Azure portal](https://portal.azure.com), go to resource groups and then select the resource group that you created for the cluster.
1. Select the AKS cluster resource.
1. Select **Delete** and confirm.
1. **Wait** for the deletion to complete before proceeding.

**CLI alternative:**

```azurecli
az resource delete --ids <cluster-resource-id>
```

## Step 2: Delete the Azure Local Logical Network (LNET)

1. In the resource group, select the Azure Local Logical Network resource.
1. Select **Delete** and confirm.

**CLI alternative:**

```azurecli
az resource delete --ids <lnet-resource-id>
```

If you created a data collection rule during cluster creation, delete it now.

1. In the resource group, select the Data Collection Rule resource.
1. Select **Delete** and confirm.

**CLI alternative:**

```azurecli
az resource delete --ids <data-collection-rule-resource-id>
```

## Step 2: Delete the Logical Network (LNET)

1. In the resource group, select the Logical Network resource.
1. Select **Delete** and confirm.

**CLI alternative:**

```azurecli
az resource delete --ids <lnet-resource-id>
```

## Step 3: Delete the Device Pool

1. In the resource group, select the resource with a name ending in **mset** and type **Azure Stack | Preview**.
1. Select **Delete** and confirm.
1. **Wait** for the deletion to complete. This action automatically deletes the Custom Location.

**CLI alternative:**

```azurecli
az resource delete --ids <device-pool-resource-id>
```

> [!NOTE]
> You don't need to manually delete the Custom Location. It's removed automatically when the Device Pool is deleted.

At this point, you deleted all your AKS on bare metal cluster resources. If you also want to delete the Azure Local Small Form Factor resources, follow the guidance at [How do I delete all the resources from a test?](/azure/azure-local/small-form-factor/small-form-factor-faq#how-do-i-delete-all-the-resources-from-a-test).

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Resource stuck in "Deleting" state | Dependency not deleted first. | Verify you followed the order above. Wait and retry. |
| Custom Location still exists after Device Pool delete | Deletion still in progress. | Wait a few more minutes. The deletion cascades automatically. |

## Next steps

- [Create a Kubernetes cluster using the Azure portal](aks-bare-metal-create-cluster-portal.md)
- [System requirements and prerequisites](aks-bare-metal-system-requirements.md)
