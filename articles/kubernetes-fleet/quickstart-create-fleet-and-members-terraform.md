---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Terraform"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using Terraform.
ms.date: 04/15/2025
author: muhammadali
ms.author: alimuhammad
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
---

# Quickstart: Create Azure Kubernetes Fleet Manager using Terraform

Get started with Azure Kubernetes Fleet Manager (Fleet) by using Terraform to create a Fleet resource.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).

## Create a Fleet resource

You can create a Fleet resource to later group your AKS clusters as member clusters. When created via Azure CLI, by default, this resource enables member cluster grouping and update orchestration. If the Fleet hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters and L4 service load balancing across multiple member clusters. For more information, see the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configurations.


> [!IMPORTANT]
> Once a Kubernetes Fleet resource has been created, it's possible to upgrade a Kubernetes Fleet resource without a hub cluster to one with a hub cluster. For Kubernetes Fleet resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Kubernetes Fleet resource without hub cluster](#tab/without-hub-cluster)

Fleet without a hub cluster can not be created using Terraform yet.

### [Kubernetes Fleet resource with hub cluster](#tab/with-hub-cluster)

If you want to use Fleet for Kubernetes object propagation and multi-cluster load balancing in addition to update orchestration, then you need to create the Fleet resource with the hub cluster.

Kubernetes Fleet clusters with a hub cluster support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

#### Public hub cluster
To create a public Kubernetes Fleet resource with a hub cluster, implement the following Terraform code

##### Implement the Terraform code
- Create a directory you can use to test the sample Terraform code and make it your current directory.

- Create a file named `providers.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/302-aks-fleet-public-hubful/providers.tf)]

- Create a file named `main.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/302-aks-fleet-public-hubful/main.tf)]

- Create a file named `variables.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/302-aks-fleet-public-hubful/variables.tf)]

##### Initialize Terraform

[!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]

##### Create a Terraform execution plan

[!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]

##### Apply a Terraform execution plan

[!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]

#### Private hub cluster

Private hub cluster fleet can not be created using Terraform yet.


## Next steps

* [Access Fleet hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).