---
title: Migrate from cluster autoscaler to node auto-provisioning
description: Learn how to migrate your Azure Kubernetes Service (AKS) cluster from cluster autoscaler to node auto-provisioning.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 6/25/2026
ms.author: wilsondarko
author: wdarko1
ai-usage: ai-assisted

# Customer intent: As a cluster operator or developer, I want to be able to migrate from Cluster Autoscaler to Node Auto Provisioning safely. I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.
---

# Migrate from cluster autoscaler to node auto-provisioning

Migrate your existing Azure Kubernetes Service (AKS) cluster from [cluster autoscaler][cluster-autoscaler] to [node auto-provisioning][nap-main-doc] using the steps in this guide.

Node auto-provisioning (NAP) uses pending pod resource requirements to decide the optimal virtual machine (VM) configuration to run those workloads in the most efficient and cost-effective manner.

Node auto-provisioning is based on the open-source [Karpenter](https://karpenter.sh) project and the [AKS Karpenter provider][aks-karpenter-provider]. Node auto-provisioning automatically deploys, configures, and manages Karpenter on your AKS clusters.

## Cluster autoscaler vs. node auto-provisioning

### Why migrate from cluster autoscaler to node auto-provisioning

Node auto-provisioning improves bin-packing, automates node lifecycle management, and reduces operational overhead compared to cluster autoscaler.

| **Reason to Migrate**           | **Cluster Autoscaler (CAS)**                             | **Node Auto Provisioning (NAP)**                                   |
|---------------------------------|----------------------------------------------------------|--------------------------------------------------------------------|
| **VM Size Flexibility**         | Preexisting node pools with single VM size per pool     | Dynamic provisioning of mixed VM sizes for cost/performance balance|
| **Cost Optimization**           | Adds/removes nodes in pools; risk of underutilization    | Intelligent bin-packing reduces fragmentation and lowers costs     |
| **Management Overhead**         | Requires manual tuning of CAS profiles                   | Fully managed experience integrated with AKS                       |
| **Lifecycle Management**        | Basic scale-up/scale-down only                           | Advanced node lifecycle optimization; manage node updates, disruption + more |
| **Future Feature Development**  | Cluster autoscaler is maintained, with minimal feature enhancements | Continuous active development and new feature enhancements|


### Cluster autoscaler profile settings vs. node auto-provisioning configuration settings

Cluster autoscaler node pools use the agentpool API and `az aks` commands to set node pool behavior, while NAP uses the workload deployment spec and custom resource definitions (CRDs):

- Workload deployment spec - constraints such as `topologySpreadConstraints`, `nodeAffinity`, and `PodDisruptionBudgets`.
- Nodepool CRD - for acceptable node attributes (SKU, family, version, architecture, and more).
- AKSNodeClass CRD - for Azure-specific settings, custom kubelet configs, networking, and more.
- Node Overlay CRD (optional) - for custom pricing overrides users want to factor into NAP provisioning logic.

The following table maps cluster autoscaler profile settings to node auto-provisioning configuration settings for the NodePool CRD. This table also shows the cluster autoscaler Azure CLI command and its NAP CRD equivalent.

| **Cluster Autoscaler Profile Setting** | **Description** | **CAS CLI Example** |**NAP Disruption Setting** | **Description** | **NAP YAML Example** |
|----------------------------------------|-----------------|---------------------|---------------------------|------------------|-------------------------|
| `balance-similar-node-groups` | Balances node pools across zones | **CLI:** <br> `az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile balance-similar-node-groups=true` <br>  | N/A | NAP uses Karpenter’s provisioning logic; no direct equivalent | **YAML:** <br> `# Not applicable in NAP` |
| `expander` | Strategy for selecting node pool for scale-up |  **CLI:** <br>`az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile expander=least-waste`<br>  | N/A | NAP dynamically provisions optimal VM sizes; no expander concept | **YAML:** <br> `# Not applicable in NAP` |
| `scale-down-unneeded-time` | Time a node must be unneeded before eligible for scale down (default: 10m) | **CLI:** <br>`az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile scale-down-unneeded-time=10m`<br> | `consolidateAfter` | Time NAP waits after discovering consolidation opportunity before disrupting node | **YAML:** <br> `disruption:`<br> `  consolidateAfter: 10m` |
| `scale-down-unready-time` | Time an unready node must be unneeded before eligible for scale down (default: 20m) |**CLI:** <br> `az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile scale-down-unready-time=20m` <br> | `terminationGracePeriod` | Grace period for pod termination before node removal | **YAML:** <br> `disruption:`<br> `terminationGracePeriod: 20m` |
| `scale-down-utilization-threshold` | Node utilization threshold for scale down (default: 0.5) | **CLI:** <br> `az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile scale-down-utilization-threshold=0.5 `<br> |`consolidationPolicy` | Policy for consolidation: `WhenEmpty` or `WhenEmptyOrUnderUtilized` |  **YAML:** <br> `disruption:`<br> `consolidationPolicy: WhenEmptyOrUnderUtilized` |
| `scan-interval` | How often autoscaler reevaluates cluster (default: 10s) | **CLI:** <br>`az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile scan-interval=10s `<br> | N/A | NAP doesn't use periodic scans; decisions are event-driven |  **YAML:** <br> `# Not applicable in NAP` |
| `skip-nodes-with-local-storage` | Prevents deleting nodes with local storage |  **CLI:** <br>`az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile skip-nodes-with-local-storage=true`<br> | Annotation: `karpenter.sh/do-not-disrupt` | Blocks disruption for specific nodes or pods | **YAML:** <br> `metadata:`<br> `  annotations:` <br> `    karpenter.sh/do-not-disrupt: "true"` |
| `skip-nodes-with-system-pods` | Prevents deleting nodes with system pods |  **CLI:** <br> `az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile skip-nodes-with-system-pods=true` <br> | Annotation: `karpenter.sh/do-not-disrupt` | Same behavior for NAP | **YAML:** <br> `metadata:` <br> `  annotations:` <br> `    karpenter.sh/do-not-disrupt: "true"` |
| `max-empty-bulk-delete` | Max empty nodes deleted at once (default: 10) | **CLI:** <br> `az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile max-empty-bulk-delete=10` <br>  | `budgets` | Rate limits voluntary disruptions (percentage or absolute nodes) | **YAML:** <br> `disruption:` <br> `  budgets:`<br>`  - nodes: "10"` |
| `max-graceful-termination-sec` | Max seconds to wait for pod termination during scale down (default: 600s) | **CLI:** <br>`az aks update --resource-group <rg> --name <cluster> --cluster-autoscaler-profile max-graceful-termination-sec=600` <br> |`terminationGracePeriod` | Explicitly sets termination grace period for NAP nodes |  **YAML:** <br> `disruption:`<br>`  terminationGracePeriod: 600s` |
| `max-node-provision-time` | Max time to wait for node provisioning (default: 15m) | **CLI:** <br>`az aks update --cluster-autoscaler-profile max-node-provision-time=15m`<br> | N/A | NAP provisions nodes immediately based on pending pods | **YAML:** <br>`# Not applicable in NAP` |
| `ok-total-unready-count` / `max-total-unready-percentage` | Limits unready nodes during autoscaling | **CLI:** <br>`az aks update --cluster-autoscaler-profile ok-total-unready-count=3`<br> | `budgets` | Can enforce disruption limits during maintenance windows |  **YAML:** <br> `disruption:` <br> `  budgets:`<br>`    - nodes: "20%"` |

> [!NOTE]
> Unlike cluster autoscaler, NAP doesn't use Azure CLI commands to manage node behavior, so all decision making for NAP-managed nodes is determined by the CRDs.
> For more on configuring your cluster specifications for NAP, visit our [NodePool documentation](./node-auto-provisioning-node-pools.md) and [AKSNodeClass documentation](./node-auto-provisioning-aksnodeclass.md).

## Before you begin

| Prerequisite                         | Notes                                                                                                        |
|--------------------------------------|--------------------------------------------------------------------------------------------------------------|
| **Azure Subscription**               | If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).  |
| **Azure CLI**| `2.76.0` or later. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][azure cli].|                      

