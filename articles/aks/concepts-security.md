---
title: Concepts - Security in Azure Kubernetes Services (AKS)
description: Learn about security in Azure Kubernetes Service (AKS), including identity and authorization, network security, workload protection, and how security defaults differ between AKS Automatic and AKS Standard.
author: shashankbarsin
ms.service: azure-kubernetes-service
ms.topic: concept-article
ms.subservice: aks-security
ms.date: 11/10/2025
ms.author: shasb
# Customer intent: "As a cloud security engineer, I want to implement comprehensive security practices for Azure Kubernetes Service, so that I can safeguard applications and clusters against vulnerabilities and unauthorized access throughout the development and deployment pipeline."
---

# Security concepts for applications and clusters in Azure Kubernetes Service (AKS)

Container security protects the entire end-to-end pipeline from build to the application workloads running in Azure Kubernetes Service (AKS).

The Secure Supply Chain includes the build environment and registry.

Kubernetes includes security components, such as _pod security standards_ and _Secrets_. Azure includes components like Microsoft Entra ID, Microsoft Defender for Containers, Azure Policy, Azure Key Vault, network security groups, and orchestrated cluster upgrades. AKS combines these security components to:

- Provide a complete authentication and authorization story.
- Apply AKS built-in Azure Policy to secure your applications.
- End-to-end insight from build through your application with Microsoft Defender for Containers.
- Keep your AKS cluster running the latest OS security updates and Kubernetes releases.
- Provide secure pod traffic and access to sensitive credentials.

AKS supports two cluster modes: [AKS Automatic](./intro-aks-automatic.md) and AKS Standard. The security concepts in this article apply to both modes unless otherwise noted. AKS Automatic includes a hardened security baseline with several controls preconfigured by default, while AKS Standard provides more configuration flexibility.

This article introduces the core concepts that secure your applications in AKS.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Build security

Build security is the entry point for your secure supply chain. Before images are promoted to deployment environments, run static analysis and vulnerability and compliance assessment in CI.

In both AKS modes, use risk-based triage rather than blocking all builds on any vulnerability. Prioritize remediation using vendor status and severity, and apply grace periods for non-exploitable or time-bound exceptions.

AKS Automatic helps reduce downstream configuration drift by starting clusters from a hardened baseline with preconfigured security controls. This makes build-time validation of image quality and policy compliance even more important, because trusted images are more consistently promoted into a secure runtime baseline.

AKS Standard provides more cluster-level flexibility, so build pipelines should explicitly enforce your organization baseline for image provenance, vulnerability thresholds, and policy gates before deployment.

## Registry security

