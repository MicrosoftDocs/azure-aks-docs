---
title: Upgrade Istio-based service mesh add-on for Azure Kubernetes Service
description: Upgrade Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: article
ms.service: azure-kubernetes-service
ms.date: 05/04/2023
ms.author: shasb
author: shashankbarsin
ms.custom: devx-track-azurecli
---

# Upgrade Istio-based service mesh add-on for Azure Kubernetes Service

This article addresses upgrade experiences for Istio-based service mesh add-on for Azure Kubernetes Service (AKS).

Announcements about the releases of new minor revisions or patches to the Istio-based service mesh add-on are published in the [AKS release notes][aks-release-notes]. To learn more about the release schedule and support for service mesh add-on revisions, read the [support policy][istio-support].

## Minor revision upgrade

Istio add-on allows upgrading the minor revision using [canary upgrade process][istio-canary-upstream]. When an upgrade is initiated, the control plane of the new (canary) revision is deployed alongside the initial (stable) revision's control plane. You can then manually roll over data plane workloads while using monitoring tools to track the health of workloads during this process. If you don't observe any issues with the health of your workloads, you can complete the upgrade so that only the new revision remains on the cluster. Else, you can roll back to the previous revision of Istio.

If the cluster is currently using a supported minor revision of Istio, upgrades are only allowed one minor revision at a time. If the cluster is using an unsupported revision of Istio, you must upgrade to the lowest supported minor revision of Istio for that Kubernetes version. After that, upgrades can again be done one minor revision at a time.

The following example illustrates how to upgrade from revision `asm-1-20` to `asm-1-21`. The steps are the same for all minor upgrades.

