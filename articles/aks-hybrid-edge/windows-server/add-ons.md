---
title: Add-ons and extensions available for AKS on Windows Server
description: Learn about what add-ons and integrations are supported in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 02/15/2023
ms.reviewer: baziwane
ms.custom: windows-server
---

# Add-ons, extensions, and other integrations with AKS on Windows Server

Azure Kubernetes Service (AKS) on Windows Server provides augmented functionality for your Kubernetes cluster, mainly through extensions that are supported by Microsoft. There are also many integrations offered by open-source projects and third-party organizations. It's important to note that these integrations, which are not supported by AKS, are not included in the [AKS support policy](support-policies.md).

## Add-ons

Add-ons are a fully supported way to provide extra capabilities for your Kubernetes cluster. The add-ons installation, configuration, and lifecycle are managed by AKS. For information about how to install each add-on, see the available add-ons list.

The following rules are used by AKS for applying updates to installed add-ons:

- Any breaking or behavior changes to the add-on are usually announced 60 days in advance of a release.
- Updates to add-ons are communicated through the release notes accompanying each new release of AKS.

### Available add-ons

| Add-on                           | Description                                                  |
|--------------------------------------|------------------------------------------------------------------|
| [Install-AksHciAdAuth](/azure/aks/aksarc/reference/ps/install-akshciadauth)      | Installs Active Directory authentication.                        |
| [Install-AksHciCsiNfs](/azure/aks/aksarc/reference/ps/install-akshcicsinfs)      | Installs the CSI NFS plug-in to a cluster.                       |
| [Install-AksHciCsiSmb](/azure/aks/aksarc/reference/ps/install-akshcicsismb)      | Installs the CSI SMB plug-in to a cluster.                       |
| [Install-AksHciGmsaWebhook](/azure/aks/aksarc/reference/ps/install-akshcigmsawebhook) | Installs gMSA webhook add-on to the cluster.                     |
| [Install-AksHciMonitoring](/azure/aks/aksarc/reference/ps/install-akshcimonitoring)  | Installs Prometheus for monitoring in the AKS on Windows Server deployment. |

## Azure Arc extensions

Cluster extensions build on top of certain Helm charts and provide an Azure Resource Manager-driven experience for installation and lifecycle management of different Azure capabilities on top of your Kubernetes cluster. You can [deploy these extensions to your clusters](/azure/azure-arc/kubernetes/extensions) to improve cluster management.

### Available extensions

For more information about the specific cluster extensions for AKS on Windows Server, see [Currently available extensions](/azure/azure-arc/kubernetes/extensions-release).

## Difference between extensions and add-ons

Both extensions and add-ons are supported ways to add functionality to your Kubernetes cluster. When you install an add-on, the functionality is added as part of the AKS deployment. When you install an extension, the functionality is added as part of a separate resource provider in the Azure API.

## Open source and third-party integrations

You can install many open source and third-party integrations on your Kubernetes cluster, but these open-source and third-party integrations are not covered by the [AKS support policy](support-policies.md).

The following table shows examples of open-source and third-party integrations:

| Name                | Description                                                                                           | More details                                                                                                                                                               |
|-------------------------|-----------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Helm](https://helm.sh/)         | An open-source packaging tool that helps you install and manage the lifecycle of Kubernetes applications. | [Quickstart: Develop on Azure Kubernetes Service (AKS) with Helm](/azure/aks/quickstart-helm)                                                                                                     |
| [Istio](https://istio.io/)        | An open-source service mesh.                                                                              | [Istio installation guides](https://istio.io/latest/docs/setup/install/)                                                                                                                                        |
| [Linkerd](https://linkerd.io/)      | An open-source service mesh.                                                                              | [Linkerd getting started](https://linkerd.io/2.16/getting-started/)                                                                                                                                             |

## Next steps

- [AKS on Windows Server overview](overview.md)
