---
title: Support Policies for AKS on Azure Local
description: Learn about technical support policies, limitations, shared responsibilities, and version support for Azure Kubernetes Service (AKS) on Azure Local clusters.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.reviewer: sumsmith
ms.lastreviewed: 06/30/2025
ms.custom: hyperconverged

---

# Support policies for AKS on Azure Local

This article provides details about technical support policies and limitations for AKS on Azure Local.

## Service updates and releases

AKS on Azure Local adheres to the Kubernetes support calendar and releases Kubernetes versions to ensure that AKS on Azure Local customers can always operate on a supported version of Kubernetes.

A Kubernetes cluster that operates on a deprecated minor version must be updated to a supported version to be eligible for support. Once a minor version is deprecated, any Kubernetes clusters still running on this version continue to function. You can still perform operations such as scaling up or down.

Once a minor version is deprecated, it's removed from the Microsoft servers. At that point, Kubernetes clusters using this version are unable to update Kubernetes or OS versions and must be upgraded to the latest release. In some cases, this upgrade can also mean full redeployment if the system is not in a healthy state.

For release information, see the [AKS on Azure Local release notes](/azure/aks/aksarc/aks-whats-new-local).

## Managed features in AKS

As an AKS on Azure Local user, you have limited customization and deployment options. However, you don't need to worry about or manage the Kubernetes cluster control plane and installation directly. Base infrastructure-as-a-service (IaaS) cloud components, such as compute or networking components, provide you access to low-level controls and customization options.

By contrast, AKS provides a turnkey Kubernetes deployment that gives you the common set of configurations and capabilities you need for your cluster. With AKS, you get a partially managed control plane. The control plane contains all of the components and services you need to operate and provide Kubernetes clusters to end users. Microsoft maintains all Kubernetes components.

Microsoft maintains the following components through the Arc Resource Bridge and the associated virtual machine base images for AKS clusters:

- **kubelet** or Kubernetes API servers.
- **etcd** or a compatible key-value store, providing Quality of Service (QoS), scalability, and runtime.
- DNS services (for example, **kube-dns** or CoreDNS).
- Kubernetes proxy or networking.
- Any other add-on or system component running in the kube-system namespace.

AKS isn't a Platform-as-a-Service (PaaS) solution, and AKS clusters on Azure Local have shared responsibility. Users must help maintain the Kubernetes cluster. User input is required, for example, to apply an operating system (OS) security patch or update to a newer Kubernetes version.

The services are *managed* in the sense that Microsoft and the AKS team provide the tooling that deploys the Kubernetes components such as control plane nodes and nodepools for AKS clusters. Microsoft limits customization to ensure a consistent and scalable user experience.

## Supported version policy

