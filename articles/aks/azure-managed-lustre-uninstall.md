---
title: Upgrade or uninstall the Azure Managed Lustre CSI driver
description: Review update guidance and uninstall the Azure Managed Lustre CSI driver installed with Helm or a script. Find the separate guide for the preview AKS CLI option.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 11/10/2026
author: pauljewellmsft
ms.author: akashdubey
ms.reviewer: brianl
ms.custom: sfi-image-nochange
ai-usage: ai-assisted

# Intent: As an IT pro, I want to upgrade or uninstall the Azure Lustre CSI Driver without disrupting active Lustre mounts or deleting storage resources.
# Keyword:

---

# Upgrade or uninstall the Azure Managed Lustre CSI driver

<a id="uninstall-azure-managed-lustre-from-azure-kubernetes-service"></a>

This article provides update guidance and uninstall instructions for a Helm or script installation of the Azure Managed Lustre CSI driver. For an installation made with the alternative AKS CLI option, use the separate [CLI preview upgrade and uninstall guide](azure-managed-lustre-upgrade-uninstall-cli-preview.md).

For a new installation, see [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).

> [!IMPORTANT]
> Use the lifecycle procedure that matches your installation method. Don't run Helm or the cleanup script against an extension-managed driver, or use the AKS disable option to remove a Helm or script installation.

