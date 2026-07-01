---
title: Use Image Cleaner on Azure Kubernetes Service (AKS)
description: Learn how to use Image Cleaner on AKS Automatic and AKS Standard to remove unused images with vulnerabilities.
ms.author: davidsmatlak
author: davidsmatlak
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/30/2026
ms.service: azure-kubernetes-service
# Customer intent: "As a DevOps engineer managing an AKS cluster, I want to configure Image Cleaner to automatically remove vulnerable stale images, so that I can enhance the security and efficiency of my image management process."
---

# Use Image Cleaner to clean up vulnerable stale images on your Azure Kubernetes Service (AKS) cluster

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

It's common to use pipelines to build and deploy images on Azure Kubernetes Service (AKS) clusters. While great for image creation, this process often doesn't account for the stale images left behind and can lead to image bloat on cluster nodes. These images might contain vulnerabilities, which might create security issues. To remove security risks in your clusters, you can clean these unreferenced images. Manually cleaning images can be time intensive. Image Cleaner performs automatic image identification and removal, which mitigates the risk of stale images and reduces the time required to clean them up.

AKS Automatic is the recommended production-ready default for most AKS workloads. Image Cleaner is preconfigured on AKS Automatic clusters to help remove unused images with vulnerabilities by default.

On AKS Standard clusters, Image Cleaner is optional and you enable it explicitly.

For more information about AKS Automatic, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

> [!NOTE]
> Image Cleaner is a feature based on [Eraser](https://eraser-dev.github.io/eraser). On AKS, the feature name and property name is `Image Cleaner`, while the relevant Image Cleaner pods' names contain `Eraser`.

## AKS Automatic and AKS Standard behavior

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- For AKS Standard configuration via Azure CLI, Azure CLI version 2.49.0 or later. Run `az --version` to find your version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].

## Limitations

Image Cleaner doesn't yet support Windows node pools or AKS virtual nodes.

## How Image Cleaner works

When you activate Image Cleaner on your cluster, it deploys a controller manager pod named `eraser-controller-manager`.

:::image type="content" source="./media/image-cleaner/image-cleaner.png" alt-text="Screenshot of a diagram showing ImageCleaner's workflow. The ImageCleaner pods running on the cluster can generate an ImageList, or manual input can be provided.":::

Image Cleaner supports automatic and manual cleanup modes.

## Configuration options for AKS Standard

Use these options when configuring Image Cleaner on AKS Standard with Azure CLI.

|Name|Description|Required|
|----|-----------|--------|
|`--enable-image-cleaner`|Enable Image Cleaner for an AKS cluster|Yes, unless you specify disable|
|`--disable-image-cleaner`|Disable Image Cleaner for an AKS cluster|Yes, unless you specify enable|
|`--image-cleaner-interval-hours`|Interval in hours for scheduled runs. Azure CLI default is one week. Minimum is 24 hours. Maximum is three months.|Not required for Azure CLI; required for ARM template or other clients|

> [!NOTE]
> If you disable Image Cleaner and later reenable it without explicitly passing configuration, the previous configuration value is reused.

### Automatic mode

When you deploy `eraser-controller-manager`, Image Cleaner automatically performs these actions:

