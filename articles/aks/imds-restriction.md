---
title:  Block pod access to the IMDS endpoint (preview)
description: Learn how to enable IMDS restriction on an AKS cluster to restrict pod access to the IMDS endpoint (preview).
author: charleswool

ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 10/23/2024
ms.author: yuewu2
---

# Block pod access to the Azure Instance Metadata Service (IMDS) endpoint (preview)

By default, all pods running in an Azure Kubernetes Service (AKS) cluster can access the [Azure Instance Metadata Service (IMDS)](/azure/virtual-machines/instance-metadata-service) endpoint. You can now optionally restrict access to the IMDS endpoint from your Azure Kubernetes Service (AKS) clusters to enhance security (preview).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## About IMDS restriction for AKS clusters

Azure IMDS is a REST API that provides information about currently running virtual machine instances. This information includes the SKU, storage, network configurations, and upcoming maintenance events.

The IMDS REST API is available at a well-known, nonroutable IP address (169.254.169.254) that is by default accessible from all pods running in an AKS cluster. This default access introduces certain security risks for an AKS cluster:

- Malicious users might exploit the service to obtain sensitive information such as tokens and other platform information, leading to information leakage.
- Potential authentication vulnerabilities are then exposed, because applications could misuse these credentials.

You can now opt to restrict access to the IMDS endpoint for non host network pods running in your cluster. Non host network pods have  `hostNetwork` set to **false** in their specs. When IMDS restriction is enabled, non host network pods are unable to access the IMDS endpoint or acquire OAuth 2.0 tokens for authorization by a managed identity. Non host network pods should rely on [Microsoft Entra Workload ID][workload-identity-overview] after IMDS restriction is enabled.

Host network pods have `hostNetwork` set to **true** in their specs. Host network pods can continue to access the IMDS endpoint after IMDS restriction is enabled as they share the same network namespace with the host processes. Local processes in nodes can use the IMDS endpoint to retrieve instance metadata, so they're permitted to access the endpoint after the IMDS restriction is enabled.

## Before you begin

1. Make sure you have Azure CLI version 2.61.0 or later installed. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

1. Install the `aks-preview` Azure CLI extension version 7.0.0b2 or later.

    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command.

        ```azurecli-interactive
        az extension add --name aks-preview
        ```

    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command.

        ```azurecli-interactive
        az extension update --name aks-preview
        ```

1. Register the `IMDSRestrictionPreview` feature flag using the [az feature register][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name IMDSRestrictionPreview
    ```

    Verify the registration status by using the [az feature show][az-feature-show] command. It takes a few minutes for the status to show *Registered*:

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name IMDSRestrictionPreview
    ```

    When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register][az-provider-register] command:

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Limitations

Certain add-ons that need to access the IMDS endpoint aren't supported with IMDS restriction. If you have these add-ons installed on your cluster, you can't enable IMDS restriction. Conversely, if IMDS restriction is enabled, then you can't install these add-ons. Unsupported addons include:

- Application gateway ingress controller
- Azure Monitor for containers (Container Insights)
- Virtual nodes
- Azure Policy
- Cluster extensions: Flux (GitOps), Dapr, Azure App Configuration, Azure Machine Learning, Azure Container Storage, Azure Backup 
- AI toolchain operator (preview)
- Application routing
- HTTP application routing
- Azure cost analysis 

Additionally, Windows node pools aren't currently supported with IDMS restriction.

The Azure Key Vault provider for Secrets Store Container Storage Interface (CSI) driver now supports workload identity authentication mode and therefore can work with IMDS restriction enabled.

> [!CAUTION]
> Enabling IMDS restrictions for a cluster that uses unsupported add-ons results in an error.

## Important considerations

When IMDS restriction is enabled, AKS manages the iptables rules on the node. Keep in mind the following points to prevent the iptables rules from being accidentally removed or tampered with:

- iptables rules can be modified with SSH or node-shell, so we recommend using [Disable SSH][disable-ssh] or using a policy to disable privileged pods.
- The iptables rules that restrict access to IMDS are restored when the node is [reimaged][node-image-upgrade] or restarted.

## Enable IMDS restriction on a new cluster

To enable IMDS restriction on a new cluster and block all traffic from non host network pods to the IMDS endpoint, run the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--enable-imds-restriction` parameter.

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --enable-imds-restriction
```

## Enable IMDS restriction on an existing cluster

To enable IMDS restriction on an existing cluster and block all traffic from non host network pods to the IMDS endpoint, run the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-imds-restriction` parameter.

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --enable-imds-restriction
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster with `az aks upgrade --node-image-only` to begin to block traffic to the cluster's pods.

## Verify the traffic on a cluster with IMDS restriction enabled

To verify that IMDS restriction is in effect, test traffic to both the non host and host network pods.

### Verify the traffic on a non host network pod

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

1. Test the traffic from the pod to the IMDS endpoint.

    ```bash
    curl -s -H Metadata:true --connect-timeout 10 --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Wait about 10 seconds and observe that the command doesn't return anything, which means that the connection timed out and the pod is unable to access the IMDS endpoint.

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
      - name: host-nw
        image: mcr.microsoft.com/azurelinux/base/nginx:1
        command: ["sleep", "infinity"]
    EOF
    ```

1. Connect to the shell in the pod with `kubectl exec`.

    ```bash
    kubectl exec -it host-nw -- /bin/bash
    ```

1. Test the traffic from the pod to the IMDS endpoint

    ```bash
    curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2023-11-15" 
    ```

Observe that the command returns the results, which means that the pod can access IMDS endpoints as expected.

After that, clean up the pod with `kubectl delete pod host-nw`.

## Disable IMDS restriction for a cluster

To disable IMDS restriction on an existing cluster and allow all traffic from any pods to the IMDS endpoint, run the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-imds-restriction` parameter.

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --disable-imds-restriction
```

After you update the cluster, you must [reimage][node-image-upgrade] the nodes in your cluster to begin to allow all traffic to the cluster's pods.

## See also

[Azure Instance Metadata Service for virtual machines](/azure/virtual-machines/instance-metadata-service)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-feature-show]: /cli/azure/feature#az_feature_show
[az-provider-register]: /cli/azure/provider#az_provider_register
[node-image-upgrade]: node-image-upgrade.md
[workload-identity-overview]: workload-identity-overview.md
[disable-ssh]: manage-ssh-node-access.md
