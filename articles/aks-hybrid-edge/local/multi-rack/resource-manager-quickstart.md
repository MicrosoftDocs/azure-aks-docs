---
title: "Quickstart: Deploy an AKS Arc cluster on Azure Local multi-rack deployment using an ARM template"
description: Learn how to deploy an AKS enabled by Azure Arc cluster on Azure Local (multi-rack) using an Azure Resource Manager template (ARM template).
ms.topic: quickstart
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# Quickstart: Deploy an AKS Arc cluster using an Azure Resource Manager template

This quickstart shows how to deploy a Kubernetes cluster in Azure Kubernetes Service (AKS) Arc using an Azure Resource Manager template (ARM template) on Azure Local for multi-rack deployments. Azure Arc extends Azure management capabilities to Kubernetes clusters anywhere, providing a unified approach to managing different environments.

## Before you begin

This article assumes a basic understanding of Kubernetes concepts.

To deploy an ARM template, you need write access on the resources you're deploying, and access to all operations on the `Microsoft.Resources/deployments` resource type. For example, to deploy a virtual machine, you need `Microsoft.Compute/virtualMachines/write` and `Microsoft.Resources/deployments/*` permissions. For a list of roles and permissions, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

### Prerequisites

- An Azure account with an active subscription.
- An Azure Local cluster, with a target custom location for the AKS Arc cluster.
- The [latest version of Azure CLI](/cli/azure/install-azure-cli).
- A logical network provisioned. For more information, see [Network requirements](network-system-requirements.md).

## Step 1: Prepare your Azure account

1. Sign in to Azure: open your terminal or command prompt and sign in to your Azure account using the Azure CLI:

   ```azurecli
   az login
   ```

1. Set your subscription: replace `<your-subscription-id>` with your subscription ID:

   ```azurecli
   az account set --subscription "<your-subscription-id>"
   ```

## Step 2: Create an SSH key pair

Create an SSH key pair in Azure and store the private key file for troubleshooting and log collection purposes. For detailed instructions, see [Configure SSH keys for an AKS cluster](../hyperconverged/configure-ssh-keys.md) to create SSH keys, or use [Restrict SSH access](../hyperconverged/restrict-ssh-access.md) during cluster creation. To access nodes afterward, see [Connect to Windows or Linux worker nodes with SSH](../hyperconverged/ssh-connect-to-windows-and-linux-worker-nodes.md).

