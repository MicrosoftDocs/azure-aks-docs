---
title: Monitor Data Plane and Control Plane Logs in Azure Kubernetes Application Network (Preview)
description: Learn how to enable and view data plane and control plane logs for Azure Kubernetes Application Network in Azure Monitor using Container Insights and diagnostic settings.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: how-to
ms.date: 10/30/2026
ai-usage: ai-assisted
---

# Monitor data plane and control plane logs in Azure Kubernetes Application Network (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network provides two types of logging that you can configure based on your monitoring and troubleshooting requirements: **data plane logs** and **control plane logs**.

- **Data plane logs**: Include logs from application workloads, `applink-system` namespace components, and Envoy proxy access logs.
- **Control plane logs**: Include Istiod logs from the Azure Kubernetes Application Network control plane components.

Configure data plane log collection and control plane diagnostic settings separately. If your AKS cluster already has Container Insights enabled, its existing collection settings apply. This article describes how to configure both log paths and view them in Azure Monitor.

## Set environment variables

- Set environment variables for your selected workflow using the following commands:

    ```bash
    export SUBSCRIPTION=<subscription-id>

    # Set if specifying an existing or creating a new Log Analytics workspace
    export LAW_NAME=<log-analytics-workspace-name>

    # Set for resource group, location, and AKS cluster name
    export AKS_RG=<aks-resource-group>
    export LOCATION=<location>
    export CLUSTER_NAME=<aks-cluster-name>

    # Set for Azure Kubernetes Application Network member resource group, name, and member name
    export APPNET_RG=<appnet-resource-group>
    export APPNET_NAME=<appnet-name>
    export APPNET_MEMBER_NAME=<appnet-member-name>
    ```

## Enable data plane logs

Data plane logs include logs from your workloads/applications and `applink-system` workloads (Ztunnel and Istio CNI). The Azure Container Insights add-on is the preferred way to enable and view logs for troubleshooting.

When enabling data plane logs, you have the option to specify an existing Log Analytics workspace, use the default workspace for your resource group, or create a new workspace.

### Create a new Log Analytics workspace

