---
title: Upgrade or uninstall the Azure Managed Lustre CSI driver
description: Upgrade or uninstall the Azure Managed Lustre CSI driver installed with Helm or a script. Find the separate lifecycle guide for the preview AKS CLI option.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 11/02/2026
author: pauljewellmsft
ms.author: akashdubey
ms.reviewer: brianl
ms.custom: sfi-image-nochange

# Intent: As an IT pro, I want to upgrade or uninstall the Azure Lustre CSI Driver without disrupting active Lustre mounts or deleting storage resources.
# Keyword:

---

# Upgrade or uninstall the Azure Managed Lustre CSI driver

<a id="uninstall-azure-managed-lustre-from-azure-kubernetes-service"></a>

This article describes how to upgrade the Azure Managed Lustre CSI driver to v0.6.0 or uninstall it when installed with Helm or a script. For an installation made with the alternative AKS CLI option, use the separate [CLI preview upgrade and uninstall guide](azure-managed-lustre-upgrade-uninstall-cli-preview.md).

For a new installation, see [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).

> [!IMPORTANT]
> Use the lifecycle procedure that matches your installation method. Don't run Helm or the cleanup script against an extension-managed driver, or use the AKS disable option to remove a Helm or script installation.

## Choose the matching uninstall method

Use the removal method that matches how you installed the driver:

