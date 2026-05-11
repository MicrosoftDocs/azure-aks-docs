---
title: Migrate from application routing Ingress-Nginx to the application routing Gateway API implementation on AKS
description: Step-by-step guide to migrate ingress traffic from the application routing add-on with Ingress-Nginx to the application routing Gateway API (Istio) implementation on Azure Kubernetes Service with zero downtime.
ms.subservice: aks-networking
ms.custom: devx-track-azurecli
author: kingoliver
ms.topic: how-to
ms.date: 05/05/2026
ms.author: kingoliver
# Customer intent: As a cloud engineer, I want to migrate my AKS workloads from the Ingress-Nginx-based application routing add-on to the Gateway API implementation so that I'm on a supported ingress before the November 2026 Ingress-Nginx deadline without dropping client traffic.
---

# Migrate from application routing Ingress-Nginx to the application routing Gateway API implementation (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]


This article describes how to migrate workloads from the [application routing add-on with Ingress-Nginx][app-routing-nginx] to the [application routing Gateway API implementation][app-routing-gateway-api], which serves traffic through the Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/). The two data planes can run side-by-side on the same AKS cluster, which lets you perform a zero-downtime cutover by shifting client traffic with DNS instead of an in-place swap.

## Why migrate

[!INCLUDE [ingress-nginx-retirement](./includes/ingress-nginx-retirement.md)]

Microsoft-supported security patches for the Ingress-Nginx-based application routing add-on end in November 2026. The supported successor on AKS is the application routing Gateway API implementation, which deploys a lightweight, sidecar-less Istio control plane that only reconciles Gateway API resources belonging to the `approuting-istio` `GatewayClass`.

## How the migration works

The Ingress-Nginx add-on and the Gateway API implementation each get their own Azure Load Balancer frontend IP. Clients keep hitting the Ingress-Nginx IP until the hostname they resolve points somewhere else.

There's no in-place flag that converts Ingress-Nginx to Gateway API. The strategy is to run both data planes in parallel, validate the new path, then move clients to the new IP. If an upstream system (Azure Front Door origin, Traffic Manager endpoint, firewall allowlist) pins the existing Ingress-Nginx IP, update that upstream configuration to the new Gateway IP rather than trying to reassign the existing IP — AKS-managed public IPs are deleted when their owning Service is removed even if you mark them `Static`, so an in-place IP swap can't be performed safely.

## Key differences

| | Ingress-Nginx add-on | Gateway API (Istio) implementation |
|---|---|---|
| API | `networking.k8s.io/v1` `Ingress` | `gateway.networking.k8s.io/v1` `Gateway` and `HTTPRoute` |
| Az CLI Enable flag | `--enable-app-routing` | `--enable-app-routing-istio` (requires `--enable-gateway-api`) |
| Class name | `webapprouting.kubernetes.azure.com` | `approuting-istio` |
| Data plane Service | `nginx` in `app-routing-system` | `<gateway-name>-approuting-istio` in the `Gateway`'s namespace |
| Azure DNS / Key Vault TLS wiring | Built in | Not yet supported. See [Secure application routing Gateway API ingress traffic][app-routing-gateway-api-tls] |

## Prerequisites

* Azure CLI 2.54 or later, and the `aks-preview` extension at version `19.0.0b24` or later.

    ```azurecli-interactive
    az extension add --name aks-preview
    az extension update --name aks-preview
    ```

