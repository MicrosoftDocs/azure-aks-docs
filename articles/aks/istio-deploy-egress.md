---
title: Azure Kubernetes Service (AKS) egress gateway for Istio service mesh add-on
description: Deploy egress gateways for Istio service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.date: 04/25/2025
ms.author: nshankar
---

# Deploy egress gateways for Istio service mesh add-on for Azure Kubernetes Service (Preview)

This article shows you how to deploy egress gateways for the Istio service mesh add-on for Azure Kubernetes Service (AKS) cluster.

## Overview

The Istio egress gateway can serve as a centralized point to monitor and restrict outbound traffic from applications in the mesh. With the Istio add-on, you can deploy multiple egress gateways across different namespaces, allowing you to set up an egress gateway topology of your choice: egress gateways per-cluster, per-namespace, per-workload, etc. While AKS manages the provisioning and lifecycle of the Istio add-on egress gateways, you must create Istio custom resources to route traffic from applications in the mesh through the egress gateway and apply policies and telemetry collection.

The Istio add-on egress gateway also takes a hard dependency on the [Static Egress Gateway][static-egress-gateway] feature, which assigns a fixed source IP address prefix to the Istio egress Pods that you can use for firewall rules and other traffic filtering mechanisms. Thus, you can apply Istio L7, identity-based policies and IP-based restrictions for defense-in-depth egress traffic control.

## Limitations and requirements

- You can deploy a maximum of `500` Istio egress gateways per cluster. 
- Istio add-on egress gateway names must be unique per namespace.
- Istio add-on egress gateway names must be between `1-53` characters, must only consist of lowercase alphanumerical characters, '-' and '.,' and must start and end with an alphanumerical character. Names should also be a valid DNS name. The regex used for name validation is `^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$`.
- Gateway API is currently not supported for the Istio add-on egress gateway.
- Because Static Egress Gateway is currently not supported on [Azure CNI Pod Subnet clusters][azure-cni-pod-subnet], the Istio add-on egress gateway is not supported on Pod Subnet clusters either.

## Prerequisites

### Enable Istio add-on

This guide assumes you followed the [documentation][istio-deploy-addon] to enable the Istio add-on on an AKS cluster.

### Install the `aks-preview` Azure CLI extension

Install the `aks-preview` extension if you're using Azure CLI.

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Enable and Configure Static Egress Gateway

Follow the instructions in the [Static Egress Gateway documentation][static-egress-gateway] to enable Static Egress Gateway on your cluster, create an agent pool of mode `gateway`, and create a `StaticGatewayConfiguration` resource.

## Enable an Istio egress gateway

> [!NOTE]
> The Istio add-on egress gateway pods do not get scheduled onto the `gateway` node pool. The `gateway` node pool is only used to route egress traffic and doesn't serve general-purpose workloads. If you need the egress gateway pods scheduled onto particular nodes, you can use [AKS system nodes][aks-system-nodes] or the `azureservicemesh/istio.replica.preferred` label. The pods have node affinities with a weighted preference of `100` for AKS system nodes (labeled `kubernetes.azure.com/mode: system`), and a weighted preference of `50` for nodes labeled `azureservicemesh/istio.replica.preferred: true`.

