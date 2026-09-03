---
title: Disk space exhaustion on the control plane VMs due to accumulation of kube-apiserver audit logs
description: Learn about a known issue with disk space exhaustion on the control plane VMs due to accumulation of kube-apiserver audit logs.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
---

# Disk space exhaustion on control plane VMs due to accumulation of kube-apiserver audit logs

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

## Symptoms

If you're running kubectl commands and facing issues, you might see errors such as:

```output
kubectl get ns
Error from server (InternalError): an error on the server ("Internal Server Error: \"/api/v1/namespaces?limit=500\": unknown") has prevented the request from succeeding (get namespaces)
```

When you SSH into the control plane VM, you might notice that your control plane VM ran out of disk space, specifically on the **/dev/sda2** partition. This is due to the accumulation of kube-apiserver audit logs in the **/var/log/kube-apiserver** directory, which can consume approximately 90 GB of disk space.

```output
clouduser@moc-laiwyj6tly6 [ /var/log/kube-apiserver ]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        4.0M     0  4.0M   0% /dev
tmpfs           3.8G   84K  3.8G   1% /dev/shm
tmpfs           1.6G  179M  1.4G  12% /run
tmpfs           4.0M     0  4.0M   0% /sys/fs/cgroup
/dev/sda2        99G   99G     0 100% /
tmpfs           3.8G     0  3.8G   0% /tmp
tmpfs           769M     0  769M   0% /run/user/1002
clouduser@moc-laiwyj6tly6 [ /var/log/kube-apiserver ]$ sudo ls -l /var/log/kube-apiserver|wc -l
890
clouduser@moc-laiwyj6tly6 [ /var/log/kube-apiserver ]$ sudo du -h /var/log/kube-apiserver
87G     /var/log/kube-apiserver
```

The issue occurs because the `--audit-log-maxbackup` value is set to 0. This setting allows the audit logs to accumulate without any limit, eventually filling up the disk. 

## Mitigation

This issue was fixed in [AKS on Azure Local, version 2507](/azure/azure-local/whats-new?view=azloc-2507&preserve-view=true#features-and-improvements-in-2507). Upgrade your Azure Local deployment to the 2507 build. 

### Workaround for Azure Local versions 2503 or 2504

To resolve the issue temporarily, you must manually clean up the old audit logs. Follow these steps:

- SSH into the control plane virtual machine (VM) of your AKS cluster.
- Remove the old audit logs from the **/var/log/kube-apiserver** folder.
- If you have multiple control plane nodes, you must repeat this process on each control plane VM.

[SSH into the control plane VM](ssh-connect-to-windows-and-linux-worker-nodes.md) and navigate to the kube-apiserver logs directory:

```bash
cd /var/log/kube-apiserver
```

Remove the old audit log files:

```bash
rm audit-*.log
```

Exit the SSH session:

```bash
exit
```

## Next steps

[Known issues in AKS Hybrid and Edge](aks-arc-known-issues.md)
