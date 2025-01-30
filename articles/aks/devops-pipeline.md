---
title: Deploy to Azure Kubernetes Service with Azure Pipelines
description: Build and push images to Azure Container Registry; Deploy to Azure Kubernetes Service with Azure Pipelines
ms.topic: how-to
ms.author: jukullam
author: juliakm
ms.date: 01/30/2025
ms.custom: devops-pipelines-deploy, devx-track-azurepowershell
zone_pivot_groups: pipelines-version
---

# Build and deploy to Azure Kubernetes Service with Azure Pipelines


**Azure DevOps Services**

Use [Azure Pipelines](/azure/devops/pipelines/) to automatically deploy to Azure Kubernetes Service (AKS). Azure Pipelines lets you build, test, and deploy with continuous integration (CI) and continuous delivery (CD) using [Azure DevOps](/azure/devops/). 

In this article, you'll learn how to create a pipeline that continuously builds and deploys your app. Every time you change your code in a repository that contains a Dockerfile, the images are pushed to your Azure Container Registry, and the manifests are then deployed to your AKS cluster.

## Prerequisites

* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* An Azure Resource Manager service connection. [Create an Azure Resource Manager service connection](/azure/devops/pipelines/library/connect-to-azure#create-an-azure-resource-manager-service-connection-using-automated-security).     
* A GitHub account. Create a free [GitHub account](https://github.com/join) if you don't have one already.

## Get the code

Fork the following repository containing a sample application and a Dockerfile:

```
https://github.com/MicrosoftDocs/pipelines-javascript-docker
```

## Create the Azure resources

Sign in to the [Azure portal](https://portal.azure.com/), and then select the [Cloud Shell](/azure/cloud-shell/overview) button in the upper-right corner. Use Azure CLI or PowerShell to create an AKS cluster. 

### Create a container registry

#### [Azure CLI](#tab/cli)

```azurecli-interactive
# Create a resource group
az group create --name myapp-rg --location eastus

# Create a container registry
az acr create --resource-group myapp-rg --name mycontainerregistry --sku Basic

# Create a Kubernetes cluster
az aks create \
    --resource-group myapp-rg \
    --name myapp \
    --node-count 1 \
    --enable-addons monitoring \
    --generate-ssh-keys
```

#### [PowerShell](#tab/powershell)

```powershell
# Install Azure PowerShell
Install-Module -Name Az -Repository PSGallery -Force

# The Microsoft.OperationsManagement resource provider must be registered. This is a one-time activity per subscription.
Register-AzResourceProvider -ProviderNamespace Microsoft.OperationsManagement

# Create a resource group
New-AzResourceGroup -Name myapp-rg -Location eastus

# Create a container registry
New-AzContainerRegistry -ResourceGroupName myapp-rg -Name myContainerRegistry -Sku Basic -Location eastus

# Create a log analytics workspace (or use an existing one)
New-AzOperationalInsightsWorkspace -ResourceGroupName myapp-rg -Name myWorkspace -Location eastus

# Create an AKS cluster with monitoring add-on enabled
$aksParameters = @{ 
  ResourceGroupName = 'myapp-rg'
  Name = 'myapp'
  NodeCount = 1
  AddOnNameToBeEnabled = 'Monitoring'
  GenerateSshKey = $true
  WorkspaceResourceId = '/subscriptions/<subscription-id>/resourceGroups/myapp-rg/providers/Microsoft.OperationalInsights/workspaces/myWorkspace'
}

New-AzAksCluster @aksParameters
```

--- 


## Sign in to Azure Pipelines

Sign in to [Azure Pipelines](https://azure.microsoft.com/services/devops/pipelines). After you sign in, your browser goes to `https://dev.azure.com/my-organization-name` and displays your Azure DevOps dashboard.

Within your selected organization, create a _project_. If you don't have any projects in your organization, you see a **Create a project to get started** screen. Otherwise, select the **Create Project** button in the upper-right corner of the dashboard.

## Create the pipeline

### Connect and select your repository

1. Sign in to your Azure DevOps organization and go to your project.

1. Go to **Pipelines**, and then select **New pipeline**.

1. Do the steps of the wizard by first selecting **GitHub** as the location of your source code.

1. You might be redirected to GitHub to sign in. If so, enter your GitHub credentials.

1. When you see the list of repositories, select your repository.

1. You might be redirected to GitHub to install the Azure Pipelines app. If so, select **Approve & install**.

1. Select **Deploy to Azure Kubernetes Service**. 

1. If you're prompted, select the subscription in which you created your registry and cluster.

1. Select the `myapp` cluster.

1. For **Namespace**, select **Existing**, and then select **default**.

1. Select the name of your container registry.

1. You can leave the image name set to the default.

1. Set the service port to 8080.

1. Set the **Enable Review App for Pull Requests** checkbox for [review app](/azure/devops/pipelines/process/environments-kubernetes) related configuration to be included in the pipeline YAML autogenerated in subsequent steps.

1. Select **Validate and configure**.

   As Azure Pipelines creates your pipeline, the process will:

   * Create a _Docker registry service connection_ to enable your pipeline to push images into your container registry.

   * Create an _environment_ and a Kubernetes resource within the environment. For an RBAC-enabled cluster, the created Kubernetes resource implicitly creates ServiceAccount and RoleBinding objects in the cluster so that the created ServiceAccount can't perform operations outside the chosen namespace.

   * Generate an *azure-pipelines.yml* file, which defines your pipeline.

   * Generate Kubernetes manifest files. These files are generated by hydrating the [deployment.yml](https://github.com/Microsoft/azure-pipelines-yaml/blob/master/templates/resources/k8s/deployment.yml) and [service.yml](https://github.com/Microsoft/azure-pipelines-yaml/blob/master/templates/resources/k8s/service.yml) templates based on selections you made. When you're ready, select **Save and run**.

1. Select **Save and run**.

1. You can change the **Commit message** to something like _Add pipeline to our repository_. When you're ready, select **Save and run** to commit the new pipeline into your repo, and then begin the first run of your new pipeline!

## See your app deploy

As your pipeline runs, watch as your build stage, and then your deployment stage, go from blue (running) to green (completed). You can select the stages and jobs to watch your pipeline in action.

> [!NOTE]
> If you're using a Microsoft-hosted agent, you must add the IP range of the Microsoft-hosted agent to your firewall. Get the weekly list of IP ranges from the [weekly JSON file](https://www.microsoft.com/download/details.aspx?id=56519), which is published every Wednesday. The new IP ranges become effective the following Monday. For more information, see [Microsoft-hosted agents](/azure/devops/pipelines/agents/hosted?tabs=yaml&view=azure-devops&preserve-view=true#networking).
> To find the IP ranges that are required for your Azure DevOps organization, learn how to [identify the possible IP ranges for Microsoft-hosted agents](/azure/devops/pipelines/agents/hosted?tabs=yaml&view=azure-devops&preserve-view=true#to-identify-the-possible-ip-ranges-for-microsoft-hosted-agents).
    
After the pipeline run is finished, explore what happened and then go see your app deployed. From the pipeline summary:

1. Select the **Environments** tab.

1. Select **View environment**.

1. Select the instance of your app for the namespace you deployed to. If you used the defaults, then it is the **myapp** app in the **default** namespace.

1. Select the **Services** tab.

1. Select and copy the external IP address to your clipboard.

1. Open a new browser tab or window and enter &lt;IP address&gt;:8080.

If you're building our sample app, then _Hello world_ appears in your browser.

<a name="how"></a>

## How the pipeline builds

When you finished selecting options and then proceeded to validate and configure the pipeline Azure Pipelines created a pipeline for you, using the _Deploy to Azure Kubernetes Service_ template.

The build stage uses the [Docker task](/azure/devops/pipelines/tasks/build/docker) to build and push the image to the Azure Container Registry.

```YAML
- stage: Build
  displayName: Build stage
  jobs:  
  - job: Build
    displayName: Build job
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build and push an image to container registry
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
          
    - task: PublishPipelineArtifact@1
      inputs:
        artifactName: 'manifests'
        path: 'manifests'
```

The deployment job uses the _Kubernetes manifest task_ to create the `imagePullSecret` required by Kubernetes cluster nodes to pull from the Azure Container Registry resource. Manifest files are then used by the Kubernetes manifest task to deploy to the Kubernetes cluster. The manifest files, `service.yml` and `deployment.yml`, were generated when you used the **Deploy to Azure Kubernetes Service** template. 

```YAML
- stage: Deploy
  displayName: Deploy stage
  dependsOn: Build
  jobs:
  - deployment: Deploy
    displayName: Deploy job
    pool:
      vmImage: $(vmImageName)
    environment: 'myenv.aksnamespace' #customize with your environment
    strategy:
      runOnce:
        deploy:
          steps:
          - task: DownloadPipelineArtifact@2
            inputs:
              artifactName: 'manifests'
              downloadPath: '$(System.ArtifactsDirectory)/manifests'

          - task: KubernetesManifest@1
            displayName: Create imagePullSecret
            inputs:
              action: 'createSecret'
              connectionType: 'kubernetesServiceConnection'
              kubernetesServiceConnection: 'myapp-default' #customize for your Kubernetes service connection
              secretType: 'dockerRegistry'
              secretName: '$(imagePullSecret)'
              dockerRegistryEndpoint: '$(dockerRegistryServiceConnection)'

          - task: KubernetesManifest@1
            displayName: Deploy to Kubernetes cluster
            inputs:
              action: 'deploy'
              connectionType: 'kubernetesServiceConnection'
              kubernetesServiceConnection: 'myapp-default' #customize for your Kubernetes service connection
              manifests: |
                $(Pipeline.Workspace)/manifests/deployment.yml
                $(Pipeline.Workspace)/manifests/service.yml
              containers: '$(containerRegistry)/$(imageRepository):$(tag)'
              imagePullSecrets: '$(imagePullSecret)'
```

## Clean up resources

Whenever you're done with the resources you created, you can use the following command to delete them:

```azurecli
az group delete --name myapp-rg
```

Enter `y` when you're prompted.


