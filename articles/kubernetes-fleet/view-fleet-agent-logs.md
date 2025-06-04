---
title: View agent logs in Azure Kubernetes Fleet Manager
description: Learn how to set up, configure, and access Fleet agent logs, for monitoring and troubleshooting in Azure Kubernetes Fleet Manager
ms.topic: how-to
ms.service: azure-kubernetes-fleet-manager
ms.date: 05/30/2025
author: michaelawyu
ms.author: chenyu1
---

# View agent logs in Azure Kubernetes Fleet Manager

This article shows you how to view Fleet agent logs from your hub and member clusters in Azure Kubernetes Fleet Manager. 
If you have a Fleet with the hub cluster mode enabled, Azure Kubernetes Fleet Manager installs Fleet agents in both the
hub cluster and the member clusters to facilitate communications and orchestrate operations across the Fleet, in support of
Fleet's workload orchestration and load balancing capabilities. These agents generate logs that provide insights into:

- Agent health and connectivity status
- Workload orchestration configuration changes and operation updates 
- Load balancing configuration changes and operation updates

And you can retrieve these logs for monitoring, troubleshooting, and/or auditing purposes.

## Configure diagnostic settings on relevant resources

Fleet agent logs are implemented as [resource logs](/azure/azure-monitor/essentials/resource-logs) in Azure Monitor, specifically:

* Fleet agent logs for the Fleet hub cluster are implemented as part of the resource logs for the Fleet resource.
    * Two agents are installed on the Fleet hub cluster, commonly known as the Fleet hub agents, which include:
        * `fleet-hub-agent`: the Fleet agent that manages cluster memberships and processes workload orchestration tasks on the hub cluster side (for example, scheduling, rolling out changes).
        * `fleet-hub-net-controller-manager`: the Fleet agent that processes load balancing tasks on the hub cluster side.
* Fleet agent logs for a Fleet member cluster are implemented as part of the resource logs for the AKS cluster resource.
    * Three agents are installed on a Fleet member cluster, commonly known as the Fleet member agents, which include:
        * `fleet-member-agent`: the Fleet agent that registers the member cluster to the hub cluster and processes workload orchestration tasks on the member cluster side (for example, applying manifests, drift detection, takeover).
        * `fleet-member-net-controller-manager`: the Fleet agent that processes load balancing tasks on the member cluster side.
        * `fleet-mcs-controller-manager`: the Fleet agent that facilitates multi-cluster services.

