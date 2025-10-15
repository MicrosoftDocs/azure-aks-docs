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


## Node auto provisioning Metrics
You can enable [control plane metrics (Preview)](./monitor-control-plane-metrics.md) to see the logs and operations from [node auto provisioning](./control-plane-metrics-default-list.md#minimal-ingestion-for-default-off-targets) with the [Azure Monitor managed service for Prometheus add-on](/azure/azure-monitor/essentials/prometheus-metrics-overview)

## Monitoring selection events

Node auto provisioning produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```
kubectl get events -A --field-selector source=karpenter -w
```

