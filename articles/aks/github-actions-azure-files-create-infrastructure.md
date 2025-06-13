---
title: Create the infrastructure for deploying highly available GitHub Actions on Azure Kubernetes Service (AKS)
description: Learn how to create the infrastructure for deploying highly available GitHub Actions on Azure Kubernetes Service (AKS) using Azure Files.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/13/2025
author: schaffererin
ms.author: schaffererin
ms.custom: 'stateful-workloads'
---

# Create the infrastructure for deploying highly available GitHub Actions on Azure Kubernetes Service (AKS) using Azure Files

In this article, you create the infrastructure needed to deploy a highly available Actions Runner Controller (ARC) infrastructure on AKS using Azure Files and Helm.

## Before you begin

* Review the [deployment overview](./github-actions-azure-files-overview.md) and make sure you meet the prerequisites.
* [Set environment variables](#set-environment-variables) for use throughout this guide.
* [Install the required extensions](#install-required-extensions).

### Set environment variables

Set the following environment variables for use throughout this guide:

```bash
export AKS_AND_STORAGE_ACCOUNT_RG="aks-files-actions" 
export AKS_CLUSTER_NAME="aks-actions" 
export STORAGE_ACCOUNT_NAME="metadatacaching11" 
export AKS_STORAGE_ACCOUNT_LOCATION="westus3" 
export GITHUB_CONFIG_URL="https://github.com/jorgearteiro/azurefiles-actions-aks" 

# Optional. Changes might require additional changes on ./install/*.yaml files.

export NAMESPACE_ARC_CONTROLLER="arc-systems" 
export ARC_CONTROLLER_NAME="arc-controller" 
export NAMESPACE_ARC_RUNNERS="arc-runners" 
export ARC_RUNNER_SCALESET_NAME="arc-runner-set" 
export ARC_RUNNER_GITHUB_SECRET_NAME="arc-runner-github-secret"
```

Make sure to replace the values for the following **required** variables:

* `AKS_AND_STORAGE_ACCOUNT_RG` with the name of the resource group used by the storage account and AKS cluster.
* `AKS_CLUSTER_NAME` with the name of the AKS cluster.
* `STORAGE_ACCOUNT_NAME` with the name of the storage account.
* `AKS_STORAGE_ACCOUNT_LOCATION` with the name of the region to create the resources in. In this example, we deploy them in the same region as the AKS cluster to facilitate performance and cost management.
* `GITHUB_CONFIG_URL` with the URL to the GitHub organization or repository.

Please keep the following **optional** variables as their defaults if possible:

* `NAMESPACE_ARC_CONTROLLER`: The name of Kubernetes namespace to run ARC runners scale set controller.
* `ARC_CONTROLLER_NAME`: The name of ARC runners scale set controller.
* `NAMESPACE_ARC_RUNNERS`: The name of Kubernetes namespace to run ARC self-hosted runners.
* `ARC_RUNNER_SCALESET_NAME`: The name of ARC runners scale set.
* `ARC_RUNNER_GITHUB_SECRET_NAME`: The name of GitHub secret.

### Install required extensions

The *aks-preview*, *k8s-extension* and *amg* extensions provide more functionality for managing Kubernetes clusters and querying Azure resources. Install these extensions using the following `az extension add` commands:

```azurecli-interactive
az extension add --upgrade --name aks-preview --yes --allow-preview true 
az extension add --upgrade --name k8s-extension --yes --allow-preview false 
az extension add --upgrade --name amg --yes --allow-preview false
```

## Create a resource group

Create a resource group using the [`az group create`](/cli/azure/group#az-group-create) command. This resource group will hold the AKS cluster and the Azure Files storage account.

```azurecli-interactive
az group create \ 
    --name $AKS_AND_STORAGE_ACCOUNT_RG \ 
    --location $AKS_STORAGE_ACCOUNT_LOCATION
```

## Create an AKS cluster

Create an AKS cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command.

```azurecli-interactive
az aks create --resource-group "${AKS_AND_STORAGE_ACCOUNT_RG}" --name "${AKS_CLUSTER_NAME}" \ 
    --os-sku AzureLinux \ 
    --node-count 1 \ 
    --enable-cluster-autoscaler \ 
    --min-count 1 \ 
    --max-count 3 \ 
    --node-vm-size standard_d4s_v5 \ 
    --max-pods=100 \ 
    --network-plugin azure \ 
    --network-plugin-mode overlay \ 
    --generate-ssh-keys
```

## Connect to the AKS cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/). kubectl is already installed if you use Azure Cloud Shell. To install kubectl locally, use the `az aks install-cli` command.

1. Configure kubectl to connect to your Kubernetes cluster using the `az aks get-credentials command`. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group "${AKS_AND_STORAGE_ACCOUNT_RG}" --name "${AKS_CLUSTER_NAME}"
    ```

1. Verify the connection to your cluster using the `kubectl get nodes` command. This command returns a list of nodes in your AKS cluster.

    ```bash
    kubectl get nodes
    ```

## Create an Azure file share

Before you can use an Azure Files file share as a Kubernetes volume, you need to create an Azure storage account and file share. In this guide, we use *Azure file share Premium SMB* with support for metadata caching. The minimum is *100 Gb* for each share you create.

1. Create a storage account using the [`az storage account create`](/cli/azure/storage/account#create) command. The following command creates a storage account using the Premium_LRS SKU.

    ```azurecli-interactive
    az storage account create --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${AKS_AND_STORAGE_ACCOUNT_RG}" \
        --location "${AKS_STORAGE_ACCOUNT_LOCATION}" \
        --sku Premium_LRS \
        --kind FileStorage
    ```

1. Export the connection string as an environment variable, which you use to create the file share, using the [`az storage account show-connection-string`](/cli/azure/storage/account#az-storage-account-show-connection-string) command.

    ```azurecli-interactive
    export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${AKS_AND_STORAGE_ACCOUNT_RG}" --query connectionString -o tsv)
    ```

1. Create the 100 Gb Premium file share using the [`az storage share create`](/cli/azure/storage/share#create) command. In this example, we use *metadatacaching* as the share name. If you change this name, you also have to change the `arc-runners-set-pv.yaml` file to reflect this change.

    ```azurecli-interactive
    az storage share create --name metadatacaching --quota 100 --connection-string "${AZURE_STORAGE_CONNECTION_STRING}"
    ```

## Install the ARC runners scale set controller

Install the ARC runners scale set controller using the following `helm install` command.

```bash
helm install "${ARC_CONTROLLER_NAME}" \ 
    --namespace "${NAMESPACE_ARC_CONTROLLER}" \ 
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

## Create Kubernetes secrets

### Azure file share storage key secret

Azure Files requires that you create a secret on AKS with the storage key used to connect the Azure file share from the AKS pod container.

1. Export the storage account key as an environment variable using the [`az storage account keys list`](/cli/azure/storage/account#az-storage-account-keys-list) command.

    ```azurecli-interactive
    STORAGE_KEY=$(az storage account keys list --resource-group ${AKS_AND_STORAGE_ACCOUNT_RG} --account-name ${STORAGE_ACCOUNT_NAME} --query "[0].value" -o tsv) 
    ```

1. Create a Kubernetes namespace to run ARC self-hosted runners using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace "${NAMESPACE_ARC_RUNNERS}" 
    ```

1. Create a Kubernetes secret to store the Azure file share storage key using the `kubectl create secret generic` command.

    ```bash
    kubectl create secret generic azure-storage-secret \ 
       --namespace "${NAMESPACE_ARC_RUNNERS}" \ 
       --from-literal=azurestorageaccountname=${STORAGE_ACCOUNT_NAME} \ 
       --from-literal=azurestorageaccountkey=${STORAGE_KEY}
    ```

### GitHub app secret

1. Create a GitHub app to allow the self-hosted runner to access your GitHub organization or repository using the [Registering a GitHub app](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) guide. The GitHub creation process provides you with the following parameters:

    * `GITHUB_APP_ID`: The ID of the GitHub app.
    * `GITHUB_APP_INSTALLATION_ID`: The installation ID of the GitHub app.
    * `github_app_private_key`: The private key of the GitHub app. You need to replace the *-----BEGIN RSA PRIVATE KEY-----* section with your private key.

1. Create a Kubernetes secret to store the GitHub app credentials using the `kubectl create secret generic` command. Make sure you replace the placeholders with the actual values you obtained from the GitHub app creation process.

    ```bash
    GITHUB_APP_ID="app-id-placeholder"
    GITHUB_APP_INSTALLATION_ID="installation-id-placeholder"
    
    kubectl create secret generic ${ARC_RUNNER_GITHUB_SECRET_NAME} \ 
        --namespace=${NAMESPACE_ARC_RUNNERS} \
        --from-literal=github_app_id=${GITHUB_APP_ID} \
        --from-literal=github_app_installation_id=${GITHUB_APP_INSTALLATION_ID} \
        --from-literal=github_app_private_key=' <Private Key read here>'
    ```

## Azure file share configurations

You can mount an Azure Files file share in multiple pods at same time using `AccessMode: ReadWriteMany` to mount the same file share in all pods created by the ARC Kubernetes replica set.
We use the Azure Files file share in the following ways:

* As a **persistent SMB file share** to cache NUGET packages used by the .NET sample application. The *[arc-runners-set-pv-pvc.yaml](https://github.com/jorgearteiro/azurefiles-actions-aks/blob/main/install/arc-runners-set-pv.yaml)* file creates the required PV and PVC to mount the Azure Files file share in the ARC runners scale set pods. We recommend Azure File Premium for this first option. Please customize `volumeAttributes` and any namespaces parameters on both PV and PVC manifests as shown in the following example:

    ```yaml
    volumeAttributes: 
      resourceGroup: metadata-agroves  # Optional. Only set this when the storage account isn't in the same resource group as node. 
      shareName: metadatacaching
    nodeStageSecretRef:
      name: azure-storage-secret
      namespace: arc-runners
    ```

* As an **ephemeral volume** for the GitHub runners work folder. We also create two storage classes: Azure Files Standard (`github-azurefile`) and Azure File Premium (`github-azurefile-premium`). These classes allow you to create and delete volumes on demand. When a GitHub job runs, a new runner pod is created on Kubernetes and a new Azure File file share is created and mounted. The volume lives only during the job run. Standard class allows any volume size and Premium allows a minimum of *100 Gb* volume. You can select whichever class you prefer. Keep in mind that Premium gives you a better performance. You can customize the `arc-runners-storage-class-files.yaml` file, but it's not required.

### Create the persistent volume and persistent volume claim

1. Create the persistent volume and persistent volume claim using the `kubectl apply` command.

    ```bash
    kubectl apply -f ./install/arc-runners-set-pv-pvc.yaml --namespace "${NAMESPACE_ARC_RUNNERS}" --wait 
    ```

1. Apply the storage class for Azure Files using the `kubectl apply` command.

    ```bash
    kubectl apply -f ./install/arc-runners-storage-class-files.yaml --wait 
    ```

### Install the ARC runner scale set

The following code snippet is from the `arc-runners-set-values.yaml` file in the install folder that you can customize before installing the runner set Helm chart.

```yaml
containerMode: 
  type: "kubernetes" # Type can be set to dind or kubernetes 
  ## The following is required when containerMode.type=kubernetes 
  kubernetesModeWorkVolumeClaim: 
    accessModes: ["ReadWriteMany"] 
    storageClassName: "github-azurefile-premium" # or "github-azurefile" for Standard_LRS 
    resources: 
      requests: 
        storage: 100Gi # 100Gi minimum to premium or any size when using Standard_LRS "github-azurefile" storage class 
template: 
  spec: 
  securityContext: 
    fsGroup: 123 # Group used by GitHub default agent image 
  containers: 
  - name: runner 
    image: ghcr.io/actions/actions-runner:latest 
    command: ["/home/runner/run.sh"] 
    env: 
      - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER 
        value: "false" 
      - name: ACTIONS_RUNNER_CONTAINER_HOOK_TEMPLATE 
        value: "/home/runner/container-config/container-podspec.yaml" 
    volumeMounts: 
      - name: "container-podspec-volume" 
        mountPath: "/home/runner/container-config" 
      - name: azurefile 
        mountPath: /home/runner/.nuget/              
  volumes: 
    - name: "container-podspec-volume" 
      configMap: 
        name: hook-extension 
    - name: azurefile 
      persistentVolumeClaim: 
        claimName: azurefile 
```

In this example, we use a customized version the Kubernetes `containerMode` to include Azure File file share volume mountings to NUGET packages and to the ephemeral _work folder volume.

The following parameters aren't mandatory to change:

* `storageClassName`: Choose between "github-azurefile-premium" and "github-azurefile".
* `storage`: Choose the size of the storage. 100 Gb minimum for Premium.

The other Helm parameters are set on the `helm install` command using the `--set` option.

For compatibility with the GitHub Workflow container feature that allows you to run containers inside your pipeline, we mount a `container-podspec-volume` with the pod spec for the workflow pod created by ARC when running workflows with the container feature. This pod spec is mounted from a config map created on `arc-runners-set-container-pod-spec.yaml` file in the install folder. No changes are required.

```bash
kubectl apply -f ./install/arc-runners-set-container-pod-spec.yaml 
```

### ARC runners scale set Helm chart parameters

The ARC runner scale set Helm chart provides a few parameters. The following parameters are the most important ones when installing a scale set with Azure File share volume mount on AKS:

* `githubConfigUrl`: Your GitHub organization or repository.
* `githubConfigSecret`: The GitHub app secret to access GitHub from the self-hosted runner.
* `minRunners`: Minimum number of runners on the scale set waiting for new jobs from GitHub.
* `maxRunners`: Maximum number of runners running jobs or waiting for new jobs from GitHub.
* `runnerGroup`: GitHub runner group used by the ARC runner set.

You can download the ARC runner scale set Helm chart [here](https://github.com/actions/actions-runner-controller/pkgs/container/actions-runner-controller-charts%2Fgha-runner-scale-set/).

### Install the Helm chart on AKS

Install the ARC runner scale set Helm chart on AKS using the `helm install` command.

```bash
helm install "${ARC_RUNNER_SCALESET_NAME}" \ 
    --namespace "${NAMESPACE_ARC_RUNNERS}" \ 
    --create-namespace \ 
    --values ./install/arc-runners-set-values.yaml \ 
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \ 
    --set githubConfigSecret="${ARC_RUNNER_GITHUB_SECRET_NAME}" \ 
    --set minRunners=1 \ 
    --set maxRunners=3 \ 
    --set runnerGroup=default \ 
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

### Upgrade a runner scale set installation

If you want to upgrade any configuration on the ARC runner scale set, you can use the `helm upgrade --install` command with the same parameters you used to install the scale set. For example, if you want to change the `minRunners` parameter from *1* to *2*, you can run the following command:

```bash
helm upgrade --install "${ARC_RUNNER_SCALESET_NAME}" \
    --namespace "${NAMESPACE_ARC_RUNNERS}" \
    --create-namespace \
    --values ./install/arc-runners-set-values.yaml \
    --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
    --set githubConfigSecret="${ARC_RUNNER_GITHUB_SECRET_NAME}" \
    --set minRunners=2 \
    --set maxRunners=3 \
    --set runnerGroup=default \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Next step

> [!div class="nextstepaction"]
> [Deploy and test highly available GitHub Actions with Azure Files on AKS](./github-actions-azure-files-deploy-test.md)

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Jorge Arterio | Senior Cloud Advocate
* Jeff Patterson | Principal Product Manager
* Rena Shah | Senior Product Manager
* Erin Schaffer | Content Developer 2
