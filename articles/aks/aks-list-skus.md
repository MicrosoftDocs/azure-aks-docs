---
title: List available VM SKUs for Azure Kubernetes Service (AKS) clusters
description: Learn how to use the az aks list-vm-skus command to list VM SKUs that are available for AKS in a specific Azure region.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 04/28/2026
ms.author: sachidesai
ai-usage: ai-assisted
---

# List available VM SKUs for Azure Kubernetes Service (AKS) clusters

When you add a new node pool to an Azure Kubernetes Service (AKS) cluster, you need to choose a VM SKU that is available in your target Azure region and supported by AKS. You can use the [`az aks list-vm-skus`][az-aks-list-vm-skus] command to quickly view SKUs for AKS in a specific region.

In this article, you learn how to:

- List VM SKUs for AKS in a specific region.
- Filter SKUs by partial size name.
- List only SKUs that support availability zones.
- Include all regional SKUs, including SKUs not currently available to your subscription.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An Azure account with an active subscription. If you don't have one, create an account at <https://azure.microsoft.com/free/>.
- Azure CLI installed and updated to minimum version `2.86.0`. If you need to install or update, see [Install Azure CLI][install-azure-cli].
- This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- [Install and upgrade to latest version of the `aks-preview` extension](#install-the-aks-preview-cli-extension).

> [!TIP]
> If `az aks list-vm-skus` isn't recognized in your environment, update Azure CLI to the latest version and update installed AKS extensions.

### Install the `aks-preview` CLI extension

1. Install the `aks-preview` CLI extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update the extension to ensure you have the latest version installed using the [`az extension update`][az-extension-update] command.
    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `ListVMSKUPreview` feature flag in your subscription

- Register the `ListVMSKUPreview` feature flag in your subscription using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name ListVMSKUPreview
    ```

### Get the credentials for your cluster

- Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

## List supported VM SKUs on an AKS cluster (preview)

Set an Azure region, then run `az aks list-vm-skus`:

```azurecli-interactive
LOCATION=eastus

az aks list-vm-skus \
	--location $LOCATION \
	--query "[].name" \
	--output table
```

Expected output is similar to the following example:

```output
Result
--------------------------
Standard_D2ds_v5
Standard_D4ds_v5
Standard_D8ds_v5
Standard_E4ds_v5
Standard_E8ds_v5
```

By default, the command only returns SKUs available to your current subscription.

## Filter by VM size name

Use `--size` to apply a case-insensitive partial match against SKU name:

```azurecli-interactive
az aks list-vm-skus \
	--location $LOCATION \
	--size d4ds \
	--query "[].name" \
	--output table
```

Expected output is similar to the following example:

```output
Result
--------------------
Standard_D4ds_v5
Standard_D4ds_v6
```

## Show only zone-capable SKUs

Use `--zone` to return only SKUs that support availability zones in the selected region:

```azurecli-interactive
az aks list-vm-skus \
	--location $LOCATION \
	--zone \
	--query "[].{name:name,zones:locationInfo[0].zones}" \
	--output table
```

Expected output is similar to the following example:

```output
Name                Zones
------------------  ---------
Standard_D4ds_v5    [1, 2, 3]
Standard_E8ds_v5    [1, 2, 3]
```

## Include all SKUs in the region

Use `--show-all` to include SKUs that might not currently be available to your subscription:

```azurecli-interactive
az aks list-vm-skus \
	--location $LOCATION \
	--show-all \
	--query "[].name" \
	--output table
```

> [!NOTE]
> AKS uses a best-effort approach to provision VM SKUs. A SKU appearing in this list doesn't guarantee allocation success at deployment time.

## View full details in JSON

Use JSON output if you want to inspect all returned properties:

```azurecli-interactive
az aks list-vm-skus \
	--location $LOCATION \
	--zone \
	--output jsonc
```

Expected output is similar to this example:

```json
[
	{
		"name": "Standard_D4ds_v5",
		"locationInfo": [
			{
				"location": "eastus",
				"zones": [
					"1",
					"2",
					"3"
				]
			}
		]
	},
	{
		"name": "Standard_E8ds_v5",
		"locationInfo": [
			{
				"location": "eastus",
				"zones": [
					"1",
					"2",
					"3"
				]
			}
		]
	}
]
```

The exact set of returned properties can vary by CLI/API version.

## Use a returned SKU for AKS cluster creation

After you identify a suitable SKU, use it with `--node-vm-size` when creating your cluster:

```azurecli-interactive
RESOURCE_GROUP=myResourceGroup
CLUSTER_NAME=myAKSCluster
VM_SIZE=Standard_D4ds_v5

az aks create \
	--resource-group $RESOURCE_GROUP \
	--name $CLUSTER_NAME \
	--node-count 3 \
	--node-vm-size $VM_SIZE \
	--generate-ssh-keys
```

## Troubleshooting

- If no suitable SKU appears, verify regional availability and quota by reviewing [Quotas, virtual machine size restrictions, and region availability in Azure Kubernetes Service (AKS)][quotas-skus-regions].
- If node pool creation fails with allocation or capacity errors, rerun `az aks list-vm-skus` and select another SKU family or region.

## Next steps

- Learn more about AKS limits and regional availability in [Quotas, virtual machine size restrictions, and region availability in Azure Kubernetes Service (AKS)][quotas-skus-regions].
- Compare Azure VM options in [Sizes for virtual machines in Azure][azure-vm-sizes].
- Create your first AKS cluster using [Quickstart: Deploy an AKS cluster using Azure CLI][aks-quickstart-cli].

<!-- LINKS -->
[az-aks-list-vm-skus]: /cli/azure/aks#az-aks-list-vm-skus
[install-azure-cli]: /cli/azure/install-azure-cli
[quotas-skus-regions]: ./quotas-skus-regions.md
[azure-vm-sizes]: /azure/virtual-machines/sizes
[aks-quickstart-cli]: learn/quick-kubernetes-deploy-cli.md
