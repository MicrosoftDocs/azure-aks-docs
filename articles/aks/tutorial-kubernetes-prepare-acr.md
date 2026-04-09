---
title: Kubernetes on Azure tutorial - Create an Azure Container Registry and build images
description: In this Azure Kubernetes Service (AKS) tutorial, you create an Azure Container Registry instance and upload sample application container images.
ms.topic: tutorial
ms.date: 04/07/2026
author: schaffererin
ms.author: schaffererin
ms.custom: mvc, devx-track-azurecli, devx-track-azurepowershell

# Customer intent: As a developer, I want to learn how to create and use a container registry so that I can deploy my own applications to Azure Kubernetes Service.

---

# Tutorial - Create an Azure Container Registry (ACR) and build images

Azure Container Registry (ACR) is a private registry for container images. A private container registry allows you to securely build and deploy your applications and custom code.

In this tutorial, you deploy an ACR instance and push a container image to it. You learn how to:

> [!div class="checklist"]
>
> - Create an ACR instance.
> - Use [ACR Tasks][acr-tasks] to build and push container images to ACR.
> - View images in your registry.

## Before you begin

In the [previous tutorial][aks-tutorial-prepare-app], you cloned the application code repository and used Docker to create a container image for a simple Azure Store Front application. If you didn't create the Azure Store Front app image, return to [Tutorial 1 - Prepare an application for AKS][aks-tutorial-prepare-app].

### [Azure CLI](#tab/azure-cli)

This tutorial requires Azure CLI version 2.0.53 or later. To find the version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].

### [Azure PowerShell](#tab/azure-powershell)

This tutorial requires Azure PowerShell version 5.9.0 or later. To find the version, run the `Get-InstalledModule -Name Az` command. If you need to install or upgrade, see [Install Azure PowerShell][azure-powershell-install].

---

## Create an Azure Container Registry

Before creating an ACR instance, you need a resource group. An Azure resource group is a logical container into which you deploy and manage Azure resources.

### [Azure CLI](#tab/azure-cli)

1. Create variables for the resource group name, location, and registry name. You can use these values or create your own. The registry name variable's value stored in `ACRNAME` must be unique within Azure and contain 5-50 lowercase alphanumeric characters.

    ```azurecli-interactive
    export RESOURCE_GROUP=myResourceGroup
    export LOCATION=westus2
    export RANDOM_STRING=$(printf '%05d%05d' "$RANDOM" "$RANDOM")
    export ACRNAME="myregistry${RANDOM_STRING}"
    ```

    The registry name variable's value stored in `ACRNAME` must be unique within Azure and contain 5-50 lowercase alphanumeric characters. The `ACRNAME` value is concatenated with the `RANDOM_STRING` variable that stores a random 10-digit string to ensure the registry name is unique. The variable `RESOURCE_GROUP` with the value _myResourceGroup_ for the resource group and `LOCATION` with the value _westus2_. You can use these values or create your own.

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

1. Create an ACR instance using the [`az acr create`][az-acr-create] command and provide your own unique registry name. The _Basic_ SKU is a cost-optimized entry point for development purposes that provides a balance of storage and throughput.

    ```azurecli-interactive
    az acr create \
      --resource-group $RESOURCE_GROUP \
      --location $LOCATION \
      --name $ACRNAME \
      --sku Basic
    ```

### [Azure PowerShell](#tab/azure-powershell)

1. Create variables for the resource group name, location, and registry name. You can use these values or create your own. The registry name variable's value stored in `ACRNAME` must be unique within Azure and contain 5-50 lowercase alphanumeric characters.

    ```azurepowershell-interactive
    $RESOURCE_GROUP="myResourceGroup"
    $LOCATION="westus2"
    $randobj=New-Object System.Random
    $RAND=$randobj.Next()
    $ACRNAME="myregistry$RAND"
    ```

    The registry name variable's value stored in `ACRNAME` must be unique within Azure and contain 5-50 lowercase alphanumeric characters. The `ACRNAME` value is concatenated with the `RAND` variable that stores a random 10-digit string to ensure the registry name is unique. The variable `RESOURCE_GROUP` with the value _myResourceGroup_ for the resource group and `LOCATION` with the value _westus2_. You can use these values or create your own.

1. Create a resource group using the [`New-AzResourceGroup`][new-azresourcegroup] cmdlet.

    ```azurepowershell-interactive
    New-AzResourceGroup -Name $RESOURCE_GROUP -Location $LOCATION
    ```

