---
title: node auto provisioning
description: Learn about Azure Kubernetes Service (AKS) node auto provisioning.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/30/2025
ms.author: wilsondarko
author: wdarko1

#Customer intent: As a cluster operator or developer, I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.

---

# node auto provisioning

When you deploy workloads onto AKS, you need to make a decision about the node pool configuration regarding the Virtual Machine (VM) size needed. As your workloads become more complex, and require different CPU, memory, and capabilities to run, the overhead of having to design your VM configuration for numerous resource requests becomes difficult.

node auto provisioning (NAP) uses pending pod resource requirements to decide the optimal virtual machine configuration to run those workloads in the most efficient and cost-effective manner.

node auto provisioning is based on the open source [Karpenter](https://karpenter.sh) project, and the [AKS Karpenter provider][aks-karpenter-provider] which is also open source. node auto provisioning automatically deploys, configures, and manages Karpenter on your AKS clusters.

## How node auto provisioning works

node auto provisioning provisions, scales, and manages virtual machines (nodes) in a cluster in response to pending pod pressure. node auto provisioning is able to manage this based on the specifications made using three Custom Resource Definitions (CRDs): NodePool, AKSNodeClass, and NodeClaims. The NodePool and AKSNodeClass CRDs can be created or updated to define how you want node auto provisioning to handle your workloads. NodeClaims are managed by node auto provisioning, and can be monitored to view current node state. node auto provisioning then uses definitions in the NodePools, AKSNodeClass, and NodeClaims, followed by any specifications in your workload deployment file to provision the most efficient nodes in your cluster. 

### Prerequisites

| Prerequisite                         | Notes                                                                                                        |
|--------------------------------------|--------------------------------------------------------------------------------------------------------------|
| **Azure Subscription**               | If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).  |
| **Azure CLI `aks-preview` extension**| `18.0.0b14` or later. To find the version, run `az --version`. To install, run `az extension add --name aks-preview` to install or to upgrade run `az extension upgrade --name aks-preview`. For more, see [Manage Azure CLI extensions][azure-cli-extensions].               |                      

## Limitations

- You can't enable node auto provisioning in a cluster where node pools have cluster autoscaler enabled

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

The recommended network configurations for clusters enabled with node auto provisioning are the following:
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md) with [Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Azure CNI](configure-azure-cni.md) with [Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI](configure-azure-cni.md)

Our recommended network policy engine is [Cilium](azure-cni-powered-by-cilium.md). 

The following networking configurations are currently *not* supported:

- Calico network policy
- Dynamic IP Allocation
- Static Allocation of CIDR blocks

## Enable node auto provisioning

### Enable node auto provisioning on a new cluster

