---
title: Configure multiple ingress controllers and NGINX ingress annotations with the application routing add-on for Azure Kubernetes Service (AKS)
description: Understand the advanced configuration options that are supported with the application routing add-on with the NGINX ingress controller for Azure Kubernetes Service (AKS). 
ms.subservice: aks-networking
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 11/21/2023
ms.author: schaffererin
ms.service: azure-kubernetes-service
author: schaffererin
zone_pivot_groups: app-routing-nginx-configuration
# Customer intent: As a Kubernetes administrator, I want to configure multiple NGINX ingress controllers with the application routing add-on, so that I can manage traffic to my applications using different load balancer settings and optimize my ingress resources.
---

# Advanced NGINX ingress controller and ingress configurations with the application routing add-on for Azure Kubernetes Service (AKS)

This article walks you through two ways to configure ingress controllers and ingress objects with the application routing add-on for Azure Kubernetes Service (AKS):

- [Configuration of the NGINX ingress controller](#control-the-default-nginx-ingress-controller-configuration) such as creating multiple controllers, configuring private load balancers, and setting static IP addresses.
- [Configuration per ingress resource](#configuration-per-ingress-resource-through-annotations) through annotations.

## Prerequisites

- An AKS cluster with the [application routing add-on][app-routing-add-on-basic-configuration] enabled.
- `kubectl` configured to connect to your AKS cluster. For more information, see [Connect to your AKS cluster](#connect-to-your-aks-cluster).

### Connect to your AKS cluster

To connect to the Kubernetes cluster from your local computer, you use `kubectl`, the Kubernetes command-line client. You can install it locally using the [`az aks install-cli`][az-aks-install-cli] command. If you use the Azure Cloud Shell, `kubectl` is already installed.

- Configure kubectl to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

:::zone pivot="nginx-ingress-controller"

## Configuration properties for NGINX ingress controllers

The application routing add-on uses a Kubernetes [custom resource definition (CRD)](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) called [`NginxIngressController`](https://github.com/Azure/aks-app-routing-operator/blob/main/config/crd/bases/approuting.kubernetes.azure.com_nginxingresscontrollers.yaml) to configure NGINX ingress controllers. You can create more ingress controllers or modify existing configurations.

The following table lists properties you can set to configure an `NginxIngressController`:

| Field                                  | Type    | Description                                                                                                                                | Required | Default                               |
|----------------------------------------|---------|--------------------------------------------------------------------------------------------------------------------------------------------|----------|---------------------------------------|
| `controllerNamePrefix`                 | string  | Name for the managed NGINX Ingress Controller resources.                                                                                   | Yes      | `nginx`                               |
| `customHTTPErrors`                     | array   | Array of error codes to be sent to the default backend if there's an error.                                                                | No       |                                       |
| `defaultBackendService`                | object  | Service to route unmatched HTTP traffic. Contains nested properties:                                                                     | No       |                                       |
| &emsp;`name`                           | string  | Service name.                                                                                                                              | Yes      |                                       |
| &emsp;`namespace`                      | string  | Service namespace.                                                                                                                         | Yes      |                                       |
| `defaultSSLCertificate`                | object  | Contains the default certificate for accessing the default backend service. Contains nested properties:                                   | No       |                                       |
| &emsp;`forceSSLRedirect`               | boolean | Forces HTTPS redirection when a certificate is set.                                                                                        | No       | `false`                               |
| &emsp;`keyVaultURI`                    | string  | URI for a Key Vault secret storing the certificate.                                                                                        | No       |                                       |
| &emsp;`secret`                         | object  | Holds secret information for the default SSL certificate. Contains nested properties:                                                       | No       |                                       |
| &emsp;&emsp;`name`                     | string  | Secret name.                                                                                                                               | Yes      |                                       |
| &emsp;&emsp;`namespace`                | string  | Secret namespace.                                                                                                                          | Yes      |                                       |
| `httpDisabled`                         | boolean | Flag to disable HTTP traffic to the controller.                                                                                            | No       |                                       |
| `ingressClassName`                     | string  | IngressClass name used by the controller.                                                                                                  | Yes      | `nginx.approuting.kubernetes.azure.com` |
| `loadBalancerAnnotations`              | object  | A map of annotations to control the behavior of the NGINX ingress controller's service by setting [load balancer annotations](load-balancer-standard.md#customizations-via-kubernetes-annotations). | No       |                                       |
| `scaling`                              | object  | Configuration for scaling the controller. Contains nested properties:                                                                       | No       |                                       |
| &emsp;`maxReplicas`                    | integer | Upper limit for replicas.                                                                                                                  | No       | `100`                                 |
| &emsp;`minReplicas`                    | integer | Lower limit for replicas.                                                                                                                  | No       | `2`                                   |
| &emsp;`threshold`                      | string  | Scaling threshold defining how aggressively to scale. **`rapid`** scales quickly for sudden spikes, **`steady`** favors cost-effectiveness, and **`balanced`** is a mix. | No       | `balanced`                           |

## Control the default NGINX ingress controller configuration

When you enable the application routing add-on with NGINX, it creates an ingress controller called `default` in the `app-routing-namespace` configured with a public facing Azure load balancer. That ingress controller uses an ingress class name of `webapprouting.kubernetes.azure.com`.

You can also control if the default gets a public or an internal IP, or if it gets created at all when enabling the add-on.

Possible configuration options include:

- **`None`**: The default NGINX ingress controller isn't created and isn't deleted if it already exists. You should manually delete the default `NginxIngressController` custom resource if desired.
- **`Internal`**: The default NGINX ingress controller is created with an internal load balancer. Any annotation changes on the `NginxIngressController` custom resource to make it external are overwritten.
- **`External`**: The default NGINX ingress controller created with an external load balancer. Any annotation changes on the `NginxIngressController` custom resource to make it internal are overwritten.
- **`AnnotationControlled`** (default): The default NGINX ingress controller is created with an external load balancer. You can edit the default `NginxIngressController` custom resource to configure load balancer annotations.)

### Control the default ingress controller configuration on a new cluster

#### [Azure CLI](#tab/azure-cli)

- Enable application routing on a new cluster using the [`az aks create`][az-aks-create] command with the `--enable-app-routing` and `--app-routing-default-nginx-controller` flags. You need to set the `<DefaultIngressControllerType>` to one of the configuration options described in [Control the default NGINX ingress controller configuration](#control-the-default-nginx-ingress-controller-configuration).

    ```azurecli-interactive
    az aks create \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --location $LOCATION \
      --enable-app-routing \
      --app-routing-default-nginx-controller <DefaultIngressControllerType>
    ```

#### [Bicep](#tab/bicep)

The `webAppRouting` profile has an optional `nginx` configuration with a `defaultIngressControllerType` property that you can modify to control the default configuration.

- Set the `defaultIngressControllerType` property to one of the configuration options described in [Control the default NGINX ingress controller configuration](#control-the-default-nginx-ingress-controller-configuration).

    ```bicep
    "ingressProfile": {
      "webAppRouting": {
        "nginx": {
            "defaultIngressControllerType": "None|Internal|External|AnnotationControlled"
        }
    }
    ```

---

### Update the default ingress controller configuration on an existing cluster

#### [Azure CLI](#tab/azure-cli)

- Update the application routing default ingress controller configuration on an existing cluster using the [`az aks approuting update`][az-aks-approuting-update] command with the `--nginx` flag. You need to set the `<DefaultIngressControllerType>` to one of the configuration options described in [Control the default NGINX ingress controller configuration](#control-the-default-nginx-ingress-controller-configuration).

    ```azurecli-interactive
    az aks approuting update \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --nginx <DefaultIngressControllerType>
    ```

#### [Bicep](#tab/bicep)

The `webAppRouting` profile has an optional `nginx` configuration with a `defaultIngressControllerType` property that you can modify to control the default configuration.

- Set the `defaultIngressControllerType` property to one of the configuration options described in [Control the default NGINX ingress controller configuration](#control-the-default-nginx-ingress-controller-configuration).

    ```bicep
    "ingressProfile": {
      "webAppRouting": {
        "nginx": {
            "defaultIngressControllerType": "None|Internal|External|AnnotationControlled"
        }
    }
    ```

---

## Create another public facing NGINX ingress controller

1. Copy the following YAML manifest into a new file named `nginx-public-controller.yaml` and save the file to your local computer.

    ```yaml
    apiVersion: approuting.kubernetes.azure.com/v1alpha1
    kind: NginxIngressController
    metadata:
      name: nginx-public
    spec:
      ingressClassName: nginx-public
      controllerNamePrefix: nginx-public
    ```

1. Create the NGINX ingress controller resources using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nginx-public-controller.yaml
    ```

    The following example output shows the created resource:

    ```output
    nginxingresscontroller.approuting.kubernetes.azure.com/nginx-public created
    ```

## Create an internal NGINX ingress controller with a private IP address

1. Copy the following YAML manifest into a new file named `nginx-internal-controller.yaml` and save the file to your local computer.

    ```yaml
    apiVersion: approuting.kubernetes.azure.com/v1alpha1
    kind: NginxIngressController
    metadata:
      name: nginx-internal
    spec:
      ingressClassName: nginx-internal
      controllerNamePrefix: nginx-internal
      loadBalancerAnnotations: 
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    ```

1. Create the NGINX ingress controller resources using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nginx-internal-controller.yaml
    ```

    The following example output shows the created resource:

    ```output
    nginxingresscontroller.approuting.kubernetes.azure.com/nginx-internal created
    ```

## Create an NGINX ingress controller with a static IP address

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $NETWORK_RESOURCE_GROUP --location $LOCATION
    ```

1. Create a static public IP address using the [`az network public ip create`][az-network-public-ip-create] command.

    ```azurecli-interactive
    az network public-ip create \
      --resource-group $NETWORK_RESOURCE_GROUP \
      --name $PUBLIC_IP_NAME \
      --sku Standard \
      --allocation-method static
    ```

    > [!NOTE]
    > If you're using a *Basic* SKU load balancer in your AKS cluster, use `Basic` for the `--sku` parameter when defining a public IP. Only `Basic` SKU IPs work with the _Basic_ SKU load balancer and only `Standard` SKU IPs work with the _Standard_ SKU load balancers.

1. Ensure the cluster identity used by the AKS cluster has delegated permissions to the public IP's resource group using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    CLIENT_ID=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query identity.principalId -o tsv)
    RG_SCOPE=$(az group show --name $NETWORK_RESOURCE_GROUP --query id -o tsv)
    az role assignment create \
      --assignee ${CLIENT_ID} \
      --role "Network Contributor" \
      --scope ${RG_SCOPE}
    ```

1. Copy the following YAML manifest into a new file named `nginx-staticip-controller.yaml` and save the file to your local computer.

    > [!NOTE]
    > You can either use `service.beta.kubernetes.io/azure-pip-name` for public IP name, or use `service.beta.kubernetes.io/azure-load-balancer-ipv4` for an IPv4 address and `service.beta.kubernetes.io/azure-load-balancer-ipv6` for an IPv6 address, as shown in the example YAML. Adding the `service.beta.kubernetes.io/azure-pip-name` annotation ensures the most efficient Load Balancer creation and is highly recommended to avoid potential throttling.

    ```yaml
    apiVersion: approuting.kubernetes.azure.com/v1alpha1
    kind: NginxIngressController
    metadata:
      name: nginx-static
    spec:
      ingressClassName: nginx-static
      controllerNamePrefix: nginx-static
      loadBalancerAnnotations: 
        service.beta.kubernetes.io/azure-pip-name: "$PUBLIC_IP_NAME"
        service.beta.kubernetes.io/azure-load-balancer-resource-group: "$NETWORK_RESOURCE_GROUP"
    ```

1. Create the NGINX ingress controller resources using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nginx-staticip-controller.yaml
    ```

    The following example output shows the created resource:

    ```output
    nginxingresscontroller.approuting.kubernetes.azure.com/nginx-static created
    ```

## Verify the ingress controller was created

- Verify the status of the NGINX ingress controller using the [`kubectl get nginxingresscontroller`][kubectl-get] command.

    ```bash
    kubectl get nginxingresscontroller --name $INGRESS_CONTROLLER_NAME
    ```

    The following example output shows the created resource. It may take a few minutes for the controller to be available:

    ```output
    NAME           INGRESSCLASS   CONTROLLERNAMEPREFIX   AVAILABLE
    nginx-public   nginx-public   nginx                  True
    ```

### View the conditions of the ingress controller

- View the conditions of the ingress controller to troubleshoot any issues using the [`kubectl get nginxingresscontroller`][kubectl-get] command.

    ```bash
    kubectl get nginxingresscontroller --name $INGRESS_CONTROLLER_NAME -o jsonpath='{range .items[*].status.conditions[*]}{.lastTransitionTime}{"\t"}{.status}{"\t"}{.type}{"\t"}{.message}{"\n"}{end}'
    ```

    The following example output shows the conditions of a healthy ingress controller:

    ```output
    2023-11-29T19:59:24Z    True    IngressClassReady       Ingress Class is up-to-date
    2023-11-29T19:59:50Z    True    Available               Controller Deployment has minimum availability and IngressClass is up-to-date
    2023-11-29T19:59:50Z    True    ControllerAvailable     Controller Deployment is available
    2023-11-29T19:59:25Z    True    Progressing             Controller Deployment has successfully progressed
    ```

## Use the ingress controller in an ingress

1. Copy the following YAML manifest into a new file named `ingress.yaml` and save the file to your local computer.

    > [!NOTE]
    > Update `<HostName>` with your DNS host name.
    > The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: aks-helloworld
      namespace: hello-web-app-routing
    spec:
      ingressClassName: <IngressClassName>
      rules:
      - host: <HostName>
        http:
          paths:
          - backend:
              service:
                name: aks-helloworld
                port:
                  number: 80
            path: /
            pathType: Prefix
    ```

1. Create the cluster resources using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f ingress.yaml --namespace hello-web-app-routing
    ```

    The following example output shows the created resource:

    ```output
    ingress.networking.k8s.io/aks-helloworld created
    ```

## Verify the managed ingress was created

- Verify the managed ingress was created using the [`kubectl get ingress`][kubectl-get] command.

    ```bash
    kubectl get ingress --namespace hello-web-app-routing
    ```

    Your output should resemble the following example output:

    ```output
    NAME             CLASS                                HOSTS               ADDRESS       PORTS     AGE
    aks-helloworld   webapprouting.kubernetes.azure.com   myapp.contoso.com   20.51.92.19   80, 443   4m
    ```

### Clean up of ingress controllers

- Remove the NGINX ingress controller using the [`kubectl delete nginxingresscontroller`][kubectl-delete] command.

    ```bash
    kubectl delete nginxingresscontroller --name $INGRESS_CONTROLLER_NAME
    ```

:::zone-end

:::zone pivot="ingress-resource-annotations"

## Configuration per ingress resource through annotations

The NGINX ingress controller supports adding [annotations to specific ingress objects](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/) to customize their behavior.

You can [annotate](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) the ingress object by adding the respective annotation in the `metadata.annotations` field.

> [!NOTE]
> Annotation keys and values can only be strings. Other types, such as boolean or numeric values must be quoted. For example: `"true"`, `"false"`, `"100"`.

The following sections provide examples for common configurations. For a full list, see the [NGINX ingress annotations documentation](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/).

### Custom max body size

For NGINX, a 413 error is returned to the client when the size in a request exceeds the maximum allowed size of the client request body. To override the default value, use the annotation:

```yaml
nginx.ingress.kubernetes.io/proxy-body-size: 4m
```

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 4m
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 80
        path: /
        pathType: Prefix
```

### Custom connection timeout

You can change the timeout that the NGINX ingress controller waits to close a connection with your workload. All timeout values are unitless and in seconds. To override the default timeout, use the following annotation to set a valid 120-seconds proxy read timeout:

```yaml
nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
```

Review [custom timeouts](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#custom-timeouts) for other configuration options.

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 80
        path: /
        pathType: Prefix
```

### Backend protocol

The NGINX ingress controller uses `HTTP` to reach the services by default. To configure alternative backend protocols such as `HTTPS` or `GRPC`, use one of the following annotations:

```yaml
# HTTPS annotation
nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"

# GRPC annotation
nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
```

Review [backend protocols](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#backend-protocol) for other configuration options.

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 80
        path: /
        pathType: Prefix
```

### Cross-Origin Resource Sharing (CORS)

To enable Cross-Origin Resource Sharing (CORS) in an Ingress rule, use the following annotation:

```yaml
nginx.ingress.kubernetes.io/enable-cors: "true"
```

Review [enable CORS](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#enable-cors) for other configuration options.

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 80
        path: /
        pathType: Prefix
```

### Disable SSL redirect

The controller redirects (308) to HTTPS if TLS is enabled for an ingress by default. To disable this feature for specific ingress resources, use the following annotation:

```yaml
nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

Review [server-side HTTPS enforcement through redirect](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#server-side-https-enforcement-through-redirect) for other configuration options.

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 80
        path: /
        pathType: Prefix
```

### URL rewriting

In some scenarios, the exposed URL in the backend service differs from the specified path in the ingress rule. Without a rewrite any request returns 404. This configuration is useful with [path-based routing](https://kubernetes.github.io/ingress-nginx/user-guide/ingress-path-matching/) where you can serve two different web applications under the same domain. You can set path expected by the service using the following annotation:

```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
```

Here's an example ingress configuration using this annotation:

> [!NOTE]
> Update `<HostName>` with your DNS host name.
> The `<IngressClassName>` is the one you defined when creating the `NginxIngressController`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  namespace: hello-web-app-routing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: <IngressClassName>
  rules:
  - host: <HostName>
    http:
      paths:
      - path: /app-one(/|$)(.*)
        pathType: Prefix 
        backend:
          service:
            name: app-one
            port:
              number: 80
      - path: /app-two(/|$)(.*)
        pathType: Prefix 
        backend:
          service:
            name: app-two
            port:
              number: 80
```

### NGINX health probe path update

The default health probe path for the Azure Load Balancer associated with the NGINX ingress controller must be set to `"/healthz"`. To ensure correct health checks, verify that the ingress controller service has the following annotation:

```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz"
```

If you're using Helm to manage your NGINX ingress controller, you can define the Azure Load Balancer health-probe annotation in a values file and apply it during an upgrade:

```yaml
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz"
```

This configuration helps maintain service availability and avoids unexpected traffic disruption during upgrades.

:::zone-end

## Next steps

Learn about monitoring the ingress-nginx controller metrics included with the application routing add-on with [with Prometheus in Grafana][prometheus-in-grafana] as part of analyzing the performance and usage of your application.

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete

<!-- LINKS - internal -->
[az-network-public-ip-create]: /cli/azure/network/public-ip#az_network_public_ip_create
[az-group-create]: /cli/azure/group#az-group-create
[app-routing-add-on-basic-configuration]: app-routing.md
[az-aks-approuting-update]: /cli/azure/aks/approuting#az-aks-approuting-update
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[prometheus-in-grafana]: app-routing-nginx-prometheus.md
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-create]: /cli/azure/aks#az-aks-create
