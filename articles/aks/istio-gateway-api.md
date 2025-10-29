---
title: Azure Kubernetes Service (AKS) Kubernetes Gateway API ingresses for Istio service mesh add-on
description: Configure ingresses for Istio service mesh add-on for Azure Kubernetes Service using the Kubernetes Gateway API
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.date: 08/21/2025
ms.author: nshankar
# Customer intent: "As a Kubernetes administrator, I want to deploy Kubernetes Gateway API-based ingress gateways for the Istio service mesh on my cluster, so that I can efficiently manage ingress application traffic routing."
---

# Configure Istio ingress with the Kubernetes Gateway API - Preview

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

In addition to [Istio's own ingress traffic management API][istio-deploy-ingress], the Istio service mesh add-on also supports the Kubernetes Gateway API for ingress traffic management. In order to receive support from Azure for Gateway API-based deployments with the Istio add-on, you must have the [Managed Gateway API installation][managed-gateway-addon] enabled on your cluster. You can use both the Istio Gateway API [automated deployment model][istio-gateway-auto-deployment] or the [manual deployment model][istio-gateway-manual-deployment] for ingress traffic management. ConfigMap customizations must fall under the [resource customization allowlist](#resource-customization-allowlist).

## Limitations

* Using the Kubernetes Gateway API for [egress traffic management][istio-deploy-egress] with the Istio add-on is only supported for the [manual deployment model][istio-gateway-manual-deployment].
* ConfigMap customizations for `Gateway` resources must fall within the [resource customization allowlist](#resource-customization-allowlist). Fields not on the allowlist are disallowed and blocked via add-on managed webhooks. See the [Istio add-on support policy][istio-support-policy] for more information `allowed`, `blocked`, and `supported` features.  

## Prerequisites

* Enable the [Managed Gateway API Installation][managed-gateway-addon].
* Install Istio add-on revision `asm-1-26` or higher. Follow the [installation guide][istio-deploy-addon] if you don't have the Istio add-on installed yet, or the [upgrade guide][istio-upgrade] if you are on a lower minor revision.

## Configure ingress using a Kubernetes Gateway

### Deploy sample application

First, deploy the sample `httpbin` application in the `default` namespace:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/httpbin/httpbin.yaml
```

### Create Kubernetes Gateway and HTTPRoute

Next, deploy a Gateway API configuration in the `default` namespace with the `gatewayClassName` set to `istio`. 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  gatewayClassName: istio
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
  name: http
  namespace: default
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
> The example above creates an external ingress load balancer service that's accessible from outside the cluster. You can add [annotations][annotation-customizations] to create an internal load balancer and customize other load balancer settings.

> [!NOTE]
> If you are performing a [minor revision upgrade][istio-upgrade] and have two Istio add-on revisions installed on your cluster simultaneously, by default the control plane for the higher minor revision takes ownership of the `Gateways`. You can add the `istio.io/rev` label to the `Gateway` to control which control plane revision owns it. If you add the revision label, make sure that you update it accordingly to the appropriate control plane revision before rolling back or completing the upgrade operation.

Verify that a `Deployment`, `Service`, `HorizontalPodAutoscaler`, and `PodDisruptionBudget` get created for `httpbin-gateway`:

```bash
kubectl get deployment httpbin-gateway-istio
```
```output
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
httpbin-gateway-istio   2/2     2            2           31m
```

```bash
kubectl get service httpbin-gateway-istio
```
```output
NAME                    TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)                        AGE
httpbin-gateway-istio   LoadBalancer   10.0.65.45   <external-ip>    15021:32053/TCP,80:31587/TCP   33m
```

```bash
kubectl get hpa httpbin-gateway-istio
```
```output
NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   2         5         3          34m
```

```bash
kubectl get pdb httpbin-gateway-istio
```
```output
NAME                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
httpbin-gateway-istio   1               N/A               2                     36m
```

You can [configure these resource settings](#resource-customizations) by modifying the `GatewayClass` defaults ConfigMap or by attaching a ConfigMap to a specific `Gateway`.

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

### Securing Istio ingress traffic with the Kubernetes Gateway API

The Istio add-on supports syncing secrets from Azure Key Vault (AKV) for securing Gateway API-based ingress traffic with [Transport Layer Security (TLS) termination][istio-tls-termination] or [Server Name Indication (SNI) passthrough][istio-sni-passthrough]. You can follow the [secure ingress gateway][istio-secure-gateways] document for syncing secrets from AKV onto your AKS cluster using the [AKV Secrets Store Container Storage Interface (CSI) Driver add-on][aks-csi-driver].

## Resource customizations

### Annotation customizations

You can add annotations under `spec.infrastructure.annotations` to [configure load balancer settings][azure-aks-load-balancer-annotations] for the `Gateway`. For instance, to create an internal load balancer attached to a specific subnet, you can create a `Gateway` with the following annotations:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  infrastructure:
    annotations: 
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "my-subnet"
EOF
```

### ConfigMap customizations

The Istio add-on also [supports customizations of the resources][istio-gateway-auto-deployment] generated for the `Gateways`, namely:

* Service
* Deployment
* Horizontal Pod Autoscaler (HPA)
* Pod Disruption Budget (PDB)

The [default settings for these resources][istio-gateway-class-cm] are set in the `istio-gateway-class-defaults` ConfigMap in the `aks-istio-system` namespace. This ConfigMap must have the `gateway.istio.io/defaults-for-class` label set to `istio` for the customizations to take effect for all `Gateways` with `spec.gatewayClassName: istio`. The `GatewayClass`-level ConfigMap is installed by default in the `aks-istio-system` namespace when the [Managed Gateway API installation][managed-gateway-addon] is enabled. It could take up to ~5 minutes for the `istio-gateway-class-defaults` ConfigMap to get deployed after installing the Managed Gateway API CRDs.

```bash
kubectl get configmap istio-gateway-class-defaults -n aks-istio-system -o yaml
```

```yaml
...
data:
  horizontalPodAutoscaler: |
    spec:
      minReplicas: 2
      maxReplicas: 5
  podDisruptionBudget: |
    spec:
      minAvailable: 1
...
```

As detailed in the subsequent sections, you can modify these settings for all Istio `Gateways` at a `GatewayClass` level by updating the `istio-gateway-class-defaults` ConfigMap, or you can set them for individual `Gateway` resources. For both the `GatewayClass`-level and `Gateway`-level `ConfigMaps`, fields must be allowlisted for the given resource. If there are customizations both for the `GatewayClass` and an individual `Gateway`, the `Gateway`-level configuration takes precedence.

### Resource customization allowlist

Fields not on the allowlist for the resource are disallowed and blocked via add-on managed webhooks. See the [Istio add-on support policy][istio-support-policy] for more information `allowed`, `blocked`, and `supported` features.

#### Deployment Fields

| Field Path | Description |
|------------|----------|
| `metadata.labels` | Deployment labels |
| `metadata.annotations` | Deployment annotations |
| `spec.replicas` | Deployment replica count |
| `spec.template.metadata.labels` | Pod labels |
| `spec.template.metadata.annotations` | Pod annotations |
| `spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms` | Node affinity |
| `spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Node affinity |
| `spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution` | Pod affinity|
| `spec.template.spec.affinity.podAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Pod affinity |
| `spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution` | Pod anti-affinity |
| `spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Pod anti-affinity |
| `spec.template.spec.containers.resizePolicy` | Container resource utilization |
| `spec.template.spec.containers.resources.limits` | Container resource utilization |
| `spec.template.spec.containers.resources.requests` | Container resource utilization |
| `spec.template.spec.containers.stdin` | Container debugging |
| `spec.template.spec.containers.stdinOnce` | Container debugging |
| `spec.template.spec.nodeSelector` | Pod scheduling |
| `spec.template.spec.nodeName` | Pod scheduling |
| `spec.template.spec.tolerations` | Pod scheduling |
| `spec.template.spec.topologySpreadConstraints` | Pod scheduling |

#### Service Fields

| Field Path | Description |
|------------|----------|
| `metadata.labels` | Service labels |
| `metadata.annotations` | Service annotations |
| `spec.type` | Service type |
| `spec.loadBalancerSourceRanges` | Service load balancer settings |
| `spec.loadBalancerClass` | Service load balancer settings |
| `spec.externalTrafficPolicy` | Service traffic policy |
| `spec.internalTrafficPolicy` | Service traffic policy |

#### HorizontalPodAutoscaler (HPA) Fields

| Field Path | Description |
|------------|----------|
| `metadata.labels` | HPA labels |
| `metadata.annotations` | HPA annotations |
| `spec.behavior.scaleUp.stabilizationWindowSeconds` | HPA scale-up behavior |
| `spec.behavior.scaleUp.selectPolicy` | HPA scale-up behavior |
| `spec.behavior.scaleUp.policies` | HPA scale-up behavior |
| `spec.behavior.scaleDown.stabilizationWindowSeconds` | HPA scale-down behavior |
| `spec.behavior.scaleDown.selectPolicy` | HPA scale-down behavior |
| `spec.behavior.scaleDown.policies` | HPA scale-down behavior |
| `spec.metrics` | HPA scaling resource metrics |
| `spec.minReplicas` | HPA minimum replica count. Must not be below 2. |
| `spec.maxReplicas` | HPA maximum replica count |

#### PodDisruptionBudget (PDB) Fields

| Field Path | Description |
|------------|----------|
| `metadata.labels` | PDB labels|
| `metadata.annotations` | PDB annotations |
| `spec.minAvailable` | PDB minimum availability |
| `spec.unhealthyPodEvictionPolicy` | PDB eviction policy |

> [!NOTE]
> Modifying the `PDB` minimum availability and eviction policy can lead to potential errors during cluster/node upgrade and deletion operations. Follow the [PDB troubleshooting guide][pdb-troubleshooting] to address UpgradeFailed errors due to `PDB` eviction failures.

### Configure GatewayClass-level settings

Update the `GatewayClass`-level ConfigMap in the `aks-istio-system` namespace:

```bash
kubectl edit cm istio-gateway-class-defaults -n aks-istio-system
```

Edit the resource settings:
```
...
data:
  deployment: |
    metadata:
      labels:
        test.azureservicemesh.io/deployment-config: "updated"
  horizontalPodAutoscaler: |
    spec:
      minReplicas: 3
      maxReplicas: 6
  podDisruptionBudget: |
    spec:
      minAvailable: 1
...
```

> [!NOTE]
> Only one ConfigMap per `GatewayClass` is allowed.

Now, you should see the `HPA` for `httpbin-gateway` that you created earlier get updated:

```bash
kubectl get hpa httpbin-gateway-istio
```
```output
NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   3         6         3          36m
```

Also verify that the `Deployment` is updated with the new label:

```bash
kubectl get deployment httpbin-gateway-istio -ojsonpath='{.metadata.labels.test\.azureservicemesh\.io\/deployment-config}'
```
```output
updated
```

### Configure settings for a specific gateway

Create a ConfigMap with resource customizations for the `httpbin` `Gateway`:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: gw-options
data:
  horizontalPodAutoscaler: |
    spec:
      minReplicas: 2
      maxReplicas: 4
  deployment: |
    metadata:
      labels:
        test.azureservicemesh.io/deployment-config: "updated-per-gateway"
EOF
```

Update the `httpbin` `Gateway` to reference the ConfigMap:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  gatewayClassName: istio
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: gw-options
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
EOF
```

Verify that the `HPA` is updated with the new min/max values. If you also configured the `GatewayClass`-level ConfigMap, the `Gateway`-level settings should take precedence:

```bash
kubectl get hpa httpbin-gateway-istio
```
```output
NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   2         4         2          4h14m
```

Also inspect the `Deployment` labels to ensure that the `test.azureservicemesh.io/deployment-config` is updated to the new value:

```bash
kubectl get deployment httpbin-gateway-istio -ojsonpath='{.metadata.labels.test\.azureservicemesh\.io\/deployment-config}'
```
```output
updated-per-gateway
```
## Next steps

* [Deploy egress gateways for the Istio service mesh add-on][istio-deploy-egress]

[aks-csi-driver]: ./csi-secrets-store-driver.md
[istio-deploy-addon]: istio-deploy-addon.md
[istio-deploy-egress]: istio-deploy-egress.md
[istio-deploy-ingress]: istio-deploy-ingress.md
[istio-secure-gateways]: istio-secure-gateway.md
[istio-support-policy]: istio-support-policy.md#allowed-supported-and-blocked-customizations
[istio-upgrade]: istio-upgrade.md
[managed-gateway-addon]: managed-gateway-api.md
[annotation-customizations]: #annotation-customizations
[azure-aks-load-balancer-annotations]: load-balancer-standard.md#customizations-via-kubernetes-annotations

[istio-gateway-auto-deployment]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#automated-deployment
[istio-gateway-manual-deployment]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#manual-deployment
[istio-gateway-class-cm]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#gatewayclass-defaults
[istio-tls-termination]: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
[istio-sni-passthrough]: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-sni-passthrough/
[pdb-troubleshooting]: /troubleshoot/azure/azure-kubernetes/create-upgrade-delete/error-code-poddrainfailure
