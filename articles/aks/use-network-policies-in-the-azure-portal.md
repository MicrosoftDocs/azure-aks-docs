---
title: Use Network Policies for Azure Kubernetes Service (AKS) Clusters in the Azure Portal
description: In this article, you learn how to create and manage network policies for AKS clusters in the Azure portal.
author: sasper0ni
ms.author: mirandawu
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 10/10/2025
# Customer intent: As a DevOps engineer, I want to easily implement and manage network policies in Azure Kubernetes Service through the Azure Portal so that I can easily secure pod traffic and understand the impact of existing policies.
---

# Use network policies for Azure Kubernetes Service (AKS) clusters in the Azure portal

Kubernetes network policies are essential for controlling component-level communication in many modern, microservices-based applications. This article shows you how to create and manage network policies for AKS clusters directly in the Azure Portal.

For more information on network policies, you can visit the [Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource) or review the [Best practices for network policies in Azure Kubernetes Service (AKS)](./network-policy-best-practices.md).
## Prerequisites

- An AKS cluster with a network policy engine installed. If you don't have one, see [Enable a network policy engine on an Azure Kubernetes Service (AKS) cluster](./use-network-policies.md).

    To confirm whether your cluster has a managed network policy engine installed, go to the Azure portal and navigate to your AKS cluster resource. From the service menu, select **Networking**. Under the **Network profile**, verify you have a **Network policy engine**. For example:

    :::image type="content" source="media/use-network-policies-in-the-azure-portal/network-policy-engine.png" alt-text="A screenshot of Azure portal configuration showing Cilium network policy engine enabled":::

## Create a network policy

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Kubernetes resources**, select **Network policies**.
1. Select **+ Create** > **Network policy**.

### Define a policy scope

- On the **Create a network policy** page, update the following fields:

    - Name
    - Namespace
    - Pod selector

    :::image type="content" source="media/use-network-policies-in-the-azure-portal/create-policy-scope.png" alt-text="Screenshot showing the required fields to define network policy scope during the policy create process in Azure portal.":::

    This network policy affects any traffic to or from pods that fall under specified pod selectors in your namespace. If you don't provide a selector, all pods in the specified namespace fall under your policy scope. Your network policy resource is also created in this namespace.

### Add policy rules

> [!NOTE]
> If you don't add any rules before creating your network policy, Kubernetes automatically denies all ingress traffic to pods in your policy scope. 

1. On the **Create a network policy** page, under **Policy rules**, select **+ Add rule**.
1. On the **Add rule** page, select your **Rule type** and **Rule preset**. Each rule can apply to ingress or egress traffic. To control both ingress and egress traffic in one policy, you can add multiple rules. You can also apply rule presets to allow or deny all ingress or egress traffic. For more granular control, you can select **Allow custom traffic**.

    :::image type="content" source="media/use-network-policies-in-the-azure-portal/add-rule-type-and-preset.png" alt-text="Screenshot showing options to set a rule type and preset during the network policy create process in Azure portal.":::

### Add allowed sources or destinations

1. On the **Add rule** page, select either **+ Add allowed source** or **+ Add allowed destination** depending on your rule type (ingress or egress).
1. Select one of the following options for an allowed source or destination for Kubernetes network policies:

    - Allow traffic from the same namespace
    - Allow traffic from other namespaces within the cluster
    - Allow traffic from IP blocks outside the cluster

        :::image type="content" source="media/use-network-policies-in-the-azure-portal/ingress-rule.png" alt-text="Screenshot showing available allowed sources for ingress rules.":::

    > [!IMPORTANT]
    > We don't recommend identifying pods using pod IP addresses as these IP addresses are ephemeral in nature. Instead, use pod selectors and/or namespace selectors to specify targeted pods.

    > [!NOTE]
    > If you select **Allow custom traffic** without specifying any allowed sources or destinations, Kubernetes interprets this rule as _denying all traffic_ for your selected rule type (ingress/egress).

1. Configure settings for the allowed source or destination option you selected:

    - To target _specific pods_, you can apply a pod selector with the appropriate key-value identifiers. If this pod selector is left blank or you select **Allow all pods**, all pods in specified namespaces are targeted. 
    - To target _other namespaces in the cluster_, you can apply a namespace selector and pod selector that function independently to select specific combinations of namespaces and pods. To target all pods in all namespaces, select **Allow traffic from other namespaces within the cluster**, **Allow all namespaces**, and **Allow all pods**.
    - To _allow traffic from or to external IP addresses_, you can specify a specific IP block or CIDR with optional excluded addresses or ranges. Similarly to the pod and namespace selectors, if the CIDR field is left blank, all external IP addresses are allowed.

    > [!IMPORTANT]
    > Any selector fields left blank under a source or destination allow traffic to or from all entities of this type (IP addresses, namespaces, pods, etc.). To prevent unintentionally allowing any traffic, delete any sources or destinations that shouldn't be allowed.

### Specify allowed ports

1. On the **Add rule** page, under **Ports**, the **Allow all ports** option is selected by default. This setting permits traffic on all ports. If you want to specify which ports can receive or send traffic, deselect **Allow all ports**, select a **Protocol**, and _optionally_ enter a **Port or port range**. 

    > [!IMPORTANT]
    > When restricting outbound egress communication, make sure that all Azure or AKS required traffic is explicitly allowed. These requirements might differ based on your cluster configurations. For more information, see [Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters](./outbound-rules-control-egress.md).

1. Select **Add**.

## Manage network policies

Once you create your network policy, you can view your existing policies by selecting **Network policies** from the service menu. From here, you can create another network policy, delete network policies, or view more details about your network policy resources by selecting the policy.

    :::image type="content" source="media/use-network-policies-in-the-azure-portal/manage-network-policies.png" alt-text="Screenshot showing a network policy in the AKS resource grid in the Azure portal.":::

## Frequently asked questions (FAQ)

### What happens if I have multiple policies enabled that allow different traffic streams? Does one policy override another?

Kubernetes network policies are additive in effect. For example, if one policy allows ingress from pods in namespace A, and another policy allows ingress from pods in namespace B, ingress from pods in both namespaces A and B is allowed. As long as the traffic is permitted by at least one policy, it's allowed.

### Are CiliumNetworkPolicy or CiliumClusterWideNetworkPolicy resources supported?

At this time, the Azure portal only supports KubernetesNetworkPolicy creation and management: Layer 3 and Layer 4 policy control. To learn more about advanced container network security for AKS, see [What is Container Network Security?](./container-network-security-concepts.md)

### What happens if I create a network policy without a network policy engine installed?

You can create network policies without a network policy engine on your AKS cluster. However, these policies aren't enforced until you install a network policy engine. For more infomration, see [Secure traffic between pods using network policies in Azure Kubernetes Service (AKS)](./use-network-policies.md).

## Related content

- [Learn more about network policy best practices](./network-policy-best-practices.md)