node auto provisioning is enabled by setting the field `--node-provisioning-mode` to [Auto](/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep#managedclusternodeprovisioningprofile), which sets the Node Provisioning Profile to Auto. The default setting for this field is `Manual`. 

### [Azure CLI](#tab/azure-cli)

- Enable node auto provisioning on a new cluster using the `az aks create` command and set `--node-provisioning-mode` to `Auto`. You can also set the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay` (optional), and `--network-dataplane` to `cilium` (optional).

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

- Enable node auto provisioning on a new cluster using the `az deployment group create` command and specify the `--template-file` parameter with the path to the ARM template file. The ARM template includes the `mode` field in `nodeProvisioningProfile` set to `Auto`, which enabled node auto provisioning. 

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



### Enable node auto provisioning on an existing cluster

- Enable node auto provisioning on an existing cluster using the `az aks update` command and set `--node-provisioning-mode` to `Auto`.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --node-provisioning-mode Auto
    ```

## Custom Virtual Networks and node auto provisioning
AKS allows you to add a cluster with node auto provisioning enabled in a custom virtual network via the `--vnet-subnet-id` parameter. The following sections details how to create a virtual network, create a managed identity with permissions over the virtual network, and create a node auto provisioning-enabled cluster in a custom virtual network. 

### Create a virtual network

Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command. Create a cluster subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

When using a custom virtual network with node auto provisioning, you must create and delegate an API server subnet to `Microsoft.ContainerService/managedClusters`, which grants the AKS service permissions to inject the API server pods and internal load balancer into that subnet. You can't use the subnet for any other workloads, but you can use it for multiple AKS clusters located in the same virtual network. The minimum supported API server subnet size is a */28*.

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

### Create an AKS cluster in a custom virtual network and with node auto provisioning enabled
In the following command, an AKS cluster is created as part of a custom virtual network using the [az aks create][az-aks-create] command. To create a customer virtual network

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

node auto provisioning uses a list of VM SKUs as a starting point to decide which SKU is best suited for the workloads that are in a pending state. Having control over what SKU you want in the initial pool allows you to specify specific SKU families or virtual machine types and the maximum number of resources a provisioner uses. You can also reference different specifications in the node pool file, such as specifying *spot* or *on-demand* instances, multiple architectures, and more. 

If you have specific virtual machine sizes that are reserved instances, for example, you may wish to only use those virtual machines as the starting pool.

You can have multiple node pool definitions in a cluster, but AKS deploys a default node pool definition that you can modify:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmpty
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

### Supported node pool requirements

You can use labels to define constraints for your node pool custom resource file.

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

To learn more about virtual machine SKU capabilities, visit our [Virtual machine documentation][vm-overview].

## Node pool limits

By default, node auto provisioning attempts to schedule your workloads within the Azure quota you have available. You can also specify the upper limit of resources that is used by a node pool, specifying limits within the node pool spec.

```
  # Resource limits constrain the total size of the cluster.
  # Limits prevent Karpenter from creating new instances once the limit is exceeded.
  limits:
    cpu: "1000"
    memory: 1000Gi
```

## Node pool weights

When you have multiple node pools defined, it's possible to set a preference of where a workload should be scheduled. Define the relative weight on your Node pool definitions.

```yaml
  # Priority given to the node pool when the scheduler considers which to select. Higher weights indicate higher priority when comparing node pools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 10
```
>{!NOTE}
> AKS recommends avoiding weights in favor of using labels and other scheduling requirements to ensure your workload qualifies for unique NodePools and is scheduled exactly where you want the pod to be scheduled.

## Node disruption

### Disruption Controls
Node Disruption, including Consolidation or Drift, can be controlled using different methods. 

### Consolidation
When the workloads on your nodes scale down, node auto provisioning uses disruption rules on the node pool specification to decide when and how to remove those nodes and potentially reschedule your workloads to be more efficient. This is primarily done through *consolidation*, which deletes or replaces nodes to bin-pack your pods in an optimal configuration. The state-based consideration uses `ConsolidationPolicy` such as `WhenEmpty`, or `WhenEmptyOrUnderUtilized` to trigger consolidation. `consolidateAfter` is a time-based condition that can be set to allow buffer time between actions.

You can remove a node manually using `kubectl delete node`, but node auto provisioning can also control when it should optimize your nodes based on your specifications.

```yaml
  disruption:
    # Describes which types of Nodes node auto provisioning should consider for consolidation
    consolidationPolicy: WhenEmptyorUnderutilized
    # 'WhenEmptyorUnderutilized', node auto provisioning will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is empty or underutilized and could be changed to reduce cost

    #  `WhenEmpty`, node auto provisioning will only consider nodes for consolidation that contain no workload pods
    
    # The amount of time node auto provisioning should wait after discovering a consolidation decision
    # This value can currently only be set when the consolidationPolicy is 'WhenEmpty'
    # You can choose to disable consolidation entirely by setting the string value 'Never'
    consolidateAfter: 30s
```

### Disruption Controls
AKS with node auto provisioning manages the Kubernetes version upgrades and VM OS disk updates of your nodes for you through Drift. 

These can be regulated through multiple controls:
- Karpenter Node Disruption Budgets - Node-level disruption budgets can be set on your NodePool custom resources, and will limit node disruptions based on schedule and concurrent thresholds. These can be set directly for Drift, Disruption as a whole and/or other Karpenter disruption actions. 
- Pod Disruption Budgets (PDBs) - pod disruption budgets can be set in your application deployment file to determine when and which pods should be available for disruption. node auto provisioning honors PDBs. 


With [Auto Upgrade][auto-upgrade] enabled on your cluster, you can also adjust the schedule of your Kubernetes updates using planned maintenance windows to target less busy periods for your workloads.

### Kubernetes upgrades

Kubernetes upgrades for node auto provisioning nodes follow the control plane Kubernetes version. If you perform a cluster upgrade, your nodes are automatically updated to follow the same versioning. 

AKS recommends coupling node auto provisioning with a Kubernetes [Auto Upgrade][auto-upgrade] channel for the cluster, which will automatically take care of all your cluster's Kubernetes upgrades. Pairing the Auto Upgrade channel with an `aksManagedAutoUpgradeSchedule` planned maintenance window, you can schedule your cluster upgrades during optimal times for your workloads. For more information on planning cluster upgrades, visit our [documentation on planned maintenance][planned-maintenance#schedule-configuration-types-for-planned-maintenance]

### Node image updates

By default node auto provisioning node pool virtual machines are automatically updated when a new image is available. There are multiple methods to regulate when your node image updates take place, including Karpenter or Node Disruption Budgets, and Pod Disruption Budgets.

>[!NOTE]
>[Node OS Upgrade Channel settings][node-os-upgrade-channel] of Auto Upgrade don't impact node auto provisioning-managed nodes. node auto provisioning has its own automated method for ensuring node image upgrades. 

## Monitoring selection events

node auto provisioning produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```
kubectl get events -A --field-selector source=karpenter -w
```

## Disabling node auto provisioning

node auto provisioning can only be disabled when:
- There are no existing node auto provisioning-managed nodes. Use `kubectl get nodes -l karpenter.sh/nodepool` to view node auto provisioning-managed nodes.
- All existing karpenter.sh/NodePools have their `spec.limits.cpu` set to 0.

### Steps to disable node auto provisioning

1. Set all karpenter.sh/NodePools `spec.limits.cpu` field to 0. This prevents new nodes from being created, but doesn't disrupt currently running nodes.

> [!NOTE]
> If you don't care about ensuring that every pod that was running on a node auto provisioning node is migrated safely to a non-node auto provisioning node,
> you can skip steps 2 and 3 and instead use the `kubectl delete node` command for each node auto provisioning-managed node.
>
> **Skipping steps 2 and 3 is not recommended, as it might leave some pods pending and doesn't honor PDBs.**
>
> **Don't run `kubectl delete node` on any nodes that aren't managed by node auto provisioning.**

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
   This starts the process of migrating the workloads on the node auto provisioning-managed nodes to non-node auto provisioning nodes, honoring PDBs
   and disruption limits. Pods migrates to non-node auto provisioning nodes if they can fit. If there isn't enough fixed-size
   capacity, some node auto provisioning-managed nodes remains.
3. Scale up existing fixed-size ManagedCluster AgentPools, or create new fixed-size AgentPools, to take the load from the node auto provisioning-managed nodes.
   As these nodes are added to the cluster the node auto provisioning-managed nodes are drained, and work is migrated to the fixed-scale nodes.
4. Confirm that all node auto provisioning-managed nodes are deleted, using `kubectl get nodes -l karpenter.sh/nodepool`. If there are still node auto provisioning-managed
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
            }
          }
        }
      ]
    }
    ```
---

## FAQ

### How does node auto provisioning differ from the cluster autoscaler?
- **Direct VM management**: node auto provisioning provisions VMs directly rather than scaling VM Scale Sets
- **Faster provisioning**: No need to precreate VM Scale Sets for every combination of instance type and zone
- **Better bin packing**: Considers multiple instance types and zones simultaneously
- **More flexibility**: Supports diverse instance types, zones, and capacity types without complex configuration

**Installation and Configuration**

### Can I use node auto provisioning with existing AKS clusters?
Yes, node auto provisioning can be installed on existing AKS clusters.

### Do I need to remove Cluster Autoscaler before installing node auto provisioning?
Yes, you must remove or disable Cluster Autoscaler prior to enabling node auto provisioning. 

**Node Management**

### Which Azure VM sizes does node auto provisioning support?
node auto provisioning supports most Azure Virtual Machine sizes that are:
- Available in AKS
- Have 2 or more vCPUs
- Support standard Azure managed disks
- Are available in your region and availability zones

### Can I use custom virtual machine images with node auto provisioning?
No, you can't specify custom VM images for node auto provisioning.

### Does node auto provisioning handle spot VMs?
node auto provisioning supports Azure Spot VMs for cost savings. When using spot instances, be aware that they're subject to eviction policies.

### Can I mix spot and regular VMs in the same NodePool?
Yes, you can specify both `spot` and `on-demand` in the capacity type requirements. Weights can be applied in the pod spec to have an affinity for spot VMs, with a fall-back of on-demand instances.

**Networking and Security**

### How does NAP handle network security groups?
NAP uses the network security groups configured for your AKS cluster. It doesn't create or modify NSG rules.

## Troubleshooting

### Why aren't my pods being scheduled?
Common reasons include:
- No NodePool matches the pod's requirements
- NodePool limits have been reached
- Insufficient Azure quota or capacity
- Pod has unsatisfiable constraints

Mitigation:
- Review your current quota usage, and update if necessary
- Adjust pod constraints or NodePool constraints such that at least one NodePool can match pod specification
- Check recent Karpenter events for any capacity errors

   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   ```

