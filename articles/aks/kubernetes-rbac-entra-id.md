---
title: Use Microsoft Entra ID and Kubernetes RBAC for clusters
titleSuffix: Azure Kubernetes Service
description: Learn how to use Microsoft Entra group membership to restrict access to cluster resources using Kubernetes role-based access control (Kubernetes RBAC) in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.author: shasb
author: shashankbarsin
ms.subservice: aks-integration
ms.custom: devx-track-azurecli, devx-track-terraform, annual
ms.date: 08/31/2026
zone_pivot_groups: azure-cli-or-terraform
# Customer intent: "As a Kubernetes administrator, I want to configure role-based access control using Microsoft Entra group membership, so that I can restrict cluster resource access based on user identities and enhance security in my Azure Kubernetes Service environment."
---

# Use Kubernetes RBAC with Microsoft Entra ID in AKS

Azure Kubernetes Service (AKS) can be configured to use Microsoft Entra ID for user authentication. In this configuration, you sign in to an AKS cluster using a Microsoft Entra authentication token. Once authenticated, you can use the built-in Kubernetes role-based access control (RBAC) to manage access to namespaces and cluster resources based on a user's identity or group membership.

This article shows you how to:

* Control access using Kubernetes RBAC in an AKS cluster based on Microsoft Entra group membership.

* Create example groups and users in Microsoft Entra ID.

* Create Roles and RoleBindings in an AKS cluster granting the appropriate permissions, such as to create and view resources.

## Prerequisites

* You have an existing AKS cluster with Microsoft Entra integration enabled. If you need an AKS cluster with this configuration, see [Integrate Microsoft Entra ID with AKS][azure-ad-aks-cli].

* Kubernetes RBAC is enabled by default during AKS cluster creation. To upgrade an existing cluster with Microsoft Entra integration and Kubernetes RBAC, see [Enable Microsoft Entra integration on your existing AKS cluster][enable-azure-ad-integration-existing-cluster].

* Make sure that Azure CLI version 2.0.61 or later is installed and configured. To find the version, run `az --version`. To install or upgrade, see [Install Azure CLI][install-azure-cli].

Use the Azure portal or Azure CLI to verify Microsoft Entra integration with Kubernetes RBAC is enabled.

# [Azure portal](#tab/portal)

To verify using the Azure portal:

1. Sign-in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. In the service menu, under **Settings**, select **Security configuration**.
1. Under the **Authentication and Authorization** section, verify the **Microsoft Entra authentication with Kubernetes RBAC** option is selected.

# [Azure CLI](#tab/azure-cli)

You can verify using the Azure CLI `az aks show` command. Replace the value *myResourceGroup* with the resource group name hosting your AKS cluster resource, and replace *myAKSCluster* with the actual name of your AKS cluster.

```azurecli
az aks show --resource-group myResourceGroup --name myAKSCluster
```

If you're using Microsoft Entra authentication with Kubernetes RBAC (and not Azure RBAC), the output value for `enableAzureRbac` is `false`.

---

:::zone pivot="terraform"

If you plan to use Terraform to configure Kubernetes RBAC for this article, you also need:

