---
title: Data encryption at rest concepts for Azure Kubernetes Service (AKS)
description: Learn about encryption at rest for Kubernetes secrets in Azure Kubernetes Service (AKS) using Azure Key Vault and the KMS provider.
ms.date: 12/14/2025
ms.subservice: aks-security
ms.topic: concept-article
ms.service: azure-kubernetes-service
author: shashankbarsin
ms.author: shasb
# Customer intent: As a Kubernetes administrator, I want to understand how data encryption at rest works in AKS so I can choose the right key management approach for my security and compliance requirements.
---

# Data encryption at rest concepts for Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) stores sensitive data such as Kubernetes secrets in etcd, the distributed key-value store used by Kubernetes. For enhanced security and compliance requirements, AKS supports encryption of Kubernetes secrets at rest using the Kubernetes Key Management Service (KMS) provider integrated with Azure Key Vault.

This article explains the key concepts, encryption models, and key management options available for protecting Kubernetes secrets at rest in AKS.

## Understanding data encryption at rest

Data encryption at rest protects your data when it's stored on disk. Without encryption at rest, an attacker who gains access to the underlying storage could potentially read sensitive data like Kubernetes secrets.

AKS provides encryption for Kubernetes secrets stored in etcd:

| Layer | Description |
|-------|-------------|
| **Azure platform encryption** | Azure Storage automatically encrypts all data at rest using 256-bit AES encryption. This encryption is always enabled and transparent to users. |
| **KMS provider encryption** | An optional layer that encrypts Kubernetes secrets before they're written to etcd using keys stored in Azure Key Vault. |

For more information about Azure's encryption at rest capabilities, see [Azure data encryption at rest][azure-encryption-atrest] and [Azure encryption models][azure-encryption-models].

## KMS provider for data encryption

The [Kubernetes KMS provider][k8s-kms-provider] is a mechanism that enables encryption of Kubernetes secrets at rest using an external key management system. AKS integrates with Azure Key Vault to provide this capability, giving you control over encryption keys while maintaining the security benefits of a managed Kubernetes service.

### How KMS encryption works

When you enable KMS for an AKS cluster:

1. **Secret creation**: When a secret is created, the Kubernetes API server sends the secret data to the KMS provider plugin.
1. **Encryption**: The KMS plugin encrypts the secret data using a Data Encryption Key (DEK), which is itself encrypted using a Key Encryption Key (KEK) stored in Azure Key Vault.
1. **Storage**: The encrypted secret is stored in etcd.
1. **Secret retrieval**: When a secret is read, the KMS plugin decrypts the DEK using the KEK from Azure Key Vault, then uses the DEK to decrypt the secret data.

This envelope encryption approach provides both security and performance benefits. The DEK handles frequent encryption operations locally while the KEK in Azure Key Vault provides the security of a hardware-backed key management system.

## Key management options

AKS offers two key management options for KMS encryption:

### Platform-managed keys (PMK)

With platform-managed keys, AKS automatically manages the encryption keys for you:

- AKS creates and manages the Azure Key Vault and encryption keys.
- Key rotation is handled automatically by the platform.
- No additional configuration or key vault setup is required.

**When to use platform-managed keys:**

- You want the simplest setup with minimal configuration.
- You don't have specific regulatory requirements that mandate customer-managed keys.
- You want automatic key rotation without manual intervention.

### Customer-managed keys (CMK)

With customer-managed keys, you have full control over the encryption keys:

- You create and manage your own Azure Key Vault and encryption keys.
- You control key rotation schedules and policies.

**When to use customer-managed keys:**

- You have regulatory or compliance requirements that mandate customer-managed keys.
- You need to control the key lifecycle, including rotation schedules and key versions.
- You require audit logs for all key operations.

### Key vault network access options

When using customer-managed keys, you can configure the network access for your Azure Key Vault:

| Network access | Description | Use case |
|----------------|-------------|----------|
| **Public** | Key vault is accessible over the public internet with authentication. | Development environments, simpler setup |
| **Private** | Key vault is only accessible through private endpoints. Requires the AKS cluster to use [API Server VNet Integration][api-server-vnet-integration] so the API server can access the private key vault. | Production environments, enhanced security |

## Comparing encryption key options

| Feature | Platform-managed keys | Customer-managed keys (Public) | Customer-managed keys (Private) |
|---------|----------------------|-------------------------------|--------------------------------|
| **Key ownership** | Microsoft manages | Customer manages | Customer manages |
| **Key rotation** | Automatic | Manual | Manual |
| **Key vault creation** | Automatic | Customer creates | Customer creates |
| **Network isolation** | N/A | No | Yes |
| **Regulatory compliance** | Basic | Enhanced | Maximum |

## Requirements and limitations

### Kubernetes version requirement

KMS encryption with platform-managed keys or customer-managed keys with automatic key rotation requires **Kubernetes version 1.33 or later**.

### Limitations

- **No downgrade**: After enabling the new KMS encryption experience, you can't disable the feature.
- **Key deletion**: Deleting the encryption key or key vault makes your secrets unrecoverable.

## Related content

- [Enable KMS data encryption in AKS][kms-data-encryption]
- [Azure data encryption at rest][azure-encryption-atrest]
- [Azure encryption models][azure-encryption-models]
- [Kubernetes KMS provider documentation][k8s-kms-provider]

<!-- INTERNAL LINKS -->
[kms-data-encryption]: kms-data-encryption.md
[api-server-vnet-integration]: api-server-vnet-integration.md
[azure-encryption-atrest]: /azure/security/fundamentals/encryption-atrest
[azure-encryption-models]: /azure/security/fundamentals/encryption-models

<!-- EXTERNAL LINKS -->
[k8s-kms-provider]: https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/