| Installation method | Matching uninstall method |
| --- | --- |
| Helm | Follow [Uninstall a Helm-managed driver](#uninstall-a-helm-managed-driver). |
| Script | Follow [Uninstall a script-managed driver](#uninstall-a-script-managed-driver). |
| AKS CLI options (preview): `az aks create` or `az aks update` with `--enable-azure-managed-lustre` or `--enable-amlfs` | Follow [Uninstall with AKS CLI options (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#uninstall-with-aks-cli-options-preview) and use `az aks update --disable-azure-managed-lustre` or `--disable-amlfs`. |

For upgrades, follow [Upgrade the CSI driver](#upgrade-the-csi-driver) for Helm or script installations. For the alternative installation option, see [Upgrade an AKS CLI installation (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#upgrade-an-aks-cli-installation-preview).

## Upgrade the CSI driver

For a Helm or script installation, upgrade an earlier release (v0.2.0 or later) to v0.6.0 by uninstalling the existing driver and installing v0.6.0 during a maintenance window. This procedure also supports changing from the script to Helm. If your cluster runs a release earlier than v0.2.0, contact Microsoft Support before you upgrade.

> [!IMPORTANT]
> Before upgrading, stop every workload that uses Lustre and confirm that no Lustre mounts remain on the nodes. You can't replace the Lustre client kernel modules while a Lustre mount is active. Only then, uninstall the existing driver. Uninstalling the driver doesn't remove existing mounts. Keep workloads stopped until the replacement driver is installed and verified.
>
> Stopping workloads preserves storage only if their controllers retain the PersistentVolumeClaims. Before scaling down a StatefulSet, complete [Protect StatefulSet claims](#protect-statefulset-claims). A StatefulSet with `whenScaled: Delete` can delete its template-created claims during scale-down; with a dynamically provisioned PV using `reclaimPolicy: Delete`, that deletion can also remove the remote Azure Managed Lustre file system and its data. Don't delete PVs, PVCs, or file systems as part of the driver upgrade.

### Prepare for the upgrade

Use your existing driver namespace in every `kube-system` command in this article. For Helm commands, also substitute your existing release name for `azurelustre`.

1. Check the effective OS SKU for every node:

   ```bash
   kubectl get nodes -L kubernetes.azure.com/os-sku-effective
   ```

   All nodes in the node pools where you intend to run Azure Managed Lustre workloads must report `Ubuntu2204`, `Ubuntu2404`, `AzureLinux3`, or, for Confidential VM node pools, `Ubuntu2004`. Confirm that the cluster also meets the [Kubernetes and architecture requirements](azure-managed-lustre-overview.md#supported-kubernetes-and-aks-versions). Don't continue if a required node has a missing or unsupported value. AKS manages this label. Don't change it manually.

1. Confirm the [installation prerequisites](azure-managed-lustre-install.md#prerequisites), including `cluster-admin` permissions, network access, and node scheduling.

1. For a Helm installation with custom values, export them before uninstalling and keep the file for the reinstall:

   ```bash
   helm get values azurelustre --namespace kube-system --output yaml > azurelustre-values.yaml
   ```

   Review the exported values for compatibility with the v0.6.0 chart before reusing them. Don't override the released driver image or Lustre client versions unless Microsoft Support directs you to.

1. List the PersistentVolumes that use the Azure Lustre CSI driver:

   ```bash
   printf 'PV\tCLAIM\tSTATUS\tDELETING\n'
   kubectl get pv -o jsonpath='{range .items[?(@.spec.csi.driver=="azurelustre.csi.azure.com")]}{.metadata.name}{"\t"}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{"\t"}{.status.phase}{"\t"}{.metadata.deletionTimestamp}{"\n"}{end}'
   ```

   Use the claim references to account for every bound Azure Lustre claim, even if its StorageClass no longer exists.

1. List the storage classes that use the Azure Lustre CSI driver:

   ```bash
   kubectl get storageclass -o jsonpath='{range .items[?(@.provisioner=="azurelustre.csi.azure.com")]}{.metadata.name}{"\n"}{end}'
   ```

1. List all PersistentVolumeClaims and use the preceding storage class list to identify unbound Azure Lustre claims:

   ```bash
   kubectl get pvc --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,STATUS:.status.phase,VOLUME:.spec.volumeName,DELETING:.metadata.deletionTimestamp'
   ```

   Account for every Azure Lustre claim, including claims with `Pending` status. Don't continue if an Azure Lustre PV or PVC has a deletion timestamp, or while an Azure Lustre volume creation or deletion is in progress.

1. List pods and the PersistentVolumeClaims that they reference:

   ```bash
   kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.volumes[?(@.persistentVolumeClaim)]}{.persistentVolumeClaim.claimName}{" "}{end}{"\n"}{end}'
   ```

#### Protect StatefulSet claims

Complete these checks before scaling down or deleting any application workloads. See [StatefulSet PersistentVolumeClaim retention](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#persistentvolumeclaim-retention) for the retention and garbage-collection behavior.

1. Identify StatefulSets that manage any of the Azure Lustre claims from the inventory, including claims created from `volumeClaimTemplates`. Inspect their desired replica counts and claim retention policies:

   ```bash
   kubectl get statefulsets --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,WHEN-SCALED:.spec.persistentVolumeClaimRetentionPolicy.whenScaled,WHEN-DELETED:.spec.persistentVolumeClaimRetentionPolicy.whenDeleted'
   ```

   Unset retention fields default to `Retain`. `whenScaled: Delete` deletes template-created claims when replicas are removed; `whenDeleted: Delete` deletes them when the StatefulSet is deleted.

1. Record each affected StatefulSet's original replica count and retention policy. Update or pause operators, autoscalers, and GitOps automation so they can't scale down or delete these workloads or revert the retention policy during maintenance. Keep the Kubernetes StatefulSet controller and CSI driver running.

1. For each affected StatefulSet with a `Delete` retention setting, set both `whenScaled` and `whenDeleted` to `Retain` for the maintenance window. Make the change in its source configuration if an operator or GitOps process manages it. For a directly managed StatefulSet, use:

   ```bash
   kubectl patch statefulset <statefulset-name> -n <namespace> \
     --type=merge \
     -p '{"spec":{"persistentVolumeClaimRetentionPolicy":{"whenScaled":"Retain","whenDeleted":"Retain"}}}'
   ```

   Read back the StatefulSet to confirm the effective policy before continuing:

   ```bash
   kubectl get statefulset <statefulset-name> -n <namespace> -o yaml
   ```

1. Wait for the StatefulSet controller to reconcile the policy on every affected template-created PVC. Inspect each claim:

   ```bash
   kubectl get pvc <claim-name> -n <namespace> -o yaml
   ```

   Don't continue until every claim has no deletion timestamp and its `metadata.ownerReferences` no longer contains the StatefulSet or any of its pods. A successful policy patch alone doesn't prove that these references have been reconciled. Don't manually remove owner references or finalizers to bypass this check.

1. Repeat the PV and PVC inventory checks before stopping workloads. Don't continue if a claim is missing, a PV or PVC has a deletion timestamp, the retention policy reverts, or you can't verify that the claims will be retained. Resolve the condition with the workload or cluster administrator first.

#### Stop workloads and inspect mounts

1. Before stopping the workloads, record their nodes with `kubectl get pods --all-namespaces -o wide`.

1. After verifying claim retention, stop every application workload that uses an Azure Managed Lustre claim. Scale its Deployments or protected StatefulSets to zero replicas, suspend its scheduled jobs, and pause any deployment or GitOps process that recreates its pods. Don't delete StatefulSets as a shutdown shortcut. Delete standalone application pods, including the provisioning example pods. Keep the CSI driver running until you confirm that no Lustre mounts remain.

1. Repeat the pod-and-claim inventory query from [Prepare for the upgrade](#prepare-for-the-upgrade). Don't continue while it lists a pod that references an Azure Managed Lustre claim, including a pod in `Terminating` state.

1. List the CSI node pods:

   ```bash
   kubectl get pods -n kube-system -l app=csi-azurelustre-node -o wide
   ```

   Compare the `NODE` column with the nodes used by the workloads you stopped. Don't continue unless every such node has a CSI node pod in `Running` state that you can inspect for remaining mounts.

1. Check every CSI node pod for remaining Lustre mounts:

   ```bash
   (
     set -e
     pods=$(kubectl get pods -n kube-system -l app=csi-azurelustre-node -o name)
     if [ -z "$pods" ]; then
       echo "No Azure Lustre CSI node pods found." >&2
       exit 1
     fi
     for pod in $pods; do
       echo "$pod"
       kubectl exec -n kube-system "$pod" -c azurelustre -- \
         sh -c 'grep " - lustre " /proc/self/mountinfo; status=$?; [ "$status" -eq 1 ]'
     done
     echo "No Lustre mounts remain on the inspected nodes."
   )
   ```

   The command displays each CSI node pod, then prints `No Lustre mounts remain on the inspected nodes.` on success. It exits with an error if it finds a Lustre mount or can't inspect a pod. Don't continue if the command fails.

### Install v0.6.0

Complete the preparation and unmount checks first. Keep Azure Managed Lustre workloads stopped until verification is complete.

1. Remove the existing driver by using the [Helm uninstall procedure](#uninstall-a-helm-managed-driver) for a Helm release, or the [script uninstall procedure](#uninstall-a-script-managed-driver) for a script-managed installation. Leave PVs, PVCs, and file systems in place.

1. Confirm that both lists are empty before installing the replacement:

   ```bash
   kubectl get pods -n kube-system -l app=csi-azurelustre-node
   kubectl get pods -n kube-system -l app=csi-azurelustre-controller
   ```

1. Follow the [Helm](azure-managed-lustre-install.md#install-with-helm) or [script](azure-managed-lustre-install.md#install-with-the-script) procedure to install v0.6.0. For a Helm reinstall, use the same release name and namespace, and add `--values azurelustre-values.yaml` if you exported custom values.

1. Complete [Verify the upgrade](#verify-the-upgrade) before restarting workloads. If installation reports a timeout, use those checks to determine its state before retrying.

### Verify the upgrade

1. Complete the [installation checks](azure-managed-lustre-install.md#verify-the-installation).

1. Check the loaded Lustre kernel module version on every CSI node pod:

   ```bash
   (
     set -e
     pods=$(kubectl get pods -n kube-system -l app=csi-azurelustre-node -o name)
     if [ -z "$pods" ]; then
       echo "No Azure Lustre CSI node pods found." >&2
       exit 1
     fi
     for pod in $pods; do
       echo "$pod"
       kubectl exec -n kube-system "$pod" -c lustre-loader -- \
         cat /sys/module/lustre/version
     done
   )
   ```

   Compare the loaded version with the expected Lustre client version for the node's OS in the [compatibility table](azure-managed-lustre-overview.md#azure-lustre-csi-driver-versions).

### Restart workloads

Keep Azure Managed Lustre workloads stopped until verification is complete. Then restart them and confirm that a representative workload's normal file operations succeed. You can inspect its mount with:

```bash
kubectl exec -n <namespace> <pod-name> -- df -h <mount-path>
```

Restore StatefulSets to their intended replica counts and verify that they reuse the original claims and file systems. Only after the workloads are running at those replica counts and their mounts are verified should you restore any recorded retention policies and resume automation. Don't restore a `Delete` policy while the StatefulSet is still scaled down for maintenance.

### Recover from an unsuccessful upgrade

> [!IMPORTANT]
> Keep Azure Managed Lustre workloads stopped while recovering from an unsuccessful upgrade. Don't install an arbitrary older driver release, because it might not support the node operating system, kernel, or Lustre client version in the cluster.

Use the [v0.6.0 troubleshooting guide](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.6.0/docs/csi-debug.md) and [v0.6.0 error reference](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.6.0/docs/errors.md) to correct the failure, then repeat [Verify the upgrade](#verify-the-upgrade). If you can't complete the installation or confirm that existing Lustre mounts are gone, contact Microsoft Support before removing more resources.

## Uninstall the driver

Before scaling down StatefulSets, complete [Protect StatefulSet claims](#protect-statefulset-claims). Stop every workload that uses Lustre and confirm that no Lustre mounts remain before uninstalling the driver. Use the workload and mount checks in [Prepare for the upgrade](#prepare-for-the-upgrade). Uninstalling the driver doesn't remove existing mounts.

### Uninstall a Helm-managed driver

Use the release name and namespace from your installation:

```bash
helm uninstall azurelustre --namespace kube-system --wait --timeout 30m
```

Helm removes the resources in the release. It doesn't delete PVs, PVCs, or Azure Managed Lustre file systems.

### Uninstall a script-managed driver

Use the v0.6.0 cleanup script to remove a script-managed v0.2.0 or later installation. Also delete the legacy `csi-azurelustre-node` DaemonSet explicitly because it lacks the label selected by the script:

```bash
git clone --branch v0.6.0 --depth 1 https://github.com/kubernetes-sigs/azurelustre-csi-driver.git
cd azurelustre-csi-driver
./deploy/uninstall-driver.sh
kubectl delete daemonset csi-azurelustre-node -n kube-system --ignore-not-found
```

These commands remove the CSI controller, node DaemonSets, `CSIDriver` object, and RBAC resources. They don't delete PersistentVolumes, PersistentVolumeClaims, or Azure Managed Lustre file systems.

## Upgrade an AKS CLI installation (preview)

See [Upgrade an AKS CLI installation (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#upgrade-an-aks-cli-installation-preview). Don't apply the Helm or script upgrade procedure to an extension-managed driver.

## Uninstall with AKS CLI options (preview)

<a id="before-you-begin"></a>
<a id="clean-up-volumes"></a>
<a id="disable-the-extension"></a>
<a id="verify-removal"></a>

For prerequisites, volume cleanup, the matching disable command, and removal verification, see [Uninstall with AKS CLI options (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#uninstall-with-aks-cli-options-preview).

<a id="next-steps"></a>

## Related content

- [Azure Lustre CSI driver overview](azure-managed-lustre-overview.md)
- [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md)
- [Use dynamic provisioning with the Azure Lustre CSI driver](azure-managed-lustre-dynamic-provisioning-reference.md)
- [Use static provisioning with the Azure Lustre CSI driver](azure-managed-lustre-static-provisioning.md)
- [Validate CSI driver image security](azure-managed-lustre-image-security.md)
