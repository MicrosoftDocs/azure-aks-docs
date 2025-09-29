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

Kubernetes [sidecar containers][k8s-native-sidecar-support] aims to provide a more robust and user-friendly way to incorporate sidecar patterns into Kubernetes applications, improving efficiency, reliability, and simplicity.

Native sidecar is well-suited for Istio. It offers several benefits, including simplified sidecar management, improved reliability, and enhanced coordination. Native sidecar mode guarantees that the sidecar starts before the main application and gracefully shuts down after it, eliminating the need for complex manual workarounds for container lifecycle and Pod termination issues. It also optimizes resources and enhances operational efficiency.

Starting from Kubernetes version 1.29, [sidecar containers][k8s-native-sidecar-support] feature is turned on for AKS. With this change, [Istio native sidecar mode][istio-native-sidecar-support] can be used with the Istio add-on for AKS.

Native sidecar mode became the default for Istio [starting in version 1.27][istio-default-native-sidecar]. The Istio-based service mesh on AKS aligns with this behavior with minimal interruption for existing customers.

## Before you begin
Native sidecar is enabled by default for new Istio enablements if the cluster version is 1.33 or higher and the installed add-on revision is asm-1-27 or newer. Clusters outside this compatibility range do not have native sidecar enabled by default when installing the Istio add-on, and will not have native sidecar mode enabled upon upgrading to asm-1-27 unless explicitly turned on. Starting from asm-1-28, native sidecar mode will be the default for all Istio-enabled clusters. This means:
- Existing clusters with Istio add-on retain their current native sidecar status until upgrading their clusters to 1.33 and add-on to asm-1-28.
- Existing clusters with Istio add-on and the preview `IstioNativeSidecarModePreview` feature flag retain their current native sidecar status regardless of cluster version or Istio add-on revision
- Clusters enabling Istio add-on on cluster versions less than 1.33, or Istio add-on revisions older than asm-1-27 do not have native sidecar mode enabled by default. These clusters will not have native sidecar enabled by default until upgraded to asm-1-28 with cluster version 1.33 or higher.
- Clusters enabling Istio add-on on cluster version 1.33 or higher, and installing Istio add-on revision asm-1-27 or newer have native sidecar mode enabled by default.



## Installing Istio add-on on an existing cluster
For clusters installing the Istio add-on, native sidecar is enabled by default if the cluster version is 1.33 or higher and the installed add-on revision is asm-1-27 or newer.

1. Check that the AKS cluster's Kubernetes control plane version is 1.33 or higher using [az aks show][az-aks-show].

   ```bash
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER -o json | jq ".kubernetesVersion"
   ```

   If the control plane version is too old, [upgrade Kubernetes control plane][upgrade-aks-cluster].

2. Ensure node pools run version `1.33` or newer and the power state is running.

   ```bash
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER -o json | jq ".agentPoolProfiles[] | { currentOrchestratorVersion, powerState}"
   ```

   > [!CAUTION]
   > Native sidecar mode by default requires both Kubernetes control plane and data plane on version 1.33 or higher. Ensure all your nodes are version 1.33 or newer before enabling the service mesh add-on. Otherwise, native sidecar will not be enabled by default.

   If any node pool version is too old, [upgrade the node image][upgrade-node-image] to version `1.33` or newer.

3. Install Istio add-on revision `asm-1-27` or newer. Use the `az aks mesh get-revisions` command to check which revisions are available for different AKS cluster versions in a region. Based on the available revisions, include the `--revision asm-X-Y` (ex: `--revision asm-1-27`) flag in the enable command for mesh installation.



### Check native sidecar feature status on Istio control plane

The AKS cluster needs to be reconciled with the [az aks update][az-aks-update] command.

```bash
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER
```

When native sidecar mode is enabled, environment variable `ENABLE_NATIVE_SIDECARS` appears with value `true` in Istio's control plane pod template. Use the following command to check `istiod` deployment.

```bash
kubectl get deployment -l app=istiod -n aks-istio-system -o json | jq '.items[].spec.template.spec.containers[].env[] | select(.name=="ENABLE_NATIVE_SIDECARS")'
```

### Check sidecar injection

If native sidecar mode is successfully enabled, the `istio-proxy` container is shown as an init container. Use the following command to check sidecar injection:

```bash
kubectl get pods -o "custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
```

The `istio-proxy` container should be shown as an init container.

```bash
NAME                     INIT                     CONTAINERS
sleep-7656cf8794-5b5j4   istio-init,istio-proxy   sleep
```

## Create a new cluster

When creating a new AKS cluster with the [az aks create][az-aks-create] command, choose version `1.33` or newer and Istio `asm-1-27` or newer. The new cluster will have native sidecar mode enabled automatically.

```bash
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER \
    --enable-asm \
    --kubernetes-version 1.33 \
    --revision asm-1-27 \
    --generate-ssh-keys    
    ...
```

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
