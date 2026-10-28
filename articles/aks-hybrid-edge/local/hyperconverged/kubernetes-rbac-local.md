---
title: Control access using Microsoft Entra ID and Kubernetes RBAC in AKS Hybrid and Edge
description: Learn how to use Microsoft Entra group membership to restrict access to cluster resources using Kubernetes role-based access control (Kubernetes RBAC) in AKS.
author: davidsmatlak
ms.author: davidsmatlak 
ms.lastreviewed: 07/25/2025
ms.reviewer: leslielin
ms.topic: how-to
ms.custom: hyperconverged
  - devx-track-azurecli
ms.date: 09/01/2026

# Intent: As an IT Pro, I need to learn how to enable Kubernetes role-based access control so that I can manage access to resources.
# Keyword: Kubernetes role-based access control 
---

# Control access using Microsoft Entra ID and Kubernetes RBAC

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

You can configure Azure Kubernetes Service (AKS) to use Microsoft Entra ID for user authentication. In this configuration, you sign in to a Kubernetes cluster using a Microsoft Entra authentication token. Once authenticated, you can use the built-in Kubernetes role-based access control (Kubernetes RBAC) to manage access to namespaces and cluster resources based on a user's identity or group membership.

This article describes how to control access using Kubernetes RBAC in a Kubernetes cluster based on Microsoft Entra group membership in AKS. First, you create a demo group and users in Microsoft Entra ID. Then you create roles and role bindings in the cluster to grant the appropriate permissions to create and view resources.

## Prerequisites

Before you set up Kubernetes RBAC using Microsoft Entra ID, you must have the following prerequisites:

