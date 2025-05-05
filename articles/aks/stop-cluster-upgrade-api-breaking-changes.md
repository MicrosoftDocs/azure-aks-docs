---
title: Stop Azure Kubernetes Service (AKS) cluster upgrades automatically on API breaking changes
description: Learn how to stop Azure Kubernetes Service (AKS) cluster upgrades automatically on API breaking changes.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 07/05/2024
author: schaffererin
ms.author: schaffererin
---

# Stop Azure Kubernetes Service (AKS) cluster upgrades automatically on API breaking changes

This article shows you how to stop Azure Kubernetes Service (AKS) cluster upgrades automatically on API breaking changes.

## Overview

To stay within a supported Kubernetes version, you have to upgrade your cluster at least once per year and prepare for all possible disruptions. These disruptions include ones caused by API breaking changes, deprecations, and dependencies such as Helm and Container Storage Interface (CSI). It can be difficult to anticipate these disruptions and migrate critical workloads without experiencing any downtime.

You can configure your AKS cluster to automatically stop upgrade operations consisting of a minor version change with deprecated APIs and alert you to the issue. This feature helps you avoid unexpected disruptions and gives you time to address the deprecated APIs before proceeding with the upgrade.

## Before you begin

Before you begin, make sure you meet the following prerequisites:

* The upgrade operation is a Kubernetes minor version change for the cluster control plane.
* The Kubernetes version you're upgrading to is 1.26 or later.
* The last seen usage of deprecated APIs for the targeted version you're upgrading to must occur within 12 hours before the upgrade operation. AKS records usage hourly, so any usage of deprecated APIs within one hour isn't guaranteed to appear in the detection.

## Mitigate stopped upgrade operations

If you meet the [prerequisites](#before-you-begin), attempt an upgrade, and receive an error message similar to the following example error message:

```output
Bad Request({
  "code": "ValidationError",
  "message": "Control Plane upgrade is blocked due to recent usage of a Kubernetes API deprecated in the specified version. Please refer to https://kubernetes.io/docs/reference/using-api/deprecation-guide to migrate the usage. To bypass this error, set enable-force-upgrade in upgradeSettings.overrideSettings. Bypassing this error without migrating usage will result in the deprecated Kubernetes API calls failing. Usage details: 1 error occurred:\n\t* usage has been detected on API flowcontrol.apiserver.k8s.io.prioritylevelconfigurations.v1beta1, and was recently seen at: 2023-03-23 20:57:18 +0000 UTC, which will be removed in 1.26\n\n",
  "subcode": "UpgradeBlockedOnDeprecatedAPIUsage"
})
```

You have two options to mitigate the issue: you can [remove usage of deprecated APIs (recommended)](#remove-usage-of-deprecated-apis-recommended) or [bypass validation to ignore API changes](#bypass-validation-to-ignore-api-changes).

### Remove usage of deprecated APIs (recommended)

1. In the Azure portal, navigate to your cluster resource and select **Diagnose and solve problems**
2. Select **Create, Upgrade, Delete, and Scale** > **Kubernetes API deprecations**.

    :::image type="content" source="./media/upgrade-cluster/applens-api-detection-full-v2.png" alt-text="A screenshot of the Azure portal showing the 'Selected Kubernetes API deprecations' section.":::

3. Wait 12 hours from the time the last deprecated API usage was seen. Read-Only verbs are excluded from the deprecated api usage namely [Get/List/Watch][k8s-api].(You can also check past API usage by enabling [Container insights][container-insights] and exploring kube audit logs.)
4. Retry your cluster upgrade.

### Bypass validation to ignore API changes

> [!NOTE]
> This method requires you to use the Azure CLI version 2.57 or later. If you have the preview CLI extension installed, you need to update to version `3.0.0b10` or later. This method isn't recommended, as deprecated APIs in the targeted Kubernetes version might not work long term. We recommend removing them as soon as possible after the upgrade completes.

1. Bypass validation to ignore API breaking changes and invoke an upgrade. Specify the `enable-force-upgrade` flag and set the `upgrade-override-until` property to define the end of the window during which validation is bypassed. If no value is set, it defaults the window to three days from the current time. The date and time you specify must be in the future.

    ```azurecli-interactive
    az aks upgrade --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --kubernetes-version $KUBERNETES_VERSION --enable-force-upgrade --upgrade-override-until 2023-10-01T13:00:00Z
    ```
    > [!NOTE]
    > `Z` is the zone designator for the zero UTC/GMT offset, also known as 'Zulu' time. This example sets the end of the window to `13:00:00` GMT. For more information, see [Combined date and time representations](https://wikipedia.org/wiki/ISO_8601#Combined_date_and_time_representations).

## Next steps

This article showed you how to stop AKS cluster upgrades automatically on API breaking changes. To learn more about more upgrade options for AKS clusters, see [Upgrade options for Azure Kubernetes Service (AKS) clusters](./upgrade-cluster.md).

<!-- LINKS - external -->
[k8s-api]: https://kubernetes.io/docs/reference/using-api/api-concepts/

<!-- LINKS - internal -->
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-aks-upgrade]: /cli/azure/aks#az_aks_upgrade
[container-insights]:/azure/azure-monitor/containers/container-insights-log-query#resource-logs
