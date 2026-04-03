---
title: Azure Kubernetes Service (AKS) application routing add-on with the Kubernetes Gateway API (preview)
description: Use the application routing add-on to manage ingress traffic on Azure Kubernetes Service (AKS) using the Kubernetes Gateway API.
ms.subservice: aks-networking
ms.custom: devx-track-azurecli, biannual
author: nshankar
ms.topic: how-to
ms.date: 11/18/2025
ms.author: nshankar
# Customer intent: As a cloud engineer, I want to deploy and configure ingress on Azure Kubernetes Service with the Kubernetes Gateway API using the application routing add-on, so that I can efficiently manage HTTP/HTTPS traffic to my applications.
---

# Configure ingress with the Kubernetes Gateway API via the application routing add-on (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

[!INCLUDE [ingress-nginx-retirement](./includes/ingress-nginx-retirement.md)]

The application routing add-on supports the Kubernetes Gateway API for ingress traffic management. The [Kubernetes Gateway API][k8s-gateway-api] is a set of resources that provide a standardized, role-oriented, and extensible framework for traffic management, designed to be a successor and evolution of the Ingress API. The application routing Gateway API implementation thus aims to serve as a successor to the [managed NGINX][app-routing-nginx] add-on, which is based on the legacy Ingress API and will stop receiving Azure support from Azure after November 2026. If you are using managed NGINX, you must migrate to the application routing Gateway API implementation, or another supported implementation, by November 2026.

The application routing add-on Kubernetes Gateway API implementation deploys an Istio control plane to manage infrastructure for Kubernetes Gateway API resources. However, it differs from the [Istio service mesh add-on for AKS][istio-addon] in the following ways:

| Feature | Application routing Gateway API | Istio service mesh add-on |
|---------|---------------------------------|---------------------------|
| Gateway Class name | `approuting-istio` | `istio` |
| Sidecar injection and Istio CRD support | Not supported. Only manages infrastructure for Kubernetes Gateway API resources | Supported |
| Revisioning and upgrades | Not [revisioned][istio-revisions]. Upgraded in-place for both minor and patch version updates | Revisioned. Upgraded via [canary upgrades][istio-canary-upgrades] for minor version updates and in-place for patch version updates |

## Limitations

* The application routing Gateway API implementation and the [Istio service mesh add-on][istio-addon] cannot be enabled simultaneously. You must disable one first and enable the other in a separate operation. When transitioning from the Istio service mesh add-on to the application routing Gateway API implementation, you must delete the Istio GatewayClass and Istio CRDs after disabling the Istio add-on. The Istio add-on installs CRDs (such as `virtualservices.networking.istio.io`, `destinationrules.networking.istio.io`, and others in the `networking.istio.io`, `security.istio.io`, `telemetry.istio.io`, and `extensions.istio.io` API groups) that are not removed when the add-on is disabled. If these CRDs remain on the cluster, the application routing Gateway API Istio control plane fails to start. Run the following command to delete them:

    ```azurecli-interactive
    kubectl delete crd $(kubectl get crd -o name | grep -E 'istio\.io')
    kubectl delete gatewayclass istio
    ```
> [!NOTE]
> If you have existing Istio custom resources (such as VirtualServices or DestinationRules), deleting the CRDs will also delete those resources. Ensure you no longer need them before proceeding.

* The application routing Gateway API implementation uses the same [resource customization allow list][istio-gateway-resource-customization] as the Istio add-on for validating ConfigMap customizations for `Gateway` resources. Customizations not on the allow list are blocked via add-on managed webhooks.
* [Azure DNS and TLS certificate management][app-routing-dns-tls] via the application routing add-on is currently not supported for the Kubernetes Gateway API. You can follow the steps in the [application routing Gateway API implementation secure ingress guide][app-routing-gateway-api-tls] to configure a `Gateway` to perform TLS termination.
* Configuring HTTPS ingress access to HTTPS services – i.e Server Name Indication (SNI) Passthrough – via the `TLSRoute` resource is currently unsupported.
* Egress traffic management via the application routing Gateway API implementation is unsupported.

## Prerequisites

* Install the `aks-preview` extension or update to the latest version of the extension using the [`az extension add`][az-extension-add] and [`az extension update`][az-extension-update] commands. if you're using Azure CLI. You must use `aks-preview` version `19.0.0b24` and later.

    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update the aks-preview extension to the latest version
    az extension update --name aks-preview
    ```
* Enable the [Managed Gateway API installation][managed-gateway-api]. Use of self-managed Gateway API CRDs with the application routing add-on is unsupported.

* Register the App Routing Gateway API preview feature flag

- Register the `AppRoutingIstioGatewayAPIPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AppRoutingIstioGatewayAPIPreview"
    ```

## Enable the application routing Gateway API implementation

Set environment variables

```bash
export CLUSTER=<cluster-name>
export RESOURCE_GROUP=<resource-group-name>
```

### Enable during cluster creation

Run the following command to enable the application routing Gateway API implementation during cluster creation:

```azurecli-interactive
az aks create --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --enable-app-routing-istio
```

### Enable for an existing cluster

Run the following command to enable the application routing Gateway API implementation for an existing cluster:

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --enable-app-routing-istio
```

