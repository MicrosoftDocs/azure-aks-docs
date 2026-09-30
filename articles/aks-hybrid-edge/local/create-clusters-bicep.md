---
title: Create Kubernetes clusters using Bicep
description: Learn how to create Kubernetes clusters in Azure Local using Bicep.
ms.topic: how-to
ms.custom: devx-track-azurecli, local
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: haojiehang
ms.lastreviewed: 01/09/2026

---

# Create Kubernetes clusters using Bicep

This article describes how to create Kubernetes clusters in Azure Local using Bicep. The workflow creates an SSH key pair and creates a Kubernetes cluster in Azure Local using Bicep. By default, the cluster is Azure Arc-connected. You then validate the deployment and connect to the cluster.

## Before you begin

Before you begin, make sure you have the following prerequisites:

1. Get the following details from your on-premises infrastructure administrator:

   - Azure subscription ID: the Azure subscription ID that uses Azure Local for deployment and registration.
   - Custom location name or ID: the Azure Resource Manager ID of the custom location. The custom location is configured during the Azure Local cluster deployment. Your infrastructure admin should give you the Resource Manager ID of the custom location. This parameter is required in order to create Kubernetes clusters. You can also get the Resource Manager ID using `az customlocation show --name "<custom location name>" --resource-group <azure resource group> --query "id" -o tsv`, if the infrastructure admin provides a custom location name and resource group name.
   - Logical network name or ID: the Azure Resource Manager ID of the Azure Local logical network that was created following these steps. Your admin should give you the ID of the logical network. This parameter is required in order to create Kubernetes clusters. You can also get the Azure Resource Manager ID using `az stack-hci-vm network lnet show --name "<lnet name>" --resource-group <azure resource group> --query "id" -o tsv` if you know the resource group in which the logical network was created.

1. Make sure you have the [latest version of Azure CLI](/cli/azure/install-azure-cli) on your development machine. You can also upgrade your Azure CLI version using `az upgrade`.
1. Download and install the Kubernetes command-line tool, `kubectl` on your development machine. You can use [az-aks-install-cli](/cli/azure/aks#az-aks-install-cli) or the [Kubernetes](https://kubernetes.io/docs/tasks/tools/#kubectl) website. Use `kubectl` to run commands against Kubernetes clusters, deploy applications, inspect and manage cluster resources, and view logs.

## Create an SSH key pair

Create an SSH key pair in Azure and store the private key file for troubleshooting and log collection purposes. For detailed instructions, see [Configure SSH keys for an AKS cluster](hyperconverged/configure-ssh-keys.md) to create SSH keys, or use [Restrict SSH access](hyperconverged/restrict-ssh-access.md) during cluster creation. To access nodes afterward, see [Connect to Windows or Linux worker nodes with SSH](hyperconverged/ssh-connect-to-windows-and-linux-worker-nodes.md).

1. [Open a Cloud Shell session](https://shell.azure.com/) in your web browser or launch a terminal on your local machine.
1. Create an SSH key pair using the [az sshkey create](/cli/azure/sshkey#az-sshkey-create) command.  

   ```azurecli
   az sshkey create --name "mySSHKey" --resource-group $<resource_group_name>
   ```

   or, use the `ssh-keygen` command:

   ```azurecli
   ssh-keygen -t rsa -b 4096 
   ```

1. Retrieve the value of your public key from Azure or from your local machine under _/.ssh/id_rsa.pub_.

## Deploy the cluster using Bicep templates

For detailed instructions on deploying an AKS cluster using Bicep templates, see the [AKSArc Bicep deployment templates repository](https://github.com/Azure/aksArc/tree/main/deploymentTemplates/aksarc-bicep-azlocal/Cluster). The repository includes:

- **CreateWithExistingLnet**: Deploy a cluster using an existing logical network.
- **CreateWithoutExistingLnet**: Deploy a cluster and create a new logical network.
- Complete deployment instructions and examples.
- Parameter file templates.

To deploy your cluster, follow the instructions in the repository's [README](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aksarc-bicep-azlocal/Cluster/README.md) file.

## Connect to the cluster

After deployment, you can connect to your Kubernetes cluster by running the `az connectedk8s proxy` command from your development machine. You can also use `kubectl` to see the node and pod status. Follow the same steps as described in [Connect to the Kubernetes cluster](aks-create-clusters-cli.md#connect-to-the-kubernetes-cluster).

## Deploy node pools (optional)

To add more node pools to your cluster using Bicep templates, see the [Bicep template to deploy/update an AKS node pool](https://github.com/Azure/aksArc/tree/main/deploymentTemplates/aksarc-bicep-azlocal/Nodepool). The repository includes complete instructions for deploying and managing node pools.

## Related content

[Create Kubernetes clusters using Azure CLI](aks-create-clusters-cli.md).