Use `az aks mesh enable-egress-gateway` to enable an Istio egress gateway on your AKS cluster. You must specify a name for the Istio egress gateway and the name of the `StaticGatewayConfiguration` that you created in the [prerequisites](#prerequisites) step. You can also specify a namespace to deploy the Istio egress gateway in, which must be the same namespace that the `StaticGatewayConfiguration` was created in. If you don't specify a namespace, the egress gateway will be provisioned in the `aks-istio-egress` namespace. 

As a best-practice, you should wait until the `StaticGatewayConfiguration` is assigned an `egressIpPrefix` before enabling the Istio egress gateway using that gateway configuration. 

```azurecli-interactive
az aks mesh enable-egress-gateway --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --istio-egressgateway-name $ISTIO_EGRESS_NAME --istio-egressgateway-namespace $ISTIO_EGRESS_NAMESPACE --gateway-configuration-name $ISTIO_SGC_NAME
```

Verify that the service has been created for the egress gateway. 

```bash
kubectl get svc $ISTIO_EGRESS_NAME -n $ISTIO_EGRESS_NAMESPACE
```

You should see a `ClusterIP` service for the egress gateway:

```
NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                    AGE
asm-egress-test   ClusterIP   10.0.128.17   <none>        15021/TCP,80/TCP,443/TCP   6d4h
```

You can also verify that a deployment has been created for the Istio egress gateway and that the egress gateway pods have the `kubernetes.azure.com/static-gateway-configuration` annotation set to the `gatewayConfigurationName`.

```bash
ASM_REVISION=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME | jq '.serviceMeshProfile.istio.revisions[0]' | sed 's/"//g')

kubectl get deployment $ISTIO_EGRESS_NAME-$ASM_REVISION -n $ISTIO_EGRESS_NAMESPACE -o jsonpath={.spec.template.metadata.annotations."kubernetes\.azure\.com\/static-gateway-configuration"}
```

You can run the `az aks mesh enable-egress-gateway` command again to create another Istio egress gateway. 

> [!NOTE]
> When performing a [minor revision upgrade](./istio-upgrade.md#minor-revision-upgrades-with-ingress-and-egress-gateways) of the Istio add-on, another deployment for each egress gateway will be created for the new control plane revision.

## Route traffic through the Istio egress gateway

### Set `outboundTrafficPolicy.mode`
By default, the Istio `outboundTrafficPolicy.mode` is set to `ALLOW_ANY`, meaning that Envoy will pass through requests for unknown services. As a security best-practice, it is recommended to set the Istio `outboundTrafficPolicy.mode` to `REGISTRY_ONLY` so that the Istio proxy blocks requests to services that haven't been added to Istio's Service Registry. You can add hosts outside of the cluster to Istio's service registry with a `ServiceEntry`. 

You can configure the `outboundTrafficPolicy.mode` on a mesh-wide level using the Istio add-on [shared MeshConfig][shared-mesh-config], or use the [Sidecar Custom Resource][sidecar-cr] to target specific namespaces or workloads.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-shared-configmap-asm-1-24
  namespace: aks-istio-system
data:
  mesh: |-
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
```

### Deploy sample application

In this example, we will deploy the `curl` application in the same namespace as the Istio add-on egress gateway. Remember to label the `ISTIO_EGRESS_NAMESPACE` with the `istio.io/rev` label so that the deployed application pod will be injected with a sidecar:

```bash
kubectl label namespace $ISTIO_EGRESS_NAMESPACE istio.io/rev=$ASM_REVISION
```

Then, deploy the sample application:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/curl/curl.yaml -n $ISTIO_EGRESS_NAMESPACE
```

You should see the `curl` pod running with an injected sidecar container:

```
NAME                                       READY   STATUS    RESTARTS   AGE
curl-5b549b49b8-bcgts                      2/2     Running   0          13s
```

Try sending a request from `curl` directly to `edition.cnn.com`: 

```bash
SOURCE_POD=$(kubectl get pod -n $ISTIO_EGRESS_NAMESPACE -l app=curl -o jsonpath={.items..metadata.name})

kubectl exec -n $ISTIO_EGRESS_NAMESPACE "$SOURCE_POD" -c curl -- curl -sSL -o /dev/null -D - http://edition.cnn.com/politics
```

If you set `outboundTrafficPolicy.mode` to `REGISTRY_ONLY`, then the `curl` request should fail because you haven't created a `ServiceEntry` for `edition.cnn.com`. If `outboundTrafficPolicy.mode` is `ALLOW_ANY`, then the request should succeed. 

To actually route requests to `edition.cnn.com` from the `curl` pod to the Istio add-on egress gateway, you need to create a `ServiceEntry` and configure other Istio custom resources. Follow instructions one of the subsequent sections to configure an [HTTP Egress Gateway](#configure-an-http-istio-egress-gateway), [HTTPS Egress Gateway](#configure-an-https-istio-egress-gateway), or an [Egress Gateway that originates a TLS connection](#configure-an-istio-egress-gateway-to-perform-tls-origination).

Before starting any of the following scenarios, set these environment variables:

```bash
ISTIO_EGRESS_DEPLOYMENT=$ISTIO_EGRESS_NAME-$ASM_REVISION
EGRESS_GTW_SELECTOR=$(kubectl get deployment $ISTIO_EGRESS_DEPLOYMENT -n $ISTIO_EGRESS_NAMESPACE -o jsonpath={.metadata.labels.istio})
```

It's also recommended to [enable Envoy access logging][envoy-access-logging] either through the [MeshConfig][shared-mesh-config] or [Telemetry API][istio-telemetry-api]. Once you have access logging enabled, you can verify that traffic is flowing through the egress gateway by inspecting the `istio-proxy` container logs:

```bash
kubectl logs -l istio=$EGRESS_GTW_SELECTOR -n $ISTIO_EGRESS_NAMESPACE
```

### Configure an HTTP Istio egress gateway

1. Create a `ServiceEntry` for `edition.cnn.com`:

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: cnn
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 80
    name: http-port
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
EOF
```

2. Create the `Gateway`, `VirtualService`, and `DestinationRule` to route HTTP traffic from the `curl` application to `edition.cnn.com` through the egress gateway. Be sure to set the gateway selector and service Fully Qualified Domain Name (FQDN) accordingly based on the `istio` label selector in the egress gateway deployment.

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: $EGRESS_GTW_SELECTOR
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - edition.cnn.com
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
  subsets:
  - name: cnn
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - edition.cnn.com
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
        subset: cnn
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 80
      weight: 100
EOF
```

3. Try sending an HTTP request from the `curl` pod to `edition.cnn.com`:

```bash
kubectl exec -n $ISTIO_EGRESS_NAMESPACE "$SOURCE_POD" -c curl -- curl -sSL -o /dev/null -D - http://edition.cnn.com/politics
```

You should see an `HTTP/2 200` response.

4. Clean up resources

```bash
kubectl delete serviceentry cnn -n $ISTIO_EGRESS_NAMESPACE
kubectl delete gateway istio-egressgateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete virtualservice direct-cnn-through-egress-gateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete destinationrule egressgateway-for-cnn -n $ISTIO_EGRESS_NAMESPACE
```

### Configure an HTTPS Istio egress gateway

1. Create an HTTPS `ServiceEntry` for `edition.cnn.com`:

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: cnn
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 443
    name: tls
    protocol: TLS
  resolution: DNS
EOF
```

2. Create the `Gateway`, `VirtualService`, and `DestinationRule` to route HTTP traffic from the `curl` application to `edition.cnn.com` through the egress gateway. Be sure to set the gateway selector and service FQDN accordingly based on the `istio` label selector in the egress gateway deployment.

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: $EGRESS_GTW_SELECTOR
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - edition.cnn.com
    tls:
      mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
  subsets:
  - name: cnn
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - edition.cnn.com
  gateways:
  - mesh
  - istio-egressgateway
  tls:
  - match:
    - gateways:
      - mesh
      port: 443
      sniHosts:
      - edition.cnn.com
    route:
    - destination:
        host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
        subset: cnn
        port:
          number: 443
  - match:
    - gateways:
      - istio-egressgateway
      port: 443
      sniHosts:
      - edition.cnn.com
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 443
      weight: 100
EOF
```

3. Try sending an HTTPS request from `curl` to `edition.cnn.com`: 

```bash
kubectl exec "$SOURCE_POD" -n $ISTIO_EGRESS_NAMESPACE -c curl -- curl -sSL -o /dev/null -D - https://edition.cnn.com/politics
```

You should see an `HTTP/2 200` response.

4. Clean up resources

```bash
kubectl delete serviceentry cnn -n $ISTIO_EGRESS_NAMESPACE
kubectl delete gateway istio-egressgateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete virtualservice direct-cnn-through-egress-gateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete destinationrule egressgateway-for-cnn -n $ISTIO_EGRESS_NAMESPACE
```

### Configure an Istio egress gateway to perform TLS Origination

1. Create a `ServiceEntry` for `edition.cnn.com`:

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: cnn
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
EOF
```

2. Create the `Gateway`, `VirtualService`, and `DestinationRule` to route HTTP traffic from the `curl` application to `edition.cnn.com` through the egress gateway, and to perform TLS origination at the egress gateway. Be sure to set the gateway selector and service FQDN accordingly based on the `istio` label selector in the egress gateway deployment.

```bash
kubectl apply -n $ISTIO_EGRESS_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: $EGRESS_GTW_SELECTOR
  servers:
  - port:
      number: 80
      name: https-port-for-tls-origination
      protocol: HTTPS
    hosts:
    - edition.cnn.com
    tls:
      mode: ISTIO_MUTUAL
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
  subsets:
  - name: cnn
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
      portLevelSettings:
      - port:
          number: 80
        tls:
          mode: ISTIO_MUTUAL
          sni: edition.cnn.com
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - edition.cnn.com
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: $ISTIO_EGRESS_NAME.$ISTIO_EGRESS_NAMESPACE.svc.cluster.local
        subset: cnn
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 443
      weight: 100
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: originate-tls-for-edition-cnn-com
spec:
  host: edition.cnn.com
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    portLevelSettings:
    - port:
        number: 443
      tls:
        mode: SIMPLE # initiates HTTPS for connections to edition.cnn.com
EOF
```

3. Try sending a request form `curl` to `edition.cnn.com` with the egress gateway performing TLS origination;

```bash
kubectl exec "${SOURCE_POD}" -n $ISTIO_EGRESS_NAMESPACE -c curl -- curl -sSL -o /dev/null -D - http://edition.cnn.com/politics
```

You should see a `200` status response. 

4. Clean up resources

```bash
kubectl delete serviceentry cnn -n $ISTIO_EGRESS_NAMESPACE
kubectl delete gateway istio-egressgateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete virtualservice direct-cnn-through-egress-gateway -n $ISTIO_EGRESS_NAMESPACE
kubectl delete destinationrule originate-tls-for-edition-cnn-com -n $ISTIO_EGRESS_NAMESPACE
kubectl delete destinationrule egressgateway-for-cnn -n $ISTIO_EGRESS_NAMESPACE
```

## Disable the Istio egress gateway

Run the `az aks mesh disable-egress-gateway` command to disable the one or more Istio add-on egress gateways that you created:

```azurecli-interactive
az aks mesh disable-egress-gateway --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --istio-egressgateway-name $ISTIO_EGRESS_NAME --istio-egressgateway-namespace $ISTIO_EGRESS_NAMESPACE
```

Once you disable the Istio egress gateway, you should be able to delete the `StaticGatewayConfiguration`, namespace, and `gateway` agent pool that the egress gateway was using if no other Istio egress gateway is using them.

## Next steps

* [Deploy external or internal ingresses for Istio service mesh add-on][istio-deploy-ingress]

> [!NOTE]
> If there are any issues encountered with deploying the Istio ingress gateway or configuring ingress traffic routing, refer to [article on troubleshooting Istio add-on ingress gateways][istio-ingress-tsg]

[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[static-egress-gateway]: configure-static-egress-gateway.md
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
[shared-mesh-config]: istio-meshconfig.md
[istio-telemetry-api]: istio-telemetry.md
[sidecar-cr]: https://istio.io/latest/docs/reference/config/networking/sidecar/#OutboundTrafficPolicy
[envoy-access-logging]: https://istio.io/latest/docs/tasks/observability/logs/access-log/
[istio-deploy-ingress]: istio-deploy-ingress.md
[istio-deploy-addon]: istio-deploy-addon.md