---
title: Connectivity modes in AKS on Azure Local
description: Learn about running AKS on Azure Local in disconnected and semi-connected mode.
ms.topic: overview
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: srikantsarwa
ms.lastreviewed: 04/08/2025
ms.custom: conceptual, hyperconverged

---

# Connectivity modes in AKS on Azure Local

AKS on Azure Local requires connectivity to Azure in order to use features such as Kubernetes cluster upgrades, and identity and access options such as Azure Entra ID. Also, Azure Arc agents on the AKS cluster must remain connected to enable functionality such as [configuring (GitOps)](/azure/azure-arc/kubernetes/conceptual-gitops-flux2), Arc extensions, and [cluster connect](/azure/azure-arc/kubernetes/conceptual-cluster-connect). Since AKS on Azure Local clusters deployed at the edge might not always have stable network access, the Kubernetes cluster might occasionally be unable to reach Azure when it operates in a semi-connected state.

## Understand connectivity modes

When working with AKS on Azure Local clusters, it's important to understand how network connectivity modes impact your operations.

- **Fully connected**: With ongoing network connectivity, AKS and Arc agents can consistently communicate with Azure. In this mode, there is typically little delay with tasks such as scaling out your AKS cluster, upgrading the Kubernetes version, propagating GitOps configurations, enforcing Azure Policy and Gatekeeper policies, or collecting workload metrics and logs in Azure Monitor.

- **Semi-connected**:  Refers to a temporary loss of connectivity with Azure, which is supported for a duration of up to 30 days. This constraint is due to the 30-day validity period of certificates managed by AKS on Azure Local. If network connectivity is not restored within this timeframe, the AKS cluster may cease to function. To maintain cluster operability, it is recommended that the AKS cluster establish connectivity with Azure at least once every 30 days. Failure to do so may result in certificate expiration, requiring the cluster to be deleted and redeployed.

- **Disconnected**: We currently do not support running AKS on Azure Local in a disconnected environment beyond 30 days.

## Impact of semi-connected mode (temporary disconnection) on AKS on Azure Local operations

The connectivity status of a cluster is determined by the time of the latest heartbeat received from the Azure Arc agents deployed on the cluster.

| AKS operation | Impact of temporary disconnection | Details | Workaround |
| ------------- | ---------------------------------- |---------|------------|
| Creating, updating, upgrading, and deleting Kubernetes clusters | Not supported | Since Kubernetes CRUD operations are driven by Azure, you can't perform any CRUD operations while disconnected. | No supported workaround. |
| Scaling the Kubernetes cluster | Partially supported | You can't manually scale an existing nodepool or add a new nodepool to the Kubernetes cluster. | Your Kubernetes cluster scales dynamically if you [enabled autoscalar](auto-scale-aks-arc.md) while creating the Kubernetes cluster. |
| Access the Kubernetes cluster | Partially supported | You can't use [Azure Entra](enable-authentication-microsoft-entra-id.md) and `az connectedk8s proxy`, since they require connectivity to Azure. | [Retrieve admin kubeconfig](retrieve-admin-kubeconfig.md) to access the Kubernetes cluster. |
| Viewing Kubernetes cluster status | Partially supported | You can't use the Azure portal or Azure Resource Manager APIs to view Kubernetes cluster status. | Use local tools such as [kubectl get](https://kubernetes.io/docs/reference/kubectl/quick-reference/#viewing-and-finding-resources). |
| MetalLB Arc extension | Partially supported | Your load balancer continues working but you can't add or remove IP pools or update MetalLB configuration. | No supported workaround. |
| AKS cluster and application observability | Partially supported | You can't use Container Insights and [create diagnostic settings using Container Insights](kubernetes-monitor-audit-events.md#create-a-diagnostic-setting), since they require connectivity to Azure. | Use [3rd party on-premises monitoring solutions](aks-monitor-logging.md). |
| SSH into the Kubernetes VMs | Supported | You can SSH into Kubernetes VMs. | No workaround needed. |
| Collect logs for troubleshooting | Supported | You can collect logs for troubleshooting issues. | No workaround needed. |

## Next steps

- [Azure Arc connectivity modes](/azure//azure-arc/kubernetes/conceptual-connectivity-modes)
- [Create and manage Kubernetes clusters on-premises using Azure CLI](../aks-create-clusters-cli.md)
