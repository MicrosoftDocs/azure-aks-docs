---
title: Configure Azure DNS and TLS with the Application Routing Gateway API Implementation
description: Use the Application Routing add-on to automatically manage Azure DNS records and Azure Key Vault TLS certificates for ingress traffic on Azure Kubernetes Service (AKS) with the Kubernetes Gateway API.
ms.subservice: aks-networking
ms.custom: devx-track-azurecli, biannual
author: jaiveerk
ms.topic: how-to
ms.date: 06/10/2026
ms.author: jkatariya
# Customer intent: As a cloud engineer, I want the Application Routing add-on to manage Azure DNS records and TLS certificates from Azure Key Vault for my Gateway API ingress traffic, so that I do not have to manually configure the SecretProviderClass, the synced Kubernetes Secret, the listener certificateRefs, or the external-dns deployment.
---

# Configure Azure DNS and TLS with the Application Routing Gateway API implementation

With the [Application Routing Gateway API][app-routing-gateway-api], users can easily expose HTTPS applications on AKS with their own Azure Key Vault certificates, including automatic Domain Name publication. The Application Routing operator integrates with Azure DNS and Azure Key Vault, and reconciles a `SecretProviderClass`, a Kubernetes Secret for TLS certificates, the listener `certificateRefs` field, and the separate `external-dns` Deployment so you don't have to manage these resources manually.

This article shows you how to:

- Provision the prerequisite Azure resources (Azure DNS zone, Azure Key Vault, user-assigned managed identity, role assignments, and federated identity credentials).
- Configure a `Gateway` listener to terminate TLS using a certificate stored in Azure Key Vault via the `kubernetes.azure.com/tls-cert-keyvault-uri` and `kubernetes.azure.com/tls-cert-service-account` listener TLS options.
- Use the `ClusterExternalDNS` and `ExternalDNS` custom resources to publish DNS records to Azure DNS based on the hostnames of your `Gateway`, `HTTPRoute`, and `GRPCRoute` resources.

## How the integration works

The Application Routing operator exposes two integrations to automate the resources you would otherwise create by hand to bring a `Gateway` resource online with a custom domain and TLS termination.

### TLS integration

When a `Gateway` resource uses the `approuting-istio` GatewayClass and a listener carries the following two TLS options, the Application Routing operator reconciles the resources needed to terminate TLS with a certificate stored in Azure Key Vault:

| TLS option key | Value |
|---|---|
| `kubernetes.azure.com/tls-cert-keyvault-uri` | The Azure Key Vault certificate URI to source the TLS certificate from. Use an unversioned URI (for example, `https://<vault>.vault.azure.net/certificates/<cert>`) so the operator automatically picks up certificate rotations in Azure Key Vault. |
| `kubernetes.azure.com/tls-cert-service-account` | The name of a Kubernetes ServiceAccount in the same namespace as the `Gateway`. The ServiceAccount must be bound to a user-assigned managed identity via Microsoft Entra Workload Identity, and that managed identity must have the `Key Vault Secrets User` role on the target Azure Key Vault. |

For each listener that carries both TLS options, the operator:

1. Provisions a `SecretProviderClass` named `kv-gw-cert-<gateway-name>-<listener-name>` in the `Gateway`'s namespace, configured to source the certificate from Azure Key Vault using workload identity authentication.
2. Triggers the Azure Key Vault provider for Secrets Store CSI Driver to sync the certificate as a `kubernetes.io/tls` Kubernetes Secret of the same name in the `Gateway`'s namespace.
3. Patches the listener's `tls.certificateRefs` field to reference the synced Kubernetes Secret.

### DNS integration

The Application Routing operator manages an `external-dns` instance for you through two custom resources:

| Custom resource | Scope |
|---|---|
| `ClusterExternalDNS` (`clusterexternaldnses.approuting.kubernetes.azure.com`) | Cluster-scoped. Watches `Gateway`, `HTTPRoute`, and `GRPCRoute` resources across all namespaces in the cluster. |
| `ExternalDNS` (`externaldnses.approuting.kubernetes.azure.com`) | Namespace-scoped. Watches only `Gateway`, `HTTPRoute`, and `GRPCRoute` resources in the same namespace as the custom resource. |

Both custom resources accept optional `filters` selectors to further narrow which resources the managed `external-dns` instance observes within its scope:

| Filter | What it narrows |
|---|---|
| `filters.gatewayLabels` | Restricts which `Gateway` resources the controller observes. |
| `filters.routeAndIngressLabels` | Restricts which `HTTPRoute` and `Ingress` resources the controller observes. |

