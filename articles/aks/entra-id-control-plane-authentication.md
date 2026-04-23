---
title: Enable Microsoft Entra ID authentication for the AKS control plane
description: Learn how to enable Microsoft Entra ID authentication for the Kubernetes API server (control plane) on an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.subservice: aks-security
ms.date: 04/19/2026
ms.custom: devx-track-azurecli
author: shashankbarsin
ms.author: shasb
ai-usage: ai-assisted

# Customer intent: As an Azure Kubernetes Service (AKS) administrator, I want to enable Microsoft Entra ID authentication for my AKS cluster's Kubernetes API server so that cluster users sign in with their organizational identities.
---

# Enable Microsoft Entra ID authentication for the AKS control plane

The Microsoft Entra integration simplifies the Microsoft Entra integration process. Previously, you were required to create a client and server app, and the Microsoft Entra tenant had to assign [Directory Readers][directory-readers-rbac-role] role permissions. Now, the Azure Kubernetes Service (AKS) resource provider manages the client and server apps for you.

Cluster administrators can configure Kubernetes role-based access control (Kubernetes RBAC) based on a user's identity or directory group membership.

Learn more about the Microsoft Entra integration flow in the [Microsoft Entra documentation](concepts-cluster-authentication.md).

## Limitations

Microsoft Entra integration can't be disabled after it's enabled on a cluster.

## Before you begin

To install the AKS addon, verify you have the following items:

