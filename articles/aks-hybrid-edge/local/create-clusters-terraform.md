---
title: Create Kubernetes clusters using Terraform (preview)
description: Learn how to create Kubernetes clusters using Terraform.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: local

---

# Create Kubernetes clusters using Terraform (preview)

This article describes how to create Kubernetes clusters in Azure Local using Terraform and the Azure Verified Module. The workflow is as follows:

- Create an SSH key pair.
- Create a Kubernetes cluster in Azure Local using Terraform. By default, the cluster is Azure Arc-connected.
- Validate the deployment and connect to the cluster.

> [!IMPORTANT]
> These preview features are available on a self-service, opt-in basis. Previews are provided "as is" and "as available," and they're excluded from the service-level agreements and limited warranty. Azure Kubernetes Service, Hybrid and Edge previews are partially covered by customer support on a best-effort basis.

## Before you begin

Before you begin, make sure you have the following prerequisites:

1. Get the following details from your on-premises infrastructure administrator:
   - Azure subscription ID: the Azure subscription ID that uses Azure Local for deployment and registration.
   - Custom location name or ID: the Azure Resource Manager ID of the custom location. The custom location is configured during the Azure Local cluster deployment. Your infrastructure admin should give you the Resource Manager ID of the custom location. This parameter is required to create Kubernetes clusters. You can also get the Resource Manager ID using `az customlocation show --name "<custom location name>" --resource-group <azure resource group> --query "id" -o tsv`, if the infrastructure admin provides a custom location name and resource group name.
   - Logical network name or ID: the Azure Resource Manager ID of the Azure Local logical network that was created following these steps. Your admin should give you the ID of the logical network. This parameter is required in order to create Kubernetes clusters. You can also get the Azure Resource Manager ID using `az stack-hci-vm network lnet show --name "<lnet name>" --resource-group <azure resource group> --query "id" -o tsv` if you know the resource group in which the logical network was created.
1. Make sure you have GitHub, [the latest version of Azure CLI](/cli/azure/install-azure-cli), and [the Terraform client](/azure/developer/terraform/quickstart-configure) installed on your development machine.  
1. [Download and install kubectl](https://kubernetes.io/docs/tasks/tools/) on your development machine.

## Create an SSH key pair

Create an SSH key pair in Azure and store the private key file for troubleshooting and log collection purposes. For detailed instructions, see [Create and store SSH keys with the Azure CLI](/azure/virtual-machines/ssh-keys-azure-cli) or in the [Azure portal](/azure/virtual-machines/ssh-keys-portal).

1. [Open a Cloud Shell session](https://shell.azure.com/) in your web browser or launch a terminal on your local machine.
1. Create an SSH key pair using the [az sshkey create](/cli/azure/sshkey#az-sshkey-create) command:  

   ```azurecli
   az sshkey create --name "mySSHKey" --resource-group $<resource_group_name>
   ```

   or, use the `ssh-keygen` command:

   ```azurecli
   ssh-keygen -t rsa -b 4096 
   ```

1. Retrieve the value of your public key from Azure or from your local machine under **/.ssh/id_rsa.pub**.

For more options, you can either follow [Configure SSH keys for an AKS cluster](/azure/aks/aksarc/configure-ssh-keys) to create SSH keys, or use [Restrict SSH access](/azure/aks/aksarc/restrict-ssh-access) during cluster creation. To access nodes afterward, see [Connect to Windows or Linux worker nodes with SSH](/azure/aks/aksarc/ssh-connect-to-windows-and-linux-worker-nodes).

## Sign in to Azure

Terraform only supports authenticating to Azure with the Azure CLI using [`az login`](/cli/azure/reference-index#az-login). Authenticating using Azure PowerShell isn't supported. Therefore, while you can use the Azure PowerShell module when doing your Terraform work, you must first [authenticate to Azure](/azure/developer/terraform/authenticate-to-azure):

```azurecli
az login 
```

## Implement the Terraform code

1. Create a directory you can use to test the sample Terraform code, and make it your current directory.
1. In the same directory, create a file named **providers.tf** and paste the following code. Make sure to replace `<subscription_ID>` with your subscription ID:

   ```terraform
   terraform { 
    required_version = "~> 1.5" 
    required_providers { 
      azapi = { 
        source  = "azure/azapi" 
        version = "~> 2.0" 
      } 
      azurerm = { 
       source  = "hashicorp/azurerm" 
       version = "~> 4.0" 
      } 
     }
    }
  
    provider "azurerm" {
    subscription_id = "<subscription_ID>"
    features { 
     resource_group { 
      prevent_deletion_if_contains_resources = false 
     } 
    } 
   }
   ```

1. Create another file named **main.tf** that points to the latest AKS AVM module, and insert the following code. You can read the comments in the the module and edit parameters as needed. Please make sure all the values are correctly entered to avoid failures during cluster creation. To find the admin group object ID, see [Enable Microsoft Entra authentication for Kubernetes clusters](hyperconverged/enable-authentication-microsoft-entra-id.md). To enable Azure RBAC, update the corresponding parameter and see [Enable Azure RBAC for Kubernetes Authorization](hyperconverged/azure-rbac-local.md) for prerequisites.

   ```terraform
   module "aks_arc" { 
   # Make sure to use the latest AVM module version
   source = "Azure/avm-res-hybridcontainerservice-provisionedclusterinstance/azurerm" 
   version = "~>2.0"

   # Make sure to provide all required parameters; for example, location= = "eastus"
   resource_group_id = "<Resource_Group>" 
   location = "<Region>" 
   name = "<Cluster_Name>" 
   logical_network_id = "<LNet_ID>" 
   custom_location_id = "<CustomLocation_ID>" 
   agent_pool_profiles = [{count=1}] 
   ssh_public_key =  "Your_SSH_Key"

   # Optional parameters, update them as needed
   enable_azure_rbac = false
   enable_workload_identity = false 
   enable_oidc_issuer = false 
   rbac_admin_group_object_ids = ["<Admin_Group_Object_ID>"]
   }
   ```

## Initialize Terraform

Run [`terraform init`](https://www.terraform.io/docs/commands/init.html) to initialize the Terraform deployment. Make sure to use the `-upgrade` flag to upgrade the necessary provider plugins to the latest version:

```terraform
terraform init -upgrade
```

## Create a Terraform execution plan and apply

Make sure you run [`az login`](/cli/azure/reference-index#az-login) and authenticate to Azure before this step, otherwise applying the Terraform plan fails. Run [`terraform plan`](https://www.terraform.io/docs/commands/plan.html) to create an execution plan, then run [`terraform apply`](https://www.terraform.io/docs/commands/apply.html) to apply the output file to your cloud infrastructure:

```terraform
terraform plan -out main.tfplan 
terraform apply main.tfplan 
```

The command executes, then returns success after the resource is successfully provisioned.

## Validate the deployment and connect to the cluster

You can now connect to your Kubernetes cluster by running `az connectedk8s proxy` from your development machine. You can also use **kubectl** to see the node and pod status. Follow the same steps as described in [Connect to the Kubernetes cluster](aks-create-clusters-cli.md#connect-to-the-kubernetes-cluster).

## Next steps

[Connect to the Kubernetes cluster](aks-create-clusters-cli.md#connect-to-the-kubernetes-cluster)
