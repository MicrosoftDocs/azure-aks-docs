---
title: Statically provision Azure Managed Lustre volumes for AKS
description: Learn how to connect an existing Azure Managed Lustre file system to workloads in Azure Kubernetes Service.
ms.topic: how-to
ms.subservice: aks-storage
ms.date: 11/10/2026
author: wolfgang-desalvador
ms.author: wdesalvador

# Customer intent: As a cluster operator, I want to mount an existing Azure Managed Lustre file system in my AKS workloads.
---

# Statically provision Azure Managed Lustre volumes for AKS

<a id="use-static-provisioning-with-the-azure-managed-lustre-csi-driver"></a>

Static provisioning connects an existing Azure Managed Lustre file system to your Azure Kubernetes Service (AKS) cluster. In this example, a storage class identifies the existing file system and the driver creates a Kubernetes persistent volume (PV) for your persistent volume claim (PVC). It doesn't create a new Azure Managed Lustre file system.

To create a new file system through Kubernetes instead, see [Dynamic provisioning](azure-managed-lustre-dynamic-provisioning.md).

<a id="prerequisites-for-static-provisioning"></a>
<a id="create-an-azure-managed-lustre-file-system-cluster-for-static-provisioning"></a>
<a id="install-the-driver-for-static-provisioning"></a>

## Before you begin

- Complete [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md), including the verification steps for your chosen installation method. Don't install a second driver if one is already installed.
- Have an existing Azure Managed Lustre file system with network connectivity from AKS. If needed, [create a file system](/azure/azure-managed-lustre/create-file-system-portal).
- Copy the Lustre Management Service (MGS) IP address from the file system's **Client connection** page in the Azure portal.
- Configure `kubectl` for your cluster. Create the example PVC and pod in the same namespace.

<a id="create-and-configure-a-persistent-volume-for-static-provisioning"></a>

## Create a storage class

Create a file named `azure-managed-lustre-storage-class.yaml`. Replace `<MGS_IP_ADDRESS>` with the MGS IP address of your Azure Managed Lustre file system.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurelustre-static
provisioner: azurelustre.csi.azure.com
parameters:
  mgs-ip-address: <MGS_IP_ADDRESS>
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - noatime
  - flock
```

Apply the storage class:

```bash
kubectl apply -f azure-managed-lustre-storage-class.yaml
```

## Create a persistent volume claim

Create a file named `azure-managed-lustre-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurelustre-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurelustre-static
  resources:
    requests:
      storage: 4Ti
```

The requested capacity doesn't resize the existing Azure Managed Lustre file system.

Apply the claim and check its status:

```bash
kubectl apply -f azure-managed-lustre-pvc.yaml
kubectl get pvc azurelustre-pvc
```

Wait until the claim reaches the `Bound` state before continuing. To inspect provisioning events, run `kubectl describe pvc azurelustre-pvc`.

<a id="create-a-pod-for-static-provisioning"></a>
<a id="verify-static-provisioning"></a>

## Mount and verify the volume

Create a file named `azure-managed-lustre-pod.yaml`. Run the example on a supported node pool with the driver installed.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: azurelustre-test
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
        claimName: azurelustre-pvc
```

Apply the pod and wait for it to become ready:

```bash
kubectl apply -f azure-managed-lustre-pod.yaml
kubectl wait --for=condition=Ready pod/azurelustre-test --timeout=10m
```

Verify that the file system is mounted and the pod is writing to it:

```bash
kubectl exec azurelustre-test -- df -h /mnt/lustre
kubectl exec azurelustre-test -- tail /mnt/lustre/outfile
```

<a id="clean-up-static-resources"></a>

## Clean up the example

Find the PV name in the claim's `VOLUME` column before deleting the claim:

```bash
kubectl get pvc azurelustre-pvc -o wide
```

Stop the test pod and let its volume unmount. Then delete the claim, its retained PV, and the storage class. Replace `<PV_NAME>` with the name you recorded:

```bash
kubectl delete pod azurelustre-test
kubectl delete pvc azurelustre-pvc
kubectl delete pv <PV_NAME>
kubectl delete storageclass azurelustre-static
```

The storage class uses `Retain`, so deleting the claim alone leaves the PV behind. These commands remove the example's Kubernetes resources, not the Azure Managed Lustre file system or its data. They don't uninstall the driver.

## Troubleshooting

- **Network connectivity problems**: Verify virtual network peering or subnet configuration using the [network planning guide](azure-managed-lustre-network-planning.md).
- **Incorrect configuration**: Check the MGS IP address in the storage class.
- **Pod scheduling issues**: Confirm that the workload uses a supported node pool and review the pod events.
- **Network setup permission issues**: Verify that the AKS control-plane identity has appropriate permissions on the AKS subnet. Static provisioning doesn't require the CSI controller to create an Azure Managed Lustre file system.

For common driver issues, see [CSI driver troubleshooting](azure-managed-lustre-overview.md#troubleshooting). For version-specific diagnostics, see the [upstream v0.7.0 troubleshooting guide](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.7.0/docs/csi-debug.md). For file system deployment issues, see [Azure Managed Lustre troubleshooting](/azure/azure-managed-lustre/troubleshoot-deployment).

<a id="related-content"></a>

## Next steps

- [Dynamically provision Azure Managed Lustre volumes](azure-managed-lustre-dynamic-provisioning.md).
- [Upgrade or uninstall the Azure Managed Lustre CSI driver](azure-managed-lustre-uninstall.md).
- [Troubleshoot Azure Managed Lustre CSI driver extension errors](/troubleshoot/azure/azure-kubernetes/extensions/troubleshoot-azurelustre-csi-extension-errors).
