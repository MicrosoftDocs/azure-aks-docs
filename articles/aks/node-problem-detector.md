---
title:  Node Problem Detector (NPD) in Azure Kubernetes Service (AKS) nodes
description: Learn about how AKS uses Node Problem Detector to expose issues with the node.
ms.topic: concept-article
ms.date: 05/31/2023
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: As a Kubernetes administrator, I want to utilize Node Problem Detector to monitor node health and detect issues, so that I can maintain cluster stability and promptly address any underlying problems affecting performance.
---

# Node Problem Detector (NPD) in Azure Kubernetes Service (AKS) nodes

[Node Problem Detector (NPD)](https://github.com/kubernetes/node-problem-detector) is an open source Kubernetes component that detects node-related problems and reports on them. It runs as a systemd serviced on each node in the cluster and collects various metrics and system information, such as CPU usage, disk usage, and network connectivity. When it detects a problem, it generates *events and/or node conditions*. Azure Kubernetes Service (AKS) uses NPD to monitor and manage nodes in a Kubernetes cluster running on the Azure cloud platform. The AKS Linux extension enables NPD by default.

> [!NOTE]
> Upgrades to NPD are independent of the node image and Kubernetes version upgrade processes. If a node pool is unhealthy (that is, in a failed state), new NPD versions aren't installed.

## Node conditions

Node conditions indicate a permanent problem that makes the node unavailable. AKS uses the following node conditions from NPD to expose permanent problems on the node. NPD also emits corresponding Kubernetes events.

|Problem Daemon type| NodeCondition | Reason |  
|---|---|---|
|CustomPluginMonitor| FilesystemCorruptionProblem | FilesystemCorruptionDetected |
|CustomPluginMonitor| KubeletProblem | KubeletIsDown |
|CustomPluginMonitor| ContainerRuntimeProblem | ContainerRuntimeIsDown |
|CustomPluginMonitor| VMEventScheduled | VMEventScheduled |
|CustomPluginMonitor| FrequentUnregisterNetDevice | UnregisterNetDevice|
|CustomPluginMonitor|FrequentKubeletRestart|FrequentKubeletRestart|
|CustomPluginMonitor|FrequentContainerdRestart|FrequentContainerdRestart|
|CustomPluginMonitor|FrequentDockerRestart|FrequentDockerRestart|
|SystemLogMonitor|KernelDeadlock|DockerHung|
|SystemLogMonitor|ReadonlyFilesystem |FilesystemIsReadOnly|

## Events

NPD emits events with relevant information to help you diagnose underlying issues.

|Problem Daemon type| Reason  |  Frequency  |  Description | Action |
|---|---| ---| --| --|
|CustomPluginMonitor|EgressBlocked|30 min| This event checks for connectivity to external [endpoints](#egressblocked) | Check if a firewall or NSG blocking the connectivity to the endpoint getting flagged|
|CustomPluginMonitor|FilesystemCorruptionDetected|5min| This checks for filesystem corruption surfaced by docker | |
|CustomPluginMonitor|KubeletIsDown|30s| This checks if kubelet service is running and healthy | |
|CustomPluginMonitor|ContainerRuntimeIsDown| 30s | This event checks if the container runtime eg: containerd is running and healthy | |
|CustomPluginMonitor|FreezeScheduled|1min|  This event checks if a Freeze Event is scheduled on the node. Check [https://aka.ms/aks/scheduledevents](https://aka.ms/aks/scheduledevents) for more information ||
|CustomPluginMonitor|RebootScheduled|1min|  This event checks if a Reboot Event is scheduled on the node Check [https://aka.ms/aks/scheduledevents](https://aka.ms/aks/scheduledevents) for more information || 
|CustomPluginMonitor|RedeployScheduled|1min|  This event checks if a Redeploy Event is scheduled on the node. Check [https://aka.ms/aks/scheduledevents](https://aka.ms/aks/scheduledevents) for more information || 
|CustomPluginMonitor|TerminateScheduled|1min|  This event checks if a Terminate Event is scheduled on the node. Check [https://aka.ms/aks/scheduledevents](https://aka.ms/aks/scheduledevents) for more information || 
|CustomPluginMonitor|PreemptScheduled|2s|  This event checks if a Preempt Event is scheduled on the node. Check [https://aka.ms/aks/scheduledevents](https://aka.ms/aks/scheduledevents) for more information || 
|CustomPluginMonitor|DNSProblem|
|SystemLogMonitor|OOMKilling|
|SystemLogMonitor|TaskHung|
|SystemLogMonitor|UnregisterNetDevice|
|SystemLogMonitor| KernelOops|
|SystemLogMonitor| DockerSocketCannotConnect|
|SystemLogMonitor| KubeletRPCDeadlineExceeded|
|SystemLogMonitor|KubeletRPCNoSuchContainer|
|SystemLogMonitor|CNICannotStatFS|
|SystemLogMonitor|PLEGUnhealthy|
|SystemLogMonitor|KubeletStart|
|SystemLogMonitor|DockerStart|
|SystemLogMonitor|ContainerdStart|

In certain instances, AKS automatically cordons and drains the node to minimize disruption to workloads. For more information about the events and actions, see [Node autodrain](/azure/aks/node-auto-repair#node-auto-drain).


### EgressBlocked
The list of endpoints checked by the EgressBlocked are listed below

> [!NOTE]
> The actual endpoints will depend on the type of the cluster and the location where it's hosted (Public cloud vs Airgapped clouds). Review the documentation for outbound access [here](/azure/aks/outbound-rules-control-egress). The documentation is for public clouds

Type | Example | Note
|---|---|---|
|MCR | https://mcr.microsoft.com | |
|Microsoft Entra ID |  https://login.microsoftonline.com" ||
|Resource Manager | https://management.azure.com||
|Packages |https://packages.microsoft.com||
|Kube Binary|https://acs-mirror.azureedge.net/acs-mirror/healthz,https://packages.aks.azure.com/acs-mirror/healthz ||


## Check the node conditions and events

* Check the node conditions and events using the `kubectl describe node` command.

    ```azurecli-interactive
    kubectl describe node my-aks-node
    ```

    Your output should look similar to the following example condensed output:

    ```output
    ...
    ...

    Conditions:
      Type                          Status  LastHeartbeatTime                 LastTransitionTime                Reason                          Message
      ----                          ------  -----------------                 ------------------                ------                          -------
      VMEventScheduled              False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   NoVMEventScheduled              VM has no scheduled event
      FrequentContainerdRestart     False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   NoFrequentContainerdRestart     containerd is functioning properly
      FrequentDockerRestart         False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   NoFrequentDockerRestart         docker is functioning properly
      FilesystemCorruptionProblem   False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   FilesystemIsOK                  Filesystem is healthy
      FrequentUnregisterNetDevice   False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   NoFrequentUnregisterNetDevice   node is functioning properly
      ContainerRuntimeProblem       False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:40 +0000   ContainerRuntimeIsUp            container runtime service is up
      KernelDeadlock                False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   KernelHasNoDeadlock             kernel has no deadlock
      FrequentKubeletRestart        False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   NoFrequentKubeletRestart        kubelet is functioning properly
      KubeletProblem                False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   KubeletIsUp                     kubelet service is up
      ReadonlyFilesystem            False   Thu, 01 Jun 2023 19:14:25 +0000   Thu, 01 Jun 2023 03:57:41 +0000   FilesystemIsNotReadOnly         Filesystem is not read-only
      NetworkUnavailable            False   Thu, 01 Jun 2023 03:58:39 +0000   Thu, 01 Jun 2023 03:58:39 +0000   RouteCreated                    RouteController created a route
      MemoryPressure                True    Thu, 01 Jun 2023 19:16:50 +0000   Thu, 01 Jun 2023 19:16:50 +0000   KubeletHasInsufficientMemory    kubelet has insufficient memory available
      DiskPressure                  False   Thu, 01 Jun 2023 19:16:50 +0000   Thu, 01 Jun 2023 03:57:22 +0000   KubeletHasNoDiskPressure        kubelet has no disk pressure
      PIDPressure                   False   Thu, 01 Jun 2023 19:16:50 +0000   Thu, 01 Jun 2023 03:57:22 +0000   KubeletHasSufficientPID         kubelet has sufficient PID available
      Ready                         True    Thu, 01 Jun 2023 19:16:50 +0000   Thu, 01 Jun 2023 03:57:23 +0000   KubeletReady                    kubelet is posting ready status. AppArmor enabled
    ...
    ...
    ...
    Events:
      Type    Reason                   Age                  From     Message
      ----    ------                   ----                 ----     -------
      Normal  NodeHasSufficientMemory  94s (x176 over 15h)  kubelet  Node aks-agentpool-40622340-vmss000009 status is now: NodeHasSufficientMemory
    ```

These events are also available in [Container Insights](/azure/azure-monitor/containers/container-insights-overview) through [KubeEvents](/azure/azure-monitor/reference/tables/kubeevents).

## Metrics

NPD also exposes Prometheus metrics based on the node problems, which you can use for monitoring and alerting. These metrics are exposed on port 20257 of the Node IP and Prometheus can scrape them.

The following example YAML shows a scrape config you can use with the [Azure Managed Prometheus add on as a DaemonSet](/azure/azure-monitor/essentials/prometheus-metrics-scrape-configuration#advanced-setup-configure-custom-prometheus-scrape-jobs-for-the-daemonset):

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: ama-metrics-prometheus-config-node
  namespace: kube-system
data:
  prometheus-config: |-
    global:
      scrape_interval: 1m
    scrape_configs:
    - job_name: node-problem-detector
      scrape_interval: 1m
      scheme: http
      metrics_path: /metrics
      relabel_configs:
      - source_labels: [__metrics_path__]
        regex: (.*)
        target_label: metrics_path
      - source_labels: [__address__]
        replacement: '$NODE_NAME'
        target_label: instance
      static_configs:
      - targets: ['$NODE_IP:20257']
```

The following example shows the scraped metrics:

```output
problem_gauge{reason="UnregisterNetDevice",type="FrequentUnregisterNetDevice"} 0
problem_gauge{reason="VMEventScheduled",type="VMEventScheduled"} 0
```

## Next steps

For more information on NPD, see [kubernetes/node-problem-detector](https://github.com/kubernetes/node-problem-detector).

