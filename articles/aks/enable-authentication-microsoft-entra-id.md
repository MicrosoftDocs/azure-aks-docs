---
title: Enable AKS-managed Microsoft Entra integration on an Azure Kubernetes Service cluster
description: Learn how to enable AKS-managed Microsoft Entra integration on an Azure Kubernetes Service cluster with kubelogin.
ms.topic: how-to
ms.subservice: aks-security
ms.date: 10/07/2025
ms.custom: devx-track-azurecli
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: As an Azure Kubernetes Service (AKS) administrator, I want to enable AKS-managed Microsoft Entra integration for my AKS cluster with kubelogin and configure Kubernetes role-based access control (Kubernetes RBAC).
---

# Enable AKS-managed Microsoft Entra integration for Kubernetes clusters with kubelogin

The AKS-managed Microsoft Entra integration simplifies the Microsoft Entra integration process. Previously, you were required to create a client and server app, and the Microsoft Entra tenant had to assign [Directory Readers][directory-readers-rbac-role] role permissions. Now, the Azure Kubernetes Service (AKS) resource provider manages the client and server apps for you.

Cluster administrators can configure Kubernetes role-based access control (Kubernetes RBAC) based on a user's identity or directory group membership. Microsoft Entra authentication is provided to AKS clusters with OpenID Connect. OpenID Connect is an identity layer built on top of the OAuth 2.0 protocol. For more information on OpenID Connect, see the [OpenID Connect documentation][open-id-connect].

