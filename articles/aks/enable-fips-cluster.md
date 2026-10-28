---
title: Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) clusters (preview)
description: Learn how to enable Federal Information Processing Standard (FIPS) at the cluster level for Azure Kubernetes Service (AKS) clusters.
author: everjing
ms.author: gaojing
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.date: 10/22/2026
ms.custom: template-how-to, devx-track-azurecli, linux-related-content
ai-usage: ai-assisted
# Customer intent: "As a cloud administrator, I want to enable FIPS compliance for AKS cluster, so that I can ensure the security of cryptographic modules and meet regulatory requirements while deploying applications."
---

# Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) clusters (preview)

The Federal Information Processing Standard (FIPS) is a US government standard that defines minimum security requirements for cryptographic modules in information technology products and systems. This article describes how to enable FIPS mode at the **cluster level** for Azure Kubernetes Service (AKS). Cluster-level FIPS enforces that every node pool in the cluster uses a FIPS-enabled OS image, and it blocks AKS-managed [components][aks-components] that aren't FIPS-compliant. This capability is intended for customers with compliance requirements such as FedRAMP who need a single, declarative way to ensure FIPS usage across their AKS cluster. For more information on FIPS, see [Federal Information Processing Standard (FIPS) 140][fips].

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What is FIPS mode in AKS?

FIPS 140-2/140-3 defines U.S. government standards for cryptographic modules. When you enable FIPS mode on an AKS cluster:

- All **node pools** in the cluster, including Windows node pools, must use FIPS-enabled OS images.
- AKS blocks creation of **non-FIPS node pools**.
- AKS blocks **AKS-managed add-ons, features, and extensions** that aren't validated for FIPS compliance.

Cluster-level FIPS (`properties.enableFIPS`) is separate from FIPS on individual node pools (`enableFIPS` on each agent pool). Cluster-level FIPS requires every node pool to be FIPS-enabled, but disabling cluster-level FIPS doesn't disable FIPS on your node pools. For more information about FIPS-enabled node pools, see [Enable FIPS for AKS node pools][fips-node-pools].

> [!IMPORTANT]
> FIPS mode applies to **AKS-managed infrastructure and components**. Customers remain responsible for ensuring their **own application containers** use FIPS-compliant cryptography.

## Prerequisites

