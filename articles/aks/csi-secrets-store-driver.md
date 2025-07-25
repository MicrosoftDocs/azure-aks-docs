---
title: Use the Azure Key Vault provider for Secrets Store CSI Driver for Azure Kubernetes Service (AKS) secrets
description: Learn how to use the Azure Key Vault provider for Secrets Store CSI Driver to integrate secrets stores with Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.subservice: aks-security
ms.date: 06/10/2025
ms.custom: template-how-to, devx-track-azurecli, biannual
# Customer intent: As a Kubernetes administrator, I want to integrate Azure Key Vault with my AKS cluster using the Secrets Store CSI Driver, so that I can securely manage and access secrets, keys, and certificates within my applications.
---

# Use the Azure Key Vault provider for Secrets Store CSI Driver in an Azure Kubernetes Service (AKS) cluster

The Azure Key Vault provider for Secrets Store CSI Driver allows for the integration of an Azure Key Vault as a secret store with an Azure Kubernetes Service (AKS) cluster via a [CSI volume][kube-csi].

## Features

* Mounts secrets, keys, and certificates to a pod using a CSI volume.
* Supports CSI inline volumes.
* Supports mounting multiple secrets store objects as a single volume.
* Supports pod portability with the `SecretProviderClass` CRD.
* Supports Windows containers.
* Syncs with Kubernetes secrets.
* Supports autorotation of mounted contents and synced Kubernetes secrets.

## Limitations

