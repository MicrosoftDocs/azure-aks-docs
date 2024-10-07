---
title: Control cluster access using Privileged Identity Management (PIM) with AKS-managed Microsoft Entra integration
description: Learn how to access clusters using Privileged Identity Management (PIM) when integrating Microsoft Entra ID in your Azure Kubernetes Service (AKS) clusters.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/26/2024
author: schaffererin
ms.author: schaffererin
---

# Use Privileged Identity Management (PIM) to control access to your Azure Kubernetes Service (AKS) clusters

When setting up permissions for different teams, you might want to set default permissions for specified teams, then grant privileged access to specific users when needed. Using Azure Kubernetes Service (AKS) with Microsoft Entra ID allows you to set up Privileged Identity Management (PIM) for just-in-time (JIT) requests.

In this article, you learn how to:

> [!div class="checklist"]
>
> - Set default roles for example groups to access or perform operations on AKS clusters based on Microsoft Entra group memberships.
> - Configure basic roles for accessing AKS clusters.
> - Self-activate roles to get just-in-time access to AKS clusters.
> - Set approvers to approve or deny approval requests for just-in-time access.

> [!NOTE]
> Microsoft Entra Privileged Identity Management (PIM) has Microsoft Entra ID P2 or Microsoft Entra ID Governance capabilities requiring a Premium P2 SKU. For more information, see [Microsoft Entra ID Governance licensing fundamentals][licensing-fundamentals] and [pricing guide][aad-pricing].

## Prerequisites

This article assumes you have an existing AKS cluster with Microsoft Entra ID integration. If you don't have one, see [Create an AKS cluster with Microsoft Entra ID integration][create-aks-managed-cluster].

## Create demo groups in Microsoft Entra ID

In this section, we create three groups in Microsoft Entra ID:

- **Default**: This group has *read-only* access (`Azure Kubernetes Service RBAC Reader`) to resources in the AKS cluster.
- **Admin**: This group has *admin* access (`Azure Kubernetes Service RBAC Admin`) to resources in the AKS cluster.
- **Approver**: This group has permissions to *approve or deny requests* for just-in-time access to the AKS cluster.

You *can* use just the **default** and **admin** groups instead of creating a separate **approver** group. However, if you include approval permissions in the **admin** group, the member who gets just-in-time access can approve their own requests and the requests of others. We don't recommend using this configuration in a production environment, but it's useful for testing purposes.

### Create default group

1. Get the *resource ID* of the AKS cluster using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    AKS_ID=$(az aks show \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --query id \
        --output tsv)
    ```

1. Get the *resource group ID* of the AKS cluster using the [`az group show`][az-group-show] command.

    ```azurecli-interactive
    RG_ID=$(az group show \
        --resource-group <resource-group-name> \
        --query id \
        --output tsv)
    ```

1. Create the **default** group using the [`az ad group create`][az-ad-group-create] command.

    ```azurecli-interactive
    DEFAULT_ID=$(az ad group create \
        --display-name default \
        --mail-nickname default \
        --query id \
        --output tsv)
    ```

1. Create an Azure role assignment for the **default** group using the [`az role assignment create`][az-role-assignment-create] command.

    There are *three* roles you can assign to the **default** group depending on your specific requirements:

    - `Azure Kubernetes Service RBAC Reader`: Assigned at the scope of the AKS cluster and gives basic read-only access to most resources in the cluster.
    - `Reader`: Assigned at the scope of the resource group and gives read-only access to resources in the resource group.
    - `Azure Kubernetes Service Cluster User Role`: Assigned at the scope of the AKS cluster and gives access to get the kubeconfig context for the AKS cluster.

    ```azurecli-interactive
    # Assign the Azure Kubernetes Service RBAC Reader role to the default group
    az role assignment create \
        --role "Azure Kubernetes Service RBAC Reader" \
        --assignee $DEFAULT_ID \
        --scope $AKS_ID

    # Assign the Reader role to the default group
    az role assignment create \
        --role "Reader" \
        --assignee $DEFAULT_ID \
        --scope $RG_ID

    # Assign the Azure Kubernetes Service Cluster User Role to the default group
    az role assignment create \
        --role "Azure Kubernetes Service Cluster User Role" \
        --assignee $DEFAULT_ID \
        --scope $AKS_ID
    ```

### Create admin group

1. Create the **admin** group using the [`az ad group create`][az-ad-group-create] command.

    ```azurecli-interactive
    ADMIN_ID=$(az ad group create \
        --display-name admin \
        --mail-nickname admin \
        --query id \
        --output tsv)
    ```

1. Assign the `Azure Kubernetes Service RBAC Admin` role to the **admin** group using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create \
        --role "Azure Kubernetes Service RBAC Admin" \
        --assignee $ADMIN_ID \
        --scope $AKS_ID
    ```

