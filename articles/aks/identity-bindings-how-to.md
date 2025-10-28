---
title: Set up identity bindings on AKS (Preview)
description: Learn how to enable and configure identity bindings on Azure Kubernetes Service (AKS) to map a user-assigned managed identity (UAMI) across multiple clusters while using a single federated identity credential.
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 10/27/2025
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
2. Register the `IdentityBinding` feature flag:

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

3. Ensure the following Azure permissions on the identity and cluster scope:
   - `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write`
   - `Microsoft.ContainerService/managedClusters/write`

4. Ensure Kubernetes cluster admin (or equivalent) permissions to create `ClusterRole` and `ClusterRoleBinding` resources.

## Create test resources

Create a resource group, an AKS cluster with workload identity enabled, and a user-assigned managed identity (UAMI):

```bash
export RESOURCE_GROUP="ib-test"
export LOCATION="westus2"
export CLUSTER="ibtest"
export MI_NAME="ib-test-mi"

az group create --name $RESOURCE_GROUP -l $LOCATION
az aks create -g $RESOURCE_GROUP -n $CLUSTER -l $LOCATION --no-ssh-key --enable-workload-identity
az identity create -g $RESOURCE_GROUP -n $MI_NAME
```

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

:::image type="content" source="media/identity-bindings/identity-bindings-fic.png" lightbox="media/identity-bindings/identity-bindings-fic.png" alt-text="Screenshot showing the federated identity credential created by identity bindings in the Azure portal." :::

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

## Annotate the service account

Add required annotations so the pod can use workload identity with identity binding:

```bash
export MI_TENANT_ID=$(az identity show -g $RESOURCE_GROUP -n $MI_NAME --query tenantId -o tsv)
kubectl annotate sa demo -n demo azure.workload.identity/tenant-id=$MI_TENANT_ID --overwrite
kubectl annotate sa demo -n demo azure.workload.identity/client-id=$MI_CLIENT_ID --overwrite
```

## Deploy a test workload

Deploy a pod with labels and annotations enabling workload identity and identity binding usage:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-shell
  namespace: demo
  labels:
    azure.workload.identity/use: "true"
  annotations:
    azure.workload.identity/use-identity-binding: "true"
spec:
  serviceAccountName: demo
  containers:
    - name: azure-cli
      image: mcr.microsoft.com/azure-cli:cbl-mariner2.0
      command: ["bash", "-c", "sleep infinity"]
  restartPolicy: Never
EOF
```

Wait for the pod to be ready:

```bash
kubectl get pod -n demo
```

## Validate pod configuration

Describe the pod and confirm environment variables and projected token volume mounts are present:

```bash
kubectl describe pod test-shell -n demo
```

:::image type="content" source="media/identity-bindings/identity-bindings-demo-pod-describe.png" lightbox="media/identity-bindings/identity-bindings-demo-pod-describe.png" alt-text="Screenshot showing the results of describing the demo pod with identity binding environment variables and volume mounts." :::

> [!TIP]
> Look for mounted token volumes and environment variables related to Azure workload identity. Their presence indicates correct mutation.

## Acquire a Microsoft Entra access token

Exec into the pod and use `curl` to request a token via the identity binding proxy:

```bash
kubectl exec -it test-shell -n demo -- bash

curl "https://${AZURE_KUBERNETES_SNI_NAME}" \
  --cacert $AZURE_KUBERNETES_CA_FILE \
  --resolve "${AZURE_KUBERNETES_SNI_NAME}:443:10.0.0.1" \
  -d "grant_type=client_credentials" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "scope=https://management.azure.com//.default" \
  -d "client_assertion=$(cat $AZURE_FEDERATED_TOKEN_FILE)" \
  -d "client_id=$AZURE_CLIENT_ID"
```

You can copy the returned `access_token` value and paste it into [jwt.ms][jwt-ms] to decode and inspect the claims.

:::image type="content" source="media/identity-bindings/identity-bindings-entra-token.png" lightbox="media/identity-bindings/identity-bindings-entra-token.png" alt-text="Screenshot showing the decoded Microsoft Entra access token in jwt.ms." :::

## Scale out usage across clusters

Identity bindings allow mapping multiple AKS clusters to the same UAMI while still using a single FIC. Repeat steps 2–8 for additional clusters (creating a new identity binding per cluster) to validate scaled usage patterns.

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
kubectl delete pod test-shell -n demo
kubectl delete ns demo
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Next steps

* Review [Identity bindings concepts][identity-bindings-concepts].
* Explore creating additional bindings for the same managed identity across more clusters.
* Plan RBAC governance to track which namespaces and service accounts can acquire tokens via identity bindings.

<!-- INTERNAL LINKS -->
[identity-bindings-concepts]: identity-bindings-concepts.md
[workload-identity-overview]: workload-identity-overview.md

<!-- EXTERNAL LINKS -->
[general-federated-identity-credential-considerations]: /azure/active-directory/workload-identities/workload-identity-federation-considerations#general-federated-identity-credential-considerations
[managed-identities-overview]: /azure/active-directory/managed-identities-azure-resources/overview
[jwt-ms]: https://jwt.ms/
