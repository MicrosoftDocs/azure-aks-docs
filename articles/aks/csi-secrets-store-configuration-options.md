---
title: Azure Key Vault provider for Secrets Store CSI Driver for AKS configuration and troubleshooting options
description: Learn configuration and troubleshooting options for the Azure Key Vault provider for Secrets Store CSI Driver in Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.subservice: aks-security
ms.topic: how-to
ms.date: 12/10/2025
ms.custom: devx-track-azurecli
# Customer intent: As a Kubernetes administrator, I want to configure and troubleshoot the Azure Key Vault provider for the Secrets Store CSI Driver in AKS, so that I can securely manage and automate the handling of secrets in my Kubernetes environment.
---

# Azure Key Vault provider for Secrets Store CSI Driver for AKS configuration and troubleshooting options

The Azure Key Vault provider for Secrets Store Container Storage Interface (CSI) Driver enables secure and automated management of secrets in Azure Kubernetes Service (AKS). This article provides guidance on configuring the provider, troubleshooting common issues, and optimizing secret handling in your AKS environment.

## Prerequisites

Follow the steps in the following articles before proceeding with this guide. Once you complete these steps, you can apply extra configurations or perform troubleshooting on your AKS cluster.

* [Use the Azure Key Vault provider for Secrets Store CSI Driver in an AKS cluster](./csi-secrets-store-driver.md)

* [Provide an identity to access the Azure Key Vault provider for Secrets Store CSI Driver in AKS](./csi-secrets-store-identity-access.md)

## Configuration options

### Manage auto rotation

Once you enable auto rotation for Azure Key Vault Secrets Provider, it updates the pod mount and the Kubernetes secret defined in the `secretObjects` field of `SecretProviderClass`. It does so by polling for changes periodically, based on the rotation poll interval you defined. The default rotation poll interval is *two minutes*. When a secret is updated in the external secrets store after the initial pod deployment, both the Kubernetes Secret and the pod mount are periodically refreshed. The update frequency and method depend on how your application accesses the secret data.

* **Mount the Kubernetes Secret as a volume**: Use the auto rotation and sync K8s secrets features of Secrets Store CSI Driver. The application needs to watch for changes from the mounted Kubernetes Secret volume. When the CSI Driver updates the Kubernetes Secret, the corresponding volume contents automatically update as well.

* **Application reads the data from the container filesystem**: Use the rotation feature of Secrets Store CSI Driver. The application needs to watch for the file change from the volume mounted by the CSI driver.

* **Use the Kubernetes Secret for an environment variable**: Restart the pod to get the latest secret as an environment variable. Use a tool such as [Reloader][reloader] to watch for changes on the synced Kubernetes Secret and perform rolling upgrades on pods.

# [Enable](#tab/enable)

1. To enable auto rotation of secrets on a new AKS cluster using the [`az aks create`][az-aks-create] command and enable the `enable-secret-rotation` add-on, run the following command:

    ```azurecli-interactive
    az aks create \
        --name myAKSCluster2 \
        --resource-group myResourceGroup \
        --enable-addons azure-keyvault-secrets-provider \
        --enable-secret-rotation \
        --generate-ssh-keys
    ```

1. To update an existing AKS cluster to enable auto rotation of secrets using the [`az aks addon update`][az-aks-addon-update] command and the `enable-secret-rotation` parameter, run the following command:

   ```azurecli-interactive
   az aks addon update --resource-group myResourceGroup --name myAKSCluster2 --addon azure-keyvault-secrets-provider --enable-secret-rotation
   ```

# [Disable](#tab/disable)

To disable auto rotation, you first need to disable the add-on. Then, you can re-enable the add-on without the `enable-secret-rotation` parameter.

1. Disable the secrets provider add-on using the [`az aks addon disable`][az-aks-addon-disable]
   command:

   ```azurecli-interactive
   az aks addon disable --resource-group myResourceGroup --name myAKSCluster2 --addon azure-keyvault-secrets-provider
   ```

