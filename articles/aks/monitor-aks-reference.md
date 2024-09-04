---
title: Monitoring data reference for Azure Kubernetes Service
description: This article contains important reference material you need when you monitor Azure Kubernetes Service (AKS) by using Azure Monitor.
ms.date: 09/05/2024
ms.custom: horz-monitor
ms.topic: reference
author: nickomang
ms.author: nickoman
ms.subservice: aks-monitoring
---

# Azure Kubernetes Service monitoring data reference

[!INCLUDE [horz-monitor-ref-intro](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-intro.md)]

See [Monitor Azure Kubernetes Service (AKS)](monitor-aks.md) for details on the data you can collect for AKS and how to use it.

[!INCLUDE [horz-monitor-ref-metrics-intro](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-intro.md)]

### Supported metrics for Microsoft.ContainerService/managedClusters

The following table lists the metrics available for the Microsoft.ContainerService/managedClusters resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [Microsoft.ContainerService/managedClusters](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-containerservice-managedclusters-metrics-include.md)]

### Supported metrics for microsoft.kubernetes/connectedClusters

The following table lists the metrics available for the microsoft.kubernetes/connectedClusters resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [microsoft.kubernetes/connectedClusters](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-kubernetes-connectedclusters-metrics-include.md)]

### Supported metrics for microsoft.kubernetesconfiguration/extensions

The following table lists the metrics available for the microsoft.kubernetesconfiguration/extensions resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [microsoft.kubernetesconfiguration/extensions](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-kubernetesconfiguration-extensions-metrics-include.md)]

### Supported metrics for Microsoft.Compute/virtualMachines

The following table lists the metrics available for the Microsoft.Compute/virtualMachines resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [Microsoft.Compute/virtualMachines](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-compute-virtualmachines-metrics-include.md)]

### Supported metrics for Microsoft.Compute/virtualmachineScaleSets

The following table lists the metrics available for the Microsoft.Compute/virtualmachineScaleSets resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [Microsoft.Compute/virtualmachineScaleSets](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-compute-virtualmachinescalesets-metrics-include.md)]

### Supported metrics for Microsoft.Compute/virtualMachineScaleSets/virtualMachines

The following table lists the metrics available for the Microsoft.Compute/virtualMachineScaleSets/virtualMachines resource type.

[!INCLUDE [horz-monitor-ref-metrics-tableheader](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-tableheader.md)]

[!INCLUDE [Microsoft.Compute/virtualMachineScaleSets/virtualMachines](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/metrics/microsoft-compute-virtualmachinescalesets-virtualmachines-metrics-include.md)]

[!INCLUDE [horz-monitor-ref-metrics-dimensions-intro](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-dimensions-intro.md)]

[!INCLUDE [horz-monitor-ref-metrics-dimensions](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-metrics-dimensions.md)]

| Dimension Name | Description |
|:------------------- |:----------------- |
| requestKind | Used by metrics such as *Inflight Requests* to split by type of request. |
| condition | Used by metrics such as *Statuses for various node conditions*, *Number of pods in Ready state* to split by condition type. |
| status | Used by metrics such as *Statuses for various node conditions* to split by status of the condition. |
| status2 | Used by metrics such as *Statuses for various node conditions* to split by status of the condition.  |
| node | Used by metrics such as *CPU Usage Millicores* to split by the name of the node. |
| phase | Used by metrics such as *Number of pods by phase* to split by the phase of the pod. |
| namespace | Used by metrics such as *Number of pods by phase* to split by the namespace of the pod. |
| pod | Used by metrics such as *Number of pods by phase* to split by the name of the pod. |
| nodepool | Used by metrics such as *Disk Used Bytes* to split by the name of the nodepool. |
| device | Used by metrics such as *Disk Used Bytes* to split by the name of the device. |
| 3gppGen | Used by metrics such as *Number of Active PDU Sessions*. |
| Cause | Used by metrics such as *User plane packet drop rate*. |
| Direction | Used by metrics such as *User plane bandwidth*. |
| Dnn | Used by metrics such as *PDU session establishment attempts rate*. |
| Interface | Used by metrics such as *User plane bandwidth*. |
| LUN | Used by metrics such as *Percentage of data disk bandwidth consumed*. |
| PccpId | Used by metrics such as *Number of Active PDU Sessions*. |
| Result | Used by metrics such as *Authentication failure rate*. |
| SiteId | Used by metrics such as *Number of Active PDU Sessions*. |
| Tai | Used by metrics such as *Service request failure rate*. |
| VMName | Used by metrics such as *Amount of physical memory*. |

