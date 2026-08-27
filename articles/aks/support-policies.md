---
title: Support Policies for Azure Kubernetes Service (AKS)
description: Learn about Azure Kubernetes Service (AKS) support policies, shared responsibility, and features that are in preview (or alpha or beta).
ms.topic: concept-article
ms.date: 08/27/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a cluster operator or developer, I want to understand what AKS components I need to manage, what components are managed by Microsoft (including security patches), and networking and preview features.
---

# Support policies for Azure Kubernetes Service

This article describes technical support policies and limitations for Azure Kubernetes Service (AKS). It also details agent node management, managed control plane components, non-Microsoft open-source components, and security or patch management.

## Service updates and releases

- For release information, see [AKS release notes](https://github.com/Azure/AKS/releases).
- For information on preview features, see the [AKS roadmap](https://github.com/Azure/AKS/projects/1).

## Managed features in AKS

AKS is a mix of Infrastructure as a Service (IaaS) and Platform as a Service (PaaS). Base IaaS cloud components, like compute or networking components, provide access to low-level controls and customization options. By contrast, AKS provides a turnkey Kubernetes deployment that gives you a common set of configurations and capabilities you need for your cluster. As an AKS user, you have limited customization and deployment options and don't manage Kubernetes clusters directly.

With AKS, you get a fully managed _control plane_. The control plane contains all of the components and services you need to operate and deliver Kubernetes clusters to end users. Microsoft maintains and operates all Kubernetes components.

Microsoft manages and monitors the following components through the control plane:

- The Kubernetes API server and `kubelet`.
- `etcd` or a compatible key-value store, providing Quality of Service (QoS), scalability, and runtime.
- DNS services like CoreDNS.
- `kube-proxy` and cluster networking, except when [BYOCNI](use-byo-cni.md) is used.
- Any other [add-ons][add-ons] or system component running in the kube-system namespace.

Some components, like agent nodes, have _shared responsibility_, where you must help maintain the AKS cluster. User input is required, for example, to apply an agent node operating system (OS) security patch.

The services are _managed_ in the sense that Microsoft and the AKS team deploys, operates, and is responsible for service availability and functionality. Customers can't alter these managed components. Microsoft limits customization to ensure a consistent and scalable user experience.

## Shared responsibility

When you create a cluster, you define the Kubernetes agent nodes that AKS creates. Your workloads run on these nodes. Keep the following agent node constraints in mind:

- **Microsoft Support has limited access.** Because your agent nodes run private code and store sensitive data, Microsoft Support can't sign in to, run commands on, or view logs for these nodes without your express permission or assistance.
- **Use Kubernetes-native mechanisms for changes.** Any modification made directly to the agent nodes through the IaaS APIs renders the cluster unsupportable. Apply changes by using Kubernetes-native mechanisms like a `DaemonSet`.
- **Don't change system-created metadata.** You can add metadata like tags and labels, but changing any system-created metadata renders the cluster unsupported.

## Division of responsibility

The following matrix summarizes support responsibility across an AKS cluster, and contrasts AKS with self-managed Kubernetes that you run on-premises. In AKS, Microsoft manages the control plane and core platform. You manage your node configuration, workloads, networking configuration, and data. _Shared_ areas are where Microsoft provides and maintains a capability and you enable, configure, or schedule it. Use the matrix as an at-a-glance guide, then see the detailed sections that follow for support specifics.

Use the following key to read the matrix:

| Symbol | Meaning |
|---|---|
| 🔵 Customer | You own and manage this area. |
| 🟣 Shared | Microsoft provides and maintains the capability; you enable, configure, or schedule it. |
| 🟢 Microsoft | Microsoft owns and manages this area. |
| ⚠️ Unsupported | Unsupported or best-effort only. For details, see [Unsupported scenarios](#unsupported-scenarios). |
| Not applicable | The capability doesn't apply to self-managed on-premises Kubernetes. |

| Responsibility area | On-premises Kubernetes | AKS (Azure) |
|---|:--|:--|
| **Physical and infrastructure** | | |
| Physical datacenter and network | 🔵 Customer | 🟢 Microsoft |
| Physical hosts (servers and VMs) | 🔵 Customer | 🟢 Microsoft |
| **Control plane** | | |
| Kubernetes control plane (API server, `etcd`, scheduler, controllers) | 🔵 Customer | 🟢 Microsoft |
| Control plane high availability and SLA | 🔵 Customer | 🟢 Microsoft |
| `etcd` backups (automatic, every 30 minutes) | 🔵 Customer | 🟢 Microsoft |
| Kubernetes version upgrades (control plane) | 🔵 Customer | 🟣 Shared |
| **Nodes and OS** | | |
| Worker node provisioning and scaling | 🔵 Customer | 🟣 Shared |
| Node OS image and patching | 🔵 Customer | 🟣 Shared |
| Node auto-repair | Not applicable | 🟢 Microsoft |
| Node pool configuration (VM size, count, labels, taints) | 🔵 Customer | 🔵 Customer |
| **Managed add-ons and components** | | |
| AKS managed add-ons (CoreDNS, Metrics Server, Azure Policy, CSI drivers) | 🔵 Customer | 🟣 Shared |
| Container runtime (`containerd`) | 🔵 Customer | 🟢 Microsoft |
| `kubelet` and `kube-proxy` | 🔵 Customer | 🟢 Microsoft |
| **Networking** | | |
| Microsoft-managed CNI (Azure CNI, Cilium, kubenet) | 🔵 Customer | 🟣 Shared |
| Bring your own CNI plugin ([BYOCNI](use-byo-cni.md)) | 🔵 Customer | 🔵 Customer ⚠️ Unsupported |
| VNet, subnets, NSGs, UDRs | 🔵 Customer | 🔵 Customer |
| Microsoft-managed ingress controllers and load balancers | 🔵 Customer | 🟣 Shared |
| Non-Microsoft ingress controllers (`nginx`, `kong`, `traefik`) | 🔵 Customer | 🔵 Customer ⚠️ Unsupported |
| Network policies (pod-to-pod traffic) | 🔵 Customer | 🔵 Customer |
| **Security** | | |
| Kubernetes RBAC and cluster roles | 🔵 Customer | 🔵 Customer |
| Microsoft Entra ID integration | 🔵 Customer | 🟣 Shared |
| Secrets management | 🔵 Customer | 🔵 Customer |
| Pod security (security context, Pod Security Standards) | 🔵 Customer | 🔵 Customer |
| Image security and vulnerability scanning | 🔵 Customer | 🟣 Shared |
| Security patching of managed container images | Not applicable | 🟢 Microsoft |
| **Workloads** | | |
| Application deployments (Pods, Deployments, StatefulSets) | 🔵 Customer | 🔵 Customer |
| Application code and container images | 🔵 Customer | 🔵 Customer |
| Persistent storage (disks, file shares) | 🔵 Customer | 🟣 Shared |
| Non-Microsoft or open-source tools (Istio, Helm charts) | 🔵 Customer | 🔵 Customer ⚠️ Unsupported |
| `DaemonSet` objects for node customization | 🔵 Customer | 🔵 Customer ⚠️ Unsupported |
| **Data and compliance** | | |
| Customer data | 🔵 Customer | 🔵 Customer |
| Identities and access management | 🔵 Customer | 🔵 Customer |
| Regulatory compliance and governance | 🔵 Customer | 🔵 Customer |
| **Observability** | | |
| Platform monitoring (control plane logs and metrics) | 🔵 Customer | 🟣 Shared |
| Workload monitoring and alerting | 🔵 Customer | 🔵 Customer |
| **Disaster recovery** | | |
| Cluster backup and disaster recovery | 🔵 Customer | 🔵 Customer |

For the shared areas in the following matrix, the table shows what Microsoft provides and what you're responsible for:

| Shared responsibility | Microsoft provides | Customer provides |
|---|---|---|
| Kubernetes version upgrades | Supported versions and deprecation timelines | Trigger and schedule the upgrade |
| Node OS patching | Updated node images | Choose an auto-upgrade channel, or apply manually |
| Worker node scaling | Cluster autoscaler and Karpenter | Configure policies, min/max, and priorities |
| Managed add-ons | Ships and patches add-on versions | Enable, disable, and configure them |
| CNI plugin | Maintains Azure CNI and Cilium | Choose the plugin, CIDR ranges, and tuning |
| Microsoft Entra ID integration | Provides the integration | Configure groups, roles, and conditional access |
| Persistent storage | CSI drivers and Azure Disk and Files | Configure storage classes, PVCs, and backup |
| Platform monitoring | Emits control plane logs and metrics | Enable diagnostic settings and build alerts |
| Image vulnerability scanning | Scans and patches managed container images | Update the VHD; own your application images |

> [!NOTE]
> This article describes the division of responsibility for AKS clusters that run in Azure. AKS also runs on your own infrastructure through [AKS Hybrid and Edge](/azure/aks/aksarc/aks-overview), where the split differs by deployment option because you own the physical hardware and, for some options, self-manage the cluster. For those responsibilities, see [AKS Hybrid and Edge support policies](/azure/aks/aksarc/support-policies).

## AKS support coverage

The following sections describe the supported and unsupported scenarios for AKS technical support.

### Supported scenarios

Microsoft provides technical support for the following examples:

| Area | What Microsoft supports |
|---|---|
| Control plane connectivity | Connectivity to all Kubernetes components that AKS provides and supports, like the API server. |
| Control plane operations | Management, uptime, QoS, and operations of Kubernetes control plane services like the control plane, API server, `etcd`, and CoreDNS. |
| `etcd` data store | Automated, transparent backups of all `etcd` data every 30 minutes for disaster planning and cluster state restoration. Backups aren't directly available to you or anyone else. On-demand rollback or restore isn't supported as a feature. |
| Azure cloud provider integrations | Integration points in the Azure cloud provider driver, like load balancers, persistent volumes, and networking (Kubernetes and Azure CNI), except when [BYOCNI](use-byo-cni.md) is in use. |
| Control plane customization | Questions about customizing control plane components like the Kubernetes API server, `etcd`, and CoreDNS. |
| Networking | Network access and functionality issues (except [BYOCNI](use-byo-cni.md)), like DNS resolution, packet loss, and routing. Supported scenarios include kubenet and Azure CNI with managed or custom (bring your own) subnets; connectivity to other Azure services and applications; Microsoft-managed ingress controllers and load balancer configurations; network performance and latency; and Microsoft-managed [network policies](use-network-policies.md#differences-between-network-policy-engines-cilium-azure-npm-and-calico). |
| Agent node components | Autoremediation of `kubelet`, `kube-proxy`, `containerd`, and networking tunnels on agent nodes. For more information, see [Microsoft responsibilities for AKS agent nodes](#microsoft-responsibilities-for-aks-agent-nodes). |

Any cluster actions taken by Microsoft or AKS are made with your consent under a built-in Kubernetes role `aks-service` and built-in role binding `aks-service-rolebinding`, which binds the role to the `aks-support` Microsoft Support service identity. This role enables AKS to troubleshoot and diagnose cluster issues, but it can't modify permissions or create roles or role bindings, or do other high privilege actions. Role access is only enabled under active support tickets with just-in-time (JIT) access.

### Unsupported scenarios

Microsoft doesn't provide technical support for the following scenarios.

| Scenario | Not supported |
|---|---|
| How to use Kubernetes | General Kubernetes usage advice, like how to create custom ingress controllers or apply non-Microsoft software. |
| Non-Microsoft open-source projects | Projects like Istio, Helm, or Envoy that aren't part of the control plane or deployed with AKS. |
| Non-Microsoft closed-source software | Security scanning tools and networking devices or software. |
| Application-specific code | Configuring or troubleshooting application-specific code or the behavior of non-Microsoft applications or tools running within the AKS cluster, including application deployment issues not related to the AKS platform itself. |
| Application certificates | Issuance, renewal, or management of certificates for applications running on AKS. |
| Network customizations | Network customizations beyond the AKS documentation, like VPNs or non-Microsoft firewalls. |
| BYO CNI plugins | Custom or non-Microsoft CNI plugins used in [BYOCNI](use-byo-cni.md) mode. |
| Non-Microsoft network policies | Configuring or troubleshooting non-Microsoft-managed network policies. Using network policies is supported, but Microsoft Support can't investigate issues stemming from custom network policy configurations. |
| Non-Microsoft ingress controllers | Ingress controllers like `nginx`, `kong`, or `traefik`. |
| Custom DaemonSet scripts | `DaemonSet` scripts used to customize node configurations. |
| Standby and proactive support | Proactive or standby support to reduce operational risk. Microsoft provides reactive support only. |
| CVEs less than 30 days old | Vulnerabilities and CVEs with a vendor fix less than 30 days old. |
| Custom code samples | Custom code samples or scripts specific to your environment or application. |
| Custom Azure Policy logic | Detailed troubleshooting of custom Azure Policy logic, including Rego-based policies. |

Some of these scenarios have more nuance about what Microsoft can still help with. For more information, see [Details about unsupported scenarios](#details-about-unsupported-scenarios).

#### Details about unsupported scenarios

Several unsupported scenarios have added nuance about what Microsoft can still help with:

- **How to use Kubernetes.** Microsoft Support doesn't provide advice on how to create custom ingress controllers, use application workloads, or apply non-Microsoft or open-source software packages or tools. Microsoft Support can advise on AKS cluster functionality, customization, and tuning (for example, Kubernetes operations issues and procedures).
- **Non-Microsoft open-source projects.** These projects aren't provided as part of the Kubernetes control plane or deployed with AKS clusters, and might include Istio, Helm, Envoy, or others. Microsoft can provide best-effort support for projects like Helm. Where the tool integrates with the Kubernetes Azure cloud provider or other AKS-specific bugs, Microsoft supports examples and applications from Microsoft documentation.
- **Network customizations.** For customizations other than the ones listed in the [AKS documentation](./index.yml), Microsoft Support can't configure devices or virtual appliances meant to provide [outbound traffic](outbound-rules-control-egress.md) for the cluster, like VPNs or firewalls. On a best-effort basis, Microsoft Support might advise on the [configuration needed](outbound-rules-control-egress.md) for Azure Firewall, but not for other non-Microsoft devices.
- **Non-Microsoft ingress controllers.** For controllers like `nginx`, `kong`, or `traefik`, this includes functionality issues that arise after AKS-specific operations, like an ingress controller ceasing to work following a Kubernetes version upgrade, which might stem from incompatibilities between the ingress controller version and the new Kubernetes version. For a fully supported option, consider a [Microsoft-managed ingress controller option](concepts-network-ingress.md#compare-ingress-options).
- **Custom DaemonSet scripts.** Although using `DaemonSet` is the recommended approach to tune, modify, or install non-Microsoft software on agent nodes when [configuration file parameters](custom-node-configuration.md) are insufficient, Microsoft Support can't troubleshoot issues arising from the custom scripts due to their custom nature.
- **Standby and proactive support.** Microsoft Support provides reactive support to solve active issues. Standby or proactive support to eliminate operational risks, increase availability, and optimize performance isn't covered. [Eligible customers](https://www.microsoft.com/unifiedsupport) can contact their account team to get nominated for [Azure Event Management service](https://devblogs.microsoft.com/premier-developer/proactively-plan-for-your-critical-event-in-azure-with-enhanced-support-and-engineering-services/), a paid service that includes a proactive solution risk assessment and coverage during the event.
- **CVEs less than 30 days old.** As long as you run the updated VHD, you shouldn't have any container image CVEs with a vendor fix that's over 30 days old. It's your responsibility to update the VHD, then filter the CVE report and provide Microsoft Support a list of only the CVEs with a vendor fix over 30 days old. Microsoft then works internally to address components with a vendor fix released more than 30 days ago. Microsoft provides CVE-related support only for Microsoft-managed components, like AKS node images and managed container images deployed during cluster creation or through a managed add-on. For more information, see [Vulnerability management for Azure Kubernetes Service (AKS)](concepts-vulnerability-management.md).
- **Custom code samples.** Microsoft Support can provide and review small code samples within a support case to demonstrate how to use features of a Microsoft product, but can't provide custom code samples specific to your environment or application.
- **Custom Azure Policy logic.** Microsoft Support can provide general guidance on how custom Azure Policy definitions are applied and evaluated in AKS. Detailed troubleshooting of customer-authored policy logic (including Rego-based policies), such as why a specific policy allows or denies a workload, is generally outside the scope of support.

### Bring your own CNI support boundaries

When you deploy a cluster with bring your own CNI (BYOCNI) by using `--network-plugin none`, Microsoft Support can't help with CNI-related issues. You're responsible for the CNI plugin lifecycle, and you should seek support from the CNI plugin vendor. Microsoft still supports issues that aren't related to the CNI.

| Microsoft supports | Microsoft doesn't support |
|---|---|
| Node provisioning, control plane, and other non-CNI issues | Most east-west (pod-to-pod) traffic issues |
| Kubernetes API server, `etcd`, and scheduler | `kubectl proxy` and similar commands |
| Node OS and `kubelet` | CNI plugin installation, configuration, and troubleshooting |
| Azure load balancers and managed components | Pod IP address management (IPAM) |

For more information, see [Bring your own CNI (BYOCNI)](use-byo-cni.md).

## AKS support coverage for agent nodes

The following sections describe the Microsoft and customer responsibilities for AKS agent nodes.

The following table summarizes agent node responsibilities at a glance. The sections that follow provide the detail.

| Aspect | Microsoft | Customer |
|---|---|---|
| Base OS image with monitoring and networking agents | Provides | Not applicable |
| Control plane components on nodes (`kubelet`, `kube-proxy`, `containerd`, networking tunnels) | Autoremediates | Not applicable |
| Node auto-repair for unhealthy nodes | Automatic | Not applicable |
| Node OS patches and images (weekly) | Publishes | Apply within 90 days (manual or auto-upgrade) |
| Kubernetes version currency | Publishes patches and versions | Keep the cluster on a supported version |
| Node customization | Not applicable | Use `DaemonSet` (unsupported if it breaks the node) |
| IaaS-level node modifications | Not applicable | Not supported; renders the cluster unsupportable |

### Microsoft responsibilities for AKS agent nodes

Microsoft and you share responsibility for Kubernetes agent nodes where:

- The base OS image has required additions like monitoring and networking agents.
- The agent nodes receive OS patches automatically.
- The system automatically remediates issues with the Kubernetes control plane components that run on the agent nodes. These components include the following items:
  - `kube-proxy`
  - Networking tunnels that provide communication paths to the Kubernetes control plane
  - `kubelet`
  - `containerd`

If an agent node isn't operational, AKS might restart individual components or the entire agent node. These restart operations are automated and provide autoremediation for common issues. To learn more about the autoremediation mechanisms, see [Node Auto-Repair](node-auto-repair.md).

### Customer responsibilities for AKS agent nodes

Microsoft provides patches and new images for your image nodes weekly. To keep your agent node OS and runtime components up to date, you should apply these patches and updates regularly either manually or automatically. Microsoft doesn't support node images that are older than 90 days. For more information, see:

- [Manually upgrade AKS node images](./node-image-upgrade.md).
- [Automatically upgrade AKS node images](./auto-upgrade-node-os-image.md).

Similarly, AKS regularly releases new Kubernetes patches and minor versions. These updates can contain security or functionality improvements to Kubernetes. You're responsible to keep your clusters' Kubernetes version updated and according to the [AKS Kubernetes support version policy](supported-kubernetes-versions.md).

#### User customization of agent nodes

> [!NOTE]
> AKS agent nodes appear in the Azure portal as standard Azure IaaS resources. However, these virtual machines are deployed into a custom Azure resource group (prefixed with `MC_`). You can't change the base OS image or make any direct customizations to these nodes using the IaaS APIs or resources. Any custom changes that aren't performed from the AKS API don't persist through an upgrade, scale, update, or reboot. Also, any change to the nodes' extensions like the `CustomScriptExtension` can lead to unexpected behavior and should be prohibited.
> Avoid performing changes to the agent nodes unless Microsoft Support directs you to make changes.

AKS manages the lifecycle and operations of agent nodes on your behalf and modifying the IaaS resources associated with the agent nodes is **not supported**. An example of an unsupported operation is customizing a node pool virtual machine scale set by manually changing configurations in the Azure portal or from the API.

For workload-specific configurations or packages, AKS recommends using a [Kubernetes `DaemonSet`](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

Using Kubernetes privileged `DaemonSet` and `init` containers enables you to tune/modify or install non-Microsoft software on cluster agent nodes. Examples of such customizations include adding custom security scanning software or updating sysctl settings.

While this path is recommended if the above requirements apply, AKS engineering and support can't help troubleshoot or diagnose modifications that render the node unavailable due to a custom deployed `DaemonSet`.

### Security issues and patching

If a security flaw is found in one or more of the managed components of AKS, the AKS team patches all affected clusters to mitigate the issue. Alternatively, the AKS team provides you with upgrade guidance.

For agent nodes affected by a security flaw, Microsoft notifies you with details on the impact and the steps to fix or mitigate the security issue.

### Node maintenance and access

Although you can sign in to agent nodes and change them, don't perform this operation. Changes can make a cluster unsupportable.

## Network ports, access, and NSGs

You can customize network security groups (NSGs) only on custom subnets. The following table shows where you can customize NSGs:

| Network scope | Can you customize NSGs? |
|---|---|
| Custom subnets | Yes |
| Managed subnets | No |
| Agent node NIC level | No |

AKS has egress requirements to specific endpoints. To control egress and ensure the necessary connectivity, see [limit egress traffic](limit-egress-traffic.md). For ingress, the requirements are based on the applications you deploy to the cluster.

## Stopped, deallocated, and Not Ready nodes

The following table summarizes what happens to an AKS cluster in each lifecycle state and the associated timeline:

| Scenario | Behavior | Timeline |
|---|---|---|
| Cluster stopped with `az aks stop` | State preserved, then deleted | Preserved 12 months |
| All nodes manually deallocated (IaaS APIs, Azure CLI, or portal) | Considered out of support, stopped by AKS, then normal preservation | Stopped after 30 days |
| Zero **Ready** nodes and zero **Running** VMs | Cluster stopped | After 30 days |
| Suspended subscription | Clusters stopped immediately, then deleted | Deleted after 90 days |
| Deleted subscription | Clusters deleted immediately | Immediate |

If you don't need your AKS workloads to run continuously, [stop the AKS cluster](start-stop-cluster.md#stop-an-aks-cluster), which stops all node pools and the control plane, and start it again when needed. Manually deallocating nodes by using the IaaS APIs, the Azure CLI, or the Azure portal isn't a supported way to stop a cluster.

AKS reserves the right to archive control planes configured out of support guidelines for periods of 30 days or more. AKS maintains backups of cluster `etcd` metadata and can reallocate the cluster on any PUT operation that brings it back into support, like an upgrade or scale to active agent nodes.

## Unsupported alpha and beta Kubernetes features

AKS supports stable and beta features within the upstream Kubernetes project, but not alpha features unless otherwise documented. The following table summarizes support by feature type:

| Feature type | Supported? | Notes |
|---|---|---|
| Stable upstream Kubernetes features | Yes | Fully supported. |
| Beta upstream Kubernetes features | Yes | Supported unless otherwise documented. |
| Alpha upstream Kubernetes features | No | Not supported unless otherwise documented. |
| AKS preview features and feature flags | Best-effort | Not for production. Business-hours support only. See [Preview features or feature flags](#preview-features-or-feature-flags). |

## Preview features or feature flags

For features and functionality that require extended testing and user feedback, Microsoft releases new preview features or features behind a feature flag. Consider these features as prerelease or beta features.

Preview features or feature-flag features aren't meant for production. Ongoing changes in APIs and behavior, bug fixes, and other changes can result in unstable clusters and downtime.

Features in public preview fall under **best effort** support, as these features are in preview and aren't meant for production. The AKS technical support teams provide support during business hours only. For more information, see [Azure Support FAQ](https://azure.microsoft.com/support/faq/).

## Upstream bugs and issues

Given the speed of development in the upstream Kubernetes project, bugs invariably arise. Some of these bugs can't be patched or worked around within the AKS system. Instead, bug fixes require larger patches to upstream projects (like Kubernetes, node or agent operating systems, and kernel). For components that Microsoft owns (like the Azure cloud provider), AKS and Azure personnel are committed to fixing issues upstream in the community.

When the root cause of a technical support issue is due to one or more upstream bugs, AKS support and engineering teams will:

- Identify and link the upstream bugs with any supporting details to help explain why this issue affects your cluster or workload. Customers receive links to the required repositories so they can watch the issues and see when a new release provides fixes.
- Provide potential workarounds or mitigation. If the issue can be mitigated, a [known issue](https://github.com/Azure/AKS/issues?q=is%3Aissue+is%3Aopen+label%3Aknown-issue) is filed in the AKS repository. The known-issue filing explains:
  - The issue, including links to upstream bugs.
  - The workaround and details about an upgrade or another persistence of the solution.
  - Rough timelines for the issue's inclusion, based on the upstream release cadence.

## Related content

- [AKS pricing tiers](free-standard-pricing-tiers.md)
- [Supported Kubernetes versions in AKS](supported-kubernetes-versions.md)
- [Long-term support for AKS](long-term-support.md)
- [Automatically upgrade an AKS cluster](auto-upgrade-cluster.md)
- [Automatically upgrade AKS node OS images](auto-upgrade-node-os-image.md)
- [Vulnerability management for AKS](concepts-vulnerability-management.md)
- [AKS node auto-repair](node-auto-repair.md)
- [Bring your own CNI (BYOCNI)](use-byo-cni.md)

<!-- INTERNAL LINKS -->
[add-ons]: integrations.md#add-ons
