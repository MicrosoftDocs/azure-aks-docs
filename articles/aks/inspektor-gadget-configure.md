---
title: Install and configure the Inspektor Gadget extension on AKS (preview)
description: Learn how to install, configure, and remove the Inspektor Gadget cluster extension on Azure Kubernetes Service (AKS) by using the Azure CLI.
author: mqasimsarfraz
ms.author: qasimsarfraz
ms.date: 06/26/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a Kubernetes administrator, I want to install and configure the Inspektor Gadget extension on AKS so that I can inspect and troubleshoot workloads on my cluster.
---

# Install and configure the Inspektor Gadget extension on AKS (preview)

This article shows how to install the [Inspektor Gadget](https://go.microsoft.com/fwlink/?LinkId=2260072) cluster extension on your Azure Kubernetes Service (AKS) cluster, change its configuration, and remove it.

The extension deploys Inspektor Gadget as a DaemonSet named `gadget` in the `gadget` namespace. You manage it through the Azure resource management plane by using the `az k8s-extension` commands. To learn how to inspect workloads after you install the extension, see [Run gadgets to inspect workloads on AKS](./inspektor-gadget-run-gadgets.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An AKS cluster with `kubectl` access. If you don't have one, see [Create an AKS cluster](./tutorial-kubernetes-deploy-cluster.md).
- The Azure CLI with the `k8s-extension` extension installed:

  ```azurecli-interactive
  az extension add --name k8s-extension
  ```

- Any existing Inspektor Gadget installation removed before you install the extension. If you previously deployed it manually, run `kubectl gadget undeploy` or `helm uninstall`.

In the commands in this article, replace `myResourceGroup` and `myAKSCluster` with the values for your environment.

## Install the extension

Install the extension by using `az k8s-extension create` with the `microsoft.inspektorgadget` extension type:

```azurecli-interactive
az k8s-extension create \
    --cluster-type managedClusters \
    --cluster-name myAKSCluster \
    --resource-group myResourceGroup \
    --name inspektor-gadget \
    --extension-type microsoft.inspektorgadget \
    --release-train preview
```

By default, the extension automatically upgrades its minor version. To keep it on the installed version instead, add `--auto-upgrade-minor-version false` to the install command.

### Verify the installation

Confirm that the extension is provisioned successfully and that the DaemonSet is running. The provisioning state should show `Succeeded`, and all gadget pods should be `Running` and `Ready`.

```azurecli-interactive
az k8s-extension show \
    --cluster-type managedClusters \
    --cluster-name myAKSCluster \
    --resource-group myResourceGroup \
    --name inspektor-gadget
```

```bash-interactive
kubectl get ds gadget -n gadget
kubectl get pods -n gadget -l k8s-app=gadget
```

## Configure the extension

Pass configuration settings by using the `--configuration-settings` parameter on `az k8s-extension update`. Organize settings in two levels:

- **Extension settings** at the top level configure the extension itself, such as integrations.
- **Inspektor Gadget settings** are under the `inspektor-gadget.` key, which in turn splits into runtime settings (`inspektor-gadget.config`) and Kubernetes resource settings (root level).

### Extension settings

Top-level settings configure the extension integrations:

| Setting | Description | Default |
|---------|-------------|---------|
| `azureMonitor.enabled` | Exports gadget metrics to Azure Monitor managed Prometheus. | `false` |

### Inspektor Gadget settings

Runtime settings under `inspektor-gadget.config` configure the gadget daemon:

| Setting | Description | Default |
|---------|-------------|---------|
| `inspektor-gadget.config.daemonLogLevel` | Daemon log level: `trace`, `debug`, `info`, `warning`, `error`, `fatal`, or `panic`. | `info` |
| `inspektor-gadget.config.hookMode` | How the daemon gets container notifications: `auto`, `crio`, `podinformer`, `nri`, or `fanotify+ebpf`. | `auto` |
| `inspektor-gadget.config.operator.oci.verify-image` | Verifies the signature of gadget images before running them. | `true` |
| `inspektor-gadget.config.operator.oci.allowed-gadgets` | Restricts which gadget images are allowed to run. | `[]` |

Kubernetes resource settings at the root level configure the `gadget` DaemonSet:

| Setting | Description | Default |
|---------|-------------|---------|
| `inspektor-gadget.nodeSelector` | Limits which nodes run the DaemonSet. | `kubernetes.io/os: linux` |
| `inspektor-gadget.tolerations` | Tolerations for the `gadget` container. | `{}` |
| `inspektor-gadget.resources` | CPU and memory requests and limits. | `{}` |
| `inspektor-gadget.hostPID` | Uses the host PID namespace. | `true` |
| `inspektor-gadget.additionalEnv` | Extra environment variables for the gadget container. | `[]` |

For the complete list of Inspektor Gadget values, see the [upstream chart `values.yaml`](https://go.microsoft.com/fwlink/?LinkId=2370616).

> [!IMPORTANT]
> `az k8s-extension update` is additive. New configuration settings merge with the existing ones. If an update fails, the broken setting can persist and block later updates. To recover, run `az k8s-extension update` again and explicitly revert the problematic setting.

> [!NOTE]
> Inspektor Gadget doesn't pick up configuration changes live. After you update settings, restart the DaemonSet to apply them:
>
> ```bash-interactive
> kubectl rollout restart daemonset/gadget -n gadget
> kubectl rollout status daemonset/gadget -n gadget --timeout=120s
> ```

For example, set the daemon log level to `debug`:

```azurecli-interactive
az k8s-extension update \
    --cluster-type managedClusters \
    --cluster-name myAKSCluster \
    --resource-group myResourceGroup \
    --name inspektor-gadget \
    --configuration-settings inspektor-gadget.config.daemonLogLevel=debug \
    --yes
```

## Remove the extension

When you no longer need Inspektor Gadget, delete the extension. This action removes the gadget pods, DaemonSet, and related resources.

```azurecli-interactive
az k8s-extension delete \
    --cluster-type managedClusters \
    --cluster-name myAKSCluster \
    --resource-group myResourceGroup \
    --name inspektor-gadget \
    --yes
```

## Next steps

- [Run gadgets to inspect workloads on AKS](./inspektor-gadget-run-gadgets.md)
- [Troubleshoot the Inspektor Gadget extension on AKS](./inspektor-gadget-troubleshoot.md)
- [Inspektor Gadget extension overview](./inspektor-gadget-overview.md)
