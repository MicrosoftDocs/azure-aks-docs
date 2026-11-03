---
title: Upgrade or uninstall Azure Managed Lustre with AKS CLI options (preview)
description: Review upgrade guidance and uninstall the Azure Managed Lustre extension installed with the preview AKS CLI options.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 11/03/2026
author: wolfgang-desalvador
ms.author: wdesalvador
ai-usage: ai-assisted

# Customer intent: As a cluster operator, I want to manage an Azure Managed Lustre installation made with the preview AKS CLI options.
---

# Upgrade or uninstall Azure Managed Lustre with AKS CLI options (preview)

Use this article for the managed extension installed with `az aks create` or `az aks update` and `--enable-azure-managed-lustre` or `--enable-amlfs`. For a driver installed with Helm or a script, use [Upgrade or uninstall the Azure Managed Lustre CSI driver](azure-managed-lustre-uninstall.md) instead.

> [!IMPORTANT]
> Match the removal method to the installation method. Don't use Helm or the cleanup script against an extension-managed driver, or use the AKS disable option to remove a Helm or script installation.

## Upgrade an AKS CLI installation (preview)

There's no direct, in-place upgrade path for the managed extension. To upgrade, you must disable the extension, wait for removal to complete, and then enable it again. Running the enable command while the extension is already installed preserves its configuration but doesn't upgrade or reinstall it. Don't use Helm or the cleanup script to manage an extension-installed driver.

The workload and volume precautions for a Helm upgrade also apply to this procedure. Plan a maintenance window and complete the following steps in order.

> [!IMPORTANT]
> Stop every workload that uses Lustre and confirm that no Lustre mounts remain on the nodes before disabling the extension. You can't replace the Lustre client kernel modules while a Lustre mount is active. Disabling the extension doesn't unmount existing volumes. Keep workloads stopped until the replacement driver is installed and verified.
>
> Preserve persistent volumes (PVs), persistent volume claims (PVCs), and Azure Managed Lustre file systems during the upgrade. Don't run the [volume-cleanup steps](#clean-up-volumes), which are for permanent removal. With `reclaimPolicy: Delete`, deleting a dynamically provisioned claim can also delete the file system and its data.

