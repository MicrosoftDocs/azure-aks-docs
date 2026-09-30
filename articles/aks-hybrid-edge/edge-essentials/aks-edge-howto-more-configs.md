---
title: AKS Edge Essentials configuration and scripts
description: Additional configuration options for AKS Edge Essentials.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Additional configuration and scripts for AKS Edge Essentials

This article provides alternate ways of connecting to Azure Arc, which can be applicable to clusters that are connected via a proxy.

## Connect an AKS Edge Essentials cluster to Arc using a proxy

### Prerequisites

- An Azure subscription with either the **Owner** role or a combination of **Contributor** and **User Access Administrator** roles. You can check your access level by navigating to your subscription, selecting **Access control (IAM)** on the left-hand side of the Azure portal, and then selecting **View my access**. Read the [Azure Resource Manager documentation](/azure/azure-resource-manager/management/manage-resource-groups-portal) for more information about managing resource groups.
- Enable all required resource providers in the Azure subscription such as **Microsoft.HybridCompute**, **Microsoft.GuestConfiguration**, **Microsoft.HybridConnectivity**, **Microsoft.Kubernetes**, and **Microsoft.KubernetesConfiguration**.
- Create and verify a resource group for AKS Edge Essentials Azure resources.

> [!NOTE]
> You must have the **Contributor** role to be able to delete the resources within the resource group. Commands to disconnect from Arc will fail without this role assignment.

### Step 1: configure your cluster for Azure connectivity

