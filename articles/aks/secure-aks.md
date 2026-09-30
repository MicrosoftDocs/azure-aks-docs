---
title: Secure your Azure Kubernetes Service (AKS) deployment
description: Learn how to secure Azure Kubernetes Service (AKS), with best practices for protecting your clusters, nodes, workloads, and data.
author: msmbaldwin
ms.author: mbaldwin
ms.service: azure-kubernetes-service
ms.topic: best-practice
ms.custom: horz-security
ms.date: 09/11/2026
ai-usage: ai-generated
---

# Secure your Azure Kubernetes Service (AKS) deployment

Azure Kubernetes Service (AKS) provides a managed Kubernetes environment for deploying and operating containerized applications. Microsoft manages the Kubernetes control plane, while you're responsible for securing the workloads, node configuration, networking, identity, and data in your clusters. When you deploy AKS, it's important to follow security best practices to protect this shared surface across the cluster lifecycle.

This article provides security recommendations to help protect your AKS deployment. Many of these controls are preconfigured in [AKS Automatic](intro-aks-automatic.md), which starts clusters from a hardened baseline, and are available for you to enable and manage in AKS Standard. For the concepts behind these controls, including how AKS security works across the build-to-runtime pipeline, see [Security concepts for applications and clusters in AKS](concepts-security.md).

[!INCLUDE [Security horizontal Zero Trust statement](~/reusable-content/ce-skilling/azure/includes/security/zero-trust-security-horizontal.md)]

## Service-specific security

AKS combines Kubernetes security primitives with Azure platform controls. The following recommendations address hardening concerns unique to running a managed Kubernetes cluster, including node integrity, image provenance, and workload isolation.

### Cluster and node hardening

- **Keep clusters on a supported Kubernetes version with automatic cluster upgrades**: Enroll clusters in an auto-upgrade channel so the control plane and node pools receive Kubernetes patches that fix known vulnerabilities without manual intervention. For more information, see [Automatically upgrade an AKS cluster](auto-upgrade-cluster.md).
- **Apply node OS security updates automatically**: Configure the node OS auto-upgrade channel so nodes receive Linux and Windows OS security patches on a defined cadence. For more information, see [Automatically upgrade AKS cluster node operating system images](auto-upgrade-node-os-image.md).
- **Enforce Pod Security Admission standards**: Apply the baseline or restricted Pod Security Standards at the namespace level to prevent privileged pods, host namespace sharing, and unsafe volume mounts. For more information, see [Secure your pods in AKS](developer-best-practices-pod-security.md).
- **Deploy FIPS-enabled node pools for regulated workloads**: Enable FIPS-enabled node pools, which use FIPS 140-3 validated cryptographic modules, when workloads must meet requirements such as FedRAMP compliance. For more information, see [Enable Federal Information Process Standard (FIPS) for AKS node pools](enable-fips-nodes.md).
- **Don't run hostile multitenant workloads on a shared cluster**: A standard Kubernetes cluster isn't a hard security boundary between untrusted tenants, because the security domain is the entire cluster rather than an individual node. For workloads that require strong isolation, use physically isolated clusters, isolated VM node sizes, or pod sandboxing. For more information, see [Best practices for cluster isolation in AKS](operator-best-practices-cluster-isolation.md).

### Container image and supply chain security

- **Restrict deployments to trusted container registries**: Use the Azure Policy add-on to enforce that pods can pull images only from approved registries, such as your private Azure Container Registry, so untrusted public images can't run in the cluster. For more information, see [Secure your AKS clusters with Azure Policy](use-azure-policy.md).
- **Remove unused vulnerable images with Image Cleaner**: Enable Image Cleaner to automatically remove stale images from nodes and reduce the attack surface left by vulnerable images. For more information, see [Use Image Cleaner to clean up vulnerable images on AKS](image-cleaner.md).
- **Scan registries and running workloads with Microsoft Defender for Containers**: Detect vulnerable images and misconfigurations across your registry and clusters before and after deployment. For more information, see [Overview of Microsoft Defender for Containers](/azure/defender-for-cloud/defender-for-containers-introduction).

## Network security

