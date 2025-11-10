---
title: Set up identity bindings on AKS (Preview)
description: Learn how to enable and configure identity bindings on Azure Kubernetes Service (AKS) to map a user-assigned managed identity (UAMI) across multiple clusters while using a single federated identity credential.
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 11/10/2025
ms.custom: preview
author: shashankbarsin
ms.author: shasb
# Customer intent: As an AKS operator, I want to configure identity bindings so my workloads can scale Microsoft Entra authentication across many clusters without hitting federated identity credential limits.
---

# Set up identity bindings on Azure Kubernetes Service (AKS) (Preview)

## Prerequisites

1. Install or update the Azure CLI `aks-preview` extension version `18.0.0b26` or later.

    ```bash
    # Install the aks-preview extension
    az extension add --name aks-preview

    # Update to the latest version if already installed
    az extension update --name aks-preview
    ```

1. Register the `IdentityBinding` feature flag:

    ```bash
    # Register the feature flag
    az feature register --namespace Microsoft.ContainerService --name IdentityBinding

    # Wait for registration to complete (this may take several minutes)
    az feature show --namespace Microsoft.ContainerService --name IdentityBinding

    # Refresh the provider registration
    az provider register --namespace Microsoft.ContainerService
    ```

    > [!NOTE]
    > Feature registration can take 10-15 minutes to complete. You can proceed with the next steps once the feature shows as "Registered".

1. Ensure the following Azure permissions on the identity and cluster scope:
   - `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write`
   - `Microsoft.ContainerService/managedClusters/write`

1. Ensure Kubernetes cluster admin (or equivalent) permissions to create `ClusterRole` and `ClusterRoleBinding` resources.

## Create test resources

Create a resource group, an AKS cluster with workload identity enabled, and a user-assigned managed identity (UAMI):

```bash
export RESOURCE_GROUP="ib-test"
export LOCATION="westus2"
export CLUSTER="ibtest"
export MI_NAME="ib-test-mi"

az group create --name $RESOURCE_GROUP -l $LOCATION
az aks create -g $RESOURCE_GROUP -n $CLUSTER -l $LOCATION --no-ssh-key --enable-workload-identity --enable-oidc-issuer
az identity create -g $RESOURCE_GROUP -n $MI_NAME
```

 Identity Binding requires preview version of AKS workload identity webhook. Please confirm the following output from the command:

```bash
kubectl -n kube-system get pods -l azure-workload-identity.io/system=true -o yaml | grep v1.6.0
```

Seeing `v1.6.0-alpha.1` in the image tag confirms that the preview version of webhook is installed.

## Create an identity binding

Map the managed identity to the AKS cluster with an identity binding:

```bash
export MI_RESOURCE_ID=$(az identity show -g $RESOURCE_GROUP -n $MI_NAME --query id -o tsv)
az aks identity-binding create -g $RESOURCE_GROUP --cluster-name $CLUSTER -n "${MI_NAME}-ib" --managed-identity-resource-id $MI_RESOURCE_ID
```

## Retrieve the OIDC issuer URL

Inspect the identity binding to get the OIDC issuer URL associated with this UAMI:

```bash
az aks identity-binding show -g $RESOURCE_GROUP --cluster-name $CLUSTER -n "${MI_NAME}-ib"
```

Example output (other fields omitted):

```json
{
  "oidcIssuer": {
    "oidcIssuerUrl": "https://ib.oic.prod-aks.azure.com/<MI-tenant-id>/<MI-client-id>"
  }
}
```

AKS automatically creates a federated identity credential (FIC) named `aks-identity-binding` under the managed identity. This credential is managed by AKS—don't modify or delete it while identity bindings are in use.

:::image type="content" source="media/identity-bindings/identity-bindings-federated-identity-credentials.png" lightbox="media/identity-bindings/identity-bindings-federated-identity-credentials.png" alt-text="Screenshot showing the federated identity credential created by identity bindings in the Azure portal." :::

> [!NOTE]
> The FIC created for identity bindings is shared across all identity bindings referencing the same UAMI.

