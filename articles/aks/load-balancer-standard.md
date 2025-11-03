---
title: Use a public load balancer in Azure Kubernetes Service (AKS)
description: Learn how to use a public load balancer with a Standard SKU to expose your services with Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 01/23/2024
ms.author: davidsmatlak
author: davidsmatlak
# Customer intent: As a cluster operator or developer, I want to learn how to create a service in AKS that uses an Azure Load Balancer with a Standard SKU.
---

# Use a public standard load balancer in Azure Kubernetes Service (AKS)

The [Azure Load Balancer][az-lb] operates at layer 4 of the Open Systems Interconnection (OSI) model that supports both inbound and outbound scenarios. It distributes inbound flows that arrive at the load balancer's front end to the back end pool instances.

A **public** load balancer integrated with AKS serves two purposes:

- Provide outbound connections to the cluster nodes inside the AKS virtual network (VNet) by translating the private IP address to a public IP address part of its _outbound pool_.
- Provide access to applications via Kubernetes services of type `LoadBalancer`, enabling you to easily scale your applications and create highly available services.

This article covers integration with a public load balancer on AKS. For internal load balancer integration, see [Use an internal load balancer in AKS](internal-lb.md).

## Prerequisites

- Azure Load Balancer is available in two SKUs: _Basic_ and _Standard_. The _Standard_ SKU is used by default when you create an AKS cluster. The _Standard_ SKU gives you access to added functionality, such as a larger backend pool, [multiple node pools](create-node-pools.md), [Availability Zones](availability-zones.md), and is [secure by default][azure-lb]. It's the recommended load balancer SKU for AKS. For more information on the _Basic_ and _Standard_ SKUs, see [Azure Load Balancer SKU comparison][azure-lb-comparison].
- For a full list of the supported annotations for Kubernetes services with type `LoadBalancer`, see [LoadBalancer annotations][lb-annotations].
- This article assumes you have an AKS cluster with the _Standard_ SKU Azure Load Balancer. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or [the Azure portal][aks-quickstart-portal].

> [!IMPORTANT]
> If you'd prefer to use your own gateway, firewall, or proxy to provide outbound connection, you can skip the creation of the load balancer outbound pool and respective frontend IP by using [**outbound type as UserDefinedRouting (UDR)**](egress-outboundtype.md). The outbound type defines the egress method for a cluster and defaults to type `LoadBalancer`.

## Limitations

The following limitations apply when you create and manage AKS clusters that support a load balancer with the _Standard_ SKU:

- AKS manages the lifecycle and operations of agent nodes. Modifying the IaaS resources associated with the agent nodes isn't supported. An example of an unsupported operation is making manual changes to the load balancer resource group.
- At least one public IP or IP prefix is required for allowing egress traffic from the AKS cluster. The public IP or IP prefix is required to maintain connectivity between the control plane and agent nodes and to maintain compatibility with previous versions of AKS. You have the following options for specifying public IPs or IP prefixes with a _Standard_ SKU load balancer:

  - Provide your own public IPs.
  - Provide your own public IP prefixes.
  - Specify a number up to 100 to allow the AKS cluster to create that many _Standard_ SKU public IPs in the same resource group as the AKS cluster. This resource group is usually named with `MC_` at the beginning. AKS assigns the public IP to the _Standard_ SKU load balancer. By default, one public IP is automatically created in the same resource group as the AKS cluster if no public IP, public IP prefix, or number of IPs is specified. You also must allow public addresses and avoid creating any Azure policies that ban IP creation.

- A public IP created by AKS can't be reused as a custom bring your own (BYO) public IP address. You must create and manage all custom IP addresses.
- You can only define the load balancer SKU when you create an AKS cluster. You can't change the load balancer SKU after an AKS cluster has been created.
- You can only use one type of load balancer SKU (_Basic_ or _Standard_) in a single cluster.
- _Standard_ SKU load balancers only support _Standard_ SKU IP addresses.
- [Private Link Service](/azure/private-link/private-link-service-overview) isn't supported when the load balancer backend pool type is set to `nodeIP`.

## Create a public standard load balancer

### Create a load balancer service

After you create an AKS cluster with outbound type `LoadBalancer` (default), your cluster is ready to use the load balancer to expose services.

- Create a service manifest named `public-svc.yaml`, which creates a public service of type `LoadBalancer`.

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: public-svc
    spec:
      type: LoadBalancer
      ports:
      - port: 80
      selector:
        app: public-app
    ```

### Specify the load balancer IP address

If you want to use a specific IP address with the load balancer, you have two options to specify the IP address:

- **Set service annotations** (recommended): Use `service.beta.kubernetes.io/azure-load-balancer-ipv4` for an IPv4 address and `service.beta.kubernetes.io/azure-load-balancer-ipv6` for an IPv6 address.
- **Add the _LoadBalancerIP_ property to the load balancer YAML manifest**: Add the `Service.Spec.LoadBalancerIP` property to the load balancer YAML manifest. This field is deprecating following [upstream Kubernetes](https://github.com/kubernetes/kubernetes/pull/107235), and it can't support dual-stack. Current usage remains the same and existing services are expected to work without modification.

### Deploy the service manifest

1. Deploy the public service manifest using [`kubectl apply`][kubectl-apply] and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f public-svc.yaml
    ```

    The Azure Load Balancer is configured with a new public IP that fronts the new service. Since the Azure Load Balancer can have multiple frontend IPs, each new service that you deploy gets a new dedicated frontend IP to be uniquely accessed.

1. Confirm your service is created and the load balancer is configured using the `kubectl get service` command.

    ```bash
    kubectl get service public-svc
    ```

    When you view the service details, the public IP address created for this service on the load balancer is shown in the _EXTERNAL-IP_ column of the output. It might take a few minutes for the IP address to change from _\<pending\>_ to an actual public IP address. The following example output shows successful creation of the service:

    ```output
    NAMESPACE     NAME          TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)         AGE
    default       public-svc    LoadBalancer   10.0.39.110    203.0.113.187   80:32068/TCP    52s
    ```

