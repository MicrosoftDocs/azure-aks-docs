---
title: Node autoprovisioning (preview)
description: Learn about Azure Kubernetes Service (AKS) node autoprovisioning (preview).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: wilsondarko
author: wdarko1

#Customer intent: As a cluster operator or developer, I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.

---

# Node autoprovisioning

When you deploy workloads onto AKS, you need to make a decision about the node pool configuration regarding the VM size needed. As your workloads become more complex, and require different CPU, memory, and capabilities to run, the overhead of having to design your VM configuration for numerous resource requests becomes difficult.


Node autoprovisioning (NAP) uses pending pod resource requirements to decide the optimal virtual machine configuration to run those workloads in the most efficient and cost-effective manner.
aks
NAP is based on the open source [Karpenter](https://karpenter.sh) project, and the [AKS Karpenter provider][aks-karpenter-provider] is also open source. NAP automatically deploys and configures and manages Karpenter on your AKS clusters.

## Before you begin

- You need an Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli).

## Limitations

- You can't enable in a cluster where node pools have cluster autoscaler enabled

### Unsupported features

- Windows node pools
- Applying custom configuration to the node kubelet
- IPv6 clusters
- [Service Principals](./kubernetes-service-principal.md)
   > [!NOTE]
   > You can use either a system-assigned or user-assigned managed identity.
- Disk encryption sets
- CustomCATrustCertificates
- [Start Stop mode](./start-stop-cluster.md)
- [HTTP proxy](./http-proxy.md)
- [OutboundType](./egress-outboundtype.md) mutation. All OutboundTypes are supported, however you can't change them after creation.

### Networking configuration

The recommended network configurations for clusters enabled with Node Autoprovisioning are the following:
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md) with [Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Azure CNI](configure-azure-cni.md) with [Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI](configure-azure-cni.md)

Our recommended network policy engine is [Cilium](azure-cni-powered-by-cilium.md). 

The following networking configurations are currently *not* supported:

- Calico network policy
- Dynamic IP Allocation
- Static Allocation of CIDR blocks

## Enable node autoprovisioning

### Enable node autoprovisioning on a new cluster

### [Azure CLI](#tab/azure-cli)

- Enable node autoprovisioning on a new cluster using the `az aks create` command and set `--node-provisioning-mode` to `Auto`. You also need to set the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay`, and `--network-dataplane` to `cilium`.

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

- Enable node autoprovisioning on a new cluster using the `az deployment group create` command and specify the `--template-file` parameter with the path to the ARM template file.

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
            },
          }
        }
      ]
    }
    ```

---

### Enable node autoprovisioning on an existing cluster

- Enable node autoprovisioning on an existing cluster using the `az aks update` command and set `--node-provisioning-mode` to `Auto`. You also need to set the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay`, and `--network-dataplane` to `cilium`.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium
    ```

## Custom Virtual Networks and Node Autoprovisioning

### Create an AKS cluster with custom virtual network and node autoprovisioning enabled
AKS allows you to add a cluster with node autoprovisioning enabled in a custom virtual network via the `--vent-subnet-id` parameter. In the following command, an AKS cluster is created as part of a custom virtual network. 
    ```azurecli-interactive
     	az aks create --name $(AZURE_CLUSTER_NAME) --resource-group $(AZURE_RESOURCE_GROUP) --attach-acr $(AZURE_ACR_NAME) \
    		--enable-managed-identity --node-count 3 --generate-ssh-keys -o none --network-dataplane cilium --network-plugin azure --network-plugin-mode overlay \
    		--enable-oidc-issuer --enable-workload-identity \
    		--vnet-subnet-id "/subscriptions/$(AZURE_SUBSCRIPTION_ID)/resourceGroups/$(AZURE_RESOURCE_GROUP)/providers/Microsoft.Network/virtualNetworks/$(CUSTOM_VNET_NAME)/subnets/$(CUSTOM_SUBNET_NAME)" \
    		--node-provisioning-mode Auto
    	az aks get-credentials --name $(AZURE_CLUSTER_NAME) --resource-group $(AZURE_RESOURCE_GROUP) --overwrite-existing
    	skaffold config set default-repo $(AZURE_ACR_NAME).azurecr.io/karpenter
    ```
