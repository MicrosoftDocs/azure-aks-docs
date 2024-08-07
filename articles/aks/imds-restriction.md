---
title: Block traffic from a cluster to the IMDS endpoint (preview)
description: Learn how to enable IDMS restriction on an AKS cluster to block traffic to the IMDS endpoint (preview).
author: tamram

ms.topic: article
ms.custom: devx-track-azurecli
ms.date: 08/07/2024
ms.author: tamram
---

# Block traffic from a cluster to the IMDS endpoint (preview)

[Azure Instance Metadata Service (IMDS)](../virtual-machines/instance-metadata-service.md) is a REST API that's available at a well-known, nonroutable IP address (169.254.169.254). IMDS provides information about currently running virtual machine instances. This information includes the SKU, storage, network configurations, and upcoming maintenance events.

By default, all pods running in an Azure Kubernetes Service (AKS) cluster can access the IMDS endpoints. The default behavior introduces certain security risks for an AKS cluster. You can now opt to restrict access to the IMDS endpoint for non host-network pods running in your cluster.

When IMDS restriction (preview) is enabled, nonhost network pods are unable to access IMDS endpoints. Nonhost network pods also cannot acquire OAuth 2.0 tokens for authorization by a managed identity after IMDS restriction is enabled, and should rely on [Microsoft Entra Workload ID][workload-identity-overview] instead. Host network pods and threads can continue to access the IMDS endpoints after IMDS restriction is enabled.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- Make sure you have Azure CLI version x.y.z or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Enable IMDS restriction on a new cluster

To enable IMDS restriction on a new cluster and block all traffic from non host-network pods to the IMDS endpoint, call the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--imds-restriction` parameter set to `enabled`.

```azurecli-interactive
az aks create \
    –-resource-group myResourceGroup \
    -–name myAKSCluster \
    --imds-restriction enabled
```

## Enable IMDS restriction on an existing cluster

To enable IMDS restriction on an existing cluster and block all traffic from nonhost network pods to the IMDS endpoint, call the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--imds-restriction` parameter set to `enabled`.

```azurecli-interactive
az aks update \
    -–resource-group myResourceGroup \
    -–name myAKSCluster \
    --imds-restriction enabled
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster to begin to block traffic to the cluster's pods.

## Verify the traffic on a cluster with IMDS restriction enabled

To verify that IMDS restriction is in effect, test traffic to both the nonhost and host network pods.

### Verify the traffic on a nonhost network pod

1. Create a pod with `hostNetwork: false`. If you don't have a test pod with `hostNetwork: false`, you can run the following command to create one.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
         name: non-host-nw
    spec:
      hostNetwork: false
      containers:
      - name: ubuntu-container
        image: ubuntu:latest
        command: ["sleep", "infinity"]
    EOF
    ```

1. Sign in to the pod with `kubectl exec`.

    ```bash
    kubectl exec -it non-host-nw -- /bin/bash
    ```

1. Install `curl` on the pod for the networking test.

    ```bash
    apt update && apt install curl
    ```

1. Test the traffic from the pod to the IMDS endpoints.

    ```bash
    curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Wait about two minutes and observe that that command doesn't return anything, which means that the connection has timed out and the pod can't access the IMDS endpoint.

### Verify the traffic on a host network pod

1. Create a pod with `hostNetwork: true`. If you don't have a test pod with `hostNetwork: true`, you can run the following command to create one.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: host-nw
    spec:
      hostNetwork: true
      containers:
      - name: ubuntu-container
        image: ubuntu:latest
        command: ["sleep", "infinity"]
    EOF
    ```

1. Sign in to the pod with `kubectl exec`.

    ```bash
    kubectl exec -it host-nw -- /bin/bash
    ```

1. Install `curl` on the pod for networking test

    ```bash
    apt update && apt install curl
    ```

1. Test the traffic from the pod to IMDS endpoints

    ```bash
    curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Observe that the command returns the results, which means that the pod can access IMDS endpoints.

## Disable IMDS restriction for a cluster

To disable IMDS restriction on an existing cluster and allow all traffic from any pods to the IMDS endpoint, call the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--imds-restriction` parameter set to `disabled`.

```azurecli-interactive
az aks update \
    –-resource-group myResourceGroup \
    –-name myAKSCluster \
    --imds-restriction disabled
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster to begin to allow all traffic to the cluster's pods.

## Limitations

Nonhost network addons that need to access IMDS endpoints will not work after you enable IMDS restriction. Unsupported addons include:

- HTTPApplicationRouting
- IngressApplicationGateway
- OmsAgent
- ACIConnectorLinux
- AzurePolicy
- GitOps
- ExtensionManager
- AIToolchainOperator

Azure Key Vault provider for Secrets Store CSI driver now supports workload identity authentication mode and therefore can work with IMDS restriction enabled.

## See also

[Azure Instance Metadata Service for virtual machines](../virtual-machines/instance-metadata-service.md)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[node-image-upgrade]: node-image-upgrade.md
[workload-identity-overview]: workload-identity-overview.md