[!INCLUDE [horz-monitor-ref-resource-logs](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-resource-logs.md)]

### Supported resource logs for Microsoft.ContainerService/fleets

[!INCLUDE [Microsoft.ContainerService/fleets](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/logs/microsoft-containerservice-fleets-logs-include.md)]

### Supported resource logs for Microsoft.ContainerService/managedClusters

[!INCLUDE [Microsoft.ContainerService/managedClusters](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/logs/microsoft-containerservice-managedclusters-logs-include.md)]

### Supported resource logs for microsoft.kubernetes/connectedClusters

[!INCLUDE [microsoft.kubernetes/connectedClusters](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/logs/microsoft-kubernetes-connectedclusters-logs-include.md)]

### Supported resource logs for Microsoft.Compute/virtualMachines

[!INCLUDE [<ResourceType/namespace>](~/reusable-content/ce-skilling/azure/includes/azure-monitor/reference/logs/microsoft-compute-virtualmachines-logs-include.md)]

[!INCLUDE [horz-monitor-ref-logs-tables](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-logs-tables.md)]

### AKS Microsoft.ContainerService/managedClusters

- [AzureActivity](/azure/azure-monitor/reference/tables/azureactivity#columns)
- [AzureDiagnostics](/azure/azure-monitor/reference/tables/azurediagnostics#columns)
- [AzureMetrics](/azure/azure-monitor/reference/tables/azuremetrics#columns)
- [ContainerImageInventory](/azure/azure-monitor/reference/tables/containerimageinventory#columns)
- [ContainerInventory](/azure/azure-monitor/reference/tables/containerinventory#columns)
- [ContainerLog](/azure/azure-monitor/reference/tables/containerlog#columns)
- [ContainerLogV2](/azure/azure-monitor/reference/tables/containerlogv2#columns)
- [ContainerNodeInventory](/azure/azure-monitor/reference/tables/containernodeinventory#columns)
- [ContainerServiceLog](/azure/azure-monitor/reference/tables/containerservicelog#columns)
- [Heartbeat](/azure/azure-monitor/reference/tables/heartbeat#columns)
- [InsightsMetrics](/azure/azure-monitor/reference/tables/insightsmetrics#columns)
- [KubeEvents](/azure/azure-monitor/reference/tables/kubeevents#columns)
- [KubeMonAgentEvents](/azure/azure-monitor/reference/tables/kubemonagentevents#columns)
- [KubeNodeInventory](/azure/azure-monitor/reference/tables/kubenodeinventory#columns)
- [KubePodInventory](/azure/azure-monitor/reference/tables/kubepodinventory#columns)
- [KubePVInventory](/azure/azure-monitor/reference/tables/kubepvinventory#columns)
- [KubeServices](/azure/azure-monitor/reference/tables/kubeservices#columns)
- [Perf](/azure/azure-monitor/reference/tables/perf#columns)
- [Syslog](/azure/azure-monitor/reference/tables/syslog#columns)
- [AKSAudit](/azure/azure-monitor/reference/tables/aksaudit#columns)
- [AKSAuditAdmin](/azure/azure-monitor/reference/tables/aksauditAdmin#columns)
- [AKSControlPlane](/azure/azure-monitor/reference/tables/akscontrolplane#columns)

[!INCLUDE [horz-monitor-ref-activity-log](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-ref-activity-log.md)]

- [Microsoft.ContainerService resource provider operations](/azure/role-based-access-control/resource-provider-operations#containers)

The following table lists a few example operations related to AKS that might be created in the Activity log. Use the Activity log to track information such as when a cluster is created or had its configuration change. You can view this information in the portal or by using [other methods](/azure/azure-monitor/essentials/activity-log#other-methods-to-retrieve-activity-log-events). You can also use it to create an Activity log alert to be proactively notified when an event occurs.

| Operation | Description |
|:---|:---|
| Microsoft.ContainerService/managedClusters/write | Create or update managed cluster |
| Microsoft.ContainerService/managedClusters/delete | Delete Managed Cluster |
| Microsoft.ContainerService/managedClusters/listClusterMonitoringUserCredential/action | List clusterMonitoringUser credential |
| Microsoft.ContainerService/managedClusters/listClusterAdminCredential/action | List clusterAdmin credential |
| Microsoft.ContainerService/managedClusters/agentpools/write | Create or Update Agent Pool |

## Related content

- See [Monitor Azure Kubernetes Service](monitor-aks.md) for a description of monitoring AKS.
- See [Monitor Azure resources with Azure Monitor](/azure/azure-monitor/essentials/monitor-azure-resource) for details on monitoring Azure resources.
