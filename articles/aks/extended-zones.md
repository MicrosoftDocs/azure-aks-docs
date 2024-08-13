---
title: Azure Kubernetes Service (AKS) for Extended Zones (preview)
description: Learn how to deploy an Azure Kubernetes Service (AKS) for Azure Extended Zone cluster
author: moushumig
ms.author: moghosal
ms.service: azure-kubernetes-service
ms.topic: article
ms.date: 04/04/2023
---

# Azure Kubernetes Service for Extended Zones (preview)

Azure Kubernetes Service (AKS) for Extended Zones provides an extensive and sophisticated set of capabilities that make it simpler to deploy and operate a fully managed Kubernetes cluster in an Extended Zone scenario.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What are Azure Extended Zones?

Azure Extended Zones are small-footprint extensions of Azure placed in metros, industry centers, or a specific jurisdiction to serve low latency and data residency workloads. Azure Extended Zones supports virtual machines (VMs), containers, storage, and a selected set of Azure services and can run latency-sensitive and throughput-intensive applications close to end users and within approved data residency boundaries.

Azure Extended Zones are part of the Microsoft global network that provides secure, reliable, high-bandwidth connectivity between applications that run on an Azure Extended Zone close to the user. Extended Zones address low latency and data residency by bringing all the benefits of the Azure ecosystem (access, user experience, automation, security, and more) closer to you or your jurisdiction. You can provision and manage Azure Extended Zones resources, services, and workloads through the Azure portal and other essential Azure tools. Azure Extended Zone sites are associated with a parent Azure region that hosts all the control plane functions associated with the services running in the extended zone.

The key scenarios Azure Extended Zones enable are:

- **Latency**: users want to run their resources, for example, media editing software, remotely with low latency.
- **Data residency**: users want their applications data to stay within a specific geography and might essentially want to host locally for various privacy, regulatory, and compliance reasons.

The following list highlights some of the industries and use cases where Azure Extended Zones can provide benefits:

- **Healthcare**
  - Remote patient care
  - Remote clinical education
  - Pop-up care and services
- **Public infrastructure**
  - Visual detection
  - Critical infrastructure
  - Emergency services
  - Surveillance and security
- **Manufacturing**
  - Real-time command and control in robotics
  - Machine vision
- **Media and Gaming**
  - Gaming and game streaming
  - Media editing, streaming, and content delivery
  - Remote rendering for mixed reality and Virtual Desktop Infrastructure scenarios
- **Oil and Gas**
  - Oil and gas exploration
  - Real-time analytics and inference via artificial intelligence and machine learning
- **Retail**
  - Digital in-store experiences
  - Connected worker

To learn more, see the [Azure Extended Zones overview][aez-overview].

## What is AKS for Extended Zones?

Azure Extended Zones provide a suite of Azure services for managing and deploying applications in extended zone computing environments. One of the key services offered is Azure Kubernetes Service (AKS) for Extended Zones. AKS for Extended Zones enables organizations to meet the unique needs of extended zones while leveraging the container orchestration and management capabilities of AKS, making the deployment and management of applications hosted in extended zones much simpler.

Just like a typical AKS deployment, the Azure platform is responsible for maintaining the AKS control plane and providing the infrastructure, while your organization retains control over the worker nodes that run the applications.

:::image type="content" source="./media/extended-zones/aez-aks-architecture.png" alt-text="An architecture diagram of an AKS for Azure Extended Zones deployment, showing that the control plane is deployed in an Azure region while agent nodes are deployed in an Azure Extended Zone.":::

Creating an AKS for Extended Zones cluster uses an optimized architecture that is specifically tailored to meet the unique needs and requirements of Extended Zones applications and workloads. The control plane of the clusters is created, deployed, and configured in the closest Azure region, while the agent nodes and node pools attached to the cluster are located in an Azure Extended Zone.

The components present in an AKS for Extended Zones cluster are identical to those in a typical cluster deployed in an Azure region, ensuring that the same level of functionality and performance is maintained. For more information on these components, see [Kubernetes core concepts for AKS][concepts-cluster].

## Deploy a cluster in an Azure Extended Zone location

### Prerequisites

* Before you can deploy an AKS for Extended Zones cluster, your subscription needs to have access to the targeted Azure Extended Zone location. This access is provided through our onboarding process, done by following the steps outlined in the [Azure Extended Zones overview][aez-overview].

* Your cluster must be running Kubernetes version 1.24 or later.

* The identity you're using to create your cluster must have the appropriate minimum permissions. For more information on access and identity for AKS, see [Access and identity options for Azure Kubernetes Service (AKS)](./concepts-identity.md).

### Limitations

* AKS for Extended Zones allows for autoscaling only up to 100 nodes in a node pool

### Resource constraints

While AKS is fully supported in Azure Extended Zones, resource constraints may still apply:

* In all Azure Extended Zones, the maximum node count is 100.

* In Azure Extended Zones, only selected VM SKUs are offered.
 <!--NEED LIST OF WHICH VM SKUS  -->