### Limitations

See [NAP limitations and unsupported features](./node-auto-provisioning.md#limitations-and-unsupported-features).

## Migrate from cluster autoscaler to node auto provisioning

You can migrate from cluster autoscaler to node auto provisioning by using one of two paths: 

- Disable cluster autoscaler, and then enable node auto provisioning.
  - This path avoids the complexity of running both autoscalers at once, which can result in overprovisioning without careful configuration. However, it requires a more abrupt migration.
  - With this method, existing node pools become fixed size while NAP is enabled, then you scale down the fixed nodes manually. NAP then provisions new nodes in response to pending pod pressure, and the workloads are now scheduled to NAP-managed nodes.
  - Follow [these steps](#path-1-disable-cluster-autoscaler-first-then-enable-node-auto-provisioning) for this path.
- Allow cluster autoscaler and node auto provisioning to co-exist in the same cluster.
  - This path allows a more gradual transition for existing clusters that use cluster autoscaler to move workloads to NAP-managed nodes. This path introduces more complexity and might result in overprovisioning by one or both autoscalers unless carefully managed. How to mitigate this risk is detailed in the following section.
  - The existing cluster autoscaler enabled node pools keep running, and you separate them by using taints and tolerations. Migrate workloads by changing the taints and tolerations to move from existing node pools to new NAP-managed nodes.
  - - Follow [these steps](#path-2-run-cluster-autoscaler-and-node-auto-provisioning-side-by-side) for this path.

### Pre-migration checklist

- Confirm cluster eligibility for node auto-provisioning. For more on NAP requirements, see [Overview of NAP documentation](./node-auto-provisioning.md).
- Right-size workloads for consolidation.
  - Set proper [resource requests/limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-requests-and-limits-of-pod-and-container), replicas, and [pod disruption budgets (PDBs)](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#specifying-a-poddisruptionbudget) to allow for a gradual migration. This migration method requires properly set PDBs to ensure well-managed disruption of your workloads. 
- Verify your system node pool is active.
  - AKS requires a system node pool for system components (such as CoreDNS and Karpenter). When NAP is enabled, AKS is responsible for autoscaling the system pool.
 
> [!IMPORTANT]
> If your workloads depend on custom subnets or network policies, configure custom subnets or network policies in the AKSNodeClass **before migrating workloads** to avoid scheduling failures. See the [AKSNodeClass documentation](./node-auto-provisioning-aksnodeclass.md) for details.

## Path 1: Disable cluster autoscaler first, then enable node auto provisioning

### Disable cluster autoscaler safely

If cluster autoscaler is enabled cluster-wide, disable it at the cluster level using the `--disable-cluster-autoscaler` flag. Nodes aren’t removed when you disable cluster autoscaler, so your capacity stays steady.

> [!NOTE]
> If you are planning to use cluster autoscaler and NAP in the same cluster for migration purposes, you can skip this step for now.

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myAKSCluster --disable-cluster-autoscaler
```

If cluster autoscaler is only enabled on select node pools, disable cluster autoscaler for specific node pools using the `--disable-cluster-autoscaler` flag.

```azurecli-interactive
# Disable CAS on a specific pool
az aks nodepool update \
  --resource-group myResourceGroup \
  --cluster-name myAKSCluster \
  --name mypool1 \
  --disable-cluster-autoscaler
```

You can also set the node count of your node pool to a pinned count as you begin the migration to node auto-provisioning. The following `az aks nodepool scale` command pins the node count of node pool `mypool1` in cluster `myAKSCluster` to five (5).

```azurecli-interactive
# (Optional) Pin to a safe desired count before the switch
az aks nodepool scale \
  --resource-group myResourceGroup \
  --cluster-name myAKSCluster \
  --name mypool1 \
  --node-count 5
```

### Enable node auto-provisioning on an existing cluster

Enable node auto-provisioning on an existing cluster using the `az aks update` command and set `--node-provisioning-mode` to `Auto`.

```azurecli-interactive
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --node-provisioning-mode Auto
```

Confirm that node auto-provisioning is active.

 ```azurecli-interactive
kubectl get crds
```

You should see `NodePool` and `AKSNodeClass` CRDs.

### Migrate existing workloads to NAP enabled nodes

Once cluster autoscaler is disabled your existing node pools are now a fixed count. For more on migrating these workloads from the existing fixed node pools to NAP-managed nodes, see [this section](#migrate-workloads-from-fixed-pools-to-node-auto-provisioning-managed-nodes).

## Path 2: Run Cluster Autoscaler and Node Auto-Provisioning side by side

### Allow cluster autoscaler and node auto-provisioning on the same cluster by registering the AllowClusterAutoscalerAndNAP feature flag

> [!WARNING]
> Using cluster autoscaler and NAP together in the same cluster indefinitely can cause unpredictable scaling behavior. Both scalers react to pending pod pressure, and can lead to double provisioning of nodes. When using both infrastructure scalers in the same cluster, be sure to use [taints and tolerations](./use-node-taints.md) for cluster autoscaler enabled node pools to maintain mutually exclusive scheduling.

1. Register the `AllowClusterAutoscalerAndNAP` feature flag by using the `az feature register` command.

   ```azurecli-interactive
   az feature register --namespace Microsoft.ContainerService --name AllowClusterAutoscalerAndNAP
   ```

1. Verify the registration status by using the `az feature show` command. It takes a few minutes for the status to show `Registered`.

   ```azurecli-interactive
   az feature show --namespace Microsoft.ContainerService --name AllowClusterAutoscalerAndNAP
   ```

1. When the status shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider by using the `az provider register` command.

   ```azurecli-interactive
   az provider register --namespace Microsoft.ContainerService
   ```

### Prevent cluster autoscaler and node auto-provisioning double-provisioning race condition (required)

When you use cluster autoscaler and NAP in the same cluster, both react to pending pod pressure, and without guardrails, they both scale up nodes. This condition can make pod scheduling unpredictable, so it's important to restrict which workloads can be scheduled to the cluster autoscaler-managed node pools when using the `AllowClusterAutoscalerAndNAP` feature flag. 

#### Add toleration to workloads staying on cluster autoscaler enabled node pools

Add the following toleration to workloads that should temporarily stay on cluster autoscaler enabled node pools:

```
tolerations:
- key: "autoscaling.azure.com/cas-block"
  value: true
  effect: "NoSchedule"
```

Make sure that any workloads you want to migrate to NAP do not have this toleration.

> [!NOTE]
> We recommend putting this toleration on _all_ workloads initially. You can then slowly change it to the `autoscaling.azure.com/nap-block` toleration discussed below to migrate workloads from CAS to NAP.

#### Add toleration to workloads migrating to NAP-managed nodes

Add the following toleration to workloads that you want to schedule to NAP-managed nodes:

```yaml
tolerations:
- key: "autoscaling.azure.com/nap-block"
  value: true
  effect: "NoSchedule"
```

Make sure that any workloads you want to keep on CAS do not have this toleration.

#### Add taint to cluster autoscaler enabled node pools

The following command adds a taint `autoscaling.azure.com/cas-block=true:NoSchedule` to the existing cluster autoscaler enabled node pools. This taint limits the pods that can be scheduled to these nodes to those with the proper toleration:

```
az aks nodepool update
--resource-group $RESOURCE_GROUP_NAME
--cluster-name $CLUSTER_NAME
--name $NODE_POOL_NAME
--node-taints "autoscaling.azure.com/cas-block=true:NoSchedule" --no-wait
```

Check that the taint is set on the cluster autoscaler enabled node. 

- Check the node taints in the node configuration by using the `kubectl describe node` command for a node in the cluster autoscaler managed node pool.

```
kubectl describe node $NODE_NAME
```

If you apply node taints, the following example output shows that the `<node-pool-name>` node pool has the specified Taint:

```output
[
    ...
    Name: <node-name>
    ...
    Taints: autoscaling.azure.com/cas-block=true:NoSchedule
    ...
    ],
]
```

### Enable node auto-provisioning on an existing cluster

Enable node auto-provisioning on an existing cluster using the `az aks update` command and set `--node-provisioning-mode` to `Auto` and `--node-provisioning-default-pools` to `None`. You must set `--node-provisioning-default-pools` to `None` because you must taint the NodePool to prevent CAS workloads from landing there. It is best to do this on your own NodePool rather than the default pools to avoid any race conditions.

```azurecli-interactive
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --node-provisioning-mode Auto --node-provisioning-default-poosl None
```

Confirm that node auto-provisioning is active.

 ```azurecli-interactive
kubectl get crds
```

You should see `NodePool` and `AKSNodeClass` CRDs.

### Create your own NodePool with the `autoscaling.azure.com/nap-block` taint

Follow the steps in [Customize your NodePool and AKSNodeClass](#customize-your-nodepool-and-aksnodeclass), but before deploying it ensure you also have applied the correct tains and tolerations to clearly identify workloads to be scheduled on the new NAP enabled nodes, and which should stay on the existing cluster autoscaler enabled node pools.

The following taint should be included in the `spec.template.spec.taints.key` field of the NodePool CRD for NAP-managed nodes. This taint limits the pods that can be scheduled to these nodes to those with the proper toleration:

```
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: nodepool1
spec:
  template:
    spec:
      taints:
        - key: autoscaling.azure.com/nap-block
          effect: NoSchedule
```

Check that the taint is set on the NodePool CRD.

- Check the node taints in the NodePool configuration by using the `kubectl describe nodepool` command.

```
kubectl describe CRD nodepool1
```

If you apply node taints, the following example output shows that the `nodepool1` NodePool CRD has the specified Taint:

```output
[
  spec:
    template:
      spec:
        taints:
          - key: autoscaling.azure.com/nap-block
            effect: NoSchedule
]
```

All nodes created from this NodePool CRD have the preceding taint. Be sure to apply this taint to all NAP NodePool CRDs deployed in your cluster.

### Migrate your workloads over time

Migrate your workloads from CAS to NAP over time using the tolerations above.

When you're done, follow the [clean up old autoscaling](#clean-up-old-autoscaling) steps to clean up the old autoscaling AgentPools that are no longer being used.

### Customize your NodePool and AKSNodeClass

When you first enable node auto-provisioning, the system deploys a default NodePool CRD and AKSNodeClass CRD. NAP uses these custom resource definition (CRD) files to define the acceptable range of nodes that it can provision for your workloads. You can update these defaults or add extra NodePool or AKSNodeClass CRDs that are specific to the type of workloads you want to deploy. If you don't want these default node pools and just want to define your own, you can disable these default CRDs.

#### [Basic](#tab/basic)

This example shows: 

- a basic NodePool that:
  - Supports on-demand instances
  - Uses D series VMs
  - Sets a CPU limit of 100
  - Enables consolidation when nodes are empty or underutilized
- a basic AKSNodeClass that:
  - Sets the node image OS to Ubuntu 

```yaml
#nodepool-default.yaml
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
      nodeClassRef:
        name: default
        group: karpenter.azure.com
        kind: AKSNodeClass
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: [on-demand]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: [D]
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 0s
    expireAfter: Never
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Ubuntu nodes"
spec:
  imageFamily: Ubuntu
```

You can deploy these custom resources to your cluster by using the following `kubectl` command:

```bash
kubectl apply -f nodepool-default.yaml
```

#### [Advanced](#tab/advanced)

This example shows an advanced NodePool and AKSNodeClass that you can deploy that:

- Supports both spot and on-demand instances
- Uses D, E, and F series VMs
- Sets a CPU limit of 100
- Sets nodes to never expire
- Enables consolidation when nodes are empty or underutilized
- Sets custom kubelet settings
- Sets `OSDiskSizeGB`
- Sets a max pod count per node

```yaml
#nodepool-default.yaml
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
      nodeClassRef:
        apiVersion: karpenter.azure.com/v1beta1
        kind: AKSNodeClass
        name: comprehensive-example
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: [spot, on-demand]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: [D, E, F]
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
  name: comprehensive-example
spec:
  # Image family configuration
  # Default: Ubuntu
  # Valid values: Ubuntu, AzureLinux
  imageFamily: Ubuntu

  # Virtual network subnet configuration (optional)
  # If not specified, uses the default --vnet-subnet-id from Karpenter installation
  vnetSubnetID: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/my-subnet"

  # OS disk size configuration
  # Default: 128 GB
  # Minimum: 30 GB
  osDiskSizeGB: 128

  # Maximum pods per node configuration
  # Default behavior depends on network plugin:
  # - Azure CNI with standard networking: 30 pods
  # - Azure CNI with overlay networking: 250 pods
  # - Other configurations: 110 pods
  # Range: 10-250
  maxPods: 30

  # Azure resource tags (optional)
  # Applied to all VM instances created with this AKSNodeClass
  tags:
    Environment: "production"
    Team: "platform-team"
    Application: "web-service"
    CostCenter: "engineering"

  # Kubelet configuration (optional)
  # All fields are optional with sensible defaults
  kubelet:
    # CPU management policy
    # Default: "none"
    # Valid values: none, static
    cpuManagerPolicy: "static"

    # CPU CFS quota enforcement
    # Default: true
    cpuCFSQuota: true

    # CPU CFS quota period
    # Default: "100ms"
    cpuCFSQuotaPeriod: "100ms"

    # Image garbage collection thresholds
    # imageGCHighThresholdPercent must be greater than imageGCLowThresholdPercent
    # Range: 0-100
    imageGCHighThresholdPercent: 85
    imageGCLowThresholdPercent: 80

    # Topology manager policy
    # Default: "none"
    # Valid values: none, restricted, best-effort, single-numa-node
    topologyManagerPolicy: "best-effort"

    # Container log configuration
    # containerLogMaxSize default: "50Mi"
    containerLogMaxSize: "50Mi"
    
    # containerLogMaxFiles default: 5, minimum: 2
    containerLogMaxFiles: 5

    # Pod process limits
    # Default: -1 (unlimited)
    podPidsLimit: 4096
```

> [!IMPORTANT]
> If your workloads depend on custom subnets or network policies, configure custom subnets or network policies in the AKSNodeClass **before migrating workloads** to avoid scheduling failures. Visit our [AKSNodeClass documentation](./node-auto-provisioning-aksnodeclass.md) for details.


You can now deploy the custom resources to your cluster with the following `kubectl` command:

```bash
kubectl apply -f nodepool-default.yaml
```

---

## Migrate workloads from fixed pools to node auto-provisioning managed nodes

This step migrates workloads on existing fixed node pools to NAP managed nodes. You can ignore this step if you are using cluster autoscaler and node auto-provisioning in the same cluster.

> [!NOTE]
> Consider setting node affinity that matches your specifications in NAP's NodePool and AKSNodeClass CRDs to ensure that your workloads can tolerate the types of nodes you defined NAP to provision and that they're scheduled to the NAP-managed nodes when desired. See the [AKS node selector and affinity documentation](./operator-best-practices-advanced-scheduler.md#control-pod-scheduling-using-node-selectors-and-affinity) for best practices.

Scale down user pools gradually (keep the system pool):

```azurecli-interactive
# For each user pool, step down to 0 (this command should respect properly set PDBs)
az aks nodepool scale \
  --resource-group <RG> \
  --cluster-name <CLUSTER> \
  --name <USER_POOL> \
  --node-count 0
```

As pods evict, node auto-provisioning provisions replacement nodes per your deployment spec, NodePool and AKSNodeClass rules. If a user pool must go to zero, remember you can only do that on user pools (not system pool), and with cluster autoscaler disabled on that node pool.

> [!NOTE]
> We recommend a gradual scale down in waves, and watch replicas/PDBs to avoid dips in availability.

To confirm that the scale down is working and workloads are being scheduled to NAP-managed nodes safely, check:

- Custom resource definition files are active
- Karpenter events detailing NAP decisions
- Nodeclaims are created in response to pending pod pressure 

## Verify node auto-provisioning

### Check CRDs and understand NAP fields
Check CRDs to confirm they are in use:

```bash
# Verify CRDs
kubectl get crd | grep karpenter
```

View field descriptions with the `kubectl explain` command:

```bash
# Use help api to describe fields
kubectl explain nodepool.spec
```

### Confirm new NAP-managed nodes are being created

To ensure that NAP is properly provisioning new nodes in response to pending pod pressure, verify that the new nodes are being created. Node auto-provisioning produces cluster events that you can use to monitor deployment and scheduling decisions. View events through the Kubernetes events stream.

```bash
kubectl get events -A --field-selector source=karpenter -w
```

Alternatively, view the NodeClaims that represent the nodes being created: 

```bash
kubectl get nodeclaims
```

A populated list confirms NAP is responding to pending pod pressure.

## Clean up old autoscaling 

- If you're using managed AKS cluster autoscaler only, the preceding steps already disable cluster autoscaler.
- If you're using managed AKS cluster autoscaler and node auto-provisioning in the same cluster, disable cluster autoscaler.
- If you're using self-hosted cluster autoscaler installed in kube-system, scale the cluster autoscaler pods to zero and remove.

```bash
kubectl -n kube-system scale deploy/cluster-autoscaler --replicas=0
kubectl -n kube-system delete deploy/cluster-autoscaler
```

### Remove migration taints and tolerations

- Remove the `autoscaling.azure.com/nap-block=NoSchedule` taint from the `spec.template.spec.taint` fields of your NAP NodePool CRD.
- Remove the `autoscaling.azure.com/nap-block` and `autoscaling.azure.com/cas-block` tolerations from your workloads.

## Fine-tune node auto-provisioning post-migration

After you complete your migration, you can fine-tune your cluster with these capabilities.

- **Manage disruption behavior** - Tune disruption `consolidationPolicy` and `consolidateAfter` windows to balance cost vs. virtual machine churn. See the [NAP Disruption documentation][nap-disruption-doc].
- **Multiple NodePools** - Split by workload class (for example, Spot vs On-Demand, GPU vs CPU) and use requirements, weights, and taints to control placement. See the [NAP NodePool documentation][nap-nodepool-doc].
- **Networking** - For more information on managing networking with custom virtual networks, see the [NAP networking documentation][nap-networking-doc].
- **Observability** - Stream Karpenter events and expose NAP control-plane metrics via Azure Monitor managed Prometheus. See the [NAP observability documentation][nap-observability].

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-auto-provisioning-custom-vnet.md)
- [Configure networking for node auto-provisioning on AKS](./node-auto-provisioning-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)
- [Upgrade node images for node auto-provisioning on AKS](./node-auto-provisioning-upgrade-image.md)
- [Enable/Disable node auto-provisioning on AKS][use-nap-doc]

---
<!-- LINKS - internal -->
[aks-view-master-logs]: ./monitor-aks.md#aks-control-planeresource-logs
[azure-cli-extensions]: /cli/azure/azure-cli-extensions-overview.md
[azure cli]: /cli/azure/get-started-with-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[planned-maintenance#schedule-configuration-types-for-planned-maintenance]: /azure/aks/planned-maintenance#schedule-configuration-types-for-planned-maintenance
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[auto-upgrade]: /azure/aks/auto-upgrade-cluster.md#cluster-auto-upgrade-channels
[node-os-upgrade-channel]: /azure/aks/auto-upgrade-node-os-image#available-node-os-upgrade-channels
[azure-support]: /azure/azure-portal/supportability/how-to-create-azure-support-request
[vm-overview]: /azure/virtual-machines/sizes/overview
[nap-main-doc]: /azure/aks/node-auto-provisioning
[nap-disruption-doc]: /azure/aks/node-auto-provisioning-disruption
[nap-nodepool-doc]: /azure/aks/node-auto-provisioning-node-pools
[nap-networking-doc]: /azure/aks/node-auto-provisioning-networking
[nap-observability]: /azure/aks/node-auto-provisioning#node-auto-provisioning-metrics
[cluster-autoscaler]: /azure/aks/cluster-autoscaler
[use-nap-doc]: /azure/aks/use-node-auto-provisioning

<!-- LINKS - external -->
[aks-karpenter-provider]: https://github.com/Azure/karpenter-provider-azure
[aks-karpenter-provider-issues]: https://github.com/Azure/karpenter-provider-azure/issues
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[AKS-repo]: https://github.com/Azure/AKS/issues