- A container using a `ConfigMap` or `Secret` as a `subPath` volume mount does not receive automated updates when the secret is rotated. This is a Kubernetes limitation. To have the changes take effect, the application needs to reload the changed file by either watching for changes in the file system or by restarting the pod. For more information, see [Secrets Store CSI Driver known limitations](https://secrets-store-csi-driver.sigs.k8s.io/known-limitations.html#secrets-not-rotated-when-using-subpath-volume-mount).
- The add-on creates a managed identity named `azurekeyvaultsecretsprovider-xxx` in the node resource group and assigns it to the Virtual Machine Scale Sets (VMSS) automatically. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

## Prerequisites

* If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
* Check that your version of the Azure CLI is 2.30.0 or later. If it's an earlier version, [install the latest version](/cli/azure/install-azure-cli).

### Network
* If using network isolated clusters, it's recommended to [set up private endpoint to access Azure Key Vault][private-endpoint-keyvault].
* If the cluster has outbound type `userDefinedRouting` and uses a firewall device that can control outbound traffic based on domain names, such as Azure Firewall, ensure the [required outbound network rules and FQDNs are allowed][fqdns-for-keyvault].
* If you're restricting Ingress to the cluster, make sure ports **9808** and **8095** are open.

### Roles
* The identity used to with the `SecretProviderClass` needs to have `Key Vault Certificate User` to access `key` or `certificate` [object types][keyvault-object-types].
* The identity used to with the `SecretProviderClass` needs to have `Key Vault Secrets User` to access `secret` [object type][keyvault-object-types].
  
## Create an AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name myResourceGroup --location eastus2
    ```

1. Create an AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver capability using the [`az aks create`][az-aks-create] command with the `--enable-addons azure-keyvault-secrets-provider` parameter. The add-on creates a user-assigned managed identity you can use to authenticate to your key vault. The following example creates an AKS cluster with the Azure Key Vault provider for Secrets Store CSI Driver enabled.

    > [!NOTE]
    > If you want to use Microsoft Entra Workload ID, you must also use the `--enable-oidc-issuer` and `--enable-workload-identity` parameters, such as in the following example:
    >
    > ```azurecli-interactive
    > az aks create --name myAKSCluster --resource-group myResourceGroup --enable-addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys
    > ```

    ```azurecli-interactive
    az aks create \
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --enable-addons azure-keyvault-secrets-provider \
        --generate-ssh-keys
    ```

1. The previous command creates a user-assigned managed identity, `azureKeyvaultSecretsProvider`, to access Azure resources. The following example uses this identity to connect to the key vault that stores the secrets, but you can also use other [identity access methods][identity-access-methods]. Take note of the identity's `clientId` in the output.

    ```output
    ...,
     "addonProfiles": {
        "azureKeyvaultSecretsProvider": {
          ...,
          "identity": {
            "clientId": "<client-id>",
            ...
          }
        }
    ```

> [!NOTE]
> After you enable this feature, AKS creates a managed identity named `azurekeyvaultsecretsprovider-xxx` in the node resource group and assigns it to the Virtual Machine Scale Sets (VMSS) automatically. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

## Upgrade an existing AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support

* Upgrade an existing AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver capability using the [`az aks enable-addons`][az-aks-enable-addons] command and enable the `azure-keyvault-secrets-provider` add-on. The add-on creates a user-assigned managed identity you can use to authenticate to your key vault.

    ```azurecli-interactive
    az aks enable-addons --addons azure-keyvault-secrets-provider --name myAKSCluster --resource-group myResourceGroup
    ```

> [!NOTE]
> After you enable this feature, AKS creates a managed identity named `azurekeyvaultsecretsprovider-xxx` in the node resource group and assigns it to the Virtual Machine Scale Sets (VMSS) automatically. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

## Verify the Azure Key Vault provider for Secrets Store CSI Driver installation

1. Get the AKS cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --name myAKSCluster --resource-group myResourceGroup
    ```

1. Verify the installation is finished using the `kubectl get pods` command, which lists all pods with the `secrets-store-csi-driver` and `secrets-store-provider-azure` labels in the kube-system namespace.

    ```bash
    kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'
    ```

    Your output should look similar to the following example output:

    ```output
    NAME                                     READY   STATUS    RESTARTS   AGE
    aks-secrets-store-csi-driver-4vpkj       3/3     Running   2          4m25s
    aks-secrets-store-csi-driver-ctjq6       3/3     Running   2          4m21s
    aks-secrets-store-csi-driver-tlvlq       3/3     Running   2          4m24s
    aks-secrets-store-provider-azure-5p4nb   1/1     Running   0          4m21s
    aks-secrets-store-provider-azure-6pqmv   1/1     Running   0          4m24s
    aks-secrets-store-provider-azure-f5qlm   1/1     Running   0          4m25s
    ```

1. Verify that each node in your cluster's node pool has a Secrets Store CSI Driver pod and a Secrets Store Provider Azure pod running.

## Create or use an existing Azure Key Vault

1. Create or update a key vault with Azure role-based access control (Azure RBAC) enabled using the [`az keyvault create`][az-keyvault-create] command or the [`az keyvault update`][az-keyvault-update] command with the `--enable-rbac-authorization` flag. The name of the key vault must be globally unique. For more details on key vault permission models and Azure RBAC, see [Provide access to Key Vault keys, certificates, and secrets with an Azure role-based access control](/azure/key-vault/general/rbac-guide)

    ```azurecli-interactive
    ## Create a new Azure key vault
    az keyvault create --name <keyvault-name> --resource-group myResourceGroup --location eastus2 --enable-rbac-authorization

    ## Update an existing Azure key vault
    az keyvault update --name <keyvault-name> --resource-group myResourceGroup --location eastus2 --enable-rbac-authorization
    ```

1. Your key vault can store keys, secrets, and certificates. In this example, use the [`az keyvault secret set`][az-keyvault-secret-set] command to set a plain-text secret called `ExampleSecret`.

    ```azurecli-interactive
    az keyvault secret set --vault-name <keyvault-name> --name ExampleSecret --value MyAKSExampleSecret
    ```

1. Take note of the following properties for future use:

   * The name of the secret object in the key vault
   * The object type (secret, key, or certificate)
   * The name of your key vault resource
   * The Azure tenant ID of the subscription

## Next steps

In this article, you learned how to use the Azure Key Vault provider for Secrets Store CSI Driver in an AKS cluster. You now need to provide an identity to access the Azure Key Vault. To learn how, continue to the next article.

> [!div class="nextstepaction"]
> [Provide an identity to access the Azure Key Vault provider for Secrets Store CSI Driver in AKS](./csi-secrets-store-identity-access.md)

<!-- LINKS INTERNAL -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[identity-access-methods]: ./csi-secrets-store-identity-access.md
[az-keyvault-create]: /cli/azure/keyvault#az-keyvault-create.md
[az-keyvault-update]: /cli/azure/keyvault#az-keyvault-update.md
[az-keyvault-secret-set]: /cli/azure/keyvault#az-keyvault-secret-set.md
[az-group-create]: /cli/azure/group#az-group-create
[private-endpoint-keyvault]: /azure/key-vault/general/private-link-service
[fqdns-for-keyvault]: outbound-rules-control-egress.md#azure-key-vault-provider-for-secrets-store-csi-driver
[keyvault-object-types]: /azure/key-vault/general/about-keys-secrets-certificates#object-types

<!-- LINKS EXTERNAL -->
[kube-csi]: https://kubernetes-csi.github.io/docs/
[kubernetes-version-support]: ./supported-kubernetes-versions.md?tabs=azure-cli#kubernetes-version-support-policy