1. Re-enable the secrets provider add-on without the `enable-secret-rotation` parameter using the
   [`az aks addon enable`][az-aks-addon-enable] command:

   ```azurecli-interactive
   az aks addon enable --resource-group myResourceGroup --name myAKSCluster2 --addon azure-keyvault-secrets-provider
   ```

If you're already using a `SecretProviderClass`, you can update the add-on without disabling it first by using `az aks addon enable` without specifying the `enable-secret-rotation` parameter.

# [Custom](#tab/custom)

To specify a custom rotation interval using the [`az aks addon update`][az-aks-addon-update] command with the `rotation-poll-interval` parameter, run the following command:

   ```azurecli-interactive
   az aks addon update --resource-group myResourceGroup --name myAKSCluster2 --addon azure-keyvault-secrets-provider --enable-secret-rotation --rotation-poll-interval 5m
   ```

---

### Sync mounted content with a Kubernetes secret

> [!NOTE]
> The YAML examples in this section are incomplete. You need to modify them to support your chosen method of access to your key vault identity. For details, see [Provide an identity to access the Azure Key Vault provider for Secrets Store CSI Driver][identity-access-methods].

You might want to create a Kubernetes secret to mirror your mounted secrets content. Your secrets sync after you start a pod to mount them. When you delete the pods that consume the secrets, your Kubernetes secret is also deleted.

Sync mounted content with a Kubernetes secret using the `secretObjects` field when creating a `SecretProviderClass` to define the desired state of the Kubernetes secret, as shown in the
following example YAML. Make sure the `objectName` in the `secretObjects` field matches the file name of the mounted content. If you use `objectAlias` instead, it should match the object alias.

```yml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-sync
spec:
  provider: azure
  secretObjects:             # [OPTIONAL] SecretObjects defines the desired state of synced Kubernetes secret objects
  - data:
    - key: username          # data field to populate
      objectName: foo1       # name of the mounted content to sync; this could be the object name or the object alias
    secretName: foosecret    # name of the Kubernetes secret object
    type: Opaque             # type of Kubernetes secret object (for example, Opaque, kubernetes.io/tls)
```

### Set an environment variable to reference Kubernetes secrets

> [!NOTE]
> The example YAML demonstrates how to access a secret using either environment variables or `volume/volumeMount`. Typically, an application uses one method or the other. However, to make a secret available through environment variables, at least one pod must mount the secret.

Reference your newly created Kubernetes secret by setting an environment variable in your pod, as shown in the following example YAML.

```yml
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline
spec:
  containers:
    - name: busybox
      image: registry.k8s.io/e2e-test-images/busybox:1.29-1
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
      env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: foosecret
            key: username
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-sync"
```

### Migrate from open-source to AKS-managed Secrets Store CSI Driver

1. Uninstall the open-source Secrets Store CSI Driver using the following `helm delete` command:

   ```bash
   helm delete <release name>
   ```

   > [!TIP]
   > If you installed the driver and provider using deployment YAMLs, you can delete the components using the following `kubectl delete` command:
   >
   > ```bash # Delete AKV provider pods from Linux nodes kubectl delete -f
   > https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/provider-azure-installer.yaml
   >
   > # Delete AKV provider pods from Windows nodes kubectl delete -f
   > https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/provider-azure-installer-windows.yaml
   > ```

1. Upgrade your existing AKS cluster with the feature using the
   [`az aks enable-addons`][az-aks-enable-addons] command:

   ```azurecli-interactive
   az aks enable-addons --addons azure-keyvault-secrets-provider --name myAKSCluster --resource-group myResourceGroup
   ```

## Access metrics

# [Azure Key Vault](#tab/akvp)

You can monitor the health and performance of the Azure Key Vault provider for Secrets Store CSI Driver by collecting metrics it exposes. These metrics provide insights into request durations, error rates, and the overall operation of the provider and driver components, helping you troubleshoot issues and optimize your AKS cluster's secret management.