1. Use the [az aks mesh get-upgrades](/cli/azure/aks/mesh#az-aks-mesh-get-upgrades) command to check which revisions are available for the cluster as upgrade targets:

    ```azurecli-interactive
    az aks mesh get-upgrades --resource-group $RESOURCE_GROUP --name $CLUSTER
    ```

    If you expect to see a newer revision not returned by this command, you may need to upgrade your AKS cluster first so that it's compatible with the newest revision.

1. If you set up [mesh configuration][meshconfig] for the existing mesh revision on your cluster, you need to create a separate ConfigMap corresponding to the new revision in the `aks-istio-system` namespace **before initiating the canary upgrade** in the next step. This configuration is applicable the moment the new revision's control plane is deployed on cluster. More details can be found [here][meshconfig-canary-upgrade].

1. Initiate a canary upgrade from revision `asm-1-20` to `asm-1-21` using [az aks mesh upgrade start](/cli/azure/aks/mesh/upgrade#az-aks-mesh-upgrade-start):

    ```azurecli-interactive
    az aks mesh upgrade start --resource-group $RESOURCE_GROUP --name $CLUSTER --revision asm-1-21
    ```

    A canary upgrade means the 1.20 control plane is deployed alongside the 1.21 control plane. They continue to coexist until you either complete or roll back the upgrade.

1. Verify control plane pods corresponding to both `asm-1-20` and `asm-1-21` exist:

    * Verify `istiod` pods:

        ```bash
        kubectl get pods -n aks-istio-system
        ```

        Example output:

        ```
        NAME                                        READY   STATUS    RESTARTS   AGE
        istiod-asm-1-20-55fccf84c8-dbzlt            1/1     Running   0          58m
        istiod-asm-1-20-55fccf84c8-fg8zh            1/1     Running   0          58m
        istiod-asm-1-21-f85f46bf5-7rwg4             1/1     Running   0          51m
        istiod-asm-1-21-f85f46bf5-8p9qx             1/1     Running   0          51m
        ```

    * If ingress is enabled, verify ingress pods:

        ```bash
        kubectl get pods -n aks-istio-ingress
        ```

        Example output:

        ```
        NAME                                                          READY   STATUS    RESTARTS   AGE
        aks-istio-ingressgateway-external-asm-1-20-58f889f99d-qkvq2   1/1     Running   0          59m
        aks-istio-ingressgateway-external-asm-1-20-58f889f99d-vhtd5   1/1     Running   0          58m
        aks-istio-ingressgateway-external-asm-1-21-7466f77bb9-ft9c8   1/1     Running   0          51m
        aks-istio-ingressgateway-external-asm-1-21-7466f77bb9-wcb6s   1/1     Running   0          51m
        aks-istio-ingressgateway-internal-asm-1-20-579c5d8d4b-4cc2l   1/1     Running   0          58m
        aks-istio-ingressgateway-internal-asm-1-20-579c5d8d4b-jjc7m   1/1     Running   0          59m
        aks-istio-ingressgateway-internal-asm-1-21-757d9b5545-g89s4   1/1     Running   0          51m
        aks-istio-ingressgateway-internal-asm-1-21-757d9b5545-krq9w   1/1     Running   0          51m
        ```

        Observe that ingress gateway pods of both revisions are deployed side-by-side. However, the service and its IP remain immutable.

1. Relabel the namespace so that any new pods get the Istio sidecar associated with the new revision and its control plane:

    ```bash
    kubectl label namespace default istio.io/rev=asm-1-21 --overwrite
    ```

    Relabeling doesn't affect your workloads until they're restarted.

1. Individually roll over each of your application workloads by restarting them. For example:

    ```bash
    kubectl rollout restart deployment <deployment name> -n <deployment namespace>
    ```

1. Check your monitoring tools and dashboards to determine whether your workloads are all running in a healthy state after the restart. Based on the outcome, you have two options:

    * **Complete the canary upgrade**: If you're satisfied that the workloads are all running in a healthy state as expected, you can complete the canary upgrade. Completion of the upgrade removes the previous revision's control plane and leaves behind the new revision's control plane on the cluster. Run the following command to complete the canary upgrade:

      ```azurecli-interactive
      az aks mesh upgrade complete --resource-group $RESOURCE_GROUP --name $CLUSTER
      ```

    * **Rollback the canary upgrade**: In case you observe any issues with the health of your workloads, you can roll back to the previous revision of Istio:

      * Relabel the namespace to the previous revision:

          ```bash
          kubectl label namespace default istio.io/rev=asm-1-20 --overwrite
          ```

      * Roll back the workloads to use the sidecar corresponding to the previous Istio revision by restarting these workloads again:

          ```bash
          kubectl rollout restart deployment <deployment name> -n <deployment namespace>
          ```

      * Roll back the control plane to the previous revision:

          ```azurecli-interactive
          az aks mesh upgrade rollback --resource-group $RESOURCE_GROUP --name $CLUSTER
          ```

1. If [mesh configuration][meshconfig] was previously set up for the revisions, you can now delete the ConfigMap for the revision that was removed from the cluster during complete/rollback.

> [!NOTE]
> Manually relabeling namespaces when moving them to a new revision can be tedious and error-prone. [Revision tags](https://istio.io/latest/docs/setup/upgrade/canary/#stable-revision-labels) solve this problem. Revision tags are stable identifiers that point to revisions and can be used to avoid relabeling namespaces. Rather than relabeling the namespace, a mesh operator can simply change the tag to point to a new revision. All namespaces labeled with that tag will be updated at the same time. However, note that you still need to restart the workloads to make sure the correct version of `istio-proxy` sidecars are injected.

### Minor revision upgrades with the ingress gateway

If you're currently using [Istio ingress gateways](./istio-deploy-ingress.md) and are performing a minor revision upgrade, keep in mind that Istio ingress gateway pods / deployments are deployed per-revision. However, we provide a single LoadBalancer service across all ingress gateway pods over multiple revisions, so the external/internal IP address of the ingress gateways won't change throughout the course of an upgrade. 

Thus, during the canary upgrade, when two revisions exist simultaneously on the cluster, the ingress gateway pods of both revisions serve incoming traffic.

### Minor revision upgrades with horizontal pod autoscaling customizations

If you have customized [horizontal pod autoscaling (HPA) settings for Istiod or the ingress gateways][istio-scale-hpa], note the following behavior for how HPA settings are applied across both revisions to maintain consistency during a canary upgrade:

- If you update the HPA spec before initiating an upgrade, the settings from the existing (stable) revision will be applied to the HPAs of the canary revision when the new control plane is installed. 
- If you update the HPA spec while a canary upgrade is in progress, the HPA spec of the stable revision will take precedence and be applied to the HPA of the canary revision. 
  - If you update the HPA of the stable revision during an upgrade, the HPA spec of the canary revision will be updated to reflect the new settings applied to the stable revision.
  - If you update the HPA of the canary revision during an upgrade, the HPA spec of the canary revision will be reverted to the HPA spec of the stable revision.

## Patch version upgrade

* Istio add-on patch version availability information is published in [AKS release notes][aks-release-notes].
* Patches are rolled out automatically for istiod and ingress pods as part of these AKS releases, which respect the `default` [planned maintenance window](./planned-maintenance.md) set up for the cluster.
* User needs to initiate patches to Istio proxy in their workloads by restarting the pods for reinjection:
  * Check the version of the Istio proxy intended for new or restarted pods. This version is the same as the version of the istiod and Istio ingress pods after they were patched:

    ```bash
    kubectl get cm -n aks-istio-system -o yaml | grep "mcr.microsoft.com\/oss\/istio\/proxyv2"
    ```

    Example output:

    ```bash
    "image": "mcr.microsoft.com/oss/istio/proxyv2:1.20.6-distroless",
    "image": "mcr.microsoft.com/oss/istio/proxyv2:1.20.6-distroless"
    ```

  * Check the Istio proxy image version for all pods in a namespace:

    ```bash
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |\
    sort |\
    grep "mcr.microsoft.com\/oss\/istio\/proxyv2"
    ```

    Example output:

    ```bash
    productpage-v1-979d4d9fc-p4764:	docker.io/istio/examples-bookinfo-productpage-v1:1.20.0, mcr.microsoft.com/oss/istio/proxyv2:1.20.6-distroless
    ```

  * To trigger reinjection, restart the workloads. For example:

    ```bash
    kubectl rollout restart deployments/productpage-v1 -n default
    ```

  * To verify that they're now on the newer versions, check the Istio proxy image version again for all pods in the namespace:

    ```bash
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |\
    sort |\
    grep "mcr.microsoft.com\/oss\/istio\/proxyv2"
    ```

    Example output:

    ```bash
    productpage-v1-979d4d9fc-p4764:	docker.io/istio/examples-bookinfo-productpage-v1:1.20.0, mcr.microsoft.com/oss/istio/proxyv2:1.20.7-distroless
    ```

> [!NOTE]
> In case of any issues encountered during upgrades, refer to [article on troubleshooting mesh revision upgrades][upgrade-istio-service-mesh-tsg]

<!-- LINKS - External -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[istio-canary-upstream]: https://istio.io/latest/docs/setup/upgrade/canary/

<!-- LINKS - Internal -->
[istio-support]: ./istio-support-policy.md#versioning-and-support-policy
[meshconfig]: ./istio-meshconfig.md
[meshconfig-canary-upgrade]: ./istio-meshconfig.md#mesh-configuration-and-upgrades
[upgrade-istio-service-mesh-tsg]: /troubleshoot/azure/azure-kubernetes/extensions/istio-add-on-minor-revision-upgrade
[istio-scale-hpa]: ./istio-scale.md#horizontal-pod-autoscaling-customization