In order to complete this process, permissions need to be added by granting a Network Contributor role to the cluster service principal. The following command assigns the role of `Network Contributor` to allow node autoprovisioning to function in a cluster in a custom virtual network.
    ```azurecli-interactive
    	$(eval CLUSTER_IDENTITY_ID=$(shell az aks show --name $(AZURE_CLUSTER_NAME) --resource-group $(AZURE_RESOURCE_GROUP) | jq  -r ".identity.principalId"))
    	az role assignment create --assignee $(CLUSTER_IDENTITY_ID) --scope /subscriptions/$(AZURE_SUBSCRIPTION_ID)/resourceGroups/$(AZURE_RESOURCE_GROUP) --role "Network Contributor"
    ``` 

## Node pools

Node autoprovisioning uses a list of VM SKUs as a starting point to decide which SKU is best suited for the workloads that are in a pending state. Having control over what SKU you want in the initial pool allows you to specify specific SKU families or virtual machine types and the maximum number of resources a provisioner uses. You can also reference different specifications in the node pool file, such as specifying *spot* or *on-demand* instances, multiple architectures, and more. 

If you have specific virtual machine sizes that are reserved instances, for example, you may wish to only use those virtual machines as the starting pool.

You can have multiple node pool definitions in a cluster, but AKS deploys a default node pool definition that you can modify:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    spec:
      nodeClassRef:
        name: default

      # Requirements that constrain the parameters of provisioned nodes.
      # These requirements are combined with pod.spec.affinity.nodeAffinity rules.
      # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
      # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
```

### Supported node provisioner requirements

#### SKU selectors with well known labels

| Selector | Description | Example |
|--|--|--|
| karpenter.azure.com/sku-family | VM SKU Family | D, F, L etc. |
| karpenter.azure.com/sku-name | Explicit SKU name | Standard_A1_v2 |
| karpenter.azure.com/sku-version | SKU version (without "v", can use 1) | 1 , 2 |
| karpenter.sh/capacity-type | VM allocation type (Spot / On Demand) | spot or on-demand |
| karpenter.azure.com/sku-cpu | Number of CPUs in VM | 16 |
| karpenter.azure.com/sku-memory | Memory in VM in MiB | 131072 |
| karpenter.azure.com/sku-gpu-name | GPU name | A100 |
| karpenter.azure.com/sku-gpu-manufacturer | GPU manufacturer | nvidia |
| karpenter.azure.com/sku-gpu-count | GPU count per VM | 2 |
| karpenter.azure.com/sku-networking-accelerated | Whether the VM has accelerated networking | [true, false] |
| karpenter.azure.com/sku-storage-premium-capable | Whether the VM supports Premium IO storage | [true, false] |
| karpenter.azure.com/sku-storage-ephemeralos-maxsize | Size limit for the Ephemeral OS disk in Gb | 92 |
| topology.kubernetes.io/zone | The Availability Zone(s) | [uksouth-1,uksouth-2,uksouth-3] |
| kubernetes.io/os | Operating System | linux |
| kubernetes.io/arch | CPU architecture (AMD64 or ARM64) | [amd64, arm64] |

To list the virtual machine SKU capabilities and allowed values, use the `vm list-skus` Azure CLI command.

```azurecli-interactive
az vm list-skus --resource-type virtualMachines --location <location> --query '[].name' --output table
```

## Node pool limits

By default, node autoprovisioning attempts to schedule your workloads within the Azure quota you have available. You can also specify the upper limit of resources that is used by a node pool, specifying limits within the node pool spec.

```
  # Resource limits constrain the total size of the cluster.
  # Limits prevent Karpenter from creating new instances once the limit is exceeded.
  limits:
    cpu: "1000"
    memory: 1000Gi
