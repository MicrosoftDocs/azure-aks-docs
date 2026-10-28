---
title: Deploy from private container registry to on-premises Kubernetes using Azure Container Registry and AKS
description: Learn how to deploy container images from a private container registry using Azure Container Registry.
ms.topic: how-to
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 12/11/2023
ms.custom: sfi-ropc-nochange, hyperconverged
---

# Deploy from private container registry to on-premises Kubernetes using Azure Container Registry and AKS

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to deploy container images from a private container registry using Azure Container Registry, which you can run in your own datacenter in AKS deployments. You deploy to your on-premises Kubernetes cluster hosted by AKS. Azure Container Registry allows you to build, store, and manage container images and artifacts in a private registry for all types of container deployments.

The article describes how to create a private container registry in Azure and push your container image to the private container registry. You can then deploy from the private registry to your on-premises Kubernetes cluster hosted in AKS.

For more information about Azure Container Registry, see the [Azure Container Registry documentation](/azure/container-registry/).

## Prerequisites

Verify that you have the following requirements:

- A basic understanding of [Kubernetes concepts](../../windows-server/kubernetes-concepts.md).
- An AKS cluster that's up and running.
- [Azure CLI installed](/cli/azure/install-azure-cli)
- Your local kubectl environment configured to point to your AKS cluster.

## Create a private container registry in Azure

In order to create a container registry, begin with a *resource group*. An Azure resource group is a logical container into which Azure resources are deployed and managed. Create a resource group with the `az group create` command. The following example creates a resource group in the **eastus** region:

```azurecli
az group create --name <RESOURCE_GROUP_NAME> --location eastus
```

Create a Container Registry instance with the [az acr create](/cli/azure/acr) command, and provide your own registry name. The registry name must be unique within Azure and contain 5 to 50 alphanumeric characters. In the rest of this article, `<acrName>` is used as a placeholder for the container registry name, but you can provide your own unique registry name. The **Basic** SKU is a cost-optimized entry point for development purposes that provides a balance of storage and throughput:

```azurecli
az acr create --resource-group <RESOURCE_GROUP_NAME> --name <REGISTRY_NAME> --sku Basic
```

After you create your container registry, use the following command to create a service principal, so you can access your container registry
from Kubernetes:

```azurecli
az ad sp create-for-rbac /
--scopes /subscriptions/<SUBSCRIPTION_ID>/resourcegroups/<RG_NAME>/providers/Microsoft.ContainerRegistry/registries/<REGISTRY_NAME> /
--role Contributor /
--name <SERVICE_PRINCIPAL_NAME>
```

Azure Container Registry supports three access roles. The **Contributor** role is used most commonly by application developers. However, in real world scenarios, you might need to create multiple service principals depending on the type of access needed:

- **Contributor**: This role offers push and pull access to the repository.
- **Reader**: This role only allows pull access to the repository.
- **Owner**: This role enables you to assign roles to other users, in addition to the push and pull access to the repository.

The previous command should produce output similar to the following text:

```output
{
"appId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"displayName": "akshci-service-principal",
"name": "http://akshci-service-principal",
"password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"tenant": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Once the service principal is successfully created, copy the appId and password in a safe location, to use later in your deployment.

For more information about working with service principals and Azure Container Registry, see [Azure Container Registry authentication with service principals](/azure/container-registry/container-registry-auth-service-principal).

## Sign in to the private container registry

To use the Container Registry instance, you must first sign in. You can use either the Azure CLI or the Docker CLI to sign in.

### Option 1: Sign in from the Azure CLI

Use the [az acr sign in](/cli/azure/acr#az-acr-login) command and provide the unique name assigned to the container registry in the previous step:

```azurecli
az acr login --name <REGISTRY_NAME>
```

### Option 2: Sign in from the Docker CLI

To use the Docker CLI to access your container registry, type the following command in a Bash or PowerShell terminal:

```powershell
docker login <REGISTRY_NAME>.azurecr.io -u <appId> -p <password>
```

In either option, the command should return a **sign in succeeded** message when it completes.

## Push an image to the container registry

Once you're successfully logged in, you can start pushing the image to the Container Registry. First, run the docker images command to view the list of images on your local machine:

```output
REPOSITORY TAG IMAGE ID CREATED SIZE

mcr.microsoft.com/azure-functions/dotnet 3.0 9f8ad1bdee67 5 months ago
540MB

poemfinder-app latest 2d9bef425603 6 months ago 208MB
```

To get started, tag the image using the docker `tag` command, and then use docker `push` to push it to the container registry:

```powershell
docker tag poemfinder-app <REGISTRY_NAME>.azurecr.io/poemfinder-app:v1.0
```

Verify that the image was correctly tagged by running the docker images command again. After confirming, run `docker push` to push to the
container registry, as follows:

```powershell
docker push <REGISTRY_NAME>.azurecr.io/poemfinder-app:v1.0
```

To confirm that the image was successfully pushed to the container registry, run the following command:

```azurecli
az acr repository list --name <REGISTRY_NAME>.azurecr.io --output table
```

## Deploy an image from the container registry to AKS

To deploy your container image from the container registry to your Kubernetes cluster, create *Kubernetes Secrets* to store your registry credentials. Kubernetes uses an *image pull secret* to store information needed to authenticate to your registry. To create the pull secret for a container registry, you provide the service principal ID, the password, and the registry URL:

```powershell
kubectl create secret docker-registry <secret-name> \
--namespace <namespace> \
--docker-server=<REGISTRY_NAME>.azurecr.io \
--docker-username=<appId> \
--docker-password=<password>
```

The following table describes the input parameters:

|      Value     |      Description     |
|---|---|
|     `secret-name`    |     Name of the image pulls secret; for example, `acr-secret`.    |
|     `namespace`    |     Kubernetes namespace into which to put the secret. Only needed if you want to place the secret in a namespace other than the default namespace.    |
|     `<REGISTRY_NAME>`    |     Name of your container registry. For example, `myregistry`.   The `--docker-server` is the fully qualified name of the registry sign-in server.    |
|     `appId`    |     ID of the service principal that Kubernetes uses to access your registry.    |
|     `password`    |     Service principal password.    |

Once you create the image pull secret, you can use it to create Kubernetes pods and deployments. Provide the name of the secret under `imagePullSecrets` in the deployment file, as shown in the following example:

```yml
apiVersion: v1
kind: Pod
metadata:
 name: poemfinder-app
 namespace: mydemoapps
spec:
 containers:
  - name: poemfinder-app
    image: <REGISTRY_NAME>.azurecr.io/poemfinder-app:v1.0
    imagePullPolicy: IfNotPresent
 imagePullSecrets:
   - name: acr-secret
```

In this example, `poemfinder-app:v1.0` is the name of the image to pull from the container registry, and `acr-secret` is the name of the pull secret you created to access the registry. When you deploy the pod, Kubernetes automatically pulls the image from your registry if the image isn't already present on the cluster.

You can save the above pod configuration in a file such as **pod-example.yaml** and then deploy it to Kubernetes, as follows:

```powershell
kubectl create -f pod-example.yaml
```

To confirm that the pod was successfully created using the container image from the container registry, run kubectl describe pod <POD_NAME>, which should show the container image used to create the pod.

## Next steps

- [Review AKS on Azure Local prerequisites](network-system-requirements.md)
- [What's new in AKS on Azure Local](/azure/azure-local/whats-new)
