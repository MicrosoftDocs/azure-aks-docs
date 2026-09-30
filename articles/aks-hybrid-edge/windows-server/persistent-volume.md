---
title: Use persistent volumes with AKS on Windows Server
description: Use a persistent volume in a Windows container and prepare Windows nodes for group Managed Service Accounts
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 07/03/2024
ms.reviewer: srikantsarwa
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to create and use persistent storage volumes in a Windows container and prepare Windows nodes.
# Keyword: persistent storage, persistent volume

---

# Use persistent volumes with AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to provision, use, and delete persistent volumes that provide long-term storage for use with Kubernetes pods in AKS on Windows Server.

A *persistent volume* represents a piece of storage that has been provisioned for use with Kubernetes pods. A persistent volume can be used by one or more pods and is meant for long-term storage. It's also independent of pod or node lifecycles.

While you can provision a persistent volume for both Windows and Linux nodes, this article describes how to create a persistent volume for use in your Windows application. For more information, see [Persistent volumes in Kubernetes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

## Before you begin

Here's what you need to get started:

- A [Kubernetes cluster](kubernetes-walkthrough-powershell.md#step-6-create-a-kubernetes-cluster) with at least one Windows worker node.
- A kubeconfig file to [access the Kubernetes cluster](kubernetes-walkthrough-powershell.md#access-your-clusters-using-kubectl).

## Create a persistent volume claim

A persistent volume claim (PVC) is used to automatically provision storage based on a storage class. To create a volume claim, first create a file named `pvc-akshci-csi.yaml` and copy and paste the following YAML definition. The PVC requires a disk that is 10 GB in size with *ReadWriteOnce* access. The *default* storage class is specified as the storage class (vhdx).

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: pvc-akshci-csi
spec:
 accessModes:
 - ReadWriteOnce
 resources:
  requests:
   storage: 10Gi
```

To create the volume, run the following commands in an administrative PowerShell session on one of the servers in the Windows Server cluster. Use a method such as [Enter-PSSession](/powershell/module/microsoft.powershell.core/enter-pssession) or Remote Desktop to connect to the server.

```bash
kubectl create -f pvc-akshci-csi.yaml
```

The following output shows that your persistent volume claim was successfully created:

Output:

```output
persistentvolumeclaim/pvc-akshci-csi created
```

## Use persistent volume

To use a persistent volume, create a file named `winwebserver.yaml`, and copy and paste the following YAML definition. Then, create a pod with access to the persistent volume claim and vhdx.

In the following YAML definition, `mountPath` is the path to mount a volume inside a container. After a successful pod creation, you'll see the subdirectory **mnt** created in **C:\\** and the subdirectory **akshciscsi** created inside **mnt**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: win-webserver
  name: win-webserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: win-webserver
  template:
    metadata:
      labels:
        app: win-webserver
      name: win-webserver
    spec:
     containers:
      - name: windowswebserver
        image: mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
        ports:
          - containerPort: 80
        volumeMounts:
            - name: akshciscsi
              mountPath: "/mnt/akshciscsi"
     volumes:
        - name: akshciscsi
          persistentVolumeClaim:
            claimName:  pvc-akshci-csi
     nodeSelector:
      kubernetes.io/os: windows
```

To create a pod with this YAML definition, run:

```powershell
kubectl create -f winwebserver.yaml
```

To make sure the pod is running, execute the following command. Wait a few minutes until the pod is in a running state, since pulling the image takes time:

```powershell
kubectl get pods -o wide
```

Once your pod is running, view the pod status by running the following command:

```powershell
kubectl.exe describe pod %podName%
```

To verify your volume has been mounted in the pod, run the following command:

```powershell
kubectl exec -it %podname% cmd.exe
```

## Delete a persistent volume claim

Before you delete a persistent volume claim, you must delete the app deployment by running the following command:

```powershell
kubectl delete deployments win-webserver
```

You can then delete a persistent volume claim by running:

```powershell
kubectl delete PersistentVolumeClaim pvc-akshci-csi
```

## Next steps

- [Deploy a Windows application on your Kubernetes cluster](./deploy-windows-application.md)
- [Connect your Kubernetes cluster to Azure Arc for Kubernetes](./connect-to-arc.md)
