---
title: External NFS Storage on AKS Edge Essentials
description: Learn how to use NFS external provisioner on AKS Edge Essentials.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# External NFS storage on AKS Edge Essentials

Persistent storage solutions enable you to store application data external to the pod running your application, and allow you to maintain application data, even if the application's pod fails. It's possible to use the [Local Path Provisioner](./aks-edge-howto-use-storage-local-path.md) for local storage; however, storage depends on the node's availability. It's also possible to decouple storage availability from the node's lifecycle by using external storage providers.

This article describes how to set up an NFS provider and deploy a sample container with an NFS-connected PV on your AKS Edge Essentials cluster.

For more information about the NFS plugin, see the [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner).

## Step 1: get connection information for your NFS server

Ensure your NFS server is accessible from your AKS Edge Essentials cluster and get the information you need to connect to it. The information should include the NFS server hostname and exported share path. If the NFS server has authentication mechanisms, make sure to get that information as well.

## Step 2: download resources

Get the resource templates. To set up the provisioner, download a set of YAML template files, edit them to add your NFS server's connection information, and then apply each deployment file.

>[!NOTE]
>The NFS sample used is based on the [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) sample code and adjusted for the AKS Edge Essentials virtual machine.

1. Download the latest source code .zip from [the AKS-Edge Essentials GitHub repo](https://github.com/Azure/AKS-Edge).

2. Extract the **tgz** to a desired folder.

3. Open a PowerShell session as administrator.

4. Change to the NFS sample directory: **AKS-Edge -> samples -> storage -> NFS**.

5. Using the `dir` command, check that the **NFS** folder has the following files:

    ```output
        Directory: C:\Users\AKS-Edge\samples\storage\nfs

    Mode                 LastWriteTime         Length Name
    ----                 -------------         ------ ----
    -a----         1/25/2023  10:43 AM            345 class.yaml
    -a----         1/25/2023   1:14 PM            979 deployment.yaml
    -a----         1/25/2023   1:16 PM            371 pod.yaml
    -a----         1/25/2023   1:17 PM            218 pvc.yaml
    -a----          1/9/2023  10:19 AM           1900 rbac.yaml
    ```

## Step 3: set up authorization

An AKS Edge Essentials cluster has the default RBAC enabled, so no other RBAC needs to be configured. However, if you are in a namespace/project other than **default**, edit **rbac.yaml** before deploying the template. In an elevated PowerShell window, run the following cmdlet:

```powershell
kubectl create -f .\rbac.yaml
```

## Step 4: configure the NFS subdirectory external provisioner

Next, edit the NFS provisioner's deployment file to add connection information for your NFS server. Edit **deploy/deployment.yaml** and replace the following values:

1. Replace the server hostname `VALUE` under `name: NFS_SERVER`.
1. Replace the server hostname `server` under `volumes` -> `nfs`.
1. Replace the server hostname `VALUE` under `name: NFS_PATH`.
1. Replace the server hostname `path` under `volumes` -> `nfs`.
1. Open a PowerShell window as administrator.
1. Create a folder to be used for persistent volumes inside the node:

    ```powershell
    Invoke-AksEdgeNodeCommand -NodeType Linux -command "sudo mkdir /var/persistentVolumes"
    ```

    >[!TIP]
    > The current guide uses the **/var/persistenVolumes** folder. If you want to change the folder, create another mounting folder and set the appropriate permissions. Also, update the **deployment.yaml** file with the new directory.

1. Deploy the required YAML files:

    ```powershell
    kubectl create -f .\class.yaml
    kubectl create -f .\deployment.yaml
    kubectl create -f .\pvc.yaml
    kubectl create -f .\pod.yaml
    ```

## Step 5: check created resources

If everything is running and correctly attached, you should see something similar to the following. First, you should see that the PV has been created using `kubectl get pv`:

```output
PS C:\WINDOWS\system32> kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS   REASON   AGE
pvc-72dd0e5a-1064-424d-b534-d414b6693aaa   1Mi        RWX            Delete           Bound    default/test-claim   nfs-client              20s
```

Next, the PVC has been bound using `kubectl get pvc`:

```output
PS C:\WINDOWS\system32> kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-pvc      Bound    pvc-72dd0e5a-1064-424d-b534-d414b6693aaa   1Mi        RWX            nfs-client     25s
```

Finally, you should see the **volume-test** and the **nfs-client-provisioner** using `kubectl get pods`:

```output
PS C:\WINDOWS\system32> kubectl get pods
NAME                                      READY   STATUS      RESTARTS   AGE
nfs-client-provisioner-696845f854-wz5cp   1/1     Running     0          2m
volume-test                               1/1     Running     0          2m
```

## Step 6: test persistent storage

A final test is to make sure that the storage is persistent in the NFS-connected drive.

Start by writing something to the pod. In an elevated PowerShell window, run the following cmdlet:

```powershell
kubectl exec volume-test -- sh -c "echo Hello AKS Edge! > /data/Test-NFS.txt"
```

Now, go to your NFS shared drive, and check for a file named **Test-NFS.txt**. Open the file, and you should see a line that says "Hello AKS Edge!"

Finally, delete the pod to simulate a pod failing, or even a deployment being removed, using the following cmdlet:

```powershell
kubectl delete -f .\pod.yaml
```

Check that the pod was removed and then deploy the **volume-test** pod again:

```powershell
kubectl apply -f .\pod.yaml
```

Finally, read the contents of the file that was previously written. If everything ran successfully, you should see the "Hello AKS Edge!" message:

```powershell
kubectl exec volume-test -- sh -c "cat /data/Test-NFS.txt"
```

## Step 7: clean up deployment

Once you're finished with NFS storage, go to PowerShell and clean up your workspace by running the following script:

```powershell
kubectl delete -f .\pod.yaml
kubectl delete -f .\pvc.yaml
kubectl delete -f .\deployment.yaml
kubectl delete -f .\class.yaml
```

## Next steps

- [AKS Edge Essentials overview](./aks-edge-overview.md)
- [Uninstall AKS cluster](./aks-edge-howto-uninstall.md)