For each custom resource, the Application Routing operator:

1. Deploys a managed `external-dns` instance, configured to source records from `HTTPRoute` and `GRPCRoute` resources, and targets the specified Azure DNS zones.
2. Authenticates to Azure DNS using Microsoft Entra Workload Identity, via the ServiceAccount referenced in the `identity` field of the custom resource.
3. Publishes A records to each of the listed Azure DNS zones for every `HTTPRoute` or `GRPCRoute` hostname that is bound to a managed `Gateway` resource in scope.

## Prerequisites

- An AKS cluster with **both** of the following features enabled:
  - The [Application Routing add-on][app-routing-nginx] (`--enable-app-routing`). This add-on deploys the Application Routing operator on the cluster, which is the component that reconciles the DNS and TLS integrations documented in this article. On an existing cluster, you can also enable this feature by using [`az aks approuting enable`][az-aks-approuting-enable].
  - The [Application Routing Gateway API implementation][app-routing-gateway-api] (`--enable-app-routing-istio`). This flag enables the Gateway API control plane (`approuting-istio` GatewayClass) that the Application Routing operator integrates with. On an existing cluster, you can also enable this feature by using [`az aks approuting gateway istio enable`][az-aks-approuting-gateway-istio-enable].

  Both flags are required: enabling only one of them leaves the integration unavailable. You can enable both at cluster creation time on [`az aks create`][az-aks-create], or on an existing cluster by using [`az aks update`][az-aks-update] (or the `approuting` subcommands described earlier).
- The [Managed Gateway API installation][managed-gateway-api] enabled on the cluster.
- The [Microsoft Entra Workload Identity][workload-identity-overview] feature enabled on the cluster, along with the [OIDC issuer][oidc-issuer-overview]. You can enable both features by using the `--enable-oidc-issuer` and `--enable-workload-identity` flags on [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update].
- The [Azure Key Vault provider for Secrets Store CSI Driver][csi-secrets-store-driver] add-on enabled on the cluster. You can enable it by using the [`az aks enable-addons`][az-aks-enable-addons] command with `--addons azure-keyvault-secrets-provider`, or by passing `--enable-kv` to [`az aks approuting enable`][az-aks-approuting-enable] or [`az aks approuting update`][az-aks-approuting-update].
- Azure CLI version `2.86.0` or higher. Run `az --version` to find your `azure-cli` version, and run `az upgrade` to upgrade.
- Sufficient Azure role-based access control (RBAC) on your own identity to create role assignments and federated identity credentials. The `Owner` role or a combination of `Role Based Access Control Administrator` and `Managed Identity Contributor` is sufficient.

> [!NOTE]
> The `--attach-kv` and `--attach-zones` flags on [`az aks approuting update`][az-aks-approuting-update] (and the [`az aks approuting zone`][az-aks-approuting-zone] subcommands) are designed for the legacy NGINX-based experience, where the Application Routing add-on's own user-assigned managed identity is granted Azure RBAC access to a single Azure Key Vault and DNS zone. They aren't used by the Gateway API integration documented in this article. The new experience is driven by Microsoft Entra Workload Identity instead of the add-on's managed identity, so you need to create your own user-assigned managed identity, grant it the appropriate Azure DNS and Azure Key Vault roles, and create federated identity credentials that bind it to the Kubernetes ServiceAccounts you reference in your `Gateway` listener TLS options and your `ExternalDNS`/`ClusterExternalDNS` custom resources.

Set the following environment variables. The walkthrough reuses them in every subsequent command:

```bash
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER=<cluster-name>
export LOCATION=<azure-region>
```

Pull cluster credentials for `kubectl`:

```azurecli-interactive
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER
```

## Create the Azure infrastructure

### Create the Azure DNS zone

If you already have an Azure DNS zone that you want the Application Routing operator to manage records in, you can skip this step and assign the value of `ZONE_NAME` to your existing zone name.

```azurecli-interactive
export ZONE_NAME=<dns-zone-name>
az network dns zone create --resource-group $RESOURCE_GROUP --name $ZONE_NAME
export ZONE_ID=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $ZONE_NAME --query id -o tsv)
```

### Create the Azure Key Vault and certificate

Create the Azure Key Vault that stores the TLS certificate. Configure the vault to use Azure RBAC for authorization, which is the [recommended permission model][akv-rbac-vs-policy]:

```azurecli-interactive
export KV_NAME=<key-vault-name>
az keyvault create \
  --name $KV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true
```

