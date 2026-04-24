---
title: "Quickstart: Get Started Deploying and Managing Applications using AKS Automatic with AKS Desktop"
description: Learn how to deploy and manage a containerized application on Azure Kubernetes Service (AKS) using AKS desktop without writing Kubernetes manifests.
ms.service: azure-kubernetes-service
ms.subservice: aks-developer
ms.reviewer: schaffererin
author: danielsollondon
ms.topic: quickstart
ms.date: 04/16/2026
ms.author: danis
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Quickstart: Deploy and managed applications using AKS desktop

Deploying and managing Kubernetes applications typically requires writing YAML manifests, running kubectl commands, and switching between multiple tools. AKS desktop removes this complexity with guided workflows that let developers and DevOps engineers deploy, monitor, troubleshoot, and clean up applications without deep Kubernetes expertise.

This guide walks you through deploying a TypeScript application using AKS desktop, from creating a cluster through exploring application logs, metrics, scaling, and built-in troubleshooting tools.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).
- Azure CLI version 2.64.0 or later must be installed. Check your version using the [`az --version`](/cli/azure/reference-index#az-version) command. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The `aks-preview` Azure CLI extension. Install it using the `az extension add --name aks-preview` command.
- [AKS desktop](https://github.com/Azure/aks-desktop/releases) installed. AKS desktop supports the following operating systems (OS): Windows, Linux, and Mac.
- If using an existing cluster, the cluster needs to be Microsoft Entra ID authenticated. To ensure your cluster is Microsoft Entra ID authenticated, use an [AKS Automatic cluster](intro-aks-automatic.md). You also need the [Azure Kubernetes Service RBAC Cluster Admin role](manage-azure-rbac.md#aks-built-in-roles) or equivalent permissions on the target cluster.

## Create Azure resources

If you don't have an existing AKS cluster and Azure Container Registry (ACR), you can create them using the Azure CLI. These sections show how to create a new resource group, AKS cluster, and ACR. If you already have these resources, you can skip to [Register your cluster with AKS desktop](#register-your-cluster-with-aks-desktop).

### Set environment variables

To simplify the commands, set the following environment variables in your terminal. Make sure to set `myLocation` to your Azure region. The example here uses `RAND` to create unique resource names. You can replace these with your own values if you prefer.

```bash
RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"
myResourceGroup=bbash$RAND
myLocation=westus3
myClusterName=clu-$RAND
registryName=bbashreg$RAND
```

### Create a resource group

Create an Azure resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

```azurecli-interactive
az group create --name $myResourceGroup --location $myLocation
```

### Create an Azure container registry

Create an Azure container registry using the [`az acr create`](/cli/azure/acr#az-acr-create) command.

```azurecli-interactive
az acr create --resource-group $myResourceGroup --name $registryName --sku Basic
```

### Create an AKS cluster with ACR integration

Create an AKS cluster with ACR integration using the [`az aks create`](/cli/azure/aks#az-aks-create) command. The `--attach-acr` parameter grants the AKS cluster permission to pull images from the ACR. This example command also sets the `--sku` to `automatic`. We recommend using AKS Automatic clusters for the best experience with AKS desktop, but you can also use a Standard cluster.

```azurecli-interactive
az aks create --resource-group $myResourceGroup --name $myClusterName --sku automatic --attach-acr $registryName
```

### Grant cluster admin permissions

1. Get the cluster resource ID using the [`az aks show`](/cli/azure/aks#az-aks-show) command and set it to an environment variable.

    ```azurecli-interactive
    AKS_ID=$(az aks show --resource-group $myResourceGroup --name $myClusterName --query id --output tsv)
    ```

1. Grant yourself admin permissions to the cluster using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command with the [Azure Kubernetes Service RBAC Cluster Admin role](manage-azure-rbac.md#aks-built-in-roles). Make sure to replace `<your-entra-id>` with your Microsoft Entra ID object ID.

    ```azurecli-interactive
    az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" \
       --assignee <your-entra-id> \
       --scope $AKS_ID
    ```

## Create a container image for testing

This example creates an image from the [Contoso Air sample application](https://github.com/Azure-Samples/contoso-air), but you can use any container image to test deploying an application with AKS desktop. If you want to use a different image, make sure you replace the image details in the deployment steps.

1. Create a new directory, navigate into it, and clone the Contoso Air sample application. Then navigate to the web application directory. If you're using a different application or directory structure, adjust these commands accordingly.

    ```bash
    mkdir myapp
    cd myapp
    git clone https://github.com/Azure-Samples/contoso-air
    cd contoso-air/src/web
    ```

1. Build and push the container image to your container registry using the [`az acr build`](/cli/azure/acr#az-acr-build) command. If you're using a different image, make sure to update the image name and path accordingly.

    ```azurecli-interactive
    az acr build --resource-group $myResourceGroup --registry $registryName --image contosoair:v1 .
    ```

## Register your cluster with AKS desktop

1. Make sure you're signed in to AKS desktop with the same account that has access to the AKS cluster. Once signed in, select **Add from Azure Subscription**.
1. Enter the name of your Azure subscription if you have more than one. (Alternatively, select the arrow to open the drop-down list, then select your Azure subscription.)
1. Select your cluster, and then select **Register Cluster**

    ![A video demonstrating how to add a cluster to the AKS desktop app.](./media/aks-desktop-app/aks-desktop-app-add-cluster.gif)

## Create a managed Project in AKS desktop

1. In AKS desktop, navigate to the **Projects** tab and select **Create a New Managed Project**.
1. Configure the following Project settings:

   - **Basics**:
     - Project Name: For example, `my-dev-frontend`
     - Subscription: `<your-subscription-name>`
     - Cluster: `<your-cluster-name>`

    > [!NOTE]
    > When set the Azure subscription and AKS cluster, AKS desktop checks for cluster and subscription feature support required for the AKS desktop experience.

   - **Networking Policies**: You can leave the default settings for this quickstart or update them as needed.
     - To expose the application publicly, change **Ingress** to `Allow all traffic`.

   - **Compute Quota**: Leave default for the test application.
   - **Access**: Add someone or delete the entry by deleting the line item.

1. Under **Review**, verify the settings for your Project, and then select **Create Project**.

    :::image type="content" source="./media/aks-desktop-app/aks-desktop-new-project.png" alt-text="Screenshot of creating a new Project in AKS desktop.":::

## Deploy an application

1. Provide an application name, and then select **Create Application**.

    :::image type="content" source="./media/aks-desktop-app/aks-desktop-deploy-app.png" alt-text="Screenshot of creating a new application in AKS desktop.":::

1. Select a source for your application. For this example, select **Container Image** > **Next**.

    :::image type="content" source="./media/aks-desktop-app/aks-desktop-select-app-src.png" alt-text="Screenshot of selecting a source for a new application in AKS desktop.":::

1. Configure the following application settings. You can accept the defaults or update them as needed.

   - **Container image name**:
     - Add your container image name. In this example, we use `myacr.azurecr.io/contosoair:v1`.

      > [!IMPORTANT]
      > You can't use the `latest` tag. Specify an explicit tag such as `v1`.

   - **Networking**:
      - Target port: For the example container, set to `3000`.
      - Enable public access: Set if you want to access the application from a public URL.

   - **HPA (Horizontal Pod Autoscaler)**:
     - Enable HPA: Set to enable automatic scaling of the application based on resource usage.

1. Select **Deploy** to deploy the application. It might take a few minutes for the application to finish deploying. You can view the deployment status on the Project overview page. Wait until all resources show a healthy state before [exploring the application](#explore-the-application).

    :::image type="content" source="./media/aks-desktop-app/aks-desktop-project-overview.png" alt-text="Screenshot of a Project overview screen in AKS desktop.":::

## Explore the application

From the Project overview page, you can explore your application using the following tabs:

- **Resources**: View all Kubernetes resources for the application.
- **Map**: Visualize how all Kubernetes resources interact with and depend on each other.
- **Logs**: View pod logs.
- **Metrics**: View core application resource consumption.
- **Scaling**: View scaling events and make updates.
- **Insights**: Troubleshoot DNS failures, network traffic, and resource usage (preview). For more information, see [Troubleshoot an application in AKS desktop using Insights](aks-desktop-deploy-troubleshooting.md).
- **Delete**: Delete the Project.
- **AI assistant**: Use natural language to diagnose and resolve issues in your cluster (preview). For more information, see [Use the AI troubleshooting assistant in AKS desktop](aks-desktop-deploy-ai-assistant.md).

## Clean up resources

When you're finished with the quickstart, you can clean up the resources you created to avoid unnecessary costs.

To remove the project, select **Delete**. If you also want to remove the underlying Azure managed Namespace resource, select **Also delete the namespaces**.

## Related content

For more information about AKS desktop, see the following resources:

- [AKS desktop overview](aks-desktop-overview.md)
- [Set up permissions and RBAC for AKS desktop](aks-desktop-permissions.md)