* [Terraform][terraform-on-azure] version 1.6.0 or later installed.
* [kubectl][kubectl-overview] installed and configured to connect to your AKS cluster. `kubectl` is automatically installed when you run `az aks install-cli` or as part of the [Azure Cloud Shell](https://shell.azure.com).
* Permission to create Azure role assignments at the scope of your AKS cluster, and permission to manage Kubernetes resources on the cluster.
* Two existing Microsoft Entra groups and, optionally, two existing Microsoft Entra test users to validate access with. If you don't have these resources yet, complete [Create groups in Microsoft Entra ID](#create-groups-in-microsoft-entra-id) and [Create users in Microsoft Entra ID](#create-users-in-microsoft-entra-id) before continuing. However, skip the `az role assignment create` command in that section, since the Terraform configuration in this article creates the role assignments for you.

> [!NOTE]
> If you don't already have an AKS cluster with Microsoft Entra integration and Kubernetes RBAC enabled to test with, this article's Terraform sample includes a `prequisite` configuration that creates one for you. For more information, see [Deploy the prerequisite AKS cluster with Terraform](#deploy-the-prerequisite-aks-cluster-with-terraform).

:::zone-end

<a name='create-demo-groups-in-azure-ad'></a>

## Create groups in Microsoft Entra ID

This section teaches you how to create two user roles to show how Kubernetes RBAC and Microsoft Entra ID control access cluster resources. The following two example roles are:

* **Application developer**
  * A user named *aksdev* that's part of the *appdev* group.

* **Site reliability engineer** (SRE)
  * A user named *akssre* that's part of the *opssre* group.

In production environments, you can use existing users and groups within a Microsoft Entra tenant.

# [App Dev](#tab/appdev)

1. First, get the resource ID of your AKS cluster using the [`az aks show`][az-aks-show] command. Then, assign the resource ID to a variable named *AKS_ID* so it can be referenced in other commands.

   ```azurecli-interactive
   AKS_ID=$(az aks show \
       --resource-group myResourceGroup \
       --name myAKSCluster \
       --query id -o tsv)
   ```

1. Create the first example group in Microsoft Entra ID for the application developers using the [`az ad group create`][az-ad-group-create] command. The following example creates a group named *appdev*:

   ```azurecli-interactive
   APPDEV_ID=$(az ad group create --display-name appdev --mail-nickname appdev --query id -o tsv)
   ```

1. Create an Azure role assignment for the *appdev* group using the [`az role assignment create`][az-role-assignment-create] command. This assignment lets any member of the group use `kubectl` to interact with an AKS cluster by granting them the *Azure Kubernetes Service Cluster User* Role.

   :::zone pivot="azure-cli"

   ```azurecli-interactive
   az role assignment create \
     --assignee $APPDEV_ID \
     --role "Azure Kubernetes Service Cluster User Role" \
     --scope $AKS_ID
   ```

   > [!IMPORTANT]
   > The role name you specify must exactly match the Azure role definition name, including capitalization and spacing.

   > [!TIP]
   > If you receive an error such as `Principal 35bfec9328bd4d8d9b54dea6dac57b82 doesn't exist in the directory a5443dcd-cd0e-494d-a387-3039b419f0d5.`, wait a few seconds for the Microsoft Entra group object ID to propagate through the directory then try the `az role assignment create` command again.

   :::zone-end

   :::zone pivot="terraform"

   Skip this command. The Terraform configuration in [Deploy Kubernetes RBAC with Terraform](#deploy-kubernetes-rbac-with-terraform) creates this role assignment for you.

   :::zone-end

# [SRE](#tab/sre)

1. Create an example group for SREs named *opssre*.

   ```azurecli-interactive
   OPSSRE_ID=$(az ad group create --display-name opssre --mail-nickname opssre --query id -o tsv)
   ```

1. Create an Azure role assignment to grant members of the group the **Azure Kubernetes Service Cluster User** Role.

   :::zone pivot="azure-cli"

   ```azurecli-interactive
   az role assignment create \
     --assignee $OPSSRE_ID \
     --role "Azure Kubernetes Service Cluster User Role" \
     --scope $AKS_ID
   ```

   :::zone-end

   :::zone pivot="terraform"

   Skip this command. The Terraform configuration in [Deploy Kubernetes RBAC with Terraform](#deploy-kubernetes-rbac-with-terraform) creates this role assignment for you.

   :::zone-end

---

<a name='create-demo-users-in-azure-ad'></a>

## Create users in Microsoft Entra ID

After you create the example Microsoft Entra ID groups for application developers and SREs, the next step is to create two corresponding user accounts. These users are used to sign in to the AKS cluster and validate the Kubernetes RBAC integration described later in this article.

Before you begin, you must set the user principal name (UPN) and password for the application developers. The UPN must include the verified domain name of your tenant. For example, an application developer user, `aksdev@contoso.com`. In order to figure out (or set) the verified domain names in your tenant, see [Managing custom domain names in your Microsoft Entra ID](/entra/identity/users/domains-manage).

The following command prompts you for the UPN and sets it to *AAD_DEV_UPN* so it can be used in a later command:

```azurecli-interactive
echo "Please enter the UPN for application developers: " && read AAD_DEV_UPN
```

The following command prompts you for the password and sets it to *AAD_DEV_PW* for use in a later command:

```azurecli-interactive
echo "Please enter the secure password for application developers: " && read AAD_DEV_PW
```

### Create user accounts

# [App Dev](#tab/appdev)

1. Create the first user account in Microsoft Entra ID using the [`az ad user create`][az-ad-user-create] command. The following example creates a user with the display name *AKS Dev*, the UPN, and secure password using the values in *AAD_DEV_UPN* and *AAD_DEV_PW*:

   ```azurecli-interactive
   AKSDEV_ID=$(az ad user create \
     --display-name "AKS Dev" \
     --user-principal-name $AAD_DEV_UPN \
     --password $AAD_DEV_PW \
     --query id -o tsv)
   ```

1. Add the user to the *appdev* group created in the previous section using the [`az ad group member add`][az-ad-group-member-add] command:

   ```azurecli-interactive
   az ad group member add --group appdev --member-id $AKSDEV_ID
   ```

# [SRE](#tab/sre)

1. Set the UPN and password for SREs. The UPN must include the verified domain name of your tenant. For example, an SRE user, `akssre@contoso.com`. The following command prompts you for the UPN and sets it to *AAD_SRE_UPN* for use in a later command:

   ```azurecli-interactive
   echo "Please enter the UPN for SREs: " && read AAD_SRE_UPN
   ```

1. The following command prompts you for the password and sets it to *AAD_SRE_PW* for use in a later command:

   ```azurecli-interactive
   echo "Please enter the secure password for SREs: " && read AAD_SRE_PW
   ```

1. Create a second user account. The following example creates a user with the display name *AKS SRE* and the UPN and secure password using the values in *AAD_SRE_UPN* and *AAD_SRE_PW*:

   ```azurecli-interactive
   # Create a user for the SRE role
   AKSSRE_ID=$(az ad user create \
     --display-name "AKS SRE" \
     --user-principal-name $AAD_SRE_UPN \
     --password $AAD_SRE_PW \
     --query id -o tsv)

   # Add the user to the opssre Entra ID group
   az ad group member add --group opssre --member-id $AKSSRE_ID
   ```

---

## Create AKS cluster resources

We have our Microsoft Entra groups, users, and Azure role assignments created. Now, you configure the AKS cluster to allow these different groups access to specific resources.

:::zone pivot="azure-cli"

# [App Dev](#tab/appdev)

1. Get the cluster admin credentials using the [`az aks get-credentials`][az-aks-get-credentials] command. In one of the following sections, you get the regular *user* cluster credentials to see the Microsoft Entra authentication flow in action.

   ```azurecli-interactive
   az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --admin
   ```

1. Create a namespace in the AKS cluster using the [`kubectl create namespace`][kubectl-create] command. The following example creates a namespace name *dev*:

   ```console
   kubectl create namespace dev
   ```

   > [!NOTE]
   > In Kubernetes, *Roles* define the permissions to grant, and *RoleBindings* apply them to desired users or groups. These assignments can be applied to a given namespace, or across the entire cluster. For more information, see [Using Kubernetes RBAC authorization][rbac-authorization].
   >
   > If the user you grant the Kubernetes RBAC binding for is in the same Microsoft Entra tenant, assign permissions based on the **UPN**. If the user is in a different Microsoft Entra tenant, query for and use the *objectId* property instead.

1. Create a Role for the *dev* namespace, which grants full permissions to the namespace. In production environments, you can specify more granular permissions for different users or groups. Create a file named `role-dev-namespace.yaml` and paste the following YAML manifest:

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

1. Create the Role using the [`kubectl apply`][kubectl-apply] command and specify the filename of your YAML manifest.

   ```console
   kubectl apply -f role-dev-namespace.yaml
   ```

1. Get the resource ID for the *appdev* group using the [`az ad group show`][az-ad-group-show] command. This group is set as the subject of a RoleBinding in the next step.

   ```azurecli-interactive
   az ad group show --group appdev --query id -o tsv
   ```

1. Create a RoleBinding for the *appdev* group to use the previously created Role for namespace access. Create a file named `rolebinding-dev-namespace.yaml` and paste the following YAML manifest. On the last line, replace *groupObjectId* with the group object ID output from the previous command.

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
     # Replace the placeholder below with the group's objectId (GUID)
     name: groupObjectId
   ```

   > [!TIP]
   > If you want to create the RoleBinding for a single user, specify *kind: User* and replace *groupObjectId* with the UPN in the previous sample.

1. Create the RoleBinding using the [`kubectl apply`][kubectl-apply] command and specify the filename of your YAML manifest:

   ```console
   kubectl apply -f rolebinding-dev-namespace.yaml
   ```

# [SRE](#tab/sre)

1. Create a namespace for the *SRE* using the [`kubectl create namespace`][kubectl-create] command:

   ```console
   kubectl create namespace sre
   ```

1. Create a file named `role-sre-namespace.yaml` and paste the following YAML manifest:

   ```yaml
   kind: Role
   apiVersion: rbac.authorization.k8s.io/v1
   metadata:
     name: sre-user-full-access
     namespace: sre
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

1. Create the Role using the [`kubectl apply`][kubectl-apply] command and specify the filename of your YAML manifest:

   ```console
   kubectl apply -f role-sre-namespace.yaml
   ```

1. Get the resource ID for the *opssre* group using the [az ad group show][az-ad-group-show] command:

   ```azurecli-interactive
   az ad group show --group opssre --query id -o tsv
   ```

1. Create a RoleBinding for the *opssre* group to use the previously created Role for namespace access. Create a file named `rolebinding-sre-namespace.yaml` and paste the following YAML manifest. On the last line, replace *groupObjectId* with the group object ID output from the previous command:

   ```yaml
   kind: RoleBinding
   apiVersion: rbac.authorization.k8s.io/v1
   metadata:
     name: sre-user-access
     namespace: sre
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: Role
     name: sre-user-full-access
   subjects:
   - kind: Group
     # Replace the placeholder below with the group's objectId (GUID)
     name: groupObjectId
   ```

1. Create the RoleBinding using the [`kubectl apply`][kubectl-apply] command and specify the filename of your YAML manifest:

   ```console
   kubectl apply -f rolebinding-sre-namespace.yaml
   ```

---

:::zone-end

:::zone pivot="terraform"

### Review the Terraform code

> [!NOTE]
> The sample code for this article is located in the [Azure Terraform GitHub repo](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-entra-k8s-rbac). You can view the log file containing the [test results from current and previous versions of Terraform](https://github.com/Azure/terraform/tree/master/quickstart/101-aks-entra-k8s-rbac/TestRecord.md).
>
> See more [articles and sample code showing how to use Terraform to manage Azure resources](/azure/developer/terraform/).

The sample uses two Terraform configurations, each in its own directory with its own state:

* The `prequisite` configuration creates a resource group and an AKS cluster with Microsoft Entra integration and Kubernetes RBAC enabled, which the repository's own end-to-end tests use to validate the scenario configuration against a real cluster. If you already have an AKS cluster that meets this article's [prerequisites](#prerequisites), skip this configuration and use your own resource group name, cluster name, and Microsoft Entra group object IDs with the scenario configuration instead.
* The scenario configuration, in the root of the sample, assigns the *Azure Kubernetes Service Cluster User Role* to the *appdev* and *opssre* groups at the cluster scope. It also creates the *dev* and *sre* Kubernetes namespaces with namespace-scoped Roles and RoleBindings that grant each group access only to its own namespace.

Terraform authenticates by using your Azure CLI sign-in context. Before you continue, ensure you're signed in by using `az login` and have selected the correct subscription by using `az account set --subscription <subscription-id>`.

### Deploy the prerequisite AKS cluster with Terraform

> [!NOTE]
> This stage is optional. Complete it only if you don't already have an AKS cluster with Microsoft Entra integration and Kubernetes RBAC enabled, and Azure RBAC for Kubernetes Authorization disabled, to test with.

1. Create a directory named `prequisite` and make it your current directory.

1. Create a file named `versions.tf` and insert the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-entra-k8s-rbac/prequisite/versions.tf)]

1. Create a file named `variables.tf` and add the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-entra-k8s-rbac/prequisite/variables.tf)]

1. Create a file named `main.tf` and add the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-entra-k8s-rbac/prequisite/main.tf)]

