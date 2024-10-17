---
title: AKS Preview API life cycle
description: Learn about the AKS preview API life cycle.
ms.custom: azure-kubernetes-service
ms.topic: article
ms.date: 05/29/2024
author: matthchr
ms.author: matthchr

---

# AKS Preview API life cycle

The Azure Kubernetes Service (AKS) preview APIs (APIs that end in `-preview`) have a lifespan of ~one year from their release date.
This means that you can expect the 2023-01-02-preview API to be deprecated somewhere around January 1st, 2024. 

We love when people try our preview features and give us feedback, so we encourage you to use the preview APIs and the
tools built on them (such as the [AKS Preview CLI Extension](https://github.com/Azure/azure-cli-extensions/tree/main/src/aks-preview)).

After an API version is deprecated, it will no longer function! We recommend you routinely:
- Update your ARM/BICEP templates using preview API versions to use the latest version of the preview API.
- Update your AKS preview CLI extension to the latest version.
- Update any preview SDKs or other tools built on the preview API to the latest version.

You should perform these updates at a minimum every 6-9 months. If you fail to do so, you will be notified that you are using a soon-to-be deprecated 
API version as deprecation approaches.

## How to check what API versions you're using

If you're unsure what client or tool is using this API version, check the [activity logs](/azure/azure-monitor/essentials/activity-log)
using the following command:

```bash
API_VERSION=<impacted API version, such as 2022-04-01-preview>
az monitor activity-log list --offset 30d --max-events 10000 --namespace microsoft.containerservice --query "[?eventName.value == 'EndRequest' && contains(not_null(httpRequest.uri,''), '${API_VERSION}')]"
```

## How to update to a newer version of the API

- For Azure SDKs: use a newer API version by updating to a [newer version of the SDK](https://azure.github.io/azure-sdk/releases/latest/index.html?search=containerservice).
- For Azure CLI: Update the CLI itself and the aks-preview extension (if used) to the latest version by running `az upgrade` and `az extension update --name "aks-preview"`.
- For Terraform: Update to the latest version of the AzureRM Terraform module. To find out what version of the API a particular Terraform release is using,
  check the [Terraform release notes](/azure/developer/terraform/provider-version-history-azurerm) or 
  git log [this file](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/internal/services/containers/client/client.go).
- For other tools: Update the tool to the latest version.


## Upcoming deprecations

| API version        | Announce Date     | Deprecation Date  |
|--------------------|-------------------|-------------------|
| 2022-07-02-preview | November 20, 2023 | February 14, 2024 |
| 2022-08-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-08-03-preview | March 27, 2024    | June 20, 2024     |
| 2022-09-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-10-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-11-02-preview | March 27, 2024    | June 20, 2024     |
| 2023-01-02-preview | March 27, 2024    | June 20, 2024     |
| 2023-02-02-preview | March 27, 2024    | June 20, 2024     |
| 2023-03-02-preview | Oct 21, 2024      | February 3, 2025  |
| 2023-04-02-preview | Oct 21, 2024      | February 10, 2025 |
| 2023-05-02-preview | Oct 21, 2024      | February 17, 2025 |
| 2023-06-02-preview | Oct 21, 2024      | February 24, 2025 |
| 2023-07-02-preview | Oct 21, 2024      | March 3, 2025     |
| 2023-08-02-preview | Oct 21, 2024      | March 10, 2025    |

## Completed deprecations

| API version        | Announce Date     | Deprecation Date  |
|--------------------|-------------------|-------------------|
| 2018-08-01-preview | March 7, 2023     | June 1, 2023      |
| 2021-11-01-preview | March 23, 2023    | July 1, 2023      |
| 2022-02-02-preview | April 27, 2023    | August 1, 2023    |
| 2022-01-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-03-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-04-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-05-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-06-02-preview | May 3, 2023       | Sept 1, 2023      |
