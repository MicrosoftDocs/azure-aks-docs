---
title: Azure Kubernetes Service (AKS) Application Routing Add-On with the Kubernetes Gateway API
description: Use the application routing add-on to manage ingress traffic on Azure Kubernetes Service (AKS) using the Kubernetes Gateway API.
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli, biannual
author: nshankar
ms.topic: how-to
ms.date: 07/01/2026
ms.author: nshankar
# Customer intent: As a cloud engineer, I want to deploy and configure ingress on Azure Kubernetes Service with the Kubernetes Gateway API using the application routing add-on, so that I can efficiently manage HTTP/HTTPS traffic to my applications.
---

# Configure ingress with the Kubernetes Gateway API via the application routing add-on for Azure Kubernetes Service (AKS)

[!INCLUDE [ingress-nginx-retirement](./includes/ingress-nginx-retirement.md)]

The application routing add-on supports the Kubernetes Gateway API for ingress traffic management. The [Kubernetes Gateway API][k8s-gateway-api] is a set of resources that provide a standardized, role-oriented, and extensible framework for traffic management, designed to be a successor and evolution of the Ingress API. The application routing Gateway API implementation thus aims to serve as a successor to the [managed NGINX][app-routing-nginx] add-on, which is based on the legacy Ingress API and will stop receiving Azure support from Azure after November 2026. If you are using managed NGINX, you must migrate to the application routing Gateway API implementation, or another supported implementation, by November 2026.

For production workloads, this model is the recommended default ingress model on AKS Automatic. Starting with AKS version 1.36, new AKS Automatic clusters use Kubernetes Gateway API via the application routing add-on by default. For background on AKS Automatic production defaults, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

## Comparison with Istio service mesh add-on

The application routing add-on Kubernetes Gateway API implementation deploys an Istio control plane to manage infrastructure for Kubernetes Gateway API resources. However, it differs from the [Istio service mesh add-on for AKS][istio-addon] in the following ways:

| Feature | Application routing Gateway API | Istio service mesh add-on |
| ------- | ------------------------------- | ------------------------- |
| Gateway Class name | `approuting-istio` | `istio` |
| Sidecar injection and Istio CRD support | Not supported. Only manages infrastructure for Kubernetes Gateway API resources | Supported |
| Revisioning and upgrades | Not [revisioned][istio-revisions]. Upgraded in-place for both minor and patch version updates | Revisioned. Upgraded via [canary upgrades][istio-canary-upgrades] for minor version updates and in-place for patch version updates |

## When to use application routing Gateway API in production

Use this implementation as your default ingress path when you want:

- A production-ready, managed ingress default on AKS Automatic.
- Kubernetes Gateway API-native HTTP/HTTPS ingress.
- Managed Gateway infrastructure with built-in operational safeguards such as autoscaling and disruption budgets on gateway proxies.

Consider alternatives when you require capabilities outside current support in this article, such as:

- Full Istio service mesh behavior with sidecar-based traffic management and broader Istio CRD usage.
- Features currently listed as unsupported, such as TLSRoute-based SNI passthrough.

## Limitations

- You can't enable the application routing Gateway API implementation and the [Istio service mesh add-on][istio-addon] at the same time. You must disable one first and enable the other in a separate operation. When transitioning from the Istio service mesh add-on to the application routing Gateway API implementation, you must delete the Istio GatewayClass and Istio CRDs after disabling the Istio add-on. The Istio add-on installs CRDs (such as `virtualservices.networking.istio.io`, `destinationrules.networking.istio.io`, and others in the `networking.istio.io`, `security.istio.io`, `telemetry.istio.io`, and `extensions.istio.io` API groups) that aren't removed when the add-on is disabled. If these CRDs remain on the cluster, the application routing Gateway API Istio control plane fails to start. Run the following command to delete them:

    ```bash
    kubectl delete crd $(kubectl get crd -o name | grep -E 'istio\.io')
    kubectl delete gatewayclass istio
    ```

    > [!NOTE]
    > If you have existing Istio custom resources (such as VirtualServices or DestinationRules), deleting the CRDs also deletes those resources. Ensure you no longer need them before proceeding.

- The application routing Gateway API implementation uses the same [resource customization allow list][istio-gateway-resource-customization] as the Istio add-on for validating ConfigMap customizations for `Gateway` resources. Add-on managed webhooks block customizations that aren't on the allow list.
- Configuring HTTPS ingress access to HTTPS services (for example, Server Name Indication (SNI) Passthrough) via the `TLSRoute` resource isn't currently supported. Support for the `TLSRoute` resource will be available once AKS adds support for Istio 1.30, at which point your application routing Istio control plane is automatically upgraded to that version.
- Egress traffic management via the application routing Gateway API implementation isn't supported.
- Injecting non-Microsoft-managed sidecars (for example, custom telemetry, logging, or security agents) into the Istio gateway proxy pods managed by the application routing add-on isn't officially supported. If you choose to inject your own sidecar into a managed proxy pod, Microsoft provides only best-effort support for any issues you encounter.
- Envoy access logging is enabled by default on Gateway proxy pods, but the log format, scope, and provider can't be customized via the Istio `Telemetry` API. To customize, use Gateway API ingress on the [Istio service mesh add-on][istio-gateway-api-access-logs] instead.

