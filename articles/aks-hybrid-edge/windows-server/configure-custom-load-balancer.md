---
title: Create and use a custom load balancer with Azure Kubernetes Service on Windows Server
description: Learn how to create and use a custom load balancer with Azure Kubernetes Service on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: rbaziwane
ms.custom: windows-server

# Intent: As an IT Pro, I need to create a custom load balancer and use it to send requests to the Kubernetes API server.
# Keyword: custom load balancer

---

# Create and use a custom load balancer in Azure Kubernetes Service on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to create and use a custom load balancer. In Azure Kubernetes Service (AKS) on Windows Server, you can use load balancers to send requests to the Kubernetes API server and to manage traffic to application services. When you use a custom load balancer, [kube-vip](https://kube-vip.io/) automatically deploys to manage the load balancing of requests to the Kubernetes API server and to make sure that it's highly available.

> [!NOTE]
> You can also use a other load balancers, such as MetalLB or Software Defined Networking (SDN) load balancing, to load balance traffic to application services.  

## Before you begin

You must install [AKS on Windows Server](kubernetes-walkthrough-powershell.md) and provide a range of virtual IP addresses for the load balancer during the network configuration step during installation.

## Configure a custom load balancer

> [!WARNING]
> If you choose to deploy your own load balancer, the Kubernetes cluster becomes unreachable after installation. If you deploy any services with `type=LoadBalancer`, the services are also unreachable until you configure your load balancer.

This configuration assumes you want to use a custom load balancer in your cluster. In this case, the workload cluster is deployed without a load balancer:

1. Create a load balancer configuration using the [New-AksHciLoadBalancerSetting](/azure/aks/aksarc/reference/ps/new-akshciloadbalancersetting) cmdlet and then select `none` for the `loadBalancerSku` parameter:

   ```powershell
   $lbCfg=New-AksHciLoadBalancerSetting -name "myLb" -loadBalancerSku "none" 
   ```

1. Deploy a workload cluster without providing the load balancer configuration using the following command:

   ```powershell
   New-AksHciCluster -name "summertime" -nodePoolName mynodepool -nodeCount 2 -OSType linux -nodeVmSize Standard_A4_v2 -loadBalancerSettings $lbCfg 
   ```

1. Use [Get-AksHciCluster](/azure/aks/aksarc/reference/ps/get-akshcicluster) to verify that the cluster is successfully deployed with the control plane nodes running `kube-vip` and that the API server requests are reachable.

1. Manually configure your load balancer.  

If you run an upgrade, the load balancer configuration (`loadBalancerSku` and `count`) you defined during installation remains the same after the upgrade completes. However, if you want to update `loadBalancerSku` during an upgrade, you must redeploy your workload clusters. If you have existing clusters running a HAProxy-based load balancer, you can continue running your workloads. The upgrade then completes successfully.

> [!IMPORTANT]
> If you change from using a custom load balancer to using the default load balancer, you're required to redeploy your workload cluster with the new load balancer configuration. For information about how to configure the default load balancer, see [Configure load balancer](configure-load-balancer.md).  

## Next steps

To learn more about Kubernetes services, see the [Kubernetes services documentation](https://kubernetes.io/docs/concepts/services-networking/service/).
