---
title: Troubleshoot Azure Key Vault and KMS integration with Azure Kubernetes Service (AKS)
description: Find solutions to common issues when using Azure Key Vault with the Secrets Store CSI Driver or KMS etcd encryption in AKS.
ms.date: 02/24/2026
ms.subservice: aks-security
ms.topic: troubleshooting
ms.service: azure-kubernetes-service
author: davidsmatlak
ms.author: davidsmatlak
# Customer intent: As a Kubernetes administrator, I want to quickly find solutions to common Azure Key Vault and KMS integration issues so I can resolve problems without searching multiple articles.
---

# Troubleshoot Azure Key Vault and KMS integration with Azure Kubernetes Service (AKS)

This article helps you find solutions to common issues when integrating Azure Key Vault with Azure Kubernetes Service (AKS), including the Secrets Store CSI Driver and Key Management Service (KMS) etcd encryption.

## KMS etcd encryption issues

### Which KMS experience should I use?

For new clusters running Kubernetes 1.33 or later, use the new [KMS data encryption](kms-data-encryption.md) experience. For existing clusters or specific scenarios, see the decision table in [Add KMS etcd encryption to an AKS cluster (legacy)](use-kms-etcd-encryption.md#when-to-use-this-article-vs-the-new-kms-experience).

### KMS plugin connectivity failures (unix socket errors, Konnectivity issues)

**Symptoms**: Errors like `missing unix socket /opt/azurekms.socket` or `konnectivity tunnel unavailable`.

**Cause**: Clusters using Konnectivity with private Key Vault may experience connectivity failures. Konnectivity is deprecated for private Key Vault scenarios since September 2024.

**Solution**: Migrate to [API Server VNet Integration](api-server-vnet-integration.md). For new clusters, use the [new KMS data encryption experience](kms-data-encryption.md) with [trusted services bypass](/azure/key-vault/general/network-security#key-vault-firewall-enabled-trusted-services-only).

For more information, see the prerequisites and warnings in [Add KMS etcd encryption to an AKS cluster (legacy)](use-kms-etcd-encryption.md#prerequisites).

### Key rotation failures or inaccessible secrets after rotation

**Symptoms**: Secrets become inaccessible after key rotation, `az aks update` fails, or `kubectl get secrets` returns decryption errors.

**Cause**: KMS caches two keys simultaneously. If the old key is disabled or deleted before rotation completes, secrets encrypted with that key become inaccessible.

**Solution**: Follow the pre-rotation verification steps and recovery procedures in [Rotate existing keys in a public key vault](use-kms-etcd-encryption.md#rotate-existing-keys-in-a-public-key-vault). Key points:

- Verify both old and new keys are enabled before rotating
- Always run `kubectl get secrets --all-namespaces -o json | kubectl replace -f -` after rotation
- If a key was accidentally deleted, recover it using [Azure Key Vault recovery](/azure/key-vault/general/key-vault-recovery)

### NSG blocking KMS plugin connectivity to private Key Vault

**Symptoms**: KMS plugin timeouts in API server logs, connection failures to Key Vault private endpoint.

**Cause**: For clusters using API Server VNet Integration with a private Key Vault, the NSG must allow TCP port 443 from the API server subnet to the Key Vault private endpoint.

**Solution**: Create an NSG rule allowing HTTPS traffic. See the NSG rule example in the [limitations section](use-kms-etcd-encryption.md#limitations).

### Key expired error

**Symptoms**: `KeyExpired: Operation encrypt isn't allowed on an expired key`.

**Cause**: The encryption key has passed its expiration date.

**Solution**: Extend the key expiration date in Key Vault and rotate to a new key version. For diagnostic steps, see [Observability for KMS etcd encryption](kms-observability.md#example-problem).

### Switching between public and private Key Vault

**Symptoms**: Need to change Key Vault network access mode but updates fail.

**Cause**: You can't change the Key Vault mode directly; you must disable KMS first.

**Solution**: Follow the step-by-step process in [Update the key vault mode for an AKS cluster](update-kms-key-vault.md).

## Secrets Store CSI Driver issues

### SecretProviderClass YAML syntax errors

**Symptoms**: `cannot unmarshal !!map into string` or `cannot unmarshal !!seq into string` errors when applying a `SecretProviderClass`.

**Cause**: The `objects` field must be a multiline string (using `|`), not a YAML object or array.

**Solution**: See the correct vs. incorrect YAML examples in [Common configuration errors](csi-secrets-store-driver.md#common-configuration-errors). Validate YAML before applying using `kubectl apply --dry-run=client -f secretproviderclass.yaml`.

### Secrets not updating in environment variables after rotation

**Symptoms**: Secret rotation is enabled, but pods using environment variables still see old secret values.

**Cause**: Kubernetes doesn't automatically update environment variables in running containers. Rotation only works for volume mounts.

**Solution**: Use volume mounts instead of environment variables, or restart pods after rotation. Consider using tools like Reloader to automate pod restarts. See the important callout in [Set an environment variable to reference Kubernetes secrets](csi-secrets-store-configuration-options.md#set-an-environment-variable-to-reference-kubernetes-secrets).

### Secret rotation not working with subPath volume mounts

**Symptoms**: Secrets don't update even with rotation enabled when using `subPath` in the volume mount.

**Cause**: This is a known Kubernetes limitation. Containers using `subPath` volume mounts don't receive automated updates.

**Solution**: Avoid using `subPath` for secrets that need rotation, or restart pods to pick up changes. See [Limitations](csi-secrets-store-driver.md#limitations).

### Throttling errors (HTTP 429) from Key Vault

**Symptoms**: `Too many requests` errors, HTTP 429 responses from Key Vault.

**Cause**: The cluster is exceeding Key Vault service limits, often due to frequent rotation polling across many pods.

**Solution**: See [throttling and performance considerations](csi-secrets-store-configuration-options.md#throttling-and-performance-considerations). Key mitigations:

- Increase `--rotation-poll-interval` (default is 2 minutes)
- Cache secrets in application code
- Distribute secrets across multiple Key Vault instances

For Key Vault-specific throttling guidance, see [Azure Key Vault throttling guidance](/azure/key-vault/general/overview-throttling).

### Identity not found errors in CNI Overlay clusters

**Symptoms**: Pods can't access Key Vault with "identity not found" errors in clusters using Azure CNI Overlay networking.

**Cause**: CNI Overlay clusters require the managed identity to be assigned at the cluster level, not the node pool level.

**Solution**: Assign the identity at the cluster level and verify the client ID in your `SecretProviderClass`. See the CNI Overlay note in [Connect your Azure identity provider to the Secrets Store CSI Driver](csi-secrets-store-identity-access.md).

### Certificates retrieved in PEM format instead of PFX

**Symptoms**: Application expects PFX format but receives PEM-formatted certificate.

**Cause**: The CSI Driver automatically converts PFX certificates to PEM format when using `objectType: secret`.

**Solution**: This is by design. For NGINX and most ingress controllers, PEM is the expected format. If you need PFX, store the certificate separately or handle conversion in your application. See the note in [Import the certificate to AKV](csi-secrets-store-nginx-tls.md#import-the-certificate-to-akv).

### Permission errors accessing Key Vault

**Symptoms**: Access denied, 403 Forbidden, or insufficient permissions errors.

**Cause**: The managed identity doesn't have the required Key Vault permissions.

**Solution**: Assign the appropriate role:

- For secrets: `Key Vault Secrets User`
- For keys or certificates: `Key Vault Certificate User`

See [Configure workload identity](csi-secrets-store-identity-access.md#configure-workload-identity) for RBAC setup instructions.

## Diagnostic tools

### Azure portal diagnostics for KMS

Use the Azure portal's **Diagnose and solve problems** feature to check KMS configuration and health:

1. Navigate to your AKS cluster in the Azure portal.
1. Select **Diagnose and solve problems**.
1. Search for **KMS** and select **Azure KeyVault KMS Integration Issues**.

For more information, see [Observability for KMS etcd encryption](kms-observability.md#diagnose-and-solve-problems).

### CSI Driver metrics

Monitor the `keyvault_request` metric for latency and errors. See [Access Azure Key Vault provider metrics](csi-secrets-store-configuration-options.md#azure-key-vault-provider-metrics).

### Key Vault diagnostic logs

Enable diagnostic settings on your Key Vault to track encryption operations. See [Azure Key Vault logging](/azure/key-vault/general/howto-logging).

## Related content

- [Use the Azure Key Vault provider for Secrets Store CSI Driver](csi-secrets-store-driver.md)
- [Add KMS etcd encryption to an AKS cluster (legacy)](use-kms-etcd-encryption.md)
- [Enable KMS data encryption in AKS](kms-data-encryption.md)
- [Data encryption at rest concepts for AKS](kms-data-encryption-concepts.md)
- [Azure Key Vault throttling guidance](/azure/key-vault/general/overview-throttling)
- [Configure network security for Azure Key Vault](/azure/key-vault/general/network-security)
