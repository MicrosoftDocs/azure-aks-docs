---
title: Monitor Kubernetes audit events in AKS Hybrid and Edge
description: Learn how to create a diagnostic setting to access Kubernetes audit logs.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 02/26/2024
ms.reviewer: guanghu
ms.custom: hyperconverged

---

# Monitor Kubernetes audit events

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

You can access Kubernetes audit logs in Kubernetes control plane logs. Control plane logs for AKS clusters are implemented as [resource logs](/azure/azure-monitor/essentials/resource-logs) in Azure Monitor. Resource logs aren't collected and stored until you create a diagnostic setting to route them to one or more locations. You typically send them to a Log Analytics workspace, which is where most of the data for Container Insights is stored.

## Create a diagnostic setting

Before you create the diagnostic setting, install the **Arc K8S** extension, which enables log collection from the AKS cluster.

Install the Arc K8S extension by running the following command:

```azurecli
az k8s-extension create -g <resouerce-group-name> -c <cluster-name> --cluster-type connectedClusters --extension-type Microsoft.AKSArc.AzureMonitor --name "aksarc-azuremonitor" --auto-upgrade true
```

After the extension installs successfully, follow the instructions in [Diagnostic settings in Azure Monitor](/azure/azure-monitor/essentials/diagnostic-settings#resource-logs) to create a diagnostic setting using the Azure portal, Azure CLI, or PowerShell. During this process, you can specify which categories of logs to collect. The categories for AKS are listed in the [Monitoring data reference](/azure/azure-monitor/logs/manage-logs-tables).

The example command is as follows:

```azurecli
az monitor diagnostic-settings create –-name <Diagnostics_Setting_Name> --resource <Cluster_Resource_ID> --logs "[{category:kube-audit,enabled:true},{category:kube-audit-admin,enabled:true},{category:kube-apiserver,enabled:true},{category:kube-controller-manager,enabled:true},{category:kube-scheduler,enabled:true},{category:cluster-autoscaler,enabled:true},{category:cloud-controller-manager,enabled:true},{category:guard,enabled:true},{category:csi-aksarcdisk-controller,enabled:true},{category:csi-aksarcsmb-controller,enabled:true},{category:csi-aksarcnfs-controller,enabled:true}]" --workspace <LA_Workspace_resource_ID>
```

:::image type="content" source="../../media/kubernetes-monitor-audit-events/diagnostic-settings.png" alt-text="Screenshot of portal blade showing diagnostic settings." lightbox="../../media/kubernetes-monitor-audit-events/diagnostic-settings.png":::

AKS supports either [Azure diagnostics mode](/azure/azure-monitor/essentials/resource-logs#azure-diagnostics-mode) or [resource-specific mode](/azure/azure-monitor/essentials/resource-logs#resource-specific) for resource logs. The mode specifies the tables in the Log Analytics workspace to which the data is sent. Azure diagnostics mode sends all data to the [AzureDiagnostics table](/azure/azure-monitor/reference/tables/azurediagnostics), while resource-specific mode sends data to [ArcK8SAudit](/azure/azure-monitor/reference/tables/arck8saudit), [ArcK8SAuditAdmin](/azure/azure-monitor/reference/tables/arck8sauditadmin), and [ArcK8SControlPlane](/azure/azure-monitor/reference/tables/arck8scontrolplane), as shown in the log category table in the next section.

After you save the settings, it can take up to an hour to see the events in the Log Analytics workspace or other supported destination. You can write a KQL query to extract the insights based on the log categories you enabled.

## Delete and disable the diagnostics setting

You can delete the diagnostics setting using the Azure portal, PowerShell, or Azure CLI:

```azurecli
az monitor diagnostic-settings delete -name <diagnostics-setting-name> --resource <resource-name> -g <resource-group-name>
```

After you successfully delete the setting, you can then delete the extension using Azure CLI:

```azurecli
az k8s-extension delete -g <resouerce-group-name> -c <cluster-name> --cluster-type connectedClusters --name "hybridaks-observability"
```

## Next steps

[Monitor Kubernetes object events](kubernetes-monitor-object-events.md)
