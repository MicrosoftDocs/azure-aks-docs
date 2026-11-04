---
title: Use the managed default domain with the application routing add-on for Azure Kubernetes Service (AKS)
description: Learn how to give an AKS cluster a free managed domain and TLS certificate by using the default domain feature of the application routing add-on.
ms.subservice: aks-networking
ms.author: kingoliver
author: kingoliver
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli, references_regions
ms.topic: how-to
ms.date: 11/04/2026
# Customer intent: As a Kubernetes administrator, I want to expose a workload on a free managed domain with a trusted TLS certificate, so that I can serve HTTPS traffic without buying a domain or managing certificates.
---

# Use the managed default domain with the application routing add-on for Azure Kubernetes Service (AKS)

The default domain feature of the [application routing add-on](./app-routing.md) gives your cluster a free, fully managed domain and a trusted TLS certificate. When you enable the feature, Azure Kubernetes Service (AKS) assigns your cluster a unique domain in the form `<id>.<region>.aksapp.io`. AKS then issues a publicly trusted wildcard TLS certificate for `*.<id>.<region>.aksapp.io` and publishes the Domain Name System (DNS) records automatically.

Use this feature to serve HTTPS traffic for a workload without buying a domain, creating an Azure DNS zone, or managing a certificate. AKS manages the domain, the certificate, and the DNS records for you. The certificate is renewed automatically before it expires.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Limitations

