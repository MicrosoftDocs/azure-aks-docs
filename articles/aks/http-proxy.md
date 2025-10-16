---
title: Configure Azure Kubernetes Service (AKS) nodes with an HTTP proxy
description: Learn how to configure Azure Kubernetes Service (AKS) clusters to use an HTTP proxy for outbound internet access.
ms.subservice: aks-networking
ms.custom: devx-track-arm-template, devx-track-azurecli
author: allyford
ms.topic: how-to
ms.date: 06/17/2025
ms.author: allyford
zone_pivot_groups: arm-azure-cli
# Customer intent: "As a DevOps engineer, I want to configure an HTTP proxy for AKS nodes, so that I can ensure secure outbound internet access in environments requiring proxy routing."
---

# HTTP proxy support in Azure Kubernetes Service (AKS)

In this article, you learn how to configure Azure Kubernetes Service (AKS) clusters to use an HTTP proxy for outbound internet access.

AKS clusters deployed into managed or custom virtual networks have certain outbound dependencies that are necessary to function properly, which created problems in environments requiring internet access to be routed through HTTP proxies. Nodes had no way of bootstrapping the configuration, environment variables, and certificates necessary to access internet services.

The HTTP proxy feature adds HTTP proxy support to AKS clusters, exposing a straightforward interface that you can use to secure AKS-required network traffic in proxy-dependent environments. With this feature, both AKS nodes and pods are configured to use the HTTP proxy. The feature also enables installation of a trusted certificate authority onto the nodes as part of bootstrapping a cluster. More complex solutions might require creating a chain of trust to establish secure communications across the network.

## Limitations and considerations

The following scenarios are **not** supported:

* Different proxy configurations per node pool
* User/Password authentication
* Custom certificate authorities (CAs) for API server communication
* AKS clusters with Windows node pools
* Node pools using Virtual Machine Availability Sets (VMAS)
* Using * as wildcard attached to a domain suffix for noProxy

`httpProxy`, `httpsProxy`, and `trustedCa` have no value by default. Pods are injected with the following environment variables:

* `HTTP_PROXY`
* `http_proxy`
* `HTTPS_PROXY`
* `https_proxy`
* `NO_PROXY`
* `no_proxy`

To disable the injection of the proxy environment variables, you need to annotate the Pod with `"kubernetes.azure.com/no-http-proxy-vars":"true"`.

:::zone target="docs" pivot="azure-cli"

## Before you begin

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
:::zone-end
:::zone target="docs" pivot="azure-cli"

## Create a configuration file with HTTP proxy values

Create a file and provide values for `httpProxy`, `httpsProxy`, and `noProxy`. If your environment requires it, provide a value for `trustedCa`.

The schema for the config file looks like this:

```json
{
  "httpProxy": "string",
  "httpsProxy": "string",
  "noProxy": [
    "string"
  ],
  "trustedCa": "string"
}
```

Review requirements for each parameter:

* `httpProxy`: A proxy URL to use for creating HTTP connections outside the cluster. The URL scheme must be `http`.
* `httpsProxy`: A proxy URL to use for creating HTTPS connections outside the cluster. If not specified, then `httpProxy` is used for both HTTP and HTTPS connections.
* `noProxy`: A list of destination domain names, domains, IP addresses, or other network CIDRs to exclude proxying. 
* `trustedCa`: A string containing the `base64 encoded` alternative CA certificate content. Currently only the `PEM` format is supported.

> [!IMPORTANT]
> For compatibility with Go-based components that are part of the Kubernetes system, the certificate **must** support `Subject Alternative Names(SANs)` instead of the deprecated Common Name certs.
>
> There are differences in applications on how to comply with the environment variable `http_proxy`, `https_proxy`, and `no_proxy`. Curl and Python don't support CIDR in `no_proxy`, but Ruby does.

Example input:

```json
{
  "httpProxy": "http://myproxy.server.com:8080/", 
  "httpsProxy": "https://myproxy.server.com:8080/", 
  "noProxy": [
    "localhost",
    "127.0.0.1"
  ],
  "trustedCA": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUgvVENDQmVXZ0F3SUJB...S0tLS0="
}
```

## Create a cluster with an HTTP proxy configuration using the Azure CLI

You can configure an AKS cluster with an HTTP proxy configuration during cluster creation.