1. Download the [Azure/AKS-Edge GitHub repo](https://github.com/Azure/AKS-Edge/tree/main), if you haven't done so earlier. Navigate to the **Code** tab and click the **Download Zip** button to download the repository as a **.zip** file. Extract the **.zip** file to a local folder.
1. Provide details of your Azure subscription in the **aide-userconfig.json** file under the `Azure` section as described in the following table. To successfully connect to Azure using Azure Arc-enabled kubernetes, you need a service principal that provides role-based access to resources on Azure. If you already have the service principal ID and password, you can update all the fields in the **aide-userconfig.json** file. If you don't have a service principal, you can provide a name, and the script in the next step creates one and populates the `Auth` section for you.

    | Attribute | Value type      |  Description |
    | :------------ |:-----------|:--------|
    |`Azure.ClusterName` | string | Provide a name for your cluster. By default, `hostname_cluster` is the name used. |
    |`Azure.Location` | string | The location of your resource group. Choose the location closest to your deployment. |
    |`Azure.SubscriptionName` | string | Your subscription name. |
    |`Azure.SubscriptionId` | GUID | Your subscription ID. In the Azure portal, select the subscription you're using, then copy/paste the subscription ID string into the JSON. |
    |`Azure.TenantId` | GUID | Your tenant ID. In the Azure portal, search "Azure Active Directory," which should take you to the **Default Directory** page. From here, you can copy/paste the tenant ID string into the JSON file. |
    |`Azure.ResourceGroupName` | string | The name of the Azure resource group to host your Azure resources for AKS Edge Essentials. You can use an existing resource group, or if you add a new name, the system creates one for you. |
    |`Azure.ServicePrincipalName` | string | Azure service principal name. |
    |`Azure.Auth.ServicePrincipalId` | GUID | The AppID of the Azure service principal to use as credentials. AKS Edge Essentials uses this service principal to connect your cluster to Arc. You can use an existing service principal or if you add a new name, the system creates one for you in the next step. |
    |`Azure.Auth.Password` | string | The password (in clear text) for the Azure service principal to use as credentials.|
    |`AksEdgeConfigFile` | string | The file name for the AKS Edge Essentials configuration (`aksedge-config.json`). The `AksEdgeAzureSetup.ps1` script updates the `Arc` section of this JSON file with the required information.|

    > [!NOTE]
    > This procedure is required to be done only once per Azure subscription and doesn't need to be repeated for each Kubernetes cluster.

1. Run or double-click the **AksEdgePrompt.cmd** file to open an elevated PowerShell window with the required modules loaded. An overview of the PC information and the installed software versions is displayed.
1. Run the **AksEdgeAzureSetup.ps1** script in the **tools\scripts\AksEdgeAzureSetup** folder. This script prompts you to log in with your credentials for setting up your Azure subscription:

    ```powershell
    # prompts for interactive login for service principal creation with Contributor role at resource group level
    ..\tools\scripts\AksEdgeAzureSetup\AksEdgeAzureSetup.ps1 .\aide-userconfig.json -spContributorRole

    # (or) alternative option

    # Prompts for interactive login for service principal creation with minimal privileges
    ..\tools\scripts\AksEdgeAzureSetup\AksEdgeAzureSetup.ps1 .\aide-userconfig.json
    ```

1. Make sure that the credentials are valid, using the **AksEdgeAzureSetup-Test.ps1** script. This script signs in to Azure using the new service principal credentials and checks the status of Azure resources:

    ```powershell
    # Test the credentials
    ..\tools\scripts\AksEdgeAzureSetup\AksEdgeAzureSetup-Test.ps1 .\aide-userconfig.json
    ```

### Step 2: connect your cluster to Azure

1. Load the JSON configuration into the **AksEdgeShell** using `Read-AideUserConfig` and verify that the values are updated using `Get-AideUserConfig`. Alternatively, you can reopen **AksEdgePrompt.cmd** to use the updated JSON configuration:

    ```powershell
    Read-AideUserConfig
    Get-AideUserConfig
    ```

    > [!IMPORTANT]
    > Each time you modify **aide-userconfig.json**, run `Read-AideUserConfig` to reload, or close and re-open **AksEdgePrompt.cmd**.

1. Run `Initialize-AideArc`. This installs Azure CLI (if not already installed), signs in to Azure with the given credentials, and validates the Azure configuration (resource providers and resource group status):

   ```powershell
   Initialize-AideArc
   ```

1. Run `Connect-AideArc` to install and connect the host machine to the Arc-enabled server and to connect the **existing cluster** to Arc-enabled Kubernetes:

   ```powershell
   # Connect Arc-enabled server and Arc-enabled Kubernetes
   Connect-AideArc
   ```

    Alternatively, you can connect them individually using `Connect-AideArcServer` for Arc-enabled servers, and `Connect-AideArcKubernetes` for Arc-enabled Kubernetes:

   ```powershell
   # Connect Arc-enabled server
   Connect-AideArcServer
   # Connect Arc-enabled Kubernetes
   Connect-AideArcKubernetes
   ```

   > [!NOTE]
   > This step can take up to 10 minutes and PowerShell might be stuck on "Establishing Azure Connected Kubernetes for `your cluster name`". The PowerShell command outputs `True` and returns to the prompt when the process is completed. A bearer token is saved in **servicetoken.txt** in the **tools** folder.

### Step 3: view your cluster on Azure

1. On the left panel, select the **Namespaces** blade under **Kubernetes resources (preview)**:

   :::image type="content" source="../media/aks-edge/kubernetes-resources-preview.png" alt-text="Screenshot showing kubernetes resources preview." lightbox="../media/aks-edge/kubernetes-resources-preview.png":::

1. To view your Kubernetes resources, you need a bearer token:

   :::image type="content" source="../media/aks-edge/bearer-token-required.png" alt-text="Screenshot showing bearer token required." lightbox="../media/aks-edge/bearer-token-required.png":::

1. In your PowerShell window, run `Get-AksEdgeManagedServiceToken`, copy the full string, and paste it into the Azure portal:

   :::image type="content" source="../media/aks-edge/bearer-token-in-portal.png" alt-text="Screenshot showing paste token in portal." lightbox="../media/aks-edge/bearer-token-in-portal.png":::

1. Now you can view resources on your cluster. The following image shows the **Workloads** blade, showing the same as `kubectl get pods --all-namespaces`:

   :::image type="content" source="../media/aks-edge/all-pods-in-arc.png" alt-text="Screenshot showing results of all pods shown in Arc." lightbox="../media/aks-edge/all-pods-in-arc.png":::

## Disconnect AKS Edge Essentials cluster from Arc when using a proxy

Run `Disconnect-AideArc` to disconnect from the Arc-enabled server and Arc-enabled Kubernetes:

```powershell
# Disconnect Arc-enabled server and Arc-enabled Kubernetes
Disconnect-AideArc
```

Alternatively, you can disconnect them individually using `Connect-AideArcServer` for Arc-enabled servers and `Connect-AideArcKubernetes` for Arc-enabled Kubernetes:

```powershell
# Disconnect Arc-enabled server
Disconnect-AideArcServer
# Disconnect Arc-enabled Kubernetes
Disconnect-AideArcKubernetes
```

## Connect host machine to Arc

1. You can connect the host machine using `Connect-AideArcServer` for Arc-enabled servers:

   ```powershell
   # Connect Arc-enabled server
   Connect-AideArcServer
   ```

1. To disconnect the host machine from Arc, use `Disconnect-AideArcServer` for Arc-enabled servers:

   ```powershell
   # Disconnect Arc-enabled server
   Disconnect-AideArcServer
   ```

   You can also uninstall the Arc for Server agent [following the steps here](/azure/azure-arc/servers/manage-agent#uninstall-the-agent). For a complete clean-up through the Azure portal, delete the service principal and resource group you created for this example.

## Next steps

- [Deploy your application](./aks-edge-howto-deploy-app.md)
- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