- The default domain feature is validated and supported with the [application routing Kubernetes Gateway API implementation](./app-routing-gateway-api.md). Other Gateway API implementations might interoperate with the feature if they use the [Managed Gateway API installation][managed-gateway-api], honor listener TLS `certificateRefs`, populate `Gateway.status.addresses`, and populate route `status.parents` (these fields are part of the standard [Kubernetes Gateway API specification](https://gateway-api.sigs.k8s.io/reference/api-spec/)). Microsoft doesn't test or support these configurations.

## How the feature works

The default domain feature builds on the application routing add-on. When you enable it, AKS does the following:

- Assigns a read-only domain name to the cluster, in the form `<id>.<region>.aksapp.io`. The name doesn't change even if you disable and reenable the feature.
- Issues a publicly trusted wildcard TLS certificate for `*.<id>.<region>.aksapp.io` and reconciles it into a Kubernetes Secret that you name.
- Runs a managed `external-dns` instance that publishes address (A) records for the hostnames you expose.

You bring the workload and a small amount of configuration. AKS brings the domain, the certificate, and the DNS.

## Supported regions

The default domain feature is currently available in the following regions:

- **Americas:** Brazil South, Brazil Southeast, Canada Central, Canada East, Central US, Chile Central, East US, East US 2, East US 3, Mexico Central, North Central US, South Central US, South Central US 2, Southeast US, Southeast US 3, Southeast US 5, Southwest US, West Central US, West US, West US 2, and West US 3.
- **Europe:** Austria East, Belgium Central, Denmark East, France Central, France South, Germany North, Germany West Central, Italy North, North Europe, Norway East, Norway West, Poland Central, Spain Central, Sweden Central, Sweden South, Switzerland North, Switzerland West, UK South, UK West, and West Europe.
- **Asia Pacific:** Australia Central, Australia Central 2, Australia East, Australia Southeast, Central India, East Asia, India South Central, Indonesia Central, Japan East, Japan West, Jio India Central, Jio India West, Korea Central, Korea South, Malaysia South, Malaysia West, New Zealand North, South India, Southeast Asia, Taiwan North, and Taiwan Northwest.
- **Middle East and Africa:** Israel Central, Israel Northwest, Qatar Central, South Africa North, South Africa West, UAE Central, and UAE North.

## Prerequisites

- The Azure CLI version `2.86.0` or later. Run `az version` to check your Azure CLI and installed extension versions, and run `az upgrade` to update. If you don't have the Azure CLI, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- The `aks-preview` Azure CLI extension, version `19.0.0b26` or later. Version `19.0.0b23` adds the `--enable-default-domain` and `--disable-default-domain` parameters, and version `19.0.0b26` adds the `--enable-app-routing-istio` parameter. Install or update it with the following command:

  ```azurecli-interactive
  az extension add --name aks-preview
  az extension update --name aks-preview
  ```

- An AKS cluster that uses a managed identity or has [Microsoft Entra Workload ID](/azure/aks/workload-identity-overview) enabled. The default domain feature requires one of these. The default domain feature is part of the application routing add-on, which you enable in a later section.
- The [application routing Kubernetes Gateway API implementation][app-routing-gateway-api]. This article exposes the sample application through the Gateway API. Enable it with the `--enable-app-routing-istio` flag, as shown in a later section. It also requires the [Managed Gateway API installation][managed-gateway-api], which installs the Gateway API custom resource definitions (CRDs). Enable the Managed Gateway API installation with the `--enable-gateway-api` flag, as shown in a later section.

## Register the default domain feature flag

The default domain feature is in preview and is gated by the `DefaultDomainPreview` feature flag. You must register the flag on your subscription before you enable the feature. If you try to enable the feature on an unregistered subscription, the request fails.

1. Register the `DefaultDomainPreview` feature flag by using the [`az feature register`][az-feature-register] command. The registration takes a few minutes to complete.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "DefaultDomainPreview"
    ```

1. Verify the registration state by using the [`az feature show`][az-feature-show] command. Wait until the state changes from `Registering` to `Registered` before you continue.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "DefaultDomainPreview"
    ```

1. Refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

## Enable the default domain feature

The steps in this article use four cluster settings. Each setting has its own flag:

- `--enable-app-routing` turns on the application routing add-on. The default domain feature runs in this add-on. The add-on installs the `DefaultDomainCertificate` CRD, puts the certificate in a Kubernetes Secret, and runs the managed `external-dns` instance. If the add-on is off, AKS rejects the request to enable the default domain feature.
- `--enable-app-routing-istio` turns on the application routing Gateway API implementation, which provides the `approuting-istio` GatewayClass.
- `--enable-gateway-api` turns on the Managed Gateway API installation, which installs the Gateway API CRDs.
- `--enable-default-domain` turns on the default domain feature.

### Enable during cluster creation

Run the following command to create a cluster with the application routing add-on and the default domain feature:

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export LOCATION=<location>

# Create the cluster with the application routing add-on and the default domain feature
az aks create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER_NAME} \
    --location ${LOCATION} \
    --enable-managed-identity \
    --enable-app-routing \
    --app-routing-default-nginx-controller None \
    --enable-app-routing-istio \
    --enable-gateway-api \
    --enable-default-domain \
    --generate-ssh-keys
```

### Enable on an existing cluster

The command that enables the default domain feature depends on whether the application routing add-on is on. A cluster can have the application routing Gateway API implementation without the add-on. For example, a cluster where you used only the `--enable-app-routing-istio` flag doesn't have the add-on. A new AKS Automatic cluster that runs Kubernetes 1.36 or later also doesn't have the add-on.

1. Check whether the application routing add-on is on:

    ```azurecli-interactive
    az aks show \
        --resource-group ${RESOURCE_GROUP} \
        --name ${CLUSTER_NAME} \
        --query ingressProfile.webAppRouting.enabled
    ```

1. If the command returns `true`, enable the default domain feature:

    ```azurecli-interactive
    az aks approuting update \
        --resource-group ${RESOURCE_GROUP} \
        --name ${CLUSTER_NAME} \
        --enable-default-domain
    ```

1. If the command returns `false` or no value, turn on the add-on and the default domain feature together:

    ```azurecli-interactive
    az aks approuting enable \
        --resource-group ${RESOURCE_GROUP} \
        --name ${CLUSTER_NAME} \
        --enable-default-domain \
        --nginx None
    ```

1. Enable the Gateway API implementation and the Managed Gateway API installation if they aren't already on:

    ```azurecli-interactive
    az aks update \
        --resource-group ${RESOURCE_GROUP} \
        --name ${CLUSTER_NAME} \
        --enable-app-routing-istio \
        --enable-gateway-api
    ```

## Get the assigned domain name

AKS assigns a unique domain to the cluster. Run the following command to read it:

```azurecli-interactive
az aks approuting defaultdomain show \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER_NAME} \
    --query domainName \
    --output tsv
