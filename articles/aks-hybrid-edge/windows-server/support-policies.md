---
title: Support policies for AKS on Windows Server
description: Learn about AKS on Windows Server support policies, shared responsibility, and features that are in preview.
ms.topic: concept-article
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.lastreviewed: 05/03/2023
ms.reviewer: rbaziwane
ms.custom: windows-server

# Customer intent: As a cluster operator or developer, I want to understand what AKS components I need to manage, what components are managed and supported by Microsoft (including security patches), and networking and preview features for AKS.
# Intent: As an IT Pro, I want to understand the support policies associated with my AKS deployment, including security patches, networking, and preview features in AKS.
# Keyword: support policies AKS technical support control plane service updates
---

# Support policies for AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article provides details about technical support policies and limitations for AKS on Windows Server. The article also describes cluster node management, control plane components, third-party open-source components, and security or patch management.

## Service updates and releases

- Microsoft offers a support window of 1 year for each Kubernetes minor version, starting with the initial release date. During this period, AKS releases subsequent minor or patch versions to ensure ongoing support.  
- A Kubernetes cluster that operates on a deprecated minor version must be updated to a supported version to be eligible for support.
- Once a minor version is deprecated, any clusters still running on this version will continue to function. You can still perform operations such as scaling up or down, but AKS displays a warning during cluster operations.
- Once a minor version is deprecated, it's removed from the Microsoft servers. At that point, Kubernetes clusters using this version are unable to update Kubernetes or OS versions, and must be upgraded to the latest release. In some cases, this upgrade can also mean full re-deployment if the system is not in a healthy state.

