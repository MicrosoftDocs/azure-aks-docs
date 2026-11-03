---
title: Install Azure Managed Lustre with AKS CLI options (preview)
description: Install the Azure Managed Lustre managed extension when you create or update an AKS cluster using the preview AKS CLI options.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 11/02/2026
author: wolfgang-desalvador
ms.author: wdesalvador

# Customer intent: As a cluster operator, I want to install Azure Managed Lustre using the preview AKS CLI options.
---

# Install Azure Managed Lustre with AKS CLI options (preview)

This article describes the alternative AKS CLI installation option that's in preview. For the default Helm or script procedures, see [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).

## Before you begin

You need:

- An Azure subscription and access to create or update the AKS cluster.
- A supported Linux node pool for the existing or planned cluster. Review the [driver compatibility requirements](azure-managed-lustre-overview.md#supported-kubernetes-and-aks-versions).
- [Network connectivity](azure-managed-lustre-network-planning.md) between AKS and the existing or planned Lustre file system, using separate subnets.
- `kubectl` available for cluster access after installation.

> [!IMPORTANT]
> Don't install the managed extension alongside an existing Helm, script, or other extension installation of the driver.

<a id="enable-azure-managed-lustre-on-aks"></a>

## Install with AKS CLI options (preview)

As an alternative installation option in preview, you can enable the Azure Managed Lustre managed extension when you create an AKS cluster with `az aks create` or add it to an existing cluster with `az aks update`. Both commands use `--enable-azure-managed-lustre` to install the extension instead of running Helm or the script. This option isn't a migration procedure for an existing Helm or script installation.

> [!IMPORTANT]
> The `--enable-azure-managed-lustre` and `--disable-azure-managed-lustre` options are preview features provided by the `aks-preview` Azure CLI extension. You can also use their aliases, `--enable-amlfs` and `--disable-amlfs`.

This option requires Azure CLI 2.85.0 or later and an `aks-preview` build that includes the Azure Managed Lustre options. The Helm and script procedures don't require `aks-preview`.

Install or update the required Azure CLI extensions:

```azurecli-interactive
az extension add --name aks-preview --upgrade --allow-preview true
az extension add --name k8s-extension --upgrade
```

Confirm that `az aks create --help` and `az aks update --help` list `--enable-azure-managed-lustre`, and that update also lists `--disable-azure-managed-lustre`. If the options aren't listed, the installed `aks-preview` build doesn't include this feature.

Set values for your existing AKS resource group and the cluster to create or update:

```azurecli-interactive
RESOURCE_GROUP="myResourceGroup"
AKS_CLUSTER="myAKSCluster"
```

### Create an AKS cluster with Azure Managed Lustre enabled

Set the resource ID of the AKS subnet prepared with connectivity to your existing or planned Lustre file system. Use a subnet separate from the Lustre subnet:

```azurecli-interactive
AKS_SUBNET_ID="<AKS_SUBNET_RESOURCE_ID>"
```

Create the cluster:

```azurecli-interactive
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --vnet-subnet-id "$AKS_SUBNET_ID" \
  --generate-ssh-keys \
  --enable-azure-managed-lustre
```

### Enable Azure Managed Lustre on an existing AKS cluster

```azurecli-interactive
az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --enable-azure-managed-lustre
```

The command installs the Azure Managed Lustre extension as `azurelustre`. Enabling an already successfully installed extension preserves its configuration; it doesn't upgrade or reinstall it.

Verify that the extension was installed successfully:

```azurecli-interactive
az k8s-extension show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER" \
  --cluster-type managedClusters \
  --name azurelustre \
  --query "{provisioningState:provisioningState, version:version}" \
  --output table
```

Get credentials for the cluster:

```azurecli-interactive
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER"
```

If installation fails, see [Troubleshoot Azure Managed Lustre CSI driver extension errors](/troubleshoot/azure/azure-kubernetes/extensions/troubleshoot-azurelustre-csi-extension-errors).

## Next steps

- [Statically provision Azure Managed Lustre volumes](azure-managed-lustre-static-provisioning.md).
- [Dynamically provision Azure Managed Lustre volumes](azure-managed-lustre-dynamic-provisioning.md).
- [Upgrade or uninstall an AKS CLI installation (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md).
