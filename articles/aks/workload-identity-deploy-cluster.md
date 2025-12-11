---
title: Deploy and configure an Azure Kubernetes Service (AKS) cluster with Microsoft Entra Workload ID
description: This article shows you how to deploy an AKS cluster and configure it with Microsoft Entra Workload ID, including creating a managed identity, Kubernetes service account, and federated identity credential.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.custom: devx-track-azurecli, innovation-engine
ms.date: 05/28/2024
# Customer intent: As a cloud engineer, I want to deploy and configure an Azure Kubernetes Service cluster with workload identity so that my applications can securely authenticate to Azure resources without managing credentials directly.
---

# Deploy and configure Microsoft Entra Workload ID on an Azure Kubernetes Service (AKS) cluster

In this article, you learn how to deploy and configure an Azure Kubernetes Service (AKS) cluster with [Microsoft Entra Workload ID][workload-identity-overview]. The steps in this article include:

- Create a new or update an existing AKS cluster using the Azure CLI with OpenID Connect (OIDC) issuer and Microsoft Entra Workload ID enabled.
- Create a workload identity and Kubernetes service account.
- Configure the managed identity for token federation.
- Deploy the workload and verify authentication with the workload identity.
- Optionally grant a pod in the cluster access to secrets in an Azure key vault.

## Prerequisites

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
- This article requires version 2.47.0 or later of the Azure CLI. If using Azure Cloud Shell, the latest version is already installed.
- Make sure that the identity that you're using to create your cluster has the appropriate minimum permissions. For more information, see [Access and identity options for Azure Kubernetes Service (AKS)][aks-identity-concepts].
- If you have multiple Azure subscriptions, select the appropriate subscription ID in which the resources should be billed using the [`az account set`][az-account-set] command.

> [!NOTE]
> You can use _Service Connector_ to help you configure some steps automatically. For more information, see [Tutorial: Connect to Azure storage account in Azure Kubernetes Service (AKS) with Service Connector using Microsoft Entra Workload ID][tutorial-python-aks-storage-workload-identity].

## Create a resource group

- Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    export RANDOM_ID="$(openssl rand -hex 3)"
    export RESOURCE_GROUP="myResourceGroup$RANDOM_ID"
    export LOCATION="<your-preferred-region>"
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"
    ```

## Enable OIDC issuer and Microsoft Entra Workload ID on an AKS cluster

You can enable OIDC issuer and Microsoft Entra Workload ID on a new or existing AKS cluster.

### [Create a new AKS cluster](#tab/new-cluster)

- Create an AKS cluster using the [`az aks create`][az-aks-create] command with the `--enable-oidc-issuer` parameter to enable OIDC issuer and the `--enable-workload-identity` parameter to enable Microsoft Entra Workload ID. The following example creates a cluster with a single node:

    ```azurecli-interactive
    export CLUSTER_NAME="myAKSCluster$RANDOM_ID"
    az aks create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CLUSTER_NAME}" \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --generate-ssh-keys
    ```

    After a few minutes, the command completes and returns JSON-formatted information about the cluster.

### [Update an existing AKS cluster](#tab/existing-cluster)

- Update an existing AKS cluster to enable OIDC issuer and Microsoft Entra Workload ID using the [`az aks update`][az-aks-update] command with the `--enable-oidc-issuer` and the `--enable-workload-identity` parameters.

    ```azurecli-interactive
    az aks update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CLUSTER_NAME}" \
        --enable-oidc-issuer \
        --enable-workload-identity
    ```

---

## Retrieve the OIDC issuer URL

- Get the OIDC issuer URL and save it to an environmental variable using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "oidcIssuerProfile.issuerUrl" \
        --output tsv)"
    ```

    The environment variable should contain the issuer URL, similar to the following example:

    ```output
    https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/
    ```

    By default, the issuer is set to use the base URL `https://{region}.oic.prod-aks.azure.com/{tenant_id}/{uuid}`, where the value for `{region}` matches the location to which the AKS cluster is deployed. The value `{uuid}` represents the OIDC key, which is a randomly generated and immutable GUID for each cluster.

## Create a managed identity

1. Get your subscription ID and save it to an environment variable using the [`az account show`][az-account-show] command.

    ```azurecli-interactive
    export SUBSCRIPTION="$(az account show --query id --output tsv)"
    ```