> [!NOTE]
> If you want to let users in the **admin** group change node pool settings, such as manual scaling, you need to create a `Contributor` role assignment on the cluster node pool using the following command:
>
> ```azurecli-interactive
> az role assignment create \
>    --role "Contributor" \
>    --assignee $ADMIN_ID \
>    --scope $AKS_ID/nodepools/<node-pool-name>
> ```
>
> Keep in mind that this only gives permission to scale in or out from the AKS resource. If you want to allow scaling in or out from the Virtual Machine Scale Set resource, you need to create an assignment at the Virtual Machine Scale Set level.

### Create approver group

- Create the **approver** group using the [`az ad group create`][az-ad-group-create] command.

    ```azurecli-interactive
    APPROVER_ID=$(az ad group create \
        --display-name approver \
        --mail-nickname approver \
        --query id \
        --output tsv)
    ```

## Create demo users in Microsoft Entra ID

In this section, we create two users in Microsoft Entra ID: a **normal** user with only the default role, and a **privileged** user who can approve or deny just-in-time requests from the *normal* user.

1. Create the **normal** user using the [`az ad user create`][az-ad-user-create] command.

    ```azurecli-interactive
    DOMAIN=contoso.com
    PASSWORD=Password1

    NUSER_ID=$(az ad user create \
        --display-name n01 \
        --password ${PASSWORD} \
        --user-principal-name n01@${DOMAIN} \
        --query id \
        --output tsv)
    ```

1. Add the **normal** user to the default group using the [`az ad group member add`][az-ad-group-member-add] command.

    ```azurecli-interactive
    az ad group member add \
        --group $DEFAULT_ID \
        --member-id $NUSER_ID
    ```

1. Create the **privileged** user using the [`az ad user create`][az-ad-user-create] command.

    ```azurecli-interactive
    PUSER_ID=$(az ad user create \
        --display-name p01 \
        --password ${PASSWORD} \
        --user-principal-name p01@${DOMAIN} \
        --query id \
        --output tsv)
    ```

1. Add the **privileged** user to the approver group using the [`az ad group member add`][az-ad-group-member-add] command.

    ```azurecli-interactive
    az ad group member add \
        --group $APPROVER_ID \
        --member-id $PUSER_ID
    ```

## Enable Privileged Identity Management (PIM) for the admin group

