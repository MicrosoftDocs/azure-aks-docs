---
title: Deploy Periscope to an Azure Kubernetes Service (AKS) Cluster
description: Learn how to deploy Periscope to and collect diagnostic information from an AKS cluster using the Azure CLI, Visual Studio Code, Kustomize, or Azure Copilot.
ms.topic: how-to
ms.date: 08/11/2026
ms.service: azure-kubernetes-service
ms.custom: aeo-round-2
author: schaffererin
ms.author: schaffererin
---

# Deploy Periscope to an Azure Kubernetes Service (AKS) cluster

[AKS Periscope](https://github.com/Azure/aks-periscope) is an open-source diagnostic tool that collects logs and diagnostic information from Azure Kubernetes Service (AKS) nodes and pods. To deploy Periscope and collect diagnostics, run [`az aks kollect`](/cli/azure/aks#az-aks-kollect) and specify your cluster and an Azure storage account. You can also deploy Periscope using the [AKS extension for Visual Studio Code](./aks-extension-vs-code.md), [Kustomize](https://github.com/kubernetes-sigs/kustomize), or [Azure Copilot](/azure/copilot/work-aks-clusters#deploy-periscope-and-collect-logs).

Periscope collects the following information by default:

- Container logs from the `kube-system` namespace.
- Kubelet and container runtime system service logs.
- Outbound connectivity checks for the internet, API server, tunnel, Azure Container Registry, and Microsoft Container Registry.
- Node iptables data, provisioning logs, cloud-init logs, and DNS settings.
- Descriptions of pods, services, and deployments in the `kube-system` namespace.
- Kubelet command arguments and node and pod resource usage.

## Prerequisites

- You need an existing AKS cluster with Linux or Windows nodes. Periscope supports both operating systems, but the collected information differs. For more information, see [Windows and Linux functional differences](https://github.com/Azure/aks-periscope/blob/master/docs/windows-vs-linux.md).
- To deploy Periscope using the Azure CLI or Kustomize, install the [Azure CLI](/cli/azure/install-azure-cli) and sign in using [`az login`](/cli/azure/authenticate-azure-cli).
- To deploy Periscope using the Azure CLI, Visual Studio Code, or Kustomize, install [`kubectl`](https://kubernetes.io/docs/reference/kubectl/) version 1.21 or later.
- Create or identify an [Azure storage account](/azure/storage/common/storage-account-overview) for the collected diagnostics.
- Verify that your cluster can pull images from Microsoft Container Registry (MCR).

> [!IMPORTANT]
> Periscope runs on your agent pool nodes and collects virtual machine (VM) and container-level data. Before you deploy Periscope, confirm that the cluster owner understands and consents to the collection and sharing of this information. For more information, see [Microsoft Support diagnostic information collection](https://azure.microsoft.com/support/legal/support-diagnostic-information-collection/).

## Deploy Periscope using the Azure CLI

The [`az aks kollect`](/cli/azure/aks#az-aks-kollect) command deploys Periscope, collects the diagnostic information, and uploads the results to [Azure Blob Storage](/azure/storage/blobs/storage-blobs-overview).

1. Install or update the `aks-preview` extension.

    ```azurecli-interactive
    az extension add --name aks-preview --upgrade
    ```

1. Set environment variables for your AKS cluster.

    ```azurecli-interactive
    RESOURCE_GROUP=<resource-group-name>
    AKS_CLUSTER=<aks-cluster-name>
    ```

1. Deploy Periscope and collect diagnostics using one of the following storage account options.

    - If the AKS diagnostic settings already specify a storage account, run the following command:

        ```azurecli-interactive
        az aks kollect \
            --resource-group $RESOURCE_GROUP \
            --name $AKS_CLUSTER
        ```

    - To use a storage account that you own, specify its resource ID:

        ```azurecli-interactive
        STORAGE_ACCOUNT_ID=<storage-account-resource-id>

        az aks kollect \
            --resource-group $RESOURCE_GROUP \
            --name $AKS_CLUSTER \
            --storage-account $STORAGE_ACCOUNT_ID
        ```

    - To use a storage account name and a shared access signature (SAS) token, specify a SAS token that has write permission:

        ```azurecli-interactive
        STORAGE_ACCOUNT=<storage-account-name>
        SAS_TOKEN=<sas-token>

        az aks kollect \
            --resource-group $RESOURCE_GROUP \
            --name $AKS_CLUSTER \
            --storage-account $STORAGE_ACCOUNT \
            --sas-token "$SAS_TOKEN"
        ```

    > [!CAUTION]
    > A SAS token grants access to your storage account. Protect it like a password, don't commit it to source control, and revoke or rotate it when you no longer need it.

When collection finishes, Periscope stores the results in a blob container named after the cluster API server fully qualified domain name (FQDN). The container also includes a ZIP file that you can download for analysis or share with Microsoft Support.

### Customize the collected diagnostics

By default, Periscope collects logs and Kubernetes objects from the `kube-system` namespace. Use the optional `az aks kollect` parameters to target other resources.

- Collect all container logs in a namespace or a specific container:

    ```azurecli-interactive
    az aks kollect \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --container-logs "<namespace> <namespace>/<container-name>"
    ```

- Describe all objects of a resource type in a namespace or a specific object:

    ```azurecli-interactive
    az aks kollect \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --kube-objects "<namespace>/<resource-type> <namespace>/<resource-type>/<resource-name>"
    ```

- Collect specific Linux node log files:

    ```azurecli-interactive
    az aks kollect \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --node-logs "/var/log/azure-vnet.log /var/log/azure-vnet-ipam.log"
    ```

- Collect specific Windows node log files:

    ```azurecli-interactive
    az aks kollect \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --node-logs-windows 'C:\AzureData\CustomDataSetupScript.log'
    ```

You can combine these parameters with any storage account option from [Deploy Periscope using the Azure CLI](#deploy-periscope-using-the-azure-cli). For the complete command reference, see [`az aks kollect`](/cli/azure/aks#az-aks-kollect).

## Deploy Periscope using Visual Studio Code

The AKS extension for Visual Studio Code provides a graphical workflow for deploying Periscope and downloading the results.

1. [Install the Azure Kubernetes Service extension for Visual Studio Code](./aks-extension-vs-code.md#installation).
1. Sign in to Azure in Visual Studio Code.
1. Confirm that the AKS cluster diagnostic settings specify a storage account. If you need to configure one, complete the following steps:
    1. In the AKS extension, right-click your cluster and select **Show In Azure Portal**.
    1. In the Azure portal, select **Monitoring** > **Diagnostic settings** > **Add diagnostic setting**.
    1. Enter a name for the diagnostic setting, select **Archive to a storage account**, and select a storage account.
    1. Select the logs that you want to enable, and then select **Save**.
1. In the AKS extension, right-click your cluster and select **Run AKS Periscope**.
1. If the cluster has more than one storage account in its diagnostic settings, select the account where you want to store the results.
1. When collection finishes, select **Generate Link** to create a downloadable link or a shareable link that expires after seven days. If the results don't include every node, wait for the remaining uploads and then select **Generate Link** again.

For more information, see [AKS tools and diagnostics in Visual Studio Code](https://code.visualstudio.com/docs/azure/aksextensions#_aks-periscope).

## Deploy Periscope using Kustomize

Use Kustomize when you need to inspect or override the Kubernetes resources, choose a specific Periscope release, or customize the collectors. This method requires you to manage the storage credentials and manifests directly.

1. Create a directory for the Periscope configuration, and then create a `kustomization.yaml` file in that directory.
1. Create an account SAS with the following settings. Use the shortest practical expiration time.
    - **Service**: Blob (`ss=b`).
    - **Resource types**: Service, container, and object (`srt=sco`).
    - **Permissions**: Read, list, add, create, and write (`sp=rlacw`).
    - **Allowed protocol**: HTTPS only.
1. Add the Periscope base release, image tags, storage destination, SAS key, and run ID to the file. Replace every placeholder with your values. The SAS key must include the leading question mark (`?`).

    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
      - https://github.com/Azure/aks-periscope//deployment/base?ref=<release-tag>

    images:
      - name: periscope-linux
        newName: mcr.microsoft.com/aks/periscope
        newTag: <image-tag>
      - name: periscope-windows
        newName: mcr.microsoft.com/aks/periscope
        newTag: <image-tag>

    secretGenerator:
      - name: azureblob-secret
        behavior: replace
        literals:
          - AZURE_BLOB_ACCOUNT_NAME=<storage-account-name>
          - AZURE_BLOB_CONTAINER_NAME=<container-name>
          - AZURE_BLOB_SAS_KEY=?<sas-token>

    configMapGenerator:
      - name: diagnostic-config
        behavior: merge
        literals:
          - DIAGNOSTIC_RUN_ID=<YYYY-MM-DDThh-mm-ssZ>
    ```

    > [!CAUTION]
    > The `kustomization.yaml` file contains the SAS token in plaintext. Don't commit the file to source control. Protect the SAS like an account key, and revoke or rotate it when you no longer need it.

1. Connect `kubectl` to your AKS cluster.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name>
    ```

1. Deploy Periscope.

    ```bash
    kubectl apply -k <path-to-kustomize-directory>
    ```

1. Verify that the Periscope pods are running.

    ```bash
    kubectl get pods --namespace aks-periscope
    ```

For all available configuration values, optional Windows components, and instructions to run another collection, see the [AKS Periscope Kustomize deployment guide](https://github.com/Azure/aks-periscope#kustomize-deployment).

## Deploy Periscope using Azure Copilot

Use [Azure Copilot to deploy Periscope to an AKS cluster](/azure/copilot/work-aks-clusters#deploy-periscope-and-collect-logs). If Azure Copilot can't determine the cluster from the current context, it prompts you to select one. After you select the cluster, Azure Copilot might ask you to confirm the deployment details before it deploys Periscope.

Sample prompts include:

- "Help me deploy Periscope to my AKS cluster"
- "Deploy Periscope to my cluster"
- "Add Periscope to my cluster"
- "Add periscope logging to my cluster"
- "Help me collect diagnostics logs from my AKS cluster"

## Related content

- [Diagnose and resolve issues in AKS clusters](./aks-diagnostics.md)
- [Use the AKS extension for Visual Studio Code](./aks-extension-vs-code.md)
- [Create diagnostic settings in Azure Monitor](/azure/azure-monitor/essentials/diagnostic-settings)
