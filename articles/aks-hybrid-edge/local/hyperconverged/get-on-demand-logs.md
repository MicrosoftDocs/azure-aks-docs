---
title: Get on-demand logs for troubleshooting
description: Learn how to get full on-demand logs in AKS Hybrid and Edge and send them to Microsoft.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 04/08/2025
ms.reviewer: srikantsarwa
ms.custom: hyperconverged

# Intent: As an IT Pro, I need to learn how to obtain full on-demand logs in order to troubleshoot problems with my Azure Kubernetes Service in AKS Hybrid and Edge.  
# Keyword: on-demand logs cluster nodes troubleshooting

---

# Get on-demand logs for troubleshooting

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to collect full on-demand logs and send them to Microsoft support for troubleshooting issues with AKS Hybrid and Edge.

## Prepare the SSH key

Before log collection, you must have the SSH key you obtained when you created the cluster. It is usually saved under the **~/.ssh** path; for example, **C:\Users\HciiDeploymentUser\.ssh\id_rsa**. If the SSH key is lost, the log can't be collected.

## Collect logs

You can collect logs using IPs or the `kubeconfig` parameter. If an IP is used, it collects the log from a particular node. If `kubeconfig` is used, it collects logs from all cluster nodes. This command generates a .zip file on the local disk. For other parameters, see the [Az CLI reference](/cli/azure/aksarc#az-aksarc-get-logs). You can also use the [Get-AzAksArcLog](/powershell/module/az.aksarc/get-azaksarclog) PowerShell command to collect logs. For more information, [see the PowerShell reference](/powershell/module/az.aksarc/get-azaksarclog).

```azurecli
az aksarc get-logs --ip 192.168.200.25 --credentials-dir ./.ssh --out-dir ./logs
```

Or

```azurecli
az aksarc get-logs --kubeconfig ./.kube/config --credentials-dir ./.ssh --out-dir ./logs
```

## Send logs to Microsoft Support

Contact Microsoft Support to send the logs to Microsoft. If the environment is disconnected, you must recover the network first.

## Next steps

- [Get kubelet logs](aks-get-kubelet-logs.md)
- [Monitor Kubernetes clusters in AKS](./aks-monitor-logging.md)
