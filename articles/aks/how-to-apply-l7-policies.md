---
title: "Set up Layer 7(L7) policies with Advanced Container Networking Services (ACNS)"
description: Get started with Layer 7(L7) Feature for Advanced Container Networking Services (ACNS) for your AKS cluster using Azure managed Cilium Network Policies.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 03/14/2024
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Set up Layer 7(L7) policies with Advanced Container Networking Services (Preview)

This article demonstrates how to set up L7 policies with Advanced Container Networking Services in AKS clusters. Continue only after you have reviewed the limitations and considerations listed on the [Layer 7 Policy Overview](./container-network-security-l7-policy-concepts.md) page.

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

 The minimum version of Azure CLI required for the steps in this article is 2.71.0. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).


### Install the `aks-preview` Azure CLI extension

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az_extension_add) or [`az extension update`](/cli/azure/extension#az_extension_update) command.

 The minimum version of the aks-preview Azure CLI extension is `14.0.0b6`

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingL7PolicyPreview` feature flag

Register the `AdvancedNetworkingL7PolicyPreview` feature flag using the [`az feature register`](/cli/azure/feature#az_feature_register) command.

```azurecli-interactive 
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```
Verify successful registration using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az_provider_register) command.

### Enable Advanced Container Networking Services

To proceed, you must have an AKS cluster with [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability).

* **Container Network Security:** Offers security features like Fully Qualified Domain Name (FQDN) filtering. To learn more visit  [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security).

#### [**Cilium**](#tab/cilium)

> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability and Container Network security starting with Kubernetes version 1.29.
>
> For this demo, the `--acns-advanced-networkpolicies` parameter must be set to "L7" to enable L7 policies.  Setting this parameter to "L7" also enables FQDN filtering. If you only want to enable FQDN filtering, set the parameter to "FQDN". To disable both features, you can follow the instructions provided in [Disable Container Network Security] (advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

```azurecli-interactive

export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --network-plugin azure \
    --network-dataplane cilium \
    --enable-acns \
    --acns-advanced-networkpolicies L7
```

#### [**Non-Cilium**](#tab/non-cilium)

> [!NOTE]
> [L7 Policy](./container-network-security-l7-policy-concepts.md) feature is not available for Non-Cilium clusters.

---

### Enable Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features which includes [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability) and the [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security) feature.


> [!NOTE]
> Only clusters with the Cilium data plane support Container Network Security features of Advanced Container Networking Services. 
>
> For this demo, the `--acns-advanced-networkpolicies` parameter must be set to "L7" to enable L7 policies.  Setting this parameter to "L7" also enables FQDN filtering. If you only want to enable FQDN filtering, set the parameter to "FQDN". To disable both features, you can follow the instructions provided in [Disable Container Network Security] (advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-advanced-networkpolicies L7
``` 

## Get cluster credentials 

Get your cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az_aks_get_credentials) command.

```azurecli-interactive
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Set up http-server application on your AKS cluster

Apply the below YAML to your AKS cluster to set up the `http-server` application.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-server
  labels:
    app: http-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: http-server
  template:
    metadata:
      labels:
        app: http-server
    spec:
      containers:
      - name: http-server
        image: nginx:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config-volume
        configMap:
          name: nginx-config

---
apiVersion: v1
kind: Service
metadata:
  name: http-server
spec:
  selector:
    app: http-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  default.conf: |
    server {
        listen 8080;

        location / {
            return 200 "Hello from the server root!\n";
        }

        location /products {
            return 200 "Listing products...\n";
        }
    }
```
## Set up http-client application on your AKS Cluster


Apply the below YAML to your AKS cluster to set up the `http-client` application.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-client
  labels:
    app: http-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: http-client
  template:
    metadata:
      labels:
        app: http-client
    spec:
      containers:
      - name: http-client
        image: curlimages/curl:latest
        command: ["sleep", "infinity"]
```

## Test connectivity with a policy

Next, apply the following Layer 7 policy to allow only `GET` requests from the `http-client` application to the `/products` endpoint on the `http-server`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-get-products
spec:
  description: "Allow only GET requests to /products from http-client to http-server"
  endpointSelector:
    matchLabels:
      app: http-server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: http-client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/products"
```

### Verify policy
To verify the policy's enforcement, execute these commands from the `http-client` pod:

```azurecli-interactive
kubectl exec -it <your-http-client-pod-name> -n default -- curl -v http://http-server:80/products
```
You should expect an output like  `Listing products...` when you run the above command 


```azurecli-interactive
kubectl exec -it <your-http-client-pod-name> -n default -- curl -v -XPOST http://http-server:80/products -d "test=data"
```
You should expect an output like `Access Denied` when you run the above command 


### Observing L7 metrics

If you have Advanced Container Network Service's container network observability enabled, you can visualize the traffic on Grafana. 

To simplify the analysis of these L7 metrics, we provide preconfigured Azure Managed Grafana dashboards. You can find them under the **Dashboards > Azure Managed Prometheus** folder, with filenames like  **"Kubernetes/Networking/L7 (Namespace)"** and **"Kubernetes/Networking/L7 (Workload)"**. 

You should see metrics similar to the following:

[![Screenshot showing Grafana dashboard for L7 traffic.](./media/advanced-container-networking-services/l7-traffic-grafana.png)](./media/advanced-container-networking-services/l7-traffic-grafana.png#lightbox)


## Clean up resources

If you don't plan on using this application, delete the other resources you created in this article using the [`az group delete`](/cli/azure/#az_group_delete) command.

```azurecli-interactive
  az group delete --name $RESOURCE_GROUP
```

## Next steps

In this how-to article, you learned how to enable and apply L7 Policies with Advanced Container Networking Services for your AKS cluster.

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).