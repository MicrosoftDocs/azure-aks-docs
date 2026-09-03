---
title: Create Kubernetes Clusters by Using the Azure Portal
description: Create Kubernetes clusters by using the Azure portal.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.lastreviewed: 01/30/2024
ms.reviewer: srikantsarwa
ms.custom: local
---

# Deploy a Kubernetes cluster by using the Azure portal

[!INCLUDE [hci-applies-to-23h2](../includes/hci-applies-to-23h2.md)]

This article describes how to create Kubernetes clusters in Azure Local by using the Azure portal. You need to:

- Create a Kubernetes cluster by using the Azure portal. By default, the cluster is connected to Azure Arc.
- Provide a Microsoft Entra group that contains the list of Microsoft Entra users with Kubernetes cluster administrator access.

## Before you begin

- Make sure that you have the following details from your on-premises infrastructure administrator:
  - **Azure subscription ID**: The Azure subscription ID where the Azure Arc resource bridge, the Azure Kubernetes Service (AKS) extension Hybrid and Edge, and the custom location are created.
  - **Custom location ID**: The Azure Resource Manager ID of the custom location. Your infrastructure admin should give you Contributor access to the custom location. Custom location is a required parameter to create Kubernetes clusters.
  - **AKS logical network ID Hybrid and Edge**: The Azure Resource Manager ID of the Azure Arc logical network. Your infrastructure admin should give you Contributor access to an AKS logical network Hybrid and Edge. The logical network ID is a required parameter to create Kubernetes clusters.

- Create a Microsoft Entra group and add members to it so that you can connect to the cluster from anywhere. All the members in the Microsoft Entra group have cluster administrator access to the AKS cluster Hybrid and Edge.

  Make sure to add yourself to the Microsoft Entra group. If you don't add yourself, you can't access the AKS cluster Hybrid and Edge by using `kubectl`. For more information about how to create Microsoft Entra groups and add users, see [Create Microsoft Entra groups by using the Azure portal](/azure/active-directory/fundamentals/active-directory-groups-create-azure-portal).

## Create a Kubernetes cluster

1. Sign in to the [Azure portal](https://portal.azure.com/).
1. In the Azure portal search bar, enter **Kubernetes Azure Arc**.
1. Select **Add** > **Create a Kubernetes cluster with Azure Arc**.

   :::image type="content" source="../media/aks-create-clusters-portal/cluster-portal.png" alt-text="Screenshot that shows the cluster creation page in the portal." lightbox="../media/aks-create-clusters-portal/cluster-portal.png":::

1. On the **Basics** tab, configure the following options.

   :::image type="content" source="../media/aks-create-clusters-portal/cluster-create-portal.png" alt-text="Screenshot that shows the Basics tab for cluster creation in the portal." lightbox="../media/aks-create-clusters-portal/cluster-create-portal.png":::
   - **Project details**:
     - Select an Azure subscription. This Azure subscription is where your infrastructure administrator deployed the Azure Arc resource bridge, the AKS extension Hybrid and Edge, and the custom location.
     - Select an Azure resource group, such as **myResourceGroup**.
   - **Cluster details**:
     - Enter a Kubernetes cluster name, such as **myk8scluster**. The name of a Kubernetes cluster name must consist of lowercase alphanumeric characters.
     - Select a custom location where you want to deploy the cluster. Make sure that your infrastructure administrator gives you Contributor access on a custom location.
     - Select a Kubernetes version from the list of available versions.
   - **Primary node pool**:
     - Leave the default values selected, or change the default value from the dropdown list.
   - **Secure Shell (SSH) keys**:
     - Use SSH keys because they're essential for troubleshooting and log collection. Save your private key file for future use.
     - Use an existing SSH key or generate a new key pair during cluster creation. For information about how to create new SSH keys from the Azure portal, see [Create and store SSH keys in the portal](/azure/virtual-machines/ssh-keys-portal#generate-new-keys).
     - Provide the SSH public key value to use an existing public key. Use an RSA public key in the single line format (starting with `ssh-rsa`) or the multiline Privacy-Enhanced Mail format.

1. Select **Next: Node pools** after configuration is finished.
1. On the **Node pools** page, configure the following options:
   - **Control plane nodes:**
     - ⁠Use control plane nodes to host Kubernetes components. These nodes make global decisions about the cluster, such as scheduling containers and detecting and responding to cluster events. An example is starting up a new pod. For simplicity and reliability, run these important Kubernetes components in separate control plane nodes.
     - Leave the default values selected.
   - **Node pools:**
     - Add optional node pools in addition to the primary node pool that you created on the **Basics** page.

1. At the bottom of the screen, select **Next: Access**.
1. On the **Access** page, configure the following options:

    - Select **Local accounts with Kubernetes RBAC**, which is the default value for Kubernetes cluster authentication. This option requires that you have a direct line of sight to your on-premises infrastructure to access the cluster by using `kubectl`.
    - Select **Microsoft Entra authentication with Kubernetes role-based access control (RBAC)**. This option lets you choose one or more Microsoft Entra groups. By default, all members of the specified Microsoft Entra groups have cluster administrator access to the Kubernetes cluster.
    
       You can also use this option to connect to AKS Hybrid and Edge from anywhere, without requiring a line of sight to the on-premises infrastructure. Make sure to add yourself to the Microsoft Entra group. If you don't add yourself, you can't access the AKS cluster Hybrid and Edge by using `kubectl`.
    - Choose one or more Microsoft Entra groups. At the bottom of the screen, select **Next: Networking**.

1. On the **Networking** page, select an AKS logical network Hybrid and Edge from the **Logical Network** dropdown list. The Kubernetes nodes and services in your cluster get IP addresses and networking configurations from this logical network. Make sure that your infrastructure administrator gives you Contributor access on an AKS logical network Hybrid and Edge.

1. Select **Integration**. Connect your cluster to other services, such as Azure Monitor, which is enabled by default. You can also add Kubernetes extensions to your cluster from the **Home** > `YourClusterName` > **Settings** > **Extensions** pane.

   You can choose the default Log Analytics workspace or create one of your own. This workspace stores monitoring data.

1. Select **Tags**. Tags are name/value pairs that you can use to categorize resources and view consolidated billing by applying the same tag to multiple resources and resource groups. Use this page to assign tags (optional) to your resource groups.

1. Select **Review + create**. When you go to the **Review + create** tab, Azure runs validation on the settings that you chose. If validation passes, select **Create** to create the cluster. If validation fails, the tab indicates which settings you must modify.

1. It takes a few minutes to create the cluster. When your deployment is finished, go to your resource by either selecting **Go to resource** or browsing to the Kubernetes cluster resource group and selecting the resource.

## Related content

- [Review AKS on Azure Local prerequisites](hyperconverged/network-system-requirements.md)
- [What's new in AKS on Azure Local](aks-whats-new-local.md)
