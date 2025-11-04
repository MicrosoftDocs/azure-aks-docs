---
title: Configure container network metrics filtering for Azure Kubernetes Service (AKS)
description: Learn how to configure container network metrics filtering to optimize data collection and reduce storage costs in Azure Kubernetes Service (AKS) with Cilium.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 10/30/2025
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Configure container network metrics filtering for Azure Kubernetes Service (AKS) (Preview)

This article shows you how to configure container network metrics filtering for Azure Kubernetes Service (AKS) with Cilium to optimize data collection, reduce storage costs, and focus on the metrics most relevant to your monitoring needs.

Container network metrics filtering enables dynamic management of Hubble metrics cardinality through Kubernetes Custom Resource Definitions (CRDs). This feature allows you to dynamically control the cardinality, dimensions, and targets of Hubble metrics without restarting Cilium agents or Prometheus servers.

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.

[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* The minimum version of the Azure CLI required to complete the steps in this article is **2.73.0**. To find your version, run `az --version` in the Azure CLI. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

* An AKS cluster with Cilium data plane and [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

* Kubernetes version 1.32 or later.

* Container network metrics filtering works specifically with Cilium data planes.

* Access to a canary region (eastus2euap) for preview features.

* The minimum version of the `aks-preview` Azure CLI extension to complete the steps in this article is `18.0.0b2`.

### Install the aks-preview Azure CLI extension

Install or update the Azure CLI preview extension by using the [`az extension add`](/cli/azure/extension#az_extension_add) or [`az extension update`](/cli/azure/extension#az_extension_update) command.

```azurecli
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

## Configure container network metrics filtering

### Register the AdvancedNetworkingDynamicMetricsPreview feature flag

First, register the AdvancedNetworkingDynamicMetricsPreview feature flag by using the [`az feature register`](/cli/azure/feature#az_feature_register) command:

```azurecli
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingDynamicMetricsPreview"
```

Verify successful registration by using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for registration to complete.

```azurecli
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingDynamicMetricsPreview"
```

When the feature shows **Registered**, refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`](/cli/azure/provider#az_provider_register) command.

```azurecli
az provider register --namespace Microsoft.ContainerService
```

### Create a new AKS cluster with Cilium

Create a new AKS cluster with Cilium data plane and Advanced Container Networking Services enabled:

```azurecli
# Set environment variables
export RESOURCE_GROUP="cnm-testing-rg"
export CLUSTER_NAME="cnm-cilium-cluster"
export LOCATION="eastus2euap"  # Use canary region for preview features

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster with Cilium and ACNS enabled
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --network-plugin azure \
    --network-dataplane cilium \
    --enable-acns \
    --enable-managed-identity \
    --generate-ssh-keys \
    --kubernetes-version 1.32
```

### Get cluster credentials

Get your cluster credentials by using the [`az aks get-credentials`](/cli/azure/aks#az_aks_get_credentials) command:

```azurecli
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
```

### Configure custom resources for metrics filtering 

Container network metrics filtering uses the `ContainerNetworkMetric` Custom Resource Definition (CRD) to define filtering rules. Only one CRD can exist per cluster, and changes take about 30 seconds to reconcile.


```azurecli
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: sample-containeretworkmetric # Cluster scoped
spec:
  includefilters: # List of filters
    - name: sample-filter # Filter name
      from:
        namespacedPod: # List of source namespace/pods. Prepend namespace with /
          - sample-namespace/sample-pod
        labelSelector: # Standard k8s label selector
          matchLabels:
            app: frontend
            k8s.io/namespace: sample-namespace
          matchExpressions:
            - key: environment
              operator: In
              values:
                - production
                - staging
        ip: # List of source IPs; can be CIDR
          - "192.168.1.10"
          - "10.0.0.1"
      to:
        namespacedPod:
          - sample-namespace2/sample-pod2
        labelSelector:
          matchLabels:
            app: backend
            k8s.io/namespace: sample-namespace2
          matchExpressions:
            - key: tier
              operator: NotIn
              values:
                - dev
        ip:
          - "192.168.1.20"
          - "10.0.1.1"
      protocol: # List of protocols; can be tcp, udp, dns
        - tcp
        - udp
        - dns
      verdict: # List of verdicts; can be forwarded, dropped
        - forwarded
        - dropped
```

The following table describes the fields in the custom resource definition:

| Field                        | Type         | Description                                                                                                                         | Required |
|----------------------------------|------------------|-----------------------------------------------------------------------------------------------------------------------------------------|--------------|
| `includefilters`                 | []filter | A list of filters that define network flows to include. Each filter specifies the source, destination, protocol, and other matching criteria. Include filters can't be empty and must have at least one filter. | Mandatory    |
| `filters.name`            | String           | The name of the filter.                                                                                                                | Optional    |
| `filters.protocol`        | []string | The protocols to match for this filter. Valid values are `tcp`, `udp`, and `dns`. Because it's an optional parameter, if it isn't specified, logs with all protocols are included.                                                      | Optional     |
| `filters.verdict`         | []string | The verdict of the flow to match. Valid values are `forwarded` and `dropped`. Because it's an optional parameter, if it isn't specified, logs with all verdicts are included.                                                        | Optional     |
| `filters.from`            | Endpoint          | Specifies the source of the network flow. Can include IP addresses, label selectors, and namespace/pod pairs.                           | Optional    |
| `Endpoint.ip`         | []string | It can be a single IP or a CIDR.                                                                                                         | Optional     |
| `Endpoint.labelSelector` | Object           | A label selector is a mechanism to filter and query resources based on labels, so you can identify specific subsets of resources. A label selector can include two components: `matchLabels` and `matchExpressions`. Use `matchLabels` for straightforward matching by specifying a key/value pair (for example, `{"app": "frontend"}`). For more advanced criteria, use `matchExpressions`, where you define a label key, an operator (such as `In`, `NotIn`, `Exists`, or `DoesNotExist`), and an optional list of values. Ensure that the conditions in both `matchLabels` and `matchExpressions` are met, because they're logically combined by `AND`. If no conditions are specified, the selector matches all resources. To match none, leave the selector null. Carefully define your label selector to target the correct set of resources.  | Optional     |
| `Endpoint.namespacedPod` | []string | A list of namespace and pod pairs (formatted as `namespace/pod`) for matching the source. `name` should match the RegEx pattern `^.+$`.                                              | Optional     |
| `filters.to`              | Endpoint           | Specifies the destination of the network flow. Can include IP addresses, label selectors, or namespace/pod pairs.                      | Optional    |
| `Endpoint.ip`           | []string | It can be a single IP or a CIDR.         | Optional     |
| `Endpoint.labelSelector` | Object           | A label selector to match resources based on their labels.                                                                             | Optional     |
| `Endpoint.namespacedPod` | []string | A list of namespace and pod pairs (formatted as `namespace/pod`) to match the destination.                                         | Optional     |


Apply the `ContainerNetworkMetric` custom resource to enable log collection at the cluster:

  ```azurecli
  kubectl apply -f <crd.yaml>
  ```

### Example filtering configuration

1. Create a basic filtering configuration that focuses on DNS metrics:

```yaml
# basic-dns-filter.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns  # Supported: dns, flow, tcp, drop
      includeFilters:
        - protocol: ["dns"]
      excludeFilters:
        - from:
            namespacedPod: ["kube-system/coredns-*"]
```


2. Configure filtering for TCP metrics with include and exclude filters:

```yaml
# tcp-metrics-filter.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: tcp
      includeFilters:
        - protocol: ["tcp"]
        - from:
            labelSelector:
              matchLabels:
                app: "frontend"
      excludeFilters:
        - to:
            namespacedPod: ["kube-system/metrics-server-*"]
```
3. Configure filtering for network flow metrics:

```yaml
# flow-metrics-filter.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: flow
      includeFilters:
        - from:
            labelSelector:
              matchLabels:
                tier: "frontend"
        - to:
            labelSelector:
              matchLabels:
                tier: "backend"
      excludeFilters:
        - from:
            namespacedPod: ["default/test-*"]
```

4. Drop metrics filtering

Configure filtering for dropped packet metrics (requires network policies):

```yaml
# drop-metrics-filter.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: drop
      includeFilters:
        - reason: ["Policy denied"]
      excludeFilters:
        - from:
            namespacedPod: ["kube-system/*"]
```

5. Configure filtering for multiple metric types in a single CRD:

```yaml
# multi-metrics-filter.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns
      includeFilters:
        - protocol: ["dns"]
      excludeFilters:
        - from:
            namespacedPod: ["kube-system/*"]
    - metric: tcp
      includeFilters:
        - protocol: ["tcp"]
        - from:
            labelSelector:
              matchLabels:
                environment: "production"
    - metric: flow
      excludeFilters:
        - from:
            namespacedPod: ["default/debug-*"]
    - metric: drop
      includeFilters:
        - reason: ["Policy denied", "Invalid"]
```

## Best practices

- Begin by including all necessary metrics, then progressively exclude specific ones.

- Leverage Kubernetes label selectors for flexible filtering.

- Always validate filtering configurations in development or staging

- Regularly review filtered metrics to ensure important data isn't lost.

- Remember that only one CRD can exist per cluster. Check existing CRDs before creating new ones.

## Troubleshooting

### Common issues

**Issue**: CRD configuration not applied

**Solution**: Check that the feature flag is registered and only one CRD exists:

```azurecli
# Verify feature registration
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingDynamicMetricsPreview"

# Check existing CRDs
kubectl get ContainerNetworkMetric
```

**Issue**: ConfigMap not updating after CRD changes

**Solution**: Wait 30 seconds for reconciliation and check logs:

```azurecli
# Wait for reconciliation (takes about 30 seconds)
sleep 30

# Check ConfigMap
kubectl get configmap cilium-dynamic-metrics-config -n kube-system -o yaml

# Check operator logs
kubectl logs -n kube-system -l app=retina-operator
```

**Issue**: Metrics still showing after applying excludeFilters

**Solution**: Remember that pre-existing metrics persist in Prometheus. You may need to wait for new metrics to be generated to see the filtering effects.

### Cleanup and reset

To clean up filtering configuration:

```azurecli
# Delete the CRD
kubectl delete ContainerNetworkMetric container-network-metric
```

## Limitations

* This feature is specifically designed for Cilium data planes only
* Only one `ContainerNetworkMetric` CRD can exist per cluster
* Changes to filtering configuration take approximately 30 seconds to reconcile
* Pre-existing metrics persist in Prometheus; new filtering rules apply to newly generated metrics
* Requires Kubernetes version 1.32 or later
* Available only in canary regions during preview
* Supported metric types are limited to: dns, flow, tcp, drop
* Dynamic metrics ConfigMap should not be manually edited as changes will be reverted

## Related content

- To learn about container network metrics capabilities, see [Container network metrics overview](container-network-observability-metrics.md).
- To create an AKS cluster with Advanced Container Networking Services, see [Set up Container Network Observability for AKS](container-network-observability-how-to.md).
- Get more information about [Advanced Container Networking Services for AKS](./advanced-container-networking-services-overview.md).