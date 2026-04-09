---
title: Traffic Management Use Cases for Azure Kubernetes Application Network (Preview)
description: Learn how to use Azure Kubernetes Application Network for traffic management with Istio ambient mode and Kubernetes Gateway API, including L4/L7 authorization policies, JWT claim-based routing, traffic shifting, and fault injection across multiple AKS clusters.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: how-to
ms.date: 03/19/2026
---

# Traffic management use cases for Azure Kubernetes Application Network (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network traffic management uses Istio [ambient mode](https://istio.io/latest/docs/ambient/) and the [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) to enable precise control over service-to-service interactions within and across clusters. This solution offers a comprehensive set of traffic management capabilities, including:

- L4/L7 authorization policies
- JWT claim-based routing
- Traffic shifting
- Fault injection

This article provides step-by-step instructions on how to implement these traffic management use cases using Azure Kubernetes Application Network across multiple Azure Kubernetes Service (AKS) clusters.

## Prerequisites

Before you begin, ensure you have the following prerequisites in place:

- An [existing Azure Kubernetes Application Network resource](./get-started.md#create-an-azure-kubernetes-application-network-resource).
- Two [existing AKS clusters](./get-started.md#create-an-aks-cluster) with network reachability between their east-west gateways. You can achieve this using [Azure virtual network (VNet) peering](/azure/virtual-network/virtual-network-peering-overview), [VNet to VNet VPN connection](/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal), or another supported connectivity model.
  - Both clusters must be [joined as members to your Azure Kubernetes Application Network](./get-started.md#join-an-aks-cluster-as-a-member-of-azure-kubernetes-application-network).
- The Istio CLI, [istioctl](https://istio.io/latest/docs/setup/install/istioctl/), installed. To select the correct version of istioctl, refer to the [supported Istio version](./supported-versions.md) for your Application Network. You can install istioctl using the following command:

    ```bash
    curl -sL https://istio.io/downloadIstioctl | sh -
    export PATH=$HOME/.istioctl/bin:$PATH
    ```

- Set the following environment variables for use throughout the article:

    ```bash
    export AKS_RG=<resource-group-name>
    export CLUSTER_NAME_1=<cluster-1-name>
    export CLUSTER_NAME_2=<cluster-2-name>
    ```

- Configure kubectl to connect to your AKS clusters using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command:

    ```azurecli-interactive
    az aks get-credentials --resource-group $AKS_RG --name $CLUSTER_NAME_1 --overwrite-existing
    az aks get-credentials --resource-group $AKS_RG --name $CLUSTER_NAME_2 --overwrite-existing
    ```

## Check Istio and ztunnel installation

1. Check Istio CRDs using the `kubectl get crds` command.
  
    ```bash
    kubectl --context $CLUSTER_NAME_1 get crds | grep istio
    ```

    Your output should show the following 14 CRDs for Istio ambient mode:

    ```output
    authorizationpolicies.security.istio.io                            2026-03-12T18:02:11Z
    destinationrules.networking.istio.io                               2026-03-12T18:02:11Z
    envoyfilters.networking.istio.io                                   2026-03-12T18:02:11Z
    gateways.networking.istio.io                                       2026-03-12T18:02:11Z
    peerauthentications.security.istio.io                              2026-03-12T18:02:11Z
    proxyconfigs.networking.istio.io                                   2026-03-12T18:02:11Z
    requestauthentications.security.istio.io                           2026-03-12T18:02:11Z
    serviceentries.networking.istio.io                                 2026-03-12T18:02:11Z
    sidecars.networking.istio.io                                       2026-03-12T18:02:11Z
    telemetries.telemetry.istio.io                                     2026-03-12T18:02:11Z
    virtualservices.networking.istio.io                                2026-03-12T18:02:11Z
    wasmplugins.extensions.istio.io                                    2026-03-12T18:02:11Z
    workloadentries.networking.istio.io                                2026-03-12T18:02:11Z
    workloadgroups.networking.istio.io                                 2026-03-12T18:02:11Z
    ```

1. Check Istio CNI and ztunnel DaemonSet are running in the `applink-system` namespace using the `kubectl get daemonset` command.

    ```bash
    kubectl --context $CLUSTER_NAME_1 --namespace applink-system get daemonset
    ```

    Your output should show the following DaemonSets with all pods in `READY` status:

    ```output
    NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
    istio-cni-node   3         3         3       3            3           kubernetes.io/os=linux   108m
    ztunnel          3         3         3       3            3           kubernetes.io/os=linux   107m
    ```

## Create sample application

### Application architecture

This architecture extends the [Bookinfo sample application](https://istio.io/latest/docs/ambient/getting-started/deploy-sample-app/) to run across multiple AKS clusters.

:::image type="content" source="./media/traffic-management-use-cases/traffic-management-sample-architecture.png" alt-text="Screenshot of an architecture diagram showing the Bookinfo sample application architecture running across two AKS clusters.":::

- **Cluster 1** hosts:
  - `productpage-v1` (Python)
  - `reviews-v1` (Java)
  - `details-v1` (Ruby)
- **Cluster 2** hosts:
  - `reviews-v2` (Java)
  - `reviews-v3` (Java)
  - `ratings-v1` (Node.js)

The `productpage` service sends requests to `reviews.default.svc.cluster.local`. Since the `reviews` service is available in both AKS clusters with global service scope, requests can be routed to any available backends (`reviews-v1`, `reviews-v2`, or `reviews-v3`) across clusters. The `reviews-v2` and `reviews-v3` services also call the `ratings` service to retrieve rating data before returning the response to `productpage`.

This architecture demonstrates how a distributed application can span across multiple clusters while continuing to use a consistent service name and communication pattern, enabling seamless service interaction across cluster boundaries.

### Deploy the application services

1. Deploy the `productpage` services to AKS cluster 1 using the following `kubectl apply` commands:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=productpage
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l account=productpage
    ```

1. Deploy the `reviews-v1` services to AKS cluster 1 using the following `kubectl apply` commands:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=reviews,service=reviews
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l account=reviews
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=reviews,version=v1
    ```

1. Deploy the `details` services to AKS cluster 1 using the following `kubectl apply` commands:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=details
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l account=details
    ```

1. Deploy the curl service to AKS cluster 1 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/curl/curl.yaml
    ```

1. Deploy the `reviews-v2` and `reviews-v3` services to AKS cluster 2 using the following `kubectl apply` commands:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=reviews,service=reviews
    kubectl --context $CLUSTER_NAME_2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l account=reviews
    kubectl --context $CLUSTER_NAME_2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app=reviews,version in (v2,v3)'
    ```

1. Deploy the `ratings` services to AKS cluster 2 using the following `kubectl apply` commands:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l app=ratings
    kubectl --context $CLUSTER_NAME_2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml -l account=ratings
    ```

### Deploy the ingress gateway

1. Deploy the ingress gateway to AKS cluster 1 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/gateway-api/bookinfo-gateway.yaml
    ```

1. Verify the gateway is programmed using the following `kubectl get gateway` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 --namespace default get gateway
    ```

    After about one minute, you should see output similar to the following, with `PROGRAMMED` showing as `True`:

    ```output
    NAME               CLASS   ADDRESS        PROGRAMMED   AGE
    bookinfo-gateway   istio   20.112.40.27   True         21s
    ```

### Add application to the mesh

- Add the application to the mesh by labeling the `default` namespace in both AKS clusters with `istio.io/dataplane-mode=ambient`:

    ```bash
    kubectl --context $CLUSTER_NAME_1 label namespace default istio.io/dataplane-mode=ambient
    kubectl --context $CLUSTER_NAME_2 label namespace default istio.io/dataplane-mode=ambient
    ```

### Install waypoint and mark services as global

1. Install `waypoint` gateways in both clusters using the following `istioctl waypoint apply` commands:

    ```bash
    istioctl --context $CLUSTER_NAME_1 waypoint apply --enroll-namespace --wait
    istioctl --context $CLUSTER_NAME_2 waypoint apply --enroll-namespace --wait
    ```

    Your output should look similar to the following, indicating that the `waypoint` has been applied and the `default` namespace has been labeled correctly in both clusters:

    ```output
    ✅ waypoint default/waypoint applied
    ✅ namespace default labeled with "istio.io/use-waypoint: waypoint"
    ✅ waypoint default/waypoint applied
    ✅ namespace default labeled with "istio.io/use-waypoint: waypoint"
    ```

1. Verify the `waypoint` gateways are programmed using the following `kubectl get gateway waypoint` command in both clusters:

    ```bash
    kubectl --context $CLUSTER_NAME_1 get gateway waypoint
    kubectl --context $CLUSTER_NAME_2 get gateway waypoint
    ```

    After about one minute, you should see output similar to the following in both clusters, with `PROGRAMMED` showing as `True`:

    ```output
    NAME       CLASS            ADDRESS       PROGRAMMED   AGE
    waypoint   istio-waypoint   10.1.78.229   True         28s
    ```

1. Mark the `reviews-v1` service in AKS cluster 1 and `reviews-v2` and `reviews-v3` services in AKS cluster 2 as global services by labeling them with `istio.io/global="true"`:

    ```bash
    kubectl --context $CLUSTER_NAME_1 label service reviews istio.io/global="true"
    kubectl --context $CLUSTER_NAME_2 label service reviews istio.io/global="true"
    ```

1. Mark the `waypoint` services as global services by labeling them with `istio.io/global="true"` in both clusters:

    ```bash
    kubectl --context $CLUSTER_NAME_1 label service waypoint istio.io/global="true"
    kubectl --context $CLUSTER_NAME_2 label service waypoint istio.io/global="true"
    ```

1. Verify global services from ztunnel configs in both clusters using the `istioctl zc service` command. You should see the `reviews` and `waypoint` services from both clusters with their respective VIPs under `SERVICE VIP` column.

    ```bash
    istioctl --context "$CLUSTER_NAME_1" zc service -n applink-system | awk 'NR==1 || $2=="reviews" || $2=="waypoint"'
    istioctl --context "$CLUSTER_NAME_2" zc service -n applink-system | awk 'NR==1 || $2=="reviews" || $2=="waypoint"'
    ```

    Your output should look similar to the following in both clusters, indicating that the `reviews` and `waypoint` services are recognized as global services with their VIPs:

    ```output
    # Output from cluster 1
    NAMESPACE         SERVICE NAME                 SERVICE VIP              WAYPOINT ENDPOINTS
    default           reviews                      10.1.36.199,10.1.164.195 waypoint 2/2
    default           waypoint                     10.1.78.229,10.1.135.117 None     2/2
    
    # Output from cluster 2
    NAMESPACE         SERVICE NAME                 SERVICE VIP              WAYPOINT ENDPOINTS
    default           reviews                      10.1.36.199,10.1.164.195 waypoint 3/3
    default           waypoint                     10.1.78.229,10.1.135.117 None     2/2
    ```

### Verify application access

> [!NOTE]
> If you can't access the application from the internet, make sure the network security group (NSG) associated with your cluster allows inbound internet traffic on TCP port `80` to the ingress gateway.

- Access the application through the ingress gateway using the following commands:

    ```bash
    export BOOK_INFO_GTW_IP=$(kubectl --context $CLUSTER_NAME_1 -n default get gateway bookinfo-gateway -o jsonpath="{.status.addresses[0].value}")
    echo $BOOK_INFO_GTW_IP
    curl -I http://$BOOK_INFO_GTW_IP/productpage
    ```

    Your output should look similar to the following, indicating that the application is accessible through the gateway:

    ```output
    20.112.40.27
    HTTP/1.1 200 OK
    server: istio-envoy
    date: Fri, 13 Mar 2026 17:52:13 GMT
    content-type: text/html; charset=utf-8
    content-length: 15070
    vary: Cookie
    x-envoy-upstream-service-time: 571
    ```

## Deploy L4/L7 authorization policies

### Enforce L4 authorization policy

1. Apply an L4 authorization policy to allow traffic to the `productpage` service only from the ingress gateway using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: security.istio.io/v1
    kind: AuthorizationPolicy
    metadata:
      name: productpage-ztunnel
      namespace: default
    spec:
      selector:
        matchLabels:
          app: productpage
      action: ALLOW
      rules:
      - from:
        - source:
            principals:
            - cluster.local/ns/default/sa/bookinfo-gateway-istio
    EOF
    ```

1. Verify you can still access the application through the ingress gateway using the following command:

    ```bash
    curl -I http://$BOOK_INFO_GTW_IP/productpage
    ```

    Your output should look similar to the following, indicating that the application is still accessible through the gateway:

    ```output
    HTTP/1.1 200 OK
    server: istio-envoy
    date: Fri, 13 Mar 2026 18:00:51 GMT
    content-type: text/html; charset=utf-8
    content-length: 15068
    vary: Cookie
    x-envoy-upstream-service-time: 19
    ```

1. Verify that access to the `productpage` service is blocked from other sources by trying to access it from the curl pod using the following command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec deploy/curl -- curl -s "http://productpage:9080/productpage"
    ```

    Your output should look similar to the following, indicating that access is denied due to the L4 authorization policy:

    ```output
    upstream connect error or disconnect/reset before headers. reset reason: connection termination
    ```

### Enforce L7 authorization policy

1. Apply an L7 authorization policy to allow only GET requests to the `productpage` service from the curl service account using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: security.istio.io/v1
    kind: AuthorizationPolicy
    metadata:
      name: productpage-waypoint
      namespace: default
    spec:
      targetRefs:
      - kind: Service
        group: ""
        name: productpage
      action: ALLOW
      rules:
      - from:
        - source:
            principals:
            - cluster.local/ns/default/sa/curl
        to:
        - operation:
            methods: ["GET"]
    EOF
    ```

1. Update the L4 authorization policy to allow traffic from the waypoint to ztunnel by adding the `waypoint` service account as an allowed principal using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: security.istio.io/v1
    kind: AuthorizationPolicy
    metadata:
      name: productpage-ztunnel
      namespace: default
    spec:
      selector:
        matchLabels:
          app: productpage
      action: ALLOW
      rules:
      - from:
        - source:
            principals:
            - cluster.local/ns/default/sa/bookinfo-gateway-istio
            - cluster.local/ns/default/sa/waypoint
    EOF
    ```

1. Verify `DELETE` operations to the `productpage` service are blocked from the curl service account using the following `kubectl exec` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec deploy/curl -- curl -s "http://productpage:9080/productpage" -X DELETE
    ```

    Your output should look similar to the following, indicating that access is denied due to the L7 authorization policy:

    ```output
    RBAC: access denied
    ```

1. Verify service accounts other than curl are blocked from accessing the `productpage` service using the following `kubectl exec` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec deploy/reviews-v1 -- curl -s http://productpage:9080/productpage
    ```

    Your output should look similar to the following, indicating that access is denied due to the L7 authorization policy:

    ```output
    RBAC: access denied
    ```

1. Verify that `GET` requests to the `productpage` service are allowed from the curl service account using the following `kubectl exec` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec deploy/curl -- curl -s http://productpage:9080/productpage | grep -o "<title>.*</title>"
    ```

    Your output should look similar to the following, indicating that GET requests are allowed and the `productpage` is accessible:

    ```output
    <title>Simple Bookstore App</title>
    ```

1. Verify the `productpage` is still accessible through the ingress gateway using the following command:

    ```bash
    curl -I http://$BOOK_INFO_GTW_IP/productpage
    ```

    Your output should look similar to the following, indicating that the `productpage` is still accessible through the gateway:

    ```output
    HTTP/1.1 200 OK
    server: istio-envoy
    date: Fri, 13 Mar 2026 18:07:02 GMT
    content-type: text/html; charset=utf-8
    content-length: 15070
    vary: Cookie
    x-envoy-upstream-service-time: 45
    ```

## Implement JWT claim-based routing

### Create ingress gateway and secure it with JWT authentication

1. Create a new namespace for the ingress gateway using the `kubectl create namespace` command.

    ```bash
    kubectl --context $CLUSTER_NAME_1 create namespace applink-ingress
    ```

1. Create an ingress gateway using the Kubernetes Gateway API and allow only routes from the same namespace using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: applink-ingressgateway
      namespace: applink-ingress
      labels:
        app: applink-ingressgateway
        istio: applink-ingressgateway
    spec:
      gatewayClassName: istio
      listeners:
      - name: http
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: Same
    EOF
    ```

1. Verify the gateway is programmed using the following `kubectl get gateway` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 -n applink-ingress get gateway
    ```

    After about one minute, you should see output similar to the following, with `PROGRAMMED` showing as `True`:

    ```output
    NAME                     CLASS   ADDRESS         PROGRAMMED   AGE
    applink-ingressgateway   istio   20.99.227.197   True         30s
    ```

1. Get the OIDC issuer URL from the AKS cluster and set it as an environment variable.

    ```bash
    export OIDC_ISSUER_URL=$(az aks show --resource-group $AKS_RG --name $CLUSTER_NAME_1 --query "oidcIssuerProfile.issuerUrl" -o tsv)
    echo $OIDC_ISSUER_URL
    ```

1. Apply a RequestAuthentication policy to validate JWT tokens issued by the AKS cluster OIDC issuer and forward the original token to the `reviews` service, and a VirtualService to route traffic to the `reviews` service based on the `sub` claim in the JWT token using the following `kubectl apply` command:

    ```bash
    envsubst <<EOF | kubectl --context $CLUSTER_NAME_1 apply -f -
    apiVersion: security.istio.io/v1
    kind: RequestAuthentication
    metadata:
      name: bookinfo-ingress-jwt-istio
      namespace: applink-ingress
    spec:
      selector:
        matchLabels:
          app: applink-ingressgateway
      jwtRules:
      - issuer: "${OIDC_ISSUER_URL}"
        audiences:
        - "${OIDC_ISSUER_URL}"
        jwksUri: "${OIDC_ISSUER_URL}openid/v1/jwks"
        forwardOriginalToken: true
    ---
    apiVersion: networking.istio.io/v1
    kind: Gateway
    metadata:
      name: bookinfo-gateway-istio
      namespace: applink-ingress
    spec:
      selector:
        app: applink-ingressgateway
      servers:
        - hosts:
          - "*"
          port:
            name: http
            number: 80
            protocol: HTTP
    ---
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: bookinfo-vs-istio
      namespace: applink-ingress
    spec:
        hosts:
        - "*"
        gateways:
        - bookinfo-gateway-istio
        http:
        - name: reviews
          match:
          - uri:
              prefix: /
            headers:
              "@request.auth.claims.sub":
                exact: "system:serviceaccount:default:curl"
          route:
          - destination:
              host: reviews.default.svc.cluster.local
              port:
                number: 9080
    EOF
    ```

1. Get the IP address of the new ingress gateway and set it as an environment variable.

    ```bash
    export NO_REV_GTW_IP=$(kubectl --context $CLUSTER_NAME_1 -n applink-ingress get gateway applink-ingressgateway -o jsonpath="{.status.addresses[0].value}") 
    echo $NO_REV_GTW_IP
    ```

### Verify JWT authentication and claim-based routing

1. Verify requests without JWT token are rejected by the gateway using the following `kubectl exec` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec -it $(kubectl --context $CLUSTER_NAME_1 get pod -l app=curl -o jsonpath='{.items[0].metadata.name}') -- curl -v http://$NO_REV_GTW_IP/reviews/1
    ```

    Your output should look similar to the following, indicating that the request is rejected with a 404 Not Found error because the JWT token is missing:

    ```output
    *   Trying 20.99.227.197:80...
    * Established connection to 20.99.227.197 (20.99.227.197 port 80) from 10.244.2.0 port 36736 
    * using HTTP/1.x
    > GET /reviews/1 HTTP/1.1
    > Host: 20.99.227.197
    > User-Agent: curl/8.16.0
    > Accept: */*
    > 
    * Request completely sent off
    < HTTP/1.1 404 Not Found
    < date: Fri, 13 Mar 2026 18:30:34 GMT
    < server: istio-envoy
    < content-length: 0
    < 
    * Connection #0 to host 20.99.227.197:80 left intact
    ```

1. Verify requests with invalid JWT token are rejected by the gateway using the following `kubectl exec` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec -it $(kubectl --context $CLUSTER_NAME_1 get pod -l app=curl -o jsonpath='{.items[0].metadata.name}') -- curl -v -H "Authorization: Bearer 123.456.789" http://$NO_REV_GTW_IP/reviews/1
    ```

    Your output should look similar to the following, indicating that the request is rejected with a 401 Unauthorized error because the JWT token is invalid:

    ```output
    *   Trying 20.99.227.197:80...
    * Established connection to 20.99.227.197 (20.99.227.197 port 80) from 10.244.2.0 port 33240 
    * using HTTP/1.x
    > GET /reviews/1 HTTP/1.1
    > Host: 20.99.227.197
    > User-Agent: curl/8.16.0
    > Accept: */*
    > Authorization: Bearer 123.456.789
    > 
    * Request completely sent off
    < HTTP/1.1 401 Unauthorized
    < www-authenticate: Bearer realm="http://20.99.227.197/reviews/1", error="invalid_token"
    < content-length: 29
    < content-type: text/plain
    < date: Fri, 13 Mar 2026 18:31:40 GMT
    < server: istio-envoy
    < 
    * Connection #0 to host 20.99.227.197:80 left intact
    Jwt header is an invalid JSON
    ```

1. Verify requests with valid JWT token are allowed by the gateway and routed to the `reviews` service using the following `kubectl exec` command. The JWT token is obtained from the service account token mounted in the curl pod, which is issued by the AKS cluster OIDC issuer.

    ```bash
    kubectl --context $CLUSTER_NAME_1 exec -it $(kubectl --context $CLUSTER_NAME1 get pod -l app=curl -o jsonpath='{.items[0].metadata.name}') -- sh -c "export NO_REV_GTW_IP=$NO_REV_GTW_IP; exec sh"
    ```

1. Run the following command in the interactive shell to send a request with the valid JWT token to the gateway:

    ```bash
    curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" http://$NO_REV_GTW_IP/health; echo
    ```

    Your output should look similar to the following, indicating that the request is allowed and the `reviews` service is healthy:

    ```output
    {"status": "Reviews is healthy"}
    ```

1. Run the following command in the interactive shell to send a request with the valid JWT token to the gateway to access the `reviews` service. The request should be allowed and routed to the `reviews` service because the `sub` claim in the JWT token matches the value specified in the VirtualService route match condition.

    ```bash
    curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" http://$NO_REV_GTW_IP/reviews/1; echo
    ```

    Your output should look similar to the following, indicating that the request is allowed and routed to the `reviews` service, returning the review for product 1:

    ```json
    {"id": "1","podname": "reviews-v1-12ab34c5de-fg6hi","clustername": "null","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!"},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare."}]}
    ```

## Implement cross-cluster traffic shifting

We implement cross-cluster traffic shifting using the following setup across the two AKS clusters:

- **AKS cluster 1**: The `reviews-local` services selects only `reviews-v1` pods, and the `reviews-remote` service intentionally selects no local pods.
- **AKS cluster 2**: The `reviews-local` service intentionally selects no local pods, and the `reviews-remote` service selects both `reviews-v2` and `reviews-v3` pods.

In this section, the terms _local_ and _remote_ are defined from the perspective of AKS cluster 1.

1. Apply the following Service resources in AKS cluster 1 to set up the `reviews-local` and `reviews-remote` services with the appropriate selectors using the `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-local
      namespace: default
      labels:
        app: reviews
        service: reviews-local
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: v1
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-remote
      namespace: default
      labels:
        app: reviews
        service: reviews-remote
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: remote
    EOF
    ```

1. Apply the following Service resources in AKS cluster 2 to set up the `reviews-local` and `reviews-remote` services with the appropriate selectors using the `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-local
      namespace: default
      labels:
        app: reviews
        service: reviews-local
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: local
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-remote
      namespace: default
      labels:
        app: reviews
        service: reviews-remote
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
    EOF
    ```

1. Split traffic for the `reviews` service `20/80` between the local and remote clusters using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME1 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: reviews
      namespace: default
    spec:
      hosts:
      - reviews
      http:
      - route:
        - destination:
            host: reviews-local.default.svc.cluster.local
            port:
              number: 9080
          weight: 20
        - destination:
            host: reviews-remote.default.svc.cluster.local
            port:
              number: 9080
          weight: 80
    EOF
    ```

1. Verify the settings using the following script (feel free to change the weights and test it yourself).

    The `Connection: close` header only closes the client-side HTTP/1.1 connection. In ambient multicluster, the east-west gateway and waypoint can still reuse HBONE connections, so requests sent to `cluster-2` might stay pinned to either `reviews-v2` or `reviews-v3` within a single run. Use `cluster-1` versus `cluster-2` as the authoritative verification signal for the `20/80` split, and treat the star color as an illustrative detail only.

    ```bash
    results=()
    for i in $(seq 1 20); do
      html=$(curl -sS --http1.1 -H 'Connection: close' http://$BOOKINFO_GTW_IP/productpage)
      pod=$(printf '%s' "$html" | grep -oE 'reviews-v[0-9]-[a-z0-9-]+' | head -n1)
      if printf '%s' "$pod" | grep -q '^reviews-v1-'; then
        target=cluster-1
      else
        target=cluster-2
      fi
      if printf '%s' "$html" | grep -q 'text-red-500'; then
        star=red
      elif printf '%s' "$html" | grep -q 'text-black-500'; then
        star=black
      else
        star=no-star
      fi

      line=$(printf '%02d  %-10s  %-8s  %s' "$i" "$target" "$star" "$pod")
      echo "$line"
      results+=("$target $star")
    done

    echo
    echo "Summary:"
    printf '%s\n' "${results[@]}" | sort | uniq -c
    ```

    Example output:

    ```output
    ...

    Summary:
    3 cluster-1 no-star
    17 cluster-2 black
    ```

## Implement fault injection

### Set up virtual services

> [!IMPORTANT]
> In this section, we reuse the `reviews-local` and `reviews-remote` services created in the [traffic shifting section](#implement-cross-cluster-traffic-shifting).

1. Set up virtual services for `productpage` and `details` services in AKS cluster 1 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: productpage
    spec:
      hosts:
      - productpage
      http:
      - route:
        - destination:
            host: productpage
    ---
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: details
    spec:
      hosts:
      - details
      http:
      - route:
        - destination:
            host: details
    EOF
    ```

1. Set up a virtual service for the `ratings` service in AKS cluster 2 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: ratings
    spec:
      hosts:
      - ratings
      http:
      - route:
        - destination:
            host: ratings
    EOF
    ```

1. Update `reviews-remote` in AKS cluster 2 to select `reviews-v2` only using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-remote
      namespace: default
      labels:
        app: reviews
        service: reviews-remote
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: v2
    EOF
    ```

1. Modify the virtual service for AKS cluster 1 to route user `jason`'s requests to `reviews-remote` using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: reviews
      namespace: default
    spec:
      hosts:
      - reviews
      http:
      - match:
        - headers:
            end-user:
              exact: jason
        route:
        - destination:
            host: reviews-remote.default.svc.cluster.local
            port:
              number: 9080
      - route:
        - destination:
            host: reviews-local.default.svc.cluster.local
            port:
              number: 9080
    EOF
    ```

### Inject HTTP delay

1. Inject a seven second HTTP delay for user `jason` to the `ratings` service in AKS cluster 2 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME2 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: ratings
    spec:
      hosts:
      - ratings
      http:
      - match:
        - headers:
            end-user:
              exact: jason
        fault:
          delay:
            percentage:
              value: 100.0
            fixedDelay: 7s
        route:
        - destination:
            host: ratings
      - route:
        - destination:
            host: ratings
    EOF
    ```

1. To see the impact of this delay, open a browser and navigate to `http://$BOOK_INFO_GTW_IP/productpage`. Initially, you shouldn't see any rating stars under the "Book Reviews" section since all the traffic goes to `reviews-v1`.
1. Sign in using username `jason` and any password you want.

    :::image type="content" source="./media/traffic-management-use-cases/book-info-sample-sign-in-new.png" alt-text="Screenshot of the sign in page of the Book Info sample application.":::

    You should notice the webpage becomes very slow, with each refresh taking around six seconds. The "Book Reviews" section should show an error.

    :::image type="content" source="./media/traffic-management-use-cases/book-info-sample-book-reviews.png" alt-text="Screenshot of the error message indicating book reviews are currently unavailable.":::

    The traffic pattern once logged into user `jason` is: `[(AKS cluster 1) productpage-v1] --(1)--> [(AKS cluster 2) reviews-v2] --(2)--> [(AKS cluster 2) ratings-v1]`.

    When logged in as `jason`, we add a seven second delay in the connection (2):

     - `reviews-v2` has a 10 second timeout when fetching ratings, which exceeds the delay from `ratings-v1`, so it can wait for ratings to load.
     - `productpage-v1` has a three second timeout with two retries, which equals a six second timeout.
     - `reviews-v2` is still waiting for the response from ratings, and `productpage-v1` hits the timeout and returns an error on the webpage.

### Reduce HTTP delay and timeout

In this section, we bring back the "Book Reviews" section. To reduce the webpage load time, we can change the traffic pattern for user `jason` to route to `reviews-v3`, which has a two and a half second timeout.

1. Update `reviews-remote` in AKS cluster 2 to select `reviews-v3` only using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-remote
      namespace: default
      labels:
        app: reviews
        service: reviews-remote
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: v3
    EOF
    ```

    Updated traffic pattern: `[(AKS cluster 1) productpage-v1] --(1)--> [(AKS cluster 2) reviews-v3] --(2)--> [(AKS cluster 2) ratings-v1]`

    Now the "Book Reviews" section shows up, but ratings are still missing since the `reviews-v3` waits only two and a half seconds before giving up on fetching them.

    :::image type="content" source="./media/traffic-management-use-cases/book-info-sample-book-ratings.png" alt-text="Screenshot showing the book reviews without the ratings.":::

1. Next, let's bring back the "Ratings" section. Reduce the delay for `ratings-v1` to one second using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
    name: ratings
    spec:
    hosts:
    - ratings
    http:
    - match:
        - headers:
            end-user:
            exact: jason
        fault:
        delay:
            percentage:
            value: 100.0
            fixedDelay: 1s
        route:
        - destination:
            host: ratings
            subset: v1
    - route:
        - destination:
            host: ratings
            subset: v1
    EOF
    ```

    The rating stars now show up since the ratings take one second to send back the response, which is within the `reviews-v3`'s two and a half seconds timeout which, in turn, is within the product page's six seconds timeout.

    :::image type="content" source="./media/traffic-management-use-cases/book-info-sample-book-reviews-and-ratings.png" alt-text="Screenshot showing the book reviews and ratings loaded.":::

#### Inject HTTP abort

1. Ensure `reviews-remote` in AKS cluster 2 selects `reviews-v2` again using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: reviews-remote
      namespace: default
      labels:
        app: reviews
        service: reviews-remote
        istio.io/global: "true"
        istio.io/use-waypoint: waypoint
    spec:
      ports:
      - name: http
        port: 9080
        targetPort: 9080
      selector:
        app: reviews
        version: v2
    EOF
    ```

1. Let all requests from AKS cluster 1 hit `reviews-remote` using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_1 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: reviews
    spec:
      hosts:
        - reviews
      http:
      - route:
        - destination:
            host: reviews-remote.default.svc.cluster.local
            port:
              number: 9080
    EOF
    ```

1. Inject a 503 HTTP abort for user `jason` to the `ratings` service in AKS cluster 2 using the following `kubectl apply` command:

    ```bash
    kubectl --context $CLUSTER_NAME_2 apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: VirtualService
    metadata:
      name: ratings
    spec:
      hosts:
      - ratings
      http:
      - fault:
          abort:
            httpStatus: 503
            percentage:
              value: 100
        route:
        - destination:
            host: ratings
    EOF
    ```

    Whether you log in or not, rating stars aren't able to display since all requests to `ratings` service return 503:

    :::image type="content" source="./media/traffic-management-use-cases/book-info-sample-book-ratings-503.png" alt-text="Screenshot showing the book ratings aren't displayed due to all requests to the ratings service returning 503.":::

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Azure Kubernetes Application Network observability](./observability.md)
- [Azure Kubernetes Application Network security](./security.md)