Kubernetes versions in AKS follow the [Kubernetes version policy](https://kubernetes.io/releases/version-skew-policy/).

AKS doesn't make any runtime or other guarantees for clusters that use unsupported versions. "Unsupported" means that:

- Your cluster uses a deprecated minor version. The version you're running isn't in the supported versions list.
- You need to upgrade the cluster to a supported version when you request support.

For information about supported Kubernetes versions, see [Supported Kubernetes versions](../../supported-kubernetes-versions.md).

AKS follows the platform version support timeframes for those products. AKS isn't supported on unsupported versions of those products. For more information, see [Azure Local supported versions information](/azure/azure-local/release-information-23h2).

## Shared responsibility

When you create an AKS cluster, you define the Kubernetes node pools that AKS creates. Your workloads run on these node pools.

Because your node pools run private code and store sensitive data, Microsoft Support has limited access to them. Microsoft Support can't sign in to run commands on these nodes or view logs without your express permission or assistance. Any direct modification of the agent nodes by using any of the IaaS APIs makes the cluster unsupportable. You must use Kubernetes-native mechanisms, such as **Daemon Sets**, to modify the node pools.

Similarly, while you can add metadata, such as tags and labels, to the AKS cluster and nodes, changing any system-created metadata makes the AKS cluster unsupported.

## AKS support coverage

Microsoft provides technical support for the following features and components:

- Connectivity to all Kubernetes components that the Kubernetes service provides and supports, such as the API server.
- Kubernetes control plane services, such as the Kubernetes control plane, API server, etcd, and coreDNS.
- Etcd data store.
- Integration with Azure Arc and Arc enabled Kubernetes extensions.
- Questions or issues about customization of control plane components, such as the Kubernetes API server, etcd, and coreDNS.
- Issues with networking, network access, and functionality. These issues can include DNS resolution, packet loss, and routing.

Microsoft supports various networking scenarios:

- Basic installation support for Calico CNI. The Calico CNI is community driven and supported. Microsoft Support provides only basic installation support.
- Connectivity to other Azure services and applications.
- Network performance and latency.

> [!NOTE]
> Microsoft AKS support teams take any cluster actions with your consent and assistance. Microsoft Support doesn't log in to your AKS cluster unless you configure access for the support engineer.

Microsoft doesn't provide technical support for questions about how to use Kubernetes. For example, Microsoft Support doesn't provide advice on:

- How to create custom ingress controllers.
- How to use application workloads.
- How to apply third-party or open-source software packages or tools.
- Third-party open-source projects that aren't provided as part of the Kubernetes control plane or deployed when AKS clusters are created. These projects might include Istio, Helm, Envoy, or others.
- Third-party closed-source software. This software can include security scanning tools and networking devices or software.
- Network customizations other than the ones listed in the [AKS documentation](network-system-requirements.md).

> [!NOTE]
> Microsoft Support can advise on cluster functionality, customization, and tuning in AKS. For example, Kubernetes operations issues and procedures.

> [!NOTE]
> Microsoft can provide best-effort support for third-party open-source projects such as Helm. When the third-party open-source tool integrates with Kubernetes or other AKS-specific bugs, Microsoft supports examples and applications from Microsoft documentation.

## AKS support coverage for node pools

This section describes the support coverage for AKS node pools. Node pools are the Kubernetes agent nodes that run your workloads.

### Microsoft responsibilities for AKS node pools

Microsoft and users share responsibility for Kubernetes agent nodes where:

- The base OS image requires additions, such as monitoring and networking agents.
- The agent nodes receive OS patches automatically.
- The update cycle or when you redeploy an agent node automatically remediates issues with the Kubernetes control plane components that run on the agent nodes. These components include kube-proxy, and more.
- Networking tunnels provide communication paths to the Kubernetes primary components, including:
  - kubelet
  - ContainerD

> [!NOTE]
> If a node pool isn't operational, AKS might restart individual components or the entire node pool. These automated restart operations provide self-remediation for common issues.

### Customer responsibilities for AKS node pools

AKS regularly releases new Kubernetes patches and minor versions. These updates can contain security or functionality improvements to Kubernetes. You're responsible for keeping your cluster's Kubernetes version and node pool versions updated according to the [AKS supported versions policy](/azure/aks/aksarc/aks-whats-new-local).

### User customization of node pools

> [!NOTE]
> AKS agent nodes appear in Hyper-V as regular virtual machine resources. These virtual machines use a custom OS image and include supported and managed Kubernetes components. You can't change the base OS image or make direct customizations to these nodes by using the Hyper-V APIs or resources. Any custom changes that you don't make through the AKS API don't persist through an upgrade, scale, update, or reboot. These changes can also make the Kubernetes cluster unsupported. Avoid making changes to the agent nodes unless Microsoft Support directs you to do so.

AKS manages the lifecycle and operations of node pool images for you. You can't modify the resources associated with the node pools. For example, you can't customize a virtual machine's network settings by manually changing configurations through the Hyper-V API or tools.

For Kubernetes workload-specific configurations or packages, use [Kubernetes daemon sets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

By using Kubernetes privileged daemon sets and init containers, you can tune or modify cluster agent nodes, or install third-party software. For example, you can add custom security scanning software or update sysctl settings. Although this approach is recommended, AKS engineering and support can't help with troubleshooting or diagnosing modifications that make the node unavailable because of a custom-deployed daemon set.

### Security issues and patching

If the AKS team finds a security flaw in one or more managed components of AKS, they patch all affected OS images to mitigate the issue and provide upgrade guidance.

For node pools affected by a security flaw, Microsoft notifies you with details about the impact and the steps to fix or mitigate the security issue. Usually, the steps include a cluster patch upgrade.

### Node maintenance and access

Although you can sign in to your Azure Local clusters and change the node pool VMs, avoid this operation because changes can make an AKS cluster unsupportable.

You can customize network settings only by using AKS-defined logical networks. You can't customize network settings at the NIC level of the node pools. AKS has egress requirements for specific endpoints to control egress and ensure the necessary connectivity. For more information, see [AKS system requirements](network-system-requirements.md).

## Stopped or disconnected AKS clusters

As previously described, manually deallocating all cluster nodes by using the Hyper-V APIs, CLI, or MMC renders the cluster unsupported.

You can't update clusters that are stopped for more than 30 days. The control planes for AKS clusters in this state are unsupported after 30 days, and you can't update them to the latest Kubernetes version. For more information, see the [AKS connectivity modes.](/azure/aks/aksarc/connectivity-modes)

## Deleted or suspended subscription

If your Azure subscription is suspended or deleted, your AKS clusters are out of support after 60 days, unless you reinstate the subscription before the 60-day limit. All other previously described limitations also apply. Once the subscription is deleted, you can't recover the cluster connection to Azure and must redeploy Azure Local and AKS.

## Unsupported preview and beta Kubernetes features

AKS only supports stable and beta features in the upstream Kubernetes project. Unless otherwise documented, AKS doesn't support any preview feature that's available in the upstream Kubernetes project.

## Preview features or feature flags

For features and functionality that require extended testing and user feedback, Microsoft releases new preview features or features behind a feature flag. Consider these prerelease or beta features. Preview features or feature-flag features aren't meant for production. Ongoing changes in APIs and behavior, bug fixes, and other changes can result in unstable clusters and downtime.

AKS provides "best effort" support for features in preview, as these features aren't meant for production. The AKS technical support teams support these features during business hours only. For more information, see the [Azure support FAQ](https://azure.microsoft.com/support/faq/).

## Upstream bugs and issues

Given the speed of development in the upstream Kubernetes project, bugs inevitably occur. Some of these bugs can't be patched or worked around within the AKS system. Instead, bug fixes require larger patches to upstream projects, such as Kubernetes, node or agent operating systems, and kernel. For components that Microsoft owns, such as the cluster API providers for Azure Local, AKS and Azure personnel are committed to fixing issues upstream in the community.

When an upstream bug causes a technical support issue, the AKS support and engineering teams do the following:

- Identify and link the upstream bugs with any supporting details to help explain why this issue affects your cluster or workload. You receive links to the required repositories, so you can watch the issues and see when a new release provides fixes.
- Provide potential workarounds or mitigation. If the issue can be mitigated, a [known issue is filed in the AKS on Azure Local and Windows Server repository](https://github.com/Azure/aksArc/issues?q=is%3Aopen+is%3Aissue+label%3Aknown-issue). The known issue filing explains:
  - The issue, including links to upstream bugs.
  - The workaround and details about an upgrade or another option for the solution.
  - Rough timelines for the issue's inclusion, based on the upstream release cadence.

A troubleshooting guidance article is then published and linked to from [the general troubleshooting page](aks-troubleshoot.md).

## Next steps

- [Open a support ticket](help-support.md)
- [Learn more about resource limits and scaling](../../windows-server/concepts-support.md)
