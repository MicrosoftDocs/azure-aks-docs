---
title: Azure Kubernetes Service (AKS) for Extended Zones (preview)
description: Learn how to deploy an Azure Kubernetes Service (AKS) for Azure Extended Zone cluster
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 04/04/2023
---

# Azure Kubernetes Service for Extended Zones (preview)

Azure Kubernetes Service (AKS) for Extended Zones provides an extensive and sophisticated set of capabilities that make it simpler to deploy and operate a fully managed Kubernetes cluster in an Extended Zone scenario.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What are Azure Extended Zones?

Azure Extended Zones are small-footprint extensions of Azure placed in metros, industry centers, or a specific jurisdiction to serve low latency and data residency workloads. Azure Extended Zones supports virtual machines (VMs), containers, storage, and a selected set of Azure services. They can run latency-sensitive and throughput-intensive applications close to end users and within approved data residency boundaries.

Azure Extended Zones are part of the Microsoft global network that provides secure, reliable, high-bandwidth connectivity between applications that run on an Azure Extended Zone close to the user. Extended Zones address low latency and data residency by bringing all the benefits of the Azure ecosystem (access, user experience, automation, security, and more) closer to you or your jurisdiction. Azure Extended Zone sites are associated with a parent Azure region that hosts all the control plane functions associated with the services running in the extended zone.

### Extended Zones use cases

Azure Extended Zones enable **low latency** and **data residency** scenarios. For example, you might want to run media editing software remotely with low latency or keep your applications' data within a specific geography for privacy, regulatory, and compliance reasons.

The following table highlights some of the industries and use cases where Azure Extended Zones can provide benefits:

| Industry | Use cases |
|----------|-----------|
| Healthcare | • Remote patient care <br> • Remote clinical education <br> • Pop-up care and services |
| Public infrastructure | • Visual detection <br> • Critical infrastructure <br> • Emergency services <br> • Surveillance and security |
| Manufacturing | • Real-time command and control in robotics <br> • Machine vision |
| Media and gaming | • Gaming and game streaming <br> • Media editing, streaming, and content delivery <br> • Remote rendering for mixed reality and Virtual Desktop Infrastructure scenarios |
| Oil and gas | • Oil and gas exploration <br> • Real-time analytics and inference via artificial intelligence and machine learning |
| Retail | • Digital in-store experiences <br> • Connected worker |

For more information, see the [Azure Extended Zones overview][aez-overview].

## What is AKS for Extended Zones?

AKS for Extended Zones enables organizations to meet the unique needs of extended zones while leveraging the container orchestration and management capabilities of AKS, making the deployment and management of applications hosted in extended zones much simpler. Just like a typical AKS deployment, the Azure platform is responsible for maintaining the AKS control plane and providing the infrastructure, while your organization retains control over the worker nodes that run the applications.

:::image type="content" source="./media/extended-zones/aez-aks-architecture.png" alt-text="An architecture diagram of an AKS for Azure Extended Zones deployment, showing that the control plane is deployed in an Azure region while agent nodes are deployed in an Azure Extended Zone.":::

Creating an AKS for Extended Zones cluster uses an optimized architecture that is specifically tailored to meet the unique needs and requirements of Extended Zones applications and workloads. The control plane of the clusters is created, deployed, and configured in the closest Azure region, while the agent nodes and node pools attached to the cluster are located in an Azure Extended Zone. The components in an AKS for Extended Zones cluster are identical to those in a typical cluster deployed in an Azure region, ensuring that the same level of functionality and performance is maintained. For more information, see [Kubernetes core concepts for AKS][concepts-cluster].

## Deploy a cluster in an Azure Extended Zone location

Deploying an AKS cluster in an Azure Extended Zone is similar to deploying an AKS cluster in any other region. All resource providers provide a field named [`extendedLocation`](/javascript/api/@azure/arm-compute/extendedlocation), which you can use to deploy resources in an Azure Extended Zone. This allows for precise and targeted deployment of your AKS cluster.

### Prerequisites

* Before you can deploy an AKS for Extended Zones cluster, your subscription needs to have access to the targeted Azure Extended Zone location. This access is provided through our onboarding process, done by following the steps outlined in the [Azure Extended Zones overview][aez-overview].
* Your cluster must be running Kubernetes version 1.24 or later.
* The identity you're using to create your cluster must have the appropriate minimum permissions. For more information on access and identity for AKS, see [Access and identity options for Azure Kubernetes Service (AKS)](./concepts-identity.md).

### Limitations and constraints

When deploying an AKS cluster in an Azure Extended Zone, the following limitations and constraints apply:

* AKS for Extended Zones allows for autoscaling only up to 100 nodes in a node pool.
* In all Azure Extended Zones, the maximum node count is 100.
* In Azure Extended Zones, only selected VM SKUs are offered.

### [ARM template](#tab/azure-resource-manager)