1. Create a user-assigned managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    export USER_ASSIGNED_IDENTITY_NAME="myIdentity$RANDOM_ID"
    az identity create \
        --name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --subscription "${SUBSCRIPTION}"
    ```

    The following output example shows successful creation of a managed identity:

    <!-- expected_similarity=0.3 -->
    ```output
    {
      "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroupxxxxxx/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentityxxxxxx",
      "location": "eastus",
      "name": "myIdentityxxxxxx",
      "principalId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "resourceGroup": "myResourceGroupxxxxxx",
      "systemData": null,
      "tags": {},
      "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
    }
    ```

1. Get the client ID of the managed identity and save it to an environment variable using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    export USER_ASSIGNED_CLIENT_ID="$(az identity show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --query 'clientId' \
        --output tsv)"
    ```

## Create a Kubernetes service account

1. Connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}"
    ```

1. Create a Kubernetes service account and annotate it with the client ID of the managed identity by applying the following manifest using the `kubectl apply` command:

    ```azurecli-interactive
    export SERVICE_ACCOUNT_NAME="workload-identity-sa$RANDOM_ID"
    export SERVICE_ACCOUNT_NAMESPACE="default"
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      annotations:
        azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
      name: "${SERVICE_ACCOUNT_NAME}"
      namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
    EOF
    ```

    The following output shows successful creation of the workload identity:

    ```output
    serviceaccount/workload-identity-sa created
    ```

## Create the federated identity credential

- Create a federated identity credential between the managed identity, the service account issuer, and the subject using the [`az identity federated-credential create`][az-identity-federated-credential-create] command.

    ```azurecli-interactive
    export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity$RANDOM_ID"
    az identity federated-credential create \
        --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --issuer "${AKS_OIDC_ISSUER}" \
        --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" \
        --audience api://AzureADTokenExchange
    ```

    > [!NOTE]
    > It takes a few seconds for the federated identity credential to propagate after it's added. If a token request is made immediately after adding the federated identity credential, the request might fail until the cache is refreshed. To avoid this issue, you can add a slight delay after adding the federated identity credential.

For more information about federated identity credentials in Microsoft Entra, see [Overview of federated identity credentials in Microsoft Entra ID][federated-identity-credential].

## Create a key vault with Azure RBAC authorization

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](/azure/key-vault/general/rbac-guide).

1. Create a key vault with purge protection and Azure RBAC authorization enabled using the [`az keyvault create`][az-keyvault-create] command. You can also use an existing key vault if it's configured for both purge protection and Azure RBAC authorization:

    ```azurecli-interactive
    export KEYVAULT_NAME="keyvault-workload-id$RANDOM_ID" # Ensure the key vault name is between 3-24 characters
    az keyvault create \
        --name "${KEYVAULT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --enable-purge-protection \
        --enable-rbac-authorization
    ```

1. Get the key vault resource ID and save it to an environment variable using the [`az keyvault show`][az-keyvault-show] command.

    ```azurecli-interactive
    export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${RESOURCE_GROUP}" \
        --name "${KEYVAULT_NAME}" \
        --query id \
        --output tsv)
    ```

### Assign RBAC permissions for key vault management

1. Get the caller object ID and save it to an environment variable using the [`az ad signed-in-user show`][az-ad-signed-in-user-show] command.

    ```azurecli-interactive
    export CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
    ```

1. Assign yourself the Azure RBAC [Key Vault Secrets Officer](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer) role so that you can create a secret in the new key vault using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --assignee "${CALLER_OBJECT_ID}" \
        --role "Key Vault Secrets Officer" \
        --scope "${KEYVAULT_RESOURCE_ID}"
    ```

### Create and configure secret access

1. Create a secret in the key vault using the [`az keyvault secret set`][az-keyvault-secret-set] command.

    ```azurecli-interactive
    export KEYVAULT_SECRET_NAME="my-secret$RANDOM_ID"
    az keyvault secret set \
        --vault-name "${KEYVAULT_NAME}" \
        --name "${KEYVAULT_SECRET_NAME}" \
        --value "Hello\!"
    ```

