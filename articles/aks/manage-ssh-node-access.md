---
title: Manage SSH access on Azure Kubernetes Service cluster nodes 
titleSuffix: Azure Kubernetes Service
description: Learn how to configure SSH and manage SSH keys on Azure Kubernetes Service (AKS) cluster nodes.
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli
ms.date: 11/10/2025
author: shashankbarsin
ms.author: shasb
zone_pivot_groups: aks-ssh-access-type

# Customer intent: As a Kubernetes administrator, I want to manage SSH keys and access for AKS cluster nodes, so that I can enhance security and control access to the nodes effectively.
---

# Manage SSH for secure access to Azure Kubernetes Service (AKS) nodes

This article describes how to configure SSH access (preview) on your AKS clusters or node pools, during initial deployment or at a later time.

AKS supports the following configuration options to manage SSH access on cluster nodes:

* **Disabled SSH**: Completely disable SSH access to cluster nodes for enhanced security
* **Entra ID based SSH**: Use Microsoft Entra ID credentials for SSH authentication. Benefits of using Entra ID based SSH:
    * **Centralized identity management**: Use your existing Entra ID identities to access cluster nodes
    * **No SSH key management**: Eliminates the need to generate, distribute, and rotate SSH keys
    * **Enhanced security**: Leverage Entra ID security features like Conditional Access and MFA
    * **Audit and compliance**: Centralized logging of access events through Entra ID logs
    * **Just-in-time access**: Combine with Azure RBAC for granular access control
* **Local User SSH**: Traditional SSH key-based authentication for node access

::: zone pivot="disabled-ssh"

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

::: zone-end

::: zone pivot="entraid-ssh"

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

::: zone-end

## Prerequisites

::: zone pivot="disabled-ssh"

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
- This article requires version 2.61.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- You need `aks-preview` version 9.0.0b1 or later.
    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command:
        ```azurecli-interactive
        az extension add --name aks-preview
        ```
    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command:
        ```azurecli-interactive
        az extension update --name aks-preview
        ```
- Register the `DisableSSHPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "DisableSSHPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

- Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "DisableSSHPreview"
    ```

- When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

::: zone-end

::: zone pivot="entraid-ssh"

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
- This article requires version 2.73.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- You need `aks-preview` version 19.0.0b7 or later for Entra ID SSH.
    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command:
        ```azurecli-interactive
        az extension add --name aks-preview
        ```
    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command:
        ```azurecli-interactive
        az extension update --name aks-preview
        ```
- Appropriate Azure RBAC permissions to access nodes:
    - **Required action**: `Microsoft.Compute/virtualMachineScaleSets/*/read` - to read VM scale set information
        - **Required data action**: 
            - `Microsoft.Compute/virtualMachineScaleSets/virtualMachines/login/action` - to authenticate and log in to VMs as regular user.
            - `Microsoft.Compute/virtualMachines/loginAsAdmin/action` - to login with root user privileges.
        - **Built-in role**: [**Virtual Machine Administrator Login**][vm-admin-login] or [**Virtual Machine User Login**][vm-user-login] (for non-admin access)
- Register the `EntraIdSSHPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "EntraIdSSHPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

- Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EntraIdSSHPreview"
    ```

- When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

::: zone-end

::: zone pivot="local-user-ssh"

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
- This article requires version 2.61.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- You need `aks-preview` version 9.0.0b1 or later to update SSH access method on nodepools.
    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command:
        ```azurecli-interactive
        az extension add --name aks-preview
        ```
    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command:
        ```azurecli-interactive
        az extension update --name aks-preview
        ```

::: zone-end

### Set environment variables

Set the following environment variables for your resource group, cluster name, and location:

```bash
export RESOURCE_GROUP="<your-resource-group-name>"
export CLUSTER_NAME="<your-cluster-name>"
export LOCATION="<your-azure-region>"
```

::: zone pivot="entraid-ssh"

## Limitations

- Entra ID SSH to nodes is not yet available for Windows node pool.
- Entra ID SSH to nodes is not supported for AKS automatic because of [node resource group lockdown][nrg-lockdown] preventing role assignments.

::: zone-end

## Configure SSH access

::: zone pivot="disabled-ssh"

