---
title: Create and manage storage for AKS clusters in the Azure portal
description: In this article, you learn how to create and manage storage resources for Azure Kubernetes Service (AKS) clusters in the Azure portal.
author: sasper0ni
ms.author: mirandawu
ms.service: azure-kubernetes-service
ms.topic: how-to #Required; leave this attribute/value as-is
ms.date: 05/22/2026

#CustomerIntent: As a DevOps engineer or platform administrator, I want to create and manage storage resources in Azure Kubernetes Service through the Azure portal.
---

# Create and manage storage for Azure Kubernetes Service (AKS) clusters in the Azure portal

Kubernetes workloads require storage when they need to store and/or retrieve data that persists beyond the pod or node lifecycle. This article shows you how to create and manage storage for AKS clusters directly in the Azure portal.

For more information on how storage works in Kubernetes or AKS, you can visit the [Kubernetes documentation](https://kubernetes.io/docs/concepts/storage/) or review the [Storage options for applications in Azure Kubernetes Service (AKS)](./concepts-storage.md).

## Prerequisites

- A running AKS cluster. If you don't have one, see [Create an AKS cluster](/azure/aks/learn/quick-kubernetes-deploy-portal?tabs=azure-cli).
- The Azure portal automatically installs any managed Container Storage Interface (CSI) drivers required during the deployment of your desired storage type. To confirm which CSI drivers are already installed on your cluster, go to the Azure portal and navigate to your AKS cluster resource. From the service menu, select **Storage**. On the **Drivers** tab, you can also manually enable new drivers and/or verify existing driver installations. For example:

    :::image type="content" source="media/storage-portal/driver-configuration-in-portal.png" alt-text="A screenshot of Azure portal Drivers tab showing CSI drivers enabled.":::

## Create storage

To dynamically provision storage using Kubernetes resources, you must create a Persistent Volume Claim (PVC) that references either a custom or built-in storage class.

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Kubernetes resources**, select **Storage**.
1. Select **+ Create** > **Storage**.

### Select storage type and/or create a storage class

Based on your workload or hardware requirements, select a storage type (Azure Blob, Azure File, or Azure Disk) which corresponds to the managed CSI driver that will provision your storage resource. These CSI drivers come with built-in storage classes that define properties such as SKU, protocol (when applicable), volume binding mode, and reclaim policy. You can choose to reference one of these to proceed or select **Create new** if you need to define your own custom set of properties.

You can view details of any newly created or built-in storage class by selecting it in the dropdown. For example:

:::image type="content" source="media/storage-portal/storage-class-overview.png" alt-text="A screenshot showing an overview of Azure File built-in storage class.":::

### Create a PVC

After you create or select a storage class, you can create a PVC that references that storage class to dynamically provision a storage resource.

1. Update the following fields under the **Persistent Volume Claim details** section:

    - Name
    - Namespace
    - Access mode
    - Storage size (`Gi`)

1. Select **Create**.

> [!TIP]
> Shrinking persistent volumes currently isn't supported, so make sure to size your PVC accordingly. For certain Azure Disk SKUs, the size designated here might correspond to your storage's performance tier. For more information, see [Azure managed disk types](/azure/virtual-machines/disks-types).

### Use a PVC

To mount an existing PVC into a Kubernetes workload, you must reference the PVC in the workload’s `volumes` section and mount it into a container using `volumeMounts`.

The example YAML manifest in step 2 creates a pod that runs an NGINX image and mounts your storage resource at the _/mnt/azure_ path. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as _'D:'_.

1. Navigate back to the **Storage** menu and select **+ Create** > **Apply a YAML**. 
1. Paste in the following YAML manifest, and replace the `claimName` placeholder value (`<pvc-name>`) with the name of your existing PVC:

    ```yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name: mypod
    spec:
      containers:
        - name: mypod
          image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
          volumeMounts:
            - mountPath: /mnt/azure
              name: volume
              readOnly: false
      volumes:
       - name: volume
         persistentVolumeClaim:
           claimName: <pvc-name> # replace this with your PVC name
    ```

1. To access and/or manage Kubernetes workload resources, navigate to **Kubernetes resources** > **Workloads**.
    

## Manage storage resources

You can manage your existing storage resources (PVCs, PVs and storage classes) from the **Storage** menu. You can also view recent storage-related Kubernetes events and warnings and the cluster's total provisioned storage capacity in `Gi`. For example:

:::image type="content" source="media/storage-portal/storage-manage-overview.png" alt-text="A screenshot showing the AKS Storage menu in the Azure portal.":::

To expand a PVC, select it in the PVC grid and then select **Expand** from the toolbar menu. This selection opens the **Expand Persistent Volume Claim** page where you can enter a new size (as long as your PVC's underlying storage class supports volume expansion).

:::image type="content" source="media/storage-portal/expand-persistent-volume-claim.png" alt-text="A screenshot showing the UX to expand a PVC in the Azure portal.":::

## Frequently asked questions (FAQ)

### Is Persistent Volume (PV) creation supported?

Currently, the Azure portal only explicitly supports storage creation via dynamic provisioning (using storage classes and PVCs). To statically provision a PV, you can manually apply a YAML definition via **+ Create** > **Apply a YAML** in the **Storage** menu.

## Related content

- [Storage options for applications in Azure Kubernetes Service (AKS)](./concepts-storage.md)
- [Best practices for storage and backups in Azure Kubernetes Service (AKS)](./operator-best-practices-storage.md)