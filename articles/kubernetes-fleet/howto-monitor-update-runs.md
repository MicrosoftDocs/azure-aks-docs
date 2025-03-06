---
title: "Configure monitoring and alerting of Update Runs for Azure Kubernetes Fleet Manager"
description: See how to setup alerts for Azure Kubernetes Fleet Manager Update Runs using Azure Monitor.
ms.topic: how-to
ms.date: 03/05/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Configure monitoring and alerting of Update Runs for Azure Kubernetes Fleet Manager

Fleet administrators can determine the status of long-running update runs within their fleet by using Fleet Manager telemetry and Azure Monitor. Azure Kubernetes Fleet Manager emits telemetry for Update Runs to the [Azure Resource Graph][resource-graph], enabling the use of Azure Monitor and Log Analytics for the purpose of alerting or automation. 

Data about manual or auto-upgrade update runs are stored in Azure Resource Graph, giving adminstrators the opportunity to query based on Fleet name, [update run status][rest-api-statuses], update stages and cluster name.
 
Regardless of which Azure Subcription or Region your fleet's member clusters are in, update run data is always held in the Azure Resource Group in the Azure Subscription in which your Fleet Manager resource resides.

In order to query your update run data, you will need to use queries written using the Kusto Query Language (KQL).

## Inspect update run properties

For the purpose of understanding how to work with Azure Resource Graph and Fleet update run data, let's work with update run data for a Fleet Manager resource named `contoso-fleet-01` that is using an update run strategy named `safedeployment` to update just node images.

* Start by opening the Azure Monitor Logs blade in the Azure Portal.

* When prompted to select a scope, choose the Azure Subscription that contains your Fleet Manager resource.

* In the query box you can query update run data and explore the results. The following sample will list all update runs for the fleet and strategy provided.

```kusto
arg("").aksresources
| where type == "microsoft.containerservice/fleets/updateruns"
| where id contains ('Microsoft.ContainerService/fleets/contoso-fleet-01')
| where properties.updateStrategyId contains ('updateStrategies/safedeployment')
```

If an update run that matches the supplied criteria has been created, even if it is yet to run, you will receive the data back in the query results. Each entry will be simliar to the following sample JSON.

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