You should see `istiod` pods in the `aks-istio-system` namespace:

```bash
kubectl get pods -n aks-istio-system
```

```output
NAME                      READY   STATUS    RESTARTS   AGE
istiod-54b4ff45cf-htph8   1/1     Running   0          3m15s
istiod-54b4ff45cf-wlvgd   1/1     Running   0          3m
```

You should also see the `ValidatingWebhookConfiguration` get deployed:

```bash
kubectl get validatingwebhookconfiguration
```

```output
NAME                                        WEBHOOKS   AGE
aks-node-validating-webhook                 1          117m
azure-service-mesh-ccp-validating-webhook   1          4m2s
```

If you have the [Managed Gateway API installation][managed-gateway-api] enabled, you should also see the Istio gateway customization ConfigMap get created:

```bash
kubectl get cm -n aks-istio-system
```

```output
NAME                                  DATA   AGE
...
istio-gateway-class-defaults          2      43s
...
```

## Configure ingress using a Kubernetes Gateway

### Deploy sample application

First, deploy the sample `httpbin` application in the `default` namespace:

```bash
export ISTIO_RELEASE="release-1.27"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_RELEASE/samples/httpbin/httpbin.yaml
```

### Create Kubernetes Gateway and HTTPRoute

Next, deploy a Gateway API configuration in the `default` namespace with the `gatewayClassName` set to `approuting-istio`. 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
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
spec:
  parentRefs:
  - name: httpbin-gateway
  hostnames: ["httpbin.example.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF
```

> [!NOTE]
> The example above creates an external ingress load balancer service that's accessible from outside the cluster. You can add [annotations][annotation-customizations] to create an [internal load balancer][azure-internal-lb] and customize other load balancer settings.

> [!NOTE]
> By default, the Istio control plane will append the `GatewayClass` name `approuting-istio` to the name of the resources that it provisions for the `Gateway`. You can annotate your `Gateway` resource with `gateway.istio.io/name-override` to override the name of the provisioned resources. The resource names must be less than `63` characters and must be a valid DNS name.

Verify that a `Deployment`, `Service`, `HorizontalPodAutoscaler`, and `PodDisruptionBudget` get created for `httpbin-gateway`:

```bash
kubectl get deployment httpbin-gateway-approuting-istio
```

```output
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
httpbin-gateway-approuting-istio   2/2     2            2           6m41s
```

```bash
kubectl get service httpbin-gateway-approuting-istio
```

```output
NAME                               TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)                        AGE
httpbin-gateway-approuting-istio   LoadBalancer   10.0.54.96   <external-ip>    15021:30580/TCP,80:32693/TCP   7m13s
```

```bash
kubectl get hpa httpbin-gateway-approuting-istio
```

```output
NAME                               REFERENCE                                     TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
httpbin-gateway-approuting-istio   Deployment/httpbin-gateway-approuting-istio   cpu: 3%/80%   2         5         2          8m13s
```

```bash
kubectl get pdb httpbin-gateway-approuting-istio
```

```output
NAME                               MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
httpbin-gateway-approuting-istio   1               N/A               1                     9m1s
```

### Send request to sample application

Finally, try sending a `curl` request to the `httpbin` application. First, set the `INGRESS_HOST` environment variable:

```bash
kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -ojsonpath='{.status.addresses[0].value}')
```

Then, try sending an HTTP request to `httpbin`:

```bash
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST/get"
```

You should see an `HTTP 200` response.

> [!NOTE]
> To secure ingress traffic with the application routing Gateway API implementation, see the [following guide][app-routing-gateway-api-tls] to sync secrets from Azure Key Vault (AKV) for securing Gateway API ingress traffic with TLS termination.

## Versioning and Upgrades

The application routing Gateway API implementation deploys and upgrades the Istio control plane based on the AKS cluster Kubernetes version **for both minor version and patch version upgrades**.

The Istio version is the maximum supported Istio minor version that is compatible with your cluster's AKS version. For instance, if you are on AKS version `1.34`, the maximum supported Istio minor version that is installed (as of March 2026) is `1.28`. Keep in mind that the maximum supported Istio version for a given Kubernetes version could differ between [Long-Term Support (LTS) clusters][aks-lts] and non-LTS clusters.

To find the maximum supported Istio minor version for your AKS Kubernetes version, you can check the [service mesh add-on release calendar][istio-release-calendar]. While the application routing Gateway API implementation is not revisioned, the Istio control plane minor version corresponds to the given service mesh add-on revision (ex: for service mesh add-on `asm-1-28`, the application routing Istio control plane minor version would be `1.28`). You can also see the Istio minor version by checking the patch version in the `istiod` deployment image: `kubectl get deployment istiod -n aks-istio-system -o=jsonpath="{.spec.template.spec.containers[*].image}"`.

### Upgrades

Patch version and minor version upgrades of Istio control plane for the application routing Gateway API implementation occur in-place. Patch version upgrades of the Istio control plane are triggered automatically as part of AKS releases. Minor version upgrades can be triggered automatically or manually depending on the AKS Kubernetes version and timing of Istio minor version releases. Minor version upgrades occur in the following two scenarios:
- The AKS cluster is upgraded to a new version which has a higher maximum supported Istio version pinned to it. The Istio control plane will be upgraded to the higher minor version as part of the AKS cluster upgrade.
- A new Istio version is released for AKS and is now the maximum supported Istio version for the AKS cluster version. The Istio control plane on your cluster will **automatically** be upgraded to the new minor version after the release is rolled out to your region. Follow the [AKS release notes][aks-release-notes] and [AKS release tracker][aks-release-tracker] to track new Istio version releases and see when the new version has rolled out to your region.

It's possible that traffic disruptions could occur during the upgrade process. To minimize disruptions during upgrades, the application routing add-on deploys a Horizontal Pod Autoscaler (HPA) with 2 minimum replicas and a PodDisruptionBudget (PDB) with a minimum availability of 1 for each `Gateway`. You can [customize these resources](#resource-customizations) to modify these settings.

## Resource customizations

### Control plane Horizontal Pod Autoscaling (HPA) customization

The application routing Gateway API implementation supports customization of the Istio control plane Horizontal Pod Autoscaler (HPA). The `istiod` HPA resource has the following default configurations:
- Min Replicas: 2
- Max Replicas: 5
- CPU Utilization: 80%

> [!NOTE]
> To prevent conflicts with the `PodDisruptionBudget`, the application routing Gateway API implementation does not allow setting the `minReplicas` below the initial default of `2`.

The HPA configuration can be modified through patches and direct edits. Example:

```bash
kubectl patch hpa istiod -n aks-istio-system --type merge --patch '{"spec": {"minReplicas": 3, "maxReplicas": 6}}'
```

### Gateway resource customization

The application routing Gateway API implementation supports customization of the `Gateway` resources via annotations and ConfigMaps. Application routing uses the same resource customization allow list as the Istio service mesh add-on for Gateway API resource customization. Follow the steps in the [Istio add-on Gateway API docs][istio-gateway-resource-customization] to configure resources generated for the `Gateways` and to see which fields fall under the [allow list][istio-gateway-resource-customization].

> [!NOTE]
> The `istio-gateway-class-defaults` ConfigMap is provisioned and reconciled by AKS when the Managed Gateway API CRDs and the application routing Gateway API implementation are enabled together. If you previously created the `istio-gateway-class-defaults` ConfigMap in the `aks-istio-system` namespace yourself, you must delete the self-managed ConfigMap instance prior to enabling the Managed Gateway API CRDs to avoid conflicts with reconciliation of the AKS-managed ConfigMap.

## Disable the application routing Gateway API implementation

Run the following command to disable the application routing Gateway API implementation:

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --disable-app-routing-istio
```