```

## Node pool weights

When you have multiple node pools defined, it's possible to set a preference of where a workload should be scheduled. Define the relative weight on your Node pool definitions.

```
  # Priority given to the node pool when the scheduler considers which to select. Higher weights indicate higher priority when comparing node pools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 10
```

## Node disruption

When the workloads on your nodes scale down, node autoprovisioning uses disruption rules on the node pool specification to decide when and how to remove those nodes and potentially reschedule your workloads to be more efficient. This is primarily done through *consolidation*, which deletes or replaces nodes to bin-pack your pods in an optimal configuration. The state-based consideration uses `ConsolidationPolicy` such as `WhenUnderUtilized`, `WhenEmpty`, or `WhenEmptyOrUnderUtilized` to trigger consolidation. `consolidateAfter` is a time-based condition that can be set to allow buffer time between actions.

You can remove a node manually using `kubectl delete node`, but node autoprovision can also control when it should optimize your nodes based on your specifications.

```yaml
  disruption:
    # Describes which types of Nodes NAP should consider for consolidation
    consolidationPolicy: WhenUnderutilized | WhenEmpty
    # 'WhenUnderutilized', NAP will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is underutilized and could be changed to reduce cost

    #  `WhenEmpty`, NAP will only consider nodes for consolidation that contain no workload pods
    
    # The amount of time NAP should wait after discovering a consolidation decision
    # This value can currently only be set when the consolidationPolicy is 'WhenEmpty'
    # You can choose to disable consolidation entirely by setting the string value 'Never'
    consolidateAfter: 30s
