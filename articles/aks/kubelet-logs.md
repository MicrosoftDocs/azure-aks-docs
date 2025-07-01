---
title: View Kubelet Logs from AKS Nodes
description: Learn how to view troubleshooting information in the kubelet logs from Azure Kubernetes Service (AKS) nodes.
ms.topic: how-to
ms.subservice: aks-monitoring
ms.date: 05/09/2023
author: davidsmatlak
ms.author: davidsmatlak


#Customer intent: As a cluster operator, I want to view the logs for the kubelet that runs on each node in an AKS cluster to troubleshoot problems.
---

# Get kubelet logs from Azure Kubernetes Service cluster nodes

When you operate an Azure Kubernetes Service (AKS) cluster, you might need to review logs to troubleshoot a problem. The Azure portal has a built-in capability that you can use to view logs for AKS [main components][aks-main-logs] and [cluster containers][azure-container-logs]. Occasionally, you might need to get *kubelet* logs from AKS nodes for troubleshooting purposes.

This article shows you how to use `journalctl` to view kubelet logs on an AKS node.

Alternatively, you can collect kubelet logs by using the [syslog collection feature in Container insights in Azure Monitor](https://aka.ms/CISyslog).

## Before you begin

This article assumes that you have an existing AKS cluster. If you need an AKS cluster, create one by using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].

## Use the kubectl raw command

You can quickly view any node kubelet logs by using the following command:

```bash
kubectl get --raw "/api/v1/nodes/nodename/proxy/logs/messages"|grep kubelet
```

## Create an SSH connection

First, you need to create a Secure Shell Protocol (SSH) connection with the node you need to view kubelet logs for. To create this connection, complete the steps that are described in [SSH into AKS cluster nodes][aks-ssh].

## Get kubelet logs

After you connect to the node by using `kubectl debug`, run the following command to pull the kubelet logs:

```console
chroot /host
journalctl -u kubelet -o cat
```

> [!NOTE]
> For Windows nodes, the log data is in `C:\k` and can be viewed using the *more* command:
>
> ```console
> more C:\k\kubelet.log
> ```

The following example output shows kubelet log data:

```output
I0508 12:26:17.905042    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:26:27.943494    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:26:28.920125    8672 server.go:796] GET /stats/summary: (10.370874ms) 200 [[Ruby] 10.244.0.2:52292]
I0508 12:26:37.964650    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:26:47.996449    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:26:58.019746    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:05.107680    8672 server.go:796] GET /stats/summary/: (24.853838ms) 200 [[Go-http-client/1.1] 10.244.0.3:44660]
I0508 12:27:08.041736    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:18.068505    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:28.094889    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:38.121346    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:44.015205    8672 server.go:796] GET /stats/summary: (30.236824ms) 200 [[Ruby] 10.244.0.2:52588]
I0508 12:27:48.145640    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:27:58.178534    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:05.040375    8672 server.go:796] GET /stats/summary/: (27.78503ms) 200 [[Go-http-client/1.1] 10.244.0.3:44660]
I0508 12:28:08.214158    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:18.242160    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:28.274408    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:38.296074    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:48.321952    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
I0508 12:28:58.344656    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-11482510-0"
```

## Related content

If you need more troubleshooting information for the Kubernetes main, see [View the Kubernetes main node logs in AKS][aks-main-logs].

<!-- LINKS - internal -->
[aks-ssh]: ssh.md
[aks-main-logs]: monitor-aks-reference.md#resource-logs
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[azure-container-logs]: /azure/azure-monitor/containers/container-insights-overview
