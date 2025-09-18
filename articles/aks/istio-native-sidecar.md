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

Kubernetes native sidecar aims to provide a more robust and user-friendly way to incorporate sidecar patterns into Kubernetes applications, improving efficiency, reliability, and simplicity.

Native sidecar is a good fit for Istio. It offers several benefits, such as simplified sidecar management. Additionally, it improves reliability and coordination. It also optimizes resources and enhances operational efficiency.

Starting from Kubernetes version 1.29, [sidecar containers][k8s-native-sidecar-support] feature is turned on for AKS. With this change, [Istio native sidecar mode][istio-native-sidecar-support] can be used with the Istio add-on for AKS.

Native sidecar mode became the default for Istio [starting in version 1.27][[istio-default-native-sidecar]]. Istio based service mesh on AKS will align with this behavior while ensuring minimal interuptiions for existing customers.

## Before you begin
Native sidecar will only be enabled by default for new Istio enablements if the cluster version is 1.33 or higher and the installed addon revision is asm-1-27 or newer. Clusters outside this compatibility range will not have native sidecar enabled by default, and will not have native sidecar mode enabled once upgraded to supported versions. 
- Exisiting clusters with Istio add-on will retain their current native sidecar status throughout future upgrades
- Existing clusters with Istio add-on opted-in via the preview `IstioNativeSidecarModePreview` feature flag will retain their current native sidecar status regardless of cluster versions or Istio add-on revisions
- Clusters enabling Istio add-on on cluster versions less than 1.33, or Istio add-on revisions older than asm-1-27 will not have native sidecar mode enabled by default, and will not have native sidecar enabled by default throughout future upgrades
- Clusters enabling Istio add-on on cluster versions 1.33 or higher, and installing Istio add-on revision asm-1-27 or newer, will have native sidecar mode enabled by default



## Installing Istio add-on on an existing cluster
For clusters installing Istio addon, native sidecar will be enabled by default if the cluster version is 1.33 or higher and the installed addon revision is asm-1-27 or newer. 

1. Check that the AKS cluster's Kubernetes control plane version is 1.33 or higher using [az aks show][az-aks-show].

   ```bash
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER -o json | jq ".kubernetesVersion"
   ```

   If the control plane version is too old, [upgrade Kubernetes control plane][upgrade-aks-cluster].

2. Make sure node pools runs `1.33` or newer version and power state is running.

   ```bash
   az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER -o json | jq ".agentPoolProfiles[] | { currentOrchestratorVersion, powerState}"
   ```

   > [!CAUTION]
   > Native sidecar mode by default requires both Kubernetes control plane and data plane on 1.33+. Make sure all your nodes have been upgraded to 1.33 before enabling service mesh add-on. Otherwise, native sidecar will not be enabled by default.

   If any node pool version is too old, [upgrade-node-image][upgrade-node-image] to `1.33` or newer version.

3. Make sure to install Istio add-on revision `asm-1-27` or newer. Use the az aks mesh get-revisions command to check which revisions are available for different AKS cluster versions in a region. Based on the available revisions, you can include the --revision asm-X-Y (ex: --revision asm-1-27) flag in the enable command you use for mesh installation.



### Check native sidecar feature status on Istio control plane

AKS cluster needs to be reconciled with [az aks update][az-aks-update] command.

```bash
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER
```

When native sidecar mode is enabled, environment variable `ENABLE_NATIVE_SIDECARS` appears with value `true` in Istio's control plane pod template. Use the following command to check `istiod` deployment.

```bash
kubectl get deployment -l app=istiod -n aks-istio-system -o json | jq '.items[].spec.template.spec.containers[].env[] | select(.name=="ENABLE_NATIVE_SIDECARS")'
```

### Check sidecar injection

If native side mode is successfully enabled, `istio-proxy` container is shown as an init container. Use the following command to check sidecar injection:

```bash
kubectl get pods -o "custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
```

`istio-proxy` container should be shown as an init container.

```bash
NAME                     INIT                     CONTAINERS
sleep-7656cf8794-5b5j4   istio-init,istio-proxy   sleep
```

## Create a new cluster

When creating a new AKS cluster with [az aks create][az-aks-create] command, choose a version `1.33` or newer, istio `asm-1-27` or newer. The new cluster should have native sidecar mode turned on automatically.

```bash
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER \
    --enable-asm \
    --kubernetes-version 1.29 \
    --revision asm-1-20 \
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
