---
title: Troubleshoot deleted cluster still visible in portal
description: Learn how to troubleshoot deleted cluster still visible in portal, shows "Not found."
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: sumsmith
ms.custom: hyperconverged

---

# Deleted cluster still visible in portal, shows "Not found"

A provisioned cluster that you deleted is still visible in the **Overview** blade on the Azure portal. Selecting the resource shows a **Not found** message. This error happens because occasionally, the cluster delete command fails to fully remove a resource. While it might delete the child **provisionedClusterInstance** resource, the parent **connectedCluster** resource often remains, making it still visible in the portal.

## Verify

- Get the provisioned cluster instance resource and verify that it doesn't exist:

  ```azurecli
  az aksarc show -g <resource_group> -n <cluster_name>
  ```

- Get the connected cluster resource and verify that it exists:

  ```azurecli
  az connectedk8s show -g <resource_group> -n <cluster_name>
  ```

## Workaround

Run the following command:

```azurecli
# Replace the following values appropriately

$subscription = <subscription_id>
$resource_group = <resource_group_name>
$cluster_name = <cluster_name>

az aksarc delete -g <resource_group> -n <cluster_name>
```

This command deletes the parent connected cluster resource as well.

## Validation

Run the `az connectedk8s show -g <resource_group> -n <cluster_name>` command to verify that it returns "Not found," or verify that the portal doesn't list the connected cluster resource anymore.

## Next steps

[Known issues in AKS Hybrid and Edge](aks-arc-known-issues.md)
