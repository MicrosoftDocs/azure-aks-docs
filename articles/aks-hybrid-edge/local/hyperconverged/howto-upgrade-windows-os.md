---
title: Upgrade the Windows Server version on your node pools
description: Learn how to upgrade the Windows Server version on your node pools in AKS Hybrid and Edge.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 09/24/2025
ms.custom: hyperconverged

---

# Upgrade the OS version for your Windows node pool

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes the steps to upgrade the OS version for Windows workloads on AKS. While this example focuses on the upgrade from Windows Server 2019 to Windows Server 2022, you can follow the same process to upgrade from any Windows Server version to another version.

## Windows Server OS version support

When a new version of the Windows Server operating system is released, AKS is committed to supporting it, and recommends that you upgrade to the latest version to take advantage of its fixes, improvements, and new functionality.

> [!IMPORTANT]
> Windows Server 2019 is being retired in March 2026. Azure Local version 2510 will be the last release to include the Windows Server 2019 VHDs. The last Kubernetes version available on Windows Server 2019 is 1.32. Windows Server 2019 won't be supported on 1.33 and later. For more information, see [Windows Server 2019 node pool retirement](https://techcommunity.microsoft.com/blog/containers/announcing-the-3-year-retirement-of-windows-server-2019-on-azure-kubernetes-serv/3777341).
>
> Windows Server 2022 is being retired in October 2026. Azure Local version 2603 will be the last release to include the Windows Server 2022 VHDs. The last Kubernetes version available on Windows Server 2022 is 1.34. Windows Server 2022 won't be supported on 1.35 and later.

## Before you begin

- Update the FROM statement in your Dockerfile to the new OS version.
- Check your application and verify the container app works on the new OS version.
- Deploy the verified containerized application on AKS in a development or testing environment.
- Take note of the new image name or tag for use in this article.
- Ensure that the [Windows node pool feature is enabled](howto-enable-windows-node-pools.md) on your AKS cluster.

## Add a new Windows-based node pool to an existing cluster

Select the right OS SKU and create a new [Windows-based node pool](howto-create-windows-node-pools.md) on your AKS cluster.

[!INCLUDE [gmsa-windows-node-pools-not-supported](../../includes/gmsa-windows-node-pools-not-supported.md)]

## Update the application YAML to use the new OS SKU

A node selector is the most common and recommended option for placement of Windows pods on Windows nodes.

1. Update the `nodeSelector` field in your application's deployment YAML to match the label of the new Windows node pool.

   ```yaml
   nodeSelector:
        "kubernetes.azure.com/os-sku": Windows2022
   ```

   This enforces the placement of the pod on a Windows node that's running the latest OS version.

1. Once you update the `nodeSelector` in the YAML file, you also need to update the container image you want to use. You can get this information from the previous step in which you created a new version of the containerized application by changing the FROM statement on your Dockerfile.

   > [!NOTE]
   > You should use the same YAML file you used to initially deploy the application. This ensures that no other configuration changes besides the nodeSelector and container image.

## Apply the updated YAML file to the existing workload

1. View the nodes on your cluster using the `kubectl get nodes` command:

   ```bash
   kubectl get nodes -o wide
   ```

   This command shows all the nodes on your cluster, including the new node pool you created and the existing node pools.

1. Apply the updated YAML file to the existing workload using the `kubectl apply` command, and specify the name of the YAML file:

   ```bash
   kubectl apply -f <filename>
   ```

   At this point, AKS starts the process of terminating the existing pods and deploying new pods to the Windows Server 2022 nodes.

1. Check the status of the deployment using the `kubectl get pods` command.

   ```bash
   kubectl get pods -o wide
   ```

You should now see the pods  running on the new Windows node pool you created. You can now delete the old Windows node pool that's running on the older Windows SKU.

## Next steps

- [Delete a node pool](/azure/aks/aksarc/manage-node-pools#delete-a-node-pool)
- [Manage multiple node pools](/azure/aks/aksarc/manage-node-pools)