- Starts cleanup and creates `eraser-aks-xxxxx` worker pods for each node.
- Uses a **collector** container to collect unused images.
- Uses a **trivy-scanner** container to scan vulnerabilities with [trivy](https://github.com/aquasecurity/trivy).
- Uses a **remover** container to remove unused images with vulnerabilities.
- Deletes the worker pod after completion.
- Schedules the next cleanup according to `--image-cleaner-interval-hours`.

### Manual mode

You can manually trigger the cleanup by defining a CRD object,`ImageList`. This triggers the `eraser-contoller-manager` to create `eraser-aks-xxxxx` worker pods for each node and complete the manual removal process.

> [!NOTE]
> After disabling Image Cleaner, the old configuration still exists. This means if you enable the feature again without explicitly passing configuration, the existing value is used instead of the default.

## Use Image Cleaner on AKS Automatic and AKS Standard

### AKS Automatic

Image Cleaner is preconfigured on AKS Automatic clusters, which are the recommended production-ready default for most AKS workloads. You don't need to run a separate enable command.

To create an AKS Automatic cluster, see [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md).

Use the manual cleanup and monitoring guidance in this article when you want targeted remediation or operational verification.

### AKS Standard: enable on a new cluster

Enable Image Cleaner on a new AKS Standard cluster using the [`az aks create`][az-aks-create] command with the `--enable-image-cleaner` parameter.

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myManagedCluster \
    --enable-image-cleaner \
    --generate-ssh-keys
```

### AKS Standard: enable on an existing cluster

Enable Image Cleaner on an existing AKS Standard cluster using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update \
  --resource-group myResourceGroup \
  --name myManagedCluster \
  --enable-image-cleaner
```

### AKS Standard: update interval on a new or existing cluster

Update the Image Cleaner interval on a new or existing AKS Standard cluster using the  `--image-cleaner-interval-hours` parameter.

```azurecli-interactive
# Create a new cluster with specifying the interval
az aks create \
    --resource-group myResourceGroup \
    --name myManagedCluster \
    --enable-image-cleaner \
    --image-cleaner-interval-hours 48 \
    --generate-ssh-keys

# Update the interval on an existing cluster
az aks update \
    --resource-group myResourceGroup \
    --name myManagedCluster \
    --enable-image-cleaner \
    --image-cleaner-interval-hours 48
```

## Manually remove images using Image Cleaner

> [!IMPORTANT]
> The `name` must be set to `imagelist`.

Manually remove an image using the following `kubectl apply` command. This example removes the `docker.io/library/alpine:3.7.3` image if it's unused.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: eraser.sh/v1
kind: ImageList
metadata:
  name: imagelist
spec:
  images:
    - docker.io/library/alpine:3.7.3
EOF
```

The manual cleanup is a one-time operation and is only triggered when a new `imagelist` is created or changes are made to the existing `imagelist`. After the image is deleted, the `imagelist` won't be deleted automatically.

If you need to trigger another manual cleanup, you have to create a new `imagelist` or make changes to an existing one. If you want to remove the same image again, you need to create a new `imagelist`.

### Delete an existing ImageList and create a new one

1. Delete the old `imagelist` using the `kubectl delete` command.

    ```bash
    kubectl delete ImageList imagelist
    ```

1. Create a new `imagelist` with the same image name. The following example uses the same image as the [previous example](#manually-remove-images-using-image-cleaner).

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: eraser.sh/v1
    kind: ImageList
    metadata:
      name: imagelist
    spec:
      images:
        - docker.io/library/alpine:3.7.3
    EOF
    ```

### Modify an existing ImageList

Modify the existing `imagelist` using the `kubectl edit` command.

```bash
kubectl edit ImageList imagelist

# Add a new image to the list
apiVersion: eraser.sh/v1
kind: ImageList
metadata:
  name: imagelist
spec:
  images:
      docker.io/library/python:alpine3.18
```

When using manual mode, the `eraser-aks-xxxxx` pod deletes within 10 minutes after work completion.

## Image exclusion list

Images specified in the exclusion list aren't removed from the cluster. Image Cleaner supports system and user-defined exclusion lists. It's not supported to edit the system exclusion list.

### Check the system exclusion list

Check the system exclusion list using the following `kubectl get` command.

```bash
kubectl get -n kube-system configmap eraser-system-exclusion -o yaml
```

### Create a user-defined exclusion list

1. Create a sample JSON file to contain excluded images.

    ```bash
    cat > sample.json <<EOF
    {"excluded": ["excluded-image-name"]}
    EOF
    ```

1. Create a `configmap` using the sample JSON file using the following `kubectl create` and `kubectl label` command.

    ```bash
    kubectl create configmap excluded --from-file=sample.json --namespace=kube-system
    kubectl label configmap excluded eraser.sh/exclude.list=true -n kube-system
    ```

## Disable Image Cleaner on AKS Standard

Disable Image Cleaner on an AKS Standard cluster using the [`az aks update`][az-aks-update] command with the `--disable-image-cleaner` parameter.

```azurecli-interactive
az aks update \
  --resource-group myResourceGroup \
  --name myManagedCluster \
  --disable-image-cleaner
```

## Frequently asked questions (FAQs)

### Is Image Cleaner enabled by default on AKS Automatic?

Yes. Image Cleaner is preconfigured on AKS Automatic clusters.

### Do I need to run enable commands for Image Cleaner on AKS Automatic?

No. Use the enable commands for AKS Standard.

### How can I check which version Image Cleaner is using?

```bash
kubectl describe configmap -n kube-system eraser-manager-config | grep tag -C 3
```

### Does Image Cleaner support other vulnerability scanners besides trivy-scanner?

No.

### Can I specify vulnerability levels for images to clean?

No. The default settings for vulnerability levels include:

- `LOW`,
- `MEDIUM`,
- `HIGH`, and
- `CRITICAL`

You can't customize the default settings.

### How to review images were cleaned up by Image Cleaner?

Image logs are stored in the `eraser-aks-xxxxx` worker pod. When `eraser-aks-xxxxx` is alive, you can run the following commands to view deletion logs:

```bash
kubectl logs -n kube-system <worker-pod-name> -c collector
kubectl logs -n kube-system <worker-pod-name> -c trivy-scanner
kubectl logs -n kube-system <worker-pod-name> -c remover
```

The `eraser-aks-xxxxx` pod deletes within 10 minutes after work completion. You can follow these steps to enable the [Azure Monitor add-on](./monitor-aks.md) and use the Container Insights pod log table. After that, historical logs will be stored and you can review them even `eraser-aks-xxxxx` is deleted.
  
1. Ensure Azure Monitor is enabled on your cluster. For detailed steps, see [Enable Container Insights on AKS clusters](/azure/azure-monitor/containers/container-insights-enable-aks#existing-aks-cluster).
1. By default, logs for the containers running in the `kube-system` namespace aren't collected. Remove the `kube-system` namespace from `exclude_namespaces` in the config map and apply the config map to enable collection of these logs. See [Configure Container insights data collection](/azure/azure-monitor/containers/container-insights-data-collection-configure#configure-data-collection-using-configmap) for details.
1. Get the Log Analytics resource ID using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
      az aks show --resource-group myResourceGroup --name myManagedCluster
    ```

     After a few minutes, the command returns JSON-formatted information about the solution, including the workspace resource ID:

     ```json
     "addonProfiles": {
       "omsagent": {
         "config": {
           "logAnalyticsWorkspaceResourceID": "/subscriptions/<WorkspaceSubscription>/resourceGroups/<DefaultWorkspaceRG>/providers/Microsoft.OperationalInsights/workspaces/<defaultWorkspaceName>"
         },
         "enabled": true
       }
     }
     ```

1. In the Azure portal, search for the workspace resource ID, and then select **Logs**.
1. Copy one of the following queries and paste it into the query window.
   - Use the following query if your cluster is using the [ContainerLogV2 schema](/azure/azure-monitor/containers/container-insights-logs-schema). If you're still using `ContainerLog`, upgrade to ContainerLogV2.

        ```kusto
        ContainerLogV2
        | where PodName startswith "eraser-aks-" and PodNamespace == "kube-system"
        | project TimeGenerated, PodName, LogMessage, LogSource
        ```

   - If you want to continue using `ContainerLog`, use the following query instead:

        ```kusto
        let startTimestamp = ago(1h);
        KubePodInventory
        | where TimeGenerated > startTimestamp
        | project ContainerID, PodName=Name, Namespace
        | where PodName startswith "eraser-aks-" and Namespace == "kube-system"
        | distinct ContainerID, PodName
        | join
        (
            ContainerLog
            | where TimeGenerated > startTimestamp
        )
        on ContainerID
        // at this point before the next pipe, columns from both tables are available to be "projected". Due to both
        // tables having a "Name" column, we assign an alias as PodName to one column which we actually want
        | project TimeGenerated, PodName, LogEntry, LogEntrySource
        | summarize by TimeGenerated, LogEntry
        | order by TimeGenerated desc
         ```

1. Select **Run**. Any deleted image logs appear in the **Results** area.

## Related content

- Learn more about AKS Automatic in [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)
- Create a production-ready AKS Automatic cluster with [Create an Azure Kubernetes Service (AKS) Automatic cluster](./automatic/quick-automatic-managed-network.md).

<!-- LINKS -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
