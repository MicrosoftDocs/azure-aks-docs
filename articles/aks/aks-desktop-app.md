---
title: Deploy an application using AKS desktop (preview)
description: This article guides you through deploying an application using AKS desktop, enabling you to manage your containerized workloads with an intuitive, application-centric interface.
ms.service: azure-kubernetes-service
ms.subservice: aks-developer
ms.editor: schaffererin
author: qpetraroia
ms.topic: how-to
ms.date: 11/19/2025
ms.author: alalve
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Deploy an application using AKS desktop (preview)

**Applies to**: :heavy_check_mark: [AKS Automatic clusters](intro-aks-automatic.md)

Deploy applications to Azure Kubernetes Service (AKS) using AKS desktop, an application-focused experience that simplifies Kubernetes management. This guide walks you through the steps to deploy your first application using AKS desktop.

## Prerequisites

- You need an Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).
- You must have an AKS cluster available through the Azure portal or an Azure Container Registry with your application image that you want to deploy.
- The [Azure CLI](/cli/azure/install-azure-cli?view=azure-cli-latest&preserve-view=true) must be installed on your device.
- The `aks-preview` Azure CLI extension. Install it using the `az extension add --name aks-preview` command.
- You must have an [AKS Automatic cluster](intro-aks-automatic.md).
- You must install [AKS desktop](https://github.com/Azure/aks-desktop/releases). AKS desktop supports the following operating systems: Windows, Linux, and Mac.
- Your cluster must be Microsoft Entra ID authenticated. To ensure your cluster is Microsoft Entra ID authenticated, use an [AKS Automatic cluster](intro-aks-automatic.md).

## Sign in to your account

The first time you open AKS desktop, you need to sign into your Azure account. Signing in allows you to see AKS clusters and Projects that you have access to.

1. In the left pane, select **Home** > **Sign in with Azure**.
1. Select the account that you want to use.

Once signed in, you have the ability to add clusters that you have access to into AKS desktop.

## Add a cluster to AKS desktop

> [!NOTE]
> We recommend using an AKS Automatic cluster with AKS desktop. While AKS Standard SKU work in AKS desktop, you might not see the full benefits of the Project view. AKS Automatic includes built-in metrics, observability, and other tools that enable AKS desktop to surface important insights for users.

When you sign in, you can add clusters into AKS desktop from your Azure subscription or by uploading a kubeconfig file. If you have a single Azure subscription, AKS desktop auto populates your subscription once you sign in.

### [Use your Azure subscription](#tab/azure-subscription)

1. Select **Add from Azure Subscription**.
1. Enter the name of your Azure subscription if you have more than one. (Alternatively, select the arrow to open the drop-down list, then select your Azure subscription.)
1. Select your cluster, then select **Register Cluster**.

   ![A video demonstrating how to add a cluster to the AKS desktop app.](media/aks-desktop-app/aks-desktop-app-add-cluster.gif)

### [Upload a kubeconfig file](#tab/kubeconfig-file)

1. Select **Home** > **Add Other Clusters** > **Load from KubeConfig**. (If you followed the Azure subscription method first, select **Add Cluster** > **Load from KubeConfig**.)
1. Select one of the following options:

   - Select **Choose file**, locate and select your kubeconfig file, and then select **Open**.
   - Drag and drop your kubeconfig file into AKS desktop, and then select **Next**.

---

## Add additional clusters to AKS desktop

1. In the bottom left pane, select **Add Cluster**. You can choose to load from your kubeconfig file or from Azure.
1. Under **Providers**, select **Add**.
1. Enter the name of your Azure subscription if you have more than one. (Alternatively, select the arrow to open the drop-down list, then select your Azure subscription.)
1. Select your cluster, then select **Register Cluster**.

   ![A video demonstrating how to add additional clusters to the AKS desktop app.](media/aks-desktop-app/aks-desktop-app-add-additional-clusters.gif)

## Remove a cluster from AKS desktop

To delete a cluster from AKS desktop and your kubeconfig, follow these steps:

1. Under the **Home** screen, select the box next to the cluster you want to remove.
1. Under **Actions**, select the three dots, and then select **Delete**.
1. The **Delete Cluster** window appears asking if you want to remove the specified cluster. Select **Delete**.

   ![A video demonstrating how to remove a cluster from the AKS desktop app.](media/aks-desktop-app/aks-desktop-app-remove-cluster.gif)

## Create a new Project in AKS desktop

When you create a Project on a cluster, any user with access to the associated namespace can view the Project. Namespace access and labeling determine which users can see each Project, since Projects are tied to namespaces. To learn more, see [What is the Project Overview screen?](./aks-desktop-overview.md#about-the-project-overview-screen-in-aks-desktop)

There are three methods you can choose from to deploy your application using AKS desktop: **AKS managed Project**, **YAML Project**, and **New Project**.

### [Create an AKS managed Project](#tab/aks-managed-project)

> [!IMPORTANT]
> Make sure you register the namespace preview feature for first time use. Under **Feature Flag Required**, select **Register ManagedNamespacePreview Feature**.

1. Provide a Project name. Adding a Project description is optional.
1. Select your subscription, your cluster, and then select **Next**.
1. Under **Networking Policies**, choose the ingress and egress for your network traffic, and then select **Next**.
1. Under **Compute Quota**, adjust the quota based on your needs, and then select **Next**.
1. Under **Access**, assign the Project to one or more users and permission level for each under **Role**, and then select **Next**.
1. Under **Review**, verify the settings for your Project, and then select **Create Project**.
1. Add your application name, and then select **Create Application**.

    ![A video demonstrating how to create a new AKS-managed Project in the AKS desktop app.](media/aks-desktop-app/aks-desktop-app-create-new-project-aks-managed.gif)

### [Create YAML Project](#tab/yaml-project)

1. Provide a Project name.
1. Select a cluster to add to your Project.
1. Under **Load resources**, you can choose the following:

   - Select a `.yaml` or `.yml` file to load. You can also drag and drop your file into AKS desktop. Then select **Create**.
   - Select **Load from URL**, paste your YAML URL, select **Load**, and then select **Create**.

### [Create a New Project](#tab/new-project)

1. Provide a Project name.
1. Select a cluster to add to your Project. You can add more once a cluster is selected.
1. Use an existing namespace or type a new namespace to use.
1. Select **Create**.

---

## Remove a Project from AKS desktop

1. In the left pane, select the **Home** button.
1. Under **Projects**, select your Project under the **Name** column.
1. Within your Project, select the trash can icon.
1. Under the **Delete Project** window, select **Delete Project** to remove your Project from the given namespace.

   > [!NOTE]
   > If you also want to the delete the namespace along with your Project (which also removes associated resources), select **Also delete the namespaces**, and then select **Delete Project**.

## Deploy an application into a Project in AKS desktop

> [!TIP]
> When you deploy an application to AKS Desktop for the first time, metrics might take 5–10 minutes to appear as data begins flowing into managed Prometheus. After this initial delay, metrics should load within seconds. If metrics don't appear, try refreshing AKS Desktop.

We recommend you always create a new Project when deploying a new application. Once you create your first Project, AKS desktop places you directly into the newly created Project. Within your Project, select **Deploy Application**. There are two sources you can choose from to deploy your app: **Container Image** and **Kubernetes YAML**.

### [Container Image deployment](#tab/container-image)

1. Provide a name for your app.
1. Under **Container image**, paste the path to your container image. It must be in the format `<YourACR>.azurecr.io/<YourImageName>:<YourImageTag>`.

   > [!NOTE]
   > You can't use the **latest** tag for your container images, as it results in best practice violation on AKS Automatic.

1. Select your replica amount.
1. Under **Networking**, input your network port. Choose whether your app is meant for internal only or for public access, and then select **Continue**.
1. Under **Health checks**, choose which checks you want to perform, and then select **Continue**.
1. Under **Resource Limits**, configure per your app requirements, and then select **Continue**.
1. Under **Environment Variables**, add your `key:value` pair variable for your app, and then select **Continue**.
1. Under **HPA**, select whether to enable Horizontal Pod Autoscaler (HPA) for your app. HPA automatically adjusts the number of pods in response to resource usage, helping maintain optimal performance and resource efficiency. Configure per your needs, and then select **Continue**.
1. Under **Advanced**, choose which settings you'd like to apply to your app, and then select **Next**.
1. Review your app deployment configuration. Select **Deploy**, and then select **Close**.

### [Kubernetes YAML deployoment](#tab/kubernetes-yaml)

1. Select **Upload files** to upload one or more `.yaml` or `.yml` files, and then select **Next**. (Alternatively, you can paste the contents within your YAML files into the text editor, and then select **Next**.)
1. Review the resources to deploy, select **Deploy**, and then select **Close**.

---

## View cluster data and metrics in AKS desktop

AKS desktop provides a unified view of your application resources, health status, resource quotas, workloads, and configuration settings all in a single dashboard. Use the tabs to explore detailed information and manage each aspect of your deployment efficiently. You must have a cluster added into AKS desktop to view this information.

Use the following steps to view cluster data and metrics in AKS desktop:

1. Select **Home**.
1. Under the **Name** tab, select the cluster you want to view.
1. In the left pane, choose the specific setting to view detailed cluster data and metrics.

## Related content

For more information about add-ons, extensions, and features available in AKS, see [Add-ons, extensions, and other integrations with Azure Kubernetes Service (AKS)](./integrations.md).
