---
title: GitOps with AKS Edge Essentials
description: Learn how to use GitOps with AKS Edge Essentials.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Remote deployment and CI with GitOps and Flux

This article describes how to deploy applications to your Arc-enabled AKS Edge Essentials cluster. The steps are as follows:

1. Point to your GitHub application to the Azure portal.
1. Push your application to your AKS Edge Essentials cluster by installing the GitOps configuration.
1. Commit a change to your GitHub application and show that your app updates automatically.

> [!NOTE]
> Make sure you have allocated at least 4GB of RAM and 4 CPU for the Linux VM as well as a service IP range greater than 0. You might also need a larger disk space than the default 10 GB, depending on your workloads.

## Step 1: fork demo application repository

Go to the [Azure Arc Jumpstart repository](https://github.com/microsoft/azure-arc-jumpstart-apps) and fork it to your GitHub account.

## Step 2: create configuration

Go to your cluster in the Azure portal and select **GitOps**. Next, create a cluster-level configuration and a namespace-level configuration. Select **Create** and **Flux version 2**.

### Cluster-level configuration

| Attribute | Input |
| --- | --- |
| Configuration name | `config-nginx` |
| Namespace | `ingress-nginx` |
| Scope | Cluster |
| Source kind | Git repository |
| Repository URL | \<URL of your fork\>|
| Reference type | Branch |
| Branch | main |
| Repository type | Public |
| Sync interval | 1 |
| Sync timeout | 10 |
| **Kustomization** | |
| Instance name | `nginx` |
| Path | `./nginx/release` |
| Sync interval | 10 |
| Sync timeout | 10 |
| Prune | Enabled |
| Force | Not enabled |

Wait until the `config-nginx` is successfully created and visible on your Azure portal GitOps before creating the namespace-level configuration (you can move on to creating the next configuration if the compliance is in a pending state).

:::image type="content" source="../media/aks-edge/gitops-first-config.png" alt-text="Screenshot showing cluster-level configuration." lightbox="../media/aks-edge/gitops-first-config.png":::

### Namespace-level configuration

| Attribute | Input |
| --- | --- |
| Configuration name | `config-helloarc` |
| Namespace | `hello-arc` |
| Scope | Namespace |
| Source kind | Git Repository |
| Repository URL | \<URL of your fork\>|
| Reference type | Branch |
| Branch | main |
| Repository type | Public |
| Sync interval | 1 |
| Sync timeout | 10 |
| **Kustomization** | |
| Instance name | `app` |
| Path | `./hello-arc/releases/app` |
| Sync interval | 10 |
| Sync timeout | 10 |
| Prune | Enabled |
| Force | Not enabled |

:::image type="content" source="../media/aks-edge/gitops-second-config.png" alt-text="Screenshot showing namespace-level configuration." lightbox="../media/aks-edge/gitops-second-config.png":::

Refresh your configuration table and wait for the configuration to be installed and compliant. Using `kubectl`, check that the service is running:

```bash
kubectl get svc -n ingress-nginx
```

```bash
kubectl get pods -n hello-arc
```

:::image type="content" source="../media/aks-edge/hello-arc-pods-up.png" alt-text="Screenshot showing hello-arc service." lightbox="../media/aks-edge/hello-arc-pods-up.png":::

Open a web browser and navigate to your node IP, which is the `external-IP` of your `ingress-nginx-controller`:

:::image type="content" source="../media/aks-edge/hello-arc-app-success.png" alt-text="Screenshot of hello-arc application success." lightbox="../media/aks-edge/hello-arc-app-success.png":::

## Step 3: create Windows configuration (optional)

If you have a Windows node, you can also enable **flux2** for Windows. The **hello-arc-windows** sample uses a **hello-arc** Windows container.

> [!TIP]
> Windows containers are larger in size than Linux containers. The download of the **hello-arc-windows** container can take up to 15 minutes.

Create a new namespace-level configuration for Windows nodes.

### Namespace-level configuration for Windows

| Attribute | Input |
| --- | --- |
| Configuration name | `config-helloarc-windows` |
| Namespace | `hello-arc` |
| Scope | Namespace |
| Source kind | Git Repository |
| Repository URL | \<URL of your fork\>|
| Reference type | Branch |
| Branch | main |
| Repository type | Public |
| Sync interval | 1 |
| Sync timeout | 10 |
| **Kustomization** | |
| Instance name | `app` |
| Path | `./hello-arc-windows/releases/app` |
| Sync interval | 10 |
| Sync timeout | 10 |
| Prune | Enabled |
| Force | Not enabled |

## Step 4: update your application using GitOps

1. In your fork of the **azure-arc-jumpstart-apps** repository, navigate to **hello-arc > releases > app > hello-arc.yaml**.
1. Make a change to this YAML file by selecting **Edit**. Change the **replicaCount** to 5. Change the value to "Deploying to AKS Edge Essentials Gitops!"
1. Commit this change.

   > [!NOTE]
   > Because we set the **sync interval** to **1 min** when creating the configuration, Flux pulls down changes from GitHub every minute.

   :::image type="content" source="../media/aks-edge/edit-yaml.png" alt-text="Screenshot showing hello-arc yaml." lightbox="../media/aks-edge/edit-yaml.png":::

1. Use `kubectl` to see the old pods terminate and new pods come online:

    ```bash
    kubectl get pods -n hello-arc -w
    ```

    :::image type="content" source="../media/aks-edge/pods-rolling-update.png" alt-text="Screenshot showing pods rolling update." lightbox="../media/aks-edge/pods-rolling-update.png":::

1. Refresh your application to see this change reflected as a rolling update:

    :::image type="content" source="../media/aks-edge/app-update-success.png" alt-text="Screenshot showing updated hello-arc application." lightbox="../media/aks-edge/app-update-success.png":::

For more information about GitOps, see the [Azure Arc Jumpstart guide](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/microk8s/local_microk8s_gitops_helm/#deploy-gitops-configurations-and-perform-helm-based-gitops-flow-on-microk8s-as-an-azure-arc-connected-cluster).

## Next steps

- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