> [!NOTE]
> To create the certificate in the next step, your own Azure identity needs the `Key Vault Certificates Officer` role (or `Key Vault Administrator`) on the vault. Grant this role on the vault before continuing.

Create a self-signed wildcard certificate in Azure Key Vault. For production deployments, import a certificate authority (CA)-signed certificate by using [`az keyvault certificate import`][az-keyvault-certificate-import] instead.

```azurecli-interactive
cat > cert-policy.json <<EOF
{
  "issuerParameters": { "name": "Self" },
  "keyProperties": { "exportable": true, "keyType": "RSA", "keySize": 2048, "reuseKey": false },
  "secretProperties": { "contentType": "application/x-pkcs12" },
  "x509CertificateProperties": {
    "subject": "CN=*.${ZONE_NAME}",
    "subjectAlternativeNames": { "dnsNames": ["*.${ZONE_NAME}", "${ZONE_NAME}"] },
    "validityInMonths": 12,
    "keyUsage": ["digitalSignature", "keyEncipherment"]
  }
}
EOF

az keyvault certificate create \
  --vault-name $KV_NAME \
  --name approuting-demo-cert \
  --policy @cert-policy.json
```

Capture the unversioned certificate URI. The Application Routing operator uses this URI to configure the `SecretProviderClass`. An unversioned URI ensures the operator picks up new certificate versions in Azure Key Vault as the certificate is rotated.

```azurecli-interactive
export CERT_URI=$(az keyvault certificate show \
  --vault-name $KV_NAME \
  --name approuting-demo-cert \
  --query id -o tsv | sed 's|/[^/]*$||')
echo "Cert URI: $CERT_URI"
```

### Create the user-assigned managed identity and grant Azure RBAC roles

Create a user-assigned managed identity that the Application Routing operator's `external-dns` deployment and the gateway listener's TLS sync use to authenticate to Azure DNS and Azure Key Vault.

```azurecli-interactive
export UAMI_NAME=<managed-identity-name>
az identity create --resource-group $RESOURCE_GROUP --name $UAMI_NAME --location $LOCATION
export UAMI_CLIENT_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $UAMI_NAME --query clientId -o tsv)
export UAMI_PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $UAMI_NAME --query principalId -o tsv)
```

Grant the managed identity the `DNS Zone Contributor` role on the target Azure DNS zone and the `Key Vault Secrets User` role on the target Azure Key Vault:

```azurecli-interactive
az role assignment create \
  --assignee-object-id $UAMI_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "DNS Zone Contributor" \
  --scope $ZONE_ID

az role assignment create \
  --assignee-object-id $UAMI_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $(az keyvault show --name $KV_NAME --query id -o tsv)
```

### Create the namespaces, ServiceAccounts, and federated identity credentials

The Application Routing operator's TLS and DNS integrations both authenticate to Azure through a Kubernetes ServiceAccount that's bound to the user-assigned managed identity by using a federated identity credential (FIC). Each `(namespace, ServiceAccount)` pair that needs to authenticate requires one FIC.

Capture the cluster's OIDC issuer URL:

```azurecli-interactive
export OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query oidcIssuerProfile.issuerUrl -o tsv)
```

For each namespace where you plan to deploy a `Gateway` resource that uses the TLS integration or an `ExternalDNS` resource, create the namespace, a federated identity credential for the ServiceAccount, and the ServiceAccount itself. The following example creates two namespaces, `app-a` and `app-b`, each with a ServiceAccount named `approuting-demo-sa`:

```azurecli-interactive
export SA_NAME=approuting-demo-sa
for ns in app-a app-b; do
  kubectl create namespace $ns

  az identity federated-credential create \
    --identity-name $UAMI_NAME \
    --resource-group $RESOURCE_GROUP \
    --name approuting-demo-fic-$ns \
    --issuer $OIDC_ISSUER \
    --subject "system:serviceaccount:$ns:$SA_NAME" \
    --audiences "api://AzureADTokenExchange"

  kubectl apply -n $ns -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SA_NAME
  annotations:
    azure.workload.identity/client-id: $UAMI_CLIENT_ID
  labels:
    azure.workload.identity/use: "true"
EOF
done
```

The `azure.workload.identity/client-id` annotation associates the ServiceAccount with the managed identity, and the `azure.workload.identity/use: "true"` label instructs the Microsoft Entra Workload Identity webhook to project a federated token into pods that consume the ServiceAccount. Both are required for the Application Routing operator's TLS and DNS integrations to authenticate to Azure successfully.

## Configure TLS termination on a Gateway