1. Create a file named `outputs.tf` and insert the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-entra-k8s-rbac/prequisite/outputs.tf)]

1. Initialize, format, and validate the configuration.

    ```console
    terraform init
    terraform fmt
    terraform validate
    ```

1. Review and apply the configuration.

    ```console
    terraform plan -out main.tfplan
    terraform apply main.tfplan
    ```

1. Get the outputs. You use these values as input for the scenario configuration in the next section.

    ```console
    terraform output -raw resource_group_name
    terraform output -raw aks_cluster_name
    terraform output -raw appdev_group_object_id
    terraform output -raw opssre_group_object_id
    ```

> [!IMPORTANT]
> The `appdev_group_object_id` and `opssre_group_object_id` outputs from the `prequisite` configuration are test principal IDs, not real Microsoft Entra groups. They resolve to the object ID of your currently signed-in Azure CLI account and the AKS cluster's managed identity principal ID, and exist only so the repository's automated tests can validate that the scenario configuration applies successfully. To test the Microsoft Entra group and user experience described in this article, use the group object IDs from [Create groups in Microsoft Entra ID](#create-groups-in-microsoft-entra-id) instead.

### Deploy Kubernetes RBAC with Terraform

1. Create a new directory, separate from `prequisite`, and make it your current directory. This configuration has its own Terraform state and doesn't manage or depend on the state of the `prequisite` configuration.

1. Create a file named `main.tf` and add the following code:

    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-entra-k8s-rbac/main.tf)]

