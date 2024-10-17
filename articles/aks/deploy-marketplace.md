---
title: Deploy a Kubernetes application from Azure Marketplace 
description: Learn how to deploy Kubernetes applications from Azure Marketplace on an Azure Kubernetes Service (AKS) cluster.
author: nickomang
ms.author: nickoman
ms.topic: how-to
ms.date: 10/15/2024
ms.service: azure-kubernetes-service
ms.subservice: aks-developer
ms.custom: ignite-fall-2022, references_regions
---

# Deploy and manage a Kubernetes application from Azure Marketplace

In this article, you learn how to deploy and manage a Kubernetes application from Azure Marketplace.

[Azure Marketplace][azure-marketplace] is an online store that contains thousands of IT software applications and services built by industry-leading technology companies. In Azure Marketplace, you can find, try, buy, and deploy the software and services that you need to build new solutions and manage your cloud infrastructure. The catalog includes solutions for different industries and technical areas, free trials, and consulting services from Microsoft partners.

## Limitations

* This feature is currently supported only in the following regions:
  * Australia East, Australia Southeast, Brazil South, Canada Central, Canada East, Central India, Central US, East Asia, East US, East US 2, East US 2 EAUP, France Central, France South, Germany North, Germany West Central, Japan East, Japan West, Jio India West, Korea Central, Korea South, North Central Us, North Europe, Norway East, Norway West, South Africa North, South Central US, South India, Southeast Asia, Sweden Central, Switzerland North, UAE North, UK South, UK West, West Central US, West Europe, West US, West US 2, West US 3
* You can't deploy Kubernetes application-based container offers on AKS for Azure Stack HCI or AKS Edge Essentials.

## Select and deploy a Kubernetes application

### From an AKS cluster

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Extensions + applications** > **Add**.
1. You can search for an offer or publisher directly by name, or you can browse all offers. To view Kubernetes application offers, select **Containers** under **Categories**.
1. After you decide on an application, select the offer. The following example uses the **TrilioVault for Kubernetes - BYOL** offer.
1. Select **Plans + Pricing** to ensure the terms are acceptable, and then select **Create**.

   :::image type="content" source="./media/deploy-marketplace/plans-pricing.png" alt-text="Screenshot of the offer purchasing page in the Azure portal, showing plan and pricing information." lightbox="./media/deploy-marketplace/plans-pricing.png":::

1. Follow each page in the application creation process, filling in information for your resource group, your cluster, and any configuration options that the application requires. You can decide to deploy on a new AKS cluster or use an existing cluster.
1. Once you've filled in all the required information, select **Review + create** > **Create**.

    It might take a few minutes for the application to deploy. You can monitor the deployment status from the **Extensions + applications** page.

### Search in the Azure portal

1. From the Azure portal home page, search for and select **Marketplace**.
1. You can search for an offer or publisher directly by name, or you can browse all offers. To find Kubernetes application offers, on the left side under **Categories** select **Containers**.
1. After you decide on an application, select the offer. The following example uses the **TrilioVault for Kubernetes - BYOL** offer.
1. Select **Plans + Pricing** to ensure the terms are acceptable, and then select **Create**.

   :::image type="content" source="./media/deploy-marketplace/plans-pricing.png" alt-text="Screenshot of the offer purchasing page in the Azure portal, showing plan and pricing information." lightbox="./media/deploy-marketplace/plans-pricing.png":::

1. Follow each page in the application creation process, filling in information for your resource group, your cluster, and any configuration options that the application requires. You can decide to deploy on a new AKS cluster or use an existing cluster.
1. Once you've filled in all the required information, select **Review + create** > **Create**.

      It might take a few minutes for the application to deploy. You can monitor the deployment status from the **Extensions + applications** page.

## Verify the deployment

### [Azure portal](#tab/azure-portal)

1. Navigate to the cluster where you recently installed the application.
1. From the service menu, under **Settings**, select **Extensions + applications**.
1. Verify that the extension is listed and the *Provisioning State* shows **Succeeded**.

### [Azure CLI](#tab/azure-cli)

1. Connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
    ```

1. List the installed extensions on the cluster using the [`az k8s-extension list`][az-k8s-extension-list] command.

    ```azurecli-interactive
    az k8s-extension list --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --cluster-type managedClusters
    ```

1. Verify that the extension is listed and the *Provisioning State* shows **Succeeded**.

---

## Manage the offer lifecycle

For lifecycle management, a Kubernetes offer is represented as a cluster extension for AKS. For more information, see [Cluster extensions for AKS][cluster-extensions]. Purchasing an offer from Azure Marketplace creates a new instance of the extension on your AKS cluster.

1. In the Azure portal, navigate to the cluster where you recently installed the application.
1. From the service menu, under **Settings**, select **Extensions + applications**.
1. Select an extension name to navigate to a properties view where you're able to disable autoupgrades, check the provisioning state, delete the extension instance, or modify configuration settings as needed.

## Monitor billing and usage information

1. In the Azure portal, navigate to your cluster's resource group.
1. From the service menu, under **Cost Management**, select **Cost analysis**. Under **Product**, you can see a cost breakdown for the plan that you selected.

## Remove an offer

You can delete a purchased plan for an Azure container offer by deleting the extension instance on the cluster.

### [Azure portal](#tab/azure-portal)

1. Navigate to the cluster where you recently installed the application.
1. From the service menu, under **Settings**, select **Extensions + applications**.
1. Select an application, then select **Uninstall**.

### [Azure CLI](#tab/azure-cli)

* Uninstall the extension on your AKS cluster using the [`az k8s-extension delete`][az-k8s-extension-delete] command.

    ```azurecli-interactive
    az k8s-extension delete --name $EXTENSION_NAME --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --cluster-type managedClusters
    ```

---

## Troubleshooting

If you experience issues, see the [troubleshooting checklist for failed deployments of a Kubernetes offer][marketplace-troubleshoot].

## Next steps

* Learn more about [exploring and analyzing costs][billing].
* Learn more about [deploying a Kubernetes application programmatically using Azure CLI](/azure/aks/deploy-application-az-cli).
* Learn more about [deploying a Kubernetes application using an ARM template](/azure/aks/deploy-application-template).

<!-- LINKS -->
[azure-marketplace]: /marketplace/azure-marketplace-overview
[cluster-extensions]: ./cluster-extensions.md
[billing]: /azure/cost-management-billing/costs/quick-acm-cost-analysis
[marketplace-troubleshoot]: /troubleshoot/azure/azure-kubernetes/troubleshoot-failed-kubernetes-deployment-offer
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-k8s-extension-list]: /cli/azure/k8s-extension#az-k8s-extension-list
[az-k8s-extension-delete]: /cli/azure/k8s-extension#az-k8s-extension-delete
