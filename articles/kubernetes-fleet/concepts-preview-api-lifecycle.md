---
title: Azure Kubernetes Fleet Manager Preview API lifecycle
description: Learn about the Azure Kubernetes Fleet Manager preview API lifecycle.
ms.date: 11/21/2024
ms.topic: conceptual
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager

---

# Azure Kubernetes Fleet Manager Preview API lifecycle

The Azure Kubernetes Fleet Manager (Kubernetes Fleet) preview REST Azure Resource Manager APIs (APIs that end in `-preview`) have a lifespan of approximately one year from their release date. This means that you can expect the 2023-01-02-preview API to be deprecated around January 1, 2024.
 
We love when people try our preview features and give us feedback, so we encourage you to use the preview APIs and the tools built on them.

After an API version is deprecated, it will no longer function. We recommend you routinely:

- Update your ARM/Bicep/Terraform templates using preview API versions to use the latest compatible version of the API.
- Update any preview SDKs or other tools built on the preview API to the latest version.

You should perform these updates at a minimum every 6-9 months. If you fail to do so, you'll be notified that you're using a soon-to-be deprecated API version as deprecation approaches.

Azure Kubernetes Service (AKS) API deprecations are listed on the [AKS preview API lifecycle page](/azure/aks/concepts-preview-api-life-cycle).

## Upcoming API deprecations

| API version        | Announce Date     | Deprecation Date  |
|--------------------|-------------------|-------------------|
| 2023-08-15-preview | December 16, 2024 | April 14, 2025    |
| 2023-06-15-preview | December 16, 2024 | April 14, 2025    |
| 2023-03-15-preview | December 16, 2024 | April 14, 2025    |
| 2022-09-02-preview | December 16, 2024 | April 14, 2025    |
| 2022-07-02-preview | December 16, 2024 | April 14, 2025    |

## Completed API deprecations

No Azure Resource Manager (ARM) API deprecations to date.

## How to check API versions in use

If you're unsure what client or tool is using a specific API version, check the [activity logs](/azure/azure-monitor/essentials/activity-log) using the following command. Replace `API_VERSION` with the version you wish to check.

```azurecli-interactive

API_VERSION="2023-08-02-preview"
az monitor activity-log list \
    --offset 30d \
    --max-events 10000 \
    --namespace microsoft.containerservice.fleets \
    --query "[?eventName.value == 'EndRequest' && contains(not_null(httpRequest.uri,''), '${API_VERSION}')]"
```

## Checking templates

### [Bicep templates](#tab/bicep-templates)

In Bicep templates, look at the version of the resource which appears at the end of the resource type (`@2023-08-15-preview`). 

```bicep
resource symbolicname 'Microsoft.ContainerService/fleets@2023-08-15-preview' = {
    ...
}
```

### [ARM templates](#tab/arm-templates)

In ARM templates check the `apiVersion` property

```json
{
  "type": "Microsoft.ContainerService/fleets",
  "apiVersion": "2023-08-15-preview",
  ...
}
```

### [Terraform templates](#tab/terraform-templates)

In terraform, check the value of the `type` property which defines the resource type and API version (`@2023-08-15-preview`).

```json
resource "azapi_resource" "symbolicname" {
  type = "Microsoft.ContainerService/fleets@2023-08-15-preview"
  ...
}
```

---

## How to update to a newer API version

- For Azure SDKs: use a newer API version by updating to a [newer version of the SDK](https://azure.github.io/azure-sdk/releases/latest/index.html?search=containerservicefleet).
- For Azure CLI: Update the CLI itself and the fleet extension to the latest version by running `az upgrade` and `az extension update --name fleet`.
- For Terraform: Update to the latest version of the AzureRM Terraform module. To find out what version of the API a particular Terraform release is using,
  check the [Terraform release notes](/azure/developer/terraform/provider-version-history-azurerm) or 
  git log [this file](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/internal/services/containers/client/client.go).
- For other tools: Update the tool to the latest version.