1. Create a file named `terraform.tfvars` and provide the resource group name and cluster name for the AKS cluster you want to configure, and the object IDs of the *appdev* and *opssre* groups.

    ```hcl
    resource_group_name    = "<resource-group-name>"
    aks_cluster_name       = "<aks-cluster-name>"
    appdev_group_object_id = "<appdev-group-object-id>"
    opssre_group_object_id = "<opssre-group-object-id>"
    ```

1. Initialize, format, and validate the configuration.

    ```console
    terraform init
    terraform fmt
    terraform validate
    ```

1. Review and apply the configuration.

    ```console
    terraform plan -out main.tfplan
    terraform apply main.tfplan
    ```

    The configuration creates the Azure role assignments for both groups, the *dev* and *sre* Kubernetes namespaces, and namespace-scoped Roles and RoleBindings that grant the *appdev* group access to *dev* and the *opssre* group access to *sre*.

### Verify namespace access

1. Get the cluster admin credentials by using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --admin
    ```

1. Verify that both namespaces exist by using the [`kubectl get namespaces`][kubectl-get] command.

    ```console
    kubectl get namespaces
    ```

    The output shows the *dev* and *sre* namespaces, along with the default namespaces created for the cluster.

To test that the *appdev* and *opssre* groups can access only their assigned namespace, continue to [Access AKS cluster resources with Microsoft Entra identities](#access-aks-cluster-resources-with-microsoft-entra-identities).

### Clean up Terraform resources

> [!IMPORTANT]
> Destroy the scenario configuration before the `prequisite` configuration. The scenario configuration's Kubernetes provider needs the AKS cluster to still exist so Terraform can remove the namespaces, Roles, and RoleBindings it created.

1. From the scenario configuration directory, remove the Azure role assignments, namespaces, Roles, and RoleBindings it created.

    ```console
    terraform destroy
    ```

1. If you deployed the `prequisite` AKS cluster only to test this sample and no longer need it, remove it from the `prequisite` directory after the scenario configuration finishes destroying its resources.

    ```console
    terraform destroy
    ```

:::zone-end

<a name='interact-with-cluster-resources-using-azure-ad-identities'></a>

## Access AKS cluster resources with Microsoft Entra identities

Now, test that the expected permissions work when you create and manage resources in an AKS cluster. In these examples, you schedule and view pods in the user's assigned namespace, and try to schedule and view pods outside of the assigned namespace.

1. Reset the *kubeconfig* context using the [`az aks get-credentials`][az-aks-get-credentials] command. In a previous section, you set the context using the cluster admin credentials. The admin user bypasses Microsoft Entra sign-in prompts. Without the `--admin` parameter, the user context is applied that requires all requests to be authenticated using Microsoft Entra ID.

   ```azurecli-interactive
   az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --overwrite-existing
   ```

1. Schedule a basic NGINX pod using the [`kubectl run`][kubectl-run] command in the *dev* namespace:

   ```console
   kubectl run nginx-dev --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace dev
   ```

1. Enter the credentials for the *appdev* group account (enter *your* own credentials) at the sign-in prompt. Once you're successfully signed in, the account token is cached for future `kubectl` commands. The NGINX is successfully scheduled as shown in the following example output:

   ```console
   $ kubectl run nginx-dev --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace dev

   To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code B24ZD6FP8 to authenticate.

   pod/nginx-dev created
   ```

1. Use the [`kubectl get pods`][kubectl-get] command to view pods in the *dev* namespace:

   ```console
   kubectl get pods --namespace dev
   ```

1. Ensure the status of the NGINX pod is *Running*. The output looks like the following output:

   ```console
   $ kubectl get pods --namespace dev

   NAME        READY   STATUS    RESTARTS   AGE
   nginx-dev   1/1     Running   0          4m
   ```

### Test SRE access to AKS cluster resources

To confirm that our Microsoft Entra group membership and Kubernetes RBAC work correctly between different users and groups, try the previous commands when signed in as the *akssre* user.

1. Reset the *kubeconfig* context using the [`az aks get-credentials`][az-aks-get-credentials] command that clears the previously cached authentication token for the *aksdev* user.

   ```azurecli-interactive
   az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --overwrite-existing
   ```

1. Schedule and view pods in the assigned *SRE* namespace. When prompted, sign in with the *opssre* group account credentials (enter *your* own credentials).

   ```console
   kubectl run nginx-sre --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace sre
   kubectl get pods --namespace sre
   ```

   As shown in the following example output, you can successfully create and view the pods:

   ```console
   $ kubectl run nginx-sre --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace sre
   ```

1. To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code BM4RHP3FD to authenticate.

   ```console
   pod/nginx-sre created

   $ kubectl get pods --namespace sre

   NAME        READY   STATUS    RESTARTS   AGE
   nginx-sre   1/1     Running   0
   ```

1. Try to view or schedule pods outside of assigned SRE namespace.

   ```console
   kubectl get pods --all-namespaces
   kubectl run nginx-sre --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace dev
   ```

   These `kubectl` commands fail, as shown in the following example output. The user's group membership and Kubernetes Role and RoleBindings don't grant permissions to create or manager resources in other namespaces.

   ```console
   $ kubectl get pods --all-namespaces
   Error from server (Forbidden): pods is forbidden: User "akssre@contoso.com" cannot list pods at the cluster scope

   $ kubectl run nginx-sre --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace dev
   Error from server (Forbidden): pods is forbidden: User "akssre@contoso.com" cannot create pods in the namespace "dev"
   ```

### Create and view cluster resources outside of the assigned namespace

To view pods outside of the *dev* namespace. Use the [`kubectl get pods`][kubectl-get] command using `--all-namespaces`:

```console
kubectl get pods --all-namespaces
```

The user's group membership doesn't have a Kubernetes Role that allows this action, as shown in the following example output:

```console
Error from server (Forbidden): pods is forbidden: User "aksdev@contoso.com" cannot list resource "pods" in API group "" at the cluster scope
```

In the same way, schedule a pod in a different namespace, such as the *SRE* namespace. The user's group membership doesn't align with a Kubernetes Role and RoleBinding to grant these permissions, as shown in the following example output:

```console
$ kubectl run nginx-dev --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine --namespace sre

