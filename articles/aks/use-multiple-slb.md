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

### Prerequisites

- Azure CLI ** Need Requirements  
- Subscription feature flag `Microsoft.ContainerService/MultipleStandardLoadBalancersPreview` registered.  
- Kubernetes version 1.27 or later.
- Cluster created with `--load-balancer-backend-pool-type nodeIP` (you can’t migrate an existing NIC‑based cluster).  

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
az aks loadbalancer list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME
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