Metrics are served via Prometheus from port 8898, but this port isn't exposed outside the pod by default. Access the metrics over localhost using the `kubectl port-forward` command:

```bash
kubectl port-forward -n kube-system ds/aks-secrets-store-provider-azure 8898:8898 & curl localhost:8898/metrics
```

These metrics help you monitor the performance and reliability of the Azure Key Vault provider including request latency and error tracking for both Key Vault and gRPC operations.

|Metric|Description|Tags|
|----|----|----|
|keyvault_request|The distribution of how long it took to get from the key vault.|`os_type=<runtime os>`, `provider=azure`, `object_name=<keyvault object name>`, `object_type=<keyvault object type>`, `error=<error if failed>`|
|grpc_request|The distribution of how long it took for the gRPC requests.|`os_type=<runtime os>`, `provider=azure`, `grpc_method=<rpc full method>`, `grpc_code=<grpc status code>`, `grpc_message=<grpc status message>`|

# [Secret Store CSI Driver](#tab/sscsi)

Metrics are served from port 8095, but this port isn't exposed outside the pod by default. Access the metrics over localhost using the `kubectl port-forward` command:

```bash
kubectl port-forward -n kube-system ds/aks-secrets-store-csi-driver 8095:8095 & curl localhost:8095/metrics
```

These metrics provide visibility into the internal operations of the CSI driver such as volume mount and unmount requests, secret synchronization, and rotation activities.

|Metric|Description|Tags|
|----|----|----|
|total_node_publish|The total number of successful volume mount requests.|`os_type=<runtime os>`, `provider=<provider name>`|
|total_node_unpublish|The total number of successful volume unmount requests.|`os_type=<runtime os>`|
|total_node_publish_error|The total number of errors with volume mount requests.|`os_type=<runtime os>`, `provider=<provider name>`, `error_type=<error code>`|
|total_node_unpublish_error|The total number of errors with volume unmount requests.|`os_type=<runtime os>`|
|total_sync_k8s_secret|The total number of Kubernetes secrets synced.|`os_type=<runtime os`, `provider=<provider name>`|
|sync_k8s_secret_duration_sec|The distribution of how long it took to sync the Kubernetes secret.|`os_type=<runtime os>`|
|total_rotation_reconcile|The total number of volume rotation reconcile operations.|`os_type=<runtime os>`, `rotated=<true or false>`|
|total_rotation_reconcile_error|The total number of reconcile operations that resulted in errors.|`os_type=<runtime os>`, `rotated=<true or false>`, `error_type=<error code>`|
|rotation_reconcile_duration_sec|The distribution of how long it took to rotate secrets-store content for pods.|`os_type=<runtime os>`|

---

## Troubleshooting

For troubleshooting steps, see [Troubleshoot Azure Key Vault Provider for Secrets Store CSI Driver][troubleshoot-csi].

## Next steps

To learn more about the Azure Key Vault provider for Secrets Store CSI Driver, see the following resources:

* [Using the Azure Key Vault provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/)

* [Upgrading the Azure Key Vault provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/upgrading/)

* [Using Secrets Store CSI with AKS and Azure Key Vault](https://github.com/Azure-Samples/secrets-store-csi-with-aks-akv)

<!-- LINKS INTERNAL -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[identity-access-methods]: ./csi-secrets-store-identity-access.md
[az-aks-addon-update]: /cli/azure/aks#az-aks-addon-update
[az-aks-addon-disable]: /cli/azure/aks#az-aks-addon-disable
[az-aks-addon-enable]: /cli/azure/aks#az-aks-addon-enable
[troubleshoot-csi]: /troubleshoot/azure/azure-kubernetes/troubleshoot-key-vault-csi-secrets-store-csi-driver

<!-- LINKS EXTERNAL -->
[reloader]: https://github.com/stakater/Reloader