To improve security and support your corporate security requirements or strategy, AKS supports disabling SSH both on the cluster and at the node pool level. Disable SSH introduces a simplified approach compared to configuring [network security group rules][network-security-group-rules-overview] on the AKS subnet/node network interface card (NIC). Disable SSH only supports Virtual Machine Scale Sets node pools.

When you disable SSH at cluster creation time, it takes effect after the cluster is created. However, when you disable SSH on an existing cluster or node pool, AKS doesn't automatically disable SSH. At any time, you can choose to perform a nodepool upgrade operation. The disable/enable SSH operation takes effect after the node image update is complete.

> [!NOTE]
> When you disable SSH at the cluster level, it applies to all existing node pools. Any node pools created after this operation will have SSH enabled by default, and you'll need to run these commands again in order to disable it.

>[!NOTE]
>[kubectl debug node][kubelet-debug-node-access] continues to work after you disable SSH because it doesn't depend on the SSH service.

### Create a resource group

Create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Disable SSH on a new cluster deployment

By default, the SSH service on AKS cluster nodes is open to all users and pods running on the cluster. You can prevent direct SSH access from any network to cluster nodes to help limit the attack vector if a container in a pod becomes compromised.

Use the [`az aks create`][az-aks-create] command to create a new cluster, and include the `--ssh-access disabled` argument to disable SSH (preview) on all the node pools during cluster creation.

> [!IMPORTANT]
> After you disable the SSH service, you can't SSH into the cluster to perform administrative tasks or to troubleshoot.

>[!NOTE]
>On a newly created cluster, disable SSH will only configure the first system node pool. All other node pools need to be configured at the node pool level.

```azurecli-interactive
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --ssh-access disabled
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster. The following example resembles the output and the results related to disabling SSH:

```json
"securityProfile": {
  "sshAccess": "Disabled"
},
```

### Disable SSH for a new node pool

Use the [`az aks nodepool add`][az-aks-nodepool-add] command to add a node pool, and include the `--ssh-access disabled` argument to disable SSH during node pool creation.

```azurecli-interactive
az aks nodepool add \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access disabled
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster indicating *mynodepool* was successfully created. The following example resembles the output and the results related to disabling SSH:

```json
"securityProfile": {
  "sshAccess": "Disabled"
},
```

### Disable SSH for an existing node pool

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--ssh-access disabled` argument to disable SSH (preview) on an existing node pool.

```azurecli-interactive
az aks nodepool update \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access disabled
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster indicating *mynodepool* was successfully updated. The following example resembles the output and the results related to disabling SSH:

```json
"securityProfile": {
  "sshAccess": "Disabled"
},
```

For the change to take effect, you need to reimage the node pool by using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command.

```azurecli-interactive
az aks nodepool upgrade \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --node-image-only
```

> [!IMPORTANT]
> To disable SSH on an existing cluster, you need to disable SSH for each node pool on this cluster.

### Re-enable SSH access

To re-enable SSH access on a node pool, update the node pool with either `--ssh-access localuser` (for traditional SSH key-based access) or `--ssh-access entraid` (for Entra ID based access). See the respective sections for detailed instructions.

::: zone-end

::: zone pivot="entraid-ssh"

You can configure your AKS cluster to use Microsoft Entra ID (formerly Azure AD) for SSH authentication to cluster nodes. This eliminates the need to manage SSH keys and allows you to use your Entra ID credentials to access nodes securely.

### Create a resource group

Create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Enable Entra ID based SSH on a new cluster

Use the [`az aks create`][az-aks-create] command with the `--ssh-access entraid` argument to enable Entra ID based SSH authentication during cluster creation.

```azurecli-interactive
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --ssh-access entraid
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster. The following example resembles the output:

```json
"securityProfile": {
  "sshAccess": "EntraID"
},
```

### Enable Entra ID based SSH for a new node pool

Use the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--ssh-access entraid` argument to enable Entra ID based SSH during node pool creation.

```azurecli-interactive
az aks nodepool add \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access entraid
```

After a few minutes, the command completes and returns JSON-formatted information indicating *mynodepool* was successfully created with Entra ID based SSH. The following example resembles the output:

```json
"securityProfile": {
  "sshAccess": "EntraID"
},
```