1. From the [Azure portal home page](https://portal.azure.com/), select **Microsoft Entra ID**.
1. From the service menu, under **Manage**, select **Groups**, and then select the **admin** group.
1. From the service menu, under **Activity**, select **Privileged Identity Management**, and then select **Enable PIM for this group**.

### Set an approver for the admin group

1. From the [Azure portal home page](https://portal.azure.com/), search for and select **Privileged Identity Management**.
1. From the service menu, under **Manage**, select **Groups**, and then select the **admin** group.
1. From the service menu, under **Manage**, select **Assignments** > **Add assignments**.
1. On the **Membership** tab of the **Add assignments** page, select **Member** as the selected role and **default** as the selected member, and then select **Next**.
1. On the **Settings** tab, select **Eligible** as the assignment type, and then select **Assign**.
1. From the service menu, under **Manage**, select **Settings** > **Member** > **Edit**.
1. On the **Edit role setting - Member** page, select the **Require approval to activate** checkbox and add the **approver** group as the selected approver.

    > [!NOTE]
    > If you don't select the **Require approval to activate** checkbox, the users in the **default** group can self-activate the role to get just-in-time access to the AKS cluster without approval. The user in the **approver** group has to be a member of the group. Even if you set the user as the **owner**, they still aren't able to review just-in-time requests because the group owner only has administrative rights to the group, not the role assignment. You *can* set the user as the member and owner of the same group without conflict.

1. Make any other necessary changes, and then select **Update**.

For more information about PIM configuration, see [Configure PIM for groups][configure-pim-for-groups].

## Interact with cluster resources using the default role

Now, we can try to access the AKS cluster using the **normal** user, who is a member of the **default** group.

1. Log in to the Azure portal as the **normal** user using the [`az login`][az-login] command.

    ```azurecli-interactive
    az login --username n01@$DOMAIN --password ${PASSWORD}
    ```

1. Get the user credentials to access the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
    ```

1. Try to access the cluster pods using the `kubectl get` command.

    ```bash
    kubectl get pods --namespace kube-system
    ```

    Your output should look similar to the following example output, which shows the pods in the `kube-system` namespace:

    ```output
    NAME                                   READY   STATUS    RESTARTS   AGE
    azure-ip-masq-agent-2rdd9              1/1     Running   0          30h
    azure-policy-767c9d9d9d-886rf          1/1     Running   0          31h
    cloud-node-manager-92t6h               1/1     Running   0          30h
    coredns-789789675-b2dhg                1/1     Running   0          31h
    coredns-autoscaler-77bbc46446-pgt92    1/1     Running   0          31h
    csi-azuredisk-node-lnzrf               3/3     Running   0          30h
    csi-azurefile-node-lhbxr               3/3     Running   0          31h
    konnectivity-agent-7645d94b-9wqct      1/1     Running   0          30h
    kube-proxy-lkx4w                       1/1     Running   0          31h
    metrics-server-5955767688-lpbjb        2/2     Running   0          30h
    ```

1. Try to access the cluster secrets using the `kubectl get` command.

    ```bash
    kubectl get secrets --namespace kube-system
    ```

    Your output should look similar to the following example output, which shows an error message because the user doesn't have permission to access the secrets:

    ```output
    Error from server (Forbidden): secrets is forbidden: User "[email protected]" cannot list resource "secrets" in API group "" in the namespace "kube-system": User does not have access to the resource in Azure. Update role assignment to allow access.
    ```

    The `Azure Kubernetes Service RBAC Reader` role doesn't have permission to access secrets, so this error is expected.

## Request just-in-time access to the AKS cluster

This time, we can request just-in-time access as a temporary `Azure Kubernetes Service RBAC Admin` using the steps in [Activate your group membership or ownership in Privileged Identity Management][activate-ownership-pim]. To learn how to approve or deny requests as an approver, see [Approve activation requests for group members and owners][approve-requests].

## Interact with cluster resources using the admin role

After temporarily adding the `Azure Kubernetes Service RBAC Admin` role, you can access the cluster resources that require admin permissions.

1. Remove existing stored tokens using the following `kubelogin` command:

    ```bash
    kubelogin remove-tokens
    ```

    > [!NOTE]
    > If you encounter an error due to lack of permissions, log in to refresh the permissions using the `az login` command.

1. Try to access the cluster secrets again using the `kubectl get secrets` command.

    ```bash
    kubectl get secrets --namespace kube-system
    ```

    Your output should look similar to the following example output, which shows the secrets in the `kube-system` namespace:

    ```output
    NAME                     TYPE                            DATA   AGE
    bootstrap-token-sw3rck   bootstrap.kubernetes.io/token   4      35h
    konnectivity-certs       Opaque                          3      35h
    ```

    The user can now access the secrets because they have the `Azure Kubernetes Service RBAC Admin` role.

### Token lifetime considerations

Due to [token lifetime][token-lifetime] design, if you're granting roles to users who use CLI tools, like `kubectl` or `kubelogin`, the activation duration technically can't be less than *60 minutes*. Even if the duration is set to less than 60 minutes, the actual effective duration remains between 60-75 minutes.

When `kubelogin` tries to [get tokens from the Microsoft identity platform][get-tokens], `access_token` and `refresh_token` are returned for further use. The `access_token` makes requests to the API, and the `refresh_token` is used to get a new `access_token` when the current one expires. The `access_token` can't be revoked once generated, but the `refresh_token` can be revoked. If the `refresh_token` is revoked, the user has to reauthenticate to get a new `refresh_token`. To manually revoke the `refresh_token`, you can use [`Revoke-AzureADUserAllRefreshToken`][revoke-refresh-token].

## Next steps

For more information, see the following articles:

- [Control cluster access using Conditional Access with AKS-managed Microsoft Entra integration][conditional-access]
- [Microsoft Entra Privileged Identity Management overview][what-is-pim]
- [Use Kubernetes role-based access control with Microsoft Entra ID in AKS][aks-rbac]

<!-- LINKS -->
[licensing-fundamentals]: /entra/id-governance/licensing-fundamentals
[aad-pricing]: https://azure.microsoft.com/pricing/details/active-directory/
[create-aks-managed-cluster]: ./enable-authentication-microsoft-entra-id.md
[az-aks-show]: /cli/azure/aks#az_aks_show
[az-group-show]: /cli/azure/group#az_group_show
[az-ad-group-create]: /cli/azure/ad/group#az_ad_group_create
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[az-ad-user-create]: /cli/azure/ad/user#az_ad_user_create
[az-ad-group-member-add]: /cli/azure/ad/group/member#az_ad_group_member_add
[az-login]: /cli/azure/reference-index#az_login
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[configure-pim-for-groups]: /entra/id-governance/privileged-identity-management/groups-assign-member-owner
[activate-ownership-pim]: /entra/id-governance/privileged-identity-management/groups-activate-roles
[approve-requests]: /entra/id-governance/privileged-identity-management/groups-approval-workflow
[token-lifetime]: /entra/identity-platform/access-tokens#token-lifetime
[get-tokens]: /entra/identity-platform/access-tokens#token-lifetime
[revoke-refresh-token]: /powershell/module/azuread/revoke-azureaduserallrefreshtoken
[conditional-access]: ./access-control-managed-azure-ad.md
[what-is-pim]: /entra/id-governance/privileged-identity-management/pim-configure
[aks-rbac]: ./azure-ad-rbac.md