Deploy a sample `httpbin` workload in each namespace:

```bash
for ns in app-a app-b; do
  kubectl apply -n $ns -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/httpbin/httpbin.yaml
done
```

Create a `Gateway` resource in each namespace with an HTTPS listener that references the Azure Key Vault certificate through the TLS options. Each `Gateway` uses its own sub-host of the Azure DNS zone (for example, `a.<zone>` and `b.<zone>`):

```bash
for pair in "app-a:a" "app-b:b"; do
  ns=${pair%%:*}
  sub=${pair##*:}
  fqdn=${sub}.${ZONE_NAME}
  kubectl apply -n $ns -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${sub}-gateway
  labels:
    app: approuting-demo
    zone: ${sub}
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: https
    hostname: $fqdn
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      options:
        kubernetes.azure.com/tls-cert-keyvault-uri: $CERT_URI
        kubernetes.azure.com/tls-cert-service-account: $SA_NAME
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${sub}-route
spec:
  parentRefs:
  - name: ${sub}-gateway
  hostnames: ["$fqdn"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF
done
```

Wait for each `Gateway` to reach the `Programmed` condition:

```bash
kubectl wait -n app-a --for=condition=programmed gateway a-gateway --timeout=300s
kubectl wait -n app-b --for=condition=programmed gateway b-gateway --timeout=300s
```

Verify that the Application Routing operator created a `SecretProviderClass` and that the Azure Key Vault provider for Secrets Store CSI Driver synced the certificate into a `kubernetes.io/tls` Secret in each namespace:

```bash
kubectl get secretproviderclass,secret -n app-a
kubectl get secretproviderclass,secret -n app-b
```

Example output for one namespace:

```output
NAME                                                                        AGE
secretproviderclass.secrets-store.csi.x-k8s.io/kv-gw-cert-a-gateway-https   2m

NAME                                TYPE                DATA   AGE
secret/kv-gw-cert-a-gateway-https   kubernetes.io/tls   2      2m
```

## Configure Azure DNS records by using ClusterExternalDNS

Deploy a cluster-scoped `external-dns` instance that publishes A records for `Gateway` resources in any namespace by applying a `ClusterExternalDNS` custom resource.

```bash
kubectl apply -f - <<EOF
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: ClusterExternalDNS
metadata:
  name: demo-cluster-dns
spec:
  resourceName: demo-cluster-dns
  resourceNamespace: app-a
  dnsZoneResourceIDs:
  - $ZONE_ID
  resourceTypes:
  - gateway
  identity:
    type: workloadIdentity
    serviceAccount: $SA_NAME
EOF
```

The `resourceNamespace` field specifies the namespace where the Application Routing operator deploys the managed `external-dns` instance. The ServiceAccount referenced by `identity.serviceAccount` must exist in that namespace.

After about a minute, two A records appear in the Azure DNS zone - one for each `Gateway`:

```azurecli-interactive
az network dns record-set a list --resource-group $RESOURCE_GROUP --zone-name $ZONE_NAME -o table
```

```output
Name    ResourceGroup              Ttl    Type    AutoRegistered    Metadata
------  -------------------------  -----  ------  ----------------  --------
a       <your-rg>                  300    A       False
b       <your-rg>                  300    A       False
```

## Configure Azure DNS records by using a namespace-scoped ExternalDNS

To publish records for only a subset of `Gateway` resources, use the namespace-scoped `ExternalDNS` custom resource. Unlike `ClusterExternalDNS`, the namespace-scoped variant only observes `Gateway`, `HTTPRoute`, and `GRPCRoute` resources in the same namespace as the custom resource. As with `ClusterExternalDNS`, you can optionally narrow scope further by using the `filters.gatewayLabels` and `filters.routeAndIngressLabels` selectors.

First, delete the `ClusterExternalDNS` from the previous step:

```bash
kubectl delete clusterexternaldns demo-cluster-dns
```

Deploy a new `Gateway` in `app-a` with the label `zone: c` and a corresponding `HTTPRoute`:

```bash
kubectl apply -n app-a -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: c-gateway
  labels:
    app: approuting-demo
    zone: c
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: https
    hostname: c.${ZONE_NAME}
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      options:
        kubernetes.azure.com/tls-cert-keyvault-uri: $CERT_URI
        kubernetes.azure.com/tls-cert-service-account: $SA_NAME
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: c-route
spec:
  parentRefs:
  - name: c-gateway
  hostnames: ["c.${ZONE_NAME}"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF

kubectl wait -n app-a --for=condition=programmed gateway c-gateway --timeout=300s
```

