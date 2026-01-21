---
title: Set up identity bindings on Azure Kubernetes Service (AKS) (preview)
description: Learn how to enable and configure identity bindings on AKS to map a user-assigned managed identity (UAMI) across multiple clusters while using a single federated identity credential.
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 12/13/2025
ms.custom: preview
author: shashankbarsin
ms.author: shasb
ms.reviewer: schaffererin
# Customer intent: "As an AKS operator, I want to configure identity bindings so my workloads can scale Microsoft Entra authentication across many clusters without hitting federated identity credential limits."
---

# Set up identity bindings on Azure Kubernetes Service (AKS) (preview)

Set up [identity bindings](./identity-bindings-concepts.md) on your Azure Kubernetes Service (AKS) clusters to map a user-assigned managed identity (UAMI) across multiple clusters while using a single federated identity credential (FIC). This setup helps you scale Microsoft Entra authentication for workloads without hitting FIC limits.

## Prerequisites

- Review [Identity bindings concepts][identity-bindings-concepts] to understand how identity bindings works.
- Azure CLI version 2.73.0 or later. To check your version, use the `az version` command. To install or update the Azure CLI, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- The [Azure CLI `aks-preview` extension version `18.0.0b26` or later installed](#install-or-update-the-aks-preview-extension).
- The [`IdentityBindingPreview` feature flag enabled for your subscription](#enable-the-identitybindingpreview-feature-flag).
- You need the following Azure permissions on the identity and cluster scope: `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write` and `Microsoft.ContainerService/managedClusters/write`.
- You need Kubernetes cluster admin (or equivalent) permissions to create `ClusterRole` and `ClusterRoleBinding` resources.

### Install or update the `aks-preview` extension

- Install or update the Azure CLI `aks-preview` extension to the latest version using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`]( /cli/azure/extension#az-extension-update) command:

    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update to the latest version if already installed
    az extension update --name aks-preview
    ```

### Enable the `IdentityBindingPreview` feature flag

1. Register the `IdentityBindingPreview` feature flag on your Azure subscription using the [`az feature register`]( /cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name IdentityBindingPreview
    ```

    Feature registration can take up to 15 minutes to complete.

1. Wait for the feature to finish registering using the [`az feature show`]( /cli/azure/feature#az-feature-show) command.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name IdentityBindingPreview
    ```

1. Once the feature shows as `Registered`, refresh the provider registration using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Limitations

- Identity bindings aren't yet supported on clusters configured with [API server VNet integration][api-server-vnet-integration].

## Create environment variables for test resources

- Create the following environment variables to use when creating test resources. You can replace the placeholder values with your own if desired.

    ```azurecli-interactive
    export RESOURCE_GROUP="ib-test"
    export LOCATION="westus2"
    export CLUSTER_NAME="ib-test-cluster"
    export MI_NAME="ib-test-mi"
    ```

## Create test resources

1. Create an Azure resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

1. Create an AKS cluster with workload identity and OIDC issuer enabled using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--enable-workload-identity` and `--enable-oidc-issuer` flags.

    ```azurecli-interactive
    az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --location $LOCATION --no-ssh-key --enable-workload-identity --enable-oidc-issuer
    ```

1. Create a user-assigned managed identity (UAMI) using the [`az identity create`](/cli/azure/identity#az-identity-create) command.

    ```azurecli-interactive
    az identity create --resource-group $RESOURCE_GROUP --name $MI_NAME
    ```

## Verify the workload identity webhook version

- Identity binding requires the preview version of the AKS workload identity webhook. Verify the installed webhook version using the following `kubectl get pods` command:

    ```bash
    kubectl -n kube-system get pods -l azure-workload-identity.io/system=true -o yaml | grep v1.6.0
    ```

    The output should show `v1.6.0-alpha.1` in the image tag, which confirms the correct version is installed.

## Get the UAMI resource ID

- Get the resource ID of the UAMI using the [`az identity show`](/cli/azure/identity#az-identity-show) command and set it as an environment variable:

    ```azurecli-interactive
    export MI_RESOURCE_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $MI_NAME --query id -o tsv)
    ```

## Create an identity binding

- Map the UAMI to the AKS cluster with an identity binding using the [`az aks identity-binding create`](/cli/azure/aks/identity-binding#az-aks-identity-binding-create) command.

    ```azurecli-interactive
    az aks identity-binding create --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name "${MI_NAME}-ib" --managed-identity-resource-id $MI_RESOURCE_ID
    ```

    > [!NOTE]
    > When you create an identity binding, AKS automatically creates a federated identity credential (FIC) named `aks-identity-binding` under the UAMI. This credential is managed by AKS. Don't modify or delete it while identity bindings are in use. The FIC created for identity bindings is shared across all identity bindings referencing the same UAMI.

## Get the OIDC issuer URL for the UAMI

- Get the OIDC issuer URL associated with the UAMI by inspecting the identity binding using the [`az aks identity-binding show`](/cli/azure/aks/identity-binding#az-aks-identity-binding-show) command.

    ```azurecli-interactive
    az aks identity-binding show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name "${MI_NAME}-ib"
    ```

    Condensed example output:

    ```output
    {
      "oidcIssuer": {
        "oidcIssuerUrl": "https://ib.oic.prod-aks.azure.com/<MI-tenant-id>/<MI-client-id>"
      }
    }
    ```

## Connect to the AKS cluster

1. Get the AKS cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command and save them to a separate kubeconfig file:

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME -a -f "${CLUSTER_NAME}.kubeconfig"
    ```

1. Set the `KUBECONFIG` environment variable to point to the new kubeconfig file:

    ```bash
    export KUBECONFIG="$(pwd)/${CLUSTER_NAME}.kubeconfig"
    ```

## Get the UAMI client ID

- Get the client ID of the UAMI using the [`az identity show`](/cli/azure/identity#az-identity-show) command and set it as an environment variable:

    ```azurecli-interactive
    export MI_CLIENT_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $MI_NAME --query clientId -o tsv)
    ```

## Authorize namespaces and service accounts

- Configure role-based access control (RBAC) to grant specific subjects the permission to use the managed identity via identity binding by applying the following manifest using with the following `kubectl apply` command.

    > [!NOTE]
    > The following example explicitly refers to the `demo` service account in the `demo` namespace. While explicitly referring to a specific service account is one option, it's also possible to refer to a collection of service accounts under `subjects`. For more information, see [Referring to subjects][k8s-rbac-subjects] in the Kubernetes documentation.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Namespace
    metadata:
      name: demo
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: demo
      namespace: demo
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: use-mi-${MI_CLIENT_ID}
    rules:
      - verbs: ["use-managed-identity"]
        apiGroups: ["cid.wi.aks.azure.com"]
        resources: ["${MI_CLIENT_ID}"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: use-mi-${MI_CLIENT_ID}
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: use-mi-${MI_CLIENT_ID}
    subjects:
      - kind: ServiceAccount
        name: demo
        namespace: demo
    EOF
    ```

## Create a key vault and configure access

LEFT OFF HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

The instructions in this step show how to access secrets, keys, or certificates in an Azure key vault from the pod. The examples in this section configure access to secrets in the key vault for the workload identity, but you can perform similar steps to configure access to keys or certificates.

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](/azure/key-vault/general/rbac-guide).

1. Create a key vault with purge protection and Azure RBAC authorization enabled. You can also use an existing key vault if it's configured for both purge protection and Azure RBAC authorization:

    ```azurecli-interactive
    export KEYVAULT_NAME="ib-test"
    # Ensure the key vault name is between 3-24 characters
    if [ ${#KEYVAULT_NAME} -gt 24 ]; then
        KEYVAULT_NAME="${KEYVAULT_NAME:0:24}"
    fi
    az keyvault create \
        --name "${KEYVAULT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --enable-purge-protection \
        --enable-rbac-authorization
    ```

1. Assign yourself the Azure RBAC [Key Vault Secrets Officer](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer) role so that you can create a secret in the new key vault:

    ```azurecli-interactive
    export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${RESOURCE_GROUP}" \
        --name "${KEYVAULT_NAME}" \
        --query id \
        --output tsv)

    export CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

    az role assignment create --assignee "${CALLER_OBJECT_ID}" \
        --role "Key Vault Secrets Officer" \
        --scope "${KEYVAULT_RESOURCE_ID}"
    ```

1. Create a secret in the key vault:

    ```azurecli-interactive
    export KEYVAULT_SECRET_NAME="my-secret"
    az keyvault secret set \
        --vault-name "${KEYVAULT_NAME}" \
        --name "${KEYVAULT_SECRET_NAME}" \
        --value "Hello\!"
    ```

1. Assign the [Key Vault Secrets User](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user) role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

    ```azurecli-interactive
    export IDENTITY_PRINCIPAL_ID=$(az identity show \
        --name "${MI_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query principalId \
        --output tsv)

    az role assignment create \
        --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" \
        --role "Key Vault Secrets User" \
        --scope "${KEYVAULT_RESOURCE_ID}" \
        --assignee-principal-type ServicePrincipal
    ```

1. Create an environment variable for the key vault URL:

    ```azurecli-interactive
    export KEYVAULT_URL="$(az keyvault show \
        --resource-group ${RESOURCE_GROUP} \
        --name ${KEYVAULT_NAME} \
        --query properties.vaultUri \
        --output tsv)"
    ```

1. Annotate the service account with the managed identity information:

    ```bash
    export MI_TENANT_ID=$(az identity show -g $RESOURCE_GROUP -n $MI_NAME --query tenantId -o tsv)
    export MI_CLIENT_ID=$(az identity show -g $RESOURCE_GROUP -n $MI_NAME --query clientId -o tsv)
    
    kubectl annotate sa demo -n demo azure.workload.identity/tenant-id=$MI_TENANT_ID
    kubectl annotate sa demo -n demo azure.workload.identity/client-id=$MI_CLIENT_ID
    ```

1. Deploy the sample pod that uses identity binding to obtain an access token for the managed identity to access Azure Key Vault:

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo
      namespace: demo
      labels:
        azure.workload.identity/use: "true"
      annotations:
        azure.workload.identity/use-identity-binding: "true"
    spec:
      serviceAccount: demo
      containers:
        - name: azure-sdk
          # source code: https://github.com/Azure/azure-workload-identity/blob/feature/custom-token-endpoint/examples/identitybinding-msal-go/main.go
          image: ghcr.io/bahe-msft/azure-workload-identity/identitybinding-msal-go:latest-linux-amd64
          env:
            - name: KEYVAULT_URL
              value: ${KEYVAULT_URL}
            - name: SECRET_NAME
              value: ${KEYVAULT_SECRET_NAME}
      restartPolicy: Never
    EOF
    ```

1. Describe the pod and confirm environment variables and projected token volume mounts are present:

    ```bash
    kubectl describe pod demo -n demo
    ```

    Expected output should contain values for `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_FEDERATED_TOKEN_FILE`, `AZURE_AUTHORITY_HOST`, `AZURE_KUBERNETES_TOKEN_PROXY`. `AZURE_KUBERNETES_SNI_NAME`, and `AZURE_KUBERNETES_CA_FILE`.

1. To verify that the pod is able to get a token and access the resource, use the `kubectl logs` command:

    ```bash
    kubectl logs demo -n demo
    ```

    If successful, the output should be similar to the following example:

    ```output
    I1107 20:03:42.865180       1 main.go:77] "successfully got secret" secret="Hello!"
    ```

## Scale out usage across clusters

Identity bindings allow mapping multiple AKS clusters to the same UAMI while still using a single FIC. Repeat the steps from "Create an identity binding" through "Deploy sample application" for additional clusters (creating a new identity binding per cluster) to validate scaled usage patterns.

## Clean up (optional)

Delete resources when finished:

```bash
kubectl delete pod demo -n demo
kubectl delete ns demo
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Next steps

* Review [Identity bindings concepts][identity-bindings-concepts].
* Explore creating additional identity bindings for the same managed identity across more clusters.

<!-- INTERNAL LINKS -->
[identity-bindings-concepts]: identity-bindings-concepts.md
[workload-identity-overview]: workload-identity-overview.md
[general-federated-identity-credential-considerations]: /azure/active-directory/workload-identities/workload-identity-federation-considerations#general-federated-identity-credential-considerations
[managed-identities-overview]: /azure/active-directory/managed-identities-azure-resources/overview
[api-server-vnet-integration]: /azure/aks/api-server-vnet-integration

<!-- EXTERNAL LINKS -->
[k8s-rbac-subjects]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects
[jwt-ms]: https://jwt.ms/