For release information, see the [AKS release notes](https://github.com/Azure/aksArc/releases). For information about features in preview, see [AKS preview features](https://github.com/Azure/aksArc/tree/main/preview).

## Managed features in AKS

As an AKS user, you have limited customization and deployment options. However, you don't need to worry about or manage Kubernetes cluster control plane and installation directly. Base infrastructure-as-a-service (IaaS) cloud components, such as compute or networking components, allow you access to low-level controls and customization options.

By contrast, AKS provides a turnkey Kubernetes deployment that gives you the common set of configurations and capabilities you need for your cluster. With AKS, you get a partially managed control plane. The control plane contains all of the components and services you need to operate and provide Kubernetes clusters to end users. Microsoft maintains all Kubernetes components.

Microsoft maintains the following components through the management cluster and the associated virtual machine base images:

- `kubelet` or Kubernetes API servers.
- `etcd` or a compatible key-value store, providing Quality of Service (QoS), scalability, and runtime.
- DNS services (for example, `kube-dns` or CoreDNS).
- Kubernetes proxy or networking.
- Any other add-on or system component running in the `kube-system` namespace.

AKS isn't a Platform-as-a-Service (PaaS) solution. Some components, such as workload clusters, control plane, and worker nodes, have shared responsibility. Users must help maintain the Kubernetes cluster. User input is required, for example, to apply an operating system (OS) security patch or update to a newer Kubernetes version.

The services are *managed* in the sense that Microsoft and the AKS team provide the tooling that deploys the management cluster, control plane, and agent nodes for workload clusters. You can't alter these managed components. Microsoft limits customization to ensure a consistent and scalable user experience. For a fully customizable solution in the cloud, see the [AKS engine](https://github.com/Azure/aks-engine).

## Supported version policy

Kubernetes versions in AKS follow the [Kubernetes version policy](https://kubernetes.io/releases/version-skew-policy/).

AKS doesn't make any runtime (or other) guarantees for clusters outside of the supported versions list. "Outside of support" means that:

- Your cluster operates on a deprecated minor version. The version you're running is outside of the supported versions list.
- You are asked to upgrade the cluster to a supported version when requesting support.

For information about the supported Kubernetes versions, see [Supported Kubernetes versions](../supported-kubernetes-versions.md).

AKS follows the platform version support timeframes for those products. That is, AKS is not supported on unsupported versions of those products. For more information, see their support policies:

- [Windows Server 2019 Datacenter and above supported versions](/windows-server/get-started/windows-server-release-info)

## Shared responsibility

When a cluster is created, you define the Kubernetes agent nodes that AKS creates. Your workloads are executed on these nodes.

Because your agent nodes execute private code and store sensitive data, Microsoft Support has limited access to them. Microsoft Support can't sign in to execute commands on, or view logs for these nodes without your express permission or assistance. Any direct modification of the agent nodes by using any of the IaaS APIs renders the cluster unsupportable. Any modification done to the agent nodes must be done using Kubernetes-native mechanisms such as `Daemon Sets`.

Similarly, while you can add any metadata, such as tags and labels, to the cluster and nodes, changing any of the system-created metadata renders the cluster unsupported.

## AKS support coverage

Microsoft provides technical support for the following features and components:

- Connectivity to all Kubernetes components that the Kubernetes service provides and supports, such as the API server.
- Kubernetes control plane services (for example, Kubernetes control plane, API server, etcd, and coreDNS).
- Etcd data store.
- Integration with Azure Arc and the Azure Billing service.
- Questions or issues about customization of control plane components such as the Kubernetes API server, etcd, and coreDNS.
- Issues with networking, network access, and functionality. Issues could include DNS resolution, packet loss, and routing. Microsoft supports various networking scenarios:
  - Basic installation support for Flannel and Calico CNI. These CNIs are community driven and supported. Microsoft Support provides only basic installation and configuration support.
  - Connectivity to other Azure services and applications.
  - Ingress controllers, and ingress or load balancer configuration.
  - Network performance and latency.

> [!NOTE]
> Any cluster actions taken by Microsoft AKS support teams are made with user consent and assistance. Microsoft Support doesn't log into your cluster unless you configure access for the support engineer.

Microsoft doesn't provide technical support for the following areas:

- Questions about how to use Kubernetes. For example, Microsoft Support doesn't provide advice on how to create custom ingress controllers, use application workloads, or apply third-party or open-source software packages or tools.

  > [!NOTE]
  > Microsoft Support can advise on cluster functionality, customization, and tuning in AKS; for example, Kubernetes operations issues and procedures.

- Third-party open-source projects that aren't provided as part of the Kubernetes control plane or deployed when clusters are created in AKS. These projects might include Istio, Helm, Envoy, or others.

  > [!NOTE]
  > Microsoft can provide best-effort support for third-party open-source projects such as Helm. Where the third-party open-source tool integrates with Kubernetes or other AKS-specific bugs, Microsoft supports examples and applications from Microsoft documentation.

- Third-party closed-source software. This software can include security scanning tools and networking devices or software.
- Network customizations other than the ones listed in the [AKS documentation](../index.yml).

## AKS support coverage for agent nodes

### Microsoft responsibilities for AKS agent nodes

Microsoft and users share responsibility for Kubernetes agent nodes where:

- The base OS image required additions (such as monitoring and networking agents).
- The agent nodes receive OS patches automatically.
- Issues with the Kubernetes control plane components that run on the agent nodes are automatically remediated during the update cycle or when you redeploy an agent node. These components include:
  - `kube-proxy`
  - Networking tunnels that provide communication paths to the Kubernetes master components:
    - `kubelet`
    - `Moby` or `ContainerD`

> [!NOTE]
> If an agent node is not operational, AKS might restart individual components or the entire agent node. These automated restart operations provide auto-remediation for common issues.

### Customer responsibilities for AKS agent nodes

Microsoft provides patches and new images for your image nodes monthly, but doesn't automatically patch them by default. To keep your agent node OS and runtime components patched, you should keep a regular upgrade schedule or automate patching.

Similarly, AKS regularly releases new Kubernetes patches and minor versions. These updates can contain security or functionality improvements to Kubernetes. You're responsible for keeping your cluster's Kubernetes version updated according to the [AKS supported versions policy](../supported-kubernetes-versions.md).

### User customization of agent nodes

> [!NOTE]
> AKS agent nodes appear in Hyper-V as regular virtual machine resources. These virtual machines are deployed with a custom OS image, and supported and managed Kubernetes components. You cannot change the base OS image or do any direct customizations to these nodes using the Hyper-V APIs or resources. Any custom changes that are not done via the AKS-HCI API do not persist through an upgrade, scale, update, or reboot, and can render the cluster unsupported. Avoid performing changes to the agent nodes unless Microsoft Support directs you to make changes.

AKS manages the lifecycle and operations of agent node images on your behalf. Modifying the resources associated with the agent nodes is not supported. For example, customizing a virtual machine's network settings by manually changing configurations through the Hyper-V API or tools is not supported.

For workload-specific configurations or packages, you should use [Kubernetes daemon sets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

When you use Kubernetes privileged `daemon sets` and init containers, you can tune/modify or install third-party software on cluster agent nodes. For example, you can add custom security scanning software or update `sysctl` settings. While this path is recommended if the previous requirements apply, AKS engineering and support can't help with troubleshooting or diagnosing modifications that render the node unavailable because of a custom-deployed `daemon set`.

### Security issues and patching

If a security flaw is found in one or more of the managed components of AKS, the AKS team patches all affected OS images to mitigate the issue, and the team gives users upgrade guidance.

For agent nodes affected by a security flaw, Microsoft notifies you with details about the impact and the steps to fix or mitigate the security issue. Usually, the steps include a node image upgrade or a cluster patch upgrade.

### Node maintenance and access

Although you can sign in and change agent nodes, this operation is discouraged because changes can make a cluster unsupportable.

## Network ports, IP pools, and access

You can only customize network settings using AKS defined subnets. You can't customize network settings at the NIC level of the agent nodes. AKS has egress requirements for specific endpoints, to control egress and ensure the necessary connectivity. For more information, see [AKS system requirements](system-requirements.md).

## Stopped or disconnected clusters

As previously described, manually de-allocating all cluster nodes via the Hyper-V APIs, CLI, or MMC renders the cluster out of support.

Clusters that are stopped for more than 90 days can no longer be updated. The control planes for clusters in this state are out of support after 30 days, and they can't be updated to the latest version.

The management cluster in AKS must be able to connect to Azure via HTTPS outbound traffic to well-known Azure endpoints at least every 30 days to maintain day 2 operations such as upgrade and node pool scaling. If the management cluster is disconnected within the 30 day period, workloads continue to run and work as expected until the management cluster and or Windows Server re-connect and synchronize to Azure. Once re-connected, all day 2 operations should recover and continue as expected.

If the cluster is running on Windows Server 2019 or Windows Server 2022, the underlying host platform does not have the 30-day recurring connection requirement.

> [!NOTE]
> The start/end of the 30-day period might be different from the validity period on AKS and Windows Server. Manually stopping or de-allocating all cluster nodes via the Hyper-V APIs/CLI/MMC for prolonged periods greater than 30 days and outside of regular maintenance procedures renders the cluster out of support.

## Deleted or suspended subscription

If your Azure subscription is suspended or deleted, your AKS cluster(s) are out of support after 60 days, unless the subscription is reinstated before the 60-day limit is reached. All other limitations described previously also apply. Once the subscription is deleted, the cluster connection to Azure cannot be recovered and AKS must be re-deployed to be able to reconnect to Azure.

## Unsupported preview and beta Kubernetes features

AKS only supports stable and beta features in the upstream Kubernetes project. Unless otherwise documented, AKS doesn't support any preview feature that is available in the upstream Kubernetes project.

## Preview features or feature flags

For features and functionality that require extended testing and user feedback, Microsoft releases new preview features or features behind a feature flag. Consider these prerelease or beta features. Preview features or feature-flag features aren't meant for production. Ongoing changes in APIs and behavior, bug fixes, and other changes can result in unstable clusters and downtime.

Features in preview receive "best effort" support, as these features are in preview and not meant for production. These features are supported by the AKS technical support teams during business hours only. For more information, see the [Azure support FAQ](https://azure.microsoft.com/support/faq/).

## Upstream bugs and issues

Given the speed of development in the upstream Kubernetes project, bugs invariably arise. Some of these bugs can't be patched or worked around within the AKS system. Instead, bug fixes require larger patches to upstream projects (such as Kubernetes, node or agent operating systems, and kernel). For components that Microsoft owns (such as the cluster API providers), AKS and Azure personnel are committed to fixing issues upstream in the community.

When a technical support issue is root-caused by one or more upstream bugs, AKS support and engineering teams will do the following:

- Identify and link the upstream bugs with any supporting details to help explain why this issue affects your cluster or workload. Customers receive links to the required repositories so they can watch the issues and see when a new release will provide fixes.
- Provide potential workarounds or mitigation. If the issue can be mitigated, a [known issue is filed in the AKS on Windows Server repository](https://github.com/Azure/aksArc/issues?q=is%3Aopen+is%3Aissue+label%3Aknown-issue). The known-issue filing explains:
  - The issue, including links to upstream bugs.
  - The workaround and details about an upgrade or another option for the solution.
  - Rough timelines for the issue's inclusion, based on the upstream release cadence.

## Next steps

- [Open a support ticket](../local/hyperconverged/help-support.md)
- [Learn more about resource limits and scaling](concepts-support.md)
