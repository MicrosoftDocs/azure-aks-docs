---
title: 'Quickstart: Deploy an application to a new Azure Kubernetes Service (AKS) Automatic cluster (preview) using Automated Deployments'
description: Learn how to quickly deploy an application from source code to a new Azure Kubernetes Service (AKS) Automatic (preview) cluster.
ms.topic: quickstart
ms.custom: devx-track-azurecli, devx-track-bicepW
ms.date: 02/07/2025
author: sabbour
ms.author: asabbour
---

# Quickstart: Deploy an application to a new Azure Kubernetes Service (AKS) Automatic cluster (preview) from a code repository

**Applies to:** :heavy_check_mark: AKS Automatic (preview)

Use [automated deployments][automated-deployments] to build and deploy an application from a code repository to a new or existing AKS Automatic cluster. Automated deployments simplify the process of setting up a GitHub Action workflow to build and deploy your code. Once connected, every new commit you make kicks off the pipeline. Automated deployments build on [draft.sh](https://draft.sh). When you create a new deployment workflow, you can use an existing Dockerfile, generate a Dockerfile, use existing Kubernetes manifests, or generate Kubernetes manifests. The generated manifests are created with security and resiliency best practices in mind.

In this quickstart, you learn to:

- Connect to a code repository
- Containerize your application
- Configure Kubernetes manifests
- Create an AKS Automatic cluster
- Deploy the application via a pull request

## Before you begin

- Register the `AutomaticSKUPreview` feature in your Azure subscription.
- Have a GitHub account with the application to deploy.
- The identity creating the cluster should also have the [following permissions on the resource group][Azure-Policy-RBAC-permissions]:
    - `Microsoft.Authorization/policyAssignments/write`
    - `Microsoft.Authorization/policyAssignments/read`
- AKS Automatic clusters require deployment in Azure regions that support at least three [availability zones][availability-zones].

> [!IMPORTANT]
> AKS Automatic tries to dynamically select a virtual machine size for the `system` node pool based on the capacity available in the subscription. Make sure your subscription has quota for 16 vCPUs of any of the following sizes in the region you're deploying the cluster to: [Standard_D4pds_v5](/azure/virtual-machines/sizes/general-purpose/dpsv5-series), [Standard_D4lds_v5](/azure/virtual-machines/sizes/general-purpose/dldsv5-series), [Standard_D4ads_v5](/azure/virtual-machines/sizes/general-purpose/dadsv5-series), [Standard_D4ds_v5](/azure/virtual-machines/sizes/general-purpose/ddsv5-series), [Standard_D4d_v5](/azure/virtual-machines/sizes/general-purpose/ddv5-series), [Standard_D4d_v4](/azure/virtual-machines/sizes/general-purpose/ddv4-series), [Standard_DS3_v2](/azure/virtual-machines/sizes/general-purpose/dsv3-series), [Standard_DS12_v2](/azure/virtual-machines/sizes/memory-optimized/dv2-dsv2-series-memory). You can [view quotas for specific VM-families and submit quota increase requests](/azure/quotas/per-vm-quota-requests) through the Azure portal.

## Bring your application source code

To deploy an application from a code repository, start at the [Azure portal][azure-portal] home page.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-create-button.png" alt-text="Select 'Deploy application' on the Kubernetes services create menu" lightbox="../media/automatic/from-code/automatic-from-app-create-button.png" :::

1. Search for **Kubernetes services** in the top search bar.
1. Select [**Kubernetes services**][portal-kubernetes-services] in the search results.
1. Select the **Create** button and select **Deploy application**.

### Connect to source code repository

Create and automated deployment workflow and authorize it to connect to the desired source code repository.

1. In the **Basics** tab, select **Deploy your application**.
1. Under **Project details**, choose the **Subscription**, **Resource Group**, and **Region**.
1. Under **Repository details**, enter a name for the workflow, then select **Authorize access** to connect to the desired GitHub repository.
1. Choose the **Repository** and **Branch**.
1. Select the **Next** button.

### Choose the container image configuration

To get an application ready for Kubernetes, you need to build it into a container image and stored into a container registry. You use a Dockerfile to provide instructions on how to build the container image. If your source code repository doesn't already have a Dockerfile, Automated Deployments can generate one for you, otherwise, you can utilize an existing Dockerfile.

#### [Without an existing Dockerfile](#tab/generate-dockerfile)

Use Automated Deployments to generate a Dockerfile for many languages and frameworks such as Go, C#, Node.js, Python, Java, Gradle, Clojure, PHP, Ruby, Erlang, Swift, and Rust. The language support is built on what's available in [draft.sh](https://draft.sh).

1. Select **Auto-containerize (generate Dockerfile)** for the container configuration.
1. Select the **location of where to save the generated Dockerfile** in the repository.
1. Choose the **application environment** from the list of supported languages and frameworks.
1. Enter the **application port**.
1. Select an existing **Azure Container Registry** or create a new one. This registry is used to store the built application image. The [kubelet identity][aks-identities] of the AKS Automatic cluster is given `AcrPull` permissions on that registry.

#### [With an existing Dockerfile](#tab/use-existing-dockerfile)

If your code repository already has a Dockerfile, you can select it to be used to build the application image.

1. Select **Existing Dockerfile** for the container configuration.
1. Select the **Dockerfile** from your repository.
1. Enter the **Dockerfile build context** to pass the set of files and directories to the build process. These files are used to build the image, and they're included in the final image, unless they're ignored by a `.dockerignore` file.
1. Select an existing **Azure Container Registry** or create a new one. This registry is used to store the built application image. The [kubelet identity][aks-identities] of the AKS Automatic cluster is given `AcrPull` permissions on that registry.

---

### Choose the Kubernetes manifest configuration

An application running on Kubernetes consists of many Kubernetes primitive components. These components describe what container image to use, how many replicas to run, if there's a public IP required to expose the application, etc. For more information, see the official [Kubernetes documentation][kubernetes-documentation]. If your source code repository doesn't already have the basic Kubernetes manifests to deploy, Automated Deployments can generate them for you, otherwise, you can utilize a set of existing manifests. You can also choose an existing Helm chart.

#### [Without existing Kubernetes manifests](#tab/generate-kubernetes-manifests)

Use Automated Deployments to generate a set of basic Kubernetes manifest files to have your application up and running. At the moment, Automated Deployments creates a `Deployment`, a `Service`, and a `ConfigMap`.

The generated manifests are designed to apply recommendations of [deployment safeguards][deployment-safeguards], such as:

- Automatically generating [liveness, readiness, and startup probes][kubernetes-probes].
- Preferring [pod anti-affinity][pod-anti-affinity] and [topology spread constraints][topology-spread-constraints] that spread replicas onto different nodes for improved resiliency.
- Enforcing the `RuntimeDefault` [secure computing profile][seccomp-profile] which establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors.
- Dropping all Linux capabilities and only allowing a limited set following the baseline [Kubernetes Pod Security Standards][kubernetes-pod-security-standards].

To generate Kubernetes manifests:

1. Select **Generate application deployment files** for the deployment options.
1. Enter the **application port**. This port is used on the generated `Service`.
1. Select the **location of where to save the generated Kubernetes manifests** in the repository.
1. Select the **Next** button.

#### [With existing Kubernetes manifests](#tab/existing-kubernetes-manifests)

If your code repository already has a Dockerfile, you can select it to be used to build the application image.

1. Select **Use existing Kubernetes manifest deployment files** for the deployment options.
1. Select the **Kubernetes manifest file or folder** from your repository.
1. Select the **Next** button.

#### [With an existing Helm chart](#tab/existing-helm-chart)

If your code repository already has a Helm chart, you can select it to be used to build the application image.

1. Select **Use existing Helm chart** for the deployment options.
1. Select the **Charts path** folder from your repository.
1. Select the **Values.yaml** file path from your repository.
1. Optionally, provide **Helm chart overrides**.
1. Select the **Next** button.

---

## Select where you want to deploy the application

#### [Create a new AKS Automatic cluster](#tab/new-aks-automatic-cluster)

If you don't have a cluster already, you can create a new AKS Automatic cluster as part of this deployment.

1. Select **Create Automatic Kubernetes cluster** for the cluster configuration.
1. Enter a **cluster name**.
1. Choose the **automatic upgrade maintenance schedule** or leave the default selected.
1. Enter the **Kubernetes namespace** where the application is deployed.
1. Choose the **monitoring and logging level** or leave the default selected.
1. Select the **Next** button.

#### [Existing AKS cluster](#tab/existing-aks-cluster)

If you have a cluster, you can use it to deploy the application.

1. Select **Existing AKS cluster** for the cluster configuration.
1. Select the **Subscription**, **Resource Group**, and **Cluster**.
1. Enter the **Kubernetes namespace** where the application is deployed.
1. Select the **Next** button.

---

## Review configuration and deploy

Review the configuration for the cluster, application, and Kubernetes manifests, then select **Deploy**. Creating a cluster takes a few minutes, don't navigate away from deployment page.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-deploy.png" alt-text="Deploying the application" lightbox="../media/automatic/from-code/automatic-from-app-deploy.png" :::

1. A new AKS Automatic cluster is created or an existing one is configured.
1. A container registry is created or an existing one is configured with the cluster.
1. Federated credentials are created to allow the GitHub Action workflow to deploy to the cluster.
1. A pull request is created on the code repository with any generated files and the workflow.

### Review and merge pull request

When the deployment succeeds, select the **View pull request** button to view the details of the generated pull request on your code repository.

 :::image type="content" source="../media/automatic/from-code/automatic-from-app-pull-request.png" alt-text="Pull request on GitHub." lightbox="../media/automatic/from-code/automatic-from-app-pull-request.png" :::

1. Review the changes under **Files changed** and make any desired edits.
1. Select **Merge pull request** to merge the changes into your code repository.

Merging the change runs the GitHub Actions workflow that builds your application into a container image, store it in Azure Container Registry, and deploy it to the cluster.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-workflow-build.png" alt-text="GitHub Actions workflow in progress." lightbox="../media/automatic/from-code/automatic-from-app-workflow-build.png" :::


### Check the deployed resources

After the pipeline is completed, you can review the created Kubernetes `Service` on the Azure portal by selecting **Services and ingresses** under **Kubernetes resources** service menu.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-services.png" alt-text="Services and ingresses pane" lightbox="../media/automatic/from-code/automatic-from-app-services.png" :::

Selecting the **External IP** should open up a new browser page with the running application.

:::image type="content" source="../media/automatic/from-code/automatic-from-app-running.png" alt-text="Contoso Air application running" lightbox="../media/automatic/from-code/automatic-from-app-running.png" :::

## Delete resources

Once you're done with your cluster, can delete it to avoid incurring Azure charges.

1. In the Azure portal, navigate to your resource group.
1. Select **Delete resource group**.
1. Enter the name of your resource group to confirm deletion and select **Delete**.
1. In the **Delete confirmation** dialog box, select **Delete**.

## Next steps

In this quickstart, you deployed an application to a Kubernetes cluster using [AKS Automatic][what-is-aks-automatic] and set up a continuous integration/continious deployment (CI/CD) pipeline from a code repository.

To learn more about AKS Automatic, continue to the introduction.

> [!div class="nextstepaction"]
> [Introduction to Azure Kubernetes Service (AKS) Automatic (preview)][what-is-aks-automatic]

[what-is-aks-automatic]: ../intro-aks-automatic.md
[Azure-Policy-RBAC-permissions]: /azure/governance/policy/overview#azure-rbac-permissions-in-azure-policy
[availability-zones]: /azure/reliability/availability-zones-region-support
[automated-deployments]: ../automated-deployments.md
[azure-portal]: https://portal.azure.com
[portal-kubernetes-services]: https://portal.azure.com/#browse/Microsoft.ContainerService%2FmanagedClusters
[aks-identities]: ../use-managed-identity.md#summary-of-managed-identities-used-by-aks
[kubernetes-documentation]: https://kubernetes.io/docs/concepts/workloads/
[deployment-safeguards]: ../deployment-safeguards.md
[seccomp-profile]: ../secure-container-access.md#secure-computing-seccomp.md
[kubernetes-probes]: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
[kubernetes-pod-security-standards]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[pod-anti-affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
[topology-spread-constraints]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
