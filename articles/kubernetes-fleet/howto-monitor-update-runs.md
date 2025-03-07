---
title: "Configure alerting of Update Runs for Azure Kubernetes Fleet Manager"
description: See how to setup alerts for Azure Kubernetes Fleet Manager Update Runs using Azure Resource Graph and Azure Monitor.
ms.topic: how-to
ms.date: 03/05/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Configure monitoring and alerting of Update Runs for Azure Kubernetes Fleet Manager

Fleet administrators can monitor the status of long-running update runs by configuring alerts in Azure Monitor. Fleet update run resource changes are ingested into [Azure Resource Graph][resource-graph], allowing administrators to configure alerts and automations via Azure Monitor and Log Analytics.

Data about manual or auto-upgrade update runs are stored in Azure Resource Graph, giving adminstrators the opportunity to query based on Fleet name, [update run status][rest-api-statuses], update stages and cluster name.
 
Regardless of which Azure Subcription or Region your fleet's member clusters are located in, the update run data is always in the Azure Resource Graph of the Azure Subscription of the Fleet Manager resource.

In order to query your update run data, you will need to use queries written using the [Kusto Query Language (KQL)][kusto-query-docs].

## Understand update run data in Azure Resource Graph

For the purpose of understanding how to work with Azure Resource Graph and Fleet update run data, let's use the Azure Resource Group Explorer to query update run data.

* Start by opening the [Azure Resource Group Explorer](https://ms.portal.azure.com/#view/HubsExtension/ArgQueryBlade) in the Azure Portal.

* Select **Table** and then expand **aksresources**. You will see Fleet's resources with the prefix of `microsoft.containerservice/fleets`.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-arg-explorer.png" alt-text="A view of the Azure Resource Group Explorer with the aksresources Table expanded." lightbox="./media/monitor-update-runs/monitor-update-run-arg-explorer.png":::

* In the **Table** pane select **aksresources** to add it to the explorer query box.

* Now select **microsoft.containerservices/fleets/updateruns**. You explorer query box should look like the following KQL sample.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    ```

* Run the query and you will recieve back all update run data held in the Azure Resource Group for the current Azure Subscription. Update run data is held as a JSON object in the `properties` field of the result. You can view a sample of this object [later in this article](#sample-update-run-json-properties-result).

### Filter to a Fleet Manager instance

When you build a Kusto query against Azure Resource Graph you can use the following sample query as a guide on how to select only update runs associated with a particular Fleet Manager resource.

You can add a manual filter to your explorer query to select your Fleet Manager instance as follows.

* In the explorer query manually add the additional where clause, replacing the `your-fleet-name` placeholder with the name of your Fleet Manager.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    | where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
    ```

* Run the query to see the result set only includes update runs for the specified Fleet Manager.

### Filter by update run status

Now that you know how to find update runs associated with your Fleet Manager you can add further filters so results are based on the state of the update run.

* Update your explorer query by expanding the `microsoft.containerservice/fleets/updateruns` node, followed by `status` and `status`. 

* Select `state` so that the property is added to your explorer query.

    :::image type="content" source="./media/monitor-update-runs/monitor-update-run-arg-explorer-add-filter.png" alt-text="Selecting a field in an update run in Azure Resource Group Explorer to add it to the query." lightbox="./media/monitor-update-runs/monitor-update-run-arg-explorer-add-filter.png":::

    Your explorer query should contain the following.

    ```kusto
    aksresources
    | where type == "microsoft.containerservice/fleets/updateruns"
    | where id contains ('Microsoft.ContainerService/fleets/your-fleet-name')
    | where properties['status']['status']['state'] == "INSERT_VALUE_HERE"
    ```

* Replace the `INSERT_VALUE_HERE` placeholder with an appropriate [update run status][rest-api-statuses] value. For example, to receive only failed update runs set this value to `Failed`.
   
* Run the query and you will receive only update runs for your Fleet Manager that have a matching status.



## Building alerts 

Now that you have explored the data available you can use Azure Monitor Alerts to trigger based on Azure Resource Graph queries.

```kusto
arg("").aksresources
| where type == "microsoft.containerservice/fleets/updateruns"
| where id contains ('Microsoft.ContainerService/fleets/contoso-fleet-01')
| where properties.updateStrategyId contains ('updateStrategies/safedeployment')
```

If an update run that matches the supplied criteria has been created, even if it is yet to run, you will receive the data back in the query results. Each entry will be simliar to the following sample JSON.

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

* To learn more about resource propagation, see the [open-source Kubernetes Fleet documentation](https://github.com/Azure/fleet/blob/main/docs/concepts/ClusterResourcePlacement/README.md).

<!-- LINKS -->
[fleet-quickstart]: ./quickstart-create-fleet-and-members.md#create-a-fleet-resource
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[resource-graph]: /azure/governance/resource-graph/overview
[rest-api-statuses]: /rest/api/fleet/update-runs/get#updatestate
[fleet-update-strategy]: ./update-create-update-strategy
[kusto-query-docs]: /kusto/query