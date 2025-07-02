---
title: View Kubelet Logs from AKS Nodes
description: Learn how to view troubleshooting information in the kubelet logs from Azure Kubernetes Service (AKS) nodes.
ms.topic: how-to
ms.subservice: aks-monitoring
ms.date: 06/08/2024
author: nickoman
ms.author: nickoman
ms.custom: innovation-engine,aks,logs,troubleshooting
---

# Get kubelet logs from Azure Kubernetes Service cluster nodes

You might need to review logs to troubleshoot a problem in your Azure Kubernetes Service (AKS) cluster. You can use tools in the Azure portal to view logs for AKS [main components][aks-main-logs] and [cluster containers][azure-container-logs]. Occasionally, you might need to get *kubelet* logs from AKS nodes to help you troubleshoot an issue.

This article shows you how to use `journalctl` to view kubelet logs on an AKS node.

Alternatively, you can collect kubelet logs by using the [syslog collection feature in Container insights in Azure Monitor](https://aka.ms/CISyslog).

## Before you begin

This article assumes that you have an existing AKS cluster. If you need an AKS cluster, create one by using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].

## Connect to your AKS cluster

To interact with your AKS cluster, first get the cluster credentials by using the Azure CLI:

```bash
export RESOURCE_GROUP_NAME="<ResourceGroupName>"
export AKS_CLUSTER_NAME="<AKSClusterName>"
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
```

This command configures kubectl to use the credentials for your AKS cluster.

## Use the kubectl raw command

You can quickly view any node's kubelet logs by using the following command:

```bash
export NODE_NAME="aks-agentpool-xxxxxxx-0"
kubectl get --raw "/api/v1/nodes/$NODE_NAME/proxy/logs/messages" | grep kubelet
```

Results:

<!-- expected_similarity=0.3 -->

```output
I0508 12:26:17.905042    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:27.943494    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:28.920125    8672 server.go:796] GET /stats/summary: (10.370874ms) 200 [[Ruby] 10.244.0.x:52492]
I0508 12:26:37.964650    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
...
```

## Create an SSH connection

You must create a Secure Shell Protocol (SSH) connection with the node you need to view kubelet logs for. To create this connection, complete the steps that are described in [SSH into AKS cluster nodes][aks-ssh].

## Get kubelet logs

After you connect to the node by using `kubectl debug`, run the following command to pull the kubelet logs:

```console
chroot /host
journalctl -u kubelet -o cat
```

> [!NOTE]
> For Windows nodes, the log data is in `C:\k` and can be viewed by using the `more` command:
>
> ```console
> more C:\k\kubelet.log
> ```

The following example output shows kubelet log data:

```output
I0508 12:26:17.905042    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:27.943494    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:28.920125    8672 server.go:796] GET /stats/summary: (10.370874ms) 200 [[Ruby] 10.244.0.x:52292]
I0508 12:26:37.964650    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:47.996449    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:26:58.019746    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:05.107680    8672 server.go:796] GET /stats/summary/: (24.853838ms) 200 [[Go-http-client/1.1] 10.244.0.x:44660]
I0508 12:27:08.041736    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:18.068505    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:28.094889    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:38.121346    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:44.015205    8672 server.go:796] GET /stats/summary: (30.236824ms) 200 [[Ruby] 10.244.0.x:52588]
I0508 12:27:48.145640    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:27:58.178534    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:05.040375    8672 server.go:796] GET /stats/summary/: (27.78503ms) 200 [[Go-http-client/1.1] 10.244.0.x:44660]
I0508 12:28:08.214158    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:18.242160    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:28.274408    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:38.296074    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:48.321952    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
I0508 12:28:58.344656    8672 kubelet_node_status.go:497] Using Node Hostname from cloudprovider: "aks-agentpool-xxxxxxx-0"
```

## Related content

* [View the Kubernetes main node logs in AKS][aks-main-logs]

<!-- LINKS - internal -->
[aks-ssh]: ssh.md
[aks-main-logs]: monitor-aks-reference.md#resource-logs
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[azure-container-logs]: /azure/azure-monitor/containers/container-insights-overview
