---
title: Migration guidance from open source Istio to Istio-based service mesh add-on for Azure Kubernetes Service
description: Migration guidance for open source Istio to Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 05/20/2025
ms.author: gerobayopaz
author: german1608
ms.custom: devx-track-azurecli
---

# Migration guidance from open source Istio to Istio-based service mesh add-on for Azure Kubernetes Service

This article provides guidance for migrating your existing [open source (OSS) Istio][istio-io] installation to the Istio-based service mesh add-on for Azure Kubernetes Service (AKS). Adopting the AKS Istio add-on can simplify operations, provide Azure integration, and streamline Istio upgrades and management.

We recommend a "canary cluster migration" strategy. This approach involves setting up a new AKS cluster with the Istio add-on enabled, progressively migrating your workloads and configurations, and then switching traffic before removing your old cluster. This method minimizes risk by allowing thorough testing in an isolated environment.

> [!IMPORTANT]
> This article provides general guidance. It does not aim to exhaustively cover all migration scenarios.


## Prerequisites

Before you begin, check [Istio add-on limitations][istio-about-limitations] and the [mesh configuration allowlist][meshconfig-allowlist] to determine if your setup uses any features that are unsupported or blocked by the Istio add-on. In order to migrate, you need to disable such features in your target cluster's configuration. After that, ensure you meet the following requirements:

* Azure CLI version 2.57.0 or later installed. You can run `az --version` to verify version. To install or upgrade, see [Install Azure CLI][azure-cli-install].
* An existing AKS cluster running open source Istio, which will be your "source cluster." The version of Istio in your source cluster must be a supported Istio revision in AKS. Read [these steps][istio-deploy-revision-selection] to see if your version is supported.
* Your workload deployment manifests (YAML files for Deployments, Services, etc.). This guide uses the [bookinfo application][istio-bookinfo-app] as an example.
* Your existing Istio custom resource configurations (YAML files for `VirtualServices`, `DestinationRules`, `Gateways`, `AuthorizationPolicies`, etc.). This guide uses the [bookinfo sample destination rules][istio-bookinfo-service-versions].
* Familiarity with Istio concepts and your application architecture.

## Migration steps

The canary cluster migration involves these key phases:

1.  **Provision a new AKS cluster**: Create a new AKS cluster with the Istio service mesh add-on enabled. This is your "target cluster."
1.  **Migrate workloads and configurations**: Adapt and apply your existing Istio configurations, such as `VirtualServices`, `Gateways`, and workloads to the new cluster.
1.  **Test thoroughly**: Validate that your applications function correctly in the new Istio mesh.
1.  **Shift traffic**: Update load balancer configurations to direct traffic to your applications running on the new cluster.
1.  **Remove old cluster**: Once the new cluster is stable and handling production traffic, remove the old cluster.

## Set environment variables

```bash
export SOURCE_CLUSTER=<source-cluster-name>
export TARGET_CLUSTER=<target-cluster-name>
export TARGET_RESOURCE_GROUP=<resource-group-name>
export LOCATION=<location>
```

## Set up source cluster

For illustrative purposes, let's set up the source cluster with a sample workload that we want to migrate. If you already have a cluster with workloads to migrate, skip this step.

```bash
# Install Istio
istioctl install -y --context $SOURCE_CLUSTER

# Enable sidecar injection for the default namespace
kubectl label --context $SOURCE_CLUSTER namespace default istio-injection=enabled

# Install the bookinfo application
kubectl apply --context $SOURCE_CLUSTER -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/bookinfo/platform/kube/bookinfo.yaml

# Create some sample Destination Rules
kubectl apply --context $SOURCE_CLUSTER -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/bookinfo/networking/destination-rule-all.yaml

# Enable the external ingress gateway
kubectl apply --context $SOURCE_CLUSTER -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/bookinfo/networking/bookinfo-gateway.yaml
```

Set environment variables for external ingress host and ports:

```bash
export INGRESS_NS=<ingress-namespace>
export INGRESS_SVC=<ingress-service-name>
export SOURCE_INGRESS_HOST_EXTERNAL=$(kubectl --context $SOURCE_CLUSTER -n $INGRESS_NS get service $INGRESS_SVC -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export SOURCE_INGRESS_PORT_EXTERNAL=$(kubectl --context $SOURCE_CLUSTER -n $INGRESS_NS get service $INGRESS_SVC -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SOURCE_GATEWAY_URL_EXTERNAL=$SOURCE_INGRESS_HOST_EXTERNAL:$SOURCE_INGRESS_PORT_EXTERNAL
```

