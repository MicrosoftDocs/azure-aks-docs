---
title: Use multiple public load balancers in Azure Kubernetes Service (preview)
titleSuffix: Azure Kubernetes Service
description: Learn how to configure multiple Standard SKU public load balancers to scale LoadBalancer Services in Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 05/13/2025
ms.author: allensu
author: asudbring
ms.service: azure-kubernetes-service
---

# Use multiple public load balancers in Azure Kubernetes Service (preview)

Azure Kubernetes Service (AKS) normally provisions one Standard Load Balancer (SLB) for all `LoadBalancer` Services in a cluster. Because each node NIC is limited to [**300 inbound load‑balancing rules** and **8 private‑link services**](azure/azure-resource-manager/management/azure-subscription-service-limits#load-balancer), large clusters or port‑heavy workloads can quickly exhaust these limits.

The **multiple SLB preview** removes that bottleneck by letting you create several SLBs inside the same cluster and shard nodes and Services across them. You define *load‑balancer configurations*, each tied to a primary agent pool and optional namespace, label, or node selectors—and AKS automatically places nodes and Services on the appropriate SLB. Outbound SNAT behavior is unchanged if `outboundType` is `loadBalancer`. Outbound traffic still flows through the first SLB.

Use this feature to:

- Scale beyond 300 inbound rules without adding clusters.  
- Isolate tenant or workload traffic by binding a dedicated SLB to its own agent pool.  
- Distribute private‑link services across multiple SLBs when you approach the per‑SLB limit.
## Prerequisites

- `aks-preview` extension 18.0.0b1 or later.
- Subscription feature flag `Microsoft.ContainerService/MultipleStandardLoadBalancersPreview` registered.  
- Kubernetes version 1.28 or later.
- Cluster created with `--load-balancer-backend-pool-type nodeIP` or update and existing cluster using `az aks update`.

### Install the aks-preview Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

* Install the aks-preview extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

* Update to the latest version of the extension released using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `MultipleStandardLoadBalancersPreview` feature flag

1. Register the `MultipleStandardLoadBalancersPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "MultipleStandardLoadBalancersPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "MultipleStandardLoadBalancersPreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### How AKS chooses a load balancer (node & Service placement)

AKS uses multiple inputs to determine where to place nodes and expose LoadBalancer Services. These inputs are defined in each load balancer configuration and influence which SLB is selected for each resource.

| Input type                                                                                      | Applies to | Description |
|--------------------------------------------------------------------------------------------------|------------|-------------|
| **Primary agent pool**<br>`--primary-agent-pool-name`                                            | Nodes      | Required. All nodes in this pool are always added to the SLB’s backend pool. Ensures each SLB has at least one healthy node. |
| **Node selector**<br>`--node-selector`                                                          | Nodes      | Optional. Adds any node with matching labels to the SLB, in addition to the primary pool. |
| **Service namespace selector**<br>`--service-namespace-selector`                                | Services   | Optional. Only Services in namespaces with matching labels are considered for this SLB. |
| **Service label selector**<br>`--service-label-selector`                                        | Services   | Optional. Only Services with matching labels are eligible for this SLB. |
| **Service annotation**<br>`service.beta.kubernetes.io/azure-load-balancer-configurations`       | Services   | Optional. Limits placement to one or more explicitly named SLB configurations. Without it, any matching configuration is eligible. |

> [!NOTE]
> Selectors define eligibility. The annotation (if used) restricts the controller to a specific subset of SLBs.

#### How AKS uses these inputs

The AKS control plane continuously reconciles node and Service state using the rules above:

**Node Placement**
When a node is added or updated, AKS checks which SLBs it qualifies for based on primary pool and node selector.

	-	If multiple SLBs match, the controller picks the one with the fewest current nodes.
	-	The node is added to that SLB’s backend pool.

**Service placement**
When a LoadBalancer Service is created or updated:

1. AKS finds SLBs whose namespace and label selectors match the Service.
1. If the Service annotation is present, only those named SLBs are considered.
1. SLBs that have allowServicePlacement=false or that would exceed Azure limits (300 rules or 8 private-link services) are excluded.
1. Among valid options, the SLB with the fewest rules is chosen.

**Optional: Rebalancing**
You can manually rebalance node distribution later using `az aks loadbalancer rebalance`

This design lets you define flexible, label-driven routing for both infrastructure and workloads, while AKS handles placement automatically to maintain balance and avoid quota issues.


## Add the first load balancer configuration

Add a configuration named `kubernetes` and bind it to a *primary* agent pool that always has at least one node. Removing every configuration switches the cluster back to single‑SLB mode.

> [!IMPORTANT]
> To enable multiple‑SLB mode you **must** add a load‑balancer configuration named `kubernetes` and attach it to a *primary* agent pool that always has at least one ready node.  
> The presence of this configuration toggles multi‑SLB support; in service selection, it has no special priority and is treated like any other load balancer configuration.  
> If you delete every load‑balancer configuration, the cluster automatically falls back to single‑SLB mode, which can briefly disrupt service routing or SNAT flows.

1. Set environment variables for use throughout this tutorial. You can replace all placeholder values with your own except `DEFAULT_LB_NAME`, which must remain as `kubernetes`.

    ```bash
    RESOURCE_GROUP="rg-aks-multislb"
    CLUSTER_NAME="aks-multi-slb"
    LOCATION="westus"
    DEFAULT_LB_NAME="kubernetes"
    PRIMARY_POOL="nodepool1"
    ```

2. Create resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

3. Create an AKS cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command.\

    ```azurecli-interactive
    az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME \
      --load-balancer-backend-pool-type nodeIP \
      --node-count 3
    ```

4. Add a default load balancer using the [`az aks loadbalancer add`](/cli/azure/aks/loadbalancer#az-aks-loadbalancer-add) command.

    ```azurecli-interactive
    az aks loadbalancer add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
      --name $DEFAULT_LB_NAME \
      --primary-agent-pool-name $PRIMARY_POOL \
      --allow-service-placement true
    ```

## Add additional load balancers

Create tenant‑specific configurations by specifying a different primary pool plus optional namespace, label, or node selectors.

1. Team 1 will run its own workloads in a separate node pool. Assign a `tenant=team1` label so workloads can be scheduled using selectors:

    ```bash
    TEAM1_POOL="team1pool"
    TEAM1_LB_NAME="team1-lb"
    ```

2. Create a second node pool for team 1 using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command.

    ```azurecli-interactive
    az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
      --name $TEAM1_POOL \
      --labels tenant=team1 \
      --node-count 2
    ```

3. Create a load balancer for team 1 using the [`az aks loadbalancer add`](/cli/azure/aks/loadbalancer#az-aks-loadbalancer-add) command.

    ```azurecli-interactive
    az aks loadbalancer add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
      --name $TEAM1_LB_NAME \
      --primary-agent-pool-name $TEAM1_POOL \
      --service-namespace-selector "tenant=team1" \
      --node-selector "tenant=team1"
    ```


Label the target namespace (e.g., `team1-apps`) to match the selector:

```azurecli
az aks command invoke \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --command "
kubectl create namespace team1-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace team1-apps tenant=team1 --overwrite
"
```

You can now list the loadbalancers in the cluster to see the multiple configurations:

```azurecli
az aks loadbalancer list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --output table
```

```output
AllowServicePlacement    ETag     Name        PrimaryAgentPoolName    ProvisioningState    ResourceGroup
-----------------------  -------  ----------  ----------------------  -------------------  ---------------
True                     <ETAG>   kubernetes  nodepool1               Succeeded            rg-aks-multislb
True                     <ETAG>   team1-lb    team1pool               Succeeded            rg-aks-multislb
```

### Deploy a Service to a specific load balancer

Add the annotation `service.beta.kubernetes.io/azure-load-balancer-configurations` with a comma‑separated list of configuration names. If the annotation is omitted, the controller chooses automatically.

```azurecli-interactive
az aks command invoke \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --command "
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: lb-svc-1
  namespace: team1-apps
  labels:
    app: nginx-test
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-configurations: \"team1-lb\"
spec:
  selector:
    app: nginx-test
  ports:
  - name: port1
    port: 80
    targetPort: 80
    protocol: TCP
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: team1-apps
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          limits:
            cpu: \"150m\"
            memory: \"300Mi\"
EOF
"
```

### Rebalance nodes (optional)

Run a rebalance operation after scaling if rule counts become unbalanced using the [`az aks loadbalancer rebalance`](/cli/azure/aks/loadbalancer#az-aks-loadbalancer-rebalance) command. This command disrupts active flows, so schedule it during a maintenance window.

```azurecli-interactive
az aks loadbalancer rebalance --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME
```

## Monitoring and troubleshooting

- Watch controller events (`kubectl get events …`) to confirm that Services are reconciled.  
- If external connectivity is blocked, open a node shell and curl the Service VIP to confirm kube‑proxy routing.

## Limitations and known issues

| Limitation           | Details                                                                                    |
|----------------------|--------------------------------------------------------------------------------------------|
| Outbound SNAT        | Always uses the first SLB; outbound flows aren’t sharded.                                  |
| Backend pool type    | Create or update and existing cluster to use `nodeIP` backend pools.                       |
| Autoscaler zeros     | A primary agent pool can’t scale to 0 nodes.                                               |
| Rebalance disruption | Removing a node from a backend pool drops in‑flight connections. plan maintenance windows. |

## Clean up resources

Delete the resource group when you’re finished to remove the cluster and load balancers using the [`az group delete`](/cli/azure/group#az-group-delete) command.

```azurecli-interactive
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

### Next steps

The multiple SLB feature helps scale and isolate workloads at the networking layer while maintaining simplicity through Azure-managed configuration. For more information, see the following resources:

- [AKS Load Balancer concepts](load-balancer-standard.md)
- [Configure outbound connections in AKS](egress-outboundtype.md)
- [AKS node pools](manage-node-pools.md)
- [Azure subscription limits](azure/azure-resource-manager/management/azure-subscription-service-limits#load-balancer)
