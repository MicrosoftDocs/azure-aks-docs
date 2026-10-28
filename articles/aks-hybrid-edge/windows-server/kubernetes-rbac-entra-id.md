---
title: Control access using Microsoft Entra ID and Kubernetes RBAC for Windows Server
description: Learn how to use Microsoft Entra group membership to restrict access to cluster resources using Kubernetes role-based access control (Kubernetes RBAC) for Windows Server
author: davidsmatlak
ms.author: davidsmatlak
ms.lastreviewed: 05/29/2024
ms.reviewer: srikantsarwa
ms.topic: how-to
ms.custom: windows-server
  - devx-track-azurecli
ms.date: 09/01/2026

# Intent: As an IT Pro, I need to learn how to enable Kubernetes role-based access control so that I can manage access to resources.
# Keyword: Kubernetes role-based access control
---

# Control access using Microsoft Entra ID and Kubernetes RBAC for Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Azure Kubernetes Service (AKS) can be configured to use Microsoft Entra ID for user authentication. In this configuration, you sign in to a Kubernetes cluster using a Microsoft Entra authentication token. Once authenticated, you can use the built-in Kubernetes role-based access control (Kubernetes RBAC) to manage access to namespaces and cluster resources based on a user's identity or group membership.

This article describes how to control access using Kubernetes RBAC in a Kubernetes cluster based on Microsoft Entra group membership in AKS. You create a demo group and users in Microsoft Entra ID. Then, you create roles and role bindings in the cluster to grant the appropriate permissions to create and view resources.

## Prerequisites

Before you set up Kubernetes RBAC using Microsoft Entra ID, you need the following prerequisites:

- **A Kubernetes cluster created in AKS**. If you need to set up your cluster, see the instructions for using [Windows Admin Center](setup.md) or [PowerShell](kubernetes-walkthrough-powershell.md) to deploy AKS.
- **Azure Arc connection**. You must have an Azure Arc connection to your Kubernetes cluster. For information about enabling Azure Arc, see [Connect an Azure Kubernetes Service on Windows Server cluster to Azure Arc-enabled Kubernetes](connect-to-arc.md).
- You need access to the following command-line tools:
  - **Azure CLI and the connectedk8s extension**. Azure CLI is a set of commands used to create and manage Azure resources. To check whether you have the Azure CLI, open a command line tool, and type: `az -v`. Also, install the [connectedk8s extension](https://github.com/Azure/azure-cli-extensions/tree/main/src/connectedk8s) in order to open a channel to your Kubernetes cluster. For installation instructions, see [How to install Azure CLI](/cli/azure/install-azure-cli).
  - **Kubectl**. This Kubernetes command-line tool enables you to run commands targeting your Kubernetes clusters. To check whether you installed kubectl, open a command prompt and type: `kubectl version --client`. Make sure your kubectl client version is at least version v1.24.0. For installation instructions, see [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl).
  - **PowerShell and the AksHci PowerShell module**. PowerShell is a cross-platform task automation solution comprised of a command-line shell, a scripting language, and a configuration management framework. If you installed AKS, you have access to the **AksHci** PowerShell module.
  - To access the Kubernetes cluster from anywhere with a proxy mode using `az connectedk8s proxy` command, you need the **Microsoft.Kubernetes/connectedClusters/listClusterUserCredential/action**, which is included in the **Azure Arc-enabled Kubernetes Cluster User** role permission. Meanwhile, you need to verify that the agents and the machine performing the onboarding process meet the network requirements in [Azure Arc-enabled Kubernetes network requirements](/azure/azure-arc/kubernetes/network-requirements?tabs=azure-cloud#details).


## Optional first steps

If you don't already have a Microsoft Entra group that contains members, you might want to create a group and add some members, so that you can follow the instructions in this article.

To demonstrate working with Microsoft Entra ID and Kubernetes RBAC, you can create a Microsoft Entra group for application developers that can be used to show how Kubernetes RBAC and Microsoft Entra ID control access to cluster resources. In production environments, you can use existing users and groups within a Microsoft Entra tenant.

### Create a demo group in Microsoft Entra ID

First, create the group in Microsoft Entra ID in your tenant for the application developers using the [`az ad group create`](/cli/azure/ad/group#az_ad_group_create) command. The following example prompts you to sign into your Azure tenant and then creates a group named **appdev**:

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

1. Get the cluster admin credentials using the [`Get-AksHciCredential`](/azure/aks/aksarc/reference/ps/get-akshcicredential) command:

   ```powershell
   Get-AksHciCredential -name <name-of-your-cluster>
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

    ```powershell
    kubectl apply -f role-dev-namespace.yaml
    ```

1. Get the resource ID for the **appdev** group using the [`az ad group show`](/cli/azure/ad/group#az_ad_group_show) command. This group is set as the subject of a RoleBinding in the next step:

    ```azurecli
    az ad group show --group appdev --query objectId -o tsv
    ```

    The `az ad group show` command returns the value you use as the `groupObjectId`:

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
    > If you want to create the **RoleBinding** for a single user, specify `kind: User` and replace `groupObjectId` with the user principal name (UPN) in the sample.

1. Create the **RoleBinding** using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command and specify the filename of your YAML manifest:

    ```powershell
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

## Work with cluster resources using Microsoft Entra IDs

Now, test the expected permissions when you create and manage resources in a Kubernetes cluster. In these examples, you schedule and view pods in the user's assigned namespace. Then, you try to schedule and view pods outside the assigned namespace.

1. Sign in to Azure using the `$AKSDEV_ID` user account that you specified as an input to the `az ad group member add` command. Run the `az connectedk8s proxy` command to open a channel to the cluster:

   ```azurecli
   az connectedk8s proxy -n <cluster-name> -g <resource-group>
   ```

1. After the proxy channel is established, open another session, and schedule an NGINX pod using the [`kubectl run`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#run) command in the **dev** namespace:

   ```bash
   kubectl run nginx-dev --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace dev
   ```

   When NGINX is successfully scheduled, you should see the following output:

   ```output
   pod/nginx-dev created
   ```

1. Now, use the [`kubectl get pods`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command to view pods in the `dev` namespace:

   ```bash
   kubectl get pods --namespace dev
   ```

   When NGINX is successfully running, you should see the following output:

    ```output
    NAME        READY   STATUS    RESTARTS   AGE
    nginx-dev   1/1     Running   0          4m
    ```

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

- [Learn more about security in AKS on Windows Server](concepts-security.md)
- To help protect your cluster, see the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).
