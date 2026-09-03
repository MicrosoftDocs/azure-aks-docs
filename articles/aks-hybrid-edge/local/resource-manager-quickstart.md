---
title: Deploy a Kubernetes cluster using an Azure Resource Manager template
description: Learn how to deploy a Kubernetes cluster in Azure Kubernetes Service (AKS) Hybrid and Edge using an Azure Resource Manager template.
ms.topic: quickstart-arm
ms.custom: devx-track-arm-template, devx-track-azurecli, local
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.lastreviewed: 01/09/2026
ms.reviewer: rbaziwane
---

# Quickstart: deploy a Kubernetes cluster using an Azure Resource Manager template

[!INCLUDE [hci-applies-to-23h2](../includes/hci-applies-to-23h2.md)]

This quickstart shows how to deploy a Kubernetes cluster in Azure Kubernetes Service (AKS) Arc using an Azure Resource Manager template (ARM template). Azure Arc extends Azure management capabilities to Kubernetes clusters anywhere, providing a unified approach to managing different environments.

## Before you begin

This article assumes a basic understanding of Kubernetes concepts.

To deploy an ARM template, you need write access on the resources you're deploying, and access to all operations on the `Microsoft.Resources/deployments` resource type. For example, to deploy a virtual machine, you need `Microsoft.Compute/virtualMachines/write` and `Microsoft.Resources/deployments/*` permissions. For a list of roles and permissions, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

### Prerequisites

- An Azure account with an active subscription.
- An Azure Local cluster.
- The [latest version of Azure CLI](/cli/azure/install-azure-cli).

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

Create an SSH key pair in Azure and store the private key file for troubleshooting and log collection purposes. For detailed instructions, see [Configure SSH keys for an AKS cluster](hyperconverged/configure-ssh-keys.md) to create SSH keys, or use [Restrict SSH access](hyperconverged/restrict-ssh-access.md) during cluster creation. To access nodes afterward, see [Connect to Windows or Linux worker nodes with SSH](hyperconverged/ssh-connect-to-windows-and-linux-worker-nodes.md).

1. [Open a Cloud Shell session](https://shell.azure.com/) in your web browser or launch a terminal on your local machine.
1. Create an SSH key pair using the [az sshkey create](/cli/azure/sshkey#az-sshkey-create) command:

   ```azurecli
   az sshkey create --name "mySSHKey" --resource-group $<resource_group_name>
   ```

   or, use the `ssh-keygen` command:

   ```azurecli
   ssh-keygen -t rsa -b 4096 
   ```

1. Retrieve the value of your public key from Azure or from your local machine under _/.ssh/id_rsa.pub_.

## Step 3: Deploy the cluster using ARM templates

For detailed instructions on deploying an AKS cluster using ARM templates, see the [AKSArc deployment templates repository](https://github.com/Azure/aksArc/tree/main/deploymentTemplates/aksarc-ARM-azlocal/Cluster). The repository includes:

- **CreateWithExistingLnet**: Deploy a cluster using an existing logical network.
- **CreateWithoutExistingLnet**: Deploy a cluster and create a new logical network.
- Complete deployment instructions and examples.
- Parameter file templates.

To deploy your cluster, follow the instructions in the repository's [README](https://github.com/Azure/aksArc/blob/main/deploymentTemplates/aksarc-ARM-azlocal/Cluster/README.md) file.

## Step 4: Connect to the cluster

1. To connect to the cluster, run the [az connectedk8s proxy](/cli/azure/connectedk8s) command. The command downloads and runs a proxy binary on the client machine, and fetches a `kubeconfig` file associated with the cluster.

   ```azurecli
   az connectedk8s proxy --name <cluster name> -g <resource group>
   ```

   Or, use the Kubernetes command-line client, `kubectl`. If you use Azure Cloud Shell, `kubectl` is already installed. To install and run `kubectl` locally, run [az-aks-install-cli](/cli/azure/aks#az-aks-install-cli) or download from the [Kubernetes](https://kubernetes.io/docs/tasks/tools/#kubectl) website.

   Configure `kubectl` to connect to your Kubernetes cluster using the `az aksarc get-credentials` command. This command downloads credentials and configures the Kubernetes CLI to use the credentials.

   ```azurecli
   az aksarc get-credentials --resource-group "<resource-group-name>" --name "<cluster-name>"
   ```

1. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes.

   ```cmd
   kubectl get nodes -A --kubeconfig .\<path to kubecofig> 
   ```

   The following example output shows the three nodes created in the previous steps. Make sure the node status is `Ready`.

   ```output
   NAME                                STATUS   ROLES   AGE   VERSION
   aks-agentpool-27442051-vmss000000   Ready    agent   10m   v1.27.7
   aks-agentpool-27442051-vmss000001   Ready    agent   10m   v1.27.7
   aks-agentpool-27442051-vmss000002   Ready    agent   11m   v1.27.7
   ```

## Deploy node pools (optional)

To add more node pools to your cluster using ARM templates, see the [ARM template to deploy/update an AKS node pool](https://github.com/Azure/aksArc/tree/main/deploymentTemplates/aksarc-ARM-azlocal/Nodepool). The repository includes complete instructions for deploying and managing node pools.

## Related content

[AKS overview](../windows-server/overview.md).
