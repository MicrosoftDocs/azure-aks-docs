---
title: "Configure alerting of Update Runs for Azure Kubernetes Fleet Manager"
description: See how to set up alerts for Azure Kubernetes Fleet Manager Update Runs using Azure Resource Graph and Azure Monitor.
ms.topic: how-to
ms.date: 03/05/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Configure monitoring and alerting of Update Runs for Azure Kubernetes Fleet Manager

Fleet administrators can monitor the status of long-running update runs by configuring alerts in Azure Monitor. Fleet update run resource changes are ingested into [Azure Resource Graph][resource-graph], allowing administrators to configure alerts and automations via Azure Monitor and Log Analytics.

Data about manual or auto-upgrade update runs are stored in Azure Resource Graph, giving administrators the opportunity to query based on Fleet name, [update run status][rest-api-statuses], update stages, and cluster name.
 
Regardless of which Azure Subscription or Region your fleet's member clusters are located in, the update run data is always in the Azure Resource Graph of the Azure Subscription of the Fleet Manager resource.

In order to query your update run data, you need to use queries written using the [Kusto Query Language (KQL)][kusto-query-docs].

## Understand update run data in Azure Resource Graph

To learn how to work with Azure Resource Graph and Fleet update run data, let's use the Azure Resource Graph Explorer to query update run data.