Error from server (Forbidden): pods is forbidden: User "akssre@contoso.com" cannot create resource "pods" in API group "" in the namespace "sre"
```

### Clean up cluster resources

To clean up all of the resources, run the following commands.

:::zone pivot="azure-cli"

Get the admin kubeconfig context and delete the *dev* and *sre* namespaces. This action also deletes the pods, Roles, and RoleBindings.

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --admin

kubectl delete namespace dev
kubectl delete namespace sre
```

:::zone-end

:::zone pivot="terraform"

If you used Terraform to create the *dev* and *sre* namespaces, Roles, and RoleBindings, see [Clean up Terraform resources](#clean-up-terraform-resources) instead of running `kubectl delete namespace`.

:::zone-end

Delete the Microsoft Entra ID user accounts for aksdev and akssre.

```azurecli-interactive
az ad user delete --upn-or-object-id $AKSDEV_ID
az ad user delete --upn-or-object-id $AKSSRE_ID
```

Delete the Microsoft Entra ID groups for appdev and opssre. This action also deletes any remaining Azure role assignments.

```azurecli-interactive
az ad group delete --group appdev
az ad group delete --group opssre
```

## Next steps

* For more information about how to secure Kubernetes clusters, see [Access and identity options for AKS][rbac-authorization].

* For best practices on identity and resource control, see [Authentication and authorization concepts in AKS][operator-best-practices-identity].

<!-- LINKS - external -->
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-run]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#run
[kubectl-overview]: https://kubernetes.io/docs/reference/kubectl/

<!-- LINKS - internal -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[install-azure-cli]: /cli/azure/install-azure-cli
[azure-ad-aks-cli]: managed-azure-ad.md
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-ad-group-create]: /cli/azure/ad/group#az-ad-group-create
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-ad-user-create]: /cli/azure/ad/user#az-ad-user-create
[az-ad-group-member-add]: /cli/azure/ad/group/member#az-ad-group-member-add
[az-ad-group-show]: /cli/azure/ad/group#az-ad-group-show
[rbac-authorization]: concepts-identity.md#kubernetes-rbac
[operator-best-practices-identity]: concepts-cluster-authentication.md
[terraform-on-azure]: /azure/developer/terraform/overview
[enable-azure-ad-integration-existing-cluster]: managed-azure-ad.md#use-an-existing-cluster
