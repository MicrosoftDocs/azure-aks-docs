---
title: What is AKS on Azure Local?
description: Learn about AKS on Azure Local, its core infrastructure components, and the personas involved in deploying and operating it.
ms.topic: overview
ms.date: 09/01/2026
ai-usage: ai-assisted
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 08/12/2026
ms.custom: local
---

# What is AKS on Azure Local?

[!INCLUDE [hci-applies-to-23h2](../includes/hci-applies-to-23h2.md)]

AKS on Azure Local creates new Kubernetes clusters on Azure Local directly from Azure. It lets you use familiar tools like the Azure portal, Azure CLI, and Azure Resource Manager templates to create and manage Kubernetes clusters running on Azure Local. Because clusters connect to Azure automatically when you create them, you can use your Microsoft Entra ID to connect to your clusters from anywhere. This way, your developers and app operators can set up and manage Kubernetes clusters according to company policies.

Microsoft focuses on delivering a consistent experience for all your AKS clusters. If you created and managed Kubernetes clusters by using Azure, you feel at home managing Kubernetes clusters running on Azure Local with Azure portal or Azure CLI.

## Simplified AKS component management on Azure Local

AKS on Azure Local includes several infrastructure components that give you Azure experiences, like Arc Resource Bridge, Custom Location, and the Kubernetes extension for the AKS operator. These infrastructure components are now part of Azure Local:

- **Arc Resource Bridge**: The Arc Resource Bridge is created automatically when you deploy Azure Local. This lightweight Kubernetes VM connects your Azure Local to Azure Cloud and enables on-premises resource management from Azure. It provides the line of sight to private clouds required to manage resources such as Kubernetes clusters on-premises through Azure.
- **Custom Location**: Like Arc Resource Bridge, a custom location is created automatically when you deploy Azure Local. A custom location is the on-premises equivalent of an Azure region and extends the Azure location concept. Custom locations let tenant admins use their data center with the right extensions installed as target locations for deploying AKS.
- **Kubernetes extension for AKS operators**: The Kubernetes extension for AKS operators is installed automatically on Arc Resource Bridge when you deploy Azure Local. It's the on-premises equivalent of an Azure Resource Manager resource provider and helps you manage AKS through Azure.

By integrating these components, Azure Local gives you a unified and efficient way to provision and manage Kubernetes, bridging the gap between on-premises and cloud infrastructure.

## Key personas

**Infrastructure administrator**: The infrastructure admin sets up Azure Local, including all the infrastructure component deployments mentioned earlier. The admin also sets up platform configuration, like networking and storage, so Kubernetes operators can create and manage Kubernetes clusters.

**Kubernetes operator**: Kubernetes operators create and manage Kubernetes clusters on Azure Local to run applications without coordinating with infrastructure admins. The admin gives the operator access to the Azure subscription, Azure custom location, and virtual network. The operator doesn't need access to the underlying on-premises infrastructure. After getting the required access, the operator creates Kubernetes clusters based on application needs, like Windows or Linux node pools and Kubernetes versions.

## Next steps

- [What's new in AKS on Azure Local](aks-whats-new-local.md)
- [System requirements for AKS on Azure Local](aks-arc-local-requirements.md)