## Prerequisites

### Update Azure CLI version

You must use `azure-cli` version `2.86.0` or higher. Run `az --version` to find your `azure-cli` version, and run `az upgrade` to upgrade.

### Enable Managed Gateway API CRDs

Enable the [Managed Gateway API installation][managed-gateway-api]. Use of self-managed Gateway API CRDs with the application routing add-on is unsupported.

### AKS Automatic default behavior (AKS 1.36 and later)

On new AKS Automatic clusters running AKS 1.36 or later, Kubernetes Gateway API via the application routing add-on is enabled by default.

You typically don't need to run the feature enablement command unless you're:

- Using an existing cluster.
- Running an earlier AKS version.
- Reenabling the feature after disabling it.

### Enable the application routing Gateway API implementation

> [!NOTE]
> If you create a new AKS Automatic cluster on AKS 1.36 or later, this feature is enabled by default. Use the commands in this section for AKS Standard clusters, earlier versions, or existing clusters that don't already have the feature enabled.

### Enable during cluster creation

Run the following command to enable the application routing Gateway API implementation during AKS Standard cluster creation:

```azurecli-interactive
# Set environment variables
export CLUSTER=<cluster-name>
export RESOURCE_GROUP=<resource-group-name>

# Enable the application routing Gateway API implementation during AKS Standard cluster creation
az aks create --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --enable-app-routing-istio
```

### Enable for an existing cluster

Run the following command to enable the application routing Gateway API implementation for an existing cluster:

```azurecli-interactive
# Set environment variables
export CLUSTER=<cluster-name>
export RESOURCE_GROUP=<resource-group-name>

# Enable the application routing Gateway API implementation for an existing cluster
az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --enable-app-routing-istio
```

You should see `istiod` pods in the `aks-istio-system` namespace:

```bash
kubectl get pods -n aks-istio-system
```

```output
NAME                      READY   STATUS    RESTARTS   AGE
istiod-12a3bc45de-fghi6   1/1     Running   0          3m15s
istiod-78j9kl01mn-opqrs   1/1     Running   0          3m
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
> To secure ingress traffic with the application routing Gateway API implementation and integrate with Azure DNS for hostname management, see [Configure Azure DNS and TLS with the application routing Gateway API implementation][app-routing-gateway-api-dns-tls] for the automated workflow powered by the application routing operator. For a manual TLS termination workflow that does not rely on the operator's integration, see [Secure ingress traffic with the application routing Gateway API implementation][app-routing-gateway-api-tls].

## Access logging

The application routing Gateway API implementation enables Envoy access logging by default on all managed `Gateway` proxy pods. Access logs are written to the proxy container's standard output in the default Envoy text format. You can view the logs by using `kubectl logs`:

```bash
kubectl logs deployment/<your-gateway-name>-approuting-istio
```

Each request that the gateway handles produces a log line containing details such as the HTTP method, path, response code, upstream service, and request and response sizes. This detail makes it easier to observe ingress traffic and troubleshoot routing issues without any additional configuration.

## Versioning and Upgrades

The application routing Gateway API implementation deploys and upgrades the Istio control plane based on the AKS cluster Kubernetes version for both minor and patch version upgrades. This in-place model aligns with AKS Automatic production defaults, where platform lifecycle management is designed to reduce manual operations.

The Istio version is the maximum supported Istio minor version that's compatible with your cluster's AKS version. For instance, if you're on AKS version `1.34`, the maximum supported Istio minor version installed (as of March 2026) is `1.28`. Keep in mind that the maximum supported Istio version for a given Kubernetes version can differ between [Long-Term Support (LTS) clusters][aks-lts] and non-LTS clusters.

To find the maximum supported Istio minor version for your AKS Kubernetes version, check the [service mesh add-on release calendar][istio-release-calendar]. While the application routing Gateway API implementation isn't revisioned, the Istio control plane minor version corresponds to the given service mesh add-on revision (ex: for service mesh add-on `asm-1-28`, the application routing Istio control plane minor version is `1.28`). You can also see the Istio minor version by checking the patch version in the istiod deployment image:

```bash
kubectl get deployment istiod -n aks-istio-system -o=jsonpath="{.spec.template.spec.containers[*].image}"
```

### Upgrades

Patch and minor version upgrades of the Istio control plane for the application routing Gateway API implementation occur in place. Patch version upgrades are triggered automatically as part of AKS releases. Minor version upgrades can be triggered automatically or manually depending on the AKS Kubernetes version and timing of Istio minor version releases. Minor version upgrades occur in the following scenarios:

- The AKS cluster is upgraded to a new version that has a higher maximum supported Istio version pinned to it. The Istio control plane is upgraded to the higher minor version as part of the AKS cluster upgrade.
- A new Istio version is released for AKS and becomes the maximum supported Istio version for the AKS cluster version. After rollout to your region, the Istio control plane on your cluster automatically upgrades to the new minor version. To track new Istio version releases and see when the new version rolls out to your region, follow the [AKS release notes][aks-release-notes] and [AKS release tracker][aks-release-tracker].

Traffic disruptions can occur during the upgrade process. To minimize disruptions during upgrades, the application routing add-on deploys a Horizontal Pod Autoscaler (HPA) with two minimum replicas and a PodDisruptionBudget (PDB) with a minimum availability of one for each `Gateway`. You can [customize these resources](#resource-customizations) to modify these settings.

## Resource customizations

### Control plane Horizontal Pod Autoscaling (HPA) customization

The application routing Gateway API implementation supports customization of the Istio control plane Horizontal Pod Autoscaler (HPA). The `istiod` HPA resource has the following default configurations:

- Min replicas: Two
- Max replicas: Five
- CPU utilization: 80%

> [!NOTE]
> To prevent conflicts with the `PodDisruptionBudget`, the application routing Gateway API implementation doesn't allow setting the `minReplicas` to less than the initial default of `2`.

The HPA configuration can be modified through patches and direct edits. Example:

```bash
kubectl patch hpa istiod -n aks-istio-system --type merge --patch '{"spec": {"minReplicas": 3, "maxReplicas": 6}}'
```

### Gateway resource customization

The application routing Gateway API implementation supports customization of the `Gateway` resources via annotations and ConfigMaps. Application routing uses the same resource customization allow list as the Istio service mesh add-on for Gateway API resource customization. Follow the steps in the [Istio add-on Gateway API docs][istio-gateway-resource-customization] to configure resources generated for the `Gateways` and to see which fields fall under the [allow list][istio-gateway-resource-customization].

> [!NOTE]
> The `istio-gateway-class-defaults` ConfigMap is provisioned and reconciled by AKS when the Managed Gateway API CRDs and the application routing Gateway API implementation are enabled together. If you previously created the `istio-gateway-class-defaults` ConfigMap in the `aks-istio-system` namespace yourself, you must delete the self-managed ConfigMap instance prior to enabling the Managed Gateway API CRDs to avoid conflicts with reconciliation of the AKS-managed ConfigMap.

> [!NOTE]
> The application routing Gateway API implementation adds [Azure Load Balancer annotations][azure-lb-annotations] to the `Gateway` Service to configure health probes for the default `externalTrafficPolicy` setting of "Cluster." If you set `spec.externalTrafficPolicy` to "Local," you must unset the following annotations either in the GatewayClass-level ConfigMap or the per-Gateway ConfigMap:
>
> ```yaml
>  service: |
>     spec:
>        externalTrafficPolicy: Local
>     metadata:
>       annotations:
>         service.beta.kubernetes.io/port_80_health-probe_port:
>         service.beta.kubernetes.io/port_80_health-probe_protocol:
>         service.beta.kubernetes.io/port_80_health-probe_request-path:
> ```

## Disable the application routing Gateway API implementation

Run the following command to disable the application routing Gateway API implementation:

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --disable-app-routing-istio
```

