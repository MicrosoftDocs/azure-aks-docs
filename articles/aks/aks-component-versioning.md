---
title: Understanding AKS component versioning
description: Learn how different AKS components are versioned, patched, and upgraded across AKS cluster control plane and nodes.
ms.topic: concept-article
ms.date: 07/31/2025
author: kaarthis
ms.author: kaarthis
---

# Understanding AKS component versioning

Azure Kubernetes Service (AKS) manages multiple components that follow different versioning and patching strategies. Understanding how these components are versioned helps you plan upgrades, track security patches, and manage your cluster lifecycle effectively.

This article explains the versioning approach for each layer of AKS components and how they're maintained over time.

## AKS components overview

:::image type="content" source="media/aks-component-versioning/aks-component-architecture.png" alt-text="Architecture diagram showing AKS control plane and node components across different layers including node image, AKS features and add-ons, and customer pod sidecars." lightbox="media/aks-component-versioning/aks-component-architecture.png":::

AKS consists of multiple components, each with distinct versioning patterns:
- **Kubernetes cluster control plane hosted by AKS**: Managed Kubernetes API server, etcd, and other cluster control plane components.
- **Node images**: Operating system, container runtime, and core Kubernetes node components. Details about what components are packaged in the node images can be found under the [VHD notes folder under AKS GitHub repository][vhd-notes].
- **Workloads**: AKS managed features/add-ons/extensions could have components in one of these two buckets:
  - **Standalone add-on/features/extension pods**: AKS feature/add-ons/extensions that are running standalone pods (from Deployments or DaemonSets) on customer hosted nodes (left side). Examples include `istiod`, `azure-cns`
  - **AKS components inside customer workload pods**: Some AKS feature/add-ons/extensions might have sidecars running inside user's pods (right side). For example, Istio injects sidecar proxies to customer workload pods.

  The following table summarizes how versioning and updates are managed for each AKS component category:

|  | **Control plane** | **Node images** | **Standalone add-on/features/extension pods** | **AKS components inside customer workload pods** |
|--|-------------------|----------------|-----------------------------------------------|-----------------------------------------------|
| **What is versioned?** | Kubernetes API server, etcd, controllers | Operating system, container runtime, and core Kubernetes node components | AKS feature/add-ons/extensions that are running standalone pods (for example - istiod) | Sidecars or supporting containers injected by add-ons/extensions |
| **Versioning model** | Follows upstream Kubernetes semantic versioning (MAJOR.MINOR.PATCH). AKS offers community and Long Term Support (LTS) models. More information on this can be found in [AKS version support policy documentation][version-support-policy] | Node image versions along with VHD notes published with [AKS releases][aks-release-notes]. | Add-on/feature/extension minor version tied 1-1 to AKS minor version | Sidecar version must be compatible with add-on control plane |
| **Update method** | Customer has control over which `MAJOR.MINOR.PATCH` version to upgrade to. Manual ([az aks upgrade][az-aks-upgrade]) or automatic ([auto-upgrade channels][auto-upgrade]) | Customer can upgrade to latest supported node image version. Manual ([az aks nodepool upgrade][az-aks-nodepool-upgrade]) or [auto-upgrade][node-image-auto-upgrade] | - Minor version upgraded when control plane minor version is upgraded (except Istio; see [Istio upgrade documentation][istio-upgrade])<br/>- Patch version upgraded by AKS releases automatically | Customer needs to manually update (restart workloads having sidecars) to compatible sidecar versions as documented by the add-on/feature/extension. |

## Version management best practices

**Security consideration**: Enable automatic patch updates to ensure CVE fixes are applied as soon as possible. Choose the auto-upgrade channel that best fits your cluster's requirements and risk tolerance.
**Manual or automatic**: Choose the update strategy that best fits your operational requirements. Automatic updates provide timely security patches and reduce operational overhead, while manual updates offer precise control over timing and change management. Use [planned maintenance windows][planned-maintenance] to control when automatic upgrades are applied, ensuring updates occur during approved timeframes for your cluster.
**Monitor and prepare for changes**: Stay informed about upcoming updates and availability of new versions using [AKS release notes][aks-release-notes] and the [AKS release tracker][aks-release-tracker]. Validate upgrades in non-production environments before upgrading production environments.
  - **For production clusters:**
    - Consider automatic patch updates for timely security fixes
    - Choose between automatic or manual minor version upgrades based on your operational needs
    - Test all changes in staging environments first
  - **For development clusters:**
    - Enable automatic updates for both control plane and node pools to stay current with latest features
    - Choose appropriate channels based on your development and testing needs (see [automatic cluster upgrades][auto-upgrade] and [node image auto-upgrade][node-image-auto-upgrade] for channel options)
    - Use as a testing ground for production update strategies
- **Breaking changes**: Monitor the [AKS release tracker][aks-release-tracker] and review [Kubernetes deprecation policies](https://kubernetes.io/docs/reference/using-api/deprecation-policy/) to stay informed about API deprecations and breaking changes in both AKS and upstream Kubernetes.
- **Pre-upgrade validation**: Before upgrading your production clusters, test your applications, custom resources (CRDs), and third-party integrations on pre-production clusters to ensure compatibility with the new Kubernetes version and updated AKS components.

## Next steps

- **Plan upgrades**: [Configure automatic cluster upgrades][auto-upgrade] or [plan manual upgrades][upgrade-planning]
- **Stay informed**: [Monitor AKS releases][aks-release-tracker] for updates and breaking changes
- **Understand support**: [Review Kubernetes version support policy][support-policy]

<!-- LINKS - External -->
[semver]: https://semver.org/
[vhd-notes]: https://github.com/Azure/AKS/tree/master/vhd-notes
[aks-release-notes]: https://github.com/azure/aks/releases

<!-- LINKS - Internal -->
[aks-release-tracker]: release-tracker.md
[upgrade-cluster]: upgrade-aks-cluster.md
[support-policy]: supported-kubernetes-versions.md
[auto-upgrade]: auto-upgrade-cluster.md
[upgrade-planning]: upgrade-cluster.md
[node-image-auto-upgrade]: auto-upgrade-node-os-image.md
[node-image-upgrade]: node-image-upgrade.md
[planned-maintenance]: planned-maintenance.md
[version-support-policy]: supported-kubernetes-versions.md
[stop-cluster-upgrade-api-breaking-changes]: stop-cluster-upgrade-api-breaking-changes.md
[istio-upgrade]: istio-upgrade.md
[az-aks-upgrade]: /cli/azure/aks#az_aks_upgrade
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az_aks_nodepool_upgrade