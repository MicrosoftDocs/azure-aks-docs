---
title: 'Quickstart: Use Terraform to deploy an Azure Kubernetes Service cluster in an Azure Extended Zone'
description: In this quickstart, you create an Azure Kubernetes Service cluster with a unique name, DNS prefix, and configurations that include agent pool profiles, network profiles, and storage profiles.
ms.topic: quickstart
ms.date: 03/19/2025
ms.custom: devx-track-terraform
ms.service: azure-kubernetes-service
author: Nickomang
ms.author: nickoman
#customer intent: As a Terraform user, I want to learn how to create an Azure Kubernetes Service cluster with a specific configuration and deploy it in an Azure Extended Zone.
content_well_notification: 
  - AI-contribution
---

# 'Quickstart: Use Terraform to deploy an Azure Kubernetes Service cluster in an Azure Extended Zone'

In this quickstart, you learn how to use Terraform to deploy an Azure Kubernetes Service (AKS) cluster in an Azure Extended Zone. Azure Kubernetes Service is a managed container orchestration service from Microsoft Azure that simplifies how containerized applications deploy, scale, and operate across clusters of hosts. It's used for running applications at a large scale with high availability and resilience. AKS for Extended Zones supports organizations to use the container orchestration and management features of AKS to streamline how applications hosted in extended zones are are deployed and managed there. Like during routine AKS deployments, the Azure platform maintains the AKS control plane and provides the infrastructure an organization retains control over the worker nodes that run the applications. To learn more about Azure Extended Zones, see [Azure Kubernetes Service for Extended Zones (preview)](/azure/aks/extended-zones?tabs=azure-resource-manager).The following diagram provides an overview of how AKS clusters deploy in Azure Extended Zones:

:::image type="content" source="./media/extended-zones/aez-aks-architecture.png" alt-text="Diagram that shows how AKS clusters deploy in Azure Extended Zones." lightbox="./media/extended-zones/aez-aks-architecture.png":::

[!INCLUDE [About Terraform](~/azure-dev-docs-pr/articles/terraform/includes/abstract.md)]

> [!div class="checklist"]
> * Create an Azure resource group with a unique name.
> * Generate a unique name with a prefix for the AKS cluster.
> * Generate a unique DNS prefix for the AKS cluster.
> * Create an AKS cluster with the generated name, DNS prefix, and other specified properties.
> * Output the name of the AKS cluster within the Azure Extended Zone.

## Prerequisites

- Create an Azure account with an active subscription. You can [create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

- [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).

## Implement the Terraform code

The following code uses Terraform to create a resource group and a Kubernetes cluster with auto-scaling enabled and specific network settings in Azure.

> [!NOTE]
> The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-extended-zones). You can view the log file containing the [test results from current and previous versions of Terraform](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-extended-zones/TestRecord.md).
>
> See more [articles and sample code showing how to use Terraform to manage Azure resources](/azure/terraform).

1. Create a directory in which to test and run the sample Terraform code, and make it the current directory.

1. Create a file named `main.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-extended-zones/main.tf":::

1. Create a file named `outputs.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-extended-zones/outputs.tf":::

1. Create a file named `providers.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-extended-zones/providers.tf":::

1. Create a file named `variables.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-extended-zones/variables.tf":::

## Initialize Terraform

[!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]

## Create a Terraform execution plan

[!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]

## Apply a Terraform execution plan

[!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]

## Verify the results

### [Azure CLI](#tab/azure-cli)

1. Get the Azure resource group name.

    ```console
    resource_group_name=$(terraform output -raw resource_group_name)
    ```

1. Get the AKS cluster name.

    ```console
    aks_cluster_name=$(terraform output -raw aks_cluster_name)
    ```

1. Run `az aks show` to view the AKS cluster within the Azure Extended Zone.

    ```azurecli
    az aks show --name $aks_cluster_name --resource-group $resource_group_name  
    ```

### [Azure PowerShell](#tab/azure-powershell)

1. Get the Azure resource group name.

    ```console
    $resource_group_name=$(terraform output -raw resource_group_name)
    ```

1. Get the AKS cluster name.

    ```console
    $aks_cluster_name=$(terraform output -raw aks_cluster_name)
    ```

1. Run `Get-AzAksCluster` to view the AKS cluster within the Azure Extended Zone.

    ```azurepowershell
    Get-AzAksCluster -Name $aks_cluster_name -ResourceGroupName $resource_group_name 
    ```

## Clean up resources

[!INCLUDE [terraform-plan-destroy.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan-destroy.md)]

## Troubleshoot Terraform on Azure

[Troubleshoot common problems when using Terraform on Azure](/azure/developer/terraform/troubleshoot).

## Next steps

> [!div class="nextstepaction"]
> [See more articles about AKS.](/search/?terms=Azure%20kubernetes%20service%20and%20terraform)