Registry security verifies that only trusted and compliant images are available for deployment and helps detect drift after build. Assess image vulnerability state in the registry continuously, not only at build time. Registry scanning catches newly disclosed vulnerabilities and images that bypassed approved build paths. Use image signing and verification, such as [Notary V2](https://github.com/notaryproject/notaryproject), to ensure workloads are deployed from trusted sources with verifiable provenance.

For AKS Automatic, where several runtime security capabilities are preconfigured, registry controls remain a critical upstream gate to keep the runtime supply chain clean. For AKS Standard, apply the same registry controls and align them with your cluster admission and policy configuration to enforce trusted image use consistently.

## Cluster security

In AKS, the Kubernetes primary components are part of the managed service provided, managed, and maintained by Microsoft. Each AKS cluster has its own single-tenanted, dedicated Kubernetes primary to provide the API Server, Scheduler, etc. For more information, see [Vulnerability management for Azure Kubernetes Service][microsoft-vulnerability-management-aks].

By default, the Kubernetes API server uses a public IP address and a fully qualified domain name (FQDN). You can limit access to the API server endpoint using [authorized IP ranges][authorized-ip-ranges]. You can also create a fully [private cluster][private-clusters] to limit API server access to your virtual network.

For AKS Automatic, API server virtual network integration is preconfigured as part of the default security posture. In AKS Standard, the same capability is available and can be enabled based on your network design and security requirements.

You can control access to the API server using Kubernetes role-based access control (Kubernetes RBAC) and Azure RBAC. In AKS Automatic, Azure RBAC for Kubernetes authorization is preconfigured. In AKS Standard, you can choose and configure the authorization model that best fits your environment. For more information, see [Microsoft Entra integration with AKS][aks-aad].

### AKS Automatic security defaults

AKS Automatic includes a hardened baseline with security controls preconfigured by default, including:

- Azure RBAC for Kubernetes authorization
- API server virtual network integration
- Workload identity and OIDC issuer
- Deployment safeguards and baseline Pod Security Standards in enforce mode
- Image cleaner for removing unused vulnerable images
- Managed system node pool security restrictions that preserve boundaries between customer workloads and AKS-managed infrastructure

AKS Standard supports these capabilities with greater implementation flexibility, but they might require explicit enablement and operational management.

## Node security

AKS nodes are Azure virtual machines (VMs). In AKS Standard, you manage node pool configuration and lifecycle options. In AKS Automatic, AKS manages system node pools and core system components on your behalf, including scaling and upgrades, with security restrictions for managed system infrastructure.

Linux nodes run optimized versions of Ubuntu or Azure Linux. Windows Server nodes run an optimized Windows Server release using the `containerd` container runtime.

When an AKS cluster is created or scaled up, the nodes are automatically deployed with the latest OS security updates and configurations.

> [!NOTE]
> AKS clusters running:
>
> - Kubernetes version 1.19 and higher: Linux node pools use `containerd` as its container runtime. Windows Server 2019 and Windows Server 2022 node pools use `containerd` as its container runtime. For more information, see [Add a Windows Server node pool with `containerd`][aks-add-np-containerd].
> - Kubernetes version 1.19 and earlier: Linux node pools use Docker as its container runtime.

For more information about the security upgrade process for Linux and Windows worker nodes, see [Security patching nodes][aks-vulnerability-management-nodes].

AKS clusters running Azure Generation 2 VMs include support for [Trusted Launch][trusted-launch]. This feature protects against advanced and persistent attack techniques by combining technologies that you can enable independently, like secure boot and a virtualized version of the trusted platform module (vTPM). Administrators can deploy AKS worker nodes with verified and signed bootloaders, OS kernels, and drivers to ensure integrity of the entire boot chain of the underlying VM.

### Container and security optimized OS options

Azure Container Linux (ACL) is an immutable, container-optimized OS for AKS. ACL is derived from the Flatcar Container Linux project, and builds on Flatcar's proven, container-first immutable design while layering in Azure Linux packages, servicing, and platform integration. This allows ACL to stay closely aligned with upstream Flatcar innovation while meeting Azure's production, security, and compliance requirements. To learn more about Flatcar Container Linux, see the [Flatcar documentation](https://www.flatcar.org/).

ACL is generally available (GA) as an OS option on AKS starting AKS v1.34. You can deploy ACL node pools in a new AKS cluster, add ACL node pools to your existing clusters, and migrate existing Linux node pools to ACL.

For more information about ACL, see [Azure Container Linux (ACL) for AKS overview](./azure-container-linux-overview.md).

### Node authorization

Node authorization is a special-purpose authorization mode that specifically authorizes kubelet API requests to protect against East-West attacks.  Node authorization is enabled by default on AKS 1.24 + clusters.

### Node deployment

Nodes are deployed onto a private virtual network subnet, with no public IP addresses assigned. For troubleshooting and management purposes, SSH is enabled by default and only accessible using the internal IP address. Disabling SSH during cluster and node pool creation, or for an existing cluster or node pool, is in preview. See [Manage SSH access][manage-ssh-access] for more information. 

### Node storage

To provide storage, the nodes use Azure Managed Disks. For most VM node sizes, Azure Managed Disks are Premium disks backed by high-performance SSDs. The data stored on managed disks is automatically encrypted at rest within the Azure platform. To improve redundancy, Azure Managed Disks are securely replicated within the Azure datacenter.

### Hostile multitenant workloads

Currently, Kubernetes environments aren't safe for hostile multitenant usage. Extra security features, like *Pod Security Policies* or Kubernetes RBAC for nodes, efficiently block exploits. For true security when running hostile multitenant workloads, only trust a hypervisor. The security domain for Kubernetes becomes the entire cluster, not an individual node.

For these types of hostile multitenant workloads, you should use physically isolated clusters. For more information on ways to isolate workloads, see [Best practices for cluster isolation in AKS][cluster-isolation].

### Compute isolation

Because of compliance or regulatory requirements, certain workloads may require a high degree of isolation from other customer workloads. For these workloads, Azure provides:

- [Kernel isolated containers][azure-confidential-containers] to use as the agent nodes in an AKS cluster. These containers are completely isolated to a specific hardware type and isolated from the Azure Host fabric, the host operating system, and the hypervisor. They're dedicated to a single customer. Select [one of the isolated VMs sizes][isolated-vm-size] as the **node size** when creating an AKS cluster or adding a node pool.
- [Confidential Containers][confidential-containers] (preview), also based on Kata Confidential Containers, encrypts container memory and prevents data in memory during computation from being in clear text, readable format, and tampering. It helps isolate your containers from other container groups/pods, and VM node OS kernel. Confidential Containers (preview) uses hardware based memory encryption (SEV-SNP).
- [Pod Sandboxing][pod-sandboxing] (preview) provides an isolation boundary between the container application and the shared kernel and compute resources (CPU, memory, and network) of the container host.

## Network security

For connectivity and security with on-premises networks, you can deploy your AKS cluster into existing Azure virtual network subnets. These virtual networks connect back to your on-premises network using Azure Site-to-Site VPN or Express Route. Define Kubernetes ingress controllers with private, internal IP addresses to limit services access to the internal network connection.

In AKS Automatic, managed virtual network capabilities and core ingress and egress defaults are preconfigured to provide a secure baseline. In AKS Standard, networking models and egress/ingress controls are more flexible and should be selected based on your security architecture.

### Azure network security groups

To filter virtual network traffic flow, Azure uses network security group rules. These rules define the source and destination IP ranges, ports, and protocols allowed or denied access to resources. Default rules are created to allow TLS traffic to the Kubernetes API server. You create services with load balancers, port mappings, or ingress routes. AKS automatically modifies the network security group for traffic flow.

If you provide your own subnet for your AKS cluster (whether using Azure CNI or Kubenet), **do not** modify the NIC-level network security group managed by AKS. Instead, create more subnet-level network security groups to modify the flow of traffic. Make sure they don't interfere with necessary traffic managing the cluster, such as load balancer access, communication with the control plane, or [egress][aks-limit-egress-traffic].

### Kubernetes network policy

To limit network traffic between pods in your cluster, AKS offers support for [Kubernetes network policies][network-policy]. With network policies, you can allow or deny specific network paths within the cluster based on namespaces and label selectors.

## Application security

To protect pods running on AKS, consider [Microsoft Defender for Containers][microsoft-defender-for-containers] to detect and restrict cyber attacks against your applications running in your pods. Run continual scanning to detect drift in the vulnerability state of your application and implement a "blue/green/canary" process to patch and replace the vulnerable images.

In AKS Automatic, workload identity and OIDC issuer are preconfigured to simplify secure workload access to Azure services. In AKS Standard, these capabilities are available and can be enabled as part of your baseline security posture.

## Secure container access to resources

In the same way that you should grant users or groups the minimum privileges required, you should also limit containers to only necessary actions and processes. To minimize the risk of attack, avoid configuring applications and containers that require escalated privileges or root access. Built-in Linux security features such as _AppArmor_ and _seccomp_ are recommended as [best practices][security-best-practices] to [secure container access to resources][security-container-access].

## Kubernetes Secrets

With a Kubernetes _Secret_, you inject sensitive data into pods, such as access credentials or keys.

1. Create a Secret using the Kubernetes API.
1. Define your pod or deployment and request a specific Secret.
    - Secrets are only provided to nodes with a scheduled pod that requires them.
    - The Secret is stored in _tmpfs_, not written to disk.
1. When you delete the last pod on a node requiring a Secret, the Secret is deleted from the node's _tmpfs_.
   - Secrets are stored within a given namespace and are only accessible from pods within the same namespace.

Using Secrets reduces the sensitive information defined in the pod or service YAML manifest. Instead, you request the Secret stored in Kubernetes API Server as part of your YAML manifest. This approach only provides the specific pod access to the Secret.

> [!NOTE]
> The raw secret manifest files contain the secret data in base64 format. For more information, see the [official documentation][secret-risks]. Treat these files as sensitive information, and never commit them to source control.

Kubernetes secrets are stored in _etcd_, a distributed key-value store. AKS allows [encryption at rest of secrets in etcd using customer managed keys][etcd-encryption-cmk].

## Related content

To get started with securing your AKS clusters, see [Upgrade an AKS cluster][aks-upgrade-cluster].

If you're evaluating mode-specific defaults and operational responsibilities, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

For associated best practices, see [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security] and [Best practices for pod security in AKS][developer-best-practices-pod-security].

For more information on core Kubernetes and AKS concepts, see:

- [Kubernetes / AKS clusters and workloads][aks-concepts-clusters-workloads]
- [Kubernetes / AKS identity][aks-concepts-identity]
- [Kubernetes / AKS virtual networks][aks-concepts-network]
- [Kubernetes / AKS storage][aks-concepts-storage]
- [Kubernetes / AKS scale][aks-concepts-scale]

<!-- LINKS - External -->
[secret-risks]: https://kubernetes.io/docs/concepts/configuration/secret/#risks

<!-- LINKS - Internal -->
[microsoft-defender-for-containers]: /azure/defender-for-cloud/defender-for-containers-introduction
[azure-confidential-containers]: /azure/confidential-computing/confidential-containers
[confidential-containers]: confidential-containers-overview.md
[pod-sandboxing]: use-pod-sandboxing.md
[isolated-vm-size]: /azure/virtual-machines/isolation
[aks-upgrade-cluster]: upgrade-cluster.md
[aks-aad]: ./managed-azure-ad.md
[aks-add-np-containerd]: create-node-pools.md
[aks-concepts-clusters-workloads]: concepts-clusters-workloads.md
[aks-concepts-identity]: concepts-identity.md
[aks-concepts-scale]: concepts-scale.md
[aks-concepts-storage]: concepts-storage.md
[aks-concepts-network]: concepts-network.md
[aks-limit-egress-traffic]: limit-egress-traffic.md
[cluster-isolation]: operator-best-practices-cluster-isolation.md
[operator-best-practices-cluster-security]: operator-best-practices-cluster-security.md
[developer-best-practices-pod-security]:developer-best-practices-pod-security.md
[authorized-ip-ranges]: api-server-authorized-ip-ranges.md
[private-clusters]: private-clusters.md
[network-policy]: use-network-policies.md
[microsoft-vulnerability-management-aks]: concepts-vulnerability-management.md
[aks-vulnerability-management-nodes]: concepts-vulnerability-management.md#worker-nodes
[manage-ssh-access]: manage-ssh-node-access.md
[trusted-launch]: use-trusted-launch.md
[security-best-practices]: /azure/aks/operator-best-practices-cluster-security
[security-container-access]: ./secure-container-access.md
[etcd-encryption-cmk]: use-kms-etcd-encryption.md
