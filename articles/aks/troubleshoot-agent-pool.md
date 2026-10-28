---
title: Troubleshoot agent pool issues in Azure Kubernetes Service (AKS)
description: Learn how to diagnose and resolve provisioning, power state, and node health issues in an Azure Kubernetes Service agent pool.
ms.topic: troubleshooting
ms.date: 08/27/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
ai-usage: ai-generated
ms.custom: aeo-round-2
# Customer intent: "As an AKS cluster operator, I want to troubleshoot an unhealthy agent pool, so that I can restore node availability and workload scheduling."
---

# Troubleshoot agent pool issues in Azure Kubernetes Service (AKS)

An Azure Kubernetes Service (AKS) agent pool becomes unavailable when the pool fails to provision, is stopped, or contains nodes that aren't ready to run workloads. These conditions can prevent pods from being scheduled or disrupt workloads already running on the affected nodes.

This article helps you determine whether an agent pool issue originates from the AKS resource, the pool's Azure infrastructure, or the Kubernetes nodes. It also provides supported remediation and escalation guidance.

## Prerequisites

- An existing AKS cluster.
- [Azure CLI](/cli/azure/install-azure-cli) version 2.38.0 or later.
- A Bash shell. The commands in this article use Bash variable and line-continuation syntax.
- [`kubectl`](/azure/aks/learn/quick-kubernetes-deploy-cli#connect-to-the-cluster) configured to connect to your cluster.
- The Azure RBAC permissions required to view the AKS cluster, its agent pools, and the Azure activity log.

Set the following environment variables for the commands in this article:

```bash
RESOURCE_GROUP="<resource-group-name>"
CLUSTER_NAME="<cluster-name>"
NODE_POOL_NAME="<node-pool-name>"
```

## Identify the agent pool issue

Start by checking the AKS cluster and agent pool state. This check helps you distinguish an Azure resource or provisioning failure from a Kubernetes node health issue.

1. Check the cluster provisioning and power states by using the [`az aks show`](/cli/azure/aks#az-aks-show) command:

	```azurecli-interactive
	az aks show \
		--resource-group $RESOURCE_GROUP \
		--name $CLUSTER_NAME \
		--query "{provisioningState:provisioningState,powerState:powerState.code}" \
		--output table
	```

	A healthy cluster has a provisioning state of `Succeeded` and a power state of `Running`. If the cluster provisioning state is `Failed`, investigate the failed cluster operation before you troubleshoot an individual agent pool. For more information, see [Troubleshoot AKS clusters or nodes in a failed state](/troubleshoot/azure/azure-kubernetes/availability-performance/cluster-node-virtual-machine-failed-state).

1. Check the agent pool provisioning and power states by using the [`az aks nodepool show`](/cli/azure/aks/nodepool#az-aks-nodepool-show) command:

	```azurecli-interactive
	az aks nodepool show \
		--resource-group $RESOURCE_GROUP \
		--cluster-name $CLUSTER_NAME \
		--name $NODE_POOL_NAME \
		--query "{provisioningState:provisioningState,powerState:powerState.code}" \
		--output table
	```

1. Use the following table to choose your next diagnostic step:

	| Agent pool state | What the state indicates | Next step |
	| --- | --- | --- |
	| `Succeeded` and `Running` | The Azure agent pool resource is available. Individual Kubernetes nodes or workloads might still be unhealthy. | [Inspect the Kubernetes nodes](#inspect-the-kubernetes-nodes). |
	| `Failed` | An agent pool create, scale, upgrade, or update operation failed. | [Investigate a failed agent pool operation](#investigate-a-failed-agent-pool-operation). |
	| `Stopped` | The agent pool is powered off and its nodes can't run workloads. | Confirm that the pool was intentionally stopped. If it should be running, [start the agent pool](/azure/aks/start-stop-nodepools). |
	| `Creating`, `Scaling`, `Upgrading`, or `Updating` | An operation is in progress. | Monitor the operation. If the state doesn't change or the operation fails, review the activity log and AKS diagnostics. |

## Inspect the Kubernetes nodes

If the agent pool resource is running, inspect the Kubernetes status of its nodes.

1. List the nodes in the agent pool. AKS applies the `kubernetes.azure.com/agentpool` label to each node:

	```bash
	kubectl get nodes \
		--selector kubernetes.azure.com/agentpool=$NODE_POOL_NAME \
		--output wide
	```

	A `Ready` status indicates that a node is healthy, but it doesn't guarantee that a specific pod can be scheduled on the node. A node can be cordoned or have a taint that the pod doesn't tolerate. In the `kubectl describe node` output, check for `SchedulingDisabled` and review the node's taints. A node with a status of `NotReady` or `Unknown` can't accept new pods.

1. Describe an affected node to view its conditions, taints, capacity, and recent events. Replace `<node-name>` with the name of an unhealthy node:

	```bash
	kubectl describe node <node-name>
	```

1. Review the `Conditions` section in the output:

	| Node condition | What to investigate |
	| --- | --- |
	| `Ready=False` or `Ready=Unknown` | Kubelet health, node heartbeats, control plane connectivity, and required outbound network access. |
	| `MemoryPressure=True` | Workload memory requests and limits, node memory use, and whether the node pool needs more capacity. |
	| `DiskPressure=True` | Available operating system and ephemeral disk space, image use, and container log growth. |
	| `PIDPressure=True` | Workloads that create excessive processes and whether the node has sufficient capacity. |
	| `NetworkUnavailable=True` | Network configuration, network security group (NSG) and firewall rules, and connectivity to required AKS endpoints. |

1. List the pods assigned to the affected node to identify workload or drain failures:

	```bash
	kubectl get pods \
		--all-namespaces \
		--field-selector spec.nodeName=<node-name> \
		--output wide
	```

1. Review recent cluster events for scheduling, eviction, volume, and networking errors:

	```bash
	kubectl get events --all-namespaces --sort-by=.lastTimestamp
	```

AKS monitors node health and attempts to [automatically repair unhealthy nodes](node-auto-repair.md). If a node remains `NotReady`, verify that the cluster uses a [supported Kubernetes version](supported-kubernetes-versions.md), the agent pool uses a current [node image](upgrade-node-image.md), and required [outbound network access](outbound-rules-control-egress.md) isn't blocked. For a detailed node health workflow, see [Basic troubleshooting of Node Not Ready failures](/troubleshoot/azure/azure-kubernetes/availability-performance/node-not-ready-basic-troubleshooting).

> [!IMPORTANT]
> AKS manages the lifecycle and configuration of agent nodes. Don't manually modify the underlying virtual machines (VMs) or virtual machine scale sets, such as by changing packages or network configuration through SSH. These changes aren't supported and can be lost during AKS operations. For more information, see [AKS support policies](support-policies.md#user-customization-of-agent-nodes).

## Investigate a failed agent pool operation

If the agent pool provisioning state is `Failed`, identify the operation and error that caused the failure.

1. Open your AKS cluster in the Azure portal and select **Activity log**.
1. Filter the activity log to show failed events for the time when the agent pool issue began.
1. Select the failed operation and review its error code, status message, and JSON details.
1. In your AKS cluster, select **Diagnose and solve problems**. Review the **Cluster and Control Plane Availability** and **Node Health** diagnostics for detected issues and recommended actions.

Common causes of failed agent pool operations include:

- Insufficient regional capacity for the selected VM size or availability zone.
- Subscription or regional compute quota limits.
- Insufficient IP addresses in the agent pool subnet.
- NSG, firewall, route, or DNS configuration that blocks required outbound connectivity.
- Azure Policy assignments, resource locks, or insufficient permissions that block an operation.
- Pod disruption budgets or unhealthy pods that prevent a node from draining during an upgrade or scale operation.
- VM extension errors that prevent a node from completing provisioning.

Use the error code and message from the failed operation to select the appropriate remediation. For error-specific guidance, see [Troubleshoot AKS clusters or nodes in a failed state](/troubleshoot/azure/azure-kubernetes/availability-performance/cluster-node-virtual-machine-failed-state).

## Validate agent pool recovery

After you address the underlying issue or AKS completes an automatic repair, verify both the Azure agent pool state and Kubernetes node health:

```azurecli-interactive
az aks nodepool show \
	--resource-group $RESOURCE_GROUP \
	--cluster-name $CLUSTER_NAME \
	--name $NODE_POOL_NAME \
	--query "{provisioningState:provisioningState,powerState:powerState.code}" \
	--output table
```

```bash
kubectl get nodes \
	--selector kubernetes.azure.com/agentpool=$NODE_POOL_NAME \
	--output wide
```

Confirm that the agent pool provisioning state is `Succeeded`, its power state is `Running`, and every expected node is `Ready`. Also verify that pending workloads can be scheduled and that workloads on the recovered nodes are healthy.

## Collect diagnostics and get support

If the issue continues after you complete these steps, collect the following information before you create an Azure support request:

- The cluster resource ID, agent pool name, region, and Kubernetes version.
- The approximate start time and duration of the issue, including the time zone.
- The failed operation's correlation ID, error code, and status message from the Azure activity log.
- The output from `az aks nodepool show`, `kubectl get nodes --output wide`, and `kubectl describe node <node-name>`.
- Relevant Kubernetes events and the names of affected workloads.

You can also use [AKS Diagnose and Solve Problems](aks-diagnostics.md) and [AKS Periscope](https://aka.ms/aksperiscope) to collect diagnostic information. Don't include secrets, credentials, or other sensitive information in support logs.

## Next steps

- Learn how to [monitor AKS with Azure Monitor](/azure/azure-monitor/containers/kubernetes-monitoring-enable).
- Review [AKS node auto-repair](node-auto-repair.md).
- Review [AKS support policies](support-policies.md).