Resource logs aren't collected and stored until you create a diagnostic setting to route them to one or more locations.
Azure Monitor supports various locations that you may use, such as an Azure storage account or a Log Analytics workspace;
for a list of available locations and their limitations,
see the [Azure Monitor Diagnostic Settings Destinations](/azure/azure-monitor/platform/diagnostic-settings#destinations) page.

To collect the Fleet agent logs, create a diagnostic setting for the corresponding resource. Depending on your Fleet use case,
you may choose to collect logs from one or more specific Fleet agents only. The most straightforward approach
would be to use the Azure portal; see the steps for further instructions. You may also use the Azure CLI, PowerShell,
the Azure Resource Manager, the REST API, or the Azure Policy to set up things; for more information, see
[Create a Diagnostic Setting](/azure/azure-monitor/essentials/diagnostic-settings).

> [!IMPORTANT]
> There can be substantial costs when collecting the Fleet agent logs. It's recommended that you
> * collect logs only from the most relevant Fleet agents 
> * read the [Cost optimization and Azure Monitor](/azure/azure-monitor/best-practices-cost) document for strategies to reduce your monitoring costs.

### Configure diagnostic settings on the Fleet resource for Fleet hub agent logs

1. Sign in to the [Azure portal](https://portal.azure.com/).
2. In the search box, enter **Kubernetes Fleet Manager** and select **Kubernetes Fleet Manager** from the search results.
3. In the list of all Fleet resources, find the Fleet from which you would like to collect Fleet hub agent logs. Click on the Fleet name.
    You may need to adjust the filter conditions to locate the Fleet resource you want.
4. Select **Diagnostic settings** under **Monitoring** on the resource's menu.
5. Select **Add diagnostic setting**.
6. Enter a name for the diagnostic setting. 
7. For the log categories, make sure that at least one of the two categories,
`fleet-hub-agent` and `fleet-hub-net-controller-manager`, is selected. You may also pick other log categories as needed.
8. For the destination details, pick the destination you prefer. More options appear that ask you for extra
destination information. For more information, see [Create a Diagnostic Setting](/azure/azure-monitor/essentials/diagnostic-settings).
9. Select **Save**.

After a few moments, the new setting appears in your list of diagnostic settings for this resource. Logs are streamed to the specified destinations as new data is generated. It may take a while between when agent emits a log
and when it appears in the destination of your choice.

### Configure diagnostic settings on the member AKS cluster resource for Fleet member agent logs

1. Sign in to the [Azure portal](https://portal.azure.com/).
2. In the search box, enter **Kubernetes Services** and select **Kubernetes Services** from the search results.
3. In the list of all AKS cluster resources, find the AKS cluster that you have joined to your Fleet as a member cluster and from which you would like to collect Fleet member agent logs. Click on the AKS cluster name.
    You may need to adjust the filter conditions to locate the AKS cluster resource you want.
4. Select **Diagnostic settings** under **Monitoring** on the resource's menu.
5. Select **Add diagnostic setting**.
6. Enter a name for the diagnostic setting. 
7. For the log categories, make sure that at least one of the three categories,
`fleet-member-agent`, `fleet-member-net-controller-manager`, and `fleet-mcs-controller-manager`, is selected.
You may also pick other log categories as needed.
8. For the destination details, pick the destination you prefer. Additional option appear that ask you for more
destination information. For more information, see [Create a Diagnostic Setting](/azure/azure-monitor/essentials/diagnostic-settings).
    If you plan to use a Log Analytics workspace as the destination, an AKS cluster resource supports both the
    Azure Diagnostics mode and the resource-specific mode. For differences between the two modes, see the explanation on the
    [Send to Log Analytics workspace](/azure/azure-monitor/platform/resource-logs#send-to-log-analytics-workspace) page.
9. Select **Save**.

After a few moments, the new setting appears in your list of diagnostic settings for this resource. Logs are streamed to the specified destinations as new data is generated. It may take a while between when the agent emits a log
and when it appears in the destination of your choice.

## View Fleet agent logs

To view the Fleet agent logs in the destination of your choice, see
[Send Azure resource logs to Log Analytics workspaces, Event Hubs, or Azure Storage](/azure/azure-monitor/platform/resource-logs).

> [!NOTE]
> If you use a Log Analytics workspace as the destination:
> * with the Azure Diagnostics mode, Fleet member agent logs can be found under the `AzureDiagnostics` table.
> * with the resource-specific mode, Fleet member agent logs can be found under the `AKSControlPlane` table.

### Understand Fleet agent logs

Fleet agent logs are written in the `klog` nonstructured format; the format is

```
[IWEF]yyyymmdd hh:mm:ss.uuuuuu threadid file:line msg kvs
```

where:

* `[IWEF]` is the log level.
    * `I` represents the `info` level.
    * `W` represents the `warning` level.
    * `E` represents the `error` level.
    * `F` represents the `fatal` level.
* `yyyymmdd` is the year (`yyyy`), month (`mm`), and day (`dd`) when the log is emitted.
* `hh:mm:ss.uuuuuu` is the timestamp (`hh` for hours, `mm` for minutes, `ss` for seconds, and `uuuuuu` for microseconds) when the log is emitted.
* `threadid` is the thread ID (PID/TID) of the Fleet agent process/thread.
* `file:line` is the file name and line number of the source code which emits the logs.
* `msg` is the log message.
* `kvs` is a list of key-value pairs (for example, `work=123`) that provides additional information, such as the API object that the log message involves.

You might want to cross-reference a log message with the Fleet agent source code to better understand the log message in context.
For the Fleet agents `fleet-hub-agent` and `fleet-member-agent`,
see the [KubeFleet GitHub repository](https://github.com/kubefleet-dev/kubefleet);
for `fleet-hub-net-controller-manager`, `fleet-member-net-controller-manager`, and `fleet-mcs-controller-manager`, see the
[Azure Fleet Networking GitHub repository](https://github.com/azure/fleet-networking). 

### Useful Kusto queries

The following list of Kusto queries that might help you easier search Fleet agent logs in a Log Analytics workspace:

> [!NOTE]
> The examples assume that you use Azure Diagnostics mode when collecting Fleet member agent logs. If you
> have the resource-specific mode enabled, use the `AKSControlPlane` table instead for the applicable query examples.

* Retrieve the latest 1,000 log entries from all Fleet hub agents.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category in ("fleet-hub-agent", "fleet-hub-net-controller-manager")
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries from all Fleet member agents.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category in ("fleet-member-agent", "fleet-member-net-controller-manager", "fleet-mcs-controller-manager")
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages cluster memberships on the hub cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "v1beta1/member_controller.go"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet processes the `ClusterResourcePlacement` API objects.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "clusterresourceplacement/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet schedules workloads.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "scheduler/" or log_s contains "framework/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet processes rolling updates.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "rollout/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet processes staged updates.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "updaterun/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet synchronizes workloads to the member clusters.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-agent"
| where log_s contains "workgenerator/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet reports cluster memberships on the member cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-member-agent"
| where log_s contains "v1beta1/member_controller.go"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet applies manifests to a specific member cluster.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-member-agent"
| where log_s contains "workapplier/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages endpoint exports/imports for networking capabilities on the hub cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-net-controller-manager"
| where log_s contains "endpointsliceexport/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages service exports/imports for networking capabilities on the hub cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-net-controller-manager"
| where log_s contains "serviceimport/" or log_s contains "internalserviceimport/" or log_s contains "internalserviceexport/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages Azure Traffic Manager related resources for networking capabilities.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your Fleet resource.
// To view the ID, go to the Fleet resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-hub-net-controller-manager"
| where log_s contains "trafficmanagerbackend/" or log_s contains "trafficmanagerprofile/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages endpoint exports/imports for networking capabilities on the member cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-member-net-controller-manager"
| where log_s contains "endpointslice/" or log_s contains "endpointsliceexport/" or log_s contains "endpointsliceimport/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages service exports/imports for networking capabilities on the member cluster side.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-member-net-controller-manager"
| where log_s contains "serviceexport/" or log_s contains "serviceimport/"
| order by TimeGenerated desc
| take 1000
```

* Retrieve the latest 1,000 log entries on how Fleet manages multi-cluster services for networking capabilities.

```kusto
// Replace YOUR-RESOURCE-ID with the value of your AKS member cluster resource.
// To view the ID, go to the AKS cluster resource page, and select JSON view on the overview page.
AzureDiagnostics
| where _ResourceId == YOUR-RESOURCE-ID
| where Category == "fleet-mcs-controller-manager"
| where log_s contains "multiclusterservice/"
| order by TimeGenerated desc
| take 1000
```
