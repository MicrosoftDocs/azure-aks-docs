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

| Component Layer | Update Frequency | Customer Control | Update Method |
|--------|--------|---------|---------|
| **Control Plane** | Security patches: 2-3 days<br/>Minor versions: With K8s releases | Yes - manual or automatic | [Cluster upgrade][upgrade-cluster] |
| **Layer 1: Node Infrastructure** | Weekly with new VHDs | Yes - manual or automatic | [Node image upgrade][node-image-upgrade] |
| **Layer 2A: Managed Add-ons** | Monthly with AKS releases | No - automatic only | Applied with AKS releases |
| **Layer 2B: Customer Workloads** | As needed | Yes - fully manual | Pod restart required |

### Version tracking commands

| Action | Method | Impact |
|--------|--------|---------|
| **View current Kubernetes version** | `az aks show --query currentKubernetesVersion` | No downtime |
| **Check all component versions** | [Component Insights][component-insights] | No downtime |
| **List available Kubernetes versions** | `az aks get-versions --location <region>` | No downtime |
| **Review release notes** | [AKS release tracker][aks-release-tracker] | Planning tool |

## AKS architecture overview

AKS consists of multiple layers, each with distinct versioning patterns:

:::image type="content" source="media/aks-component-versioning/aks-component-architecture.png" alt-text="Architecture diagram showing AKS control plane and node components across different layers including node image, AKS features and add-ons, and customer pod sidecars." lightbox="media/aks-component-versioning/aks-component-architecture.png":::

The architecture includes:
- **Kubernetes cluster control plane hosted by AKS**: Managed Kubernetes API server, etcd, and controllers
- **Layer 1 - Node Infrastructure**: Operating system, container runtime, and core Kubernetes node components
- **Layer 2 - Pod Categories**: Two categories of pods running on the same layer:
  - **AKS managed features/add-ons/extensions**: Platform-managed pods (left side)
  - **Customer workload pods**: User-managed application pods and sidecars (right side)

## AKS control plane versioning

The AKS control plane includes core Kubernetes components that follow upstream Kubernetes versioning:
### Core components
The Kubernetes control plane hosted by Microsoft includes components such as etcd, kube-apiserver, kube-controller-manager, kube-scheduler, and cloud-controller-manager.

### Patching strategy
- **Security patches**: Applied within 2-3 days of upstream Kubernetes CVE fixes
- **Bug fixes**: Follows upstream Kubernetes patch releases
- **Tracking**: Monitor updates through the [AKS release tracker][aks-release-tracker]

### Version upgrades
- **Minor versions**: Control plane minor version upgrades only occur when upstream Kubernetes releases new minor versions (e.g., 1.28 to 1.29)
- **Release cycle**: Follows upstream Kubernetes preview and GA timeline
- **Upgrade process**: See [Upgrade an AKS cluster][upgrade-cluster] for procedures
- **Automation**: Configure [automatic cluster upgrades][auto-upgrade] to keep control plane versions current
- **Release calendar**: Track [upstream Kubernetes releases](https://kubernetes.io/releases/) and [AKS release calendar][aks-release-tracker]

For detailed support timelines, review the [Kubernetes version support policy][support-policy].

## AKS node component versioning

Node components are organized into two distinct layers with different categories and update responsibilities.

### Layer 1: Node infrastructure components

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

### Layer 2: Pod categories

The pod layer consists of two categories of workloads running on your nodes, each with different update responsibilities.

#### Category A: AKS managed features and add-ons

Platform-managed components running as pods on your nodes.

#### Example components
- **coredns**: Cluster DNS resolution
- **ama-logs**: Azure Monitor logging agent
- **istiod**: Istio service mesh control plane (when enabled)
- **istio-ingress**: Istio ingress gateway (when enabled)
- **Other add-ons**: See [AKS extensions and add-ons][aks-extensions] for the complete list including Azure Policy, Azure CNI, monitoring agents, and more

#### Update frequency
- **Cadence**: Approximately every 3 weeks with AKS releases
- **Content**: Security patches (CVEs) and bug fixes are applied automatically to all clusters. New features and functionality are tied to Kubernetes minor versions and only applied during cluster upgrades.
- **Documentation**: Changes documented in [AKS release tracker][aks-release-tracker] with upstream references
#### Customer control
- **Automatic**: Updates applied automatically during AKS releases
- **No direct control**: Managed add-ons are updated as part of the AKS platform with no customer-controlled versioning
- **Update timing**: While add-on versions are automatic, you can control when updates are applied to your cluster using [planned maintenance windows][planned-maintenance]
- **No rollback**: Rollback options are not available for managed add-ons

#### Category B: Customer workload pods

User-managed application pods and sidecar containers.

#### Example sidecars
- **Istio sidecar proxies**: Service mesh data plane
- **Custom sidecars**: Application-specific containers

#### Example workloads
- **Application containers**: Your main business logic
- **Init containers**: Setup and initialization containers
- **Sidecar containers**: Supporting containers injected into pods
#### Update responsibility
- **Full ownership**: You control all aspects of your application containers and sidecars
- **No automatic updates**: AKS cannot update customer pods as this requires pod restarts, which may disrupt running applications
- **Your responsibility**: Coordinate updates with your deployment cycles and maintenance windows

#### Update triggers
When AKS updates managed components (like istiod or istio-ingress), related sidecars may need updates:
- **Compatibility**: Ensure sidecar versions align with control plane components. For example, Istio follows an [N-1 support policy](https://istio.io/latest/docs/releases/supported-releases/#support-policy), where data plane versions can be up to one minor version behind the control plane
- **Security**: Apply security patches to sidecar containers promptly after control plane updates
- **Coordination**: Plan pod restarts during maintenance windows to minimize service disruption

> [!NOTE]
> **Pod update process**: When control plane components update, you typically have a grace period to update your workload pods. Check your service mesh documentation for specific compatibility windows and update your application containers and sidecars accordingly.

## Version management best practices

### Choosing your update strategy

**For production clusters:**
- Consider automatic patch updates for timely security fixes
- Choose between automatic or manual minor version upgrades based on your operational needs
- Test all changes in staging environments first

**For development clusters:**
- Enable automatic updates for both control plane and node pools to stay current with latest features
- Choose appropriate channels based on your development and testing needs (see [automatic cluster upgrades][auto-upgrade] and [node image auto-upgrade][node-image-auto-upgrade] for channel options)
- Use as a testing ground for production update strategies

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
- **Layer 1 (Node infrastructure)**: Follows your node update configuration (automatic or manual)
- **Layer 2A (Managed add-ons)**: Automatic with AKS releases, no customer control
- **Layer 2B (Customer workloads)**: Manual coordination required with application deployments

> [!TIP]
> **Recommended approach**: Choose the update strategy that best fits your operational requirements. Automatic updates provide timely security patches and reduce operational overhead, while manual updates offer precise control over timing and change management.

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
