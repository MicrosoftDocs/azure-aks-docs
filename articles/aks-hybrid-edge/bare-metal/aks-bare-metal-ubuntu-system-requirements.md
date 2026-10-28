---
title: Prepare an Ubuntu Host for AKS on Bare Metal (Preview)
description: Review the Ubuntu, hardware, network, Azure, and Azure Arc requirements and prepare an Ubuntu host for AKS on bare metal.
ms.topic: how-to
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# System requirements and prepare your Ubuntu host (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article describes the requirements for deploying Azure Kubernetes Service (AKS) on bare metal on customer-provided Ubuntu hardware.

## Host operating system and hardware requirements

Use a physical machine that meets the following requirements:

| Requirement | Minimum | Recommended |
| --- | --- | --- |
| **Operating system** | Ubuntu 24.04.3 LTS or 24.04.4 LTS. | Ubuntu 24.04.3 LTS or 24.04.4 LTS. |
| **Processor architecture** | x86_64. | x86_64. |
| **CPU** | 2 physical cores. | 4 physical cores. |
| **Memory** | 4 GB RAM. | 8 GB RAM. |
| **Disk** | 256 GB of free disk space. | 256 GB or more of free disk space. |

AKS on Ubuntu supports one single-node cluster per host during the preview.



## Customer responsibilities

You own and maintain the Ubuntu host. AKS doesn't reimage the host or manage its operating system lifecycle. You're responsible for:

- Installing and configuring Ubuntu.
- Maintaining the operating system, kernel, system packages, and drivers.
- Applying security updates and patches.
- Configuring the host network, Domain Name System (DNS), proxy, and firewall.
- Maintaining enough CPU, memory, and disk capacity for Kubernetes and other host workloads.

AKS installs and manages the host-level packages, extensions, agents, services, and networking components required for the Kubernetes layer.

## Network requirements

Configure the host with fixed node and control plane IP addresses that don't change during the cluster lifecycle. The control plane IP must match the host IP or be an unused fixed IP address in the same subnet.

Allow outbound HTTPS traffic on TCP port 443.

## Azure requirements

| Requirement | Value |
| --- | --- |
| **Subscription** | An active Azure subscription. |
| **Region** | East US. Create the resource group and Arc-enabled server resource in this region. |
| **Permissions** | Owner, or Contributor plus User Access Administrator, on the resource group. Role assignments must be active and permanent. |
| **Resource providers** | `Microsoft.HybridCompute`, `Microsoft.HybridContainerService`, `Microsoft.Kubernetes`, `Microsoft.ExtendedLocation`, `Microsoft.HybridConnectivity`, and `Microsoft.AzureStackHCI`. |

Register the feature:

```azurecli
az feature register \
  --namespace Microsoft.HybridConnectivity \
  --name hiddenPreviewAccess
```

Register the required resource providers:

```azurecli
az provider register --namespace Microsoft.HybridCompute
az provider register --namespace Microsoft.HybridContainerService
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ExtendedLocation
az provider register --namespace Microsoft.HybridConnectivity
az provider register --namespace Microsoft.AzureStackHCI
```



## Prepare and connect the Ubuntu host

1. Configure fixed node and control plane IP addresses. Ensure the host can resolve DNS names and reach all required outbound endpoints.
1. Connect the machine to Azure Arc by following [Quickstart: Connect Linux machines to Azure Arc-enabled servers](/azure/azure-arc/servers/quick-onboard-linux).

   When you connect the machine, use the same East US resource group that you'll use for the AKS deployment and set the location to `eastus`.

1. Sign in and select the subscription that contains the Arc-enabled server.
    ```azurecli
    az login
    az account set --subscription <subscription-id>
    ```
1. Verify that the Arc-enabled server reports a `Connected` status:

   ```azurecli
   az connectedmachine show \
     --resource-group <resource-group> \
     --name <host-name> \
     --query status \
     --output tsv
   ```

## Next steps

- [Create an AKS on bare metal cluster on Ubuntu with Azure CLI](aks-bare-metal-create-cluster-ubuntu-cli.md).