## Authorize namespaces and service accounts

Configure RBAC to grant specific subjects the permission to use the managed identity via identity binding.

```bash
az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER -a -f "${CLUSTER}.kubeconfig"
export KUBECONFIG="$(pwd)/${CLUSTER}.kubeconfig"
export MI_CLIENT_ID=$(az identity show -g $RESOURCE_GROUP -n $MI_NAME --query clientId -o tsv)

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

## Deploy sample application

The instructions in this step show how to access secrets, keys, or certificates in an Azure key vault from the pod. The examples in this section  configure access to secrets in the key vault for the workload identity, but you can perform similar steps to configure access to keys or certificates.

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](/azure/key-vault/general/rbac-guide).

1. Create a key vault with purge protection and Azure RBAC authorization enabled. You can also use an existing key vault if it's configured for both purge protection and Azure RBAC authorization:

    ```azurecli-interactive
    export KEYVAULT_NAME="keyvault-workload-id"
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
    export KEYVAULT_SECRET_NAME="my-secret$RANDOM_ID"
    az keyvault secret set \
        --vault-name "${KEYVAULT_NAME}" \
        --name "${KEYVAULT_SECRET_NAME}" \
        --value "Hello\!"
    ```

1. Assign the [Key Vault Secrets User](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user) role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

    ```azurecli-interactive
    export IDENTITY_PRINCIPAL_ID=$(az identity show \
        --name "${USER_ASSIGNED_IDENTITY_NAME}" \
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

1. Deploy the sample pod that uses identity binding to obtain access token for the managed identity to access Azure Key Vault:

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
      image: ghcr.io/bahe-msft/azure-workload-identity/identitybinding-msal-go@sha256:d8a262e2aed015790335650f1d1221cbf9270ee209993337e4c6055b39dd00ae
      env:
        - name: KEYVAULT_URL
          value: https://<your-keyvault-name>.vault.azure.net/
        - name: SECRET_NAME
          value: <secret-name>
  restartPolicy: Never
EOF
```

1. Describe the pod and confirm environment variables and projected token volume mounts are present:

```bash
kubectl describe pod demo -n demo
```

:::image type="content" source="media/identity-bindings/identity-bindings-demo-pod-describe.png" lightbox="media/identity-bindings/identity-bindings-demo-pod-describe.png" alt-text="Screenshot showing the results of describing the demo pod with identity binding environment variables and volume mounts." :::


1. To verify that pod is able to get a token and access the resource, use the kubectl logs command:

Verify the sample application pod
```bash
kubectl logs demo -n demo
```

If successful, the output should be similar to the following example:

```output
I1107 20:03:42.865180       1 main.go:77] "successfully got secret" secret="Hello!"
```

## Scale out usage across clusters

Identity bindings allow mapping multiple AKS clusters to the same UAMI while still using a single FIC. Repeat the steps from "Create an identity binding" through "Acquire a Microsoft Entra access token" for additional clusters (creating a new identity binding per cluster) to validate scaled usage patterns.

## Troubleshooting

| Symptom | Possible cause | Resolution |
|---------|----------------|-----------|
| Identity binding creation fails | Missing FIC create permissions | Assign role with `federatedIdentityCredentials/write` on the UAMI scope. |
| Pod missing workload identity env vars | Missing label `azure.workload.identity/use: true` | Add the label and restart the pod. |
| Token request times out | Egress/network interception issues | Verify cluster can reach identity binding proxy endpoint and no network policies block traffic. |
| Access token missing expected claims | Incorrect service account annotations | Reapply correct `tenant-id` and `client-id` annotations and restart pod. |

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

<!-- EXTERNAL LINKS -->
[general-federated-identity-credential-considerations]: /azure/active-directory/workload-identities/workload-identity-federation-considerations#general-federated-identity-credential-considerations
[managed-identities-overview]: /azure/active-directory/managed-identities-azure-resources/overview
[jwt-ms]: https://jwt.ms/
