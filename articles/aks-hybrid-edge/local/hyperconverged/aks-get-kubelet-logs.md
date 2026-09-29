---
title: Get kubelet logs from cluster nodes
description: Learn how to get kubelet logs in an Azure Kubernetes Service (AKS) Hybrid and Edge deployment.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 1/14/2024
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
# Intent: As an IT Pro, I need to learn how to obtain kubelet logs in order to troubleshoot problems with my Azure Kubernetes Service in AKS Hybrid and Edge.
# Keyword: kubelet logs cluster nodes troubleshooting
---

# Get kubelet logs from cluster nodes

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

As part of operating a Kubernetes cluster in AKS Hybrid and Edge, you might need to review logs at some point to troubleshoot a problem. This article describes how to use `journalctl` to view the kubelet logs on a node.

## Create an SSH connection

First, you must create an SSH connection with the node on which you need to view the kubelet logs. To sign in using SSH, see [connect with SSH](../../windows-server/ssh-connection.md) for Windows and Linux worker nodes.

## Get kubelet logs

Once you connect to the node, run the following command to pull the kubelet logs:

```console
chroot /host
journalctl -u kubelet -o cat
```

The following sample output shows the kubelet log data:

```output
I0512 19:15:19.651370    1824 server.go:411] Version: v1.19.7
I0512 19:15:19.651680    1824 server.go:831] Client rotation is on, will bootstrap in background
I0512 19:15:19.709716    1824 dynamic_cafile_content.go:167] Starting client-ca-bundle::/etc/kubernetes/pki/ca.crt
I0512 19:15:19.867693    1824 server.go:640] --cgroups-per-qos enabled, but --cgroup-root was not specified.  defaulting to /
I0512 19:15:19.868130    1824 container_manager_linux.go:276] container manager verified user specified cgroup-root exists: []
I0512 19:15:19.868169    1824 container_manager_linux.go:281]
```

You can get the full on-demand logs from the cluster, then contact Microsoft for any required troubleshooting.

## Next steps

- [Get on-demand logs](get-on-demand-logs.md)
- [Monitor Kubernetes clusters in AKS](./aks-monitor-logging.md)