- An active Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
- Azure CLI version 2.86.0 or later installed and configured. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][install-azure-cli].
- The latest version of the `aks-preview` Azure CLI extension. The `--enable-fips` and `--disable-fips` parameters are available only in the `aks-preview` extension. For instructions, see [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension).
- The `k8s-extension` Azure CLI extension, used to list and remove cluster extensions. Install it by running `az extension add --upgrade --name k8s-extension`.
- [kubectl](https://kubernetes.io/releases/download/) installed. You can install it locally by using the [`az aks install-cli`][az-aks-install-cli] command.
- The `EnableFIPSPreview` feature flag registered on your subscription. For instructions, see [Register the `EnableFIPSPreview` feature flag](#register-the-enablefipspreview-feature-flag).
- Kubernetes version 1.35.0 or later. To see the versions available in your region, use the [`az aks get-versions`][az-aks-get-versions] command. A FIPS-enabled cluster on an earlier version isn't grandfathered: AKS rejects every update to the cluster until you upgrade it to 1.35.0 or later or disable FIPS.
- If you use Azure Resource Manager (ARM) templates or the REST API, use API version `2026-03-02-preview` or later for `Microsoft.ContainerService/managedClusters` and `Microsoft.ContainerService/managedClusters/agentPools`.

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension by using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension by using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Set environment variables

Set the following environment variables for the resources that you use in this article. Replace the placeholder values with your own. Then set your subscription context by using the [`az account set`][az-account-set] command.

```azurecli-interactive
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="myResourceGroup"
export CLUSTER_NAME="myAKSCluster"
export NODE_POOL_NAME="fipsnp"

az account set --subscription $SUBSCRIPTION_ID
```

### Register the `EnableFIPSPreview` feature flag

1. Register the `EnableFIPSPreview` feature flag by using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "EnableFIPSPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

1. Verify the registration status by using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EnableFIPSPreview"
    ```

1. When the status shows *Registered*, refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Limitations

The following limitations apply when using FIPS-enabled AKS clusters.

- Some AKS-managed components aren't FIPS-compliant and are blocked on FIPS-enabled clusters. For the list, see [Blocked components](#blocked-components).

- Node pools that use a Kata workload runtime (`KataVmIsolation`, `KataMshvVmIsolation`, or `KataCcIsolation`) aren't supported.

- Node pools that use the preview node pool–level custom CA trust setting (`enableCustomCATrust`) aren't supported. Use [cluster-level custom certificate authority trust][custom-ca-trust] instead.

- All limitations documented for FIPS-enabled node pools also apply to FIPS-enabled clusters, including OS, image, and upgrade constraints. For details, see [Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) node pools][fips-node-pools].

### Blocked components

Some AKS-managed components aren't yet built with FIPS-compliant cryptographic libraries. You can't enable these components on a FIPS-enabled cluster, and you can't enable FIPS on a cluster that uses them. The following table lists the blocked components and the Azure CLI command to disable each one. Add `--resource-group $RESOURCE_GROUP --name $CLUSTER_NAME` to each `az aks` command.

> [!IMPORTANT]
> This list applies only to AKS-managed components. Customer application containers aren't validated by AKS.

| Blocked component | Disable command |
| --- | --- |
| [`cost-analysis`][cost-analysis] | `az aks update --disable-cost-analysis` |
| [`approuting`][approuting] | `az aks approuting disable` |
| [`defender`][defender] (Microsoft Defender for Containers security monitoring) | `az aks update --disable-defender` |
| [`azure-monitor`][azure-monitor] (managed Prometheus metrics, Container insights, and application monitoring) | `az aks update --disable-azure-monitor-metrics`<br/>`az aks disable-addons --addons monitoring`<br/>`az aks update --disable-azure-monitor-app-monitoring` |
| [`blob-csi`][blob-csi] | `az aks update --disable-blob-driver` |
| [`ACCSGXDevicePlugin`][sgx-device-plugin] | `az aks disable-addons --addons confcom` |
| [`IngressApplicationGateway`][ingress-app-gateway] | `az aks disable-addons --addons ingress-appgw` |
| [`calico`][calico], [`azure-npm`][azure-npm] | `az aks update --network-policy none` |
| [`cilium`][cilium] | You can't remove Cilium from an existing cluster. Create a new cluster. |
| [`acns-observability`][acns-observability] | `az aks update --disable-acns` or `az aks update --disable-acns-observability` |
| [`OpenServiceMesh`][service-mesh] | `az aks disable-addons --addons open-service-mesh` |
| [`kaito`][kaito] | `az aks update --disable-ai-toolchain-operator` |
| [Istio-based service mesh add-on][istio-about] revisions earlier than `asm-1-26` | Upgrade to revision `asm-1-26` or later. For instructions, see [Upgrade the Istio-based service mesh add-on][istio-upgrade]. |
| [Windows GPU driver installation][windows-gpu] | To add a Windows GPU node pool, skip driver installation by using `--gpu-driver none`. |
| Cluster extensions that aren't FIPS-compliant, such as Flux (GitOps). See the **FIPS** column in the [extension capability matrix][extensions-matrix]. | `az k8s-extension delete --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --cluster-type managedClusters --name <extension-name>` |

If an automation, such as an Azure Policy assignment, tries to install an extension that isn't FIPS-compliant on a FIPS-enabled cluster, AKS rejects the installation and the extension shows a `Failed` provisioning state. The cluster isn't affected.

## Create a FIPS-enabled AKS cluster

You can enable FIPS when you create the cluster by using the `--enable-fips` flag. The cluster can't use any of the [blocked components](#blocked-components).

1. Create a FIPS-enabled AKS cluster by using the [`az aks create`][az-aks-create] command with the `--enable-fips` parameter.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --kubernetes-version 1.35 \
        --enable-fips \
        --generate-ssh-keys
    ```

1. Verify your cluster is FIPS-enabled by using the [`az aks show`][az-aks-show] command and query for the *enableFips* value.

    ```azurecli-interactive
    az aks show \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "enableFips"
    ```

    The following example output shows your cluster is FIPS-enabled:

    ```output
    true
    ```

    If the command doesn't return `true`, you didn't install the `aks-preview` extension when you created the cluster. Without the extension, the Azure CLI treats `--enable-fips` as `--enable-fips-image` and enables FIPS only on the default node pool. [Install the `aks-preview` extension](#install-the-aks-preview-azure-cli-extension), and then [enable FIPS on the existing cluster](#update-an-existing-cluster-to-enable-fips).

1. Creating a FIPS-enabled cluster automatically creates a FIPS-enabled node pool. You can verify this by inspecting the node pool configuration by using the [`az aks show`][az-aks-show] command and query for the *enableFips* value in *agentPoolProfiles*.

    ```azurecli-interactive
    az aks show \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "agentPoolProfiles[].{Name:name, enableFips:enableFips}" \
        --output table
    ```

    The following example output shows the default node pool is FIPS-enabled:

    ```output
    Name       EnableFips
    ---------  ----------
    nodepool1  True
    ```

## Update an existing AKS cluster to enable or disable FIPS

To enable FIPS on an existing cluster, prepare the cluster first, and then update it.

### Prepare your cluster for FIPS

Complete the following steps before you enable FIPS at the cluster level.

1. Make sure the cluster runs **Kubernetes version 1.35.0 or later**. If your cluster is running an earlier version, upgrade the cluster first. For instructions, see [Upgrade an AKS cluster][upgrade-aks-cluster].

1. Make sure every node pool is FIPS-enabled. Update each **non-FIPS node pool** to use FIPS-enabled images. For instructions, see [Update an existing node pool to enable or disable FIPS][update-fips-node-pools].

    Windows Server 2022 node pools already run with FIPS enabled in the OS, but their `enableFips` property is `False` unless you set it. Run `az aks nodepool update --enable-fips-image` on these node pools too. For these node pools, the update sets the property and doesn't change the node image.

1. Disable or remove every component that's listed in [Blocked components](#blocked-components), including cluster extensions that aren't FIPS-compliant. To list the extensions on your cluster, use the [`az k8s-extension list`][az-k8s-extension-list] command. To remove an extension, use the [`az k8s-extension delete`][az-k8s-extension-delete] command. For more information, see [Manage AKS extensions][manage-aks-extensions].

    ```azurecli-interactive
    az k8s-extension list \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --cluster-type managedClusters \
        --query "[].{name:name, extensionType:extensionType, state:provisioningState}" \
        --output table
    ```

    > [!NOTE]
    > An extension can be installed automatically after cluster creation, for example by an Azure Policy assignment. List the extensions again right before you enable FIPS. If an assignment keeps installing an extension that isn't FIPS-compliant, exempt the cluster from that assignment.

### Update an existing cluster to enable FIPS

After you [prepare your cluster](#prepare-your-cluster-for-fips), enable FIPS. If the cluster doesn't meet a requirement, AKS rejects the update, and the error message describes the cause. For help, see [Troubleshoot cluster-level FIPS errors](#troubleshoot-cluster-level-fips-errors).

1. Update an AKS cluster by using the [`az aks update`][az-aks-update] command with the `--enable-fips` parameter.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-fips
    ```

1. Verify your cluster is FIPS-enabled by using the [`az aks show`][az-aks-show] command and query for the *enableFips* value.

    ```azurecli-interactive
    az aks show \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "enableFips"
    ```

    The following example output shows your cluster is FIPS-enabled:

    ```output
    true
    ```

### Update an existing cluster to disable FIPS

You can update an existing cluster to disable FIPS. When you disable FIPS mode:

- Cluster-level FIPS enforcement is removed.
- Existing node pools aren't modified.
- You can run both FIPS and non-FIPS node pools in the same cluster.
- You can deploy AKS extensions and add-ons that were previously blocked while FIPS was enabled.
- New node pools are no longer required to be FIPS-enabled.

> [!NOTE]
> Disabling FIPS doesn't automatically convert FIPS-enabled node pools to non-FIPS. If needed, you can update node pools individually. For instructions, see [Disable FIPS on an existing node pool][disable-fips-nodepool]. Windows Server 2025 node pools can't disable FIPS.

1. Update an AKS cluster by using the [`az aks update`][az-aks-update] command with the `--disable-fips` parameter.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --disable-fips
    ```

1. Verify your cluster isn't FIPS-enabled by using the [`az aks show`][az-aks-show] command and query for the *enableFips* value.

    ```azurecli-interactive
    az aks show \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "enableFips"
    ```

    The following example output shows your cluster isn't FIPS-enabled:

    ```output
    false
    ```

## Add a node pool to a FIPS-enabled AKS cluster

Every new node pool in a FIPS-enabled cluster must be FIPS-enabled. Add a node pool by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-fips-image` parameter. If you omit `--enable-fips-image`, AKS rejects the request.

```azurecli-interactive
az aks nodepool add \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name $NODE_POOL_NAME \
    --enable-fips-image
```

## Troubleshoot cluster-level FIPS errors

When a request conflicts with cluster-level FIPS, AKS rejects it, usually with a `BadRequest` error that describes the cause. For common error messages and how to resolve them, see [Troubleshoot cluster-level FIPS errors in AKS][troubleshoot-fips].

## Clean up resources

When you no longer need the resources you created in this article, delete the resource group and all related resources by using the [`az group delete`][az-group-delete] command.

```azurecli-interactive
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Related content

- [AKS security best practices][aks-best-practices-security]
- [FIPS for AKS node pools][fips-node-pools]
- [Federal Information Processing Standard (FIPS) 140][fips]
- [Troubleshoot cluster-level FIPS errors in AKS][troubleshoot-fips]

<!-- LINKS - Internal -->
[fips]: /azure/compliance/offerings/offering-fips-140-2
[aks-components]: aks-component-versioning.md#aks-components-overview
[fips-node-pools]: enable-fips-nodes.md
[update-fips-node-pools]: enable-fips-nodes.md#update-an-existing-node-pool-to-enable-or-disable-fips
[disable-fips-nodepool]: enable-fips-nodes.md#disable-fips-on-an-existing-node-pool
[aks-best-practices-security]: operator-best-practices-cluster-security.md
[upgrade-aks-cluster]: upgrade-aks-control-plane.md
[manage-aks-extensions]: cluster-extensions.md
[extensions-matrix]: cluster-extensions.md#extension-capability-matrix
[cost-analysis]: cost-analysis.md
[approuting]: app-routing.md
[defender]: /azure/defender-for-cloud/defender-for-containers-azure-enable-programmatically
[azure-monitor]: /azure/azure-monitor/containers/kubernetes-monitoring-enable
[blob-csi]: csi-storage-drivers.md
[sgx-device-plugin]: /azure/confidential-computing/confidential-nodes-aks-addon
[ingress-app-gateway]: /azure/application-gateway/ingress-controller-overview
[cilium]: azure-cni-powered-by-cilium.md
[calico]: use-network-policies.md#create-an-aks-cluster-with-calico
[azure-npm]: use-network-policies.md#create-an-aks-cluster-with-azure-network-policy-manager-linux
[acns-observability]: container-network-observability-how-to.md
[service-mesh]: open-service-mesh-about.md
[kaito]: ai-toolchain-operator.md
[windows-gpu]: use-windows-gpu.md#skip-gpu-driver-installation
[custom-ca-trust]: custom-certificate-authority.md
[istio-about]: istio-about.md
[istio-upgrade]: istio-upgrade.md
[troubleshoot-fips]: /troubleshoot/azure/azure-kubernetes/security/troubleshoot-cluster-level-fips
[install-azure-cli]: /cli/azure/install-azure-cli
[az-account-set]: /cli/azure/account#az-account-set
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-aks-get-versions]: /cli/azure/aks#az-aks-get-versions
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-k8s-extension-list]: /cli/azure/k8s-extension#az-k8s-extension-list
[az-k8s-extension-delete]: /cli/azure/k8s-extension#az-k8s-extension-delete
[az-group-delete]: /cli/azure/group#az-group-delete