### Cleanup Resources

Run the following commands to delete the `Gateway` and `HttpRoute`:

```bash
kubectl delete gateways.gateway.networking.k8s.io httpbin-gateway
kubectl delete httproute httpbin
```

If you created a ConfigMap to customize your `Gateway`, run the following command to delete the ConfigMap:

```bash
kubectl delete configmap gw-options
```

If you created a SecretProviderClass and secret to use for TLS termination, delete the following resources as well:

```bash
kubectl delete secret httpbin-credential
kubectl delete pod secrets-store-sync-httpbin
kubectl delete secretproviderclass httpbin-credential-spc
```

## Next steps

[Secure ingress traffic with the application routing Gateway API implementation][app-routing-gateway-api-tls]

<!-- LINKS - internal -->
[annotation-customizations]: istio-gateway-api.md#annotation-customizations
[app-routing-nginx]: app-routing.md
[app-routing-dns-tls]: app-routing-dns-ssl.md
[aks-lts]: long-term-support.md
[akv-rbac-guide]: /azure/key-vault/general/rbac-guide#using-azure-rbac-secret-key-and-certificate-permissions-with-key-vault
[azure-internal-lb]: ./internal-lb.md
[aks-release-tracker]: ./release-tracker.md
[istio-addon]: istio-about.md
[istio-gateway-resource-customization]: istio-gateway-api.md#configmap-customizations
[managed-gateway-api]: managed-gateway-api.md
[istio-release-calendar]: istio-support-policy.md#service-mesh-add-on-release-calendar
[istio-meshconfig]: istio-meshconfig.md#allowed-supported-and-blocked-meshconfig-values
[istio-support-policy]: istio-support-policy.md#allowed-supported-and-blocked-customizations
[istio-canary-upgrades]: ./istio-upgrade.md#minor-revision-upgrade
[nginx-retirement]: ./includes/ingress-nginx-retirement.md
[app-routing-gateway-api-tls]: ./app-routing-gateway-api-tls.md

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/azure/aks/releases
[istio-revisions]: https://istio.io/latest/blog/2021/revision-tags/
[k8s-gateway-api]: https://gateway-api.sigs.k8s.io/
