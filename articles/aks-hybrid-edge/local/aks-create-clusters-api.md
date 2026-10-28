---
title: Create Kubernetes clusters using REST APIs
description: Learn how to create Kubernetes clusters in Azure Local using REST API for the Hybrid Container Service.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 06/19/2025
ms.reviewer: rjaini
ms.custom: local
---

# Create Kubernetes clusters using the REST API

[!INCLUDE [hci-applies-to-23h2](../includes/hci-applies-to-23h2.md)]

This article describes how to create Kubernetes clusters on Azure Local using the REST API. The Azure resource type for [AKS provisioned clusters](/azure/templates/microsoft.hybridcontainerservice/provisionedclusterinstances?pivots=deployment-language-arm-template) is **"Microsoft.HybridContainerService/provisionedClusterInstances"**. This resource is an extension of the [connected clusters](/azure/templates/microsoft.kubernetes/connectedclusters?pivots=deployment-language-arm-template) resource type, **"Microsoft.Kubernetes/connectedClusters"**. Due to this dependency, you must first create a connected cluster resource before creating an AKS resource.

## Before you begin

Before you begin, make sure you have the following details from your on-premises infrastructure administrator:

- **Azure subscription ID**: The Azure subscription ID that Azure Local uses for deployment and registration.
- **Custom Location ID**: The Azure Resource Manager ID of the custom location. The custom location is configured during the Azure Local cluster deployment. Your infrastructure admin should give you the Resource Manager ID of the custom location. This parameter is required in order to create Kubernetes clusters. If the infrastructure admin provides a custom location name and resource group name, you can also get the Resource Manager ID using the following command:

  ```azurecli
  az customlocation show --name "<custom location name>" --resource-group <azure resource group> --query "id" -o tsv
  ```
  
- **Network ID**: The Azure Resource Manager ID of the Azure Local logical network you created [following these steps](hyperconverged/aks-networks.md). Your admin should give you the ID of the logical network. This parameter is required in order to create Kubernetes clusters. If you know the resource group in which the logical network was created, you can also get the Azure Resource Manager ID using the following command:

  ```azurecli
  az stack-hci-vm network lnet show --name "<lnet name>" --resource-group <azure resource group> --query "id" -o tsv
  ```
  
- **Create an SSH key pair**: Create an SSH key pair in Azure and store the private key file for troubleshooting and log collection purposes. For detailed instructions, see [Create and store SSH keys with the Azure CLI](/azure/virtual-machines/ssh-keys-azure-cli), or with the [Azure portal](/azure/virtual-machines/ssh-keys-portal).
- To connect to the Kubernetes cluster from anywhere, create a Microsoft Entra group and add members to it. All the members in the Microsoft Entra group have cluster administrator access to the cluster. Make sure to add yourself as a member to the Microsoft Entra group. If you don't add yourself, you can't access the Kubernetes cluster using **kubectl**. For more information about creating Microsoft Entra groups and adding users, see [Manage Microsoft Entra groups and group membership](/entra/fundamentals/how-to-manage-groups).

## Step 1: Create a connected cluster resource

See the API definition for [connected clusters](/rest/api/hybridkubernetes/connected-cluster/create) and create a **PUT** request with the `kind` property set to `ProvisionedCluster`. The following example is a sample **PUT** request to create a connected cluster resource using the REST API:

```http
PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Kubernetes/connectedClusters/{connectedClusterName}?api-version=2024-01-01
Content-Type: application/json
Authorization: Bearer <access_token>

{
    "location": "<region>",
    "identity": {
        "type": "SystemAssigned"
    },
    "kind": "ProvisionedCluster",
    "properties": {
        "agentPublicKeyCertificate": "",
        "azureHybridBenefit": "NotApplicable",
        "distribution": "AKS",
        "distributionVersion": "1.0",
        "aadProfile": {
          "enableAzureRBAC": true,
          "adminGroupObjectIDs": [
            "<entra-group-id>"
          ],
          "tenantID": "<tenant-id>"
    },
  }
}
```

Replace all placeholder values with your actual details. For more information, see the [connected clusters API documentation](/rest/api/hybridkubernetes/connected-cluster/create).

## Step 2: Create a provisioned cluster resource

See the API definition for [provisioned clusters](/rest/api/hybridcontainer/provisioned-cluster-instances/create-or-update). In this **PUT** call, pass the Azure Resource Manager identifier created in the previous step as the URI parameter. The following code is an example HTTP **PUT** request to create a provisioned cluster resource with only the required parameters:

```http
PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.HybridContainerService/provisionedClusterInstances/{clusterName}?api-version=2024-01-01-preview
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "extendedLocation": {
    "type": "CustomLocation",
    "name": "<ARM ID of Custom Location>"
  },
  "properties": {
    "controlPlane": {
      "count": 1,
      "vmSize": "Standard_A4_v2"
    },
    "agentPoolProfiles": [
      {
        "name": "default-nodepool-1",
        "count": 1,
        "vmSize": "Standard_A4_v2",
        "osType": "Linux",
      }
    ],
    "linuxProfile": {
      "ssh": {
        "publicKeys": [
          {
            "keyData": "<SSH public key>"
          }
        ]
      }
    },
    "cloudProviderProfile": {
      "infraNetworkProfile": {
        "vnetSubnetIds": [
          "<ARM ID of logical network>"
        ]
      }
    },
  }
}

```

Replace the placeholder values with your actual details. For more information, see the [provisioned clusters API documentation](/rest/api/hybridcontainer/provisioned-cluster-instances/create-or-update).

## Connect to the Kubernetes cluster

Now you can connect to your Kubernetes cluster by running the `az connectedk8s proxy` command from your development machine. Make sure you sign in to Azure before running this command. If you have multiple Azure subscriptions, select the appropriate subscription ID using the [az account set](/cli/azure/account#az-account-set) command.

This command downloads the **kubeconfig** of your Kubernetes cluster to your development machine and opens a proxy connection channel to your on-premises Kubernetes cluster. The channel is open for as long as the command runs. Let this command run for as long as you want to access your cluster. If it times out, close the CLI window, open a fresh one, and then run the command again.

You must have Contributor permissions on the resource group that hosts the Kubernetes cluster in order to successfully run the following command:

```azurecli
az connectedk8s proxy --name $aksclustername --resource-group $resource_group --file .\aks-arc-kube-config
```

Expected output:

```output
Proxy is listening on port 47011
Merged "aks-workload" as current context in .\\aks-arc-kube-config
Start sending kubectl requests on 'aks-workload' context using
kubeconfig at .\\aks-arc-kube-config
Press Ctrl+C to close proxy.
```

Keep this session running and connect to your Kubernetes cluster from a different terminal or command prompt. Verify that you can connect to your Kubernetes cluster by running the `kubectl get` command. This command returns a list of the cluster nodes:

```azurecli
kubectl get node -A --kubeconfig .\aks-arc-kube-config
```

The following example output shows the node you created in the previous steps. Make sure the node status is **Ready**:

```output
NAME             STATUS ROLES                AGE VERSION
moc-l0ttdmaioew  Ready  control-plane,master 34m v1.24.11
moc-ls38tngowsl  Ready  <none>               32m v1.24.11
```

## Next steps

[AKS overview](../windows-server/overview.md)