* Register the `AppRoutingIstioGatewayAPIPreview` feature flag once per subscription.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name AppRoutingIstioGatewayAPIPreview
    az feature show --namespace Microsoft.ContainerService --name AppRoutingIstioGatewayAPIPreview --query properties.state -o tsv
    ```

* If the cluster has the [Istio service mesh add-on][istio-addon] enabled, disable it and remove the leftover `networking.istio.io` CRDs and the `istio` `GatewayClass` before you start. The application routing Gateway API control plane refuses to start while those CRDs are present. See [Limitations][app-routing-gateway-api-limitations] for the cleanup command.

Set environment variables that the rest of this article uses:

```bash
export RG=<resource-group>
export CLUSTER=<cluster-name>
```

## Step 1: Inventory current ingress

List every `Ingress` that uses the Ingress-Nginx class and the hostnames pointing at the Ingress-Nginx load balancer IP. Include any upstream references such as Azure Front Door origins, Traffic Manager endpoints, and firewall allowlists.

```bash
kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="webapprouting.kubernetes.azure.com")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
```

Capture the current Ingress-Nginx IP for later validation:

```bash
INGRESS_NGINX_IP=$(kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## Step 2: Lower the DNS TTL

> [!NOTE]
> Skip this step if your clients reach the cluster by IP rather than DNS — the cutover in step 7 is a DNS change, so a low TTL is only relevant when DNS is in the path.

For each hostname that resolves to `INGRESS_NGINX_IP`, lower the record TTL to 60 seconds (or the smallest value your provider allows). Wait for the previous TTL window to fully expire before you continue. If the previous TTL was one hour, wait at least one hour. Skipping this step means cached resolvers continue sending clients to Ingress-Nginx after you delete the `Ingress`.

## Step 3: Enable the Gateway API implementation

Enable the Managed Gateway API CRDs and the application routing Gateway API implementation. Ingress-Nginx keeps serving traffic the entire time.

```azurecli-interactive
az aks update --resource-group $RG --name $CLUSTER --enable-gateway-api
az aks update --resource-group $RG --name $CLUSTER --enable-app-routing-istio
```

Verify the control plane and `GatewayClass` are ready:

```bash
kubectl -n aks-istio-system rollout status deploy/istiod --timeout=5m
kubectl get gatewayclass approuting-istio
```

## Step 4: Translate each Ingress to Gateway and HTTPRoute

For each `Ingress`, create a matching `Gateway` and `HTTPRoute`. For per-field translation guidance — including how to convert path matches, redirects, rewrites, and header manipulation — follow the [Kubernetes Gateway API migration guide](https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/). To bulk-translate existing manifests instead of writing them by hand, consider [`ingress2gateway`](https://github.com/kubernetes-sigs/ingress2gateway), a Kubernetes SIG Network tool that reads `Ingress` resources (including `ingress-nginx` annotations) and emits equivalent Gateway API resources — treat its output as a starting point and review before applying.

The example below converts an Ingress-Nginx `Ingress` for host `httpbin.contoso.com` with path prefix `/get` and backend `httpbin:8000`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
  namespace: demo
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: demo
spec:
  parentRefs:
  - name: httpbin-gateway
  hostnames: ["httpbin.contoso.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
```

Wait for the `Gateway` to program and capture its public IP:

```bash
kubectl wait --for=condition=Programmed -n demo \
  gateways.gateway.networking.k8s.io/httpbin-gateway --timeout=5m
GW_IP=$(kubectl get gateway -n demo httpbin-gateway -o jsonpath='{.status.addresses[0].value}')
```

## Step 5: Provision TLS on the Gateway

If the original `Ingress` terminated HTTPS, configure TLS on the new `Gateway` *before* you change DNS. Follow [Secure application routing Gateway API ingress traffic][app-routing-gateway-api-tls] to sync the certificate from Azure Key Vault by using the Secrets Store CSI driver, then add a TLS listener that references the resulting Kubernetes `Secret` through `certificateRefs`.

## Step 6: Validate the new path before clients see it

Probe both data planes by pinning DNS resolution with `curl --resolve`. Both should return `200` continuously while you run the probe in a loop for several minutes.

> [!IMPORTANT]
> Do not move on to cutover until you have fully exercised the Gateway IP. The DNS flip in step 7 is the point at which real client traffic lands on the new data plane — anything broken on the Gateway side becomes a customer-visible outage at that moment. Defects that are easy to find by hitting `GW_IP` directly are much harder to triage once production traffic is mixed in.

```bash
# New Gateway path
curl -sS -o /dev/null -w '%{http_code}\n' \
  --resolve "httpbin.contoso.com:443:${GW_IP}" \
  https://httpbin.contoso.com/get

# Old Ingress-Nginx path (should still work)
curl -sS -o /dev/null -w '%{http_code}\n' \
  --resolve "httpbin.contoso.com:443:${INGRESS_NGINX_IP}" \
  https://httpbin.contoso.com/get
```

At minimum, exercise the following against `GW_IP` (using `--resolve` or a `Host` header) before you flip DNS:

* **Every hostname and route** that the original `Ingress` served, not just one happy-path URL. Routes that share a host but differ in path prefix, header match, or method must each be hit.
* **HTTPS end-to-end** with the production certificate served by the `Gateway`. Verify the certificate chain and SAN list match what clients expect; don't rely on `--insecure`.
* **Application behavior**, not just HTTP status codes. Submit POST bodies, exercise authentication, and confirm long-running responses (streaming, WebSockets, gRPC) work end-to-end if your workload uses them.
* **Sustained load** for at least several minutes from a probe loop, watching for intermittent 5xx responses, latency regressions, or `Gateway`/`HTTPRoute` status conditions flapping.
* **Upstream integrations** in a non-production configuration where possible — for example, point a staging Front Door origin or Traffic Manager endpoint at `GW_IP` and verify health probes pass.

Only proceed to step 7 once every check above passes consistently. If anything fails, fix it on the Gateway side while Ingress-Nginx is still serving real clients — you have unlimited rollback room until DNS changes.

## Step 7: Cut over

1. Update the DNS A record for the hostname to point to `GW_IP`. Because you already lowered the TTL in step 2, drain happens within minutes.
1. If any upstream system pins the Ingress-Nginx IP — for example, an Azure Front Door origin, a Traffic Manager endpoint, or a customer firewall allowlist — update it to `GW_IP` at the same time. Don't try to reassign the existing IP to the Gateway: the Ingress-Nginx Service's public IP is created and managed by the cluster's cloud provider, and it's deleted when the Service is removed even if you've set it to `Static`.
1. Watch traffic drop on Ingress-Nginx. Either scrape the `ingress-nginx` request-rate metrics or watch the `nginx` Service's load balancer byte counters until per-minute requests reach approximately zero.
1. Delete the `Ingress` resource:

    ```bash
    kubectl delete ingress -n demo httpbin
    ```

1. Disable the Ingress-Nginx add-on:

    ```azurecli-interactive
    az aks approuting disable --resource-group $RG --name $CLUSTER --yes
    ```

1. Keep the DNS TTL low for a few hours of observation, then raise it back to your normal value.

## Step 8: Clean up

After traffic is stable on the Gateway API path, stop the add-on from reconciling a default `NginxIngressController` on the cluster, then delete every existing `NginxIngressController` custom resource. Disabling the add-on in step 7 stops the controller from reconciling new resources, but the `nginx` Deployment and Service it created earlier remain on the cluster until you remove the owning `NginxIngressController`.

Update the cluster so the application routing add-on no longer manages a default Ingress-Nginx controller:

```azurecli-interactive
az aks approuting update --resource-group $RG --name $CLUSTER --nginx None
```

Then delete the remaining `NginxIngressController` resources:

```bash
kubectl delete nginxingresscontrollers.approuting.kubernetes.azure.com --all
```

Raise the DNS TTL back to its normal value once you have verified steady state.

## Roll back

Both data planes can coexist, so rollback is symmetric at any point *before* you disable the Ingress-Nginx add-on. To roll back:

1. Recreate the `Ingress` resource.
1. Flip DNS back to `INGRESS_NGINX_IP` and wait for the TTL window to drain.
1. Optionally disable the Gateway API implementation:

    ```azurecli-interactive
    az aks update --resource-group $RG --name $CLUSTER --disable-app-routing-istio
    ```

After you run `az aks approuting disable`, the Ingress-Nginx controller is gone. Rolling back from that point requires re-enabling the add-on and recreating the `Ingress`, which has its own cutover window. Validate the chosen path before you disable Ingress-Nginx.

## Next steps

* [Configure ingress with the Kubernetes Gateway API via the application routing add-on][app-routing-gateway-api]
* [Secure application routing Gateway API ingress traffic][app-routing-gateway-api-tls]
* [Managed Gateway API on AKS][managed-gateway-api]

<!-- LINKS -->
[app-routing-nginx]: ./app-routing.md
[app-routing-gateway-api]: ./app-routing-gateway-api.md
[app-routing-gateway-api-tls]: ./app-routing-gateway-api-tls.md
[app-routing-gateway-api-limitations]: ./app-routing-gateway-api.md#limitations
[managed-gateway-api]: ./managed-gateway-api.md
[istio-addon]: ./istio-about.md