- You have Azure CLI version 2.29.0 or later installed and configured. To find the version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- You need `kubectl` with a minimum version of [1.18.1](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.18.md#v1181) or [`kubelogin`][kubelogin]. With the Azure CLI and the Azure PowerShell module, these two commands are included and automatically managed. Meaning, they're upgraded by default and running [`az aks install-cli`](/cli/azure/aks#az-aks-install-cli) isn't required or recommended. If you're using an automated pipeline, you need to manage upgrades for the correct or latest version. The difference between the minor versions of Kubernetes and `kubectl` shouldn't be more than *one* version. Otherwise, authentication issues occur on the wrong version.
- This configuration requires you have a Microsoft Entra group for your cluster. This group is registered as an admin group on the cluster to grant admin permissions. If you don't have an existing Microsoft Entra group, you can create one using the [`az ad group create`](/cli/azure/ad/group#az-ad-group-create) command.

## Enable the integration on your AKS cluster

First, set environment variables for the resource group, cluster name, Microsoft Entra admin group object IDs, and tenant ID. Reuse these variables in the commands that follow.

```azurecli-interactive
export RESOURCE_GROUP="myResourceGroup"
export CLUSTER_NAME="myManagedCluster"
export AAD_ADMIN_GROUP_OBJECT_IDS="<group-object-id>"  # comma-separated for multiple groups
export AAD_TENANT_ID="<tenant-id>"
export LOCATION="centralus"
```

### Create a new cluster

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

1. Create an AKS cluster and enable administration access for your Microsoft Entra group using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --enable-aad \
      --aad-admin-group-object-ids $AAD_ADMIN_GROUP_OBJECT_IDS \
      --aad-tenant-id $AAD_TENANT_ID \
      --generate-ssh-keys
    ```

    A successful creation of an Microsoft Entra ID cluster has the following section in the response body.

    ```output
    "AADProfile": {
      "adminGroupObjectIds": [
      "aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb"
      ],
      "clientAppId": null,
      "managed": true,
      "serverAppId": null,
      "serverAppSecret": null,
      "tenantId": "aaaabbbb-0000-cccc-1111-dddd2222eeee"
    }
    ```

### Use an existing cluster

Enable Microsoft Entra integration on your existing Kubernetes RBAC enabled cluster using the [`az aks update`][az-aks-update] command. Make sure to set your admin group to keep access on your cluster.

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-aad \
  --aad-admin-group-object-ids $AAD_ADMIN_GROUP_OBJECT_IDS \
  --aad-tenant-id $AAD_TENANT_ID
```

A successful activation of an Microsoft Entra ID cluster has the following section in the response body:

```output
"AADProfile": {
  "adminGroupObjectIds": [
      "aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb"
  ],
  "clientAppId": null,
  "managed": true,
  "serverAppId": null,
  "serverAppSecret": null,
  "tenantId": "aaaabbbb-0000-cccc-1111-dddd2222eeee"
}
```

### Migrate legacy cluster to integration

If your cluster uses legacy Microsoft Entra integration, you can upgrade to Microsoft Entra integration through the [`az aks update`][az-aks-update] command.

> [!WARNING]
> Free tier clusters might experience API server downtime during the upgrade. We recommend upgrading during your nonbusiness hours.
> After the upgrade, the `kubeconfig` content changes. You need to run `az aks get-credentials --resource-group <AKS resource group name> --name <AKS cluster name>` to merge the new credentials into the `kubeconfig` file.

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-aad \
  --aad-admin-group-object-ids $AAD_ADMIN_GROUP_OBJECT_IDS \
  --aad-tenant-id $AAD_TENANT_ID
```

A successful migration of an Microsoft Entra ID cluster has the following section in the response body:

```output
"AADProfile": {
  "adminGroupObjectIds": [
      "aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb"
  ],
  "clientAppId": null,
  "managed": true,
  "serverAppId": null,
  "serverAppSecret": null,
  "tenantId": "aaaabbbb-0000-cccc-1111-dddd2222eeee"
}
```

## Access your enabled cluster

1. Get the user credentials to access your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. Follow your sign in instructions.

1. View the nodes in the cluster with the `kubectl get nodes` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

Clusters running Kubernetes 1.24 or later automatically use the `kubelogin` exec-plugin format, so no manual `kubeconfig` conversion is needed for interactive Azure CLI sign-in. For non-interactive scenarios such as CI pipelines, or to use a different authentication method (service principal, managed identity, workload identity, or device code), see [Use kubelogin to authenticate users in AKS][kubelogin-authentication].

## Break-glass access

In the rare event that Microsoft Entra ID sign-in to your cluster's Kubernetes API server isn't working — for example, during a wider Microsoft Entra service incident — you can fall back to the cluster's local admin account to keep operating the cluster until Entra-based sign-in is restored.

> [!NOTE]
> This fallback is only needed when Entra-based sign-in itself is unavailable. If your problem is a misconfigured admin group (for example, the group was deleted or the wrong object ID was set), you don't need it — update the admin group directly with `az aks update --aad-admin-group-object-ids` using an account that has the `Microsoft.ContainerService/managedClusters/write` permission.

> [!IMPORTANT]
> This workflow bypasses Microsoft Entra authentication. Use it only as a temporary fallback, and disable local accounts again once Microsoft Entra sign-in is restored.

To use the break-glass path, you need the [Azure Kubernetes Service Contributor](/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-contributor-role) role on the cluster resource. This role grants the `Microsoft.ContainerService/managedClusters/write` permission required to re-enable local accounts, plus access to the local cluster-admin credential. It's evaluated by Azure Resource Manager, so it works independently of the Microsoft Entra sign-in path to the Kubernetes API server.

1. If [local accounts](local-accounts.md) are disabled on the cluster, re-enable them temporarily.

    ```azurecli-interactive
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-local-accounts
    ```

1. Retrieve the local cluster-admin credential using the [`az aks get-credentials`][az-aks-get-credentials] command with the `--admin` flag. This credential is a certificate-based kubeconfig that bypasses Microsoft Entra.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --admin
    ```

1. Use `kubectl` to operate the cluster while Microsoft Entra is unavailable. Once Microsoft Entra sign-in is working again, [disable local accounts](local-accounts.md#disable-local-accounts) to return the cluster to its secure baseline.

    ```azurecli-interactive
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --disable-local-accounts
    ```

## Next steps

- Strengthen sign-in to your cluster with [Conditional Access for cluster and node access][conditional-access].
- Use just-in-time elevated access with [Privileged Identity Management for cluster and node access][privileged-identity-management].
- Learn about [Microsoft Entra integration with Kubernetes RBAC][kubernetes-rbac-entra-id].
- Learn more about [AKS and Kubernetes identity concepts][aks-concepts-identity].
- Learn how to [use kubelogin][kubelogin-authentication] for all supported Microsoft Entra authentication methods in AKS.
- Use [Azure Resource Manager templates][aks-arm-template] to create Microsoft Entra ID enabled clusters.


<!-- LINKS - external -->
[aks-arm-template]: /azure/templates/microsoft.containerservice/managedclusters
[kubelogin]: https://github.com/Azure/kubelogin

<!-- LINKS - Internal -->
[directory-readers-rbac-role]: /entra/identity/role-based-access-control/permissions-reference#directory-readers
[aks-concepts-identity]: concepts-identity.md
[kubernetes-rbac-entra-id]: kubernetes-rbac-entra-id.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[kubelogin-authentication]: kubelogin-authentication.md
[conditional-access]: access-control-managed-azure-ad.md
[privileged-identity-management]: privileged-identity-management.md
