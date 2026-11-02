---
title: Install the managed Kueue extension on Azure Kubernetes Service (AKS) (preview)
description: Install and verify managed Kueue on AKS.
ms.topic: how-to
ms.date: 10/22/2026
author: colinmixon
ms.author: colinmixon
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ai-usage: ai-assisted
# Customer intent: "As an AKS administrator, I want to install, verify, update, and uninstall the managed Kueue extension."
---

# Install the managed Kueue extension on Azure Kubernetes Service (AKS) (preview)

The managed Kueue extension installs and manages the supported Kueue controller on Azure Kubernetes Service (AKS). It also generates ResourceFlavors for eligible user nodes and provides default workload priority classes that you can reference from your own queues and workloads.

This article shows you how to install, verify, update, and uninstall the extension by using the Azure CLI. For concepts, see [Managed Kueue extension overview](./managed-kueue-extension-overview.md). To configure queues and try workload admission and preemption, see [Schedule and deploy batch jobs with the managed Kueue extension](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An AKS cluster that runs Kubernetes 1.34 or later. To create one, see [Create an AKS cluster using the Azure CLI](./learn/quick-kubernetes-deploy-cli.md).
- A current version of the [Azure CLI](/cli/azure/install-azure-cli) and the `k8s-extension` CLI extension version 1.9.3 or later.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) compatible with your cluster version.
- Permissions to manage cluster extensions, retrieve cluster credentials, and read the Kubernetes resources used to verify the installation.

## Limitations

