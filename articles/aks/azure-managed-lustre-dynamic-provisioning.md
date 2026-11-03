---
title: Dynamically provision Azure Managed Lustre volumes for AKS
description: Learn how to create Azure Managed Lustre file systems for persistent volume claims in Azure Kubernetes Service.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 10/30/2026
author: wolfgang-desalvador
ms.author: wdesalvador

# Customer intent: As a cluster operator, I want Kubernetes to provision Azure Managed Lustre storage for my AKS workloads.
---

# Dynamically provision Azure Managed Lustre volumes for AKS

Dynamic provisioning creates a new Azure Managed Lustre file system when you create a persistent volume claim (PVC). A storage class defines the file system configuration, and the driver provisions the storage and binds a persistent volume (PV) to the claim.

To use a file system you already own, see [Static provisioning](azure-managed-lustre-static-provisioning.md).

## Before you begin

- Complete [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md), including the verification steps for your chosen installation method. Don't install a second driver if one is already installed. You don't need an existing Lustre file system.
- Prepare an existing resource group and a subnet for the new file system, separate from the AKS subnet and reachable from your workloads. See [Plan network options for Azure Managed Lustre](azure-managed-lustre-network-planning.md).
- Grant the identity used by the CSI driver permission to manage file systems and access the subnet. Complete the [dynamic provisioning permission requirements](azure-managed-lustre-dynamic-provisioning-reference.md#permissions) before creating the claim.
- Configure `kubectl` for your cluster. Create the example PVC and pod in the same namespace.

> [!IMPORTANT]
> Creating the claim provisions an Azure resource that incurs charges. This example uses `reclaimPolicy: Delete`: deleting the claim also deletes the provisioned file system and its data. Use `Retain` instead if you need to keep the file system after deleting the claim.

## Create a storage class

Create a file named `azure-managed-lustre-dynamic-storage-class.yaml`. Replace the placeholders with your target Azure region, file system resource group, and existing virtual network and Lustre subnet.

Choose a file system configuration and capacity supported in your region. The example uses `AMLFS-Durable-Premium-125`, availability zone `1`, and a Sunday maintenance window. Adjust these values for your deployment. For supported settings, see [Dynamic provisioning configuration](azure-managed-lustre-dynamic-provisioning-reference.md#create-a-storage-class-for-dynamic-provisioning).

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurelustre-dynamic
provisioner: azurelustre.csi.azure.com
parameters:
  sku-name: "AMLFS-Durable-Premium-125"
  zone: "1"
  maintenance-day-of-week: "Sunday"
  maintenance-time-of-day-utc: "22:00"
  location: "<AZURE_REGION>"
  resource-group-name: "<LUSTRE_RESOURCE_GROUP>"
  vnet-resource-group: "<VNET_RESOURCE_GROUP>"
  vnet-name: "<VNET_NAME>"
  subnet-name: "<LUSTRE_SUBNET_NAME>"
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - noatime
  - flock
```

Apply the storage class:

```bash
kubectl apply -f azure-managed-lustre-dynamic-storage-class.yaml
```

## Create a persistent volume claim

Create a file named `azure-managed-lustre-dynamic-pvc.yaml`. Adjust the requested capacity for your workload and the selected file system configuration.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurelustre-dynamic-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurelustre-dynamic
  resources:
    requests:
      storage: 48Ti
```

Apply the claim and watch its status:

```bash
kubectl apply -f azure-managed-lustre-dynamic-pvc.yaml
kubectl get pvc azurelustre-dynamic-pvc --watch
```

File system provisioning can take several minutes. When the claim reaches `Bound`, press Ctrl+C and continue. If provisioning doesn't complete, inspect the events with `kubectl describe pvc azurelustre-dynamic-pvc`.

## Mount and verify the volume

Create a file named `azure-managed-lustre-dynamic-pod.yaml`. Run the example on a supported node pool with the driver installed.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: azurelustre-dynamic-test
spec:
  containers:
    - name: writer
      image: ubuntu:24.04
      command:
        - /bin/sh
        - -c
        - while true; do date >> /mnt/lustre/outfile; sleep 5; done
      volumeMounts:
        - name: lustre
          mountPath: /mnt/lustre
  volumes:
    - name: lustre
      persistentVolumeClaim:
        claimName: azurelustre-dynamic-pvc
```

Apply the pod and wait for it to become ready:

```bash
kubectl apply -f azure-managed-lustre-dynamic-pod.yaml
kubectl wait --for=condition=Ready pod/azurelustre-dynamic-test --timeout=10m
```

Verify that the file system is mounted and the pod is writing to it:

```bash
kubectl exec azurelustre-dynamic-test -- df -h /mnt/lustre
kubectl exec azurelustre-dynamic-test -- tail /mnt/lustre/outfile
```

## Clean up the example

> [!WARNING]
> With this example's `Delete` reclaim policy, the following commands delete the provisioned file system and its data. Save any data you need before deleting the claim.

Stop the test pod and let its volume unmount before deleting the claim:

```bash
kubectl delete pod azurelustre-dynamic-test
kubectl delete pvc azurelustre-dynamic-pvc
kubectl delete storageclass azurelustre-dynamic
```

Confirm that the provisioned file system is deleted in Azure. If you chose `Retain`, the PV and file system remain and require manual cleanup when no longer needed. Keep the driver installed until volume cleanup completes.

## Next steps

- [Statically provision Azure Managed Lustre volumes](azure-managed-lustre-static-provisioning.md).
- [Upgrade or uninstall the Azure Managed Lustre CSI driver](azure-managed-lustre-uninstall.md).
- [Troubleshoot dynamic provisioning](azure-managed-lustre-dynamic-provisioning-reference.md#troubleshooting).