1. Use the [`az aks create`][az-aks-create] command and pass in your configuration as a JSON file.

   ```azurecli-interactive
   az aks create \
       --name $clusterName \
       --resource-group $resourceGroup \
       --http-proxy-config aks-proxy-config.json \
       --generate-ssh-keys
    ```

    Your cluster should initialize with the HTTP proxy configured on the nodes.

1. Verify the HTTP proxy configuration is on the pods and nodes by checking that the environment variables contain the appropriate values for `http_proxy`, `https_proxy`, and `no_proxy` using the `kubectl describe pod` command.

    ```bash
    kubectl describe {any pod} -n kube-system
    ```

    To validate proxy variables are set in pods, you can check the environment variables present on the nodes. 

    ```bash
    kubectl get nodes
    kubectl node-shell {node name}
    cat /etc/environment
    ```

## Update an HTTP proxy configuration

You can update HTTP proxy configurations on existing clusters, including:

- Updating an existing cluster to enable HTTP proxy and adding a new HTTP proxy configuration.
- Updating an existing cluster to change an HTTP proxy configuration.

### HTTP proxy update considerations

The `--http-proxy-config` parameter should be set to a new JSON file with updated values for `httpProxy`, `httpsProxy`, `noProxy`, and `trustedCa` if necessary. The update injects new environment variables into pods with the new `httpProxy`, `httpsProxy`, or `noProxy` values. Pods must be rotated for the apps to pick it up, because the environment variable values are injected by a mutating admission webhook.

> [!NOTE]
> If switching to a new proxy, the new proxy must already exist for the update to be successful. After the upgrade is completed, you can delete the old proxy.

### Update a cluster to update or enable HTTP proxy

1. Enable or update HTTP proxy configurations on an existing cluster using the [`az aks update`][az-aks-update] command. 

    For example, let's say you created a new file with the base64 encoded string of the new CA cert called *aks-proxy-config-2.json*. You can update the proxy configuration on your cluster with the following command:

    ```azurecli-interactive
    az aks update --name $clusterName --resource-group $resourceGroup --http-proxy-config aks-proxy-config-2.json
    ```
    
> [!CAUTION]
> AKS automatically reimages all node pools in the cluster when you update the proxy configuration on your cluster using the [`az aks update`][az-aks-update] command. You can use [Pod Disruption Budgets (PDBs)][operator-best-practices-scheduler] to safeguard disruption to critical pods during reimage. 

1. Verify the HTTP proxy configuration is on the pods and nodes by checking that the environment variables contain the appropriate values for `http_proxy`, `https_proxy`, and `no_proxy` using the `kubectl describe pod` command.

    ```bash
    kubectl describe {any pod} -n kube-system
    ```

    To validate proxy variables are set in pods, you can check the environment variables present on the nodes. 

    ```bash
    kubectl get nodes
    kubectl node-shell {node name}
    cat /etc/environment
    ```

## Disable HTTP proxy on an existing cluster (Preview)

### Install `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Disable HTTP Proxy requires a minimum of 18.0.0b13**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register `DisableHTTPProxyPreview` feature flag

1. Register the `DisableHTTPProxyPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name DisableHTTPProxyPreview
    ```