1. [Open a Cloud Shell session](https://shell.azure.com/) in your web browser or launch a terminal on your local machine.
1. Create an SSH key pair using the [az sshkey create](/cli/azure/sshkey#az-sshkey-create) command:

   ```azurecli
   az sshkey create --name "mySSHKey" --resource-group $<resource_group_name>
   ```

   or, use the `ssh-keygen` command:

   ```azurecli
   ssh-keygen -t rsa -b 4096
   ```

1. Retrieve the value of your public key from Azure or from your local machine under _~/.ssh/id_rsa.pub_.


## Step 3: Gather key details

Make sure you have the following details for the ARM template:

- Custom location associated with the Azure Local instance you want to deploy AKS Arc cluster on
- Azure Resource Manager resource ID of the logical network you want to use for your AKS Arc cluster, with sufficient IP addresses. For more information, see [IP address planning](plan-aks-ip-address.md).
- Desired Kubernetes version for your environment. You can query the available Kubernetes versions for your environment using:

   ```azurecli
   az aksarc get-versions --custom-location "/subscriptions/<your-subscription-id>/providers/Microsoft.ExtendedLocation/customLocations/<your-custom-location>" -o table
   ```

## Step 4: Prepare the template

The ARM template used in this quickstart creates two resources:

- `Microsoft.Kubernetes/ConnectedClusters`: An Arc-enabled Kubernetes cluster resource that represents the cluster in Azure.
- `microsoft.hybridcontainerservice/provisionedclusterinstances`: The provisioned cluster instance that defines the cluster configuration, including node pools, networking, and Kubernetes version.

The following code is a sample template you can use:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string"
        },
        "customLocation": {
            "type": "string"
        },
        "vnetSubnetIds": {
            "type": "array"
        },
        "connectedClusterName": {
            "type": "string"
        },
        "sshRSAPublicKey": {
            "type": "string"
        },
        "controlPlaneIp": {
            "type": "string"
        },
        "kubernetesVersion": {
            "type": "string"
        },
        "controlPlaneVMSize": {
            "type": "string"
        },
        "controlPlaneNodeCount": {
            "type": "int"
        },
        "agentName": {
            "type": "string"
        },
        "agentVMSize": {
            "type": "string"
        },
        "agentOsType": {
            "allowedValues": [
                "Linux",
                "Windows"
            ],
            "type": "string"
        },
        "agentCount": {
            "type": "int"
        },
        "networkPolicy": {
            "type": "string"
        },
        "podCidr": {
            "type": "string"
        },
        "loadBalancerCount": {
            "type": "int"
        },
        "connectedClustersApiVersion":{
            "type": "string"
        },
        "provisionedClustersApiVersion": {
            "type": "string"
        },
        "nodepoolLabel":{
            "type": "string"
        },
         "nodepoolLabelValue":{
            "type": "string"
        },
        "nodepoolTaints":{
            "type": "array",
            "defaultValue": []
        },
        "enableAzureHybridBenefit": {
            "type": "string",
            "allowedValues": [
                "True",
                "False"
            ]
        },
        "enableNfsCsiDriver": {
            "type": "bool"
        },
        "enableSmbCsiDriver": {
            "type": "bool"
        },
        "enableWorkloadIdentity": {
            "type": "bool",
            "defaultValue": false
        },
        "enableOidcIssuer": {
            "type": "bool",
            "defaultValue": false
        }
    },
    "resources": [
        {
            "type": "Microsoft.Kubernetes/connectedClusters",
            "apiVersion": "[parameters('connectedClustersApiVersion')]",
            "name": "[parameters('connectedClusterName')]",
            "location": "[parameters('location')]",
            "kind": "ProvisionedCluster",
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "agentPublicKeyCertificate": "",
                "aadProfile": {
                    "enableAzureRBAC": false
                },
                "securityProfile": {
                    "workloadIdentity": {
                        "enabled": "[parameters('enableWorkloadIdentity')]"
                    }
                },
                "oidcIssuerProfile": {
                    "enabled": "[parameters('enableOidcIssuer')]"
                }
            }
        },
        {
            "type": "Microsoft.HybridContainerService/provisionedClusterInstances",
            "apiVersion": "[parameters('provisionedClustersApiVersion')]",
            "name": "default",
            "extendedLocation": {
                "type": "CustomLocation",
                "name": "[parameters('customLocation')]"
            },
            "dependsOn": [
                "[resourceId('Microsoft.Kubernetes/connectedClusters', parameters('connectedClusterName'))]"
            ],
            "properties": {
                "kubernetesVersion": "[parameters('kubernetesVersion')]",
                "linuxProfile": {
                    "ssh": {
                        "publicKeys": [
                            {
                                "keyData": "[parameters('sshRSAPublicKey')]"
                            }
                        ]
                    }
                },
                "controlPlane": {
                    "count": "[parameters('controlPlaneNodeCount')]",
                    "controlPlaneEndpoint": {
                        "hostIP": "[parameters('controlPlaneIp')]"
                    },
                    "vmSize": "[parameters('controlPlaneVMSize')]"
                },
                "networkProfile": {
                    "networkPolicy": "[parameters('networkPolicy')]",
                    "loadBalancerProfile": {
                        "count": "[parameters('loadBalancerCount')]"
                    },
        "podCidr": "[parameters('podCidr')]"
                },
                "agentPoolProfiles": [
                    {
                        "name": "[parameters('agentName')]",
                        "count": "[parameters('agentCount')]",
                        "vmSize": "[parameters('agentVMSize')]",
                        "osType": "[parameters('agentOsType')]",
                        "nodeLabels": "[if(not(empty(parameters('nodepoolLabel'))), createObject(parameters('nodepoolLabel'), parameters('nodepoolLabelValue')), json('null'))]",
                        "nodeTaints": "[if(greater(length(parameters('nodepoolTaints')), 0), parameters('nodepoolTaints'), json('null'))]"
                    }
                ],
                "cloudProviderProfile": {
                    "infraNetworkProfile": {
                        "vnetSubnetIds": "[parameters('vnetSubnetIds')]"
                    }
                },
                "licenseProfile": {
                    "azureHybridBenefit": "[parameters('enableAzureHybridBenefit')]"
                },
                "storageProfile": {
                    "nfsCsiDriver": {
                        "enabled": "[parameters('enableNfsCsiDriver')]"
                    },
                    "smbCsiDriver": {
                        "enabled": "[parameters('enableSmbCsiDriver')]"
                    }
                }
            },
            "scope": "[format('Microsoft.Kubernetes/connectedClusters/{0}', parameters('connectedClusterName'))]"
        }
    ]
}
```

### Configure the parameters

Save the following parameter file and update the placeholder values with your environment information:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "eastus"
        },
        "customLocation": {
            "value": "/subscriptions/<your-subscription-id>/resourcegroups/<your-resource-group>/providers/microsoft.extendedlocation/customlocations/<your-custom-location>"
        },
        "vnetSubnetIds": {
            "value": [
                "/subscriptions/<your-subscription-id>/resourcegroups/<your-resource-group>/providers/Microsoft.AzureStackHCI/logicalNetworks/<your-lnet-name>>"
            ]
        },
        "connectedClusterName": {
            "value": "aks-test"
        },
        "sshRSAPublicKey": {
            "value": "<your-ssh-public-key>"
        },
        "controlPlaneIp": {
            "value": ""
        },
        "kubernetesVersion": {
            "value": "v1.33.7"
        },
        "controlPlaneVMSize": {
            "value": "Standard_D4s_v3"
        },
        "controlPlaneNodeCount": {
            "value": 1
        },
        "agentName": {
            "value": "agentpool1"
        },
        "agentVMSize": {
            "value": "Standard_D4s_v3"
        },
        "agentOsType": {
            "value": "Linux"
        },
        "agentCount": {
            "value": 2
        },
        "networkPolicy": {
            "value": "calico"
        },
        "loadBalancerCount": {
            "value": 0
        },
        "connectedClustersApiVersion": {
            "value": "2025-12-01-preview"
        },
        "provisionedClustersApiVersion": {
            "value": "2025-09-01-preview"
        },
        "nodepoolLabel": {
            "value": "myown"
        },
        "nodepoolLabelValue": {
            "value": "dingdong"
        },
        "nodepoolTaints": {
            "value": []
        },
        "enableAzureHybridBenefit": {
            "value": "False"
        },
        "enableNfsCsiDriver": {
            "value": true
        },
        "enableSmbCsiDriver": {
            "value": true
        },
        "enableWorkloadIdentity": {
            "value": false
        },
        "enableOidcIssuer": {
            "value": false
        },
        "enableOidcIssuer": {
            "value": false
        },
        "podCidr": {
            "value": "10.244.0.0/16"
        }
    }
}
```

