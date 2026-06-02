---
title: "Deploy Cilium mTLS encryption with Advanced Container Networking Services"
description: Get started with Cilium mTLS encryption for Advanced Container Networking Services on your AKS cluster.
author: josephyostos
ms.author: josephyostos
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 03/16/2026
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Deploy Cilium mTLS encryption with Advanced Container Networking Services (Preview)

> [!IMPORTANT]
> Cilium mTLS encryption with Advanced Cluster Networking Services is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

This article shows you how to deploy Cilium mTLS encryption with Advanced Container Networking Services in Azure Kubernetes Service (AKS) clusters.

## Prerequisites

- An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- The minimum version of Azure CLI required for the steps in this article is 2.71.0. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

- Cilium mTLS encryption is only supported with the Azure CNI powered by Cilium. If you're using any other network plugin, Cilium mTLS encryption isn't supported. See [Configure Azure CNI Powered by Cilium](/azure/aks/azure-cni-powered-by-cilium).

- Ensure your AKS cluster is running Kubernetes version 1.34.0 or later.

- Ensure your cluster is using Cilium version 1.18 or later.

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command.

The minimum version of the aks-preview Azure CLI extension is `14.0.0b6`.

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingmTLSPreview` feature flag

Register the `AdvancedNetworkingmTLSPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingmTLSPreview"
```

Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingmTLSPreview"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

## Enable Advanced Container Networking Services and mTLS encryption

To proceed, you must have an AKS cluster with [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:

* **Container Network Observability:** Provides insights into your network traffic. To learn more, visit [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability).

* **Container Network Security:** Offers security features like Fully Qualified Domain Name (FQDN) filtering, L7 Policy, and in-transit encryption. To learn more, visit [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security).

> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability and Container Network Security starting with Kubernetes version 1.29.

> [!NOTE]
> Cilium mTLS encryption is disabled by default even after enabling ACNS. To enable mTLS, set the encryption type by using the flag `--acns-transit-encryption-type mTLS`.

```azurecli-interactive
# Set environment variables for the AKS cluster name and resource group. Make sure to replace the placeholders with your own values.
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<resourcegroup-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location eastus \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --enable-acns \
    --acns-transit-encryption-type mTLS \
    --generate-ssh-keys
```

## Enable Advanced Container Networking Services and mTLS encryption on an existing cluster

The [`az aks update`](/cli/azure/aks#az-aks-update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features, which includes [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability) and the [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security) feature.

> [!IMPORTANT]
> Enabling mTLS encryption on an existing cluster triggers a rollout restart of the Cilium agent across all nodes. For large clusters, this process can take some time and might temporarily impact workloads. Plan the update during a maintenance window or low-traffic period to minimize disruption.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-transit-encryption-type mTLS
```

## Get cluster credentials

Get your cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

```azurecli-interactive
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Enroll a namespace

To enroll an application in mTLS, apply the mTLS label to the namespace that contains the application pods.

```bash
kubectl label namespace <namespace-name> io.cilium/mtls-enabled=true
```

Traffic between enrolled and non‑enrolled workloads continues in plaintext without causing connectivity issues or hard failures.

## Verify mTLS is enabled

After enrolling a namespace for Cilium mTLS, you can verify that authentication and encryption are active using the following methods.

1. Check that ztunnel has been enabled:
   ```bash
   kubectl -n kube-system describe cm cilium-config | grep enable-ztunnel -A2
   ```
   You should see output indicating that ztunnel encryption is enabled.

2. Check which namespaces are enrolled:
   ```bash
   kubectl get namespaces -l io.cilium/mtls-enabled=true
   ```
   This shows all namespaces labeled for ztunnel enrollment.

   To verify that these namespaces are actually enrolled in the StateDB table:
   ```bash
   kubectl exec -n kube-system ds/cilium -- cilium-dbg statedb dump | jq '.["mtls-enrolled-namespaces"]'
   ```
   The results of this query should show which namespaces have been successfully processed by the enrollment reconciler.

3. Verify pods are enrolled in SPIRE

   Exec into the SPIRE Server container and list entries:

   ```bash
   kubectl exec -n kube-system spire-server-0 -c spire-server -- \
   /opt/spire/bin/spire-server entry show
   ```

   This command queries the SPIRE Server datastore and prints all registered workload identities.

   Look for entries matching the SPIFFE format:

   ```
   spiffe://<trust-domain>/ns/<namespace>/sa/<serviceaccount>
   ```

4. Verify pod enrollment in ztunnel

   Ztunnel exposes a local admin endpoint that allows inspecting its active configuration, including enrolled workloads.

   Select a ztunnel pod.

   ```bash
   kubectl get pods -n kube-system \
   -l app.kubernetes.io/name=ztunnel-cilium \
   -o wide
   ```

   Port-forward the ztunnel admin endpoint. ztunnel exposes an admin API on port 15000 (localhost-only by default).

   ```bash
   kubectl port-forward -n kube-system <ZTUNNEL_POD> 15000:15000
   ```

   Inspect the ztunnel configuration dump.

   ```bash
   curl -s http://localhost:15000/config_dump | jq
   ```

   Verify your pod is registered. Search the config dump for your workload's SPIFFE identity or namespace/service account. You should see entries like the following output:

```json
"workloads": [
    {
    "capacity": 1,
    "clusterId": "Kubernetes",
    "name": "test-server-5dc49df4cf-grr2f",
    "namespace": "ztunnel-test-enrolled",
    "networkMode": "Standard",
    "node": "10.224.0.5",
    "protocol": "HBONE",
    "serviceAccount": "default",
    "status": "Healthy",
    "trustDomain": "cluster.local",
    "uid": "30f37433-a83f-4e30-9946-f62cf5d10924",
    "workloadIps": [
        "192.168.0.50"
    ],
    "workloadType": "deployment"
    }
]
```

## Disable mTLS on an existing cluster

It's recommended to disenroll namespaces from mTLS before disabling it.

```bash
kubectl label namespace <namespace-name> io.cilium/mtls-enabled-
```

mTLS encryption can be disabled independently without affecting other ACNS features. To disable it, set the flag `--acns-transit-encryption-type` to `none`.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-transit-encryption-type none
```