1. Get more detailed information about your service using the `kubectl describe service` command.

    ```bash
    kubectl describe service public-svc
    ```

    The following example output is a condensed version of the output after you run `kubectl describe service`. _LoadBalancer Ingress_ shows the external IP address exposed by your service. _IP_ shows the internal addresses.

    ```output
    Name:                        public-svc
    Namespace:                   default
    Labels:                      <none>
    Annotations:                 <none>
    Selector:                    app=public-app
    ...
    IP:                          10.0.39.110
    ...
    LoadBalancer Ingress:        203.0.113.187
    ...
    TargetPort:                  80/TCP
    NodePort:                    32068/TCP
    ...
    Session Affinity:            None
    External Traffic Policy:     Cluster
    ...
    ```

## Configure the public standard load balancer

You can customize different settings for your standard public load balancer at cluster creation time or by updating the cluster. These customization options allow you to create a load balancer that meets your workload needs. With the standard load balancer, you can:

- [Change the inbound pool type](#change-the-inbound-pool-type).
- [Set or scale the number of managed outbound IPs](#scale-the-number-of-managed-outbound-public-ips).
- [Provide your own custom outbound IPs or outbound IP prefix](#provide-your-own-outbound-public-ips-or-prefixes).
- [Customize the number of allocated outbound ports to each node on the cluster](#configure-the-allocated-outbound-ports).
- [Configure the timeout setting for idle connections](#configure-the-load-balancer-idle-timeout).

> [!IMPORTANT]
> You can only use one outbound IP option (managed IPs, bring your own IP, or IP prefix) at a given time.

### Change the inbound pool type

You can reference AKS nodes in the load balancer backend pools by their IP configuration (Azure Virtual Machine Scale Sets based membership) or their IP address only. The IP address based backend pool membership provides higher efficiencies when updating services and provisioning load balancers, especially at high node counts. When combined with [NAT Gateway](./nat-gateway.md) or [user-defined routing egress](./egress-udr.md) types, provisioning of new nodes and services are more performant.

Two different pool membership types are available:

- `nodeIPConfiguration`: Legacy Virtual Machine Scale Sets IP configuration based pool membership type.
- `nodeIP`: IP-based membership type.

#### Requirements for changing the inbound pool type

Make sure you meet the following requirements before changing the inbound pool type:

- The AKS cluster must be version 1.23 or newer.
- The AKS cluster must be using standard load balancers and Virtual Machine Scale Sets.

#### [Create a new AKS cluster with IP-based inbound pool membership](#tab/create-cluster-ip-based)

- Create an AKS cluster with IP-based inbound pool membership using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--load-balancer-backend-pool-type=nodeIP` parameter.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-backend-pool-type=nodeIP \
        --generate-ssh-keys
    ```

#### [Update an existing AKS cluster to use IP-based inbound pool membership](#tab/update-cluster-ip-based)

> [!WARNING]
> This operation causes a temporary disruption to incoming service traffic in the cluster. The impact time increases with larger clusters that have many nodes.

- Update an existing AKS cluster to use IP-based inbound pool membership using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--load-balancer-backend-pool-type=nodeIP` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-backend-pool-type=nodeIP
    ```

---

### Scale the number of managed outbound public IPs

Azure Load Balancer provides outbound and inbound connectivity from a VNet. Outbound rules make it simple to configure network address translation for the public standard load balancer.

Outbound rules follow the same syntax as load balancing and inbound NAT rules: **_frontend IPs + parameters + backend pool_**

An outbound rule configures outbound NAT for all virtual machines (VMs) identified by the backend pool to be translated to the frontend. Parameters provide more control over the outbound NAT algorithm.

While you can use an outbound rule with a single public IP address, outbound rules are great for scaling outbound NAT because they ease the configuration burden. You can use multiple IP addresses to plan for large-scale scenarios and outbound rules to mitigate SNAT exhaustion prone patterns. Each IP address provided by a frontend provides 64k ephemeral ports for the load balancer to use as SNAT ports.

When using a _Standard_ SKU load balancer with managed outbound public IPs (which are created by default), you can scale the number of managed outbound public IPs using the `--load-balancer-managed-outbound-ip-count` parameter.

> [!IMPORTANT]
> We don't recommend using the Azure portal to make any outbound rule changes. When making these changes, you should go through the AKS cluster and not directly on the Load Balancer resource.
>
> Outbound rule changes made directly on the Load Balancer resource are removed whenever the cluster is reconciled, such as when it's stopped, started, upgraded, or scaled.
>
> Use the Azure CLI, as shown in the examples. Outbound rule changes made using `az aks` CLI commands are permanent across cluster downtime.
>
> For more information, see [Azure Load Balancer outbound rules][alb-outbound-rules].

#### Update an existing cluster to scale managed outbound public IPs

- Update an existing AKS cluster to scale the number of managed outbound public IPs using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--load-balancer-managed-outbound-ip-count` parameter. The following example sets the number of managed outbound public IPs to _two_.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-managed-outbound-ip-count 2
    ```

> [!NOTE]
> You can also set the initial number of managed outbound public IPs at cluster creation time with the `--load-balancer-managed-outbound-ip-count` parameter. The default number of managed outbound public IPs is _one_.

### Provide your own outbound public IPs or prefixes

When you use a _Standard_ SKU load balancer, the AKS cluster automatically creates a public IP in the AKS-managed infrastructure resource group and assigns it to the load balancer outbound pool by default.

A public IP created by AKS is an AKS-managed resource, meaning AKS manages the lifecycle of that public IP and doesn't require user action directly on the public IP resource. Alternatively, you can assign your own custom public IP or public IP prefix at cluster creation time. Your custom IPs can also be updated on an existing cluster's load balancer properties.

#### Requirements for using your own outbound public IPs or prefixes

Make sure you meet the following requirements before providing your own outbound public IPs or prefixes:

- You must create and own custom public IP addresses. You can't reuse managed public IP addresses created by AKS as a "bring your own custom IP" because it can cause management conflicts.
- You must ensure the AKS cluster identity has permissions to access the outbound IP, as per the [required public IP permissions list](kubernetes-service-principal.md#networking).
- Make sure you meet the [prerequisites and constraints](/azure/virtual-network/ip-services/public-ip-address-prefix#limitations) necessary to configure outbound IPs or outbound IP prefixes.

#### Provide your own outbound public IPs

##### [Provide your own outbound public IPs when creating a new cluster](#tab/create-cluster-custom-ips)

- Create a new AKS cluster with your own outbound public IPs using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--load-balancer-outbound-ips` parameter. Make sure you replace the placeholder values with your own.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-outbound-ips $PUBLIC_IP_ID1,$PUBLIC_IP_ID2 \
        --generate-ssh-keys
    ```

##### [Update an existing cluster to use your own outbound public IPs](#tab/update-cluster-custom-ips)

- Update an existing AKS cluster to use your own outbound public IPs using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--load-balancer-outbound-ips` parameter. Make sure you replace the placeholder values with your own.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-outbound-ips $PUBLIC_IP_ID1,$PUBLIC_IP_ID2
    ```

---

#### Provide your own outbound public IP prefixes

##### [Provide your own outbound public IP prefixes when creating a new cluster](#tab/create-cluster-custom-ip-prefixes)

- Create a new AKS cluster with your own outbound public IP prefixes using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--load-balancer-outbound-ip-prefixes` parameter. Make sure you replace the placeholder values with your own.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --load-balancer-outbound-ip-prefixes $PUBLIC_IP_PREFIX_ID1,$PUBLIC_IP_PREFIX_ID2 \
        --generate-ssh-keys
    ```

##### [Update an existing cluster to use your own outbound public IP prefixes](#tab/update-cluster-custom-ip-prefixes)

- Update an existing AKS cluster to use your own outbound public IP prefixes using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--load-balancer-outbound-ip-prefixes` parameter. Make sure you replace the placeholder values with your own.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-outbound-ip-prefixes $PUBLIC_IP_PREFIX_ID1,$PUBLIC_IP_PREFIX_ID2
    ```

---

### Configure the allocated outbound ports

> [!IMPORTANT]
>
> If you have applications on your cluster that can establish a large number of connections to small set of destinations on public IP addresses, like many instances of a frontend application connecting to a database, you might have a scenario susceptible to encounter SNAT port exhaustion. SNAT port exhaustion happens when an application runs out of outbound ports to use to establish a connection to another application or host. If you have a scenario susceptible to encounter SNAT port exhaustion, we highly recommended you increase the allocated outbound ports and outbound frontend IPs on the load balancer.
>
> For more information on SNAT, see [Use SNAT for outbound connections](/azure/load-balancer/load-balancer-outbound-connections).

By default, AKS sets _AllocatedOutboundPorts_ on its load balancer to `0`, which enables [automatic outbound port assignment based on backend pool size][azure-lb-outbound-preallocatedports] when creating a cluster. For example, if a cluster has 50 or fewer nodes, 1024 ports are allocated to each node. This value allows for scaling to cluster maximum node counts without requiring networking reconfiguration, but can make SNAT port exhaustion more common as more nodes are added. As the number of nodes in the cluster increases, fewer ports are available per node. Increasing the node counts across the boundaries in the chart (for example, going from 50 to 51 nodes or 100 to 101) might be disruptive to connectivity as the SNAT ports allocated to existing nodes are reduced to allow for more nodes. We recommend using an explicit value for _AllocatedOutboundPorts_.

#### View the current allocated outbound ports

- Get the _AllocatedOutboundPorts_ value for the AKS cluster load balancer using the [`az network lb outbound-rule list`](/cli/azure/network/lb/outbound-rule#az-network-lb-outbound-rule-list) command.

    ```azurecli-interactive
    NODE_RG=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query nodeResourceGroup -o tsv)
    az network lb outbound-rule list --resource-group $NODE_RG --lb-name kubernetes -o table
    ```

    The following example output shows that automatic outbound port assignment based on backend pool size is enabled for the cluster:

    ```output
    AllocatedOutboundPorts    EnableTcpReset    IdleTimeoutInMinutes    Name             Protocol    ProvisioningState    ResourceGroup
    ------------------------  ----------------  ----------------------  ---------------  ----------  -------------------  -------------
    0                         True              30                      aksOutboundRule  All         Succeeded            MC_myResourceGroup_myAKSCluster_eastus
    ```

#### Calculate and verify outbound ports and IPs needed

Before setting a specific value or increasing an existing value for either outbound ports or outbound IP addresses, you must calculate the appropriate number of outbound ports and IP addresses. Use the following equation for this calculation rounded to the nearest integer: `64,000 ports per IP / <outbound ports per node> * <number of outbound IPs> = <maximum number of nodes in the cluster>`.

When calculating the number of outbound ports and IPs and setting the values, keep the following information in mind:

- The number of outbound ports per node is fixed based on the value you set.
- The value for outbound ports must be a multiple of 8.
- Adding more IPs doesn't add more ports to any node, but it provides capacity for more nodes in the cluster.
- You must account for nodes that might be added as part of upgrades, including the count of nodes specified via [maxCount][maxcount] and [maxSurge][maxsurge] values.

The following examples show how the values you set affect the number of outbound ports and IP addresses:

- If the default values are used and the cluster has 48 nodes, each node has 1024 ports available.
- If the default values are used and the cluster scales from 48 to 52 nodes, each node is updated from 1024 ports available to 512 ports available.
- If the number of outbound ports is set to 1,000 and the outbound IP count is set to 2, then the cluster can support a maximum of 128 nodes: `64,000 ports per IP / 1,000 ports per node * 2 IPs = 128 nodes`.
- If the number of outbound ports is set to 1,000 and the outbound IP count is set to 7, then the cluster can support a maximum of 448 nodes: `64,000 ports per IP / 1,000 ports per node * 7 IPs = 448 nodes`.
- If the number of outbound ports is set to 4,000 and the outbound IP count is set to 2, then the cluster can support a maximum of 32 nodes: `64,000 ports per IP / 4,000 ports per node * 2 IPs = 32 nodes`.
- If the number of outbound ports is set to 4,000 and the outbound IP count is set to 7, then the cluster can support a maximum of 112 nodes: `64,000 ports per IP / 4,000 ports per node * 7 IPs = 112 nodes`.

> [!IMPORTANT]
> After calculating the number outbound ports and IPs, verify you have extra outbound port capacity to handle node surge during upgrades. It's critical to allocate sufficient excess ports for extra nodes needed for upgrade and other operations. AKS defaults to _one_ buffer node for upgrade operations. If you're using [`maxSurge` values][maxsurge], multiply the outbound ports per node by your `maxSurge` value to determine the number of ports required. For example, if you calculate that you need 4000 ports per node with 7 IP address on a cluster with a maximum of 100 nodes and a max surge of 2:
>
> - 2 surge nodes * 4000 ports per node = 8000 ports needed for node surge during upgrades.
> - 100 nodes * 4000 ports per node = 400,000 ports required for your cluster.
> - 7 IPs * 64000 ports per IP = 448,000 ports available for your cluster.
>
> This example shows the cluster has an excess capacity of 48,000 ports, which is sufficient to handle the 8000 ports needed for node surge during upgrades.

#### Set the allocated outbound ports and outbound IPs

Once the values have been calculated and verified, you can apply those values using `load-balancer-outbound-ports` and either `load-balancer-managed-outbound-ip-count`, `load-balancer-outbound-ips`, or `load-balancer-outbound-ip-prefixes` when creating or updating a cluster.

##### [Create a new cluster with specific outbound ports and IPs](#tab/create-cluster-outbound-ports-ips)

- Create a new AKS cluster with specific outbound ports and IPs using the [`az aks create`](/cli/azure/aks#az-aks-create) command. The following example sets the `--load-balancer-managed-outbound-ip-count` parameter to _7_ and the `--load-balancer-outbound-ports` parameter to _4000_:

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-managed-outbound-ip-count 7 \
        --load-balancer-outbound-ports 4000 \
        --generate-ssh-keys
    ```

##### [Update an existing cluster with specific outbound ports and IPs](#tab/update-cluster-outbound-ports-ips)

- Update an existing AKS cluster with specific outbound ports and IPs using the [`az aks update`](/cli/azure/aks#az-aks-update) command. The following example sets the `--load-balancer-managed-outbound-ip-count` parameter to _7_ and the `--load-balancer-outbound-ports` parameter to _4000_:

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-managed-outbound-ip-count 7 \
        --load-balancer-outbound-ports 4000
    ```

---

### Configure the load balancer idle timeout

When SNAT port resources are exhausted, outbound flows fail until existing flows release SNAT ports. Load balancer reclaims SNAT ports when the flow closes, and the AKS-configured load balancer uses a 30-minute idle timeout for reclaiming SNAT ports from idle flows. You can also use transport (for example, **`TCP keepalives`** or **`application-layer keepalives`**) to refresh an idle flow and reset this idle timeout if necessary.

If you expect to have numerous short-lived connections and no long-lived connections that might have long times of idle, like using `kubectl proxy` or `kubectl port-forward`, consider using a low timeout value such as _4 minutes_. When using TCP keepalives, it's sufficient to enable them on one side of the connection. For example, it's sufficient to enable them on the server side only to reset the idle timer of the flow. It's not necessary for both sides to start TCP keepalives. Similar concepts exist for application layer, including database client-server configurations. Check the server side for what options exist for application-specific keepalives.

> [!IMPORTANT]
>
> AKS enables _TCP Reset_ on idle by default. We recommend you keep this configuration and leverage it for more predictable application behavior on your scenarios. For more information, see [Azure load balancer TCP reset](/azure/load-balancer/load-balancer-tcp-reset).

When setting _IdleTimeoutInMinutes_ to a different value than the default of 30 minutes, consider how long your workloads need an outbound connection. Also consider that the default timeout value for a _Standard_ SKU load balancer used outside of AKS is _4 minutes_. An _IdleTimeoutInMinutes_ value that more accurately reflects your specific AKS workload can help decrease SNAT exhaustion caused by tying up connections no longer being used.

> [!WARNING]
> Altering the values for _AllocatedOutboundPorts_ and _IdleTimeoutInMinutes_ might significantly change the behavior of the outbound rule for your load balancer and shouldn't be done lightly. Check the [SNAT Troubleshooting section][troubleshoot-snat] and review the [Load balancer outbound rules][azure-lb-outbound-rules-overview] and [outbound connections in Azure][azure-lb-outbound-connections] before updating these values to fully understand the impact of your changes.

#### [Create a new cluster with a specific idle timeout](#tab/create-cluster-idle-timeout)

- Create a new AKS cluster with a specific idle timeout using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--load-balancer-idle-timeout` parameter. The following example sets the idle timeout to _4 minutes_:

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-idle-timeout 4 \
        --generate-ssh-keys
    ```

#### [Update an existing cluster with a specific idle timeout](#tab/update-cluster-idle-timeout)

- Update an existing AKS cluster with a specific idle timeout using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--load-balancer-idle-timeout` parameter. The following example sets the idle timeout to _4 minutes_:

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --load-balancer-idle-timeout 4
    ```

---

## Restrict inbound traffic to specific IP ranges

The following manifest uses `loadBalancerSourceRanges` to specify a new IP range for inbound external traffic:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
  loadBalancerSourceRanges:
  - MY_EXTERNAL_IP_RANGE
```

This example updates the rule to allow inbound external traffic only from the `MY_EXTERNAL_IP_RANGE` range. If you replace `MY_EXTERNAL_IP_RANGE` with the internal subnet IP address, traffic is restricted to only cluster internal IPs. If traffic is restricted to cluster internal IPs, clients outside your Kubernetes cluster are unable to access the load balancer.

> [!NOTE]
> Keep the following information in mind when restricting inbound traffic:
>
> - When you need to allow both CIDR blocks and Azure service tags, remove the `loadBalancerSourceRanges` property and add the `service.beta.kubernetes.io/azure-allowed-ip-ranges` and/or `service.beta.kubernetes.io/azure-allowed-service-tags` Load Balancer annotations. This configuration applies filtering only at the NSG layer and skips host-level kube-proxy rules. If you set the `loadBalancerSourceRanges` property together with the `azure-allowed-service-tags` annotation, AKS will report an error when you attempt to apply the specification.
> - Inbound, external traffic flows from the load balancer to the VNet for your AKS cluster. The VNet has a network security group (NSG) which allows all inbound traffic from the load balancer. This NSG uses a [service tag][service-tags] of type _LoadBalancer_ to allow traffic from the load balancer.
> - Pod CIDR should be added to `loadBalancerSourceRanges` if there are Pods needing to access the service's Load Balancer IP for clusters with Kubernetes version 1.25 or above.

## Maintain the client's IP on inbound connections

By default, a service of type `LoadBalancer` [in Kubernetes](https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-loadbalancer) and in AKS doesn't persist the client's IP address on the connection to the pod. The source IP on the packet that's delivered to the pod becomes the private IP of the node. To maintain the client's IP address, you must set `service.spec.externalTrafficPolicy` to `local` in the service definition. The following manifest shows an example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
  - port: 80
  selector:
    app: azure-vote-front
```

## Customizations via Kubernetes Annotations

The following annotations are supported for Kubernetes services with type `LoadBalancer`, and they only apply to **INBOUND** flows.

| Annotation                                                         | Value                               | Description                                                                                                                                                                                                  |
|--------------------------------------------------------------------|-------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `service.beta.kubernetes.io/azure-load-balancer-internal`          | `true` or `false`                   | Specify whether the load balancer should be internal. If not set, it defaults to public.                                                                                                                     |
| `service.beta.kubernetes.io/azure-load-balancer-internal-subnet`   | Name of the subnet                  | Specify which subnet the internal load balancer should be bound to. If not set, it defaults to the subnet configured in cloud config file.                                                                   |
| `service.beta.kubernetes.io/azure-dns-label-name`                  | Name of the DNS label on Public IPs | Specify the DNS label name for the **public** service. If it's set to an empty string, the DNS entry in the Public IP isn't used.                                                                            |
| `service.beta.kubernetes.io/azure-shared-securityrule`             | `true` or `false`                   | Specify exposing the service through a potentially shared Azure security rule to increase service exposure, utilizing Azure [Augmented Security Rules][augmented-security-rules] in Network Security groups. |
| `service.beta.kubernetes.io/azure-load-balancer-resource-group`    | Name of the resource group          | Specify the resource group of load balancer public IPs that aren't in the same resource group as the cluster infrastructure (node resource group).                                                           |
| `service.beta.kubernetes.io/azure-allowed-service-tags`            | List of allowed service tags        | Specify a list of allowed [service tags][service-tags] separated by commas.                                                                                                                                  |
| `service.beta.kubernetes.io/azure-allowed-ip-ranges`               | list of allowed IP ranges           | Specify a list of allowed IP ranges separated by comma.                                                                                                                                                      |
| `service.beta.kubernetes.io/azure-load-balancer-tcp-idle-timeout`  | TCP idle timeouts in minutes        | Specify the time in minutes for TCP connection idle timeouts to occur on the load balancer. The default and minimum value is 4. The maximum value is 30. The value must be an integer.                       |
| `service.beta.kubernetes.io/azure-load-balancer-disable-tcp-reset` | `true` or `false`                   | Specify whether the load balancer should disable TCP reset on idle timeout.                                                                                                                                  |
| `service.beta.kubernetes.io/azure-load-balancer-ipv4`              | IPv4 address                        | Specify the IPv4 address to assign to the load balancer.                                                                                                                                                     |
| `service.beta.kubernetes.io/azure-load-balancer-ipv6`              | IPv6 address                        | Specify the IPv6 address to assign to the load balancer.                                                                                                                                                     |

### Customize allowed IP ranges (preview)

You can use the `azure-allowed-service-tags` and `azure-allowed-ip-ranges` annotations to combine CIDR blocks and Azure service tags on the load balancer. Add `service.beta.kubernetes.io/azure-allowed-ip-ranges` with a comma-separated list of IP prefixes, and add `service.beta.kubernetes.io/azure-allowed-service-tags` with one or more Azure service tags. The AKS cloud provider merges both values into a single NSG rule, so traffic is filtered centrally at the NSG giving you a single, NSG-centric control plane for both IP addresses and service tags.

You can continue to use the `loadBalancerSourceRanges` property for cases where you want CIDR-based restrictions enforced both in the NSG and the host. You can't use this property with the `azure-allowed-service-tags` annotation. If both are specified, AKS reports an error when you try to apply the load balancer service specification.

### Customize the load balancer health probe

The following annotations are supported to customize the load balancer health probe behavior:

| Annotation | Value | Description |
|------------|-------|-------------|
| `service.beta.kubernetes.io/azure-load-balancer-health-probe-interval`     | Health probe interval                                     |                                                                                                                                                                                                                       |
| `service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe` | The minimum number of unhealthy responses of health probe |                                                                                                                                                                                                                       |
| `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path` | Request path of the health probe                          |                                                                                                                                                                                                                       |
| `service.beta.kubernetes.io/port_{port}_no_lb_rule`                        | true/false                                                | {port} is service port number. When set to true, no lb rule or health probe rule for this port is generated. Health check service should not be exposed to the public internet(e.g. istio/envoy health check service) |
| `service.beta.kubernetes.io/port_{port}_no_probe_rule`                     | true/false                                                | {port} is service port number. When set to true, no health probe rule for this port is generated.                                                                                                                     |
| `service.beta.kubernetes.io/port_{port}_health-probe_protocol`             | Health probe protocol                                     | {port} is service port number. Explicit protocol for the health probe for the service port {port}, overriding port.appProtocol if set.                                                                                |
| `service.beta.kubernetes.io/port_{port}_health-probe_port`                 | port number or port name in service manifest              | {port} is service port number. Explicit port for the health probe for the service port {port}, overriding the default value.                                                                                          |
| `service.beta.kubernetes.io/port_{port}_health-probe_interval`             | Health probe interval                                     | {port} is service port number.                                                                                                                                                                                        |
| `service.beta.kubernetes.io/port_{port}_health-probe_num-of-probe`         | The minimum number of unhealthy responses of health probe | {port} is service port number.                                                                                                                                                                                        |
| `service.beta.kubernetes.io/port_{port}_health-probe_request-path`         | Request path of the health probe                          | {port} is service port number.                                                                                                                                                                                        |

#### Default health probe behavior

Currently, the default protocol of the health probe varies among services with different transport protocols, app protocols, annotation, and external traffic policies.

- For local services, HTTP and /healthz would be used. The health probe will query `NodeHealthPort` rather than actual backend service.
- For cluster TCP services, TCP would be used.
- For cluster UDP services, no health probes.

> [!NOTE]
> For local services with PLS integration and PLS proxy protocol enabled, the default HTTP and /healthz health probe doesn't work. Thus health probe can be customized the same way as cluster services to support this scenario.

##### Health probe request path annotation

Starting in Kubernetes version 1.20, the service annotation `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path` was introduced to determine the health probe behavior.

- For clusters <=1.23, `spec.ports.appProtocol` would only be used as probe protocol when `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path` is also set.
- For clusters >1.24,  `spec.ports.appProtocol` would be used as probe protocol and `/` would be used as default probe request path (`service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path` could be used to change to a different request path).

Note that the request path would be ignored when using TCP or the `spec.ports.appProtocol` is empty. The following table summarizes the default health probe behavior:

| loadbalancer sku | `externalTrafficPolicy` | spec.ports.Protocol | spec.ports.AppProtocol | `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path` | LB Probe Protocol                 | LB Probe Request Path       |
|------------------|-------------------------|---------------------|------------------------|----------------------------------------------------------------------------|-----------------------------------|-----------------------------|
| standard         | local                   | any                 | any                    | any                                                                        | http                              | `/healthz`                  |
| standard         | cluster                 | udp                 | any                    | any                                                                        | null                              | null                        |
| standard         | cluster                 | tcp                 |                        | (ignored)                                                                  | tcp                               | null                        |
| standard         | cluster                 | tcp                 | tcp                    | (ignored)                                                                  | tcp                               | null                        |
| standard         | cluster                 | tcp                 | http/https             |                                                                            | TCP(<=1.23) or http/https(>=1.24) | null(<=1.23) or `/`(>=1.24) |
| standard         | cluster                 | tcp                 | http/https             | `/custom-path`                                                             | http/https                        | `/custom-path`              |
| standard         | cluster                 | tcp                 | unsupported protocol   | `/custom-path`                                                             | tcp                               | null                        |
| basic            | local                   | any                 | any                    | any                                                                        | http                              | `/healthz`                  |
| basic            | cluster                 | tcp                 |                        | (ignored)                                                                  | tcp                               | null                        |
| basic            | cluster                 | tcp                 | tcp                    | (ignored)                                                                  | tcp                               | null                        |
| basic            | cluster                 | tcp                 | http                   |                                                                            | TCP(<=1.23) or http/https(>=1.24) | null(<=1.23) or `/`(>=1.24) |
| basic            | cluster                 | tcp                 | http                   | `/custom-path`                                                             | http                              | `/custom-path`              |
| basic            | cluster                 | tcp                 | unsupported protocol   | `/custom-path`                                                             | tcp                               | null                        |

##### Health probe interval and number of probes annotations

Starting in Kubernetes version 1.21, two service annotations `service.beta.kubernetes.io/azure-load-balancer-health-probe-interval` and `load-balancer-health-probe-num-of-probe` were introduced, which customize the configuration of health probe. If `service.beta.kubernetes.io/azure-load-balancer-health-probe-interval` isn't set, a default value of _5_ is applied. If `load-balancer-health-probe-num-of-probe` isn't set, a default value of _2_ is applied.

### Custom Load Balancer health probe for port

Different ports in a service can require different health probe configurations. This could be because of service design (such as a single health endpoint controlling multiple ports), or Kubernetes features like the [MixedProtocolLBService](https://kubernetes.io/docs/concepts/services-networking/service/#load-balancers-with-mixed-protocol-types).

The following table summarizes the port specific annotations that can be used to override the global health probe annotations for a specific port in the service:

| port specific annotation                                         | global probe annotation                                                  | Usage                                                                        |
|------------------------------------------------------------------|--------------------------------------------------------------------------|------------------------------------------------------------------------------|
| service.beta.kubernetes.io/port_{port}_no_lb_rule                | N/A (no equivalent globally)                                             | if set true, no lb rules and probe rules will be generated                   |
| service.beta.kubernetes.io/port_{port}_no_probe_rule             | N/A (no equivalent globally)                                             | if set true, no probe rules will be generated                                |
| service.beta.kubernetes.io/port_{port}_health-probe_protocol     | N/A (no equivalent globally)                                             | Set the health probe protocol for this service port (e.g. Http, Https, Tcp)  |
| service.beta.kubernetes.io/port_{port}_health-probe_port         | N/A (no equivalent globally)                                             | Sets the health probe port for this service port (e.g. 15021)                |
| service.beta.kubernetes.io/port_{port}_health-probe_request-path | service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path | For Http or Https, sets the health probe request path. Defaults to /         |
| service.beta.kubernetes.io/port_{port}_health-probe_num-of-probe | service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe | Number of consecutive probe failures before the port is considered unhealthy |
| service.beta.kubernetes.io/port_{port}_health-probe_interval     | service.beta.kubernetes.io/azure-load-balancer-health-probe-interval     | The amount of time between probe attempts                                    |

<!--- LEFT OFF HERE!!! --->

## Troubleshooting SNAT

If you know that you're starting many outbound TCP or UDP connections to the same destination IP address and port, and you observe failing outbound connections or support notifies you that you're exhausting SNAT ports (preallocated ephemeral ports used by PAT), you have several general mitigation options. Review these options and decide what's best for your scenario. It's possible that one or more can help manage your scenario. For detailed information, review the [outbound connections troubleshooting guide](/azure/load-balancer/troubleshoot-outbound-connection).

The root cause of SNAT exhaustion is frequently an anti-pattern for how outbound connectivity is established, managed, or configurable timers changed from their default values. Review this section carefully.

### Steps

1. Check if your connections remain idle for a long time and rely on the default idle timeout for releasing that port. If so, the default timeout of 30 minutes might need to be reduced for your scenario.
2. Investigate how your application creates outbound connectivity (for example, code review or packet capture).
3. Determine if this activity is expected behavior or whether the application is misbehaving. Use [metrics](/azure/load-balancer/load-balancer-standard-diagnostics) and [logs](/azure/load-balancer/monitor-load-balancer) in Azure Monitor to substantiate your findings. For example, use the "Failed" category for SNAT connections metric.
4. Evaluate if appropriate [patterns](#design-patterns) are followed.
5. Evaluate if SNAT port exhaustion should be mitigated with [more outbound IP addresses + more allocated outbound ports](#configure-the-allocated-outbound-ports).

### Design patterns

Take advantage of connection reuse and connection pooling whenever possible. These patterns help you avoid resource exhaustion problems and result in predictable behavior. Primitives for these patterns can be found in many development libraries and frameworks.

* Atomic requests (one request per connection) generally aren't a good design choice. Such anti-patterns limit scale, reduce performance, and decrease reliability. Instead, reuse HTTP/S connections to reduce the numbers of connections and associated SNAT ports. The application scale increases and performance improves because of reduced handshakes, overhead, and cryptographic operation cost when using TLS.
* If you're using out of cluster/custom DNS, or custom upstream servers on coreDNS, keep in mind that DNS can introduce many individual flows at volume when the client isn't caching the DNS resolvers result. Make sure to customize coreDNS first instead of using custom DNS servers and to define a good caching value.
* UDP flows (for example, DNS lookups) allocate SNAT ports during the idle timeout. The longer the idle timeout, the higher the pressure on SNAT ports. Use short idle timeout (for example, 4 minutes).
* Use connection pools to shape your connection volume.
* Never silently abandon a TCP flow and rely on TCP timers to clean up flow. If you don't let TCP explicitly close the connection, state remains allocated at intermediate systems and endpoints, and it makes SNAT ports unavailable for other connections. This pattern can trigger application failures and SNAT exhaustion.
* Don't change OS-level TCP close related timer values without expert knowledge of impact. While the TCP stack recovers, your application performance can be negatively affected when the endpoints of a connection have mismatched expectations. Wishing to change timers is usually a sign of an underlying design problem. Review following recommendations.

## Shared health probes for `externalTrafficPolicy: Cluster` Services (preview)

In clusters that use `externalTrafficPolicy: Cluster`, Azure Load Balancer (SLB) currently creates a _separate probe per Service_ and targets each Service's `nodePort`.

This design means SLB infers node health from whichever **application pod** answers the probe. As clusters grow, this approach leads to several issues:

* **Configuration drift and blind spots**: SLB can't detect a failed or misconfigured `kube‑proxy` if iptables rules are still present.
* **Duplicate health logic**: Readiness must be defined twice. Once in each pod's `readinessProbe`, and again through SLB annotations.
* **Operational overhead**: Each Service on each node is probed every *five seconds*, consuming connections, SNAT ports, and SLB rule space.
* **Feature friction**: Customers can't set `allocateLoadBalancerNodePorts=false`, and workloads like Istio or ingress‑nginx require extra annotations to keep probes working.
* **Troubleshooting confusion**: An unhealthy app, Network Policy rule, or scale‑to‑zero event can make an *entire node* appear down.

The **shared probe mode** (preview) solves these problems by moving to a *single HTTP probe* for all `externalTrafficPolicy: Cluster` Services:

* SLB probes `http://<node‑ip>:10356/healthz`, the standard `kube‑proxy` health endpoint.
* A lightweight sidecar runs next to `kube‑proxy` to relay the probe and handle PROXY protocol when Private Link Service is enabled.

The following table outlines **key benefits** of using shared probe mode:

| Benefit                | Why it matters                                                            |
|------------------------|---------------------------------------------------------------------------|
| Accurate node health   | SLB now measures `kube‑proxy` directly, not an arbitrary backend pod.     |
| Simpler configuration  | No per‑Service probe annotations; readiness lives solely in the pod spec. |
| Lower traffic overhead | One probe per node instead of *Services × (nodes – 1)* probes.            |

> [!NOTE]
> * Services that use `externalTrafficPolicy: Local` are **unchanged**.*
> This feature does **not** address container‑native load balancing.

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

### Register the `EnableSLBSharedHealthProbePreview` feature flag

1. Register the `EnableSLBSharedHealthProbePreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "EnableSLBSharedHealthProbePreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EnableSLBSharedHealthProbePreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Create a new cluster with shared probe mode\

Create a new cluster with shared probe mode using the following [`az aks create`](/cli/azure/aks#az-aks-create) command:

```azurecli-interactive
az aks create \
  --resource-group <rg> \
  --name <cluster> \
  --cluster-service-load-balancer-health-probe-mode shared
```

### Enable shared probe mode on an existing cluster

Enable shared probe mode on an existing cluster using the following [`az aks update`](/cli/azure/aks#az-aks-update) command:

```azurecli-interactive
az aks update \
  --resource-group <rg> \
  --name <cluster> \
  --cluster-service-load-balancer-health-probe-mode shared
```


## Moving from a *Basic* SKU load balancer to *Standard* SKU

If you have an existing cluster with the *Basic* SKU load balancer, there are important behavioral differences to note when migrating to the *Standard* SKU load balancer.

For example, making blue/green deployments to migrate clusters is a common practice given the `load-balancer-sku` type of a cluster and can only be defined at cluster create time. However, *Basic* SKU load balancers use *Basic* SKU IP addresses, which aren't compatible with *Standard* SKU load balancers. *Standard* SKU load balancers require *Standard* SKU IP addresses. When migrating clusters to upgrade load balancer SKUs, a new IP address with a compatible IP address SKU is required.

For more considerations on how to migrate clusters, visit [our documentation on migration considerations](aks-migration.md).

>[!Important]
>On September 30, 2025, Basic Load Balancer will be retired. For more information, see the [official announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you are currently using the Basic Load Balancer, make sure to upgrade to Standard Load Balancer prior to the retirement date. For more information on how to upgrade your Basic load balancer on AKS, see our [documentation on Basic load balancer migration][upgrade-blb-on-aks] .


## Next steps

To learn more about Kubernetes services, see the [Kubernetes services documentation][kubernetes-services].

To learn more about using internal load balancer for inbound traffic, see the [AKS internal load balancer documentation](internal-lb.md).

<!-- LINKS - External -->
[kubectl]: https://kubernetes.io/docs/user-guide/kubectl/
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubernetes-services]: https://kubernetes.io/docs/concepts/services-networking/service/
[lb-annotations]: https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/#loadbalancer-annotations

<!-- LINKS - Internal -->
[advanced-networking]: configure-azure-cni.md
[aks-support-policies]: support-policies.md
[aks-faq]: faq.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[aks-sp]: kubernetes-service-principal.md#delegate-access-to-other-azure-resources
[augmented-security-rules]: /azure/virtual-network/network-security-groups-overview#augmented-security-rules
[az-aks-show]: /cli/azure/aks#az_aks_show
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-aks-install-cli]: /cli/azure/aks#az_aks_install_cli
[az-extension-add]: /cli/azure/extension#az_extension_add
[az-feature-list]: /cli/azure/feature#az_feature_list
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-group-create]: /cli/azure/group#az_group_create
[az-provider-register]: /cli/azure/provider#az_provider_register
[az-network-lb-outbound-rule-list]: /cli/azure/network/lb/outbound-rule#az_network_lb_outbound_rule_list
[az-network-public-ip-show]: /cli/azure/network/public-ip#az_network_public_ip_show
[az-network-public-ip-prefix-show]: /cli/azure/network/public-ip/prefix#az_network_public_ip_prefix_show
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[azure-lb]: /azure/load-balancer/load-balancer-overview#securebydefault
[azure-lb-comparison]: /azure/load-balancer/skus
[azure-lb-outbound-rules]: /azure/load-balancer/load-balancer-outbound-connections#outboundrules
[azure-lb-outbound-connections]: /azure/load-balancer/load-balancer-outbound-connections
[azure-lb-outbound-preallocatedports]: /azure/load-balancer/load-balancer-outbound-connections#preallocatedports
[azure-lb-outbound-rules-overview]: /azure/load-balancer/load-balancer-outbound-connections#outboundrules
[install-azure-cli]: /cli/azure/install-azure-cli
[internal-lb-yaml]: internal-lb.md#create-an-internal-load-balancer
[kubernetes-concepts]: concepts-clusters-workloads.md
[use-kubenet]: configure-kubenet.md
[az-extension-add]: /cli/azure/extension#az_extension_add
[az-extension-update]: /cli/azure/extension#az_extension_update
[use-multiple-node-pools]: use-multiple-node-pools.md
[upgrade-blb-on-aks]: upgrade-basic-load-balancer-on-aks.md
[troubleshoot-snat]: #troubleshooting-snat
[service-tags]: /azure/virtual-network/network-security-groups-overview#service-tags
[maxcount]: ./cluster-autoscaler.md#enable-the-cluster-autoscaler-on-an-existing-cluster
[maxsurge]: ./upgrade-aks-cluster.md#customize-node-surge-upgrade
[az-lb]: /azure/load-balancer/load-balancer-overview
[alb-outbound-rules]: /azure/load-balancer/outbound-rules