You use the  `extendedLocation` parameter to specify the desired Azure Extended zone in an ARM template.

```json
"extendedLocation": {
    "name": "<extended-zone-id>",
    "type": "EdgeZone",
},
```

The following ARM template deploys a new cluster in an Azure Extended Zone.

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "bicep",
      "version": "0.9.1.41621",
      "templateHash": "2637152180661081755"
    }
  },
  "parameters": {
    "clusterName": {
      "type": "string",
      "defaultValue": "myAKSCluster",
      "metadata": {
        "description": "The name of the Managed Cluster resource."
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]",
      "metadata": {
        "description": "The location of the Managed Cluster resource."
      }
    },
    "edgeZoneName": {
      "type": "String",
      "metadata": {
        "description": "The name of the Azure Extended Zone"
      }
    },
    "dnsPrefix": {
      "type": "string",
      "metadata": {
        "description": "Optional DNS prefix to use with hosted Kubernetes API server FQDN."
      }
    },
    "osDiskSizeGB": {
      "type": "int",
      "defaultValue": 0,
      "maxValue": 1023,
      "minValue": 0,
      "metadata": {
        "description": "Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize."
      }
    },
    "agentCount": {
      "type": "int",
      "defaultValue": 3,
      "maxValue": 50,
      "minValue": 1,
      "metadata": {
        "description": "The number of nodes for the cluster."
      }
    },
    "agentVMSize": {
      "type": "string",
      "defaultValue": "standard_d2s_v3",
      "metadata": {
        "description": "The size of the Virtual Machine."
      }
    },
    "linuxAdminUsername": {
      "type": "string",
      "metadata": {
        "description": "User name for the Linux Virtual Machines."
      }
    },
    "sshRSAPublicKey": {
      "type": "string",
      "metadata": {
        "description": "Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example 'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm'"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.ContainerService/managedClusters",
      "apiVersion": "2022-05-02-preview",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('location')]",
      "extendedLocation": {
        "name": "[parameters('edgeZoneName')]",
        "type": "EdgeZone"
      }
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "dnsPrefix": "[parameters('dnsPrefix')]",
        "agentPoolProfiles": [
          {
            "name": "agentpool",
            "osDiskSizeGB": "[parameters('osDiskSizeGB')]",
            "count": "[parameters('agentCount')]",
            "vmSize": "[parameters('agentVMSize')]",
            "osType": "Linux",
            "mode": "System"
          }
        ],
        "linuxProfile": {
          "adminUsername": "[parameters('linuxAdminUsername')]",
          "ssh": {
            "publicKeys": [
              {
                "keyData": "[parameters('sshRSAPublicKey')]"
              }
            ]
          }
        }
      }
    }
  ],
  "outputs": {
    "controlPlaneFQDN": {
      "type": "string",
      "value": "[reference(resourceId('Microsoft.ContainerService/managedClusters', parameters('clusterName'))).fqdn]"
    }
  }
}
```

If you're unfamiliar with ARM templates, see the tutorial on [deploying a local ARM template][arm-template-deploy].

### [Azure CLI](#tab/azure-cli)

Prepare the following variables to deploy an AKS cluster in an Azure Extended Zone using the Azure CLI:

```azurecli-interactive
SUBSCRIPTION="<your-subscription>"
RG_NAME="<your-resource-group>"
CLUSTER_NAME="<your-cluster>"
EXTENDED_ZONE_NAME="<extended-zone-id>"
LOCATION="<parent-region>" # Ensure this location corresponds to the parent region for your targeted Azure Extended Zone
```

After making sure you're logged in and using the appropriate subscription, use [`az aks create`][az-aks-create] to deploy the cluster, specifying the targeted Azure Extended Zone with the `--edge-zone` property.

```azurecli-interactive
# Log in to Azure
az login

# Set the subscription you want to create the cluster on
az account set --subscription $SUBSCRIPTION 

# Create the resource group
az group create --name $RG_NAME --location $LOCATION

# Deploy the cluster in your designated Azure Extended Zone
az aks create \
    --resource-group $RG_NAME \
    --name $CLUSTER_NAME \
    --edge-zone $EXTENDED_ZONE_NAME \
    --location $LOCATION \
    --generate-ssh-keys
```

After deploying an AKS for Extended Zones cluster, you can check the status and monitor the cluster's metrics using the Azure portal or the Azure CLI.

---

## Next steps

After deploying your AKS cluster in an Azure Extended Zone, learn about [AKS cluster configuration options][configure-cluster].

<!-- LINKS -->
[aez-overview]: /azure/extended-zones/overview
[configure-cluster]: ./cluster-configuration.md
[arm-template-deploy]: /azure/azure-resource-manager/templates/deployment-tutorial-local-template
[concepts-cluster]: /azure/aks/core-aks-concepts
[az-aks-create]: /cli/azure/aks#az_aks_create
