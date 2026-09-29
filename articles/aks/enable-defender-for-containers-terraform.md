---
title: 'Quickstart: Use Terraform for Defender for Containers on Azure'
description: Use Terraform to deploy an AKS cluster, enable Microsoft Defender for Containers at the subscription level, and verify runtime protection.
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ms.topic: quickstart
ms.custom: devx-track-terraform
ms.date: 08/31/2026
content_well_notification:
  - AI-contribution
ai-usage: ai-assisted

# Customer intent: As a cloud security engineer, I want to enable Microsoft Defender for Containers on an AKS cluster by using Terraform so that I can protect Kubernetes workloads with infrastructure as code.
---

# Quickstart: Use Terraform for Defender for Containers on Azure

Microsoft Defender for Containers is a cloud workload protection plan in Microsoft Defender for Cloud that provides security monitoring, vulnerability assessment, and threat detection for your Kubernetes environments. In this quickstart, you use Terraform to enable the Defender for Containers plan at the subscription level and deploy an Azure Kubernetes Service (AKS) cluster with Microsoft Defender security monitoring connected to a Log Analytics workspace.

[!INCLUDE [About Terraform](~/azure-dev-docs-pr/articles/terraform/includes/abstract.md)]

In this article, you learn how to:

> [!div class="checklist"]
> * Access the current subscription context using [azurerm_client_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config).
> * Create an Azure resource group using [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group).
> * Create a Log Analytics workspace for AKS security monitoring data using [azurerm_log_analytics_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace).
> * Enable the Defender for Containers plan at the subscription level using [azurerm_security_center_subscription_pricing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/security_center_subscription_pricing).
> * Create an AKS cluster with Azure Policy, OIDC issuer, and Microsoft Defender security monitoring enabled using [azurerm_kubernetes_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster).

