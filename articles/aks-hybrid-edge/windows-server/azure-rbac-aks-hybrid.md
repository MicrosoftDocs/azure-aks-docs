---
title: Use Azure RBAC for AKS clusters (preview)
description: Use Azure RBAC with Microsoft Entra ID to control access to AKS clusters.
ms.topic: how-to
ms.custom: devx-track-azurecli, windows-server
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: leslielin
ms.lastreviewed: 06/28/2024

# Intent: As an IT Pro, I want to use Azure RBAC to authenticate connections to my AKS clusters over the Internet or on a private network.
# Keyword: Kubernetes role-based access control AKS Azure RBAC AD
---

# Use Azure RBAC for AKS clusters (preview, retired)

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

> [!WARNING]
> This preview feature has been retired and is unsupported starting from 7/15/2024. Microsoft does not recommend using this Azure RBAC preview feature in a production environment.
> - PREVIEWS ARE PROVIDED "AS-IS," "WITH ALL FAULTS," AND "AS AVAILABLE," as described herein. For more information about PREVIEW terms and conditions, see Online Services from [Universal License Terms](https://www.microsoft.com/licensing/terms/product/ForOnlineServices/EAEAS)
> - If you want to use Azure RBAC for AKS on Azure Local, see [Use Azure role-based access control (RBAC) for Kubernetes authorization for AKS on Azure Local](../local/hyperconverged/azure-rbac-local.md).

This article describes how to set up Azure RBAC on an AKS cluster to use Microsoft Entra ID and Azure role assignments for authorization. The steps to create the cluster are covered in [Prerequisites](#prerequisites).

For a conceptual overview of using Azure RBAC with Azure Arc-enabled Kubernetes clusters, see [Azure RBAC on Azure Arc-enabled Kubernetes](/azure/azure-arc/kubernetes/conceptual-azure-rbac).

## Prerequisites

Before you deploy a Kubernetes cluster with Azure Arc enabled, you must complete the following prerequisites.

### Install the Azure CLI extension

The preview version of the Azure Arc-enabled Kubernetes Azure CLI extension is the only compatible version for this preview setup of AKS on Windows Server. Using a higher version can cause incompatibility issues with Azure RBAC and AKS. To install the extension, run the following command:

```azurecli
az extension add -n connectedk8s --version 1.5.4
```

### Prepare your network

Configure the following network, proxy, and firewall settings:

- Configure the endpoints that must be accessible to connect a cluster to Azure Arc. For a list, see [Meet network requirements](/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#meet-network-requirements).  

- Allow the [Graph endpoint](https://graph.microsoft.com) in your proxy or firewall.

  For information about configuring a proxy server, see [Proxy server settings](set-proxy-settings.md).

### Server and client apps

Azure RBAC uses Microsoft Entra client and server apps for different purposes. The client app is used to retrieve the user token once the user authenticates with Microsoft Entra ID using interactive login; for example, via device code flow. The client app is a public client, and also supports a non-interactive flow to retrieve the token for service principals.

The server app is a confidential client and is used to retrieve a signed-in user's security group details [for overage claim users](https://techcommunity.microsoft.com/t5/microsoft-entra-azure-ad-blog/azure-active-directory-now-with-group-claims-and-application/ba-p/243862), and for checking access requests that return the authorization result that the principal (user or SPN) has on the AKS cluster.

When you register the Microsoft Entra application, it stores configuration information in Microsoft Entra ID. This configuration enables the application represented by the Microsoft Entra application to authenticate on behalf of the user (or SPN). Once authenticated, the application can then use the Microsoft Entra app ID to access APIs on behalf of the user.

### Create the server app and client app

Register your server app and secret, and your client app and secret, by performing the following steps:

> [!NOTE]
> These steps direct you to key tasks in [Use Azure RBAC for Azure Arc-enabled Kubernetes clusters](/azure/azure-arc/kubernetes/azure-rbac) that are required to prepare for the Azure RBAC setup in AKS.  

To perform these steps, you must have the built-in [Application Administrator role](/azure/active-directory/roles/permissions-reference) in Microsoft Entra ID. For instructions, see [Assign Microsoft Entra roles to users](/azure/active-directory/roles/manage-roles-portal).

1. [Create a server application and shared secret](/azure/azure-arc/kubernetes/azure-rbac?tabs=AzureCLI#create-a-server-application).
1. [Create a role assignment for the server application](/azure/azure-arc/kubernetes/azure-rbac?tabs=AzureCLI#create-a-role-assignment-for-the-server-application).
1. [Create a client application](/azure/azure-arc/kubernetes/azure-rbac?tabs=AzureCLI#create-a-client-application). You refer to the client application when you use `kubectl` to connect within your network.

### Grant permissions for users on the cluster

Assign roles to grant permissions to users of service principal names (SPNs) on the cluster. Use the `az role assignment` command.

To assign roles on a Kubernetes cluster, you must have **Owner** permission on the subscription, resource group, or cluster.

The following example uses [az role assignment](/cli/azure/role/assignment) to assign the **Azure Arc Kubernetes Cluster Admin** role to the resource group that contains the cluster. You can set the scope of the resource group before you create the cluster:

```azurecli
az role assignment create --role "Azure Arc Kubernetes Cluster Admin" --assignee xyz@contoso.com --scope /subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.Kubernetes/connectedClusters/<resource name, aka name of AKS cluster>
```

In order to access the cluster via the **connectedk8s** proxy method (one of the options to communicate with the **api-server**), you must have the "Azure Arc Enabled Kubernetes Cluster User Role" scoped to the subscription, resource group, or cluster.

The following command assigns a role to a group instead of a specific user (see the previous example):

```azurecli
az role assignment create --assignee 00000000-0000-0000-0000-000000000000 --role "Azure Arc Kubernetes Cluster Admin" --scope $id
```

The assignee is the object ID of the Microsoft Entra group.

For more information about the role, [see this section](/azure/role-based-access-control/built-in-roles#azure-arc-enabled-kubernetes-cluster-user-role).

To get the scope ID for the cluster or resource group, run the following commands, and use the `"id":property`:

```azurecli
az connectedk8s show -g <name of resource group>  
az connectedk8s show -n <name of cluster> -g <name of resource group>
```

For other examples, see [az role assignment](/cli/azure/role/assignment).

For information about pre-built Azure RBAC roles for Arc-enabled Kubernetes clusters, see [Create role assignments for users to access a cluster](/azure/azure-arc/kubernetes/azure-rbac?tabs=AzureCLI#create-role-assignments-for-users-to-access-the-cluster). For a list of all available built-in roles, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

## Step 1: Create an SPN and assign permissions

Use an Azure service principal to configure an automation account with the permissions needed to create a target cluster with Azure RBAC enabled.

Creating a target cluster only requires limited privileges on the subscription. We recommend using the **Kubernetes Cluster - Azure Arc Onboarding** role. You can also use the **Owner** or **Contributor** role. For more information, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

Use the [`az ad sp create-for-rbac`](/cli/azure/ad/sp) Azure CLI command to create the SPN and configure it with the needed permissions.

The following example assigns the **Kubernetes Cluster - Azure Arc Onboarding** role to the subscription. For more information, see the [`az ad sp`](/cli/azure/ad/sp) command reference:

```azurecli
az ad sp create-for-rbac --role "Kubernetes Cluster - Azure Arc Onboarding" --scopes /subscriptions/<OID of the subscription ID> 
```

> [!IMPORTANT]
> The command output for `az ad sp` includes credentials that you must protect. Don't include these credentials in your code or check the credentials into your source control. For more information, see [Create an Azure service principal](/cli/azure/azure-cli-sp-tutorial-1).

For more information about creating an SPN and assigning a role to it, see [Create an Azure service principal](/cli/azure/azure-cli-sp-tutorial-1).

## Step 2: Create the credential object  

To create a credential object to use with the SPN, open a PowerShell window, and run the following command:

```powershell
$Credential = Get-Credential
```

This command prompts for a password.

To automate creation of the credential object without requiring manual password entry, see [Get-Credential, Example 4](/powershell/module/microsoft.powershell.security/get-credential#example-4). The script includes a plaintext credential, which might violate security standards in some enterprises.

## Step 3: Create an Azure RBAC-enabled AKS cluster

You can create an Azure RBAC-enabled cluster using an SPN (Option A) or create the cluster interactively (Option B).

### Option A: Create Azure RBAC-enabled AKS target cluster using an SPN

To create an AKS target cluster with Azure RBAC enabled using an SPN:

1. If you don't already have an SPN to use with the target cluster, [create the SPN](/cli/azure/azure-cli-sp-tutorial-1) now.
1. Note that the new SPN is for one time use when creating the cluster and doesn't require managing passwords.
1. Open a PowerShell window on the AKS node or Windows Server where you deploy the cluster, and run the following command:

   ```powershell
   New-AksHciCluster -name "<cluster name>"  -enableAzureRBAC -resourceGroup "<resource group name>" -subscriptionID "<subscription ID>" -tenantId "<tenant ID>" -credential $Credential -location "eastus" -appId $SERVER_APP_ID -appSecret $SERVER_APP_SECRET -aadClientId $CLIENT_APP_ID -nodePoolName <name of node pool> 
   ```

### Option B: Create Azure RBAC-enabled AKS target cluster interactively

If you prefer to create your Azure RBAC-enabled target cluster interactively, follow these steps:

1. Open a PowerShell window on the AKS node or Windows server where you deploy the cluster.
1. Sign in to Azure by running the following `connect-azaccount -deviceauth` command:

   ```powershell
   connect-azaccount -deviceauth
   ```

   The command prompts for authentication via the device code flow.

1. Set the subscription context to the subscription where the target cluster is to be created:

   ```powershell
   Set-AzContext -Subscription "subscriptionName"
   ```

1. Create the AKS target cluster, with Azure RBAC enabled:

   ```powershell
   New-AksHciCluster -name "<cluster name>"  -enableAzureRBAC -resourceGroup "<name of resource group>"  -location "eastus" -appId $SERVER_APP_ID -appSecret $SERVER_APP_SECRET -aadClientId $CLIENT_APP_ID -nodePoolName <name of node pool> 
   ```

## Step 4: Connect to the AKS cluster via Azure RBAC

The Azure RBAC setup on the AKS cluster is now complete. To test your Azure RBAC setup, connect to the AKS cluster. Azure RBAC authenticates the connections.

The procedures in this section use the `connectedk8s` proxy method to connect to an AKS cluster and connect to an AKS cluster over a private network.

### Connect to AKS cluster over the internet using the `connectedk8s` proxy method

Use the `connectedk8s` proxy method to send an authentication/authorization request from anywhere on the internet. When you use this method, you're limited to 200 groups.

To connect to an AKS cluster using the `connectedk8s` proxy method, perform the following steps:

1. Open an Azure CLI window, and use `az login` to connect to Azure. For more information, see [Sign in with Azure CLI](/cli/azure/authenticate-azure-cli).
1. Set the subscription for your Azure account to the subscription you used to create the AKS cluster if needed:

   ```azurecli
   az account set -subscription "<mySubscription>" 
   ```

1. Confirm that you're connected to Azure:

   ```azurecli
   az account show
   ```

1. Start the proxy process:

   ```azurecli
   az connectedk8s proxy -n <cluster name> -g <resource group name>
   ```

1. Make sure authentication is working correctly by sending requests to the cluster. Leave the terminal that you connected from open, open another tab, and send the requests to the cluster. You should get responses based on your Azure RBAC configuration.
1. Press **Ctrl+C** to close the `connectedk8s` proxy connection.

### Connect to AKS cluster over a private network

When you connect to an AKS cluster over a private network, there's no limit the on number of groups you can use.

To retrieve the Microsoft Entra kubeconfig log into and on-premises machine (for example, a Windows Server cluster), generate the Microsoft Entra kubeconfig using the following command. You can distribute the Microsoft Entra kubeconfig to users that connect from their client machine. The Microsoft Entra kubeconfig doesn't contain any secrets.

To connect to an AKS cluster over a private network, perform the following steps:

1. Download the **kubeconfig** file:

   ```powershell
   Get-AksHciCredential -Name <cluster name> -aadauth
   ```

1. Start sending requests to AKS API server by running the `kubectl` command `api-server`. You are prompted for your Microsoft Entra credentials. You might get a warning message, but you can ignore it.

## Update to the kubelogin authentication plugin

> [!NOTE]
> The information in this section applies to AKS version 1.0.17.10310 and later. [See the release notes](https://github.com/Azure/aks-hybrid/releases) for version information.

To provide authentication tokens for communicating with AKS clusters, **Kubectl** clients require [an authentication plugin](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins).

To generate a **kubeconfig** file that requires the [Azure **kubelogin.exe** binary](https://github.com/Azure/kubelogin) authentication plugin, run the following PowerShell command:

```powershell
Get-AksHciCredential -Name <cluster name> -aadauth
```

This command also downloads the **kubelogin.exe** binary. To find the location of the **kubelogin.exe** file, run the following command:

```powershell
$workingdir = (Get-AksHciConfig).Akshci.installationPackageDir
```

This command returns the path to where **kubelogin.exe** is downloaded. Copy the **kubelogin.exe** file to your Windows Server node or client machine. For Windows Server, copy the file to the path as described in the following example. For a client machine, copy the executable to your client machine and add it to your path. For example:

```powershell
cp $workingdir\kubelogin.exe "c:\program files\akshci"
```

Alternatively, to download **kubelogin.exe** to your client machine, you can run the following command:

```cmd
wget https://github.com/Azure/kubelogin/releases/download/v0.0.26/kubelogin-win-amd64.zip -OutFile kubelogin-win-amd64.zip
```

For more information about how to convert to the **kubelogin** authentication plugin, see the [Azure kubelogin page on GitHub](https://github.com/Azure/kubelogin).

## Next steps

- [Learn more about SPNs](/cli/azure/azure-cli-sp-tutorial-1)