Learn more about the Microsoft Entra integration flow in the [Microsoft Entra documentation](concepts-identity.md#azure-ad-integration).

## Limitations

The following are constraints to integrate authentication on AKS:

- Integration can't be disabled after being added.
- Downgrades from an integrated cluster to the legacy Microsoft Entra ID clusters aren't supported.
- Clusters without Kubernetes RBAC support are unable to add the integration.

## Before you begin

To install the AKS addon, verify you have the following items:

- You have Azure CLI version 2.29.0 or later installed and configured. To find the version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- You need `kubectl` with a minimum version of [1.18.1](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.18.md#v1181) or [`kubelogin`][kubelogin]. With the Azure CLI and the Azure PowerShell module, these two commands are included and automatically managed. Meaning, they're upgraded by default and running `az aks install-cli` isn't required or recommended. If you're using an automated pipeline, you need to manage upgrades for the correct or latest version. The difference between the minor versions of Kubernetes and `kubectl` shouldn't be more than *one* version. Otherwise, authentication issues occur on the wrong version.
- If you're using [helm](https://github.com/helm/helm), you need a minimum version of helm 3.3.
- This configuration requires you have a Microsoft Entra group for your cluster. This group is registered as an admin group on the cluster to grant admin permissions. If you don't have an existing Microsoft Entra group, you can create one using the [`az ad group create`](/cli/azure/ad/group#az_ad_group_create) command.

> [!NOTE]
> Microsoft Entra integrated clusters using a Kubernetes version newer than version 1.24 automatically use the `kubelogin` format. Beginning with Kubernetes version 1.24, the default format of the `clusterUser` credential for Microsoft Entra ID clusters is `exec`, which requires [`kubelogin`][kubelogin] binary in the execution `PATH`. There's no behavior change for non-Microsoft Entra clusters, or Microsoft Entra ID clusters running a version older than 1.24.
> Existing downloaded `kubeconfig` continues to work. An optional query parameter `format` is included when getting `clusterUser` credential to overwrite the default behavior change. You can explicitly specify format to `azure` if you need to maintain the old `kubeconfig` format.

## Enable the integration on your AKS cluster

### Create a new cluster

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name myResourceGroup --location centralus
    ```

1. Create an AKS cluster and enable administration access for your Microsoft Entra group using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
      --resource-group myResourceGroup \
      --name myManagedCluster \
      --enable-aad \
      --aad-admin-group-object-ids <id> \
      --aad-tenant-id <id> \
      --generate-ssh-keys
    ```

    A successful creation of an AKS-managed Microsoft Entra ID cluster has the following section in the response body.

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

Enable AKS-managed Microsoft Entra integration on your existing Kubernetes RBAC enabled cluster using the [`az aks update`][az-aks-update] command. Make sure to set your admin group to keep access on your cluster.

```azurecli-interactive
az aks update \
  --resource-group MyResourceGroup \
  --name myManagedCluster \
  --enable-aad \
  --aad-admin-group-object-ids <id-1>,<id-2> \
  --aad-tenant-id <id>
```

A successful activation of an AKS-managed Microsoft Entra ID cluster has the following section in the response body:

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

If your cluster uses legacy Microsoft Entra integration, you can upgrade to AKS-managed Microsoft Entra integration through the [`az aks update`][az-aks-update] command.

> [!WARNING]
> Free tier clusters might experience API server downtime during the upgrade. We recommend upgrading during your nonbusiness hours.
> After the upgrade, the `kubeconfig` content changes. You need to run `az aks get-credentials --resource-group <AKS resource group name> --name <AKS cluster name>` to merge the new credentials into the `kubeconfig` file.

```azurecli-interactive
az aks update \
  --resource-group myResourceGroup \
  --name myManagedCluster \
  --enable-aad \
  --aad-admin-group-object-ids <id> \
  --aad-tenant-id <id>
```

A successful migration of an AKS-managed Microsoft Entra ID cluster has the following section in the response body:

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
    az aks get-credentials --resource-group myResourceGroup --name myManagedCluster
    ```

1. Follow your sign in instructions.

1. Set `kubelogin` to use the Azure CLI.

    ```azurecli-interactive
    kubelogin convert-kubeconfig -l azurecli
    ```

1. View the nodes in the cluster with the `kubectl get nodes` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

## Non-interactive sign-in with kubelogin

There are some non-interactive scenarios that don't support `kubectl`. In these cases, use [`kubelogin`][kubelogin] to connect to the cluster with a non-interactive service principal credential to perform continuous integration pipelines.

> [!NOTE]
> Microsoft Entra integrated clusters using a Kubernetes version newer than version 1.24 automatically use the `kubelogin` format. Beginning with Kubernetes version 1.24, the default format of the `clusterUser` credential for Microsoft Entra ID clusters is `exec`, which requires [`kubelogin`][kubelogin] binary in the execution PATH. There's no behavior change for non-Microsoft Entra clusters, or Microsoft Entra ID clusters running a version older than 1.24.
> Existing downloaded `kubeconfig` continues to work. An optional query parameter `format` is included when getting `clusterUser` credential to overwrite the default behavior change. You can explicitly specify format to `azure` if you need to maintain the old `kubeconfig` format.

When getting the `clusterUser` credential, you can use the `format` query parameter to overwrite the default behavior. You can set the value to `azure` to use the original `kubeconfig` format:

```azurecli-interactive
az aks get-credentials --format azure
```

If your Microsoft Entra integrated cluster uses Kubernetes version 1.24 or lower, you need to manually convert the `kubeconfig` format.

```azurecli-interactive
export KUBECONFIG=/path/to/kubeconfig
kubelogin convert-kubeconfig
```

If you receive the message **error: The Azure auth plugin has been removed.**, you need to run the command `kubelogin convert-kubeconfig` to convert the `kubeconfig` format manually. For more information, see [Azure Kubelogin Known Issues][azure-kubelogin-known-issues].

## Troubleshoot access issues

> [!IMPORTANT]
> The step described in this section suggests an alternative authentication method compared to the normal Microsoft Entra group authentication. Use this option only in an emergency.

If you lack administrative access to a valid Microsoft Entra group, you can follow this workaround. Sign in with an account that is a member of the [Azure Kubernetes Service Cluster Admin](/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-cluster-admin-role) role and grant your group or tenant admin credentials to access your cluster.

## Next steps

- Learn about [Microsoft Entra integration with Kubernetes RBAC][azure-ad-rbac].
- Learn more about [AKS and Kubernetes identity concepts][aks-concepts-identity].
- Learn how to [use kubelogin][kubelogin-authentication] for all supported Microsoft Entra authentication methods in AKS.
- Use [Azure Resource Manager templates][aks-arm-template] to create AKS-managed Microsoft Entra ID enabled clusters.


<!-- LINKS - external -->
[aks-arm-template]: /azure/templates/microsoft.containerservice/managedclusters
[kubelogin]: https://github.com/Azure/kubelogin
[azure-kubelogin-known-issues]: https://azure.github.io/kubelogin/known-issues.html

<!-- LINKS - Internal -->
[directory-readers-rbac-role]: /entra/identity/role-based-access-control/permissions-reference#directory-readers
[aks-concepts-identity]: concepts-identity.md
[azure-ad-rbac]: azure-ad-rbac.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-group-create]: /cli/azure/group#az-group-create
[open-id-connect]: /entra/identity-platform/v2-protocols-oidc
[az-aks-update]: /cli/azure/aks#az-aks-update
[kubelogin-authentication]: kubelogin-authentication.md