By default, the AKS API server is reachable over a public endpoint, and cluster egress is unrestricted. Restricting both inbound access to the control plane and outbound traffic from workloads is among the most effective changes you can make to reduce your cluster's network attack surface.

- **Deploy a private cluster to remove the public API server endpoint**: Create a private cluster so the Kubernetes API server is reachable only from your virtual network over a private endpoint. For more information, see [Create a private Azure Kubernetes Service (AKS) cluster](private-clusters.md).
    - If you can't use a fully private cluster, restrict the public API server endpoint to known addresses with authorized IP ranges. For more information, see [Secure access to the API server using authorized IP address ranges](api-server-authorized-ip-ranges.md).
- **Integrate the API server with your virtual network**: Use API server virtual network integration so control plane traffic stays on a private subnet without requiring tunneling components. For more information, see [Create an AKS cluster with API server virtual network integration](api-server-vnet-integration.md).
- **Enforce network policies to control pod-to-pod traffic**: Apply Kubernetes network policies to restrict east-west traffic between pods to only what your workloads require. For more information, see [Secure traffic between pods by using network policies in AKS](use-network-policies.md).
- **Restrict cluster egress traffic**: Set a user-defined outbound type and route egress through Azure Firewall to filter and inspect the destinations your workloads can reach. For more information, see [Control egress traffic for cluster nodes in AKS](limit-egress-traffic.md).
- **Filter outbound traffic by fully qualified domain name**: Use FQDN-based filtering in Advanced Container Networking Services to allow egress only to approved domains. For more information, see [FQDN filtering for Advanced Container Networking Services](container-network-security-fqdn-filtering-concepts.md).

## Identity and access management

AKS authenticates cluster and workload identities through Microsoft Entra ID and authorizes access through Azure RBAC and Kubernetes RBAC. Use managed identities and Entra-backed authorization instead of static credentials or standalone Kubernetes accounts.

- **Use a managed identity for the cluster**: Configure the cluster to use a managed identity so AKS accesses Azure resources without static service principal credentials that you have to rotate. For more information, see [Use a managed identity in Azure Kubernetes Service (AKS)](managed-identity-overview.md).
- **Use workload identity for pod access to Azure resources**: Federate Kubernetes service accounts with Microsoft Entra workload identities so pods obtain tokens for Azure resources without storing secrets. For more information, see [Use Microsoft Entra Workload ID with AKS](workload-identity-overview.md).
- **Integrate cluster authentication with Microsoft Entra ID**: Enable Microsoft Entra integration so users and groups authenticate to the cluster with their Entra identities instead of shared certificates. For more information, see [AKS-managed Microsoft Entra integration](access-control-managed-azure-ad.md).
- **Authorize Kubernetes API access with Azure RBAC**: Use Azure RBAC for Kubernetes authorization and assign the AKS built-in roles (Azure Kubernetes Service RBAC Reader, Azure Kubernetes Service RBAC Writer, Azure Kubernetes Service RBAC Admin, and Azure Kubernetes Service RBAC Cluster Admin) at cluster or namespace scope to grant least-privilege access. For more information, see [Cluster authorization concepts](concepts-cluster-authorization.md).
- **Disable local Kubernetes accounts**: Turn off local accounts so all cluster access flows through Microsoft Entra ID and can't bypass Entra-backed authorization with the static cluster admin credential. For more information, see [Manage local accounts with AKS-managed Microsoft Entra integration](local-accounts.md).
- **Enforce Conditional Access for cluster administrators**: Apply Conditional Access policies that require multifactor authentication and compliant devices for the Entra identities that can create, upgrade, or delete AKS clusters and manage their node pools, networking, and role assignments. For more information, see [Require MFA for Azure management](/entra/identity/conditional-access/policy-old-require-mfa-azure-mgmt).

## Data protection

AKS encrypts data at rest on managed disks by default. Configure the following controls to protect Kubernetes secrets and to bring your own keys where your compliance requirements call for it.

