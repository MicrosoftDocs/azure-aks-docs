---
title: Azure Kubernetes Service (AKS) cost analysis
description: Learn how to use cost analysis to surface granular cost allocation data for your Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
ms.topic: how-to
ms.date: 04/06/2025
---

# Azure Kubernetes Service (AKS) cost analysis

In this article, you learn how to enable cost analysis on Azure Kubernetes Service (AKS) to view detailed cost data for cluster resources.

## About cost analysis

AKS clusters rely on Azure resources, such as virtual machines (VMs), virtual disks, load balancers, and public IP addresses. Multiple applications can use these resources. The resource consumption patterns often differ for each application, so their contribution toward the total cluster resource cost might also vary. Some applications might have footprints across multiple clusters, which can pose a challenge when performing cost attribution and cost management.

When you enable cost analysis on your AKS cluster, you can view detailed cost allocation scoped to Kubernetes constructs, such as clusters and namespaces, and Azure Compute, Network, and Storage resources. The add-on is built on top of [OpenCost](https://www.opencost.io/), an open-source Cloud Native Computing Foundation Incubating project for usage data collection. Usage data is reconciled with your Azure invoice data to provide a comprehensive view of your AKS cluster costs directly in the Azure portal Cost Management views.

For more information on Microsoft Cost Management, see [Start analyzing costs in Azure](/azure/cost-management-billing/costs/quick-acm-cost-analysis).

After enabling the cost analysis add-on and allowing time for data to be collected, you can use the information in [Understand AKS usage and costs](./understand-aks-costs.md) to help you understand your data.

## Prerequisites

* Your cluster must use the `Standard` or `Premium` tier, not the `Free` tier.
* To view cost analysis information, you must have one of the following roles on the subscription hosting the cluster: `Owner`, `Contributor`, `Reader`, `Cost Management Contributor`, or `Cost Management Reader`.
* [Microsoft Entra Workload ID](./workload-identity-overview.md) configured on your cluster.
* If using the Azure CLI, you need version `2.61.0` or later installed.
* Once you have enabled cost analysis, you can't downgrade your cluster to the `Free` tier without first disabling cost analysis.
* Access to the Azure API including Azure Resource Manager (ARM) API. For a list of fully qualified domain names (FQDNs) required, see [AKS Cost Analysis required FQDN](./outbound-rules-control-egress.md#aks-cost-analysis-add-on).

## Limitations

* Kubernetes cost views are only available for the *Enterprise Agreement* and *Microsoft Customer Agreement* Microsoft Azure offer types. For more information, see [Supported Microsoft Azure offers](/azure/cost-management-billing/costs/understand-cost-mgt-data#supported-microsoft-azure-offers).
* Currently, virtual nodes aren't supported.

## Enable cost analysis on your AKS cluster

You can enable the cost analysis with the `--enable-cost-analysis` flag during one of the following operations:

* Creating a `Standard` or `Premium` tier AKS cluster.
* Updating an existing `Standard` or `Premium` tier AKS cluster.
* Upgrading a `Free` cluster to `Standard` or `Premium`.
* Upgrading a `Standard` cluster to `Premium`.
* Downgrading a `Premium` cluster to `Standard` tier.

### Enable cost analysis on a new cluster

Enable cost analysis on a new cluster using the [`az aks create`][az-aks-create] command with the `--enable-cost-analysis` flag. The following example creates a new AKS cluster in the `Standard` tier with cost analysis enabled:

```text
export RANDOM_SUFFIX=$(openssl rand -hex 3)
export RESOURCE_GROUP="AKSCostRG$RANDOM_SUFFIX"
export CLUSTER_NAME="AKSCostCluster$RANDOM_SUFFIX"
export LOCATION="WestUS2"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --location $LOCATION --enable-managed-identity --generate-ssh-keys --tier standard --enable-cost-analysis
```

Results: 

```JSON
{
    "id": "/subscriptions/xxxxx/resourceGroups/AKSCostRGxxxx",
    "location": "WestUS2",
    "name": "AKSCostClusterxxxx",
    "properties": {
        "provisioningState": "Succeeded"
    },
    "tags": null,
    "type": "Microsoft.ContainerService/managedClusters"
}
```

### Enable cost analysis on an existing cluster

Enable cost analysis on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-cost-analysis` flag. The following example updates an existing AKS cluster in the `Standard` tier to enable cost analysis:

```azurecli-interactive
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-cost-analysis
```

Results: 

<!-- expected_similarity=0.3 -->

```JSON
{
    "id": "/subscriptions/xxxxx/resourceGroups/AKSCostRGxxxx",
    "name": "AKSCostClusterxxxx",
    "properties": {
        "provisioningState": "Succeeded"
    }
}
```

> [!NOTE]
> An agent is deployed to the cluster when you enable the add-on. The agent consumes a small amount of CPU and Memory resources.

> [!WARNING]
> The AKS cost analysis add-on Memory usage is dependent on the number of containers deployed. You can roughly approximate Memory consumption using *200 MB + 0.5 MB per container*. The current Memory limit is set to *4 GB*, which supports approximately *7000 containers per cluster*. These estimates are subject to change.

## Disable cost analysis on your AKS cluster

Disable cost analysis using the [`az aks update`][az-aks-update] command with the `--disable-cost-analysis` flag.

```text
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --disable-cost-analysis
```

Results: 

```JSON
{
    "id": "/subscriptions/xxxxx/resourceGroups/AKSCostRGxxxx",
    "name": "AKSCostClusterxxxx",
    "properties": {
        "provisioningState": "Succeeded"
    }
}
```

> [!NOTE]
> If you want to downgrade your cluster from the `Standard` or `Premium` tier to the `Free` tier while cost analysis is enabled, you must first disable cost analysis.

## View the cost data

You can view cost allocation data in the Azure portal. For more information, see [View AKS costs in Microsoft Cost Management](/azure/cost-management-billing/costs/view-kubernetes-costs).

### Cost definitions

In the Kubernetes namespaces and assets views, you might see any of the following charges:

* **Idle charges** represent the cost of available resource capacity that isn't used by any workloads.
* **Service charges** represent the charges associated with the service, like Uptime SLA, Microsoft Defender for Containers, etc.
* **System charges** represent the cost of capacity reserved by AKS on each node to run system processes required by the cluster, including the kubelet and container runtime. [Learn more](./concepts-clusters-workloads.md#resource-reservations).
* **Unallocated charges** represent the cost of resources that couldn't be allocated to namespaces.

> [!NOTE]
> It might take *up to one day* for data to finalize. After 24 hours, any fluctuations in costs for the previous day will have stabilized.

## Troubleshooting

If you're experiencing issues, such as the `cost-agent` pod getting `OOMKilled` or stuck in a `Pending` state, see [Troubleshoot AKS cost analysis add-on issues](/troubleshoot/azure/azure-kubernetes/aks-cost-analysis-add-on-issues).

## Next steps

For more information on cost in AKS, see [Understand Azure Kubernetes Service (AKS) usage and costs](./understand-aks-costs.md).

<!-- LINKS -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update