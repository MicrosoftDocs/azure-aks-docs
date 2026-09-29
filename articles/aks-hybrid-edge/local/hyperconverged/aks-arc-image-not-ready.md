---
title: Troubleshoot AKS on Azure Local issues when Kubernetes version image isn't ready
description: Learn how to mitigate cluster and node pool issues when a Kubernetes version reports image not ready on AKS Hybrid and Edge on Azure Local.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged

# Intent: As an IT admin, I want to troubleshoot and resolve Kubernetes version image readiness issues in AKS on Azure Local.
# Keyword: Kubernetes version image not ready AKS Azure Local
---

# Troubleshoot AKS on Azure Local issues when Kubernetes version image isn't ready

This article describes how to mitigate cluster and node pool issues when a Kubernetes version reports image not ready on AKS Hybrid and Edge on Azure Local.

## Symptoms

You might observe one or more of the following error scenarios when creating or updating an AKS cluster:

### Error 1: Gallery image not found during cluster creation

```output
Provisioning the AKSArc cluster. This operation might take a while...

(ResourceDeploymentFailure) The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.

(ClusterPrecheckFailed) Error: Aks Arc cluster creation precheck failed. Detailed message: 1 error occurred:
* rpc error: code = NotFound desc = Type[GalleryImage], Location[MocLocation], Name[linux-cblmariner-0.11.26.10605]: Not Found
```

### Error 2: Kubernetes version validation failure

```output
Provisioning the AKSArc cluster. This operation might take a while...

(TemplateDeploymentValidationFailed) Validation failed for 'Microsoft.HybridContainerService/provisionedClusterInstances'.

(PreflightValidationFailed) Preflight validation failed for one or more resources

(PreflightValidationFailed) admission webhook "vhybridakscluster.kb.io" denied the request: {
   "result": "Failed",
   "validationChecks": [
      {
         "name": "K8sVersionValidation",
         "message": "Kubernetes version 1.33.5 isn't ready for use on Linux. Please go to https://aka.ms/aksarccheckk8sversions for details of how to check the readiness of Kubernetes versions.",
         "recommendation": "Please check https://aka.ms/AKSArcValidationErrors/K8sVersionValidation for recommendations"
      }
   ]
}
```

For more information on troubleshooting the K8sVersionValidation error code, see [Troubleshoot K8sVersionValidation error code](cluster-k8s-version.md).

## Cause

It's possible that the image provisioning is still in progress. AKS on Azure Local depends on image readiness for the selected Kubernetes version and OS SKU. If the required image variant isn't fully provisioned or available, the Kubernetes version remains not ready and dependent operations can fail.

## Workaround

Use the following steps to recover image readiness.

### 1. Verify available Kubernetes versions

Run the following command to check available Kubernetes versions:

```azurecli
az aksarc get-versions --resource-group <resource-group-name> --custom-location <custom-location-name>
```

Confirm that your target version is listed and supported for your intended OS SKU.

### 2. Check storage path health

Run the following command to verify storage path status:

```azurecli
az stack-hci-vm storagepath list --resource-group <resource-group-name> --custom-location <custom-location-resource-id>
```

If the expected storage path is missing or unhealthy, recreate or update it by following the guidance in [Create storage path for Azure Local](/azure/azure-local/manage/create-storage-path).

### 3. Refresh storage path metadata

Run the following command to refresh the storage path:

```azurecli
az stack-hci-vm storagepath update --resource-group <resource-group-name> --custom-location <custom-location-resource-id> --name <storage-path-name> --location <azure-region>
```

This action can trigger revalidation and image resynchronization.

### 4. Run support module validation

Use the Support.AksArc diagnostic tool to validate that all tests are passing. For installation and usage instructions, see [Support.AksArc diagnostic and remediation tool](support-module.md).

Ensure all validation checks pass before proceeding with cluster operations.

### 5. Wait and retry the AKS operation

After recovering the storage path and image sync, retry the failed cluster or node pool operation.

### 6. If the issue persists

If the problem continues after following the previous steps, collect diagnostic logs and open a support request.

Include the following information:

- Resource group
- Custom location
- Azure Local resource ID
- Full error message
- Correlation IDs from the error output

## Prevention

To prevent this issue:

- Keep at least one storage path for AKS cluster to work.
- Validate storage path status is healthy (green status).
- Never rename or change the folder path name locally on the Azure Local machine.
- Avoid deleting storage volumes or storage paths used by AKS on Azure Local.
- Validate storage path availability before cluster upgrades.
- Use supported Kubernetes versions and OS SKUs for your target environment.
- Apply platform updates and retry transient image provisioning states after a short interval.

## Related content

- [Troubleshoot AKS on Azure Local issues after deleting storage volumes](delete-storage-volume.md)
- [Create storage path for Azure Local](/azure/azure-local/manage/create-storage-path)
- [AKS troubleshooting](aks-troubleshoot.md)
