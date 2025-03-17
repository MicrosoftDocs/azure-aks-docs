---
title: Azure Kubernetes Service (AKS) external or internal ingresses for Istio service mesh add-on
description: Deploy external or internal ingresses for Istio service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.service: azure-kubernetes-service
author: shashankbarsin
ms.date: 08/07/2023
ms.author: shasb
---

# Azure Kubernetes Service (AKS) external or internal ingresses for Istio service mesh add-on deployment

This article shows you how to deploy external or internal ingresses for Istio service mesh add-on for Azure Kubernetes Service (AKS) cluster.

> [!NOTE]
> When performing a [minor revision upgrade](./istio-upgrade.md#minor-revision-upgrades-with-the-ingress-gateway) of the Istio add-on, another deployment for the external / internal gateways will be created for the new control plane revision.

## Prerequisites

This guide assumes you followed the [documentation][istio-deploy-addon] to enable the Istio add-on on an AKS cluster, deploy a sample application, and set environment variables.

## Enable external ingress gateway

Use `az aks mesh enable-ingress-gateway` to enable an externally accessible Istio ingress on your AKS cluster:

```azurecli-interactive
az aks mesh enable-ingress-gateway --resource-group $RESOURCE_GROUP --name $CLUSTER --ingress-gateway-type external
```

Use `kubectl get svc` to check the service mapped to the ingress gateway:

```bash
kubectl get svc aks-istio-ingressgateway-external -n aks-istio-ingress
```

Observe from the output that the external IP address of the service is a publicly accessible one:

```
NAME                                TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.10.249   <EXTERNAL_IP>   15021:30705/TCP,80:32444/TCP,443:31728/TCP   4m21s
```

> [!NOTE]
> Customizations to IP address on internal and external gateways aren't supported yet. IP address customizations on the ingress specifications are reverted back by the Istio add-on.It's planned to allow these customizations in the Gateway API implementation for the Istio add-on in future.

Applications aren't accessible from outside the cluster by default after enabling the ingress gateway. To make an application accessible, map the sample deployment's ingress to the Istio ingress gateway using the following manifest:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway-external
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo-vs-external
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway-external
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
EOF
```

> [!NOTE]
> The selector used in the Gateway object points to `istio: aks-istio-ingressgateway-external`, which can be found as label on the service mapped to the external ingress that was enabled earlier.

Set environment variables for external ingress host and ports:

```bash
export INGRESS_HOST_EXTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT_EXTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL_EXTERNAL=$INGRESS_HOST_EXTERNAL:$INGRESS_PORT_EXTERNAL
```

Retrieve the external address of the sample application:

```bash
echo "http://$GATEWAY_URL_EXTERNAL/productpage"
```

Navigate to the URL from the output of the previous command and confirm that the sample application's product page is displayed. Alternatively, you can also use `curl` to confirm the sample application is accessible. For example:

```bash
curl -s "http://${GATEWAY_URL_EXTERNAL}/productpage" | grep -o "<title>.*</title>"
```

Confirm that the sample application's product page is accessible. The expected output is:

```html
<title>Simple Bookstore App</title>
```

## Enable internal ingress gateway

Use `az aks mesh enable-ingress-gateway` to enable an internal Istio ingress on your AKS cluster:

```azurecli-interactive
az aks mesh enable-ingress-gateway --resource-group $RESOURCE_GROUP --name $CLUSTER --ingress-gateway-type internal
```

Use `kubectl get svc` to check the service mapped to the ingress gateway:

```bash
kubectl get svc aks-istio-ingressgateway-internal -n aks-istio-ingress
```

Observe from the output that the external IP address of the service isn't a publicly accessible one and is instead only locally accessible:

```
NAME                                TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                                      AGE
aks-istio-ingressgateway-internal   LoadBalancer   10.0.182.240  <IP>      15021:30764/TCP,80:32186/TCP,443:31713/TCP   87s
```

After enabling the ingress gateway, applications need to be exposed through the gateway and routing rules need to be configured accordingly. Use the following manifest to map the sample deployment's ingress to the Istio ingress gateway:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-internal-gateway
spec:
  selector:
    istio: aks-istio-ingressgateway-internal
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo-vs-internal
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-internal-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
EOF
```

> [!NOTE]
> The selector used in the Gateway object points to `istio: aks-istio-ingressgateway-internal`, which can be found as label on the service mapped to the internal ingress that was enabled earlier.

Set environment variables for internal ingress host and ports:

```bash
export INGRESS_HOST_INTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-internal -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT_INTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-internal -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL_INTERNAL=$INGRESS_HOST_INTERNAL:$INGRESS_PORT_INTERNAL
```

Retrieve the address of the sample application:

```bash
echo "http://$GATEWAY_URL_INTERNAL/productpage"
```

Navigate to the URL from the output of the previous command and confirm that the sample application's product page is  **NOT** displayed. Alternatively, you can also use `curl` to confirm the sample application is **NOT** accessible. For example:

```bash
curl -s "http://${GATEWAY_URL_INTERNAL}/productpage" | grep -o "<title>.*</title>"
```

Use `kubectl exec` to confirm application is accessible from inside the cluster's virtual network:

```bash
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS  "http://$GATEWAY_URL_INTERNAL/productpage"  | grep -o "<title>.*</title>"
```

Confirm that the sample application's product page is accessible. The expected output is:

```html
<title>Simple Bookstore App</title>
```

## Ingress gateway service annotation customization

The following annotations can be added to the Kubernetes service for the external and internal ingress gateways:

- `service.beta.kubernetes.io/azure-load-balancer-internal-subnet`: name of subnet to bind internal ingress gateway to. This subnet must exist in the same virtual network as the mesh.
- `service.beta.kubernetes.io/azure-shared-securityrule`: for exposing the ingress gateway through an [augmented security rule][azure-nsg-docs].
- `service.beta.kubernetes.io/azure-allowed-service-tags`: for specifying which [service tags][azure-service-tags] the ingress gateway can receive requests from.
- `service.beta.kubernetes.io/azure-load-balancer-ipv4`: for configuring a static IPv4 address.
- `service.beta.kubernetes.io/azure-load-balancer-resource-group`: for specifying the resource group of a public IP in a different resource group from the cluster.
- `service.beta.kubernetes.io/azure-pip-name`: for specifying the name of a public IP address.
- `external-dns.alpha.kubernetes.io/hostname`: for specifying the domain for resource's DNS records. For more information, see [external-dns][external-dns].

The add-on supports health probe annotations for ports 80 and 443. Learn more about the usage of ports [here][azure-load-balancer-annotations-for-ports].

## Delete resources

If you want to clean up the Istio external or internal ingress gateways, but leave the mesh enabled on the cluster, run the following command:

```azurecli-interactive
az aks mesh disable-ingress-gateway --ingress-gateway-type <external/internal> --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

If you want to clean up the Istio service mesh and the ingresses (leaving behind the cluster), run the following command:

```azurecli-interactive
az aks mesh disable --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

If you want to clean up all the resources created from the Istio how-to guidance documents, run the following command:

```azurecli-interactive
az group delete --name ${RESOURCE_GROUP} --yes --no-wait
```

## Next steps

> [!NOTE]
> If there are issues encountered with deploying the Istio ingress gateway or configuring ingress traffic routing, refer to [article on troubleshooting Istio add-on ingress gateways][istio-ingress-tsg]

* [Secure ingress gateway for Istio service mesh add-on][istio-secure-gateway]
* [Scale ingress gateway Horizontal Pod Autoscaler][istio-scaling-guide]

[istio-deploy-addon]: istio-deploy-addon.md
[istio-secure-gateway]: istio-secure-gateway.md
[istio-scaling-guide]: istio-scale.md#scaling
[istio-ingress-tsg]: /troubleshoot/azure/azure-kubernetes/extensions/istio-add-on-ingress-gateway
[azure-nsg-docs]: /azure/virtual-network/network-security-groups-overview#augmented-security-rules
[azure-service-tags]: /azure/virtual-network/service-tags-overview
[external-dns]: https://kubernetes-sigs.github.io/external-dns/latest/docs/annotations/annotations/#external-dnsalphakubernetesiohostname
[azure-load-balancer-annotations-for-ports]: /azure/aks/load-balancer-standard#customize-the-load-balancer-health-probe