1. Verify the registration status using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the status to show *Registered*.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name DisableHTTPProxyPreview
    ```

1. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Update cluster to disable HTTP proxy (preview)

1. Update your cluster to disable HTTP proxy using the [`az aks update`][az-aks-update] command with `--disable-http-proxy` flag.

    ```azurecli-interactive
    az aks update --name $clusterName --resource-group $resourceGroup --disable-http-proxy
    ```

> [!CAUTION]
> AKS automatically reimages all node pools in the cluster when you update the proxy configuration on your cluster using the [`az aks update`][az-aks-update] command. You can use [Pod Disruption Budgets (PDBs)][operator-best-practices-scheduler] to safeguard disruption to critical pods during reimage. 

1. Verify HTTP proxy is disabled by validating the HTTP proxy configuration isn't set on the pods and nodes using the `kubectl describe pod` command.

    ```bash
    kubectl describe {any pod} -n kube-system
    ```

    To validate proxy variables aren't set in pods, you can check the environment variables present on the nodes. 

    ```bash
    kubectl get nodes
    kubectl node-shell {node name}
    cat /etc/environment
    ```

### Re-enable HTTP proxy on an existing cluster

When you create a cluster, HTTP proxy is enabled by default. Once you disable HTTP proxy on a cluster, the proxy configuration is saved in the database but the proxy variables are removed from the pods and nodes.

To re-enable HTTP proxy on an existing cluster, use the [`az aks update`][az-aks-update] command with the `--enable-http-proxy` flag.

   ```azurecli-interactive
   az aks update --name $clusterName --resource-group $resourceGroup --enable-http-proxy
   ```

> [!CAUTION]
> AKS automatically reimages all node pools in the cluster when you update the proxy configuration on your cluster using the [`az aks update`][az-aks-update] command. You can use [Pod Disruption Budgets (PDBs)][operator-best-practices-scheduler] to safeguard disruption to critical pods during reimage.

> [!IMPORTANT]
> If you had an HTTP proxy configuration on your cluster before disabling, the existing HTTP proxy configuration automatically applies when you re-enable HTTP proxy on that cluster. We recommend verifying the configuration to ensure it meets your current requirements before proceeding. If you want to change your HTTP proxy configuration after re-enabling HTTP proxy, follow the steps to [Update the HTTP proxy configuration on an existing cluster](#update-a-cluster-to-update-or-enable-http-proxy).

:::zone-end

:::zone target="docs" pivot="arm"

## Configure an HTTP proxy configuration using an Azure Resource Manager (ARM) template

You can deploy an AKS cluster with an HTTP proxy using an ARM template. 

1. Review requirements for each parameter:

   * `httpProxy`: A proxy URL to use for creating HTTP connections outside the cluster. The URL scheme must be `http`.
   * `httpsProxy`: A proxy URL to use for creating HTTPS connections outside the cluster. If not specified, then `httpProxy` is used for both HTTP and HTTPS connections.
   * `noProxy`: A list of destination domain names, domains, IP addresses, or other network CIDRs to exclude proxying.
   * `trustedCa`: A string containing the `base64 encoded` alternative CA certificate content. Currently only the `PEM` format is supported.

    > [!IMPORTANT]
    > For compatibility with Go-based components that are part of the Kubernetes system, the certificate **must** support `Subject Alternative Names (SANs)` instead of the deprecated Common Name certs.
    >
    > There are differences in applications on how to comply with the environment variable `http_proxy`, `https_proxy`, and `no_proxy`. Curl and Python don't support CIDR in `no_proxy`, but Ruby does.

1. Create a template with HTTP proxy parameters. In your template, provide values for `httpProxy`, `httpsProxy`, and `noProxy`. If necessary, provide a value for `trustedCa`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "httpProxyConfig": {
          "enabled": "true",
            "httpProxy": "string",
            "httpsProxy": "string",
            "noProxy": [
                "string"
            ],
            "trustedCa": "string"
        }
    }
    ```

1. Deploy your ARM template with the HTTP Proxy configuration. Your cluster should initialize with your HTTP proxy configured on the nodes.

## Update an HTTP proxy configuration
  
You can update HTTP proxy configurations on existing clusters, including:
  
- Updating an existing cluster to enable HTTP proxy and adding a new HTTP proxy configuration.
- Updating an existing cluster to change an HTTP proxy configuration.

### HTTP proxy update considerations
  
The `--http-proxy-config` parameter should be set to a new JSON file with updated values for `httpProxy`, `httpsProxy`, `noProxy`, and `trustedCa` if necessary. The update injects new environment variables into pods with the new `httpProxy`, `httpsProxy`, or `noProxy` values. Pods must be rotated for the apps to pick it up, because the environment variable values are injected by a mutating admission webhook.
  
> [!NOTE]
> If switching to a new proxy, the new proxy must already exist for the update to be successful. After the upgrade is completed, you can delete the old proxy.

### Update an ARM template to configure HTTP proxy