>[!WARNING]
> - Pod CIDR is a required field. Ensure it's specified at time of cluster creation.

> [!NOTE]
> AKS on Azure Local for multi-rack deployments supports Azure role-based access control (Azure RBAC). This quickstart sets `enableAzureRBAC` to `false`. To enable Azure RBAC, set `enableAzureRBAC` to `true` in the `aadProfile` when you create the cluster. You can only enable Azure RBAC when you create the cluster. You can't change it on an existing cluster. For more information, see [Use Azure RBAC for AKS on Azure Local for multi-rack deployments](use-azure-rbac.md).

### Parameter reference

| Parameter | Required | Description | Default |
| --------- | -------- | ----------- | ------- |
| `provisionedClusterName` | Yes | Name for your AKS Arc cluster. | `my-aksarc-cluster` |
| `location` | Yes | Azure region. Must match the region of your Azure Local deployment. | Resource group location |
| `sshRSAPublicKey` | Yes | SSH public key for node access. | — |
| `kubernetesVersion` | Yes | Kubernetes version to deploy (for example, `1.33.7`). | — |
| `vnetSubnetIds` | Yes | Azure Resource Manager resource ID of the logical network. Must have DHCP enabled and /28+ subnet. | — |
| `customLocation` | Yes | Azure Resource Manager resource ID of the custom location. | — |
| `podCidr` | Yes | CIDR range for pod IPs. Must not overlap with the logical network subnet. | `10.244.0.0/16` |
| `controlPlaneIp` | No | This parameter _must_ be empty during cluster creation because it's auto-allocated. For any updates, it must be provided to match the current endpoint.| `""` (auto-allocate) |


