---
title: Configure container network metrics filtering for Azure Kubernetes Service (AKS)
description: Learn how to configure container network metrics filtering to optimize data collection and reduce storage costs in Azure Kubernetes Service (AKS) with Cilium.
author: shaifaligargmsft
ms.author: shaifaligarg
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

### Verify the setup

Verify that the dynamic metrics configuration is properly set up:

1. **Check the Cilium ConfigMap contains dynamic metrics configuration**:

   ```azurecli
   kubectl get configmap cilium-config -n kube-system -o yaml | grep -A 10 "dynamic-metrics-config"
   ```

2. **Verify the dynamic metrics ConfigMap is created with base metrics**:

   ```azurecli
   kubectl get configmap cilium-dynamic-metrics-config -n kube-system -o yaml
   ```

3. **Check that Cilium agents have started in dynamic metrics mode**:

   ```azurecli
   # Get a Cilium pod name
   CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
   
   # Check the logs for dynamic metrics configuration
   kubectl logs -n kube-system $CILIUM_POD | grep "Starting Hubble server with dynamically configurable metrics"
   ```

   You should see output similar to:
   ```
   level=info msg="Starting Hubble server with dynamically configurable metrics" address=":9965" metricConfig=/dynamic-metrics-config/dynamic-metrics.yaml subsys=hubble tls=false
   ```

## Configure filtering rules

Container network metrics filtering uses the `ContainerNetworkMetric` Custom Resource Definition (CRD) to define filtering rules. Only one CRD can exist per cluster, and changes take about 30 seconds to reconcile.

### Basic filtering configuration

Create a basic filtering configuration that focuses on DNS metrics:

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

Apply the configuration:

```azurecli
kubectl apply -f basic-dns-filter.yaml
```

### TCP metrics filtering

Configure filtering for TCP metrics with include and exclude filters:

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

Apply the configuration:

```azurecli
kubectl apply -f tcp-metrics-filter.yaml
```

### Flow metrics filtering

Configure filtering for network flow metrics:

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

Apply the configuration:

```azurecli
kubectl apply -f flow-metrics-filter.yaml
```

### Drop metrics filtering

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

Apply the configuration:

```azurecli
kubectl apply -f drop-metrics-filter.yaml
```

### Multi-metric filtering

Configure filtering for multiple metric types in a single CRD:

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

Apply the configuration:

```azurecli
kubectl apply -f multi-metrics-filter.yaml
```

## Validate the configuration

### Check filtering status

Verify that the filtering configuration is applied correctly:

```azurecli
# Check the ContainerNetworkMetric CRD
kubectl get ContainerNetworkMetric

# Get detailed information about the CRD
kubectl describe ContainerNetworkMetric container-network-metric
```

### Verify ConfigMap updates

Check that the dynamic metrics ConfigMap includes your filtering rules (takes about 30 seconds to reconcile):

```azurecli
kubectl get configmap cilium-dynamic-metrics-config -n kube-system -o yaml
```

### Check Cilium and Retina operator logs

Monitor for any errors during configuration:

```azurecli
# Check Cilium agent logs
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kube-system $CILIUM_POD | tail -20

# Check Retina operator logs
kubectl logs -n kube-system -l app=retina-operator
```

### Test ConfigMap resilience

Test that the configuration is resilient to changes:

1. **Edit the dynamic metrics ConfigMap** (it should reconcile back to default):

   ```azurecli
   kubectl edit configmap cilium-dynamic-metrics-config -n kube-system
   # Make any change and save - it should be reverted
   ```

2. **Delete the ConfigMap** (it should be recreated):

   ```azurecli
   kubectl delete configmap cilium-dynamic-metrics-config -n kube-system
   # Wait a few seconds and check if it's recreated
   kubectl get configmap cilium-dynamic-metrics-config -n kube-system
   ```

## Best practices

### Start with broad inclusion, then exclude

Begin by including all necessary metrics, then progressively exclude specific ones:

```yaml
spec:
  filters:
    - metric: flow
      excludeFilters:
        - from:
            namespacedPod: ["kube-system/*"]
        - to:
            namespacedPod: ["default/debug-*"]
```

### Use label selectors for flexibility

Leverage Kubernetes label selectors for flexible filtering:

```yaml
spec:
  filters:
    - metric: tcp
      includeFilters:
        - from:
            labelSelector:
              matchLabels:
                app: "frontend"
                environment: "production"
```

### Test in development environments

Always validate filtering configurations in development or staging:

```yaml
# Development environment - minimal metrics
spec:
  filters:
    - metric: dns
      includeFilters:
        - protocol: ["dns"]
    - metric: drop
      includeFilters:
        - reason: ["Policy denied"]
```

### Monitor filtering effectiveness

Regularly review filtered metrics to ensure important data isn't lost:

```azurecli
# Check that critical metrics are still available
kubectl port-forward -n kube-system svc/hubble-relay 4245:443 &
hubble observe --protocol dns --last 100
```

### Use single CRD per cluster

Remember that only one `ContainerNetworkMetric` CRD can exist per cluster:

```azurecli
# Check existing CRDs before creating new ones
kubectl get ContainerNetworkMetric
```

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

**Issue**: Cilium agents not in dynamic metrics mode

**Solution**: Verify Cilium configuration and restart if necessary:

```azurecli
# Check Cilium ConfigMap
kubectl get configmap cilium-config -n kube-system -o yaml | grep -A 10 "dynamic-metrics-config"

# Restart Cilium agents if needed
kubectl rollout restart daemonset/cilium -n kube-system
```

**Issue**: Metrics still showing after applying excludeFilters

**Solution**: Remember that pre-existing metrics persist in Prometheus. You may need to wait for new metrics to be generated to see the filtering effects.

### Cleanup and reset

To clean up filtering configuration:

```azurecli
# Delete the CRD (ConfigMap should reconcile to default)
kubectl delete ContainerNetworkMetric container-network-metric

# Verify ConfigMap reset to default
kubectl get configmap cilium-dynamic-metrics-config -n kube-system -o yaml
```

To completely reset the cluster:

```azurecli
# Delete the filtering CRD
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