---
title: 'Quickstart: Use Terraform to deploy an Azure Kubernetes Service cluster in an Azure Extended Zone'
description: In this quickstart, you create an Azure Kubernetes Service cluster with a unique name, DNS prefix, and configurations that include agent pool profiles, network profiles, and storage profiles.
ms.topic: quickstart
ms.date: 03/20/2025
ms.custom: devx-track-terraform
ms.service: azure-kubernetes-service
author: Nickomang
ms.author: nickoman
#customer intent: As a Terraform user, I want to learn how to create an Azure Kubernetes Service cluster with a specific configuration and deploy it in an Azure Extended Zone.
content_well_notification: 
  - AI-contribution
---

### [Terraform](#tab/terraform)
The following code creates a resource group and a Kubernetes cluster in Azure, with auto-scaling enabled and specific network settings, using Terraform.
> [!NOTE]
> The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-standard-lb-and-vmss). You can view the log file containing the [test results from current and previous versions of Terraform](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-standard-lb-and-vmss/TestRecord.md).
> 
> See more [articles and sample code showing how to use Terraform to manage Azure resources](/azure/terraform)
1. Create a directory in which to test and run the sample Terraform code, and make it the current directory.
1. Create a file named `main.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-standard-lb-and-vmss/main.tf":::
1. Create a file named `outputs.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-standard-lb-and-vmss/outputs.tf":::
1. Create a file named `providers.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-standard-lb-and-vmss/providers.tf":::
1. Create a file named `variables.tf`, and insert the following code:
    :::code language="Terraform" source="~/terraform_samples/quickstart/101-aks-standard-lb-and-vmss/variables.tf":::
1. Initialize Terraform.
    [!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]
1. Create a Terraform execution plan.
    [!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]
1. Apply a Terraform execution plan.
    [!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]
---