- If creating a new Log Analytics workspace, use the [`az monitor log-analytics workspace create`](/cli/azure/monitor/log-analytics/workspace#az-monitor-log-analytics-workspace-create) command:

    ```azurecli-interactive
    az monitor log-analytics workspace create \
        --resource-group $AKS_RG \
        --workspace-name $LAW_NAME \
        --location $LOCATION
    ```

### Enable Container Insights add-on on your AKS cluster

- Enable the Container Insights add-on for your Azure Kubernetes Application Network member cluster (optionally omitting the workspace ID) using the [`az aks enable-addons`](/cli/azure/aks#az-aks-enable-addons) command.

    ```azurecli-interactive
     az aks enable-addons \
      --addon monitoring \
      --name $CLUSTER_NAME \
      --resource-group $AKS_RG \
      --workspace-resource-id /subscriptions/$SUBSCRIPTION/resourcegroups/$AKS_RG/providers/microsoft.operationalinsights/workspaces/$LAW_NAME
    ```

### View logs

- View the logs by navigating to the Log Analytics workspace and running the following query:

    ```kusto
    ContainerLogV2
    | where TimeGenerated > ago(45m)
    | where PodNamespace == "applink-system"
    ```

### Envoy access logs

Use the [Telemetry API][istio-telemetry] as described in the following steps to enable Envoy access-log generation. Container Insights collects the proxy's standard output and sends it to your Log Analytics workspace, so collection must include the namespace where the proxy runs.

For HTTP request-level logs, traffic must pass through an Envoy waypoint or gateway. Traffic that only passes through ztunnel doesn't produce Envoy HTTP access logs. For waypoint deployment and enrollment steps, see [Traffic management use cases][appnet-waypoints].

> [!NOTE]
> A namespace can have only one Telemetry default without a workload selector or `targetRefs`. If a default already exists, merge the access-logging configuration into that resource instead of creating another default. Namespace-specific or targeted access-logging settings override the corresponding mesh-wide settings.

1. To enable Envoy access logging for a namespace, apply the following example. For an application namespace other than `default`, replace `default` in both the command and `metadata.namespace`.

    ```bash
    cat <<EOF | kubectl apply -n default -f -
    apiVersion: telemetry.istio.io/v1
    kind: Telemetry
    metadata:
      name: namespace-access-logging
      namespace: default
    spec:
      accessLogging:
      - providers:
        - name: envoy
        disabled: false
    EOF
    ```

1. To set the mesh-wide default for Envoy access logging, apply the configuration to the mesh root namespace, `applink-system`, in each member cluster where you want the default. Set the namespace in both the command and `metadata.namespace`.

    > [!NOTE]
    > Removing `metadata.namespace` doesn't create a mesh-wide policy.

    ```bash
    cat <<EOF | kubectl apply -n applink-system -f -
    apiVersion: telemetry.istio.io/v1
    kind: Telemetry
    metadata:
      name: mesh-access-logging
      namespace: applink-system
    spec:
      accessLogging:
      - providers:
        - name: envoy
        disabled: false
    EOF
    ```

    The namespace and mesh-wide examples configure defaults at different scopes. A namespace-specific setting takes precedence over the mesh-wide default.

1. Generate application traffic through the waypoint or gateway, then query its container output in the Log Analytics workspace used by Container Insights. Replace `default` with the namespace where the proxy runs. This query includes proxy component logs as well as access logs:

    ```kusto
    ContainerLogV2
    | where TimeGenerated > ago(45m)
    | where PodNamespace == "default"
    | where ContainerName == "istio-proxy"
    | project TimeGenerated, PodNamespace, PodName, LogMessage
    | order by TimeGenerated desc
    | take 10
    ```

### Enable control plane logs

To enable control plane logs, you create a diagnostic setting and send logs to the Log Analytics workspace.

1. Set an environment variable for your diagnostic setting name using the following command:

    ```bash
    export DS_NAME=<diagnostic-settings-name>
    ```

1. Create a diagnostic setting for your Azure Kubernetes Application Network member resource and specify the Log Analytics workspace as the destination using the [`az monitor diagnostic-settings create`](/cli/azure/monitor/diagnostic-settings#az-monitor-diagnostic-settings-create) command.

    ```azurecli-interactive
    az monitor diagnostic-settings create \
    --resource /subscriptions/$SUBSCRIPTION/resourceGroups/$APPNET_RG/providers/Microsoft.AppLink/appLinks/$APPNET_NAME/appLinkMembers/$APPNET_MEMBER_NAME \
    --workspace /subscriptions/$SUBSCRIPTION/resourcegroups/$AKS_RG/providers/microsoft.operationalinsights/workspaces/$LAW_NAME \
    --logs "[{category:istiod,enabled:true}]" \
    --name $DS_NAME
    ```

1. Once enabled, navigate to the Log Analytics workspace and run the following query:

    > [!NOTE]
    > Replace the placeholders in the `appnetMemberResourceId` variable with your member's values. Log Analytics doesn't expand Bash environment variables. Resource ID filters use the case-insensitive `=~` operator.

    ```kusto
    let appnetMemberResourceId = "/subscriptions/<subscription-id>/resourceGroups/<appnet-resource-group>/providers/Microsoft.AppLink/appLinks/<appnet-name>/appLinkMembers/<appnet-member-name>";
    MeshControlPlane
    | where TimeGenerated > ago(1h)
    | where _ResourceId =~ appnetMemberResourceId
    ```

## Log tables and schema

The following tables contain Azure Kubernetes Application Network logs in your Log Analytics workspace:

| Log table | Description |
| --------- | ----------- |
| `ContainerLogV2` | Contains your application/workload logs |
| `MeshControlPlane` | Contains Istiod logs |

### Schema

To find the `ContainerLogV2` schema, see [ContainerLogV2 columns](/azure/azure-monitor/reference/tables/containerlogv2#columns).

`MeshControlPlane` is a custom table with the following schema:

| # | Column name | Type |
| - | ----------- | ---- |
| 0 | TenantId | string |
| 1 | TimeGenerated | datetime |
| 2 | Category | string |
| 3 | Level | string |
| 4 | Message | string |
| 5 | Container | string |
| 6 | PodName | string |
| 7 | SourceSystem | string |
| 8 | Type | string |
| 9 | _ResourceId | string |

## Sample queries

### Filter logs by AKS cluster resource ID

- Filter logs based on your AKS managed cluster resource ID in the `ContainerLogV2` table by using the following query. Replace the placeholders in the `aksClusterResourceId` variable with your cluster's values:

    ```kusto
    let aksClusterResourceId = "/subscriptions/<subscription-id>/resourceGroups/<aks-resource-group>/providers/Microsoft.ContainerService/managedClusters/<aks-cluster-name>";
    ContainerLogV2
    | where TimeGenerated > ago(45m)
    | where _ResourceId =~ aksClusterResourceId
    ```

### Filter logs by Azure Kubernetes Application Network member resource ID

- Filter logs based on your Azure Kubernetes Application Network member resource ID in the `MeshControlPlane` table for control plane logs by using the following query. Replace the placeholders in the `appnetMemberResourceId` variable with your member's values:

    ```kusto
    let appnetMemberResourceId = "/subscriptions/<subscription-id>/resourceGroups/<appnet-resource-group>/providers/Microsoft.AppLink/appLinks/<appnet-name>/appLinkMembers/<appnet-member-name>";
    MeshControlPlane
    | where TimeGenerated > ago(45m)
    | where Level =~ "ERROR"
    | where _ResourceId =~ appnetMemberResourceId
    ```

    The following screenshot shows an example of the Application Network Istiod errors in Azure Monitor Logs:

    :::image type="content" source="./media/logs/mesh-control-plane-logs.png" alt-text="Screenshot of example Application Network Istiod errors in Azure Monitor logs." lightbox="./media/logs/mesh-control-plane-logs.png":::

## Related content

For more information about Azure Kubernetes Application Network observability and monitoring, see the following articles:

- [Overview of Azure Kubernetes Application Network observability](./observability.md)
- [Configure and view Azure Kubernetes Application Network metrics](./metrics.md)

<!--- LINKS --->
[istio-telemetry]: https://istio.io/latest/docs/reference/config/telemetry/
[appnet-waypoints]: ./traffic-management-use-cases.md#install-waypoint-and-mark-services-as-global
