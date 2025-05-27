---
title: Automate app deployment to Azure Kubernetes Service (AKS) with CI/CD via Automated deployments Automated deployments
description: Learn how to use automated deployments to simplify the process of adding GitHub Actions or Azure DevOps Pipelines to your Azure Kubernetes Service (AKS) project.
ms.author: qpetraroia
ms.topic: how-to
ms.custom: build-2023, build-2024
ms.date: 05/10/2023
ms.subservice: aks-developer
ms.service: azure-kubernetes-service
author: qpetraroia
---

# Automated deployments for Azure Kubernetes Service (AKS)

Automated Deployments streamline the process of setting up a GitHub Action or Azure DevOps Pipeline, making it easy to create a continuous deployment pipeline for your application to Azure Kubernetes Service (AKS). Once connected, every new commit automatically triggers the pipeline, delivering updates to your application seamlessly. You can either bring your own deployment files for quick pipeline creation or generate Dockerfiles and Kubernetes manifests to containerize and deploy non-containerized applications with minimal effort.

## Prerequisites

* A GitHub account or an Azure DevOps organization.
* An AKS cluster. If you don't have one, you can create one using the steps in [Deploy an Azure Kubernetes Service (AKS) cluster][aks-deploy].
* An Azure Container Registry (ACR). If you don't have one, you can create one using the steps in [Integrate Azure Container Registry (ACR) with an Azure Kubernetes Service (AKS) cluster][acr-create].
* An application to deploy.

### Connect to source code repository

Create an automated deployment workflow and authorize it to connect to the desired source code repository.

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Automated deployments** > **Create**.
1. Under **Repository details**, enter a name for the workflow, then select **GitHub or ADO** for your repository location.
1. Select **Authorize access** to connect to the desired repository.
1. Choose the **Repository** and **Branch**, and then select **Next**.

### Choose the container image configuration

To get an application ready for Kubernetes, you need to build it into a container image and store it in a container registry. You use a Dockerfile to provide instructions on how to build the container image. If your source code repository doesn't already have a Dockerfile, Automated Deployments can generate one for you. Otherwise, you can use an existing Dockerfile.

#### [Without an existing Dockerfile](#tab/generate-dockerfile)

Use Automated Deployments to generate a Dockerfile for many languages and frameworks such as Go, C#, Node.js, Python, Java, Gradle, Clojure, PHP, Ruby, Erlang, Swift, and Rust. The language support is built on what's available in [draft.sh](https://draft.sh).

1. Select **Auto-containerize (generate Dockerfile)** for the container configuration.
1. Select the **location of where to save the generated Dockerfile** in the repository.
1. Select the **application environment** from the list of supported languages and frameworks.
1. Enter the **application port**.
1. Provide the **Dockerfile build context** path.
1. Select an existing **Azure Container Registry** or create a new one. This registry is used to store the built application image.

#### [With an existing Dockerfile](#tab/use-existing-dockerfile)

If your code repository already has a Dockerfile, you can select it to be used to build the application image.

1. Select **Existing Dockerfile** for the container configuration.
1. Select the **Dockerfile** from your repository.
1. Enter the **Dockerfile build context** to pass the set of files and directories to the build process. These files are used to build the image, and they're included in the final image, unless they're ignored by a `.dockerignore` file.
1. Select an existing **Azure Container Registry** or create a new one. This registry is used to store the built application image.

---

### Choose the Kubernetes manifest configuration

> [!NOTE]
> The Generate Manifests option also supports advanced features like Service Connector integration, auto-generated Ingress resources, and more detailed, customizable Kubernetes manifest files.

An application running on Kubernetes consists of many Kubernetes primitive components. These components describe what container image to use, how many replicas to run, if there's a public IP required to expose the application, etc. For more information, see the official [Kubernetes documentation][kubernetes-documentation]. If your source code repository doesn't already have the basic Kubernetes manifests to deploy, Automated Deployments can generate them for you. Otherwise, you can use a set of existing manifests. You can also choose an existing Helm chart.

#### [Use existing Kubernetes manifests](#tab/existing-kubernetes-manifests)

If your code repository already has a Dockerfile, you can select it to be used to build the application image.

1. Select **Use existing Kubernetes manifest deployment files** for the deployment options.
1. Select the **Kubernetes manifest file or folder** from your repository.
1. Select **Next**.

#### [Use an existing Helm chart](#tab/existing-helm-chart)

If your code repository already has a Helm chart, you can select it to be used to build the application image.

1. Select **Use existing Helm chart** for the deployment options.
1. Select the **Charts path** folder from your repository.
1. Select the **Values.yaml** file path from your repository.
1. Optionally, provide **Helm chart overrides**.
1. Select **Next**.

#### [Generate manifests](#tab/generate-kubernetes-manifests)

Use Automated Deployments to generate a set of basic Kubernetes manifest files to have your application up and running. At the moment, Automated Deployments creates a `Deployment`, a `Service`, and a `ConfigMap`.

The generated manifests are designed to apply recommendations of [deployment safeguards][deployment-safeguards], such as:

