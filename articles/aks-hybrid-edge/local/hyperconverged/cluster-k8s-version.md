---
title: Troubleshoot K8sVersionValidation error code
description: Learn how to troubleshoot the K8sVersionValidation error code.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
---

# Troubleshoot K8sVersionValidation error code

This article describes how to identify and resolve the K8sVersionValidation error code that occurs when you try to create and deploy an AKS cluster on Azure Local.

## Symptoms

When you try to create an AKS cluster, you receive one of the following error messages:

- `Kubernetes version 1.27.7 isn't ready for use on Linux. To check the readiness of Kubernetes versions, visit https://aka.ms/aksarccheckk8sversions.`
- `Kubernetes version 1.26.12 isn't supported. To learn about the supported Kubernetes versions on this platform, visit https://aka.ms/aksarcsupportedversions.`
- `Admission webhook 'vhybridakscluster.kb.io' denied the request: Kubernetes version 1.26.12 isn't available.`

## Error messages

This section describes the error messages that you might see when you encounter the K8sVersionValidation error code.

### Kubernetes version 1.27.7 is not ready for use on Linux

This error message is caused by an incomplete Linux VHD download.

When you install Azure Local, you download a Linux VHD of approximately 4-5 GB in size. This Linux VHD is used to create the underlying VMs for the Kubernetes nodes in your AKS cluster. The error message can occur when your Linux VHD didn't finish downloading. To resolve this issue, wait until your internet connection finishes downloading the Linux VHD image.

To check if the image download is in progress or finished, run the following command:

```azurecli
$cl_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.ExtendedLocation/customLocations/<custom_location_name>"
          
# Get the kubernetes version using CLI (it automatically creates the **kubernetesVersions/default** Azure resource).
az aksarc get-versions --custom-location $cl_id
```

If this command says that the K8s versions are ready, and you're running Azure Local [release 2411](/azure/aks/aksarc/aks-whats-new-local#release-2411) or newer, file a [support request](help-support.md).

If you're running Azure Local release 2408 or older, proceed to the next section. We strongly recommend that you upgrade your Azure Local deployment to the latest version to get the latest bug fixes and security updates.

#### Recreate kubernetesVersions/default

If you redeploy Azure Local with the same name and parameters, you might have to recreate **kubernetesVersions/default**. To do so, run the following commands:

```azurecli
$subscription = <subscription_id>
$cl_id = <custom_location_id>

az login --use-device-code
az account set -s $subscription
$token = $(az account get-access-token --query accessToken)
$url = "https://management.azure.com${cl_id}/providers/Microsoft.HybridContainerService/kubernetesVersions/default?api-version=2024-01-01"

# Get the Kubernetes version Azure resource
az rest --headers "Authorization=Bearer $token" "Content-Type=application/json;charset=utf-8" --uri $url --method GET

# Delete the Kubernetes version Azure resource
az rest --headers "Authorization=Bearer $token" "Content-Type=application/json;charset=utf-8" --uri $url --method DELETE

# Get the Kubernetes version using CLI (it automatically creates the Kubernetes version Azure resource)
az aksarc get-versions --custom-location $cl_id
```

#### Can't see the Kubernetes versions or VM size options on the Azure portal

This scenario can happen in Azure Local releases 2408 or older, when the default resource for Kubernetes version (or VM sizes) wasn't created as part of the Azure Local deployment.

To resolve this issue, run the following command:

```azurecli
$cl_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.ExtendedLocation/customLocations/<custom_location_name>"
          
# Get the kubernetes version using CLI (it automatically creates the **kubernetesVersions/default** Azure resource).

az aksarc get-versions --custom-location $cl_id
```

### Kubernetes version 1.26.12 is not supported

Azure Local supports specific Kubernetes versions in each of its releases. As stated in the error message, go to `https://aka.ms/aksarcsupportedversions` for a list of supported Kubernetes versions based on your deployed Azure Local release.

## Next steps

[Troubleshoot issues in AKS Hybrid and Edge](aks-troubleshoot.md)