1. Create an ACR instance using the [`New-AzContainerRegistry`][new-azcontainerregistry] cmdlet and provide your own unique registry name. The _Basic_ SKU is a cost-optimized entry point for development purposes that provides a balance of storage and throughput.

    ```azurepowershell-interactive
    New-AzContainerRegistry -ResourceGroupName $RESOURCE_GROUP -Name $ACRNAME -Location $LOCATION -Sku Basic
    ```

---

## Build and push container images to registry

Build and push the images to your ACR using the Azure CLI [`az acr build`][az-acr-build] command. The `az acr build` commands use images in the repository you cloned in the previous article [prepare an app for AKS](tutorial-kubernetes-prepare-app.md). Make sure you switch to that directory or the `build` commands fail. For example, if you created directory _demorepo_ and cloned the repository, the repository's root directory is _aks-store-demo_, so switch to the _demorepo/aks-store-demo_ directory.

There isn't an equivalent Azure PowerShell cmdlet that builds or pushes container images to the registry. You need to use the steps for Azure CLI, but with the `ACRNAME` variable set to the value you created in PowerShell. In PowerShell you can get the value with the command `$ACRNAME`.

In the following example, we don't build the `product-service` image. This image can take a long time to build, and there's a container image already available in the GitHub Container Registry (GHCR). You can use the [`az acr import`][az-acr-import] command to import the image from the GHCR to your ACR instance. We also don't build the `rabbitmq` image. This image is available from the Docker Hub public repository and doesn't need to be built or pushed to your ACR instance.

```azurecli-interactive
az acr import \
  --name $ACRNAME \
  --source ghcr.io/azure-samples/aks-store-demo/product-service:latest \
  --image aks-store-demo/product-service:latest

az acr build \
  --registry $ACRNAME \
  --image aks-store-demo/order-service:latest ./src/order-service/

az acr build \
  --registry $ACRNAME \
  --image aks-store-demo/store-front:latest ./src/store-front/
```

## List images in registry

### [Azure CLI](#tab/azure-cli)

View the images in your ACR instance using the [`az acr repository list`][az-acr-repository-list] command.

```azurecli-interactive
az acr repository list --name $ACRNAME --output table
```

The following example output lists the available images in your registry:

```output
Result
----------------
aks-store-demo/product-service
aks-store-demo/order-service
aks-store-demo/store-front
```

### [Azure PowerShell](#tab/azure-powershell)

View the images in your ACR instance using the [`Get-AzContainerRegistryRepository`][get-azcontainerregistryrepository] cmdlet.

```azurepowershell-interactive
Get-AzContainerRegistryRepository -RegistryName $ACRNAME
```

The following example output lists the available images in your registry:

```output
aks-store-demo/productservice
aks-store-demo/orderservice
aks-store-demo/storefront
```

---

## Next steps

In this tutorial, you created an ACR and pushed images to it to use in an AKS cluster. You learned how to:

> [!div class="checklist"]
>
> - Create an ACR instance.
> - Use [ACR Tasks][acr-tasks] to build and push container images to ACR.
> - View images in your registry.

In the next tutorial, you learn how to deploy a Kubernetes cluster in Azure.

> [!div class="nextstepaction"]
> [Deploy Kubernetes cluster][aks-tutorial-deploy-cluster]

<!-- LINKS - internal -->
[az-acr-create]: /cli/azure/acr#az-acr-create
[az-acr-repository-list]: /cli/azure/acr/repository#az-acr-repository-list
[az-group-create]: /cli/azure/group#az-group-create
[azure-cli-install]: /cli/azure/install-azure-cli
[aks-tutorial-deploy-cluster]: ./tutorial-kubernetes-deploy-cluster.md
[aks-tutorial-prepare-app]: ./tutorial-kubernetes-prepare-app.md
[azure-powershell-install]: /powershell/azure/install-az-ps
[new-azresourcegroup]: /powershell/module/az.resources/new-azresourcegroup
[new-azcontainerregistry]: /powershell/module/az.containerregistry/new-azcontainerregistry
[get-azcontainerregistryrepository]: /powershell/module/az.containerregistry/get-azcontainerregistryrepository
[acr-tasks]: /azure/container-registry/container-registry-tasks-overview
[az-acr-build]: /cli/azure/acr#az-acr-build
[az-acr-import]: /cli/azure/acr#az-acr-import