### Why is node auto provisioning not terminating underutilized nodes?
Possible causes:
- Pods without proper tolerations
- DaemonSets preventing node drain
- Node disruption budgets blocking eviction
- Pod disruption budgets blocking eviction
- Nodes or Pods marked with `do-not-disrupt` annotation

### How can I debug node auto provisioning issues?

1. Examine NodePool and AKSNodeClass status:
   ```bash
   kubectl describe nodepool <name>
   kubectl describe aksnodeclass <name>
   ```

2. Review node and pod events:
   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   ```

**Cost Optimization**

### Does NAP support Azure Reserved Instances?
NAP can provision VMs that benefit from Reserved Instance pricing, but it doesn't directly manage reservations. You can configure a NodePool file to include the VM sizes that are your Reserved Instances, with a separate NodePool for other on-demand or spot instances. When your reserved VMs run out of quota, node auto provisioning falls back to a different NodePool config file's VM sizes. You can also configure your reserved instance NodePool limits to match the limits of capacity for reserved instances you have. [Purchase reservations][azure-reserved-instances] for your expected baseline capacity. The following example shows two NodePools: a NodePool for reserved instances, and spot VMs

```yaml
         apiVersion: karpenter.sh/v1
         kind: NodePool
         metadata:
           name: default-spot
         spec:
           template:
             spec:
               requirements:
               - key: karpenter.sh/capacity-type
                 operator: In
                 values: ["spot"]
               - key: kubernetes.io/arch
                 operator: In
                 values: ["amd64"]
               - key: karpenter.azure.com/sku-family
                 operator: In
                 values: ["D", "E", "F"]
               - key: karpenter.azure.com/sku-name
                 operator: NotIn
                 values: ["Standard_D2s_v3", "Standard_F2s_v2"]
         ---
         apiVersion: karpenter.sh/v1
         kind: NodePool
         metadata:
           name: reserved-vms
         spec:
           template:
             spec:
               requirements:
               - key: kubernetes.io/arch
                 operator: In
                 values: ["amd64"]
              - key: karpenter.azure.com/sku-name
                operator: In
                values: ["Standard_D2s_v3","Standard_F2s_v2"]
