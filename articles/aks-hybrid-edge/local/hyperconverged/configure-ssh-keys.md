---
title: Configure SSH keys for a cluster in AKS Hybrid and Edge
description: Learn how to configure SSH keys for an AKS cluster.
ms.date: 09/01/2026
ms.topic: how-to
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: leslielin
ms.lastreviewed: 01/10/2025
ms.custom: hyperconverged
---

# Configure SSH keys for an AKS cluster

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

[Secure Shell Protocol (SSH)](https://www.ssh.com/ssh/) is an encrypted connection protocol that provides secure sign-ins over unsecured connections. AKS on Azure Local supports access to a VM in your Kubernetes nodes over SSH using a public-private key pair, also known as *SSH keys*. For information about how to create and manage SSH keys, see [Create and manage SSH keys](/azure/virtual-machines/ssh-keys-azure-cli).

An SSH key is required when deploying an AKS cluster. When you create the cluster, you can either generate a new key pair or use an existing public key. This article explains how to use SSH keys for AKS clusters from Azure CLI and the Azure portal.

## Before you begin

To create an AKS cluster, ensure that you have the necessary details from your on-premises infrastructure administrator as described in [Create Kubernetes clusters](../aks-create-clusters-cli.md#before-you-begin).

## Azure CLI

Use the [az aksarc create](/cli/azure/aksarc#az-aksarc-create) command to create an AKS cluster with an SSH public key. To generate a new key, pass the `--generate-ssh-key` parameter. To use an existing public key, specify the key or key file using the `--ssh-key-value` parameter. To restrict SSH access to specific IP addresses, use the `--ssh-auth-ips` argument. For instructions, see [restrict SSH access to virtual machines](restrict-ssh-access.md).

| SSH parameter | Description |
|-------------------------|-------------------------|
| `--generate-ssh-key` | - Required parameter if no preexisting SSH key exists on your local machine. When you specify `--generate-ssh-key`, Azure CLI automatically generates a set of SSH keys and saves them in the default directory **~/.ssh/**.</br> - If you already have an SSH key on your local machine, the AKS cluster reuses that key. In this scenario, whether you specify `--generate-ssh-keys` or omit the parameter entirely, it has no effect. |
| `--ssh-key-value` | - Public key path or key contents for SSH access to node VMs. For example: **ssh-rsa AAAAB ... UcyupgH azureuser@linuxvm**.</br> - By default, this key is located in **~/.ssh/id_rsa.pub**. You can specify a different location using the `--ssh-key-value` parameter during cluster creation. |
| `--ssh-auth-ips` | A comma-separated list of IP addresses or CIDR ranges that are allowed to SSH into the cluster VM. |

The following examples show how to use this command:

- To create an AKS cluster and use the default generated SSH keys:

  ```azurecli
  az aksarc create -n $<aks_cluster_name> -g $<resource_group_name> --custom-location $<customlocation_ID> --vnet-ids $<logicnet>_Id --aad-admin-group-object-ids <entra-admin-group-object-ids> --generate-ssh-keys
  ```

- To create an AKS cluster using a pre-generated SSH key:

  1. Generate the SSH key. For more information, see [Generate and store SSH keys with the Azure CLI](/azure/virtual-machines/ssh-keys-azure-cli#generate-new-keys):

     ```azurecli
     az sshkey create --name "mySSHKey" --resource-group $<resource_group_name>
     ```

  1. Create an AKS cluster with a pre-generated SSH key:

     ```azurecli
     az aksarc create -n $<aks_cluster_name> -g $<resource_group_name> --custom-location $<customlocation_ID> --vnet-ids $<logicnet_Id> --aad-admin-group-object-ids <entra-admin-group-object-ids> --ssh-key-value $pubkey.publickey
     ```

- To specify an SSH public key file, include the `--ssh-key-value` parameter:

  ```azurecli
  az aksarc create -n $<aks_cluster_name> -g $<resource_group_name> --custom-location $<customlocation_ID> --vnet-ids $<logicnet_Id> --aad-admin-group-object-ids <entra-admin-group-object-ids> --generate-ssh-keys --ssh-key-value ~/.ssh/id_rsa.pub
  ```

## Azure portal

For information about how to create new SSH keys from the Azure portal, see [Create and manage SSH keys in the portal](/azure/virtual-machines/ssh-keys-portal#generate-new-keys).

When you create an AKS cluster using the Azure portal, provide the necessary information as described in [Create a Kubernetes cluster](../aks-create-clusters-portal.md#create-a-kubernetes-cluster). You can configure your SSH key in the **Administrator account** section under the **Basic** tab.

You have three options for SSH key configuration:

- Generate a new key pair.
- Use an existing key stored in Azure and select from the stored keys.
- Use an existing public key by providing the SSH public key value.

## Error messages

For information about error messages that can occur when you create and deploy an AKS cluster on Azure Local, see the [Control plane configuration validation errors](control-plane-validation-errors.md) article.

## Next steps

- [Connect to Windows or Linux worker nodes with SSH](ssh-connect-to-windows-and-linux-worker-nodes.md)
- [Restrict SSH access to specific IP addresses](restrict-ssh-access.md)
- [Get on-demand logs for troubleshooting](get-on-demand-logs.md)
- Help to protect your cluster in other ways by following the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).