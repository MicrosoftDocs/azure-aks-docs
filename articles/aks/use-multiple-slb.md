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
---

## Overview

Azure Kubernetes Service (AKS) normally provisions one Standard Load Balancer (SLB) for all `LoadBalancer` Services in a cluster. Because each node NIC is limited to [**300 inbound load‑balancing rules** and **8 private‑link services**](azure/azure-resource-manager/management/azure-subscription-service-limits#load-balancer), large clusters or port‑heavy workloads can quickly exhaust these limits.

The **multiple SLB preview** removes that bottleneck by letting you create several SLBs inside the same cluster and shard nodes and Services across them. You define *load‑balancer configurations* each tied to a primary agent pool and optional namespace, label, or node selectors—and AKS automatically places nodes and Services on the appropriate SLB. Outbound SNAT behavior is unchanged: if `outboundType` is `loadBalancer`, outbound traffic still flows through the first SLB.

Use this feature to:

- Scale beyond 300 inbound rules without adding clusters.  
- Isolate tenant or workload traffic by binding a dedicated SLB to its own agent pool.  
- Distribute private‑link services across multiple SLBs when you approach the per‑SLB limit.

### How AKS chooses a load balancer (node & Service placement)

Multiple‑SLB clusters rely on three independent selectors to decide where traffic lands:

| Selector source | Evaluated for | What it does |
|-----------------|--------------|--------------|
| **Primary agent‑pool name** (set when the LB config is created) | Nodes only | All nodes in this pool are permanently attached to the corresponding SLB backend pool. Guarantees each SLB has at least one healthy node. |
| **Node selector** (`--node-selector` on the LB config)<br>*Kubernetes label selector* | Nodes only | Adds any node whose labels match to the SLB, supplementing the primary pool. Useful for multi‑pool or zone spread. |
| **Namespace & Service selectors** (`--service-namespace-selector`, `--service-label-selector` on the LB config)<br>*Kubernetes label selectors* | Services only | A `LoadBalancer` Service is eligible for an SLB when **both** its namespace labels and its own labels satisfy these selectors (if supplied). |

**Optional Service annotation**

`service.beta.kubernetes.io/azure-load-balancer-configurations: "<lb‑config‑1>,<lb‑config‑2>"`  
narrows the controller’s choice to a named subset of SLB configs. If the annotation is omitted, every configuration that passes the selectors is considered.

**Controller placement sequence**

1. **Node reconciliation** – Each new or updated node is evaluated against *primary pool* and *node selectors*; matching SLBs add the node to their backend pools.  
2. **Service reconciliation** – When a `LoadBalancer` Service appears:  
   - Intersect the annotation list (if present) with SLBs whose namespace and label selectors match.  
   - Discard SLBs with `allowServicePlacement=false`, or that would exceed Azure limits (300 rules / 8 private‑link services).  
   - Select the SLB that currently has the fewest rules. The Service’s front‑end is provisioned there.  
3. **Rebalance (optional)** – Run `az aks loadbalancer rebalance` to redistribute nodes if rule counts drift after scaling operations.

This mechanism lets you:

- Keep platform or shared traffic on the default `kubernetes` configuration.  
- Route team‑, environment‑, or workload‑specific Services to their own SLBs via labels.  
- Scale a single cluster well past the 300‑rule per‑NIC ceiling without re‑architecting.

### Prerequisites

- Azure CLI ** Need Requirements
- Subscription feature flag `Microsoft.ContainerService/MultipleStandardLoadBalancersPreview` registered.  
- Kubernetes version 1.28 or later.
- Cluster created with `--load-balancer-backend-pool-type nodeIP` or update and existing cluster using `az aks update`.

### Install the aks-preview Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

* Install the aks-preview extension using the [`az extension add`][az-extension-add] command.

    ```azurecli
    az extension add --name aks-preview
    ```

* Update to the latest version of the extension released using the [`az extension update`][az-extension-update] command.

    ```azurecli
    az extension update --name aks-preview
    ```

### Register the 'MultipleStandardLoadBalancersPreview' feature flag

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

### Add the first load balancer configuration

Add a configuration named `kubernetes` and bind it to a *primary* agent pool that always has at least one node. Removing every configuration switches the cluster back to single‑SLB mode.

> [!IMPORTANT]
> The first load balancer configuration must be named `kubernetes` and bound to a *primary* agent pool that always has at least one active node. AKS uses this configuration as the default for system services and workloads that don’t match any other selector. It also ensures outbound connectivity and stable control plane behavior. Removing all configurations reverts the cluster to single load balancer mode, which may disrupt service routing or SNAT behavior.

```azurecli
RESOURCE_GROUP="rg-aks-multislb"
CLUSTER_NAME="aks-multi-slb"
LOCATION="westus"
DEFAULT_LB_NAME="kubernetes"
PRIMARY_POOL="nodepool1"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME \
  --load-balancer-backend-pool-type nodeIP \
  --node-count 3

# Add default load balancer
az aks loadbalancer add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
  --name $DEFAULT_LB_NAME \
  --primary-agent-pool-name $PRIMARY_POOL \
  --allow-service-placement true
```

### Add additional load balancers

Create tenant‑specific configurations by specifying a different primary pool plus optional namespace, label, or node selectors.
Team 1 will run its own workloads in a separate node pool. Assign a `tenant=team1` label so workloads can be scheduled using selectors:

```azurecli
TEAM1_POOL="team1pool"
TEAM1_LB_NAME="team1-lb"

# Create a second node pool for team 1
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
  --name $TEAM1_POOL \
  --labels tenant=team1 \
  --node-count 2

# Create a load balancer for team 1
az aks loadbalancer add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME \
  --name $TEAM1_LB_NAME \
  --primary-agent-pool-name $TEAM1_POOL \
  --service-namespace-selector "tenant=team1" \
  --node-selector "tenant=team1"
```

Label the target namespace (e.g., `team1-apps`) to match the selector:

```azurecli


You can now list the loadbalancers in the cluster to see the multiple configurations:

```azurecli
az aks loadbalancer list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --output table
```

```output
AllowServicePlacement    ETag                                  Name        PrimaryAgentPoolName    ProvisioningState    ResourceGroup
-----------------------  ------------------------------------  ----------  ----------------------  -------------------  ---------------
True                     98bda91b-0247-4579-b969-ad8a92398694  kubernetes  nodepool1               Succeeded            rg-aks-multislb
True                     fc576898-4f4c-47cc-b49f-c7d83b9f0173  team1-lb    team1pool               Succeeded            rg-aks-multislb
```

### Deploy a Service to a specific load balancer

Add the annotation `service.beta.kubernetes.io/azure-load-balancer-configurations` with a comma‑separated list of configuration names. If the annotation is omitted, the controller chooses automatically.

```azurecli
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

Run a rebalance operation after scaling if rule counts become unbalanced. The command disrupts active flows, so schedule it during a maintenance window.

```azurecli
az aks loadbalancer rebalance --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME
```

### Monitoring and troubleshooting

- Watch controller events (`kubectl get events …`) to confirm that Services are reconciled.  
- If external connectivity is blocked, open a node shell and curl the Service VIP to confirm kube‑proxy routing.

### Limitations and known issues

| Limitation           | Details                                                                                    |
|----------------------|--------------------------------------------------------------------------------------------|
| Outbound SNAT        | Always uses the first SLB; outbound flows aren’t sharded.                                  |
| Backend pool type    | Cluster must be created with `nodeIP` backend pools; you can’t convert an existing one.    |
| Autoscaler zeros     | A primary agent pool can’t scale to 0 nodes.                                               |
| Rebalance disruption | Removing a node from a backend pool drops in‑flight connections. plan maintenance windows. |

### Clean up resources

Delete the resource group when you’re finished to remove the cluster and load balancers.

```azurecli
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

### Next steps and additional resources

The multiple SLB feature helps scale and isolate workloads at the networking layer while maintaining simplicity through Azure-managed configuration. For more information, see the following:

- [AKS Load Balancer concepts](load-balancer-standard.md)
- [Configure outbound connections in AKS](egress-outboundtype.md)
- [AKS node pools](manage-node-pools.md)
- [Azure subscription limits](azure/azure-resource-manager/management/azure-subscription-service-limits#load-balancer)