```

### How can I optimize costs with node auto provisioning?
- Use spot instances for fault-tolerant workloads
- Set appropriate expiration times for security updates
- Configure consolidation policies
- Use resource limits to prevent unexpected scaling
- Monitor and tune your NodePool configurations 

**Integration and Compatibility**

### Can I use node auto provisioning with Azure Container Instances (ACI)?
node auto provisioning manages VM-based nodes only. For serverless containers, consider using AKS virtual nodes with ACI alongside node auto provisioning.

### Does node auto provisioning work with Azure Policy?
Yes, VMs provisioned by node auto provisioning are subject to Azure Policy rules applied to the resource group and subscription.

### Can I use node auto provisioning with GitOps tools?
Yes, node auto provisioning resources (NodePools, AKSNodeClasses) can be managed through GitOps tools like ArgoCD or Flux.

### Does node auto provisioning support Windows nodes?
node auto provisioning currently supports Linux nodes through Ubuntu22.04 and AzureLinux (v2 and v3 based on the cluster's kubernetes version). Windows node support may be considered for future releases.

### Can I create nodes in my cluster which aren't managed by node auto provisioning?
Yes, you can manually create nodes or node pools in your cluster which aren't managed by node auto provisioning. For existing clusters that enable node auto provisioning, you can keep existing nodes or nodepools intact, though they won't be managed by node auto provisioning. 

### How do I  get help?
Learn how to [File An Azure support ticket][azure-support] with:
- Detailed description of the issue
- Steps to reproduce
- Relevant events and error messages

### How do I request features for node-auto provisioning?
- You can submit feature requests for node auto provisioning to our [AKS Github Repo: Issues][AKS-repo]
- To file tickets for self-hosted Karpenter on Azure, visit our [GitHub Repository: AKS Karpenter Provider][aks-karpenter-provider]

For feature reqeusts, file a feature request issue through the [AKS Karpenter Provider][aks-karpenter-provider-issues], which node auto provisioning is based on. 

<!-- LINKS - internal -->
[aks-view-master-logs]: monitor-aks.md#aks-control-planeresource-logs
[azure-cli-extensions]: /cli/azure/azure-cli-extensions-overview
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
