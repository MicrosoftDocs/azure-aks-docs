---
title: 'Quickstart: Deploy Azure ALB Controller on AKS using Terraform'
description: Use Terraform to deploy an AKS cluster, enable the Application Gateway for Containers ALB Controller add-on, and verify the Gateway API installation.
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ms.topic: quickstart
ms.custom: devx-track-terraform
ms.date: 08/31/2026
content_well_notification:
  - AI-contribution
ai-usage: ai-assisted

# Customer intent: As a platform engineer, I want to deploy an AKS cluster with the Application Gateway for Containers ALB Controller add-on by using Terraform so that I can manage Kubernetes ingress traffic with infrastructure as code.
---

# Quickstart: Deploy Azure ALB Controller on AKS using Terraform

Application Gateway for Containers is a managed layer 7 load balancing and ingress service for Kubernetes workloads. The ALB Controller is the Kubernetes controller that runs in your Azure Kubernetes Service (AKS) cluster and translates Gateway API and Ingress API configuration into Application Gateway for Containers load balancing rules. In this quickstart, you use Terraform to deploy an AKS cluster, enable the Application Gateway for Containers ALB Controller add-on, and install the managed Gateway API implementation that the add-on requires.

[!INCLUDE [About Terraform](~/azure-dev-docs-pr/articles/terraform/includes/abstract.md)]

In this article, you learn how to:

> [!div class="checklist"]
> * Create a random value for the resource group and AKS cluster names using [random_pet](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet).
> * Access the AzAPI provider's Azure subscription context using [azapi_client_config](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/client_config).
> * Register the `ApplicationLoadBalancerPreview` and `ManagedGatewayAPIPreview` subscription features using [azapi_resource_action](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource_action).
> * Pause while the preview feature registrations propagate using [time_sleep](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep).
> * Re-register the `Microsoft.ContainerService` resource provider using [azapi_resource_action](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource_action).
> * Create an Azure resource group using [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group).
> * Create an AKS cluster using [azurerm_kubernetes_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster).
> * Enable the Application Gateway for Containers ALB Controller add-on and install the managed Gateway API using [azapi_update_resource](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/update_resource).

## Prerequisites

- [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).
- An Azure account with an active subscription and permission to create AKS resources and assign roles in that subscription. If you don't have an Azure account, [create one for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- Terraform version 1.6.0 or later.
- [Azure CLI](/cli/azure/install-azure-cli) installed, and signed in with `az login`.
- [`kubectl`](https://kubernetes.io/releases/download/) installed.
- This quickstart deploys a new AKS cluster, so you don't need an existing cluster before you begin. The cluster that Terraform creates uses Azure CNI networking. AKS Automatic clusters aren't supported for this scenario.
- The `Microsoft.ContainerService` and `Microsoft.ServiceNetworking` resource providers registered in your subscription. For more information, see [Azure resource providers and types](/azure/azure-resource-manager/management/resource-providers-and-types).
- A supported [Azure region for Application Gateway for Containers](/azure/application-gateway/for-containers/overview#supported-regions).
- The Application Gateway for Containers ALB Controller add-on and the AKS-managed Gateway API installation are in preview. Preview features are governed by the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).
- The `ApplicationLoadBalancerPreview` and `ManagedGatewayAPIPreview` preview features registered on the `Microsoft.ContainerService` resource provider in your subscription. Feature registration is subscription-wide, so if another cluster in the subscription already registered these features, you don't need to register them again. Registration is asynchronous and can take several minutes to propagate. The Terraform configuration in this quickstart registers the features and waits for the registration to propagate, but you can also register them ahead of time:

  ```azurecli-interactive
  az feature register --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview
  az feature register --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview
  az provider register --namespace Microsoft.ContainerService
  ```

## Implement the Terraform code

> [!NOTE]
> The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-alb-controller).
>
> See more [articles and sample code showing how to use Terraform to manage Azure resources](/azure/terraform).

1. Create a directory to test the sample Terraform code and set it as the current directory.

1. Create a file named `main.tf` and add the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-alb-controller/main.tf)]

> [!NOTE]
> The configuration registers the `ApplicationLoadBalancerPreview` and `ManagedGatewayAPIPreview` subscription features, waits for the registrations to propagate, and then re-registers the `Microsoft.ContainerService` resource provider so the propagated features take effect. The resource that enables the add-on retries automatically while the resource provider still reports the features as unregistered. Because of this registration and retry sequence, the first `terraform apply` can take considerably longer than a typical AKS deployment.

## Initialize Terraform

[!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]

## Create a Terraform execution plan

[!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]

## Apply a Terraform execution plan

[!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]

## Verify the results

1. Get the resource group name, AKS cluster name, and AKS cluster resource ID from the Terraform state.

    ```console
    resource_group_name=$(terraform output -raw resource_group_name)
    aks_cluster_name=$(terraform output -raw aks_cluster_name)
    aks_cluster_id=$(terraform output -raw aks_cluster_id)
    ```

1. Get the AKS cluster credentials by using the [az aks get-credentials](/cli/azure/aks#az-aks-get-credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $resource_group_name --name $aks_cluster_name
    ```

1. Confirm the AKS `ingressProfile` shows the Application Gateway for Containers ALB Controller add-on as enabled. Query the same preview API version that the Terraform configuration used to enable the add-on.

    ```azurecli-interactive
    az rest --method get --uri "https://management.azure.com${aks_cluster_id}?api-version=2025-09-02-preview" --query "properties.ingressProfile"
    ```

    The output shows `applicationLoadBalancer.enabled` set to `true` and `gatewayAPI.installation` set to `Standard`.

1. Verify the ALB Controller pods are running in the `kube-system` namespace.

    ```console
    kubectl get pods -n kube-system | grep alb-controller
    ```

    You should see two `alb-controller` pods in a `Running` state.

1. Verify the `azure-alb-external` GatewayClass is installed on your cluster.

    ```console
    kubectl get gatewayclass azure-alb-external -o yaml
    ```

    The output shows a condition of type `Accepted` with the message `Valid GatewayClass`, which confirms the ALB Controller manages the `azure-alb-external` GatewayClass.

## Clean up resources

[!INCLUDE [terraform-plan-destroy.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan-destroy.md)]

Running `terraform destroy` removes the resource group and the AKS cluster that Terraform created. It doesn't remove the `ApplicationLoadBalancerPreview` and `ManagedGatewayAPIPreview` feature registrations, or the `Microsoft.ContainerService` resource provider registration, because those registrations are subscription-wide settings that Terraform doesn't manage as destroyable resources. Before you unregister a preview feature manually, verify that no other clusters or workloads in your subscription still depend on it.

## Troubleshoot Terraform on Azure

[Troubleshoot common problems when using Terraform on Azure](/azure/developer/terraform/troubleshoot).

## Next steps

> [!div class="nextstepaction"]
> [Deploy Application Gateway for Containers ALB Controller using the AKS add-on](/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon)
