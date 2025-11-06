---
title: Deploy an application via AKS desktop (Preview)
description: Learn how to deploy and manage applications on Azure Kubernetes Service (AKS) using the AKS desktop guided deployment wizard.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: how-to
ms.date: 11/06/2025
ms.author: alalve
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Deploy an application to AKS desktop (Preview)

This article guides you through deploying an application using AKS desktop, enabling you to manage your containerized workloads with an intuitive, application-centric interface.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop may undergo design changes, add/delete additional features, and more. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at [aka.ms/aks/aks-desktop](aka.ms/aks/aks-desktop).

## Prerequisites

- You'll need an Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).
- You must have an AKS cluster available through the Azure portal or an Azure Container Registry with your application image that you want to deploy.
- Your AKS cluster must have a namespace for use.
- Install AKS desktop for your specific operating system (OS):

  - Windows
  - Linux
  - Mac

- If you decide to create an AKS managed Project, your cluster must be Microsoft Entra ID authenticated. You can run the following command on an existing cluster to perform this action. You can also add multiple admin groups by adding `ObjectID_1,ObjectID_2,...`:

  ```azurecli
  az aks update --resource-group YourResourceGroupName --name YourManagedClusterName --enable-aad --aad-admin-group-object-ids <ObjectID_1> --aad-tenant-id <TenantID>
  ```

## Sign into your account

The first time you open AKS desktop, you need to sign into your Azure account. To sign in, follow these steps:

1. In the left pane, select **Home**, then select **Sign in with Azure**.
1. Select the account which you want to use.

Once signed in, you have the ability to add clusters that you have access to into AKS desktop.

## Add a cluster to AKS desktop

When you add a cluster, you're given two options to add a cluster to AKS desktop. The available options are:

- From your Azure subscription
- Uploading a Kubeconfig file

If you have a single Azure subscription, AKS desktop will auto populate your subscription once you sign in.

# [Azure](#tab/azure)

1. Select **Add from Azure Subscription**.
1. Type the name of your Azure subscription if you have more than one.

   *Alternatively*, select the arrow to open the drop-down list, then select your Azure subscription.

1. Choose your cluster, then select **Register Cluster**.

# [KubeConfig](#tab/kubeconfig)

If this is your first method of choice, follow these steps:

1. Select **Home**, then select **Add Other Clusters**.
1. Select **Load from KubeConfig**, from here, pick one of two options:

   1. Select **Choose file**, locate your Kubconfig file, select it, then select **Open**.

   1. Drag and drop your Kubeconfig file into AKS desktop. Then select **Next**.

If you followed the Azure portal method first, follow these steps:

1. In the left pane, select **Add Cluster**, then select **Load from KubeConfig**.
1. From here, pick one of two options:

   1. Select **Choose file**, locate your Kubconfig file, select it, then select **Open**.

   1. Drag and drop your Kubeconfig file into AKS desktop. Then select **Next**.

---

## Add additional clusters to AKS desktop

1. In the left pane, select **Add Cluster**.
1. Under **Providers**, select **Add**.
1. Type the name of your Azure subscription if you have more than one.

   *Alternatively*, select the arrow to open the drop-down list, then select your Azure subscription.

1. Choose your cluster, then select **Register Cluster**.

## Remove a cluster from AKS desktop

To delete a cluster from AKS desktop, follow these steps:

1. Under the **Home** screen, tick the box next to the cluster you want to remove.
1. To the far right under **Actions**, select the three dots, then select **Delete**.
1. The **Delete Cluster** window appears asking if you want to remove the specified cluster. Select **Delete**.

## Create a new Project

When you create a project on a cluster, it's visible to all other users who have access to the namespace. This is because the project is based on a namespace, and that namespace has a specific label.

> [!NOTE]
> We recommend that you always create a new Project when deploying a new application.

There are three methods you can choose from to deploy your application using AKS desktop:

# [New project](#tab/new-project)