- Automatically generating [liveness, readiness, and startup probes][kubernetes-probes].
- Preferring [pod anti-affinity][pod-anti-affinity] and [topology spread constraints][topology-spread-constraints] that spread replicas onto different nodes for improved resiliency.
- Enforcing the `RuntimeDefault` [secure computing profile][seccomp-profile] which establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors.
- Dropping all Linux capabilities and only allowing a limited set following the baseline [Kubernetes Pod Security Standards][kubernetes-pod-security-standards].

Generated Kubernetes manifests also support the addition of an **Ingress** and **Service Connector**. These optional integrations will be covered below.

To generate Kubernetes manifests:

1. Select **Generate application deployment files** for the deployment options.
1. Enter the **application port**. This port is used on the generated `Service`.
1. Select the **location of where to save the generated Kubernetes manifests** in the repository.
1. (Optional) Edit the **Application and configuration** or **Service** values in your manifest file by selecting **Change**.
    1. If you don't want to use the defaults that AKS recommends, you can change various values of the manifest file, such as the:
        - Memory/CPU requests
        - Memory/CPU limits
        - TCP Readiness and Startup Probes
        - Minimum/Maximum scaling replicas for HPA
        - Memory/CPU utilization for HPA
        - Loadbalancer Port/Target Port
1. Select **Next**.

---
## (Optional) Use a managed ingress and/or Service Connector

When generating Kubernetes manifests with Automated Deployments, you can optionally enable App Routing to set up an ingress controller for your application. You can also use Service Connector to create a new connection or seamlessly integrate your app with an existing Azure service backend.

#### [Expose Ingress](#tab/expose-ingress)

App Routing provides a fully managed NGINX-based ingress controller out of the box, complete with built-in SSL/TLS encryption using certificates stored in Azure Key Vault and DNS zone management through Azure DNS. When using Automated Deployments, the expose ingress command integrates seamlessly with App Routing, making it easy to expose your application to external traffic under a secure, custom DNS name—with minimal configuration.

1. Select the **Expose ingress** box.
1. Choose between an **Existing ingress controller** or a **New ingress controller**.
1. Choose between using a **SSL/TLS enabled** or **Insecure** ingress controller.
1. (Optional) Enter **Certificate details** if choosing a **SSL/TLS enabled** ingress controller.
1. Choose between using **Azure DNS** or a **3rd party provider**.
1. Enter the **Azure DNS Zone** and **Subdomain name**.

#### [Use Service Connector](#tab/use-service-connector)

Service Connector helps you connect your application to other backing Azure services. By configuring the proper networking settings and connection variables, it can automatically inject credentials into your application via Kubernetes secret objects with no manual setup needed. To learn more about Service Connector, see the official [documentation][service-connector]. 

1. Select an **existing connection** or **Create a connection**.
1. When **Creating a new connection**, make sure you fill out all appropriate fields.

---

## (Optional) Add environment variables

Define environment variables for a container in Kubernetes by specifying name-value pairs. Environment variables are important as they help enable easier management of settings, secure handling of sensitive information, and flexibility across environments.

## Review configuration and deploy

Review the configuration for the application, and Kubernetes manifests, then select **Deploy**. A pull request (PR) will be generated against the repository that you selected, so don't navigate away from deployment page.

### Review and merge pull request

When the deployment succeeds, select **View pull request** to view the details of the generated pull request on your code repository.

 :::image type="content" source="./media/automatic/from-code/automatic-from-app-pull-request.png" alt-text="Screenshot of pull request on GitHub." lightbox="./media/automatic/from-code/automatic-from-app-pull-request.png" :::

1. Review the changes under **Files changed** and make any desired edits.
1. Select **Merge pull request** to merge the changes into your code repository.

Merging the change runs the GitHub Actions workflow that builds your application into a container image, stores it in Azure Container Registry, and deploys it to the cluster.

:::image type="content" source="./media/automatic/from-code/automatic-from-app-workflow-build.png" alt-text="Screenshot showing GitHub Actions workflow in progress." lightbox="./media/automatic/from-code/automatic-from-app-workflow-build.png" :::


### Check the deployed resources

After the pipeline is completed, you can review the created Kubernetes `Service` in the Azure portal by selecting **Services and ingresses** under the **Kubernetes resources** section of the service menu.

:::image type="content" source="./media/automatic/from-code/automatic-from-app-services.png" alt-text="Screenshot of the Services and ingresses pane." lightbox="./media/automatic/from-code/automatic-from-app-services.png" :::

Selecting the **External IP** should open up a new browser page with the running application.

:::image type="content" source="./media/automatic/from-code/automatic-from-app-running.png" alt-text="Screenshot showing the Contoso Air application running." lightbox="./media/automatic/from-code/automatic-from-app-running.png" :::

## Delete resources

Once you're done with your cluster, use the following steps to delete it to avoid incurring Azure charges:

1. In the Azure portal, navigate to **Automated deployments**
1. Select **...** on the pipeline of your choice.
1. Select **Delete**.

<!-- LINKS -->
[kubernetes-action]: kubernetes-action.md
[aks-deploy]: ./learn/quick-kubernetes-deploy-portal.md
[acr-create]: ./cluster-container-registry-integration.md
[service-connector]: /azure/service-connector/quickstart-portal-aks-connection