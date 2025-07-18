---
title: Node autoprovisioning (preview)
description: Learn about Azure Kubernetes Service (AKS) node autoprovisioning (preview).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: schaffererin
author: schaffererin

# Customer intent: As a cluster operator or developer, I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.
---

# Node autoprovisioning (preview)

When you deploy workloads onto AKS, you need to make a decision about the node pool configuration regarding the VM size needed. As your workloads become more complex, and require different CPU, memory, and capabilities to run, the overhead of having to design your VM configuration for numerous resource requests becomes difficult.


Node autoprovisioning (NAP) (preview) uses pending pod resource requirements to decide the optimal virtual machine configuration to run those workloads in the most efficient and cost-effective manner.

NAP is based on the open source [Karpenter](https://karpenter.sh) project, and the [AKS provider](https://github.com/Azure/karpenter-provider-azure) is also open source. NAP automatically deploys and configures and manages Karpenter on your AKS clusters.


> [!IMPORTANT]
> Node autoprovisioning (NAP) for AKS is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

## Before you begin

- You need an Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- You need the [Azure CLI installed](/cli/azure/install-azure-cli).
- [Install the `aks-preview` Azure CLI extension.  Minimum version 0.5.170](#install-the-aks-preview-cli-extension).
- [Register the NodeAutoProvisioningPreviewfeature flag](#register-the-nodeautoprovisioningpreview-feature-flag).

## Install the `aks-preview` CLI extension

1. Install the `aks-preview` CLI extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update the extension to ensure you have the latest version installed using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `NodeAutoProvisioningPreview` feature flag

1. Register the `NodeAutoProvisioningPreview` feature flag using the `az feature register` command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the `az feature show` command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the `az provider register` command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

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
- Private cluster (and bring your own private DNS)

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
          "apiVersion": "2023-09-02-preview",
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
| kubernetes.io/os | Operating System (Linux only during preview) | linux |
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

## Kubernetes and node image updates

AKS with node autoprovisioning manages the Kubernetes version upgrades and VM OS disk updates for you by default.

### Kubernetes upgrades

Kubernetes upgrades for node autoprovision nodes follows the control plane Kubernetes version. If you perform a cluster upgrade, your node autoprovision nodes are automatically updated to follow the same versioning.

### Node image updates

By default NAP node pool virtual machines are automatically updated when a new image is available. If you wish to pin a node pool at a certain node image version, you can set the imageVersion on the node class:


```kubectl
kubectl edit aksnodeclass default
```

Within the node class definition, set the imageVersion to one of the published releases listed on the [AKS Release notes](https://github.com/Azure/AKS/blob/master/CHANGELOG.md).  You can also see the availability of images in regions by referring to the [AKS release tracker](https://releases.aks.azure.com/)

The imageVersion is the date portion on the Node Image as only Ubuntu 22.04 is supported, for example, "AKSUbuntu-2204-202311.07.0" would be "202311.07.0"

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  annotations:
    kubernetes.io/description: General purpose AKSNodeClass for running Ubuntu2204
      nodes
    meta.helm.sh/release-name: aks-managed-karpenter-overlay
    meta.helm.sh/release-namespace: kube-system
  creationTimestamp: "2023-11-16T23:59:06Z"
  generation: 1
  labels:
    app.kubernetes.io/managed-by: Helm
    helm.toolkit.fluxcd.io/name: karpenter-overlay-main-adapter-helmrelease
    helm.toolkit.fluxcd.io/namespace: 6556abcb92c4ce0001202e78
  name: default
  resourceVersion: "1792"
  uid: 929a5b07-558f-4649-b78b-eb25e9b97076
spec:
  imageFamily: Ubuntu2204
  imageVersion: 202311.07.0
  osDiskSizeGB: 128
  ```

Removing the imageVersion spec would revert the node pool to be updated to the latest node image version.

> [!IMPORTANT]
> After you update the SSH key, AKS doesn't automatically update your nodes. At any time, you can choose to perform a [nodepool update operation][node-image-upgrade]. The update SSH keys operation takes effect after a node image update is complete. For clusters with Node Auto-provisioning enabled, a node image update can be performed by applying a new label to the Kubernetes NodePool custom resource.

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
          "apiVersion": "2023-09-02-preview",
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

[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
