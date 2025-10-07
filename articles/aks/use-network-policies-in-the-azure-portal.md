---
title: Use network policies in the Azure Portal
description: In this article, you learn how to create and manage network policies for Kubernetes clusters directly in the Azure Portal.
author: sasper0ni
ms.author: mirandawu
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to #Required; leave this attribute/value as-is
ms.date: 10/10/2025

#CustomerIntent: As a DevOps engineer, I want to easily implement and manage network policies in Azure Kubernetes Service through the Azure Portal so that I can easily secure pod traffic and understand the impact of existing policies.
---
# Use network policies in the Azure Portal


Kubernetes network policies are essential for controlling component-level communication in many modern, microservices-based applications. To learn more about network policies and best practices, you can visit the [Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource) or start with [this guide](./network-policy-best-practices.md) to network policies on Azure Kubernetes Service (AKS).
This article discusses how to create and manage network policies for Kubernetes clusters directly in the Azure Portal.


## Prerequisites

You need an AKS cluster with a network policy engine installed (otherwise, [follow these steps to create your cluster and enable a network policy engine](./use-network-policies.md)). To confirm whether your cluster has a managed network policy engine installed, visit the Azure Portal and select your cluster. Select the Networking menu item and verify that "Network policy engine" is not none.

:::image type="content" source="media/use-network-policies-in-the-azure-portal/network-policy-engine.png" alt-text="A screenshot of Azure Portal configurations showing Cilium network policy engine enabled":::

## Create a network policy
From the Azure Kubernetes Service menu, select Network policies. Select "Create" at the top of the page. 

#### Define a policy scope

On this page, configure the following options to define your policy scope:
- Name
- Namespace
- Pod selector

This network policy will affect any traffic to or from pods that fall under specified pod selectors in your namespace. If you don't provide a selector, all pods in the specified namespace fall under your policy scope. Your network policy resource is also created in this namespace.

:::image type="content" source="media/use-network-policies-in-the-azure-portal/create-policy-scope.png" alt-text="Screenshot showing the required fields to define network policy scope during the policy create process in Azure Portal":::

#### Add policy rules


To specify allowed traffic, select "Add rule" under Policy rules. Once this policy is created, any other traffic that does not satisfy these rules will be blocked.

> [!NOTE]
> If you don't add any rules before creating your network policy, Kubernetes automatically denies all ingress traffic to pods in your policy scope. 

Each rule can apply to ingress or egress traffic. To control both ingress and egress traffic in one policy, you can add multiple rules. At this stage, you can also apply rule presets to allow or deny all ingress or egress traffic. For more granular control, continue with the "Allow custom traffic" selection.

:::image type="content" source="media/use-network-policies-in-the-azure-portal/add-rule-type-and-preset.png" alt-text="Screenshot showing options to set a rule type and preset during the network policy create process in Azure Portal":::

#### Add allowed sources or destinations

To specify which sources or destinations can send or receive traffic to pods in your policy scope, select "Add allowed source" or "Add allowed destination" depending on your rule type (ingress or egress)

There are three categories of allowed sources or destinations for Kubernetes network policies:

- Pods in the same namespace
- Pods in other namespaces within the cluster
- IP blocks outside the cluster 

> [!IMPORTANT]
> We don't recommend identifying pods using pod IP addresses as these IP addresses are ephemeral in nature. Instead, use pod selectors and/or namespace selectors to specify targeted pods.

> [!NOTE]
> If you select "Allow custom traffic" without specifying any allowed sources or destinations, Kubernetes interprets this rule as denying all traffic for your selected rule type (ingress/egress).

:::image type="content" source="media/use-network-policies-in-the-azure-portal/ingress-rule.png" alt-text="Screenshot showing available allowed sources for ingress rules":::

To target specific pods, you can apply a pod selector with the appropriate key-value identifiers. If this pod selector is left blank or you select the "Allow all pods" checkbox, all pods in specified namespaces are targeted. 

To target other namespaces in the cluster, you can apply a namespace selector and pod selector that function independently to select specific combinations of namespaces and pods. To target all pods in all namespaces, select the "Allow traffic from other namespaces within the cluster" option, select "Allow all namespaces," and select "Allow all pods."

To allow traffic from or to external IP addresses, you may specify a specific IP block or CIDR with optional excluded addresses or ranges. Similarly to the pod and namespace selectors, if the CIDR field is left blank, all external IP addresses are allowed.

> [!IMPORTANT]
> Any selector fields left blank under a source or destination allow traffic to or from all entities of this type (IP addresses, namespaces, pods, etc.). To prevent unintentionally allowing any traffic, delete any sources or destinations that shouldn't be allowed.

:::image type="content" source="media/use-network-policies-in-the-azure-portal/ingress-rule.png" alt-text="Screenshot showing the different ways to specify allowed traffic in a network policy rule":::

#### Specify allowed ports

By default, any rules added apply to all traffic on all ports. To specify which ports can receive or send traffic, uncheck the "Allow all ports" checkbox, select a protocol, and optionally enter a port or port range. 

> [!IMPORTANT]
> When restricting outbound egress communication, make sure that all Azure or AKS required traffic is explicitly allowed. These requirements may differ based on your cluster configurations; visit [this link to learn more](./outbound-rules-control-egress.md).

## Manage network policies

Once your network policy is created, you can view your existing network policies in the grid under the Network policies service menu. You can create another network policy, delete your network policy, or view more details about your network policy resource by clicking on the resource name.

:::image type="content" source="media/use-network-policies-in-the-azure-portal/manage-network-policies.png" alt-text="Screenshot showing a network policy in the AKS Portal resource grid":::


## Frequently asked questions

##### What happens if I have multiple policies enabled that allow different traffic streams? Does one policy override another?

Kubernetes network policies are additive in effect. For example, if one policy allows ingress from pods in namespace A, and another policy allows ingress from pods in namespace B, ingress from pods in both namespaces A and B is allowed. As long as the traffic is permitted by at least one policy, it is allowed.

##### Are CiliumNetworkPolicy or CiliumClusterWideNetworkPolicy resources supported?

At this time, the Azure Portal only supports KubernetesNetworkPolicy creation and management; that is, Layer 3 and Layer 4 policy control. To learn more about advanced container network security for AKS, visit [this link](https://docs.azure.cn/en-us/aks/container-network-security-concepts).

##### What happens if I create a network policy without a network policy engine installed?

You can create network policies without a network policy engine on your AKS cluster; however, these policies aren't enforced until a network policy engine is installed. To learn more about enabling a network policy engine on your AKS cluster, visit [this link](./use-network-policies.md).

## Related content

- [Learn more about network policy best practices](./network-policy-best-practices.md)

