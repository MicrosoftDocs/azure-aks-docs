---
title: Node auto provisioning
description: Learn about Azure Kubernetes Service (AKS) node autoprovisioning.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/23/2025
ms.author: wilsondarko
author: wdarko1

#Customer intent: As a cluster operator or developer, I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.

---

# Node auto provisioning

When you deploy workloads onto AKS, you need to make a decision about the node pool configuration regarding the Virtual Machine (VM) size needed. As your workloads become more complex, and require different CPU, memory, and capabilities to run, the overhead of having to design your VM configuration for numerous resource requests becomes difficult.

Node auto provisioning (NAP) uses pending pod resource requirements to decide the optimal virtual machine configuration to run those workloads in the most efficient and cost-effective manner.

Node auto provisioning is based on the open source [Karpenter](https://karpenter.sh) project, and the [AKS Karpenter provider][aks-karpenter-provider], which is also open source. Node auto provisioning automatically deploys, configures, and manages Karpenter on your AKS clusters.

## How node autoprovisioning works

Node auto provisioning provisions, scales, and manages virtual machines (nodes) in a cluster in response to pending pod pressure. Node auto provisioning uses these key components:

- **NodePool and AKSNodeClass**: Custom Resource Definitions that you create and manage to define node provisioning policies, VM specifications, and constraints for your workloads.
- **NodeClaims**: Managed by node autoprovisioning to represent the current state of provisioned nodes that you can monitor.
- **Workload resource requirements**: CPU, memory, and other specifications from your Pods, Deployments, Jobs, and other Kubernetes resources that drive provisioning decisions.

### Prerequisites

| Prerequisite                         | Notes                                                                                                        |
|--------------------------------------|--------------------------------------------------------------------------------------------------------------|
| **Azure Subscription**               | If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).  |
| **Azure CLI**| `2.76.0` or later. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][azure cli].|                      

## Limitations

- You can't enable node autoprovisioning in a cluster where node pools have cluster autoscaler enabled

### Unsupported features

- Windows node pools
- IPv6 clusters
- [Service Principals](./kubernetes-service-principal.md)
   > [!NOTE]
   > You can use either a system-assigned or user-assigned managed identity.
- Disk encryption sets
- CustomCATrustCertificates
- Clusters with node autoprovisioning can't be [stopped](./start-stop-cluster.md)
- [HTTP proxy](./http-proxy.md)
- All cluster egress [outbound types](./egress-outboundtype.md) are supported, however the type can't be changed after the cluster is created

## Networking configuration

The following network configurations are recommended for clusters enabled with node autoprovisioning:

- [Azure Container Network Interface (CNI) Overlay](concepts-network-azure-cni-overlay.md) with [Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Azure CNI](configure-azure-cni.md) with [Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI](configure-azure-cni.md)

For detailed networking configuration requirements and recommendations, see [Node autoprovisioning networking configuration](node-autoprovision-networking.md).

Key networking considerations:

- Azure CNI Overlay with Cilium is recommended
- Standard Load Balancer is required
- Private clusters aren't currently supported

## Enable node autoprovisioning

### Enable node autoprovisioning on a new cluster