1. Start by opening the [Azure Resource Graph Explorer](https://ms.portal.azure.com/#view/HubsExtension/ArgQueryBlade) in the Azure portal.

1. Select **Table** and then expand **aksresources**. Fleet Manager's resources have the prefix `microsoft.containerservice/fleets`.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-azure-resource-graph-explorer.png" alt-text="Screenshot of the Azure Resource Graph Explorer with the aksresources Table expanded." lightbox="./media/monitor-update-runs/monitor-update-run-azure-resource-graph-explorer.png":::

1. In the **Table** pane, select **aksresources** to add it to the explorer query box.

1. Now select **microsoft.containerservices/fleets/updateruns**. Your explorer query box should look like the following KQL sample.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    ```

1. Run the query to retrieve all update run data held in the Azure Resource Graph for the current Azure Subscription. Update run data is held as a JSON object in the `properties` field of the result. You can view a sample of this object [later in this article](#sample-update-run-json-properties-result).

### Filter to a Fleet Manager instance

When you build a Kusto query against Azure Resource Graph, you can use the following sample query as a guide on how to select only update runs associated with a particular Fleet Manager resource.

You can add a manual filter to your explorer query to select your Fleet Manager instance as follows.

1. In the explorer query add the additional where clause manually, replacing the `your-fleet-name` placeholder with the name of your Fleet Manager.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    | where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
    ```

1. Run the query to see the result set only includes update runs for the specified Fleet Manager.

### Filter by update run status

Now that you know how to find update runs associated with your Fleet Manager you can add further filters so results are based on the state of the update run.

1. Update your explorer query by expanding the `microsoft.containerservice/fleets/updateruns` node, followed by `status` and `status`. 

1. Select `state` so that the property is added to your explorer query.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-query-add-filter.png" alt-text="Screenshot of selecting a field in an update run in Azure Resource Graph Explorer to add it to the query." lightbox="./media/monitor-update-runs/monitor-update-run-query-add-filter.png":::

    Your explorer query should be similar to the following sample.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    | where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
    | where properties['status']['status']['state'] == "INSERT_VALUE_HERE"
    ```

1. Replace the `INSERT_VALUE_HERE` placeholder with an appropriate [update run status][rest-api-statuses] value. For example, to receive only failed update runs set this value to `Failed`.
   
1. Run the query and you receive only update runs for your Fleet Manager that have a matching status.

## Advanced filtering

Azure Resource Graph Explorer offers an easy way to start exploring data you have about update runs.

The following advanced Kusto query options make it easier to use further update run properties when building your alerts.

- [mv-expand][kusto-mv-expand] can be used to unpack the stages, groups, and member clusters in an update run record.
- [json_parse][kusto-json-parse] can be used to make it easier to reference JSON objects without using nested arrays.
 
In the following sample query we can determine which member cluster in the `canary` group of the `prod` stage failed. If no cluster in this group/stage failed then no rows are returned. 
  
```kusto
aksresources
| where type == "microsoft.containerservice/fleets/updateruns"
| where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
| extend parsedProperties = parse_json(properties)
| mv-expand stages = parsedProperties.status.stages
| mv-expand groups = stages.groups
| mv-expand members = groups.members
| where properties.status.status.state == "Failed"
| where stages.name == "prod" and groups.name == "canary" and members.status.state == "Failed"
| project stageName = stages.name, groupName = groups.name, memberName = members.name, memberState = members.status.state, memberStartTime = members.status.startTime
```

## Building alerts 

Now that you understand the Azure Resource Graph data available you can use [Azure Monitor alert rules][monitor-log-search] with log search to define when you wish to receive alerts.

1. Start by opening the [Azure Monitor blade](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/overview) in the Azure portal.

1. Select **Alerts** in the left navigation, followed by **+ Create**, then **Alert rule**.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-01.png" alt-text="Screenshot of the Alert rule option highlighted in the Create menu for Azure Monitor Alerts." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-01.png":::

1. On the **Create an alert rule** screen, select **+ Select scope** and in the **Select a resource** blade, navigate to your Fleet Manager resource by selecting the Azure Subscription and resource group it resides in.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-02.png" alt-text="Screenshot showing the selecting of the scope to create a new alert rule." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-02.png":::

1. Select the **Condition** tab and in the **Signal name** select list, choose **Custom log search**. The **Logs** blade loads on the right of the screen.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-03.png" alt-text="Screenshot showing the Condition tab loaded and custom log search selected in the signal name drop-down." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-03.png":::

1. In the **Logs** blade, enter the Resource Graph query you wish to use to trigger an alert. For our sample we alert on any failed update run and include the update run start time.

    > [!NOTE]
    > For Azure Monitor log search queries you must prefix the `aksresources` table with `arg("").`. The remaining syntax is unchanged from the queries used earlier in this article.

    ```kusto
    arg("").aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    | where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
    | extend parsedProps = parse_json(properties)
    | where parsedProps.status.status.state == "Failed"
    | project id, startTime = parsedProps.status.status.startTime
    ```

1. Once you're happy with the results being returned by the query, select **Continue Editing Alert** to close the **Logs** blade. The query is automatically inserted into the **Search query** box. You can continue to edit it here if you wish.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-04.png" alt-text="Screenshot showing how the query text is automatically inserted into the Search query box for the Create alert rule screen." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-04.png":::

1. Scroll down until you see **Alert logic**, using the form field to define the criteria you wish to trigger the alert. It's recommended you use a **Static** Threshold, setting the value to **0**, and the **Operator** to **Greater than**. Adjust the frequency to suit your preferred time period.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-05.png" alt-text="Screenshot showing how to set the Alert logic to Greater than 0 with a check every 5 minutes." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-05.png":::

1. Select **Next: Actions >** or the **Actions** tab to define the actions to take when the alert logic is matched. You can select a range of channels and integration options which are covered in detail in the [Azure Monitor action group documentation][monitor-set-up-action-group].

1. To save the alert rule, select the **Details** tab and choose an appropriate Azure Subscription and resources group. Set the details for the alert rule by choosing a **Severity**, providing an **alert rule name**, optional description, and then select the **Azure Region** to save the alert to. Finally, set the **Identity** you wish to use to run the log query.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-06.png" alt-text="Screenshot showing how to save an Alert rule to a resource group while setting its alert level and name." lightbox="./media/monitor-update-runs/monitor-update-run-set-up-alert-rule-06.png":::

1. Select the **Tags** tab to add any tags you wish, before selecting **Review + create** to create the new alert rule.

The next time the alert rule is triggered, the selected alert groups will be activated and your chosen notifications and integrations will be invoked.  


## Sample update run JSON properties result 

The following sample represents the `properties` payload held in Azure Resource Graph for each update run. You can use this structure to inform how you build you alerting queries or dashboards.

```json
{
    "status": {
        "status": {
            "state": "Pending",
            "startTime": "2025-03-05T13:17:18.277945575Z"
        },
        "nodeImageSelection": {
            "selectedNodeImageVersions": [
                {
                    "version": "AKSAzureLinux-V2gen2-202502.26.0"
                },
                {
                    "version": "AKSWindows-2022-containerd-20348.3207.250214"
                }
            ]
        },
        "stages": [
            {
                "status": {
                    "state": "Pending",
                    "startTime": "2025-03-05T13:17:19.51815878Z"
                },
                "name": "prod",
                "groups": [
                    {
                        "status": {
                            "completedTime": "2025-03-05T13:48:59.049364234Z",
                            "state": "Completed",
                            "startTime": "2025-03-05T13:17:19.51815818Z"
                        },
                        "name": "canary",
                        "members": [
                            {
                                "clusterResourceId": "/subscriptions/a22dfd3c-4a99-4d5a-9e2f-70ba55d59fbe/resourceGroups/rg-contoso-demo-01/providers/Microsoft.ContainerService/managedClusters/consoto-web-01",
                                "status": {
                                    "completedTime": "2025-03-05T13:31:09.441388843Z",
                                    "state": "Completed",
                                    "startTime": "2025-03-05T13:17:19.51815698Z"
                                },
                                "name": "member-consoto-web-01",
                                "operationId": "b046b73e-8827-45a7-8696-d1da0815941b",
                                "message": "Skipped upgrade of following agent pool(s): current node image version \"AKSWindows-2022-containerd-20348.3207.250214\" of agent pool \"win\" is already at or ahead of target upgrade version \"AKSWindows-2022-containerd-20348.3207.250214\"."
                            },
                            {
                                "clusterResourceId": "/subscriptions/3a22dfd3c-4a99-4d5a-9e2f-70ba55d59fbe/resourceGroups/rg-contoso-demo-01/providers/Microsoft.ContainerService/managedClusters/consoto-web-02",
                                "status": {
                                    "completedTime": "2025-03-05T13:48:59.049364234Z",
                                    "state": "Completed",
                                    "startTime": "2025-03-05T13:31:09.495402941Z"
                                },
                                "name": "member-consoto-web-02",
                                "operationId": "759816e9-d924-4ff4-a992-97aac2a2dddb"
                            }
                        ]
                    },
                    {
                        "status": {
                            "state": "Pending",
                            "startTime": "2025-03-05T13:17:19.51826128Z"
                        },
                        "name": "apac",
                        "members": [
                            {
                                "clusterResourceId": "/subscriptions/fe691fe1-d1ce-43b9-869a-73c4a14cdafc/resourceGroups/rg-contoso-demo-02/providers/Microsoft.ContainerService/managedClusters/consoto-app-01",
                                "status": {
                                    "state": "Pending",
                                    "startTime": "2025-03-05T13:17:19.51826048Z",
                                    "error": {
                                        "message": "target upgrade node image version \"AKSAzureLinux-V2gen2-202502.26.0\" for agent pool pool is not available in region \"australiaeast\" \n",
                                        "code": "NodeImageVersionNotAvailable"
                                    }
                                },
                                "name": "member-consoto-app-01",
                                "message": "set member: member-consoto-app-01 to Pending due to failed validation err: target upgrade node image version \"AKSAzureLinux-V2gen2-202502.26.0\" for agent pool pool is not available in region \"australiaeast\" \n"
                            }
                        ]
                    },
                    {
                        "status": {
                            "state": "Pending",
                            "startTime": "2025-03-05T13:17:19.518346681Z"
                        },
                        "name": "europe",
                        "members": [
                            {
                                "clusterResourceId": "/subscriptions/fe691fe1-d1ce-43b9-869a-73c4a14cdafc/resourceGroups/rg-contoso-demo-03/providers/Microsoft.ContainerService/managedClusters/contoso-db-01",
                                "status": {
                                    "state": "Pending",
                                    "startTime": "2025-03-05T13:17:19.518345781Z",
                                    "error": {
                                        "message": "target upgrade node image version \"AKSAzureLinux-V2gen2-202502.26.0\" for agent pool pool is not available in region \"northeurope\" \n",
                                        "code": "NodeImageVersionNotAvailable"
                                    }
                                },
                                "name": "member-contoso-db-01",
                                "message": "set member: member-contoso-db-01 to Pending due to failed validation err: target upgrade node image version \"AKSAzureLinux-V2gen2-202502.26.0\" for agent pool pool is not available in region \"northeurope\" \n"
                            }
                        ]
                    }
                ]
            }
        ]
    },
    "provisioningState": "Succeeded",
    "managedClusterUpdate": {
        "nodeImageSelection": {
            "customNodeImageVersions": [
                {
                    "version": "AKSAzureLinux-V2-202502.26.0"
                },
                {
                    "version": "AKSWindows-23H2-gen2-25398.1425.250214"
                }
            ],
            "type": "Custom"
        },
        "upgrade": {
            "type": "NodeImageOnly"
        }
    },
    "updateStrategyId": "/subscriptions/00a3c596-fcb8-43ec-bf56-a2d19b4d3663/resourceGroups/flt-contoso-demo/providers/Microsoft.ContainerService/fleets/contoso-fleet-01/updateStrategies/safedeployment",
    "strategy": {
        "stages": [
            {
                "name": "prod",
                "afterStageWaitInSeconds": 0,
                "groups": [
                    {
                        "name": "canary"
                    },
                    {
                        "name": "apac"
                    },
                    {
                        "name": "europe"
                    }
                ]
            }
        ]
    }
}
```



## Related content

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- LINKS -->
[resource-graph]: /azure/governance/resource-graph/overview
[rest-api-statuses]: /rest/api/fleet/update-runs/get#updatestate
[kusto-query-docs]: /kusto/query
[kusto-mv-expand]: /kusto/query/mv-expand-operator
[kusto-json-parse]: /kusto/query/parse-json-function
[monitor-log-search]: /azure/azure-monitor/alerts/alerts-create-log-alert-rule
[monitor-set-up-action-group]: /azure/azure-monitor/alerts/action-groups#create-an-action-group-in-the-azure-portal