1. Provide a project name.
1. Select a cluster to add to your project. You can add more once a clusters is selected.
1. Use an existing namespace or type a new namespace to use.
1. Select **Create**.

# [YAML project](#tab/yaml-project)

1. Provide a project name.
1. Select a cluster to add to your project.
1. Under **Load resources**, you can choose the following:

   1. Select a `.yaml` or `.yml` file to load. You can also drag and drop your file into AKS desktop. Then select **Create**.
   
   1. Select **Load from URL**, paste your YAML URL, select **Load**, then select **Create**.

# [AKS managed project](#tab/new-project)

To manage your project using this method, the **aks-preview** extension must be installed by running the following command:

```azurecli
az extension add --name aks-preview
```

*Alternatively*, under **AKS Preview Extension Required**, select the **Install Extension** button.

You must also register the namespace preview feature for first time use. Under **Feature Flag Required**, select the **Register ManagedNamespacePreview Feature** button.

Once these prerequisites are complete, perform the following steps:

1. Provide a project name. Adding a project description is optional.
1. Select your subscription.
1. Select your cluster. Your cluster must be Microsoft Entra ID authenticated.
1. Select **Next**.
1. Under **Networking Policies**, choose the ingress and egress for your network traffic. Then select **Next**.
1. Under **Compute Quota**, adjust the quota based on your needs. Then select **Next**.
1. Under **Access**, assign the project to one or more users and permission level for each under **Role**. Then select **Next**.
1. Under **Review**, verify the settings for your project, then select **Create Project**.

---

## Deploy an application into a Project

1. Select the Project you created and then select **Deploy Application** in the top right corner.

1. There are two sources you can select from:

   - **Container Image**

   - **K8s YAML**

   Select **Container Image**, scroll down, and then select **Next**.

1. Paste in your container image into the **Container Image** textbox. It must be in the format `<YOUR ACR>.azurecr.io/<YOUR IMAGE NAME>:<YOUR IMAGE TAG>`.

   > [!NOTE]
   > Images can't use the "latest" tag as this results in best practice violation on AKS Automatic.

You can later select your app properties. This table provides the following configuration options:

| Option | Description |
|--|--|
| **Deployment Name** | The name of your deployment. |
| **Resource Limits** | The resource or request limits of your application. |
| **Service Type** | Choose between: <br><br><li> Cluster IP <li> Load balancer <li> Node port </li> |
| **Target Port** | The port your application listens on. |
| **Environment Variables** | Add environment variables to your deployment. |
| **Horizontal Pod Autoscaler** | Enable Horizontal Pod Autoscaler (HPA) on your application. |

### Deploy app: Health checks and advanced configuration

These are **default** settings needed to deploy to AKS Automatic. AKS Automatic deployment safeguards might block your deployment if you change these settings.

### Deploy app: Preview and deploy

1. You can check the YAML and also select **Deploy**. This performs the `kubectl apply` action to the cluster directly.

1. Select **Deploy to AKS**. The app should deploy.

1. On the next screen, select **Close**.

## View tile details

The key benefit to AKS desktop is to see your application resources, health status, and resource quota in one screen. The tabs on the screen provide more detail of each individual tile:

| Tile | Description |
|--|--|
| **Resources** | View all associated application workload resources, including **Network**, **Configuration**, and **Discovery** added by Namespace and YAML. |
| **Map** | Visualize resource dependencies for quick understanding and troubleshooting. |
| **Info** | View and update project networking policies and compute quota. |
| **Logs** | View live application logs for workload deployments. |
| **Metrics** | View live metrics per workload deployment. |
| **Scaling** | View scaling and CPU metrics. Configure manual scaling or Horizontal Pod Autoscaler (HPA). |

## Next steps

- Learn more about [AKS desktop overview](aks-desktop-overview.md)
- Explore [AKS Automatic clusters](auto-upgrade-cluster.md)