### Clean up resources

Run the following commands to delete the `Gateway` and `HTTPRoute` resources:

```bash
kubectl delete gateways.gateway.networking.k8s.io httpbin-gateway
kubectl delete httproute httpbin
```

If you created a ConfigMap to customize your `Gateway`, run the following command to delete the ConfigMap:

```bash
kubectl delete configmap gw-options
```

If you created a SecretProviderClass and secret to use for TLS termination, delete the following resources:

```bash
kubectl delete secret httpbin-credential
kubectl delete pod secrets-store-sync-httpbin
kubectl delete secretproviderclass httpbin-credential-spc
```

## Related content

- [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Configure Azure DNS and TLS with the application routing Gateway API implementation][app-routing-gateway-api-dns-tls]
- [Secure ingress traffic with the application routing Gateway API implementation (manual configuration)][app-routing-gateway-api-tls]

<!-- LINKS - internal -->
[annotation-customizations]: istio-gateway-api.md#annotation-customizations
[app-routing-nginx]: app-routing.md
[aks-lts]: long-term-support.md
[azure-internal-lb]: ./internal-lb.md
[aks-release-tracker]: ./release-tracker.md
[istio-addon]: istio-about.md
[istio-gateway-resource-customization]: istio-gateway-api.md#configmap-customizations
[istio-gateway-api-access-logs]: istio-gateway-api.md#enable-access-logs-for-the-gateway-pods
[managed-gateway-api]: managed-gateway-api.md
[istio-release-calendar]: istio-support-policy.md#service-mesh-add-on-release-calendar
[istio-canary-upgrades]: ./istio-upgrade.md#minor-revision-upgrade
[app-routing-gateway-api-tls]: ./app-routing-gateway-api-tls.md
[app-routing-gateway-api-dns-tls]: ./app-routing-gateway-api-dns-tls.md

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/azure/aks/releases
[istio-revisions]: https://istio.io/latest/blog/2021/revision-tags/
[k8s-gateway-api]: https://gateway-api.sigs.k8s.io/
[azure-lb-annotations]: https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/