Retrieve the external address of the sample application installed in the source cluster:

```bash
echo $SOURCE_GATEWAY_URL_EXTERNAL
```

Navigate to the URL from the output of the previous command and confirm that the sample application's product page is displayed. Alternatively, you can also use `curl` to confirm the sample application is accessible. For example:

```bash
curl -s "http://${SOURCE_GATEWAY_URL_EXTERNAL}/productpage" | grep -o "<title>.*</title>"
```

## Create the target cluster

Follow [these steps][istio-deploy-aks-create] to create a new AKS cluster with the Istio add-on enabled. This cluster can be created in the same or a different resource group as the source cluster. During installation, you must select the same Istio revision that is installed on your source cluster. Read [these steps][istio-deploy-revision-selection] for revision selection. If you use any of the following Istio features in your source cluster, follow the corresponding guide to configure the features on your target cluster:

1. [Mesh configuration][istio-meshconfig]
1. [Deploy][istio-deployingress] and [secure][istio-secureingress] ingress gateways
    * For migration of secured ingress gateway, in addition to the above guide, you will also need to add the following server definition to your gateway:
      ```yaml
      - hosts:
        - productpage.bookinfo.com
        port:
        name: http
        number: 80
        protocol: HTTP
      ```
      Verify making an HTTP request to the target cluster's ingress gateway:
      ```bash
      curl "http://TARGET_GATEWAY_URL_EXTERNAL/productpage" | grep "<title>.*</title>"
      ```
      This configuration also enables unsecured HTTP incoming traffic to the istio ingress gateway of your ingress gateway, which is needed when migrating traffic using traffic shifting. Once migration is complete, this extra server should be removed.
1. [Deploy egress gateways (preview)][istio-deployegress]
1. [Plug-in CA certificates][istio-plugin-ca]
    * If you are setting up your own CA certificates, you need to set up this at the same time you're enabling the add-on in the cluster. Read the guide for more information.

## Migrate your workload and configuration

Use `az aks get-credentials` to get the credentials for your new cluster:

```azurecli-interactive
az aks get-credentials -g $TARGET_RESOURCE_GROUP -n $TARGET_CLUSTER
```

Install your workload and Istio custom resource configurations in the target cluster:

```bash
export ASM_REVISION=asm-X-Y

# Enable sidecar injection for the default namespace. istio-injection labelling
# does not work in the Istio add-on
kubectl label --context $TARGET_CLUSTER namespace default istio.io/rev=$ASM_REVISION

# Install the bookinfo application
kubectl apply --context $TARGET_CLUSTER -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/bookinfo/platform/kube/bookinfo.yaml

# Install some demo Destination Rules
kubectl apply --context $TARGET_CLUSTER -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/bookinfo/networking/destination-rule-all.yaml
```

Verify that sidecar injection succeeded by ensuring all containers are ready in your application pod(s) and checking for the `istio-proxy` container in the `kubectl describe` output of the pod(s), for example:

```bash
kubectl describe pod --context $TARGET_CLUSTER -n default <pod-name>
```

> [!NOTE]
> How you install your workload and configuration depends on your infrastructure setup. You can use tools like [Velero][velero-io] to make backups from your workload from your source cluster and apply it in the target cluster, or you can use GitOps tools such as [Flux][fluxcd-io] or [Argo CD][argocd-io].

## Test the Istio add-on

Follow [these steps][istio-external-ingress-deploy] to enable an external Istio ingress gateway in your target cluster

Set environment variables for the target cluster ingress host and ports

```bash
export TARGET_INGRESS_HOST_EXTERNAL=$(kubectl --context $TARGET_CLUSTER -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export TARGET_INGRESS_PORT_EXTERNAL=$(kubectl --context $TARGET_CLUSTER -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export TARGET_GATEWAY_URL_EXTERNAL=$TARGET_INGRESS_HOST_EXTERNAL:$TARGET_INGRESS_PORT_EXTERNAL
```

Retrieve the external address of the sample application installed in the target cluster:

```bash
echo $TARGET_GATEWAY_URL_EXTERNAL
```

Navigate to the URL from the output of the previous command and confirm that the sample application's product page is displayed. Alternatively, you can also use `curl` to confirm the sample application is accessible. For example:

```bash
curl -s "http://${TARGET_GATEWAY_URL_EXTERNAL}/productpage" | grep -o "<title>.*</title>"
```

## Migrate traffic to target cluster

Add a ServiceEntry in the source cluster to set a domain in Istio's internal service registry to point to the target cluster:

```bash
kubectl apply --context $SOURCE_CLUSTER -f - <<EOF
# This ServiceEntry instructs the mesh to direct HTTP requests from
# the mesh that target v2.example.com to the specified IP address.
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: target-cluster-http
spec:
  hosts:
  - v2.example.com
  location: MESH_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: STATIC
  endpoints:
  - address: $TARGET_INGRESS_HOST_EXTERNAL
EOF
```

When installing the Istio ingress gateway, we created an Istio gateway to access it. Update its VirtualService to split traffic between the source cluster and the target cluster. We recommend starting with a small percentage of requests being redirected to the target cluster:

```bash
kubectl apply --context $SOURCE_CLUSTER -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
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
        port:
          number: 9080
        host: productpage # The name of the Service inside the cluster you're migrating away from.
      weight: 90
    - destination:
        port:
          number: 80
        host: v2.example.com # The temporary domain name of the frontend inside the cluster with managed ASM.
      weight: 10
EOF
```

Verify that the 90% of the requests include pod names from the source cluster, and 10% of the others include pod names from the target cluster:

```bash
for i in {1..100}; do curl -s http://$SOURCE_INGRESS_HOST_EXTERNAL/productpage | awk '/Reviews served by/ {getline; print}' | uniq; done | sort | uniq -c | while read count pod; do ctx="unknown"; for c in $SOURCE_CLUSTER $TARGET_CLUSTER; do if kubectl --context=$c get pod $pod &>/dev/null; then ctx=$c; fi; done; echo "$ctx $count $pod"; done | sort | column -t
```

You should see an output like this:

```
$SOURCE_CLUSTER    14  reviews-v1-849f9bc5d6-vcd56
$SOURCE_CLUSTER    18  reviews-v3-6d5d98f5c4-ljcwj
$SOURCE_CLUSTER    20  reviews-v2-5c757d5846-s9fx9
$TARGET_CLUSTER    13  reviews-v3-6d5d98f5c4-pfv75
$TARGET_CLUSTER    14  reviews-v2-5c757d5846-p58wm
$TARGET_CLUSTER    21  reviews-v1-849f9bc5d6-mbs74
```

You can gradually increase the percentage of requests being redirected to the target cluster until the source cluster is no longer serving any requests.

## Remove the source cluster

Once you feel comfortable with your testing and have shifted all requests to the target cluster, you can remove your source cluster. If you have DNS settings, ensure you update your domain to use the target cluster's IP address.

## Summary

We hope this walk-through provided the guidance on how to migrate your user-managed Istio installation to the Istio-based service mesh add-on for Azure Kubernetes Service. Although the specific steps might depend on your installation, we recommend following this general strategy to perform migration.

<!-- LINKS - External -->
[istio-io]: https://istio.io/
[istio-bookinfo-app]: https://istio.io/latest/docs/examples/bookinfo/#start-the-application-services
[istio-bookinfo-service-versions]: https://istio.io/latest/docs/examples/bookinfo/#define-the-service-versions
[velero-io]: https://velero.io
[fluxcd-io]: https://fluxcd.io/
[argocd-io]: https://argo-cd.readthedocs.io/en/stable/

<!-- LINKS - Internal -->
[istio-scale-hpa]: ./istio-scale.md#horizontal-pod-autoscaling-customization
[azure-cli-install]: /cli/azure/install-azure-cli
[istio-about-limitations]: ./istio-about.md#limitations
[istio-meshconfig]: ./istio-meshconfig.md
[istio-deployingress]: ./istio-deploy-ingress.md
[istio-secureingress]: ./istio-secure-gateway.md
[istio-deployegress]: ./istio-deploy-egress.md
[istio-plugin-ca]: ./istio-plugin-ca.md
[istio-deploy-aks-create]: ./istio-deploy-addon.md#install-mesh-during-cluster-creation
[istio-external-ingress-deploy]: ./istio-deploy-ingress.md#enable-external-ingress-gateway
[istio-deploy-revision-selection]: ./istio-deploy-addon.md#revision-selection
[meshconfig-allowlist]: ./istio-meshconfig.md#allowed-supported-and-blocked-meshconfig-values