```

The command returns the domain name in the form `<id>.<region>.aksapp.io`, for example `6a27935b0c1d2e0001a3b4c5.westus2.aksapp.io`. The `<id>` value has 24 hexadecimal characters. You expose your workloads on subdomains of this domain.

> [!TIP]
> If you prefer a Kubernetes-native workflow, you can also read the domain from the `status.domain` field of the `DefaultDomainCertificate` resource after you create it. This field shows the name in the certificate, so it starts with `*.`. This method lets you get the domain by using only the Kubernetes API, without the Azure CLI. See [Request the managed certificate](#request-the-managed-certificate).

## Connect to your cluster

Configure `kubectl` to connect to your cluster with the [`az aks get-credentials`][az-aks-get-credentials] command:

```azurecli-interactive
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}
```

## Request the managed certificate

To get the managed TLS certificate, create a `DefaultDomainCertificate` resource. This resource tells AKS which Kubernetes Secret to store the certificate in. AKS reconciles the certificate into that Secret in the **same namespace** as the `DefaultDomainCertificate` resource. This example uses a dedicated `hello-world` namespace so that the certificate, the `Gateway`, and the workload all live together. A `Gateway` can reference a certificate Secret in a different namespace only if a `ReferenceGrant` in that namespace allows it. This example keeps all the resources in one namespace, so it doesn't need a `ReferenceGrant`.

1. Create the namespace:

    ```bash
    kubectl create namespace hello-world
    ```

1. Create a file named `default-domain-certificate.yaml` that has the following content. The `metadata.namespace` field places the resource, and therefore the resulting Secret, in the `hello-world` namespace:

    ```yaml
    apiVersion: approuting.kubernetes.azure.com/v1alpha1
    kind: DefaultDomainCertificate
    metadata:
      name: cert
      namespace: hello-world
    spec:
      target:
        secret: cert
    ```

1. Apply the resource with the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f default-domain-certificate.yaml
    ```

1. Confirm that the certificate is ready. AKS issues the certificate after you create the resource, which usually takes a few minutes. Run the following command to show the reason of the `Available` condition:

    ```bash
    kubectl get defaultdomaincertificate cert -n hello-world -o jsonpath='{.status.conditions[?(@.type=="Available")].reason}'
    ```

    Until the certificate is ready, the command returns `CertificateNotReady`. When the certificate is ready, the command returns `CertificateSecretApplied`, the `Available` condition is `True`, and the Secret named `cert` in the `hello-world` namespace holds the certificate. To wait for the certificate instead of checking manually, run the following command:

    ```bash
    kubectl wait --for=condition=Available defaultdomaincertificate/cert -n hello-world --timeout=5m
    ```

    Confirm the Secret exists:

    ```bash
    kubectl get secret cert -n hello-world
    ```

1. Read the assigned domain from the resource status. The `DefaultDomainCertificate` resource reports the domain in its `status.domain` field, so you can get it without the Azure CLI:

    ```bash
    kubectl get defaultdomaincertificate cert -n hello-world -o jsonpath='{.status.domain}'
    ```

    The command returns the certificate name for the domain, for example `*.6a27935b0c1d2e0001a3b4c5.westus2.aksapp.io`.

## Deploy a sample application

The following steps deploy a sample application into the `hello-world` namespace and expose it on the default domain.