Deploying an AKS cluster in an Azure Extended Zone is similar to deploying an AKS cluster in any other region. All resource providers provide a field named [`extendedLocation`](/javascript/api/@azure/arm-compute/extendedlocation), which you can use to deploy resources in an Azure Extended Zone. This allows for precise and targeted deployment of your AKS cluster.

### [Resource Manager Template](#tab/azure-resource-manager)

A parameter called `extendedLocation` should be used to specify the desired Azure Extended zone:

```json
"extendedLocation": {
    "name": "<extended-zone-id>",
    "type": "EdgeZone",
},
```
The following example is an Azure Resource Manager template (ARM template) that will deploy a new cluster in an Azure Extended Zone. Provide your own values for the following template parameters:

* **Subscription**: Select an Azure subscription.

* **Resource group**: Select Create new. Enter a unique name for the resource group, such as myResourceGroup, then choose OK.

* **Location**: Select a location, such as East US.

* **Cluster name**: Enter a unique name for the AKS cluster, such as myAKSCluster.

* **DNS prefix**: Enter a unique DNS prefix for your cluster, such as myakscluster.

* **Linux Admin Username**: Enter a username to connect using SSH, such as azureuser.

* **SSH RSA Public Key**: Copy and paste the public part of your SSH key pair (by default, the contents of the `~/.ssh/id_rsa.pub` file).

If you're unfamiliar with ARM templates, see the tutorial on [deploying a local ARM template][arm-template-deploy].

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

### [Azure CLI](#tab/azure-cli)

Set the following variables for use in the deployment, filling in your own values:

```bash
SUBSCRIPTION="<your-subscription>"
RG_NAME="myResourceGroup"
CLUSTER_NAME="myAKSCluster"
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

### [Azure portal](#tab/azure-portal)

In this section you'll learn how to deploy a Kubernetes cluster in the Azure Extended Zone.

If you don't have an Azure subscription, create an Azure free account before you begin.

1. Sign in to the [Azure portal](https://portal.azure.com).

2. On the Azure portal menu or from the **Home** page, select **Create a resource**.

3. Select **Containers** > **Kubernetes Service**.

4. On the **Basics** page, configure the following options:

    - **Project details**:
        * Select an Azure **Subscription**.
        * Select or create an Azure **Resource group**, such as *myResourceGroup*.
    - **Cluster details**:
        * Ensure the **Preset configuration** is *Production Standard ($$)*. For more information on preset configurations, see [Cluster configuration presets in the Azure portal][preset-config].

            :::image type="content" source="./learn/media/quick-kubernetes-deploy-portal/cluster-preset-options.png" alt-text="Screenshot of Create AKS cluster - portal preset options.":::

        * Enter a **Kubernetes cluster name**, such as *myAKSCluster*.
        * Select **Deploy to an Azure Extended Zone** under the region locator for the AKS cluster.
        * Select the Azure Extended Zone targeted for deployment, and leave the default value selected for **Kubernetes version**.
            
            :::image type="content" source="./media/extended-zones/select-extended-zone.png" alt-text="Screenshot of the Azure Extended Zone Context pane for selecting location for AKS cluster in Azure Extended Zone creation.":::

    > [!NOTE]
    > You can change the preset configuration when creating your cluster by selecting *Learn more and compare presets* and choosing a different option.

8. Click **Review + create**. When you navigate to the **Review + create** tab, Azure runs validation on the settings that you have chosen. If validation passes, you can proceed to create the AKS cluster by selecting **Create**. If validation fails, then it indicates which settings need to be modified.

    :::image type="content" source="./media/extended-zones/review-and-create-inline.png" alt-text="Screenshot of Create AKS cluster in Azure Extended Zone showing the review and create tab." lightbox="./media/extended-zones/review-and-create-full.png":::

9. It takes a few minutes to create the AKS cluster. When your deployment is complete, navigate to your resource by either:
    * Selecting **Go to resource**.
    * Browsing to the AKS cluster resource group and selecting the AKS resource. In this example you browse for *myResourceGroup* and select the resource *myAKSCluster*. You can see the Azure Extended Zone locations with the home Azure region in the Location.

---

## Monitoring

After deploying an AKS for Extended Zones cluster, you can check the status and monitor the cluster's metrics. Monitoring capability is similar to what is available in Azure regions.

:::image type="content" source="./media/extended-zones/monitoring-cluster-in-extended-zone.png" alt-text="Screenshot of monitoring metrics for Azure Extended Zone AKS cluster.":::

## Next steps

After deploying your AKS cluster in an Azure Extended Zone, learn about how you can [configure an AKS cluster][configure-cluster].

<!-- LINKS -->
[aez-overview]: /azure/extended-zones/overview
[configure-cluster]: ./cluster-configuration.md
[arm-template-deploy]: /azure/azure-resource-manager/templates/deployment-tutorial-local-template
[concepts-cluster]: /azure/aks/core-aks-concepts
[az-aks-create]: /cli/azure/aks#az_aks_create
[preset-config]: ./quotas-skus-regions.md#cluster-configuration-presets-in-the-azure-portal