> [!IMPORTANT]
> The `azurerm_security_center_subscription_pricing` resource sets the Defender for Containers plan for the entire Azure subscription, not just the AKS cluster created in this quickstart. Enabling the Standard tier affects all supported container resources in the subscription, including other AKS clusters and container registries, and can increase your Azure bill. Review the [Defender for Containers pricing](https://azure.microsoft.com/pricing/details/defender-for-cloud/) before you apply this configuration in a subscription that you share with other workloads.

## Prerequisites

- [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).
- Terraform version 1.5.0 or later.
- An Azure account with an active subscription. If you don't have an Azure account, [create one for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- [Azure CLI](/cli/azure/install-azure-cli) installed, and signed in using `az login`.
- Permission to create resource groups, Log Analytics workspaces, and AKS clusters in the target subscription (for example, the [Contributor](/azure/role-based-access-control/built-in-roles/general#contributor) role).
- Permission to modify Microsoft Defender for Cloud pricing plans at the subscription scope. You must be assigned the [Security Admin](/azure/defender-for-cloud/permissions#roles-and-allowed-actions), Owner, or Contributor role on the subscription. For more information, see [User roles and permissions in Defender for Cloud](/azure/defender-for-cloud/permissions).

## Implement the Terraform code

> [!NOTE]
> The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-defender-containers). You can view the log file containing the [test results from current and previous versions of Terraform](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-defender-containers/TestRecord.md).
>
> See more [articles and sample code showing how to use Terraform to manage Azure resources](/azure/terraform).

1. Create a directory to test the sample Terraform code and set it as the current directory.

1. Create a file named `main.tf` and add the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-defender-containers/main.tf)]

> [!NOTE]
> The configuration enables the following Defender for Containers extensions on the `Containers` pricing plan:
>
> - **AgentlessVmScanning**: Performs agentless vulnerability scanning of AKS node disks without installing an agent on the nodes.
> - **ContainerSensor**: Deploys the Defender sensor to AKS nodes. The `AntiMalwareEnabled`, `AutoProvisioning`, `InstallationMethod`, and `SecurityGatingEnabled` properties enable malware protection, automatic provisioning of the sensor, installation through the AKS security profile add-on, and security gating for the sensor.
> - **AgentlessDiscoveryForKubernetes**: Discovers Kubernetes cluster configuration and workload data without requiring an agent.
> - **ContainerRegistriesVulnerabilityAssessments**: Scans container images in Azure Container Registry for known vulnerabilities.
> - **ContainerIntegrityContribution**: Monitors runtime configuration drift and integrity of running containers.
>
> The AKS cluster resource also enables Azure Policy (`azure_policy_enabled`) for at-scale governance of the cluster, the OIDC issuer (`oidc_issuer_enabled`) for workload identity federation, and the Microsoft Defender security profile (`microsoft_defender`) that connects the cluster to the Log Analytics workspace for security monitoring.

## Initialize Terraform

[!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]

## Create a Terraform execution plan

[!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]

## Apply a Terraform execution plan

[!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]

## Verify the results

1. Get the resource group name, AKS cluster name, and Log Analytics workspace ID from the Terraform state.

    ```console
    resource_group_name=$(terraform output -raw resource_group_name)
    aks_cluster_name=$(terraform output -raw aks_cluster_name)
    log_analytics_workspace_id=$(terraform output -raw log_analytics_workspace_id)
    ```

1. Verify that the Defender for Containers plan is set to the Standard tier at the subscription level by using the [az security pricing show](/cli/azure/security/pricing#az-security-pricing-show) command.

    ```azurecli-interactive
    az security pricing show -n Containers --query "{name:name, tier:pricingTier}" -o table
    ```

    The output shows the `Containers` plan with the `Standard` pricing tier.

1. Check the extensions enabled on the plan by using the [az security pricing show](/cli/azure/security/pricing#az-security-pricing-show) command.

    ```azurecli-interactive
    az security pricing show -n Containers --query "extensions[].{name:name, isEnabled:isEnabled}" -o table
    ```

    The output lists the `AgentlessVmScanning`, `ContainerSensor`, `AgentlessDiscoveryForKubernetes`, `ContainerRegistriesVulnerabilityAssessments`, and `ContainerIntegrityContribution` extensions as enabled.

1. Confirm that Azure Policy, the OIDC issuer, and Microsoft Defender security monitoring are enabled on the AKS cluster by using the [az aks show](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show \
      --resource-group $resource_group_name \
      --name $aks_cluster_name \
      --query "{azurePolicy:addonProfiles.azurepolicy.enabled, oidc:oidcIssuerProfile.enabled, defender:securityProfile.defender}" \
      -o json
    ```

    The output shows `azurePolicy` and `oidc` set to `true`, and a `defender` object with `securityMonitoring.enabled` set to `true` and `logAnalyticsWorkspaceResourceId` set to the ID of the Log Analytics workspace that Terraform created.

1. Confirm that the Log Analytics workspace exists and is linked to the AKS cluster by using the [az monitor log-analytics workspace show](/cli/azure/monitor/log-analytics/workspace#az-monitor-log-analytics-workspace-show) command.

    ```azurecli-interactive
    az monitor log-analytics workspace show --ids $log_analytics_workspace_id --query "{name:name, provisioningState:provisioningState}" -o table
    ```

    The output shows the workspace name and a `provisioningState` of `Succeeded`.

## Clean up resources

> [!IMPORTANT]
> The `azurerm_security_center_subscription_pricing` resource manages the Defender for Containers plan for the entire subscription. When Terraform destroys this resource, it resets the `Containers` pricing tier back to `Free` for the whole subscription. This action disables Defender for Containers protection and its extensions for every AKS cluster and container registry in that subscription, not only the resources created in this quickstart. Confirm that no other clusters or workloads in the subscription depend on Defender for Containers protection before you continue.

[!INCLUDE [terraform-plan-destroy.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan-destroy.md)]

## Troubleshoot Terraform on Azure

[Troubleshoot common problems when using Terraform on Azure](/azure/developer/terraform/troubleshoot).

## Next step

> [!div class="nextstepaction"]
> [Enable Defender for Containers in Microsoft Defender for Cloud](/azure/defender-for-cloud/defender-for-containers-enable-plan)