For a version update, start with [Upgrade the CSI driver](#upgrade-the-csi-driver). Don't follow the permanent-removal steps just to install v0.7.0.

## Choose the matching uninstall method

For permanent removal, use the method that matches how you installed the driver:

| Installation method | Matching uninstall method |
| --- | --- |
| Helm | Follow [Uninstall a Helm-managed driver](#uninstall-a-helm-managed-driver). |
| Script | Follow [Uninstall a script-managed driver](#uninstall-a-script-managed-driver). |
| AKS CLI options (preview): `az aks create` or `az aks update` with `--enable-azure-managed-lustre` or `--enable-amlfs` | Follow [Uninstall with AKS CLI options (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#uninstall-with-aks-cli-options-preview) and use `az aks update --disable-azure-managed-lustre` or `--disable-amlfs`. |

<a id="upgrade-a-helm-release"></a>

## Upgrade the CSI driver

For an existing Helm installation or managed extension, contact Microsoft Support for an update plan for your installed version and installation method. Don't uninstall the driver or delete volumes just to install v0.7.0.

For an older script installation, see [Replace a legacy script installation](#replace-a-legacy-script-installation). Don't use that procedure for a Helm installation or managed extension.

## Replace a legacy script installation

This procedure applies only to unmodified v0.2.0 through v0.6.0 script installations with the default CSI identity in `kube-system`. It uses the v0.6.0 cleanup script to remove the old driver resources without deleting volumes. For v0.4.0, this removal also resolves the [legacy DaemonSet selector incompatibility](#upgrade-a-v040-script-installation).

Don't use an older cleanup script to remove an installation already running v0.7.0. Its [uninstall guard](#uninstall-the-driver) blocks removal while matching PVs remain. If you need to replace a guarded installation while preserving its volume objects, stop and contact Microsoft Support; don't bypass the guard or delete claims to force replacement.

For a script installation that uses a custom identity or namespace, a change of installation method, or an installation whose existing identity you can't confirm, contact Microsoft Support for a migration procedure before changing the driver.

> [!IMPORTANT]
> Before replacing the script-installed driver, stop every workload that uses Lustre and confirm that no Lustre mounts remain on the nodes. You can't replace the Lustre client kernel modules while a Lustre mount is active. Removing the driver doesn't unmount application volumes. Keep workloads stopped until the driver is verified.
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

1. For a script installation, confirm that it uses the standard manifests without a custom entrypoint or other manifest changes. If it's customized, stop before removing the driver. Preserve the custom scripts, ConfigMaps, and manifest changes, and contact Microsoft Support for a compatible replacement plan. The cleanup script deletes the custom-entrypoint ConfigMap, and stock reinstallation doesn't restore it. Don't assume an older custom entrypoint is compatible with v0.7.0.

1. Inspect the CSI identities on existing PersistentVolumes before filtering the inventory:

   ```bash
   kubectl get pv -o custom-columns='NAME:.metadata.name,DRIVER:.spec.csi.driver,CLAIM-NAMESPACE:.spec.claimRef.namespace,CLAIM:.spec.claimRef.name'
   ```

   Use the Azure Lustre PVs' `spec.csi.driver` as the source of truth, not chart values alone. If `csidriver.name`, any existing `--drivername` argument, and those PV identities disagree, stop and contact Microsoft Support.

1. List the PersistentVolumes that use the Azure Lustre CSI driver. Set `DRIVER` to the verified installed identity; the default is shown below. Confirm that its `CSIDriver` object exists before continuing:

   ```bash
   DRIVER=azurelustre.csi.azure.com
   kubectl get csidriver "${DRIVER}"
   printf 'PV\tCLAIM\tSTATUS\tDELETING\n'
   kubectl get pv -o "jsonpath={range .items[?(@.spec.csi.driver==\"${DRIVER}\")]}{.metadata.name}{\"\t\"}{.spec.claimRef.namespace}{\"/\"}{.spec.claimRef.name}{\"\t\"}{.status.phase}{\"\t\"}{.metadata.deletionTimestamp}{\"\n\"}{end}"
   ```

   Use the claim references to account for every bound Azure Lustre claim, even if its StorageClass no longer exists.

1. List the storage classes that use the Azure Lustre CSI driver:

   ```bash
   kubectl get storageclass -o "jsonpath={range .items[?(@.provisioner==\"${DRIVER}\")]}{.metadata.name}{\"\n\"}{end}"
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

<a id="install-v060"></a>
<a id="upgrade-to-v070"></a>

### Install v0.7.0

This section covers an unmodified v0.2.0 through v0.6.0 **script installation**, not an existing Helm release or managed extension. Complete the preparation and unmount checks first. Keep Azure Managed Lustre workloads stopped until verification is complete.

1. Remove the existing driver, leaving PVs, PVCs, and file systems in place.

   For a script installation by using the default identity in `kube-system`, use the v0.6.0 cleanup script, which also removes legacy DaemonSets and RBAC:

   ```bash
   (
     set -e
     git clone --branch v0.6.0 --depth 1 https://github.com/kubernetes-sigs/azurelustre-csi-driver.git azurelustre-csi-driver-v0.6.0-cleanup
     cd azurelustre-csi-driver-v0.6.0-cleanup
     ./deploy/uninstall-driver.sh
     kubectl delete daemonset csi-azurelustre-node -n kube-system --ignore-not-found --wait=true
   )
   ```

   If removal fails or a guard blocks it, stop and contact Microsoft Support. Don't delete volumes, remove finalizers, or bypass hooks to proceed.

1. Confirm that the old controller, node DaemonSets, and pods are gone and that the old driver is no longer registered:

   ```bash
   kubectl get deployments,daemonsets,pods -n kube-system \
     -l 'app in (csi-azurelustre-controller,csi-azurelustre-node)'
   kubectl get csidriver "${DRIVER}" --ignore-not-found
   ```

   Both lists must be empty. An API error isn't proof of removal. Confirm that the original PVs and PVCs remain before installing the replacement.

1. Follow the [script installation procedure](azure-managed-lustre-install.md#install-with-the-script) to install v0.7.0. Use the same installation method, namespace, and CSI identity. Pass `v0.7.0` explicitly; omitting the version argument selects `main`.

1. Complete [Verify the upgrade](#verify-the-upgrade) before restarting workloads. If installation reports a timeout, inspect its state and diagnostics before retrying or attempting recovery.

### Upgrade a v0.4.0 script installation

The Jammy and Noble node DaemonSets that v0.4.0 installs use immutable selectors that differ from v0.6.0 and v0.7.0. Applying the new manifests over them fails with `spec.selector: field is immutable`.

Follow the complete [remove-and-replace procedure](#install-v070), not an in-place script upgrade. The v0.6.0 cleanup script removes both `csi-azurelustre-node-jammy` and `csi-azurelustre-node-noble`. Confirm that these DaemonSets and their pods are gone before installing v0.7.0, which recreates them with the new selectors. Preserve PVs, PVCs, and file systems throughout the replacement.

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

   Ready pods alone don't confirm that the expected Lustre client version is loaded. Check the version on every affected node before restarting workloads.

### Restart workloads

Keep Azure Managed Lustre workloads stopped until verification is complete. Then restart them and confirm that a representative workload's normal file operations succeed. You can inspect its mount with:

```bash
kubectl exec -n <namespace> <pod-name> -- df -h <mount-path>
```

Restore StatefulSets to their intended replica counts and verify that they reuse the original claims and file systems. Only after the workloads are running at those replica counts and their mounts are verified should you restore any recorded retention policies and resume automation. Don't restore a `Delete` policy while the StatefulSet is still scaled down for maintenance.

### Recover from an unsuccessful upgrade

> [!IMPORTANT]
> Keep Azure Managed Lustre workloads stopped while recovering from an unsuccessful upgrade. Don't install an arbitrary older driver release, because it might not support the node operating system, kernel, or Lustre client version in the cluster.

Use the [v0.7.0 troubleshooting guide](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.7.0/docs/csi-debug.md) and [v0.7.0 error reference](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.7.0/docs/errors.md) for diagnostics. Don't follow their generic upgrade or installer-repair examples in place of the script procedure in this article.

If you can't complete maintenance or confirm that existing Lustre mounts are gone, contact Microsoft Support before removing more resources. Don't delete claims, remove finalizers, or bypass hooks to recover. Complete [Verify the upgrade](#verify-the-upgrade) before restarting workloads.

## Uninstall the driver

Before scaling down StatefulSets, complete [Protect StatefulSet claims](#protect-statefulset-claims). Stop every workload that uses Lustre and confirm that no Lustre mounts remain before uninstalling the driver. Use the workload and mount checks in [Prepare for the upgrade](#prepare-for-the-upgrade). Uninstalling the driver doesn't remove existing mounts.

The following volume-cleanup steps are for permanent removal, not a [Helm upgrade](#upgrade-a-helm-release) or volume-preserving [script replacement](#install-v070).

An installed Helm release using chart 0.7.0 enables a pre-delete guard by default. Older releases don't gain this protection until they use chart 0.7.0. It checks all PVs whose `spec.csi.driver` matches the installed driver name, in every namespace and PV phase. It blocks removal for static and retained PVs as well as dynamically provisioned volumes. It also fails closed if the inventory query can't run. Unmounting volumes alone isn't enough.

Complete these steps while the driver is still running:

1. Stop provisioning and pause automation that recreates claims or workloads. Wait for in-flight volume creation and deletion to finish.
1. Inventory matching PVs and their reclaim policies. Use the installed CSI driver name verified against existing PVs in [Prepare for the upgrade](#prepare-for-the-upgrade); substitute it if your installation uses a custom identity:

   ```bash
   DRIVER=azurelustre.csi.azure.com
   kubectl get pv -o "jsonpath={range .items[?(@.spec.csi.driver==\"${DRIVER}\")]}{.metadata.name}{\"\t\"}{.spec.claimRef.namespace}{\"/\"}{.spec.claimRef.name}{\"\t\"}{.spec.persistentVolumeReclaimPolicy}{\"\t\"}{.status.phase}{\"\n\"}{end}"
   ```

1. Decide which file systems to retain. Before deleting a claim whose data you need, set and verify `Retain` on its **existing PV**, and save the PV configuration and file system mapping. Changing the StorageClass doesn't change existing PVs. See [Change the reclaim policy of a PersistentVolume](https://kubernetes.io/docs/tasks/administer-cluster/change-pv-reclaim-policy/).
1. Complete the selected [static](azure-managed-lustre-static-provisioning.md#clean-up-the-example) or [dynamic](azure-managed-lustre-dynamic-provisioning.md#clean-up-the-example) cleanup. With `Delete`, deleting a dynamically provisioned claim can delete its backing file system and data. With `Retain`, remove the remaining PV object only after its consumers and claim are gone and you've saved the mapping. The retained file system remains billable and can be reattached through static provisioning.
1. Repeat the inventory query until it succeeds with no matching PVs. An API error or incorrect driver name isn't proof that the inventory is empty. Investigate stuck finalizers with the driver still installed; don't strip finalizers to force removal.

The guard doesn't replace these checks and can't block deletion of an AKS cluster or Azure resource group. Verify backing file system resources separately.

### Uninstall a Helm-managed driver

Use the release name and namespace from your installation:

```bash
helm uninstall azurelustre --namespace kube-system --wait --timeout 30m
```

After the volume checks pass, Helm removes the resources in the release. A timeout can occur after deletion starts, so inspect the release and driver resources before retrying.

If the guard blocks removal, preserve its Job events and logs before retrying because failed Jobs expire and retries replace them. Resolve remaining PVs or restore the guard's cluster-wide permission to list PVs, then retry ordinary uninstall. Don't delete Helm release secrets or bypass hooks to clear the status. See the [blocked-uninstall reference](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.7.0/charts/README.md#troubleshoot-a-blocked-uninstall).

### Uninstall a script-managed driver

After completing the volume checks, use the v0.7.0 cleanup script for a script-managed installation using the default CSI identity and `kube-system` namespace. The script refuses removal while matching PVs remain or the check fails. For an older installation, also remove the legacy `csi-azurelustre-node` DaemonSet if it remains:

```bash
(
  set -e
  git clone --branch v0.7.0 --depth 1 https://github.com/kubernetes-sigs/azurelustre-csi-driver.git azurelustre-csi-driver-v0.7.0
  cd azurelustre-csi-driver-v0.7.0
  ./deploy/uninstall-driver.sh
  kubectl delete daemonset csi-azurelustre-node -n kube-system --ignore-not-found
)
```

These commands remove the CSI controller, node DaemonSets, `CSIDriver` object, and RBAC resources, not the retained Azure Managed Lustre file systems. Don't use `--force` to bypass the volume check. For a custom identity or namespace, contact Microsoft Support before using the script.

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