- **Encrypt Kubernetes secrets in etcd with a key management service**: Enable KMS data encryption so Kubernetes Secret objects are encrypted at the application layer before they're written to etcd, using platform-managed keys or your own customer-managed keys in Azure Key Vault. For more information, see [Data encryption at rest concepts for AKS](kms-data-encryption-concepts.md).
- **Store application secrets in Azure Key Vault**: Use the Azure Key Vault provider for Secrets Store CSI Driver to mount secrets, keys, and certificates from Key Vault instead of storing them as plaintext Kubernetes secrets. For more information, see [Use the Azure Key Vault provider for Secrets Store CSI Driver in AKS](csi-secrets-store-driver.md).
- **Use customer-managed keys for node and data disks**: Encrypt OS and data disks with your own keys in Key Vault when you need control over the encryption key lifecycle. For more information, see [Bring your own keys (BYOK) with Azure disks in AKS](azure-disk-customer-managed-keys.md).
- **Enable host-based encryption**: Turn on host-based encryption so temporary disks and OS/data disk caches on the node VM are encrypted at rest on the host. For more information, see [Host-based encryption on AKS](enable-host-encryption.md).

## Logging and monitoring

Collect cluster, control plane, and workload telemetry so you can detect and investigate threats against your AKS clusters.

- **Monitor clusters with Container insights**: Enable Container insights to collect node and container metrics and logs for your clusters into a Log Analytics workspace. For more information, see [Monitor Azure Kubernetes Service (AKS)](monitor-aks.md).
- **Collect control plane audit logs with diagnostic settings**: Configure diagnostic settings to send Kubernetes API server and audit log categories (`kube-audit`, `kube-audit-admin`, and `guard`) to Log Analytics for security investigation. For more information, see [Monitoring AKS data reference](monitor-aks-reference.md).
- **Enable threat detection with Microsoft Defender for Containers**: Turn on Defender for Containers to receive runtime threat detection alerts for cluster nodes, workloads, and the Kubernetes control plane. For more information, see [Overview of Microsoft Defender for Containers](/azure/defender-for-cloud/defender-for-containers-introduction).

## Compliance and governance

Use Azure Policy to enforce security configurations consistently across your AKS clusters and to prevent noncompliant workloads from being deployed.

- **Enforce cluster and workload configuration with Azure Policy for AKS**: Enable the Azure Policy add-on and assign the AKS built-in policy initiative to audit and enforce controls such as approved registries, resource limits, and blocked privileged containers. For more information, see [Secure your AKS clusters with Azure Policy](use-azure-policy.md).
- **Apply deployment safeguards for Kubernetes best practices**: Enable deployment safeguards to validate cluster resources against AKS best practices in warning or enforcement mode. For more information, see [Use deployment safeguards to enforce best practices in AKS](deployment-safeguards.md).
- **Assign AKS built-in policy definitions to enforce specific controls**: Assign built-in Azure Policy definitions for AKS to enforce individual controls, such as requiring authorized IP ranges or private clusters, disabling privileged containers, and enforcing internal load balancers. For more information, see [Azure Policy built-in definitions for AKS](policy-reference.md).

## Backup and recovery

Protect cluster state and application data so you can recover from accidental deletion, corruption, or a failed upgrade.

- **Back up cluster state and persistent volumes with AKS backup**: Use AKS backup with a Backup vault to schedule backups of cluster resources and persistent volumes backed by Azure Disk and Azure Files (SMB), and to restore a namespace or an entire cluster. For more information, see [What is Azure Kubernetes Service (AKS) backup?](/azure/backup/azure-kubernetes-service-backup-overview).
- **Grant backup access with Trusted Access instead of broad permissions**: Enable Trusted Access so the Backup vault reaches the cluster with scoped permissions rather than requiring standing administrative access. For more information, see [Enable Azure resources to access AKS clusters by using Trusted Access](trusted-access-feature.md).

## Next steps

- [Security concepts for applications and clusters in AKS](concepts-security.md)
- [Best practices for cluster security in AKS](operator-best-practices-cluster-security.md)
- [Well-Architected Framework – AKS guide](/azure/well-architected/service-guides/azure-kubernetes-service)
- [Zero Trust guidance center](/security/zero-trust/zero-trust-overview)