### Enable Entra ID based SSH for an existing node pool

Use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--ssh-access entraid` argument to enable Entra ID based SSH on an existing node pool.

```azurecli-interactive
az aks nodepool update \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access entraid
```

After a few minutes, the command completes and returns JSON-formatted information indicating *mynodepool* was successfully updated with Entra ID based SSH. The following example resembles the output:

```json
"securityProfile": {
  "sshAccess": "EntraID"
},
```

For the change to take effect, you need to reimage the node pool by using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command.

```azurecli-interactive
az aks nodepool upgrade \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --node-image-only
```

> [!IMPORTANT]
> To enable Entra ID based SSH on an existing cluster, you need to enable it for each node pool individually.

::: zone-end

::: zone pivot="local-user-ssh"

Local user SSH access uses traditional SSH key-based authentication. This is the default SSH access method for AKS clusters.

### Create a resource group

Create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Create an AKS cluster with SSH keys

Use the [az aks create][az-aks-create] command to deploy an AKS cluster with an SSH public key. You can either specify the key or a key file using the `--ssh-key-value` argument, or use `--ssh-access localuser` to explicitly set local user SSH access.

|SSH parameter |Description |Default value |
|-----|-----|-----|
|`--generate-ssh-key` |If you don't have your own SSH keys, specify `--generate-ssh-key`. The Azure CLI automatically generates a set of SSH keys and saves them in the default directory `~/.ssh/`.||
|`--ssh-key-value` |Public key path or key contents to install on node VMs for SSH access. For example, `ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm`.|`~/.ssh/id_rsa.pub` |
|`--ssh-access localuser` |Explicitly enable local user SSH access with key-based authentication.||
|`--no-ssh-key` | If you don't require SSH keys, specify this argument. However, AKS automatically generates a set of SSH keys because the Azure Virtual Machine resource dependency doesn't support an empty SSH keys file. As a result, the keys aren't returned and can't be used to SSH into the node VMs. The private key is discarded and not saved.||

>[!NOTE]
>If no parameters are specified, the Azure CLI defaults to referencing the SSH keys stored in the `~/.ssh/id_rsa.pub` file. If the keys aren't found, the command returns the message `An RSA key file or key value must be supplied to SSH Key Value`.

**Examples:**

* To create a cluster and use the default generated SSH keys:

    ```azurecli-interactive
    az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --generate-ssh-key
    ```

* To specify an SSH public key file:

    ```azurecli-interactive
    az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --ssh-key-value ~/.ssh/id_rsa.pub
    ```

* To explicitly enable local user SSH access:

    ```azurecli-interactive
    az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --ssh-access localuser --generate-ssh-key
    ```

### Enable local user SSH for a new node pool

Use the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--ssh-access localuser` argument to enable local user SSH during node pool creation.

```azurecli-interactive
az aks nodepool add \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access localuser
```

### Enable local user SSH for an existing node pool

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--ssh-access localuser` argument to enable local user SSH on an existing node pool.

```azurecli-interactive
az aks nodepool update \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --ssh-access localuser
```
> [!IMPORTANT]
> For the change to take effect, you need to reimage the node pool by using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command.

```azurecli-interactive
az aks nodepool upgrade \
    --cluster-name $CLUSTER_NAME \
    --name mynodepool \
    --resource-group $RESOURCE_GROUP \
    --node-image-only
```

### Update SSH public key on an existing AKS cluster

Use the [`az aks update`][az-aks-update] command to update the SSH public key (preview) on your cluster. This operation updates the key on all node pools. You can either specify a key or a key file using the `--ssh-key-value` argument.

> [!NOTE]
> Updating the SSH keys is supported on Azure virtual machine scale sets with AKS clusters.

**Examples:**

* To specify a new SSH public key value:

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --ssh-key-value 'ssh-rsa AAAAB3Nza-xxx'
    ```

