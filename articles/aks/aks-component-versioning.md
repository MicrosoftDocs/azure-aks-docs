---
title: Understanding AKS component versioning
description: Learn how different AKS components are versioned, patched, and upgraded across the control plane and node layers.
ms.topic: concept-article
ms.date: 07/31/2025
author: kaarthis
ms.author: kaarthis
---

# Understanding AKS component versioning

Azure Kubernetes Service (AKS) manages multiple layers of components that follow different versioning and patching strategies. Understanding how these components are versioned helps you plan upgrades, track security patches, and manage your cluster lifecycle effectively.

This article explains the versioning approach for each layer of AKS components and how they're maintained over time.

> [!TIP]
> To view current component versions in your cluster, use [AKS Component Insights (Preview)](view-aks-component-versions.md). This feature shows real-time version information for all components and highlights available updates.

## Quick reference

| Action | Method | Impact |
|--------|--------|---------|
| **Check current versions** | [Component Insights][component-insights] or `az aks show --query currentKubernetesVersion` | No downtime |
| **Enable security patches** | [Auto-upgrade patches only][auto-upgrade] | Minimal downtime (~2-5 minutes per node) |
| **Check for breaking changes** | [AKS release tracker][aks-release-tracker], [Kubernetes deprecation guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/), or use [Diagnose and solve problems](https://portal.azure.com/#blade/Microsoft_Azure_Support/AzureSupportCenterBlade/overview) to check deprecated APIs | Prevention |

## AKS architecture overview

AKS consists of multiple layers, each with distinct versioning patterns:

:::image type="content" source="media/aks-component-versioning/aks-component-architecture.jpeg" alt-text="Architecture diagram showing AKS control plane and node components across different layers including node image, AKS features and add-ons, and customer pod sidecars." lightbox="media/aks-component-versioning/aks-component-architecture.jpeg":::

The architecture includes:
- **AKS Control Plane**: Managed Kubernetes API server, etcd, and controllers
- **AKS Node**: Three distinct layers of components with different update cycles
- **Customer Applications**: Your workloads and any associated sidecars

## AKS control plane versioning

The AKS control plane includes core Kubernetes components that follow upstream Kubernetes versioning:

### Core components
- **etcd**: Distributed key-value store for cluster state
- **kube-apiserver**: Kubernetes API server
- **kube-controller-manager**: Core control loops
- **kube-scheduler**: Pod scheduling logic
- **cloud-controller-manager**: Azure-specific control plane logic

### Patching strategy
- **Security patches**: Applied within 2-3 days of upstream Kubernetes CVE fixes
- **Bug fixes**: Follows upstream Kubernetes patch releases
- **Tracking**: Monitor updates through the [AKS release tracker][aks-release-tracker]

### Version upgrades
- **Minor versions**: Only available with new Kubernetes versions following [semantic versioning][semver]
- **Release cycle**: Follows upstream Kubernetes preview and GA timeline
- **Upgrade process**: See [Upgrade an AKS cluster][upgrade-cluster] for procedures
- **Automation**: Configure [automatic cluster upgrades][auto-upgrade] to keep control plane versions current
- **Release calendar**: Track [upstream Kubernetes releases](https://kubernetes.io/releases/) and [AKS release calendar][aks-release-tracker]


For detailed support timelines, review the [Kubernetes version support policy][support-policy].

## AKS node component versioning

Node components are organized into three distinct layers, each with different update frequencies and responsibilities.

### Layer 1: Node image and VHD components

The foundation layer contains the operating system and core Kubernetes node components.

#### Components included
- **Operating system binaries**: Core OS packages and security updates
- **kubelet**: Kubernetes node agent
- **containerd**: Container runtime
- **Additional node binaries**: Supporting tools and utilities

#### Update frequency
- **Cadence**: Approximately weekly when new VHD builds are shipped
- **Content**: Security patches, bug fixes, and component updates
- **Tracking**: Monitor changes in [AKS release tracker notes][aks-release-tracker]
#### Customer control
- **Automatic**: Configure [node pool auto-upgrade][node-image-auto-upgrade] for automatic updates
- **Manual**: Trigger updates through [node image upgrades][node-image-upgrade]
- **Timing**: Use [planned maintenance windows][planned-maintenance] to control update timing

### Layer 2: AKS managed features and add-ons

The middle layer consists of AKS-managed components running as pods on your nodes.

#### Example components
- **coredns**: Cluster DNS resolution
- **ama-logs**: Azure Monitor logging agent
- **istiod**: Istio service mesh control plane (when enabled)
- **istio-ingress**: Istio ingress gateway (when enabled)
- **Other add-ons**: See [AKS extensions and add-ons][aks-extensions] for the complete list including Azure Policy, Azure CNI, monitoring agents, and more

#### Update frequency
- **Cadence**: Monthly, or up to twice per month with AKS releases
- **Content**: CVE fixes, feature updates, and bug fixes
- **Documentation**: Changes documented in [AKS release tracker][aks-release-tracker] with upstream references
#### Customer control
- **Automatic**: Updates applied automatically during AKS releases
- **No direct control**: Managed add-ons are updated as part of the AKS platform with no customer-controlled versioning
- **No rollback**: Rollback options are not available for managed add-ons

### Layer 3: Sidecar containers in customer pods

The top layer includes sidecar containers injected into your application pods.

#### Example sidecars
- **Istio sidecar proxies**: Service mesh data plane
- **Auto-instrumentation**: Observability sidecars
- **Custom sidecars**: Application-specific containers
#### Update responsibility
- **AKS-managed control plane**: For sidecars like Istio, AKS automatically manages patching and upgrades of control plane components such as istiod, istio-ingress gateway, and Istio CNI
- **Customer-managed sidecars**: You are responsible for updating sidecar containers injected into your application pods
- **Disruptive updates**: Sidecar updates require pod restarts, which you must coordinate
- **Coordination required**: While AKS handles the control plane updates, you must ensure your sidecars are compatible and schedule pod restarts aligned with your application deployment cycles

#### Update triggers
When AKS updates managed components (like istiod or istio-ingress), related sidecars may need updates:
- **Compatibility**: Ensure sidecar versions align with control plane components. For example, Istio follows an [N-1 support policy](https://istio.io/latest/docs/releases/supported-releases/#support-policy), where data plane versions can be up to one minor version behind the control plane
- **Security**: Apply security patches to sidecar containers promptly after control plane updates
- **Coordination**: Plan pod restarts during maintenance windows to minimize service disruption

> [!NOTE]
> **Sidecar update process**: When control plane components update, you typically have a grace period to update sidecars. Check your service mesh documentation for specific compatibility windows.

## Version management best practices

### Choosing your update strategy

**For production clusters:**
- Enable automatic patch updates for security
- Use manual control for minor version upgrades
- Test all changes in staging environments first

**For development clusters:**
- Consider full automatic updates for convenience
- Accept higher risk for faster feature access

> [!IMPORTANT]
> **Security consideration**: Enable automatic patch updates to ensure CVE fixes are applied within 2-3 days. Choose the auto-upgrade channel that best fits your cluster's requirements and risk tolerance.

### Update approach considerations

When selecting your update strategy, consider these factors:

- **Security requirements**: How quickly must security patches be applied?
- **Change control processes**: What approval workflows exist in your organization?
- **Testing requirements**: How much validation is needed before updates?
- **Service availability**: What downtime windows are acceptable?
- **Compliance requirements**: Are there regulatory constraints on changes?

Both automatic and manual update strategies are valid choices depending on your specific needs. Automatic updates can provide timely security patches and reduce operational overhead, while manual updates offer precise control over timing and sequencing.

### Planning upgrades
1. **Monitor release tracker**: Stay informed about upcoming changes through the [AKS release tracker][aks-release-tracker]
2. **Check compatibility**: Review [breaking changes and known issues][support-policy] before upgrading
3. **Test in staging**: Validate updates in non-production environments
4. **Plan maintenance windows**: Schedule disruptive updates during low-traffic periods using [planned maintenance windows][planned-maintenance]

### Tracking component versions
Use [AKS Component Insights (Preview)][component-insights] to:
- View current versions of all cluster components
- Identify components with available updates
- Monitor breaking change indicators
- Plan upgrade sequences based on dependencies

> [!IMPORTANT]
> **Before any upgrade**: Check the [AKS release tracker][aks-release-tracker] for breaking changes and validate your workloads in a test environment.

### Managing update cycles
Both control plane and node components support manual and automatic update options, with secure defaults configured for production clusters.

#### Control plane updates
- **Default**: Automatic patch channel updates for security and bug fixes
- **Manual option**: Disable auto-upgrade for full control over update timing
- **Configuration**: See [automatic cluster upgrades][auto-upgrade] for setup details

#### Node updates  
- **Default**: Automatic node-image updates for OS and Kubernetes component patches
- **Manual option**: Disable auto-upgrade to control node update scheduling
- **Configuration**: See [node image auto-upgrade][node-image-auto-upgrade] for configuration options

#### Layer-specific update behavior
- **Layer 1 (Node image)**: Follows your node update configuration (automatic or manual)
- **Layer 2 (Managed add-ons)**: Automatic with AKS releases, no customer control
- **Layer 3 (Customer sidecars)**: Manual coordination required with application deployments

> [!TIP]
> **Recommended approach**: Enable automatic updates for Layers 1-2 in development environments, but use manual control in production for better change management.

## Semantic versioning in AKS

AKS follows [semantic versioning (semver)][semver] principles for different component types:

### Major versions (X.y.z)
- **Kubernetes**: Rare, with significant breaking changes
- **AKS platform**: Major architectural changes

### Minor versions (x.Y.z)
- **Kubernetes**: New features, API additions
- **AKS platform**: New capabilities and features
- **Add-ons**: Feature additions and enhancements

### Patch versions (x.y.Z)
- **All components**: Bug fixes and security patches
- **Frequency**: Regular security and stability updates

## Breaking changes and compatibility

### Identifying potential issues
- **Breaking change notifications**: Monitor the [AKS release tracker][aks-release-tracker] for API deprecations and breaking changes
- **Component compatibility**: Use [Component Insights][component-insights] to identify version conflicts before they cause issues
- **Kubernetes API changes**: Review [Kubernetes deprecation policies](https://kubernetes.io/docs/reference/using-api/deprecation-policy/) for upstream changes

### Pre-upgrade validation
1. **Check workload compatibility**: Test applications against new Kubernetes API versions
2. **Review custom resources**: Ensure CRDs are compatible with new Kubernetes versions
3. **Validate integrations**: Confirm third-party tools work with updated components

> [!WARNING]
> **Major version upgrades**: Always test Kubernetes major version upgrades thoroughly. These may include breaking API changes that require application updates.

### Troubleshooting version issues

**Version mismatch symptoms:**
- Pods failing to start after upgrades
- API calls returning deprecation warnings
- Performance degradation post-update

**Quick fixes:**
1. **Check compatibility**: `kubectl api-versions` to verify available APIs
2. **Review logs**: `kubectl describe pod <pod-name>` for specific errors
3. **Validate resources**: `kubectl get events --sort-by='.lastTimestamp'` for recent issues
4. **Emergency rollback**: See [cluster version downgrade guidance][support-policy] for supported scenarios

## Next steps

- **Get started**: [View component versions in your cluster][component-insights]
- **Plan upgrades**: [Configure automatic cluster upgrades][auto-upgrade] or [plan manual upgrades][upgrade-planning]
- **Stay informed**: [Monitor AKS releases][aks-release-tracker] for updates and breaking changes
- **Understand support**: [Review Kubernetes version support policy][support-policy]

<!-- LINKS - Internal -->
[aks-release-tracker]: release-tracker.md
[semver]: https://semver.org/
[upgrade-cluster]: upgrade-aks-cluster.md
[support-policy]: supported-kubernetes-versions.md
[component-insights]: view-aks-component-versions.md
[auto-upgrade]: auto-upgrade-cluster.md
[upgrade-planning]: upgrade-cluster.md
[node-image-auto-upgrade]: auto-upgrade-node-os-image.md
[node-image-upgrade]: node-image-upgrade.md
[planned-maintenance]: planned-maintenance.md
[aks-extensions]: integrations.md