1. In your template, provide new values for `httpProxy`, `httpsProxy`, and `noProxy`. If necessary, provide a value for `trustedCa`. 

    The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "httpProxyConfig": {
            "enabled": "true",
            "httpProxy": "string",
            "httpsProxy": "string",
            "noProxy": [
                "string"
            ],
            "trustedCa": "string"
        }
    }
    ```

1. Deploy your ARM template with the updated HTTP Proxy configuration.

> [!CAUTION]
> AKS automatically reimages all node pools in the cluster when you update the proxy configuration on your cluster using the [`az aks update`][az-aks-update] command. You can use [Pod Disruption Budgets (PDBs)][operator-best-practices-scheduler] to safeguard disruption to critical pods during reimage.

1. Verify the HTTP proxy configuration is on the pods and nodes by checking that the environment variables contain the appropriate values for `http_proxy`, `https_proxy`, and `no_proxy` using the `kubectl describe pod` command.

    ```bash
    kubectl describe {any pod} -n kube-system
    ```

    To validate proxy variables are set in pods, you can check the environment variables present on the nodes. 

    ```bash
    kubectl get nodes
    kubectl node-shell {node name}
    cat /etc/environment
    ```

## Disable HTTP proxy on an existing cluster using an ARM template (Preview)

### Install `aks-preview` extension
  
1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]
  
    ```azurecli-interactive
    az extension add --name aks-preview
    ```
  
1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Disable HTTP Proxy requires a minimum of 18.0.0b13**.
  
    ```azurecli-interactive
    az extension update --name aks-preview
    ```
  
### Register `DisableHTTPProxyPreview` feature flag
  
1. Register the `DisableHTTPProxyPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.
  
    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name DisableHTTPProxyPreview
    ```
  
1. Verify the registration status using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the status to show *Registered*.
  
    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name DisableHTTPProxyPreview
    ```
  
1. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.
  
    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Update cluster to disable HTTP proxy  

1. Update your cluster ARM template to disable HTTP proxy by setting `enabled` to `false`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "httpProxyConfig": {
           "enabled": "false",
        }
    }
    ```

1. Deploy your ARM template with HTTP Proxy disabled.

> [!CAUTION]
> AKS automatically reimages all node pools in the cluster when you update the proxy configuration on your cluster using the [`az aks update`][az-aks-update] command. You can use [Pod Disruption Budgets (PDBs)][operator-best-practices-scheduler] to safeguard disruption to critical pods during reimage.

1. Verify HTTP proxy is disabled by validating that the HTTP Proxy configuration isn't set on the pods and nodes using the `kubectl describe pod` command.

    ```bash
    kubectl describe {any pod} -n kube-system
    ```

    To validate proxy variables aren't set in pods, you can check the environment variables present on the nodes. 

    ```bash
    kubectl get nodes
    kubectl node-shell {node name}
    cat /etc/environment
    ```

### Re-enable HTTP proxy on an existing cluster
  
When you create a cluster, HTTP proxy is enabled by default. Once you disable HTTP proxy on a cluster, you can no longer add HTTP proxy configurations to that cluster.

If you want to re-enable HTTP proxy, follow the steps to [Update an HTTP proxy configuration using an ARM template](#update-an-arm-template-to-configure-http-proxy).

:::zone-end

---

## Istio add-on HTTP proxy for External Services

If you're using the [Istio-based service mesh add-on for AKS][istio-add-on-docs], you must create a Service Entry to enable your applications in the mesh to access noncluster or external resources via the HTTP proxy. 

For example:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
    name: proxy
spec:
    hosts:
    - my-company-proxy.com # ignored
    addresses:
    - $PROXY_IP/32
    ports:
    - number: $PROXY_PORT
        name: tcp
        protocol: TCP
    location: MESH_EXTERNAL
```

1. Create a file and provide values for `PROXY_IP` and `PROXY_PORT`. 
1. You can deploy the Service Entry using:

    ```bash
    kubectl apply -f service_proxy.yaml
    ```
---

## Monitoring add-on configuration

HTTP proxy with the monitoring add-on supports the following configurations:

* Outbound proxy without authentication
* Outbound proxy with trusted cert for Log Analytics endpoint

The following configuration isn't supported: 

* Custom Metrics and Recommended Alerts features when using a proxy with trusted certificates

## Next steps

For more information regarding the network requirements of AKS clusters, see [Control egress traffic for cluster nodes in AKS][aks-egress].

<!-- LINKS - internal -->
[aks-egress]: ./limit-egress-traffic.md
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[install-azure-cli]: /cli/azure/install-azure-cli
[istio-add-on-docs]: ./istio-about.md
[operator-best-practices-scheduler]: ./operator-best-practices-scheduler.md