## Step 5: Deploy the template

1. Sign in to Azure CLI and set your subscription:

   ```azurecli
   az login
   az account set --subscription "<subscription-id>"
   ```

1. Create a resource group (or use an existing one):

   ```azurecli
   az group create --name <resource-group> --location <location>
   ```

1. Deploy the ARM template:

   ```azurecli
   az deployment group create \
     --resource-group <resource-group> \
     --template-file <template-file>.json \
     --parameters @<parameters-file>.json
   ```

   The deployment takes several minutes to complete.

## Step 6: Verify the deployment

1. Check the deployment status:

   ```azurecli
   az deployment group show \
     --name aksarc-template \
     --resource-group <resource-group> \
     --query "properties.provisioningState" -o tsv
   ```

   The output should show `Succeeded`.

1. View the cluster details:

   ```azurecli
   az aksarc show \
     --name <cluster-name> \
     --resource-group <resource-group> -o table
   ```

## Step 7: Connect to the cluster

You can now access your Kubernetes cluster with the given permissions, using either direct mode or proxy mode.

### Access your cluster with kubectl (direct mode)

To access the Kubernetes cluster with the given permissions, the Kubernetes operator needs the Microsoft Entra **kubeconfig**, which you can get by using the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command. This command provides access to the admin-based kubeconfig, as well as a user-based kubeconfig. The admin-based kubeconfig file contains secrets and should be securely stored and rotated periodically. On the other hand, the user-based Microsoft Entra ID kubeconfig doesn't contain secrets and can be distributed to users who connect from their client machines.

To run this Azure CLI command, you need the **Microsoft.HybridContainerService/provisionedClusterInstances/listUserKubeconfig/action** permission, which is included in the **Azure Kubernetes Service Arc Cluster User** role:

```azurecli
az aksarc get-credentials -g "$resource_group_name" -n $aks_cluster_name --file <file-name>
```

Now you can use kubectl to manage your cluster. For example, list the nodes in your cluster by using `kubectl get nodes`. The first time you run it, you must sign in, as shown in the following example:

```azurecli
kubectl get nodes
```

The following example output shows the three nodes created in the previous steps. Ensure the node status is `Ready`.

```output
NAME                                          STATUS   ROLES           AGE    VERSION
haks-9be0b433-control-plane-tvmbn             Ready    control-plane   106m   v1.33.7
haks-9be0b433-nodepool1-md-64scc-gfknc        Ready    <none>          102m   v1.33.7
haks-9be0b433-nodepool1-md-64scc-m9lqp        Ready    <none>          102m   v1.33.7
```

### Access your cluster from a client device (proxy mode)

To access the Kubernetes cluster from anywhere with a proxy mode using `az connectedk8s proxy` command, you need the **Microsoft.Kubernetes/connectedClusters/listClusterUserCredential/action**, which is included in **Azure Arc enabled Kubernetes Cluster User** role permission.

Run the following steps on another client device:

1. Sign in using Microsoft Entra authentication
1. Get the cluster connect **kubeconfig** needed to communicate with the cluster from anywhere (even from outside the firewall surrounding the cluster):

     ```azurecli
     az connectedk8s proxy -n $CLUSTER_NAME -g $RESOURCE_GROUP
     ```

     > [!NOTE]
     > This command opens the proxy and blocks the current shell.

1. In a different shell session, use `kubectl` to send requests to the cluster.

   ```powershell
   kubectl get pods -A
   ```

You should now see a response from the cluster containing the list of all pods under the `default` namespace.

For more information, see [Access your cluster from a client device](/azure/azure-arc/kubernetes/cluster-connect?tabs=azure-cli%2Cagent-version#access-your-cluster-from-a-client-device).

## Related content

[AKS Arc cluster architecture](cluster-architecture.md)
