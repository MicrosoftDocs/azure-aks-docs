---
title: Enable native sidecar mode for Istio-based service mesh add-on in Azure Kubernetes Service (AKS) (preview)
description: Enable native sidecar mode for Istio-based service mesh add-on in Azure Kubernetes Service (AKS) (preview).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 05/07/2024
ms.author: fuyuanbie
author: biefy
---

# Native sidecar mode for Istio-based service mesh add-on in Azure Kubernetes Service (AKS)

Kubernetes [sidecar containers][k8s-native-sidecar-support] feature aims to provide a more robust and user-friendly way to incorporate sidecar patterns into Kubernetes applications, improving efficiency, reliability, and simplicity.

Native sidecar is well-suited for Istio. It offers several benefits, including simplified sidecar management, improved reliability, and enhanced coordination. Native sidecar mode guarantees that the sidecar starts before the main application and gracefully shuts down after it, eliminating the need for complex manual workarounds for container lifecycle and Pod termination issues. It also optimizes resources and enhances operational efficiency.

Starting from Kubernetes version 1.29, [sidecar containers][k8s-native-sidecar-support] feature is turned on for AKS. With this change, [Istio native sidecar mode][istio-native-sidecar-support] can be used with the Istio add-on for AKS.

Native sidecar mode became the default for Istio [starting in version 1.27][istio-default-native-sidecar]. The Istio-based service mesh on AKS aligns with this behavior with minimal interruption for existing customers.

## Default behavior
Existing clusters with Istio add-on using the preview `IstioNativeSidecarModePreview` feature flag retain their current native sidecar status regardless of cluster version or Istio add-on revision.

Starting with AKS 1.33 and Istio add-on `asm-1-28`, AKS service mesh add-on uses native sidecar by default for the Envoy proxy. Whether this setting applies depends on your cluster version, ASM add-on revision, and whether the add-on was newly installed or upgraded.

| AKS Version       | ASM Version       | Add-on Install Behavior                 | Upgrade Behavior                               |
|-------------------|-------------------|--------------------------------------|------------------------------------------------|
| < 1.33            | Any              | Disabled                             | Disabled                                       |
| 1.33+             | < `asm-1-27`       | Disabled                             | Disabled                                       |
| 1.33+             | `asm-1-27`         | Enabled (transition release)         | Disabled (upgrade does not auto-enable)       |
| 1.33+             | `asm-1-28`+        | Enabled                              | Enabled (by mesh or cluster upgrade to required versions)         |


# New clusters
When creating a new AKS cluster with the [az aks create][az-aks-create] command, choose version `1.33` or newer and Istio `asm-1-27` or newer. The new cluster will have native sidecar mode enabled automatically.

```azurecli-interactive
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER \
    --enable-asm \
    --kubernetes-version 1.33 \
    --revision asm-1-27 \
    --generate-ssh-keys    
    ...
```

For a new service mesh installation on an existing cluster >= version AKS 1.33, select `asm-1-27` or newer during [installation][install-istio-addon].


# Existing clusters
This section describes how to check native sidecar feature status or enable it on an existing.

## Check feature status

The AKS cluster needs to be reconciled with the [az aks update][az-aks-update] command.

```az
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER
```

When native sidecar mode is enabled, environment variable `ENABLE_NATIVE_SIDECARS` appears with value `true` in Istio's control plane pod template. Use the following command to check `istiod` deployment.

```azurecli-interactive
kubectl get deployment -l app=istiod -n aks-istio-system -o json | jq '.items[].spec.template.spec.containers[].env[] | select(.name=="ENABLE_NATIVE_SIDECARS")'
```

If native sidecar mode is successfully enabled, the `istio-proxy` container is shown as an init container. Use the following command to check sidecar injection:

```bash
kubectl get pods -o "custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
```

The `istio-proxy` container should be shown as an init container.

```bash
NAME                     INIT                     CONTAINERS
sleep-7656cf8794-5b5j4   istio-init,istio-proxy   sleep
```

## Check prerequisites
If native sidecar is not enabled, it is likely one of the version prerequisites have not been met.

1. Check that the AKS cluster's Kubernetes control plane version is 1.33 or higher using [az aks show][az-aks-show].

   ```azurecli-interactive
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query "kubernetesVersion" -o tsv
   ```

   If the control plane version is too old, you can [upgrade Kubernetes control plane][upgrade-aks-cluster].

1. Ensure node pools run version `1.33` or newer and the power state is running.

   ```azurecli-interactive
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER -o json | jq ".agentPoolProfiles[] | { currentOrchestratorVersion, powerState}"
   ```

   > [!CAUTION]
   > Native sidecar mode by default requires both Kubernetes control plane and data plane on version 1.33 or higher. Ensure all your nodes are version 1.33 or newer before enabling the service mesh add-on. Otherwise, native sidecar will not be enabled by default.

   If any node pool version is too old, [upgrade the node image][upgrade-node-image] to version `1.33` or newer.

1. If service mesh-addon is enabled, check the installed revision:
   
   ```azurecli-interactive
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query "serviceMeshProfile.istio.revisions" -o tsv
   ```
   
   To upgrade into native sidecar support, [upgrade your mesh][upgrade-istio] revision to `asm-1-28` or above.
    

## Next steps

* [Deploy external or internal ingresses for Istio service mesh add-on][istio-deploy-ingress].

<!--- External Links --->
[istio-native-sidecar-support]: https://istio.io/latest/blog/2023/native-sidecars/
[istioctl-kube-inject]: https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-kube-inject
[k8s-native-sidecar-support]: https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/
[istio-default-native-sidecar]: https://istio.io/latest/news/releases/1.27.x/announcing-1.27/change-notes/#installation

<!--- Internal Links --->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-show]: /cli/azure/aks#az_aks_show
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[istio-deploy-ingress]: ./istio-deploy-ingress.md
[istio-upgrade]: ./istio-upgrade.md
[upgrade-aks-cluster]: ./upgrade-aks-cluster.md
[upgrade-node-image]: ./node-image-upgrade.md
[upgrade-istio]: ./istio-upgrade.md
[install-istio-addon]: ./istio-deploy-addon.md