Apply a namespace-scoped `ExternalDNS` resource in `app-a` with a label filter for `zone=c`:

```bash
kubectl apply -n app-a -f - <<EOF
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: ExternalDNS
metadata:
  name: demo-ns-dns
spec:
  resourceName: demo-ns-dns
  dnsZoneResourceIDs:
  - $ZONE_ID
  resourceTypes:
  - gateway
  identity:
    type: workloadIdentity
    serviceAccount: $SA_NAME
  filters:
    gatewayLabels: "zone=c"
EOF
```

Two scoping rules apply:

- The namespace scope of `ExternalDNS` excludes `b-gateway` because it lives in the `app-b` namespace.
- The `zone=c` label filter excludes `a-gateway` because it lives in `app-a` but is labeled `zone=a`.

The Application Routing operator publishes a new A record for `c.${ZONE_NAME}`:

```azurecli-interactive
az network dns record-set a list --resource-group $RESOURCE_GROUP --zone-name $ZONE_NAME -o table
```

## Verify TLS-terminated HTTPS traffic

Resolve the `Gateway`'s hostname through the Azure DNS zone's authoritative nameserver and send an HTTPS request:

```bash
NS=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $ZONE_NAME --query 'nameServers[0]' -o tsv | sed 's/\.$//')
GATEWAY_IP=$(dig +short @${NS} a.${ZONE_NAME} | tail -1)
curl -k -I --resolve "a.${ZONE_NAME}:443:${GATEWAY_IP}" "https://a.${ZONE_NAME}/get"
```

You should see an `HTTP/2 200` response. The TLS certificate the gateway presents is the one synced from Azure Key Vault. If you imported a CA-signed certificate, replace `-k` with `--cacert <path-to-ca-chain>` to validate the certificate chain.

> [!NOTE]
> The example uses `curl --resolve` to bypass local DNS resolution and direct the request to the gateway's external IP. This method is useful for testing before delegating the DNS zone to a registrar. For production use, configure your domain registrar to delegate the zone to the Azure DNS nameservers returned by `az network dns zone show --query 'nameServers'`.

## Limitations

- The TLS integration only applies to `Gateway` resources with `gatewayClassName: approuting-istio`. Using the Application Routing add-on's DNS and TLS integrations with the [Istio service mesh add-on][istio-addon] `GatewayClass` or any other `GatewayClass` isn't yet supported.
- A `ClusterExternalDNS` or `ExternalDNS` custom resource can reference up to seven Azure DNS zones through `dnsZoneResourceIDs`. All zones referenced in a single custom resource must be in the same Azure subscription and resource group. They must also be all of the same type (public or private).
- The managed `external-dns` instance doesn't automatically delete DNS records when you delete the `ClusterExternalDNS` or `ExternalDNS` custom resource. To remove orphaned records, delete them directly from the Azure DNS zone after deleting the custom resource.
- DNS record reconciliation from `TLSRoute` resources isn't currently supported. The managed `external-dns` instance only sources records from `Gateway`, `HTTPRoute`, and `GRPCRoute` resources.

## Next steps

- [Configure ingress with the Kubernetes Gateway API via the Application Routing add-on][app-routing-gateway-api]
- [Secure ingress traffic with the Application Routing Gateway API implementation (manual configuration)][app-routing-gateway-api-tls]

<!-- LINKS - internal -->
[app-routing-nginx]: ./app-routing.md
[app-routing-gateway-api]: ./app-routing-gateway-api.md
[app-routing-gateway-api-tls]: ./app-routing-gateway-api-tls.md
[managed-gateway-api]: ./managed-gateway-api.md
[csi-secrets-store-driver]: ./csi-secrets-store-driver.md
[workload-identity-overview]: ./workload-identity-overview.md
[oidc-issuer-overview]: ./use-oidc-issuer.md
[istio-addon]: ./istio-about.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[az-aks-approuting-enable]: /cli/azure/aks/approuting#az-aks-approuting-enable
[az-aks-approuting-update]: /cli/azure/aks/approuting#az-aks-approuting-update
[az-aks-approuting-gateway-istio-enable]: /cli/azure/aks/approuting/gateway/istio#az-aks-approuting-gateway-istio-enable
[az-aks-approuting-zone]: /cli/azure/aks/approuting/zone
[az-keyvault-certificate-import]: /cli/azure/keyvault/certificate#az-keyvault-certificate-import
[akv-rbac-vs-policy]: /azure/key-vault/general/rbac-access-policy