```

## Kubernetes and node image updates

AKS with node autoprovisioning manages the Kubernetes version upgrades and VM OS disk updates for you by default. You can also adjust the schedule of your Kubernetes and node image updates using planned maintenance windows during less busy periods for your workloads.

### Kubernetes upgrades

Kubernetes upgrades for node autoprovision nodes follows the control plane Kubernetes version. If you perform a cluster upgrade, your node autoprovision nodes are automatically updated to follow the same versioning. AKS recommends that you use `aksManagedAutoUpgradeSchedule` to schedule planned cluster upgrades during optimal times for your workloads. For more information on planning cluster upgrades, visit our [documentation on planned maintenance][planned-maintenance#schedule-configuration-types-for-planned-maintenance]

### Node image updates

By default NAP node pool virtual machines are automatically updated when a new image is available. There are multiple methods to regulate when your node image updates take place:

- Maintenance Windows (recommended): You can set `aksManagedNodeOSUpgradeSchedule` on an AKS-managed, or self-managed schedule. For more information, visit our [documentation on planned maintenance][planned-maintenance#schedule-configuration-types-for-planned-maintenance]
- Karpenter Node Disruption Budgets - Node-level disruption budgets can be set, and can be triggered when nodes move out of spec, known as Drift. 
- Pod Disruption Budgets (PDBs) - pod disruption budgets can be set in your application deployment file.

> [!IMPORTANT]
> After you update the SSH key, AKS doesn't automatically update your nodes. At any time, you can choose to perform a [nodepool update operation][node-image-upgrade]. The update SSH keys operation takes effect after a node image update is complete. For clusters with Node Auto-provisioning enabled, a node image update can be performed by applying a new label to the Kubernetes NodePool custom resource.

## Retrieve Karpenter logs and status 

You can retrieve logs and status updates from Node Autoprovisioning to help diagnose and debug Karpenter events. AKS manages Node autoprovisioning on your behalf and runs it in the managed control plane. You can enable control plane node to see the logs and operations from NAP through Azure Monitor, or the Diagnostic settings button in Azure Portal.

### [Azure CLI](#tab/azure-cli)

1. Set up a rule for resource logs to push Karpenter logs to Log Analytics using the [instructions here][aks-view-master-logs]. Make sure you check the box for `karpenter` when selecting options for **Logs**.
1. Select the **Log** section on your cluster.
1. Enter the following example query into Log Analytics:

    ```kusto
    AzureDiagnostics
    | where Category == "karpenter"
    ```
1. View Node Autoprovisioning scale-up not triggered events on CLI.
    ```bash
    kubectl get events --field-selector source=Karpenter,reason=NotTriggerScaleUp
    ```
1. View Node Autoprovisioning warning events on CLI.
    ```bash
    kubectl get events --field-selector source=cluster-autoscaler,type=Warning
    ```
1. Node autoprovisioning also writes out the health status to a `configmap` named `karpenter-status`. You can retrieve these logs using the following `kubectl` command:
    ```bash
    kubectl get configmap -n kube-system karpenter-status -o yaml
    ```
### [Azure portal](#tab/azure-portal)
1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
2. In the service menu, under **Settings**, select **Node pools**.
3. Select any of the tiles for **Karpenter events**, **Karpenter warnings**, or **Scale-up not triggered** to get more details.

---

## Node Auto-provisioning Metrics
You can enable [control plane metrics (Preview)](./monitor-control-plane-metrics.md) to access metrics for [Node Autoprovisioning](./control-plane-metrics-default-list.md#minimal-ingestion-for-default-off-targets) with the [Azure Monitor managed service for Prometheus add-on](/azure/azure-monitor/essentials/prometheus-metrics-overview). There is a default list of metrics that are scraped, and a larger list of metrics that can be accessed to capture more info as needed. 


## Monitoring selection events

Node autoprovision produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```
kubectl get events -A --field-selector source=karpenter -w
```

## Disabling node autoprovisioning

Node autoprovisioning can only be disabled when:
- There are no existing NAP-managed nodes. Use `kubectl get nodes -l karpenter.sh/nodepool` to view NAP-managed nodes.
- All existing karpenter.sh/NodePools have their `spec.limits.cpu` set to 0.

### Steps to disable node autoprovisioning

1. Set all karpenter.sh/NodePools `spec.limits.cpu` field to 0. This prevents new nodes from being created, but doesn't disrupt currently running nodes.

> [!NOTE]
> If you don't care about ensuring that every pod that was running on a NAP node is migrated safely to a non-NAP node,
> you can skip steps 2 and 3 and instead use the `kubectl delete node` command for each NAP-managed node.
>
> **Skipping steps 2 and 3 is not recommended, as it might leave some pods pending and doesn't honor PDBs.**
>
> **Do not run `kubectl delete node` on any nodes that are not managed by NAP.**

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
   This will start the process of migrating the workloads on the NAP-managed nodes to non-NAP nodes, honoring PDBs
   and disruption limits. Pods will migrate to non-NAP nodes if they can fit. If there isn't enough fixed-size
   capacity, some NAP-managed nodes will remain.
3. Scale up existing fixed-size ManagedCluster AgentPools, or create new fixed-size AgentPools, to take the load from the NAP-managed nodes.
   As these nodes are added to the cluster the NAP-managed nodes are drained, and work is migrated to the fixed-scale nodes.
4. Confirm that all NAP-managed nodes are deleted, using `kubectl get nodes -l karpenter.sh/nodepool`. If there are still NAP-managed
   nodes, it likely means that the cluster is out of fixed-scale capacity and needs more nodes so that the remaining workloads can be migrated.
5. Update the node provisioning mode parameter of the ManagedCluster to `Manual`.

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
            },
          }
        }
      ]
    }
    ```
---


<!-- LINKS - internal -->
[aks-view-master-logs]: monitor-aks.md#aks-control-planeresource-logs
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[planned-maintenance#schedule-configuration-types-for-planned-maintenance]: /azure/aks/planned-maintenance#schedule-configuration-types-for-planned-maintenance

<!-- LINKS - external -->
[aks-karpenter-provider]: https://github.com/Azure/karpenter-provider-azure