1. Get the principal ID of the user-assigned managed identity and save it to an environment variable using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    export IDENTITY_PRINCIPAL_ID=$(az identity show \
        --name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query principalId \
        --output tsv)
    ```

1. Assign the [Key Vault Secrets User](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user) role to the user-assigned managed identity using the [`az role assignment create`][az-role-assignment-create] command. This step gives the managed identity permission to read secrets from the key vault.

    ```azurecli-interactive
    az role assignment create \
        --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" \
        --role "Key Vault Secrets User" \
        --scope "${KEYVAULT_RESOURCE_ID}" \
        --assignee-principal-type ServicePrincipal
    ```

1. Create an environment variable for the key vault URL using the [`az keyvault show`][az-keyvault-show] command:

    ```azurecli-interactive
    export KEYVAULT_URL="$(az keyvault show \
        --resource-group "${RESOURCE_GROUP}" \
        --name ${KEYVAULT_NAME} \
        --query properties.vaultUri \
        --output tsv)"
    ```

## Deploy a verification pod and test access

1. Deploy a pod to verify that the workload identity can access the secret in the key vault. The following example uses the `ghcr.io/azure/azure-workload-identity/msal-go` image, which contains a sample application that retrieves a secret from Azure Key Vault using Microsoft Entra Workload ID:

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
        name: sample-workload-identity-key-vault
        namespace: ${SERVICE_ACCOUNT_NAMESPACE}
        labels:
            azure.workload.identity/use: "true"
    spec:
        serviceAccountName: ${SERVICE_ACCOUNT_NAME}
        containers:
          - image: ghcr.io/azure/azure-workload-identity/msal-go
            name: oidc
            env:
              - name: KEYVAULT_URL
                value: ${KEYVAULT_URL}
              - name: SECRET_NAME
                value: ${KEYVAULT_SECRET_NAME}
        nodeSelector:
            kubernetes.io/os: linux
    EOF
    ```

1. Wait for the pod to be in the `Ready` state using the `kubectl wait` command.

    ```bash
    kubectl wait --namespace ${SERVICE_ACCOUNT_NAMESPACE} --for=condition=Ready pod/sample-workload-identity-key-vault --timeout=120s
    ```

1. Check that the `SECRET_NAME` environment variable is set in the pod using the [`kubectl describe`][kubectl-describe] command.

    ```bash
    kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"
    ```

    If successful, the output should be similar to the following example:

    ```output
    SECRET_NAME: ${KEYVAULT_SECRET_NAME}
    ```

1. Verify that pods can get a token and access the resource using the `kubectl logs` command.

    ```bash
    kubectl logs sample-workload-identity-key-vault
    ```

    If successful, the output should be similar to the following example:

    ```output
    I0114 10:35:09.795900       1 main.go:63] "successfully got secret" secret="Hello\\!"
    ```

    > [!IMPORTANT]
    > Azure RBAC role assignments can take up to 10 minutes to propagate. If the pod is unable to access the secret, you might need to wait for the role assignment to propagate. For more information, see [Troubleshoot Azure RBAC](/azure/role-based-access-control/troubleshooting#).

## Disable Microsoft Entra Workload ID on an AKS cluster

- Disable Microsoft Entra Workload ID on the AKS cluster where it's been enabled and configured, update the AKS cluster using the [`az aks update`][az-aks-update] command with the `--disable-workload-identity` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CLUSTER_NAME}" \
        --disable-workload-identity
    ```

## Related content

In this article, you deployed a Kubernetes cluster and configured it to use Microsoft Entra Workload ID in preparation for application workloads to authenticate with that credential. Now you're ready to deploy your application and configure it to use the workload identity with the latest version of the [Azure Identity][azure-identity-libraries] client library. If you can't rewrite your application to use the latest client library version, you can [set up your application pod][workload-identity-migration] to authenticate using managed identity with workload identity as a short-term migration solution.

The [Service Connector](/azure/service-connector/overview) integration helps simplify the connection configuration for AKS workloads and Azure backing services. It securely handles authentication and network configurations and follows best practices for connecting to Azure services. For more information, see [Connect to Azure OpenAI in Foundry Models in AKS using Microsoft Entra Workload Identity](/azure/service-connector/tutorial-python-aks-openai-workload-identity) and the [Service Connector introduction](https://blog.aks.azure.com/2024/05/23/service-connector-intro).

<!-- EXTERNAL LINKS -->
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe

<!-- INTERNAL LINKS -->
[workload-identity-overview]: workload-identity-overview.md
[az-group-create]: /cli/azure/group#az-group-create
[aks-identity-concepts]: concepts-identity.md
[federated-identity-credential]: /graph/api/resources/federatedidentitycredentials-overview
[tutorial-python-aks-storage-workload-identity]: /azure/service-connector/tutorial-python-aks-storage-workload-identity
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-account-set]: /cli/azure/account#az-account-set
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az-identity-federated-credential-create
[workload-identity-migration]: workload-identity-migrate-from-pod-identity.md
[azure-identity-libraries]: /azure/active-directory/develop/reference-v2-libraries