1. Confirm the [CLI installation prerequisites](azure-managed-lustre-install-cli-preview.md#install-with-aks-cli-options-preview). Record the installed extension version, configuration, and driver namespace, and back up data you need to preserve. Use the volume, claim, storage class, and pod inventory commands in [Prepare for the upgrade](azure-managed-lustre-uninstall.md#prepare-for-the-upgrade), but skip the Helm-specific steps. Account for every Lustre claim, including claims with `Pending` status. Don't continue while a PV or PVC has a deletion timestamp or volume creation or deletion is in progress.

1. Before scaling down StatefulSets, complete [Protect StatefulSet claims](azure-managed-lustre-uninstall.md#protect-statefulset-claims). Set `whenScaled` and `whenDeleted` to `Retain` for affected StatefulSets and verify that the controller has reconciled the claims' owner references. Record the original replica counts and retention policies, and pause operators, autoscalers, and GitOps automation that could delete claims or undo the retention changes. Keep the StatefulSet controller and CSI driver running during these checks.

1. Follow [Stop workloads and inspect mounts](azure-managed-lustre-uninstall.md#stop-workloads-and-inspect-mounts). Use your extension's driver namespace and pod labels for the inspection commands. Keep the driver running until every workload stops and you verify that no Lustre mounts remain on every affected node. Don't continue if a workload pod is still terminating or a node can't be inspected.

1. [Disable the extension](#disable-the-extension) with `az aks update --disable-azure-managed-lustre`, and complete [Verify removal](#verify-removal). Confirm that the old CSI controller and node pods are gone before reinstalling. If retained volumes block removal, stop and contact Microsoft Support. Don't delete those volumes or remove finalizers to force the upgrade.

1. [Enable Azure Managed Lustre on the existing AKS cluster](azure-managed-lustre-install-cli-preview.md#enable-azure-managed-lustre-on-an-existing-aks-cluster) with `az aks update --enable-azure-managed-lustre`. Follow the extension verification steps in that section and confirm that its provisioning state is `Succeeded`. Verify the installed extension and driver versions, and check that any required configuration is present; don't assume that disabling and re-enabling preserves custom settings.

1. Verify that the CSI controller and node pods are ready and that every intended workload node has a ready CSI node pod. Check the loaded Lustre client version on each node against the requirements for the installed driver release. Keep workloads stopped if installation, readiness, or version checks fail.

1. Follow [Restart workloads](azure-managed-lustre-uninstall.md#restart-workloads). Confirm that workloads reuse their original claims and file systems and that normal file operations succeed. Restore the original retention policies and resume automation only after StatefulSets are running at their intended replica counts and their mounts are verified. Don't restore a `Delete` policy while a StatefulSet is still scaled down.

## Uninstall with AKS CLI options (preview)

> [!IMPORTANT]
> The `--disable-azure-managed-lustre` option and its `--disable-amlfs` alias are preview features provided by the `aks-preview` Azure CLI extension. They are the matching removal options for installation with `--enable-azure-managed-lustre` or `--enable-amlfs`.

### Before you begin

- Use the Azure CLI extensions described in [Install with AKS CLI options (preview)](azure-managed-lustre-install-cli-preview.md#install-with-aks-cli-options-preview).
- Configure `kubectl` for the cluster.
- Stop all workloads that use Lustre and let their volumes unmount.
- Clean up their Kubernetes volumes before removing the extension. Remaining volumes or mounts can prevent driver removal.

### Clean up volumes

These cleanup steps are for permanent removal, not for an [extension upgrade](#upgrade-an-aks-cli-installation-preview). Keep your PVs, PVCs, and file systems when upgrading.

Follow the cleanup steps for the provisioning method you used:

| Provisioning method | Cleanup behavior |
| --- | --- |
| [Static provisioning](azure-managed-lustre-static-provisioning.md#clean-up-the-example) | The example removes the pod, claim, retained PV, and storage class. The existing Lustre file system and its data remain. |
| [Dynamic provisioning](azure-managed-lustre-dynamic-provisioning.md#clean-up-the-example) | With `Delete`, deleting the claim also deletes the provisioned file system and its data. With `Retain`, the PV and file system remain for manual cleanup. |

Save any data you need before deleting dynamically provisioned storage. Keep the extension installed until volume cleanup completes. Cleaning up the example resources alone isn't sufficient if other workloads still use Lustre.

### Disable the extension

Set the resource group and cluster name:

```azurecli-interactive
RESOURCE_GROUP="myResourceGroup"
AKS_CLUSTER="myAKSCluster"
```

Disable Azure Managed Lustre on the cluster:

```azurecli-interactive
az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --disable-azure-managed-lustre
```

You can also use the `--disable-amlfs` alias.

### Verify removal

List the cluster extensions:

```azurecli-interactive
az k8s-extension list \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER" \
  --cluster-type managedClusters \
  --output table
```

Confirm that the `azurelustre` extension is no longer listed. Driver removal can continue after the command finishes, so also confirm that the driver is no longer registered in the cluster:

```bash
kubectl get csidriver azurelustre.csi.azure.com
```

After removal, this command returns `NotFound`. If removal doesn't complete, check for workloads or volumes that still use Lustre and contact support if needed. Don't reinstall the extension until removal completes.

Disabling the extension doesn't itself delete Azure Managed Lustre file systems. Any file systems you retained continue to exist and incur charges until you delete them separately.

## Next steps

- [Install with AKS CLI options (preview)](azure-managed-lustre-install-cli-preview.md).
- [Troubleshoot Azure Managed Lustre CSI driver extension errors](/troubleshoot/azure/azure-kubernetes/extensions/troubleshoot-azurelustre-csi-extension-errors).