* To specify an SSH public key file:

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --ssh-key-value ~/.ssh/id_rsa.pub
    ```

> [!IMPORTANT]
> After you update the SSH key, AKS doesn't automatically update your node pool. At any time, you can choose to perform a [nodepool upgrade operation][node-image-upgrade]. The update SSH keys operation takes effect after a node image update is complete. For clusters with [Node Auto-provisioning][node auto-provisioning] enabled, a node image update can be performed by applying a new label to the Kubernetes NodePool custom resource.

::: zone-end

## SSH service status

#### [Node-shell](#tab/node-shell)

Perform the following steps to use node-shell onto one node and inspect SSH service status using `systemctl`.

1. Get standard bash shell by running the command `kubectl node-shell <node>` command.

    ```bash
    kubectl node-shell aks-nodepool1-20785627-vmss000001
    ```

2. Run the `systemctl` command to check the status of the SSH service.

    ```bash
    systemctl status ssh
    ```

If SSH is disabled, the following sample output shows the results:

```output
ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; disabled; vendor preset: enabled)
     Active: inactive (dead) since Wed 2024-01-03 15:36:57 UTC; 20min ago
```

If SSH is enabled, the following sample output shows the results:

```output
ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2024-01-03 15:40:20 UTC; 19min ago
```

#### [Using run-command](#tab/run-command)

If node-shell isn't available, you can use the Virtual Machine Scale Set [`az vmss run-command invoke`][run-command-invoke] to check SSH service status.

```azurecli-interactive
az vmss run-command invoke --resource-group myResourceGroup --name myVMSS --command-id RunShellScript --instance-id 0 --scripts "systemctl status ssh"
```

The following sample output shows the json message returned:

```json
{
  "value": [
    {
      "code": "ProvisioningState/succeeded",
      "displayStatus": "Provisioning succeeded",
      "level": "Info",
      "message": "Enable succeeded: \n[stdout]\n○ ssh.service - OpenBSD Secure Shell server\n     Loaded: loaded (/lib/systemd/system/ssh.service; disabled; vendor preset: enabled)\n     Active: inactive (dead) since Wed 2024-01-03 15:36:53 UTC; 25min ago\n       Docs: man:sshd(8)\n             man:sshd_config(5)\n   Main PID: 827 (code=exited, status=0/SUCCESS)\n        CPU: 22ms\n\nJan 03 15:36:44 aks-nodepool1-20785627-vmss000000 systemd[1]: Starting OpenBSD Secure Shell server...\nJan 03 15:36:44 aks-nodepool1-20785627-vmss000000 sshd[827]: Server listening on 0.0.0.0 port 22.\nJan 03 15:36:44 aks-nodepool1-20785627-vmss000000 sshd[827]: Server listening on :: port 22.\nJan 03 15:36:44 aks-nodepool1-20785627-vmss000000 systemd[1]: Started OpenBSD Secure Shell server.\nJan 03 15:36:53 aks-nodepool1-20785627-vmss000000 systemd[1]: Stopping OpenBSD Secure Shell server...\nJan 03 15:36:53 aks-nodepool1-20785627-vmss000000 sshd[827]: Received signal 15; terminating.\nJan 03 15:36:53 aks-nodepool1-20785627-vmss000000 systemd[1]: ssh.service: Deactivated successfully.\nJan 03 15:36:53 aks-nodepool1-20785627-vmss000000 systemd[1]: Stopped OpenBSD Secure Shell server.\n\n[stderr]\n",
      "time": null
    }
  ]
}
```

Search for the word **Active** and its value should be `Active: inactive (dead)`, which indicates SSH is disabled on the node.

---

## Next steps

To help troubleshoot any issues with SSH connectivity to your clusters nodes, you can [view the kubelet logs][view-kubelet-logs] or [view the Kubernetes master node logs][view-master-logs].

<!-- LINKS - internal -->
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[view-kubelet-logs]: kubelet-logs.md
[view-master-logs]: monitor-aks-reference.md#resource-logs
[node-image-upgrade]: node-image-upgrade.md
[node auto-provisioning]: node-autoprovision.md
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az-aks-nodepool-upgrade
[network-security-group-rules-overview]: concepts-security.md#azure-network-security-groups
[kubelet-debug-node-access]: node-access.md
[run-command-invoke]: /cli/azure/vmss/run-command#az-vmss-run-command-invoke
[vm-admin-login]: /azure/role-based-access-control/built-in-roles#virtual-machine-administrator-login
[vm-user-login]: /azure/role-based-access-control/built-in-roles#virtual-machine-user-login
[nrg-lockdown]: node-resource-group-lockdown.md