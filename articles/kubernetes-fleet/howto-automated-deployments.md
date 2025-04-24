---
title: Use Fleet Manager Automated Deployments to drive multi-cluster resource placement
description: Learn how to use Fleet Manager Automated Deployments to build and deploy an application across multiple clusters.
author: sjwaight
ms.author: simonwaight
ms.topic: how-to
ms.custom: build-2025
ms.date: 04/22/2025
ms.service: azure-kubernetes-fleet-manager
---

# Use Fleet Manager Automated Deployments to drive multi-cluster resource placement (Preview)

Use Fleet Manager Automated Deployments to build and deploy an application from a code repository to one or more AKS cluster in a fleet. Automated deployments simplify the process of setting up a GitHub Action workflow to build and deploy your code. Once connected, every new commit you make runs the pipeline. Automated deployments build on [draft.sh](https://draft.sh). When you create a new deployment workflow, you can use an existing Dockerfile, generate a Dockerfile, use existing Kubernetes manifests, or generate Kubernetes manifests. The generated manifests are created with security and resiliency best practices in mind.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites

* A GitHub account with the application to deploy.
* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the [conceptual overview of resource propagation](./concepts-resource-propagation.md) to understand the concepts and terminology used in this article.
* A Kubernetes Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* The user completing the configuration has permissions to the Fleet Manager hub cluster Kubernetes API . See [Access the Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md) for more details.
* A namespace

## Bring your application source code

Find your Azure Kubernetes Fleet Manager instance and start automated deployments configuration.

1. In the [Azure portal][azure-portal], search for **Kubernetes Fleet Manager** in the top search bar.
1. Select [**Kubernetes fleet manager**][portal-fleets] in the search results.
1. Select your Azure Kubernetes Fleet Manager from the resource list. 
1. From the Fleet Manager service menu, under **Fleet resources**, select **Automated deployments**.
1. Select **+ Create** in the top menu. If this is your first automated deployment, you can also select **Create** in the deployment list area.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-create.png" alt-text="Screenshot showing create options for Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-create.png" :::

### Connect to source code repository

Create an automated deployment workflow and authorize it to connect to the desired source code repository and branch. Complete the following details on the **Repository** tab.

1. Enter a meaningful name for the workflow in the  **Workflow name** field.
1. Next, select **Authorize access** to authorize a user against GitHub to obtain a list of repositories. 
1. For **Repository source** select either:
    1. **My repositories** for repositories the currently authorized user owns, or;
    1. **All repositories** for repositories the currently authorized user can access. You will also need to select the **Organization** which owns the repository.
1. Choose the **Repository** and **Branch**.
1. Select the **Next** button.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-repository.png" alt-text="Screenshot showing selection of source control repository when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-repository.png" :::

### Specify application image and deployment configuration

To prepare an application to run on Kubernetes, you need to build it into a container image which you store in a container registry. A [Dockerfile](https://docs.docker.com/build/concepts/dockerfile/) provides instructions on how to build the container image. If your source code repository doesn't already have a Dockerfile, Automated Deployments can generate one for you.

#### [Use existing Dockerfile](#tab/use-existing-dockerfile)

If your code repository already has a Dockerfile, you can use it to build the application image.

1. Select **Existing Dockerfile** for the container configuration.
1. Select the **Dockerfile** from your repository.
1. Enter the **Dockerfile build context** to pass the set of files and directories to the build process. These files are used to build the image, and they're included in the final image, unless they're ignored by a `.dockerignore` file.
1. Select an existing **Azure Container Registry**. This registry is used to store the built application image. Any AKS cluster that can receive the application must be given `AcrPull` permissions on the registry.
1. Set the **Azure Container Registry image** name. You must use this image name in your deployment manifests.


:::image type="content" source="media/automated-deployments/fleet-auto-deploy-existing-dockerfile.png" alt-text="Screenshot showing selection of an existing Dockerfile when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-existing-dockerfile.png" :::

#### [Generate a Dockerfile](#tab/generate-dockerfile)

Use Fleet Manager Automated Deployments to generate a Dockerfile for many languages and frameworks such as Go, C#, Node.js, Python, Java, Gradle, Clojure, PHP, Ruby, Erlang, Swift, and Rust. The language support is built on what's available in [draft.sh](https://draft.sh).

1. Select **Auto-containerize (generate Dockerfile)** for the container configuration.
1. Set the **Save files in repository** location to a folder in the source repository.
1. Choose the **Application environment** from the list of supported languages and frameworks.
1. Enter the **Application port**.
1. Select an existing **Azure Container Registry**. This registry is used to store the built application image. Any AKS cluster that can receive the application must be given `AcrPull` permissions on the registry.
1. Set the **Azure Container Registry image** name. You must use this image name in your deployment manifests.
1. Review the generated Dockerfile and .dockerignore files.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-create-dockerfile.png" alt-text="Screenshot showing creating a Dockerfile when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-create-dockerfile.png" :::

---

### Choose the Kubernetes manifest configuration

An application running on Kubernetes consists of many Kubernetes primitive components. These components describe what container image to use, how many replicas to run, if there's a public IP required to expose the application, etc. For more information, see the official [Kubernetes documentation][kubernetes-documentation]. If your source code repository doesn't already have the basic Kubernetes manifests, Automated Deployments can generate them for you. You can also choose an existing Helm chart.

> [!WARNING]
> When selecting a namespace don't choose the `fleet-system` or any of the `fleet-member` namespaces as these are internal namespaces used by Fleet Manager and cannot be used to place your application. 

#### [Use existing Kubernetes manifests](#tab/existing-kubernetes-manifests)

If your code repository already has a Kubernetes manifest, you can select it to control what workload is deployed and how it is configured by a cluster resource placement.

1. Select **Use existing Kubernetes manifest deployment files** for the deployment options.
1. Select the **Kubernetes manifest file or folder** from your repository.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Select the **Next** button.


:::image type="content" source="media/automated-deployments/fleet-auto-deploy-existing-manifest.png" alt-text="Screenshot showing selection of an existing Kubernetes manifest when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-existing-manifest.png" :::

#### [Generate manifests](#tab/generate-kubernetes-manifests)

Use Fleet Manager Automated Deployments to generate a set of basic Kubernetes manifest files to get your application up and running. At present, Automated Deployments creates a `Deployment`, a `Service`, and a `ConfigMap`.

The generated manifests are designed to apply recommendations of [deployment safeguards][deployment-safeguards], such as:

- Automatically generating [liveness, readiness, and startup probes][kubernetes-probes].
- Preferring [pod anti-affinity][pod-anti-affinity] and [topology spread constraints][topology-spread-constraints] that spread replicas onto different nodes for improved resiliency.
- Enforcing the `RuntimeDefault` [secure computing profile][seccomp-profile] which establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors.
- Dropping all Linux capabilities and only allowing a limited set following the baseline [Kubernetes Pod Security Standards][kubernetes-pod-security-standards].

To generate Kubernetes manifests:

1. Select **Generate application deployment files** for the deployment options.
1. Enter the **Application port**. This port is used on the generated `Service`.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Set the **Save files in repository** location to a folder in the source repository.
1. Select the **Next** button.

#### [Use existing Helm chart](#tab/existing-helm-chart)

If your code repository already has a Helm chart, you can select it to build the application image.

1. Select **Use existing Helm chart** for the deployment options.
1. Select the **Charts path** folder from your repository.
1. Select the **Values.yaml** file path from your repository.
1. Optionally, provide **Helm chart overrides**.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Select the **Next** button.

---

## Review configuration

Review the configuration for the repository, image, and deployment configuration. 

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-review.png" alt-text="Screenshot showing the configuration of an Automated Deployment so it can be reviewed before being submitted." lightbox="media/automated-deployments/fleet-auto-deploy-review.png" :::

Select **Next** to start the process which performs these actions:

1. Create federated credentials to allow the GitHub Action to:
    1. Push the built container image to the Azure Container Registry.
    1. Stage the Kubernetes manifests into the selected namespace on the Fleet Manager hub cluster.
1. Create a pull request on the code repository with any generated files and the workflow.

Setup takes a few minutes, so don't navigate away from the Deploy page.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-run.png" alt-text="Screenshot showing Automated Deployment configuration completed with a button to approve the pull request." lightbox="media/automated-deployments/fleet-auto-deploy-run.png" :::

### Review and merge pull request

When the Deploy stage finishes, select the **Approve pull request** button to open the generated pull request on your code repository.

> [!NOTE]
> There is a known issue with the naming of the generated pull request where it says it is deploying to AKS. Despite this incorrect name, the resulting workflow does stage your workload on the Fleet Manager hub cluster in the namespace you selected. 

 :::image type="content" source="media/automated-deployments/fleet-auto-deploy-merge-pr.png" alt-text="Screenshot of pull request on GitHub." lightbox="media/automated-deployments/fleet-auto-deploy-merge-pr.png" :::

1. Review the changes under **Files changed** and make any desired edits.
1. Select **Merge pull request** to merge the changes into your code repository.

Merging the change runs the GitHub Actions workflow that builds your application into a container image and stores it in the selected Azure Container Registry.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-github-action.png" alt-text="Screenshot showing GitHub Actions workflow in progress." lightbox="media/automated-deployments/fleet-auto-deploy-github-action.pn" :::

### Check the deployed resources

TODO: Fleet Manager CRP documentation / sample here.


After the pipeline is completed, you can review the created container image on the Azure portal by locating the Azure Container Registry instance you configured and opening the image repository.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-check-registry-image.png" alt-text="Screenshot of the built container image hosted in an Azure Container Registry repository." lightbox="../media/automatic/from-code/afleet-auto-deploy-check-registry-image.png" :::

Selecting the **External IP** should open up a new browser page with the running application.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-running.png" alt-text="Screenshot showing the Contoso Air application running." lightbox="../media/automatic/from-code/automatic-from-app-running.png" :::

### Resulting GitHub Action workflow

The following GitHub Action workflow shows a sample  the output generated by selecting to

```yaml
# This workflow will build and push an application to a Azure Kubernetes Service (AKS) cluster when you push your code
#
# This workflow assumes you have already created the target AKS cluster and have created an Azure Container Registry (ACR)
# The ACR should be attached to the AKS cluster
# For instructions see:
#   - https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough-portal
#   - https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal
#   - https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli#configure-acr-integration-for-existing-aks-clusters
#   - https://github.com/Azure/aks-create-action
#
# To configure this workflow:
#
# 1. Set the following secrets in your repository (instructions for getting these can be found at https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Clinux):
#    - AZURE_CLIENT_ID
#    - AZURE_TENANT_ID
#    - AZURE_SUBSCRIPTION_ID
#
# 2. Set the following environment variables (or replace the values below):
#    - ACR_RESOURCE_GROUP (resource group of your ACR)
#    - AZURE_CONTAINER_REGISTRY (name of your container registry / ACR)
#    - CLUSTER_NAME (name of the resource to deploy to - fleet name or managed cluster name)
#    - CLUSTER_RESOURCE_GROUP (where your cluster is deployed)
#    - CLUSTER_RESOURCE_TYPE (type of resource to deploy to, either 'Microsoft.ContainerService/fleets' or 'Microsoft.ContainerService/managedClusters')
#    - CONTAINER_NAME (name of the container image you would like to push up to your ACR)
#    - DEPLOYMENT_MANIFEST_PATH (path to the manifest yaml for your deployment)
#    - DOCKER_FILE (path to your Dockerfile)
#    - BUILD_CONTEXT_PATH (path to the context of your Dockerfile)
#    - NAMESPACE (namespace to deploy your application)
# For more information on GitHub Actions for Azure, refer to https://github.com/Azure/Actions
# For more samples to get started with GitHub Action workflows to deploy to Azure, refer to https://github.com/Azure/actions-workflow-samples
# For more options with the actions used below please refer to https://github.com/Azure/login

name: contoso-store-deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  ACR_RESOURCE_GROUP: rg-contoso-02
  AZURE_CONTAINER_REGISTRY: contoso03
  CONTAINER_NAME: virtual-worker
  CLUSTER_NAME: flt-contoso-03
  CLUSTER_RESOURCE_GROUP: rg-contoso-02
  CLUSTER_RESOURCE_TYPE: Microsoft.ContainerService/fleets
  DEPLOYMENT_MANIFEST_PATH: |
    ./manifests/configmap.yaml
    ./manifests/deployment.yaml
    ./manifests/service.yaml
  DOCKER_FILE: ./Dockerfile
  BUILD_CONTEXT_PATH: ./
  NAMESPACE: contoso-store
  ENABLENAMESPACECREATION: false
  AUTH_TYPE: SERVICE_PRINCIPAL

jobs:
  buildImage:
    permissions:
      contents: read
      id-token: write
    runs-on: ubuntu-latest
    steps:
      # Checks out the repository this file is in
      - uses: actions/checkout@v3

      # Logs in with your Azure credentials
      - name: Azure login
        uses: azure/login@v2.2.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          auth-type: ${{ env.AUTH_TYPE }}

      # Builds and pushes an image up to your Azure Container Registry
      - name: Build and push image to ACR
        run: |
          az acr build --image ${{ env.AZURE_CONTAINER_REGISTRY }}.azurecr.io/${{ env.CONTAINER_NAME }}:${{ github.sha }} --registry ${{ env.AZURE_CONTAINER_REGISTRY }} -g ${{ env.ACR_RESOURCE_GROUP }} -f ${{ env.DOCKER_FILE }} ${{ env.BUILD_CONTEXT_PATH }}
  deploy:
    permissions:
      actions: read
      contents: read
      id-token: write
    runs-on: ubuntu-latest
    needs: [buildImage]
    steps:
      # Checks out the repository this file is in
      - uses: actions/checkout@v3

      # Logs in with your Azure credentials
      - name: Azure login
        uses: azure/login@v2.2.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          auth-type: ${{ env.AUTH_TYPE }}

      # Use kubelogin to configure your kubeconfig for Azure auth
      - name: Set up kubelogin for non-interactive login
        uses: azure/use-kubelogin@v1
        with:
          kubelogin-version: 'v0.0.25'

      # Retrieves your Azure Kubernetes Service cluster's kubeconfig file
      - name: Get K8s context
        uses: azure/aks-set-context@v4
        with:
          resource-group: ${{ env.CLUSTER_RESOURCE_GROUP }}
          cluster-name: ${{ env.CLUSTER_NAME }}
          admin: 'false'
          use-kubelogin: 'true'
          resource-type: ${{ env.CLUSTER_RESOURCE_TYPE }}

      # Checks if the AKS cluster is private
      - name: Is private cluster
        if: ${{ env.CLUSTER_RESOURCE_TYPE != 'Microsoft.ContainerService/fleets' }}
        id: isPrivate
        run: |
          result=$(az aks show --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --query "apiServerAccessProfile.enablePrivateCluster")
          echo "PRIVATE_CLUSTER=$result" >> "$GITHUB_OUTPUT"

      # Create Namespace
      - name: Create Namespace
        if: ${{ env.ENABLENAMESPACECREATION == 'true' }}
        run: |
          if [ ${{ steps.isPrivate.outputs.PRIVATE_CLUSTER}} == 'true' ]; then
            command_id=$(az aks command invoke --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command "kubectl get namespace ${{ env.NAMESPACE }} || kubectl create namespace ${{ env.NAMESPACE }}" --query id -o tsv)
            result=$(az aks command result --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command-id $command_id)
            echo "Command Result: $result"
            exitCode=$(az aks command result --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command-id $command_id --query exitCode -o tsv)
            if [ $exitCode -ne 0 ]; then
              exit $exitCode
            fi
          else
            kubectl get namespace ${{ env.NAMESPACE }} || kubectl create namespace ${{ env.NAMESPACE }}
          fi

      # Validate Namespace exists
      - name: Validate Namespace Exists
        run: |
          if [ ${{ steps.isPrivate.outputs.PRIVATE_CLUSTER}} == 'true' ]; then
            command_id=$(az aks command invoke --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command "kubectl get namespace ${{ env.NAMESPACE }}" --query id -o tsv)
            result=$(az aks command result --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command-id $command_id)
            echo "Command Result: $result"
            exitCode=$(az aks command result --resource-group ${{ env.CLUSTER_RESOURCE_GROUP }} --name ${{ env.CLUSTER_NAME }} --command-id $command_id --query exitCode -o tsv)
            if [ $exitCode -ne 0 ]; then
              exit $exitCode
            fi
          else
            kubectl get namespace ${{ env.NAMESPACE }}
          fi

      # Deploys application based on given manifest  file
      - name: Deploys application
        uses: Azure/k8s-deploy@v5
        with:
          action: deploy
          manifests: ${{ env.DEPLOYMENT_MANIFEST_PATH }}
          images: |
            ${{ env.AZURE_CONTAINER_REGISTRY }}.azurecr.io/${{ env.CONTAINER_NAME }}:${{ github.sha }}
          resource-group: ${{ env.CLUSTER_RESOURCE_GROUP }}
          name: ${{ env.CLUSTER_NAME }}
          private-cluster: ${{ steps.isPrivate.outputs.PRIVATE_CLUSTER == 'true' }}
          namespace: ${{ env.NAMESPACE }}
          resource-type: ${{ env.CLUSTER_RESOURCE_TYPE }}
          annotate-namespace: false
```

[Azure-Policy-RBAC-permissions]: /azure/governance/policy/overview#azure-rbac-permissions-in-azure-policy
[availability-zones]: /azure/reliability/availability-zones-region-support
[automated-deployments]: ./concepts-automated-deployments.md
[azure-portal]: https://portal.azure.com
[portal-fleets]: https://portal.azure.com/#browse/Microsoft.ContainerService%2Ffleets
[aks-identities]: ../use-managed-identity.md#summary-of-managed-identities-used-by-aks
[kubernetes-documentation]: https://kubernetes.io/docs/concepts/workloads/
[deployment-safeguards]: /azure/aks/deployment-safeguards
[seccomp-profile]: ../secure-container-access.md#secure-computing-seccomp
[kubernetes-probes]: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
[kubernetes-pod-security-standards]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[pod-anti-affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
[topology-spread-constraints]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
