---
title: Azure Kubernetes Service (AKS) managed NGINX ingress with the application routing add-on
description: Use the application routing add-on to securely access applications deployed on Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.custom: devx-track-azurecli
author: asudbring
ms.topic: how-to
ms.date: 11/21/2023
ms.author: allensu
---

# Managed NGINX ingress with the application routing add-on

One way to route Hypertext Transfer Protocol (HTTP) and secure (HTTPS) traffic to applications running on an Azure Kubernetes Service (AKS) cluster is to use the [Kubernetes Ingress object][kubernetes-ingress-object-overview]. When you create an Ingress object that uses the application routing add-on NGINX Ingress classes, the add-on creates, configures, and manages one or more Ingress controllers in your AKS cluster.

This article shows you how to deploy and configure a basic Ingress controller in your AKS cluster.

## Application routing add-on with NGINX features

The application routing add-on with NGINX delivers the following:

* Easy configuration of managed NGINX Ingress controllers based on [Kubernetes NGINX Ingress controller][kubernetes-nginx-ingress].
* Integration with [Azure DNS][azure-dns-overview] for public and private zone management
* SSL termination with certificates stored in Azure Key Vault.

For other configurations, see:

* [DNS and SSL configuration][dns-ssl-configuration]
* [Application routing add-on configuration][custom-ingress-configurations]
* [Configure internal NGIX ingress controller for Azure private DNS zone][create-nginx-private-controller].

With the retirement of [Open Service Mesh][open-service-mesh-docs] (OSM) by the Cloud Native Computing Foundation (CNCF), using the application routing add-on with OSM is not recommended.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- Azure CLI version 2.54.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Limitations

- The application routing add-on supports up to five Azure DNS zones.
- The application routing add-on can only be enabled on AKS clusters with [managed identity][managed-identity].
- All global Azure DNS zones integrated with the add-on have to be in the same resource group.
- All private Azure DNS zones integrated with the add-on have to be in the same resource group.
- Editing the ingress-nginx `ConfigMap` in the `app-routing-system` namespace isn't supported.
- The following snippet annotations are blocked and will prevent an Ingress from being configured: `load_module`, `lua_package`, `_by_lua`, `location`, `root`, `proxy_pass`, `serviceaccount`, `{`, `}`, `'`.


## Enable application routing using Azure CLI

### Enable on a new cluster

To enable application routing on a new cluster, use the [`az aks create`][az-aks-create] command, specifying the `--enable-app-routing` flag.

```azurecli-interactive
az aks create \
    --resource-group <ResourceGroupName> \
    --name <ClusterName> \
    --location <Location> \
    --enable-app-routing \
    --generate-ssh-keys
```

### Enable on an existing cluster

To enable application routing on an existing cluster, use the [`az aks approuting enable`][az-aks-approuting-enable] command.

```azurecli-interactive
az aks approuting enable --resource-group <ResourceGroupName> --name <ClusterName>
```

---

## Connect to your AKS cluster

To connect to the Kubernetes cluster from your local computer, you use [kubectl][kubectl], the Kubernetes command-line client. You can install it locally using the [`az aks install-cli`][az-aks-install-cli] command. If you use the Azure Cloud Shell, `kubectl` is already installed.

Configure `kubectl` to connect to your Kubernetes cluster using the [az aks get-credentials][az-aks-get-credentials] command.

```azurecli-interactive
az aks get-credentials --resource-group <ResourceGroupName> --name <ClusterName>
```

## Deploy an application

The application routing add-on uses annotations on Kubernetes Ingress objects to create the appropriate resources.

1. Create the application namespace called `aks-store` to run the example pods using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace aks-store
    ```

2. Deploy the AKS store application using the following YAML manifest file:

    ```yaml
    kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-deployments-and-services.yaml -n aks-store
    ```

  This manifest will create the necessary deployments and services for the AKS store application.

### Create the Ingress object

The application routing add-on creates an Ingress class on the cluster named *webapprouting.kubernetes.azure.com*. When you create an Ingress object with this class, it activates the add-on.

1. Copy the following YAML manifest into a new file named **ingress.yaml** and save the file to your local computer.

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: store-front
      namespace: aks-store
    spec:
      ingressClassName: webapprouting.kubernetes.azure.com
      rules:
      - http:
          paths:
          - backend:
              service:
                name: store-front
                port:
                  number: 80
            path: /
            pathType: Prefix
    ```

2. Create the ingress resource using the [`kubectl apply`][kubectl-apply] command.


    ```bash
    kubectl apply -f ingress.yaml -n aks-store
    ```

    The following example output shows the created resource:

    ```output
    ingress.networking.k8s.io/store-front created
    ```

## Verify the managed Ingress was created

You can verify the managed Ingress was created using the `kubectl get ingress` command.

```bash
kubectl get ingress -n aks-store
```

The following example output shows the created managed Ingress:

```output
NAME          CLASS                                HOSTS   ADDRESS       PORTS   AGE
store-front   webapprouting.kubernetes.azure.com   *       51.8.10.109   80      110s
```

You can verify that the AKS store works pointing your browser to the public IP address of the Ingress controller.
Find the IP address with kubectl:

```bash
kubectl get service -n app-routing-system nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
```

## Remove the application routing add-on

To remove the associated namespace, use the `kubectl delete namespace` command.

```bash
kubectl delete namespace aks-store
```

To remove the application routing add-on from your cluster, use the [`az aks approuting disable`][az-aks-approuting-disable] command.

```azurecli-interactive
az aks approuting disable --name <ClusterName> --resource-group <ResourceGroupName>
```

When the application routing add-on is disabled, some Kubernetes resources might remain in the cluster. These resources include *configMaps* and *secrets* and are created in the *app-routing-system* namespace. You can remove these resources if you want.

## Next steps

* [Configure custom ingress configurations][custom-ingress-configurations] shows how to create an advanced Ingress configuration and [configure a custom domain using Azure DNS to manage DNS zones and setup a secure ingress][dns-ssl-configuration].

* To integrate with an Azure internal load balancer and configure a private Azure DNS zone to enable DNS resolution for the private endpoints to resolve specific domains, see [Configure internal NGINX ingress controller for Azure private DNS zone][create-nginx-private-controller].

* Learn about monitoring the ingress-nginx controller metrics included with the application routing add-on with [with Prometheus in Grafana][prometheus-in-grafana] (preview) as part of analyzing the performance and usage of your application.

<!-- LINKS - internal -->
[azure-dns-overview]: /azure/dns/dns-overview.md
[az-aks-approuting-enable]: /cli/azure/aks/approuting#az-aks-approuting-enable
[az-aks-approuting-disable]: /cli/azure/aks/approuting#az-aks-approuting-disable
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[install-azure-cli]: /cli/azure/install-azure-cli
[dns-ssl-configuration]: app-routing-dns-ssl.md
[custom-ingress-configurations]: app-routing-nginx-configuration.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[prometheus-in-grafana]: app-routing-nginx-prometheus.md
[create-nginx-private-controller]: create-nginx-ingress-private-controller.md
[managed-identity]: use-managed-identity.md

<!-- LINKS - external -->
[kubernetes-ingress-object-overview]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[osm-release]: https://github.com/openservicemesh/osm
[open-service-mesh-docs]: https://release-v1-2.docs.openservicemesh.io/
[kubernetes-nginx-ingress]: https://kubernetes.github.io/ingress-nginx/
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[ingress-backend]: https://release-v1-2.docs.openservicemesh.io/docs/guides/traffic_management/ingress/#ingressbackend-api
