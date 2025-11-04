---
title: Use a Public Standard Load Balancer in Azure Kubernetes Service (AKS)
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

## Create a load balancer service in AKS

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

## Specify the load balancer IP address

If you want to use a specific IP address with the load balancer, you have two options to specify the IP address:

- **Set service annotations** (recommended): Use `service.beta.kubernetes.io/azure-load-balancer-ipv4` for an IPv4 address and `service.beta.kubernetes.io/azure-load-balancer-ipv6` for an IPv6 address.
- **Add the _LoadBalancerIP_ property to the load balancer YAML manifest**: Add the `Service.Spec.LoadBalancerIP` property to the load balancer YAML manifest. This field is deprecating following [upstream Kubernetes](https://github.com/kubernetes/kubernetes/pull/107235), and it can't support dual-stack. Current usage remains the same and existing services are expected to work without modification.

## Deploy the load balancer service manifest

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

## Next step

> [!div class="nextstepaction"]
> [Configure your public standard load balancer in AKS](configure-load-balancer-standard.md)

<!-- LINKS - External -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[lb-annotations]: https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/#loadbalancer-annotations

<!-- LINKS - Internal -->
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[azure-lb]: /azure/load-balancer/load-balancer-overview#securebydefault
[azure-lb-comparison]: /azure/load-balancer/skus
[az-lb]: /azure/load-balancer/load-balancer-overview