1. Create a file named `hello-world.yaml` that has the following content:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hello-world
      namespace: hello-world
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: hello-world
      template:
        metadata:
          labels:
            app: hello-world
        spec:
          containers:
          - name: hello-world
            image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: hello-world
      namespace: hello-world
    spec:
      selector:
        app: hello-world
      ports:
      - port: 80
        targetPort: 80
    ```

1. Apply the manifest:

    ```bash
    kubectl apply -f hello-world.yaml
    ```

## Expose the application on the default domain

Create a `Gateway` and an `HTTPRoute` that use the `approuting-istio` GatewayClass and the managed certificate. The managed certificate is a wildcard certificate for `*.<id>.<region>.aksapp.io`. A wildcard name covers exactly one label, so use a hostname such as `hello.<id>.<region>.aksapp.io`.

You can also route different paths on the same hostname to different services with `HTTPRoute` rules. The `Gateway`, `HTTPRoute`, and workload run in the `hello-world` namespace, alongside the certificate Secret.

1. Set a hostname under your assigned domain. Replace `<id>` and `<region>` with the values from your assigned domain:

    ```bash
    export HOST=hello.<id>.<region>.aksapp.io
    ```

1. Create the `Gateway`. The listener terminates TLS by using the managed certificate in the `cert` Secret in the same namespace:

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: hello-world
      namespace: hello-world
    spec:
      gatewayClassName: approuting-istio
      listeners:
      - name: https
        hostname: "${HOST}"
        port: 443
        protocol: HTTPS
        tls:
          mode: Terminate
          certificateRefs:
          - name: cert
        allowedRoutes:
          namespaces:
            from: Same
    EOF
    ```

1. Create the `HTTPRoute` that routes traffic to the sample service:

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: hello-world
      namespace: hello-world
    spec:
      parentRefs:
      - name: hello-world
      hostnames:
      - "${HOST}"
      rules:
      - matches:
        - path:
            type: PathPrefix
            value: /
        backendRefs:
        - name: hello-world
          port: 80
    EOF
    ```

After you create the `Gateway` and the `HTTPRoute`, the managed `external-dns` instance publishes an A record for the `HTTPRoute` hostname to the managed DNS zone. The record points to the `Gateway` address. The `Gateway` terminates TLS by using the managed certificate.

## Verify the application

DNS propagation takes a short time after you create the `Gateway`. Wait a minute, then verify that the domain resolves and serves the trusted certificate.

1. Wait for the `Gateway` to be programmed, then get its public address:

    ```bash
    kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io hello-world -n hello-world
    export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io hello-world -n hello-world -o jsonpath='{.status.addresses[0].value}')
    ```

1. Confirm that the hostname resolves to the gateway address:

    ```bash
    nslookup ${HOST}
    ```

    The command returns the public IP address of the gateway, which is the same address as `INGRESS_HOST`. If it returns no answer, wait a minute for DNS to propagate, then try again.

1. Send an HTTPS request and check the certificate:

    ```bash
    curl -sS -o /dev/null -w "HTTP %{http_code} verify=%{ssl_verify_result}\n" "https://${HOST}/"
    ```

    A result of `HTTP 200 verify=0` means the request succeeded and the certificate validated against a trusted certificate authority. You don't need the `curl -k` flag, because the certificate is publicly trusted.

You can also open `https://<HOST>` in a browser and confirm that the browser shows a valid, trusted certificate.

## Disable the default domain feature

Run the following command to disable the feature:

```azurecli-interactive
az aks approuting update \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER_NAME} \
    --disable-default-domain
```

The assigned domain name is retained. If you reenable the feature later, the cluster keeps the same domain.

## Troubleshoot

If the certificate isn't ready, check the conditions and events of the `DefaultDomainCertificate` resource:

```bash
kubectl describe defaultdomaincertificate cert -n hello-world
```

If the hostname doesn't resolve, check the logs of the managed `external-dns` instance in the `app-routing-system` namespace:

```bash
kubectl logs -n app-routing-system deployment/default-domain-dns-external-dns
```

For detailed troubleshooting steps, see [Troubleshoot the application routing default domain feature in AKS](/troubleshoot/azure/azure-kubernetes/extensions/application-routing-default-domain).

## Next steps

- Learn more about the [application routing add-on](./app-routing.md).
- Configure ingress with the [Kubernetes Gateway API implementation](./app-routing-gateway-api.md).
- Use a [custom domain name and certificate](./app-routing-dns-ssl.md) instead of the managed default domain.

<!-- LINKS - internal -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[app-routing-gateway-api]: ./app-routing-gateway-api.md
[managed-gateway-api]: ./managed-gateway-api.md
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