- An AKS cluster. If you need to set up your cluster, see the instructions for using the [Azure portal](../aks-create-clusters-portal.md) or [Azure CLI](../aks-create-clusters-cli.md).
- Azure CLI installed and configured. If you need to install CLI or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- Azure CLI and the **connectedk8s** extension. The Azure command-line interface (Azure CLI) is a set of commands used to create and manage Azure resources. To check whether you have the Azure CLI, open a command prompt and type `az -v`. Also, install the [connectedk8s extension](https://github.com/Azure/azure-cli-extensions/tree/main/src/connectedk8s) in order to open a channel to your Kubernetes cluster. For installation instructions, see [How to install the Azure CLI](/cli/azure/install-azure-cli).
- **Kubectl**. The Kubernetes command line tool, **kubectl**, enables you to run commands that target your Kubernetes clusters. To check whether you installed **kubectl**, open a command prompt and type `kubectl version --client`. Make sure your **kubectl** client version is at least **v1.24.0**. You can use the following Azure CLI or Azure PowerShell commands to install **kubectl**:

   # [Azure CLI](#tab/cli)

   Install kubectl locally using the [az aks install-cli](/cli/azure/aks?view=azure-cli-latest#az-aks-install-cli&preserve-view=true) command.

   # [PowerShell](#tab/powershell)

   Install kubectl locally using the [Install-AzAksCliTool](/powershell/module/az.aks/install-azaksclitool?view=azps-14.2.0&preserve-view=true) cmdlet.
- You can access your Kubernetes cluster with the specified permissions either with direct mode or proxy mode.
  - To access the Kubernetes cluster directly using the `az aksarc get-credentials` command, you need the **Microsoft.HybridContainerService/provisionedClusterInstances/listUserKubeconfig/action**, which is included in the **Azure Kubernetes Service Arc Cluster User** role permissions
  - To access the Kubernetes cluster from anywhere with a proxy mode using `az connectedk8s proxy` command, you need the **Microsoft.Kubernetes/connectedClusters/listClusterUserCredential/action**, which is included in **Azure Arc-enabled Kubernetes Cluster User** role permission. Meanwhile, you need to verify that the agents and the machine performing the onboarding process meet the network requirements in [Azure Arc-enabled Kubernetes network requirements](/azure/azure-arc/kubernetes/network-requirements?tabs=azure-cloud#details).

> [!NOTE]
> When you use **kubelogin version 2.0** and later with Microsoft Entra authentication and Kubernetes RBAC in AKS on Azure Local, you might encounter Entra authentication prompts for each command you run. For a solution to this known issue, see [Repeated Entra authentication prompts when running kubectl with Kubernetes RBAC](entra-prompts.md).

## Optional first steps

If you don't already have a Microsoft Entra group that contains members, you might want to create a group and add some members, so that you can follow the instructions in this article.

To demonstrate working with Microsoft Entra ID and Kubernetes RBAC, you can create a Microsoft Entra group for application developers that can be used to show how Kubernetes RBAC and Microsoft Entra ID control access to cluster resources. In production environments, you can use existing users and groups within a Microsoft Entra tenant.

### Create a demo group in Microsoft Entra ID

First, create the group in Microsoft Entra ID in your tenant for the application developers using the [`az ad group create`](/cli/azure/ad/group#az_ad_group_create) command. The following example prompts you to sign in to your Azure tenant and then creates a group named **appdev**:

```azurecli  
az login
az ad group create --display-name appdev --mail-nickname appdev
```

### Add users to your group

With the example group created in Microsoft Entra ID for application developers, add a user to the `appdev` group. You use this user account to sign in to the AKS cluster and test the Kubernetes RBAC integration.

Add a user to the **appdev** group created in the previous section using the [`az ad group member add`](/cli/azure/ad/group/member#az_ad_group_member_add) command. If you quit your session, reconnect to Azure using `az login`.

```azurecli  
$AKSDEV_ID = az ad user create --display-name <name> --password <strongpassword> --user-principal-name <name>@contoso.onmicrosoft.com
az ad group member add --group appdev --member-id $AKSDEV_ID
```

## Create a custom Kubernetes RBAC role binding on the AKS cluster resource for the Microsoft Entra group

Configure the AKS cluster to allow your Microsoft Entra group to access the cluster. If you want to add a group and users, see [Create demo groups in Microsoft Entra ID](#create-a-demo-group-in-microsoft-entra-id).

1. Use the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command to get the cluster admin credentials:

   ```azurecli
   az aksarc get-credentials --name "$aks_cluster_name" --resource-group "$resource_group_name" --admin
   ```

1. Create a namespace in the Kubernetes cluster using the [`kubectl create namespace`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create) command. The following example creates a namespace named `dev`:

   ```bash  
   kubectl create namespace dev
   ```

In Kubernetes, **Roles** define the permissions to grant, and **RoleBindings** apply the permissions to desired users or groups. These assignments can be applied to a given namespace or across an entire cluster. For more information, see [Using Kubernetes RBAC authorization](/azure/aks/concepts-identity#kubernetes-rbac).

Create a role for the **dev** namespace. This role grants full permissions to the namespace. In production environments, you might want to specify more granular permissions for different users or groups.

1. Create a file named **role-dev-namespace.yaml** and copy/paste the following YAML manifest:

   ```yaml
   kind: Role
   apiVersion: rbac.authorization.k8s.io/v1
   metadata:
     name: dev-user-full-access
     namespace: dev
   rules:
   - apiGroups: ["", "extensions", "apps"]
     resources: ["*"]
     verbs: ["*"]
   - apiGroups: ["batch"]
     resources:
     - jobs
     - cronjobs
     verbs: ["*"]
   ```

1. Create the role using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command, and specify the filename of your YAML manifest:

   ```bash
   kubectl apply -f role-dev-namespace.yaml
   ```

1. Get the resource ID for the **appdev** group using the [`az ad group show`](/cli/azure/ad/group#az_ad_group_show) command. This group is set as the subject of a RoleBinding in the next step:

   ```azurecli  
   az ad group show --group appdev --query objectId -o tsv
   ```

   The `az ad group show` command returns the value you use as `groupObjectId`:

   ```output  
   38E5FA30-XXXX-4895-9A00-050712E3673A
   ```

1. Create a file named **rolebinding-dev-namespace.yaml**, and copy/paste the following YAML manifest. You establish the role binding that enables the **appdev** group to use the `role-dev-namespace` role for namespace access. On the last line, replace `groupObjectId` with the group object ID produced by the `az ad group show` command:

   ```yaml
   kind: RoleBinding
   apiVersion: rbac.authorization.k8s.io/v1
   metadata:
     name: dev-user-access
     namespace: dev
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: Role
     name: dev-user-full-access
   subjects:
   - kind: Group
     namespace: dev
     name: groupObjectId
   ```

   > [!TIP]  
   > If you want to create the **RoleBinding** for a single user, specify `kind: User` and replace `groupObjectId` with the user principal name (UPN) in the example.

1. Create the **RoleBinding** using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command and specify the filename of your YAML manifest:

   ```bash  
   kubectl apply -f rolebinding-dev-namespace.yaml
   ```

   ```output  
   rolebinding.rbac.authorization.k8s.io/dev-user-access created
   ```

## Use built-in Kubernetes RBAC roles for your AKS cluster resource

Kubernetes also provides built-in user-facing roles. These built-in roles include:

- Super-user roles (cluster-admin)
- Roles intended to be granted cluster-wide using ClusterRoleBindings
- Roles intended to be granted within particular namespaces using RoleBindings (admin, edit, view)

For more information about built-in Kubernetes RBAC roles, see [Kubernetes RBAC user-facing roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles).

### User-facing roles

| Default ClusterRole | Default ClusterRoleBinding | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|---------------------|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| cluster-admin       | system:masters group       | Allows super-user access, to perform any action on any resource. When used in a **ClusterRoleBinding**, this role gives full control over every resource in the cluster and in all namespaces. When used in a **RoleBinding**, it gives full control over every resource in the role binding's namespace, including the namespace itself.                                                                                                                                                                                                  |
| admin               | None                       | Allows admin access, intended to be granted within a namespace using a role binding. If used in a role binding, allows read/write access to most resources in a namespace, including the capability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. This role also doesn't allow write access to endpoints in clusters created using Kubernetes v1.22+. For more information, see [Write Access for Endpoints](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#write-access-for-endpoints). |
| edit                | None                       | Allows read/write access to most objects in a namespace. This role doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing secrets and running pods as any ServiceAccount in the namespace, so it can be used to gain the API access levels of any ServiceAccount in the namespace. This role also doesn't allow write access to endpoints in clusters created using Kubernetes v1.22+. For more information, see [Write Access for Endpoints](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#write-access-for-endpoints).                |
| view                | None                       | Allows read-only access to see most objects in a namespace. It doesn't allow viewing roles or role bindings. This role doesn't allow viewing secrets, since reading the contents of secrets enables access to ServiceAccount credentials in the namespace, which would allow API access as any ServiceAccount in the namespace (a form of privilege escalation).                                                                                                                                                         |

### Use a built-in Kubernetes RBAC role with Microsoft Entra ID

To use a built-in Kubernetes RBAC role with Microsoft Entra ID, follow these steps:

1. Apply the built-in `view` Kubernetes RBAC role to your Microsoft Entra group:

   ```bash
   kubectl create clusterrolebinding <name of your cluster role binding> --clusterrole=view --group=<Azure AD group object ID>
   ```

1. Apply the built-in `view` Kubernetes RBAC role to each of your Microsoft Entra users:

   ```bash
   kubectl create clusterrolebinding <name of your cluster role binding> --clusterrole=view --user=<Azure AD user object ID>
   ```

## Access the Kubernetes cluster

You can now access your Kubernetes cluster with the specified permissions, using either direct mode or proxy mode.

### Access your cluster with kubectl (direct mode)

To access the Kubernetes cluster with the specified permissions, the Kubernetes operator needs the Microsoft Entra **kubeconfig**, which you can get using the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command. This command provides access to the admin-based kubeconfig, as well as a user-based kubeconfig. The admin-based kubeconfig file contains secrets and should be securely stored and rotated periodically. On the other hand, the user-based Microsoft Entra ID kubeconfig doesn't contain secrets and can be distributed to users who connect from their client machines.

To run this Azure CLI command, you need the **Microsoft.HybridContainerService/provisionedClusterInstances/listUserKubeconfig/action**, which is included in the **Azure Kubernetes Service Arc Cluster User** role permissions:

```azurecli
az aksarc get-credentials -g $resource_group_name -n $aks_cluster_name --file <file-name>
```

Now, you can use kubectl to manage your cluster. For example, you can list the nodes in your cluster using `kubectl get nodes`. The first time you run it, you must sign in, as shown in the following example:

```azurecli
kubectl get nodes
```

### Access your cluster from a client device (proxy mode)

To access the Kubernetes cluster from anywhere with a proxy mode using `az connectedk8s proxy` command, you need the **Microsoft.Kubernetes/connectedClusters/listClusterUserCredential/action**, which is included in the **Azure Arc-enabled Kubernetes Cluster User** role permission.

Run the following steps on another client device:

1. Sign in using Microsoft Entra authentication.

1. Get the cluster connect `kubeconfig` needed to communicate with the cluster from anywhere (from even outside the firewall surrounding the cluster):

     ```azurecli
     az connectedk8s proxy -n $aks_cluster_name -g $resource_group_name
     ```

     > [!NOTE]
     > This command opens the proxy and blocks the current shell.

1. In a different shell session, use `kubectl` to send requests to the cluster:

   ```powershell
   kubectl get pods -A
   ```

You should now see a response from the cluster containing the list of all pods under the `default` namespace.

For more information, see [Access your cluster from a client device](/azure/azure-arc/kubernetes/cluster-connect?tabs=azure-cli%2Cagent-version#access-your-cluster-from-a-client-device)

### Create and view cluster resources outside the assigned namespace

To attempt to view pods outside the **dev** namespace, use the [`kubectl get pods`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command with the `--all-namespaces` flag:

```bash  
kubectl get pods --all-namespaces
```

The user's group membership doesn't have a Kubernetes role that allows this action. Without the permission, the command generates an error:

```output  
Error from server (Forbidden): pods is forbidden: User cannot list resource "pods" in API group "" at the cluster scope
```

## Next steps

- [Azure role-based access control (Azure RBAC)](/azure/role-based-access-control/overview)
- Help to protect your cluster in other ways by following the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).
