---
title:  Block pod access to the IMDS endpoint (preview)
description: Learn how to enable IMDS restriction on an AKS cluster to restrict pod access to the IMDS endpoint (preview).
author: tamram

ms.topic: article
ms.custom: devx-track-azurecli
ms.date: 09/24/2024
ms.author: tamram
---

# Block pod access to the Azure Instance Metadata Service (IMDS) endpoint (preview)

[Azure Instance Metadata Service (IMDS)](/azure/virtual-machines/instance-metadata-service) is a REST API that provides information about currently running virtual machine instances. This information includes the SKU, storage, network configurations, and upcoming maintenance events. You can now restrict access to the IMDS endpoint from your AKS clusters to enhance security (preview).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## About IMDS restriction for AKS clusters

The IMDS REST API is available at a well-known, nonroutable IP address (169.254.169.254). By default, all pods running in an Azure Kubernetes Service (AKS) cluster can access the IMDS endpoint. The default behavior introduces certain security risks for an AKS cluster:

- Malicious users might exploit the service to obtain sensitive information such as tokens and other platform information, leading to information leakage.
- Potential authentication vulnerabilities are then exposed, because applications could misuse these credentials.

You can now opt to restrict access to the IMDS endpoint for non-host network pods running in your cluster. Non-host network pods have  `hostNetwork` set to **false** in their specs.

When IMDS restriction is enabled, non-host network pods are unable to access the IMDS endpoint or acquire OAuth 2.0 tokens for authorization by a managed identity. Non-host network pods should rely on [Microsoft Entra Workload ID][workload-identity-overview]  after IMDS restriction is enabled.

Host network pods have `hostNetwork` set to **true** in their specs. Host network pods and threads can continue to access the IMDS endpoint after IMDS restriction is enabled as they share the same network namespace with the host processes. Local processes in nodes might need to access the IMDS endpoint to retrieve instance metadata and therefore can still continue to access it after IMDS restriction is enabled.

## Before you begin

- Make sure you have Azure CLI version 2.61.0 or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Limitations

Non-host network addons that need to access the IMDS endpoint won't work after you enable IMDS restriction. Unsupported addons include:

- HTTPApplicationRouting (retired)
- IngressApplicationGateway
- OmsAgent
- ACIConnectorLinux
- AzurePolicy
- GitOps
- ExtensionManager
- AIToolchainOperator

The Azure Key Vault provider for Secrets Store Container Storage Interface (CSI) driver now supports workload identity authentication mode and therefore can work with IMDS restriction enabled.

## Enable IMDS restriction on a new cluster

To enable IMDS restriction on a new cluster and block all traffic from non-host network pods to the IMDS endpoint, call the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--imds-restriction` parameter set to `enabled`.

```azurecli-interactive
az aks create \
    –-resource-group myResourceGroup \
    -–name myAKSCluster \
    --imds-restriction enabled
```

## Enable IMDS restriction on an existing cluster

To enable IMDS restriction on an existing cluster and block all traffic from non-host network pods to the IMDS endpoint, call the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--imds-restriction` parameter set to `enabled`.

```azurecli-interactive
az aks update \
    -–resource-group myResourceGroup \
    -–name myAKSCluster \
    --imds-restriction enabled
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster to begin to block traffic to the cluster's pods.

## Verify the traffic on a cluster with IMDS restriction enabled

To verify that IMDS restriction is in effect, test traffic to both the non-host and host network pods.

### Verify the traffic on a non-host network pod

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
      - name: non-host-nw
        image: mcr.microsoft.com/azurelinux/base/nginx:1
        command: ["sleep", "infinity"]
    EOF
    ```

1. Connect to the shell in the pod with `kubectl exec`.

    ```bash
    kubectl exec -it non-host-nw -- /bin/bash
    ```

1. Install `curl` on the pod for the networking test.

    ```bash
    apt update && apt install curl
    ```

1. Test the traffic from the pod to the IMDS endpoint.

    ```bash
    curl -s -H Metadata:true --connect-timeout 10 --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Wait about 10 seconds and observe that the command doesn't return anything, which means that the connection has timed out and the pod is unable to access the IMDS endpoint.

After that, clean up the pod with `kubectl delete pod non-host-nw`.

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

1. Connect to the shell in the pod with `kubectl exec`.

    ```bash
    kubectl exec -it host-nw -- /bin/bash
    ```

1. Install `curl` on the pod for networking test

    ```bash
    apt update && apt install curl
    ```

1. Test the traffic from the pod to the IMDS endpoint

    ```bash
    curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Observe that the command returns the results, which means that the pod can access IMDS endpoints as expected.

After that, clean up the pod with `kubectl delete pod host-nw`.

## Disable IMDS restriction for a cluster

To disable IMDS restriction on an existing cluster and allow all traffic from any pods to the IMDS endpoint, call the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--imds-restriction` parameter set to `disabled`.

```azurecli-interactive
az aks update \
    –-resource-group myResourceGroup \
    –-name myAKSCluster \
    --imds-restriction disabled
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster to begin to allow all traffic to the cluster's pods.

## See also

[Azure Instance Metadata Service for virtual machines](/azure/virtual-machines/instance-metadata-service)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[node-image-upgrade]: node-image-upgrade.md
[workload-identity-overview]: workload-identity-overview.md