Node auto provisioning is enabled by setting the field `--node-provisioning-mode` to [Auto](/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep#managedclusternodeprovisioningprofile), which sets the Node Provisioning Profile to Auto. The default setting for this field is `Manual`. 

### [Azure CLI](#tab/azure-cli)

- Enable node autoprovisioning on a new cluster using the `az aks create` command and set `--node-provisioning-mode` to `Auto`. You can also set the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay` (optional), and `--network-dataplane` to `cilium` (optional).

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --node-provisioning-mode Auto \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --network-dataplane cilium \
        --generate-ssh-keys
    ```

### [ARM template](#tab/arm)

- Enable node autoprovisioning on a new cluster using the `az deployment group create` command and specify the `--template-file` parameter with the path to the ARM template file. The ARM template includes the `mode` field in `nodeProvisioningProfile` set to `Auto`, which enabled node autoprovisioning. 

    ```azurecli-interactive
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./nap.json
    ```

    The `nap.json` file should contain the following ARM template:

    ```JSON
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "metadata": {},
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.ContainerService/managedClusters",
          "apiVersion": "2025-05-01",
          "sku": {
            "name": "Base",
            "tier": "Standard"
          },
          "name": "napcluster",
          "location": "uksouth",
          "identity": {
            "type": "SystemAssigned"
          },
          "properties": {
            "networkProfile": {
                "networkPlugin": "azure",
                "networkPluginMode": "overlay",
                "networkPolicy": "cilium",
                "networkDataplane":"cilium",
                "loadBalancerSku": "Standard"
            },
            "dnsPrefix": "napcluster",
            "agentPoolProfiles": [
              {
                "name": "agentpool",
                "count": 3,
                "vmSize": "standard_d2s_v3",
                "osType": "Linux",
                "mode": "System"
              }
            ],
            "nodeProvisioningProfile": {
              "mode": "Auto"
            }
          }
        }
      ]
    }
    ```

---

### Enable node autoprovisioning on an existing cluster

- Enable node autoprovisioning on an existing cluster using the `az aks update` command and set `--node-provisioning-mode` to `Auto`.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --node-provisioning-mode Auto
    ```

## Basic NodePool and AKSNodeClass example

After enabling node autoprovisioning on your cluster, you can create a basic NodePool and AKSNodeClass to start provisioning nodes. Here's a simple example:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        intent: apps
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: [spot, on-demand]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: [D]
      expireAfter: Never
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 0s
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Ubuntu2204 nodes"
spec:
  imageFamily: Ubuntu2204
```

This example creates a basic NodePool that:
- Supports both spot and on-demand instances
- Uses D-series VMs
- Sets a CPU limit of 100
- Enables consolidation when nodes are empty or underutilized

## Custom Virtual Networks and node autoprovisioning

AKS allows you to add a cluster with node autoprovisioning enabled in a custom virtual network via the `--vnet-subnet-id` parameter. The following sections detail how to:

- Create a virtual network
- Create a managed identity with permissions over the virtual network  
- Create a node autoprovisioning-enabled cluster in a custom virtual network 

### Create a virtual network

Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command. Create a cluster subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

When using a custom virtual network with node autoprovisioning, you must create and delegate an API server subnet to `Microsoft.ContainerService/managedClusters`, which grants the AKS service permissions to inject the API server pods and internal load balancer into that subnet. You can't use the subnet for any other workloads, but you can use it for multiple AKS clusters located in the same virtual network. The minimum supported API server subnet size is a */28*.

```azurecli-interactive
az network vnet create --name ${VNET_NAME} \
--resource-group ${RG_NAME} \
--location ${LOCATION} \
--address-prefixes 172.19.0.0/16

az network vnet subnet create --resource-group ${RG_NAME} \
--vnet-name ${VNET_NAME} \
--name clusterSubnet \
--delegations Microsoft.ContainerService/managedClusters \
--address-prefixes 172.19.0.0/28
```

All traffic within the virtual network is allowed by default. But if you added Network Security Group (NSG) rules to restrict traffic between different subnets, see our [Network Security Group documentation][network-security-group] for the proper permissions.  

### Create a managed identity and give it permissions on the virtual network

Create a managed identity using the [`az identity create`][az-identity-create] command and retrieve the principal ID. Assign the **Network Contributor** role on virtual network to the managed identity using the [`az role assignment create`][az-role-assignment-create] command.

```azurecli-interactive
az identity create --resource-group ${RG_NAME} \
--name ${IDENTITY_NAME} \
--location ${LOCATION}
IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group ${RG_NAME} --name ${IDENTITY_NAME} \
--query principalId -o tsv)

az role assignment create --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}" \
--role "Network Contributor" \
--assignee ${IDENTITY_PRINCIPAL_ID}
```

### Create an AKS cluster in a custom virtual network and with node autoprovisioning enabled

In the following command, an Azure Kubernetes Service (AKS) cluster is created as part of a custom virtual network using the [az aks create][az-aks-create] command. To create a customer virtual network

```azurecli-interactive
     	az aks create --name $(AZURE_CLUSTER_NAME) --resource-group $(AZURE_RESOURCE_GROUP) \
    		--enable-managed-identity --generate-ssh-keys -o none --network-dataplane cilium --network-plugin azure --network-plugin-mode overlay \
    		--vnet-subnet-id "/subscriptions/$(AZURE_SUBSCRIPTION_ID)/resourceGroups/$(AZURE_RESOURCE_GROUP)/providers/Microsoft.Network/virtualNetworks/$(CUSTOM_VNET_NAME)/subnets/$(CUSTOM_SUBNET_NAME)" \
    		--node-provisioning-mode Auto
```

```azurecli-interactive
az aks create --resource-group ${RG_NAME} \
--name ${CLUSTER_NAME} \
--location ${LOCATION} \
--vnet-subnet-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/clusterSubnet" \
--assign-identity "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RG_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" \
--node-provisioning-mode Auto
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

Configure `kubectl` to connect to your Kubernetes cluster using the [az aks get-credentials][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

```azurecli-interactive
az aks get-credentials --resource-group ${RG_NAME} --name ${CLUSTER_NAME}
```

Verify the connection to your cluster using the [kubectl get][kubectl-get] command. This command returns a list of the cluster nodes.

```bash
kubectl get nodes
```

## Node pools

For detailed node pool configuration including SKU selectors, limits, and weights, see [Node autoprovisioning node pools configuration](node-autoprovision-node-pools.md).

Node autoprovisioning uses VM SKU requirements to decide the best virtual machine for pending workloads. You can configure:

- SKU families and specific instance types
- Resource limits and priorities
- Spot vs on-demand instances
- Architecture and capabilities requirements

## Node disruption

### Disruption Controls

Node Disruption, including Consolidation or Drift, can be controlled using different methods.

### Consolidation
When workloads on your nodes scale down, node autoprovisioning uses disruption rules. These rules decide when and how to remove nodes and reschedule workloads for better efficiency. Node auto provisioning primarily uses *consolidation* to delete or replace nodes for optimal pod placement. The state-based consideration uses `ConsolidationPolicy` such as `WhenEmpty`, or `WhenEmptyOrUnderUtilized` to trigger consolidation. `consolidateAfter` is a time-based condition that can be set to allow buffer time between actions.

You can remove a node manually using `kubectl delete node`, but node autoprovisioning can also control when it should optimize your nodes based on your specifications.

```yaml
  disruption:
    # Describes which types of Nodes node autoprovisioning should consider for consolidation
    consolidationPolicy: WhenEmptyorUnderutilized
    # 'WhenEmptyorUnderutilized', node autoprovisioning will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is empty or underutilized and could be changed to reduce cost

    #  `WhenEmpty`, node autoprovisioning will only consider nodes for consolidation that contain no workload pods
    
    # The amount of time node autoprovisioning should wait after discovering a consolidation decision
    # This value can currently only be set when the consolidationPolicy is 'WhenEmpty'
    # You can choose to disable consolidation entirely by setting the string value 'Never'
    consolidateAfter: 30s
```

### Disruption Controls

Node autoprovisioning optimizes your cluster by:

- Removing or replacing underutilized nodes
- Consolidating workloads to reduce costs
- Respecting disruption budgets and maintenance windows
- Providing manual control when needed

For detailed information about node disruption policies, upgrade mechanisms through drift, consolidation, and disruption budgets, see [Node autoprovisioning disruption policies](node-autoprovision-disruption.md).

### Kubernetes upgrades

Kubernetes upgrades for node autoprovisioning nodes follow the control plane Kubernetes version. If you perform a cluster upgrade, your nodes are automatically updated to follow the same versioning. 

AKS recommends coupling node autoprovisioning with a Kubernetes [Auto Upgrade][auto-upgrade] channel for the cluster, which automatically handles all your cluster's Kubernetes upgrades. Pairing the Auto Upgrade channel with an `aksManagedAutoUpgradeSchedule` planned maintenance window, you can schedule your cluster upgrades during optimal times for your workloads. For more information on planning cluster upgrades, visit our [documentation on planned maintenance][planned-maintenance#schedule-configuration-types-for-planned-maintenance]

### Node image updates

By default, node autoprovisioning node pool virtual machines are automatically updated when a new image version is available.

There are multiple methods to regulate when upgrades occur:
- Configure an `aksManagedNodeOSUpgradeSchedule` maintenance window for the cluster to control when new images are picked up.
- Use Karpenter Node Disruption Budgets and Pod Disruption Budgets to control how and when disruption occurs during upgrades.


#### Node OS maintenance windows (support for NAP)

Node autoprovisioning (NAP) honors Node OS maintenance windows configured via the AKS Planned Maintenance feature. Configure the `aksManagedNodeOSUpgradeSchedule` maintenance configuration to control when NAP picks up new images for NAP‑provisioned nodes.

Key points:

- The `aksManagedNodeOSUpgradeSchedule` maintenance configuration determines the window during which node autoprovisioning picks up a new image; it does not necessarily determine when existing nodes are disrupted.
- The upgrade mechanism and decision criteria are specific to NAP/Karpenter and are evaluated by NAP's drift logic; NAP respects Karpenter Node Disruption Budgets, and .
- These NAP upgrade decisions are separate from the cluster `NodeImage` and `SecurityPatch` channels. However, the `aksManagedNodeOSUpgradeSchedule` maintenance configuration will apply them as well.
- Use a maintenance window of four hours or more for reliable operation.
- If no maintenance configuration exists, AKS may use a fallback schedule to pick up new images, which can cause images to be picked up at unexpected times. Define an explicit `aksManagedNodeOSUpgradeSchedule` to avoid unexpected timing of new images, and upgrades.

>[!NOTE] NAP will force the latest image version to be picked up, if the existing node image version is ever older than 90 days. This will bypass any existing maintenance window.

Recommended schedule patterns for NAP-managed nodes:

- Weekly cadence: recommended for routine node image rollouts (for example, "Every week on Sunday").

Create a Node OS maintenance schedule example (JSON + Azure CLI)

1. Create a JSON file named `nodeosMaintenance.json` with a weekly maintenance window (Sunday at 01:00 UTC for 4 hours):

```json
{
  "properties": {
    "maintenanceWindow": {
      "durationHours": 4,
      "schedule": {
        "weekly": {
          "intervalWeeks": 1,
          "dayOfWeek": "Sunday"
        }
      },
      "startDate": "2025-01-01",
      "startTime": "01:00",
      "utcOffset": "+00:00"
    }
  }
}
```

2. Add the maintenance configuration to your cluster:

```azurecli-interactive
az aks maintenanceconfiguration add --resource-group ${RG_NAME} --cluster-name ${CLUSTER_NAME} --name aksManagedNodeOSUpgradeSchedule --config-file ./nodeosMaintenance.json
```

Update, view, list, and delete:

```azurecli-interactive
az aks maintenanceconfiguration update --resource-group ${RG_NAME} --cluster-name ${CLUSTER_NAME} --name aksManagedNodeOSUpgradeSchedule --config-file ./nodeosMaintenance.json

az aks maintenanceconfiguration show --resource-group ${RG_NAME} --cluster-name ${CLUSTER_NAME} --name aksManagedNodeOSUpgradeSchedule

az aks maintenanceconfiguration list --resource-group ${RG_NAME} --cluster-name ${CLUSTER_NAME}

az aks maintenanceconfiguration delete --resource-group ${RG_NAME} --cluster-name ${CLUSTER_NAME} --name aksManagedNodeOSUpgradeSchedule
```

Operational considerations

- Allow at least 15 minutes between creating or updating a maintenance configuration and the scheduled start time to ensure AKS has time to reconcile the new configuration.

For complete details, examples, and advanced scenarios, see Use Planned Maintenance to schedule maintenance windows for your AKS cluster: [planned-maintenance][planned-maintenance].

## Node auto provisioning Metrics
You can enable [control plane metrics (Preview)](./monitor-control-plane-metrics.md) to see the logs and operations from [node auto provisioning](./control-plane-metrics-default-list.md#minimal-ingestion-for-default-off-targets) with the [Azure Monitor managed service for Prometheus add-on](/azure/azure-monitor/essentials/prometheus-metrics-overview)

## Monitoring selection events

Node auto provisioning produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```
kubectl get events -A --field-selector source=karpenter -w
```

## Disabling node autoprovisioning

Node auto provisioning can only be disabled when:

- There are no existing node autoprovisioning-managed nodes. Use `kubectl get nodes -l karpenter.sh/nodepool` to view node autoprovisioning-managed nodes.
- All existing karpenter.sh/NodePools have their `spec.limits.cpu` field set to 0.

### Steps to disable node autoprovisioning

1. Set all karpenter.sh/NodePools `spec.limits.cpu` field to 0. This action prevents new nodes from being created, but doesn't disrupt currently running nodes.

> [!NOTE]
> If you don't care about ensuring that every pod that was running on a node autoprovisioning node is migrated safely to a non-node autoprovisioning node,
> you can skip steps 2 and 3 and instead use the `kubectl delete node` command for each node autoprovisioning-managed node.
>
> **Skipping steps 2 and 3 is not recommended, as it might leave some pods pending and doesn't honor Pod Disruption Budgets (PDBs).**
>
> **Don't run `kubectl delete node` on any nodes that aren't managed by node autoprovisioning.**

2. Add the `karpenter.azure.com/disable:NoSchedule` taint to every karpenter.sh/NodePool.
   ```yaml
   apiVersion: karpenter.sh/v1
   kind: NodePool
   metadata:
     name: default
   spec:
     template:
       spec:
         ...
         taints:
           - key: karpenter.azure.com/disable,
             effect: NoSchedule
   ```
   
   This action starts the process of migrating the workloads on the node autoprovisioning-managed nodes to non-NAP nodes, honoring Pod Disruption Budgets (PDBs) and disruption limits. Pods migrate to non-NAP nodes if they can fit. If there isn't enough fixed-size capacity, some node autoprovisioning-managed nodes remain.

4. Scale up existing fixed-size ManagedCluster AgentPools, or create new fixed-size AgentPools, to take the load from the node autoprovisioning-managed nodes.
   As these nodes are added to the cluster the node autoprovisioning-managed nodes are drained, and work is migrated to the fixed-scale nodes.

5. Confirm that all node autoprovisioning-managed nodes are deleted, using `kubectl get nodes -l karpenter.sh/nodepool`. If node autoprovisioning-managed nodes still exist, the cluster likely lacks fixed-scale capacity. Add more nodes so the remaining workloads can be migrated.
6. Update the node provisioning mode parameter of the ManagedCluster to `Manual`.

    #### [Azure CLI](#tab/azure-cli)

      ```azurecli-interactive
      az aks update \
          --name $CLUSTER_NAME \
          --resource-group $RESOURCE_GROUP_NAME \
          --node-provisioning-mode Manual
      ```

    #### [ARM template](#tab/arm)

    ```azurecli-interactive
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./nap.json
    ```

    The `nap.json` file should contain the following ARM template. The value of the `properties.nodeProvisioningProfile.mode` field set to `Manual`
    is what's performing the disablement:

    ```JSON
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "metadata": {},
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.ContainerService/managedClusters",
          "apiVersion": "2025-05-01",
          "sku": {
            "name": "Base",
            "tier": "Standard"
          },
          "name": "napcluster",
          "location": "uksouth",
          "identity": {
            "type": "SystemAssigned"
          },
          "properties": {
            "networkProfile": {
                "networkPlugin": "azure",
                "networkPluginMode": "overlay",
                "networkPolicy": "cilium",
                "networkDataplane":"cilium",
                "loadBalancerSku": "Standard"
            },
            "dnsPrefix": "napcluster",
            "agentPoolProfiles": [
              {
                "name": "agentpool",
                "count": 3,
                "vmSize": "standard_d2s_v3",
                "osType": "Linux",
                "mode": "System"
              }
            ],
            "nodeProvisioningProfile": {
              "mode": "Manual"
            }
          }
        }
      ]
    }
    ```
---
<!-- LINKS - internal -->
[aks-view-master-logs]: monitor-aks.md#aks-control-planeresource-logs
[azure-cli-extensions]: /cli/azure/azure-cli-extensions-overview
[azure cli]: /cli/azure/get-started-with-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[planned-maintenance#schedule-configuration-types-for-planned-maintenance]: /azure/aks/planned-maintenance#schedule-configuration-types-for-planned-maintenance
[Azure-Policy-RBAC-permissions]: /azure/governance/policy/overview#azure-rbac-permissions-in-azure-policy
[aks-entra-rbac]: /azure/aks/manage-azure-rbac
[aks-entra-rbac-builtin-roles]: /azure/aks/manage-azure-rbac#create-role-assignments-for-users-to-access-the-cluster
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-network-vnet-subnet-create]: /cli/azure/network/vnet/subnet#az-network-vnet-subnet-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[auto-upgrade]: /azure/aks/auto-upgrade-cluster#cluster-auto-upgrade-channels
[auto-mode]: /azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep#managedclusternodeprovisioningprofile
[node-os-upgrade-channel]: /azure/aks/auto-upgrade-node-os-image#available-node-os-upgrade-channels
[azure-support]: /azure/azure-portal/supportability/how-to-create-azure-support-request
[azure-reserved-instances]: https://azure.microsoft.com/pricing/reserved-vm-instances/
[vm-overview]: /azure/virtual-machines/sizes/overview
[network-security-group]: /azure/virtual-network/network-security-groups-overview

<!-- LINKS - external -->
[aks-karpenter-provider]: https://github.com/Azure/karpenter-provider-azure
[aks-karpenter-provider-issues]: https://github.com/Azure/karpenter-provider-azure/issues
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[AKS-repo]: https://github.com/Azure/AKS/issues