- The managed extension currently supports cluster autoscaler integration. Node auto-provisioning and AKS Automatic aren't supported by this preview.
- [Uninstall an existing self-hosted Kueue installation](#uninstall-the-existing-self-hosted-kueue) before installing the managed extension, or use a clean target cluster. Kueue is a cluster singleton; installation rejects an unmanaged controller even in another namespace. Preserve configuration and review active and queued workloads before planning an uninstall.
- Supported workload integrations include Kubernetes Job, Pod, Deployment, StatefulSet, JobSet, Ray, MPIJob, and Trainer v2 TrainJob.
- Legacy Kubeflow v1 jobs, AppWrapper, and LeaderWorkerSet aren't supported integrations in this managed preview.

## Prepare your environment

Set your subscription and cluster details:

```bash
SUBSCRIPTION_ID="<subscription-id>"
RESOURCE_GROUP="<resource-group>"
CLUSTER_NAME="<aks-cluster-name>"
EXTENSION_NAME="aks-kueue"
RELEASE_TRAIN="preview"

az login
az account set --subscription "$SUBSCRIPTION_ID"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
az extension add --name k8s-extension --upgrade
az extension show --name k8s-extension --query version --output tsv
```

Register the resource providers if they aren't already registered:

```bash
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
```

## Uninstall the existing self-hosted Kueue

Skip this section if your cluster doesn't have a self-hosted Kueue controller. If it does, plan its uninstall before you install the managed extension.

> [!WARNING]
> Uninstalling self-hosted Kueue can delete its CRDs and all custom resources of those types. Before you proceed, save important configuration and workload manifests in your own source of truth. Preserve ClusterQueues, LocalQueues, ResourceFlavors, workload priority classes, and admission policies that you need to recreate. Review running and queued workloads, preserve application data, and pause GitOps reconciliation so that it doesn't reinstall the old controller.

Follow the supported uninstall procedure for the version and installation method that you used. For a Helm installation, first identify its release and namespace:

```bash
helm list --all-namespaces
```

After you verify the release identity and preserve the required information, uninstall that self-hosted release:

```bash
OSS_KUEUE_RELEASE="<self-hosted-release-name>"
OSS_KUEUE_NAMESPACE="<self-hosted-release-namespace>"

helm uninstall "$OSS_KUEUE_RELEASE" --namespace "$OSS_KUEUE_NAMESPACE"
```

For a manifest-based installation, follow the [upstream uninstall instructions](https://kueue.sigs.k8s.io/docs/installation/). Confirm that the old controller is no longer running before continuing. Don't transfer ownership of a self-hosted controller or its CRDs to the managed extension.

After you install the managed extension, restore only your customer-owned queue and workload configuration. Reference the new managed resources rather than restoring old controller manifests or creating replacements with reserved AKS names.

## Install the managed Kueue extension

Check which extension versions are available for your cluster and release train:

```bash
az k8s-extension extension-types list-versions-by-cluster \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --extension-type microsoft.kueue \
  --release-train "$RELEASE_TRAIN" \
  --output table
```

If no compatible version is returned, check the prerequisites and package availability before continuing.

Install the extension into the required `kueue-system` namespace. This example enables compatible automatic upgrades and doesn't specify an exact version:

```bash
az k8s-extension create \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --extension-type microsoft.kueue \
  --scope cluster \
  --release-namespace kueue-system \
  --release-train "$RELEASE_TRAIN" \
  --auto-upgrade-mode compatible
```

Don't install another Kueue controller or use direct Helm operations to configure the managed release.

## Verify the extension installation

Use the same extension resource name that you used during installation:

```bash
az k8s-extension show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --query '{name:name,version:currentVersion,provisioningState:provisioningState,extensionState:extensionState,statuses:statuses}' \
  --output json
```

Confirm that provisioning succeeds and the extension reports availability. Then check both controller deployments and the managed Kueue APIs:

```bash
kubectl rollout status deployment/kueue-controller-manager --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kueue-extension --namespace kueue-system --timeout=5m
kubectl wait --for=condition=Established \
  crd/clusterqueues.kueue.x-k8s.io \
  crd/localqueues.kueue.x-k8s.io \
  crd/resourceflavors.kueue.x-k8s.io \
  crd/workloadpriorityclasses.kueue.x-k8s.io \
  crd/workloads.kueue.x-k8s.io \
  --timeout=2m
```

If these checks fail, inspect extension status, controller events, and logs before making further changes. Don't replace managed CRDs with definitions from an upstream release. See [Troubleshoot cluster extension deployment errors](/troubleshoot/azure/azure-kubernetes/extensions/cluster-extension-deployment-errors).

## Update the managed Kueue extension

Use the version-listing command in [Install the managed Kueue extension](#install-the-managed-kueue-extension) to check which versions are available for your cluster.

In the same shell session, or after you redefine the variables in [Prepare your environment](#prepare-your-environment), enable compatible automatic upgrades for an existing extension:

```bash
az k8s-extension update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --release-train "$RELEASE_TRAIN" \
  --auto-upgrade-mode compatible \
  --yes
```

Don't combine an exact `--version` with automatic upgrades. Repeat the [verification checks](#verify-the-extension-installation) after an update and confirm the installed version.

## Uninstall the managed Kueue extension

Uninstall the extension only when you intend to stop using Kueue, not as a controller-health workaround.

> [!WARNING]
> Uninstalling managed Kueue deletes Kueue custom resources across the cluster, including customer-created LocalQueues, ClusterQueues, ResourceFlavors, Workloads, and other queue configuration. Cleanup also clears finalizers that block deletion. Preserve customer-owned configuration in Git or export it before uninstalling. Pause GitOps reconciliation during the planned uninstall.

Kubernetes Jobs and their pods aren't deleted when you uninstall Kueue. Running Jobs continue without Kueue management, while queued Jobs remain suspended. A later installation creates new Workloads for surviving Jobs that still have a queue label; it doesn't restore the deleted queue policy or admission state.

Use the actual extension resource name and the cluster variables from [Prepare your environment](#prepare-your-environment). If you didn't install it in this session, discover its name with `az k8s-extension list` before deleting it:

```bash
az k8s-extension delete \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --yes
```

Before submitting queued Jobs after a new installation, restore and verify your customer-owned queue configuration. Don't delete CRDs or manually clear finalizers to bypass a failed uninstall.

<!-- Preserve published links to the workload walkthrough moved to the batch guide. -->
<a id="understand-managed-kueue-resources"></a>
<a id="add-a-cpu-user-node-pool"></a>
<a id="create-a-clusterqueue-and-localqueue"></a>
<a id="use-workload-priority-and-preemption"></a>

For generated resource flavors, node-pool setup, queue configuration, and the low- and high-priority example, continue to [Schedule and deploy batch jobs](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md#use-workload-priority-and-preemption).

## Next steps

- [Schedule and deploy batch jobs using managed ResourceFlavors and priorities](./schedule-and-deploy-batch-jobs-with-managed-kueue-extension-on-aks.md).
- [Use managed Kueue with the cluster autoscaler](./use-managed-kueue-extension-with-the-cluster-autoscaler-on-aks.md).
- [Run Ray AI workloads with Kueue](./ray-overview.md).
