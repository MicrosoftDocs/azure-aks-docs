---
title: Migrate from Network Policy Manager (NPM) to Cilium Network Policy  
description: This article is a comprehensive guide to plan, execute, and validate the migration from Network Policy Manager (NPM) to Cilium Network Policy
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/30/2025
author: josephyostos
ms.author: josephyostos
---

# Migrate from Network Policy Manager (NPM) to Cilium Network Policy 

In this article, we provide a comprehensive guide to plan, execute, and validate the migration from Network Policy Manager (NPM) to Cilium Network Policy. The goal is to ensure policy parity, minimize service disruption, and align with Azure CNI's strategic direction toward eBPF-based networking and enhanced observability.

> [!IMPORTANT]
> This guide applies exclusively to AKS clusters running Linux nodes. Cilium Network Policy isn't currently supported for Windows nodes in AKS.  

## Key considerations before you begin

- Policy Compatibility: NPM and Cilium differ in enforcement models. Before migration you need to validate that existing policies are compatible or identify required changes. Refer to the Pre-Migration Validation section for guidance.
- Downtime Expectations: Policy enforcement might be temporarily inconsistent during node reimaging.
- Windows Node Pools: Cilium Network Policy isn't currently supported for Windows nodes in AKS. 

## Pre-migration validation 

Before migrating from Network Policy Manager (NPM) to Cilium Network Policy, it's important to assess the compatibility of your existing network policies. While most policies continue to function as expected post-migration, there are specific scenarios where behavior might differ between NPM and Cilium. These differences could require updates to your policies either before or after the migration to ensure consistent enforcement and avoid unintended traffic drops.
In this section, we outline known scenarios where policy adjustments might be necessary. We explain why it matters, and provide guidance on what actions—if any—are required to make your policies Cilium-compatible.

### NetworkPolicy with endPort

> [!NOTE]
> Cilium started supporting the `endPort` field in Kubernetes NetworkPolicy in version 1.17.

The endPort field allows you to define a range of ports in a single rule, rather than specifying individual ports. 

Here's an example of a Kubernetes NetworkPolicy that uses the endPort field:
```
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/24
      ports:
        - protocol: TCP
          port: 32000
          endPort: 32768
```

**Action Required:**  
- If your AKS cluster is running Cilium version 1.17 or later, no changes are needed as endPort is fully supported.
- If your cluster is running a Cilium version earlier than 1.17, remove the endPort field from any policies before migrating. Use explicit single-port entries instead.

### NetworkPolicy with ipBlock

The ipBlock field in Kubernetes NetworkPolicy allows you to define CIDR ranges for ingress sources or egress destinations. These ranges can include external IPs, Pod IPs, or Node IPs. However, Cilium doesn't allow egress to Pod or Node IPs using ipBlock, even if those IPs fall within the specified CIDR range. 

For example, the following NetworkPolicy uses an ipBlock to allow all egress traffic to 0.0.0.0/0:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-ipblock
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
      - ipBlock:
          cidr: 0.0.0.0/0 
```

- Under NPM, this policy would allow egress to all destinations, including Pods and Nodes. 
- After migrating to Cilium, egress to Pod and Node IPs will be blocked, even though they fall within the 0.0.0.0/0 range.

**Action Required:** 

- To allow traffic to Pod IPs, before migration replace the ipBlock with a combination of namespaceSelector and podSelector.

Here's an example of using namespaceSelector and podSelector:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-ipblock
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
      - ipBlock:
          cidr: 0.0.0.0/0
      - namespaceSelector: {}
      - podSelector: {}
```
- For Node IPs, there's no pre-migration workaround. After migration, you must create a CiliumNetworkPolicy that explicitly allows egress to the host and/or remote-node entities. Until this policy is in place, egress traffic to Node IPs is blocked. 

Here's an example of CiliumNetworkPolicy to allow traffic from/to local and remote nodes:

```
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-node-egress
  namespace: ipblock-test
spec:
  endpointSelector: {}  # Applies to all pods in the namespace
  egress:
     - toEntities:
          - host # host allows traffic from/to the local node's host network namespace
          - remote-node # remote-node allows traffic from/to the remote node's host network namespace
```

### NetworkPolicy with named Ports

Kubernetes NetworkPolicy allows you to reference ports by name instead of number. If you're using named ports in your NetworkPolicies, Cilium might fail to enforce rules correctly and lead to unexpected traffic being blocked. This issue happens when the same port name is used for different ports.
For more information, see [Cilium GitHub issue #30003](https://github.com/cilium/cilium/issues/30003).

Here's an example of NetworkPolicy uses Named port to allow egress traffic:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  annotations:
  name: allow-egress
  namespace: default
spec:
  podSelector:
    matchLabels:
      network-rules-egress: cilium-np-test
  egress:
  - ports:
    - port: http-test # Named port
      protocol: TCP
  policyTypes:
  - Egress
```

**Action Required:** 
- Before migration, replace all named ports in your policies with their corresponding numeric values.

### NetworkPolicy with Egress Policies 

Kubernetes NetworkPolicy on NPM doesn't block egress traffic from a pod to its own node's IP, this traffic is implicitly allowed. After you migrate to Cilium, this behavior will change, and traffic to local nodes that was previously allowed will be blocked unless explicitly allowed.

For example, the following policy allows egress only to an internal API subnet:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress 
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
      - ipBlock:
          cidr: 10.20.30.0/24
```
- With NPM: Egress traffic to 10.20.30.0/24 is allowed explicitly, and egress traffic to the local node is allowed implicitly.
- With Cilium: Only traffic to 10.20.30.0/24 is allowed; egress to the node IP is blocked unless you permit it explicitly.

**Action Required:** 
- Review all existing egress policies for your workloads.
- If your applications rely on NPM's implicit allow behavior for egress to the local node, you must add explicit egress rules to maintain connectivity after migration.
- You can add a CiliumNetworkPolicy after migration to explicitly allow egress traffic to the local host. 

### Ingress policy behavior changes

Under Network Policy Manager (NPM), ingress traffic arriving via a LoadBalancer or NodePort service with "externalTrafficPolicy=Cluster" - which is the default setting - isn't subject to ingress policy enforcement. This behavior means that even if a pod has a restrictive ingress policy, traffic from external sources might still reach it via loadbalancer or nodeport services.

In contrast, Cilium enforces ingress policies on all traffic, including traffic routed internally due to externalTrafficPolicy=Cluster. As a result, after migration, traffic that was previously allowed might be dropped if the appropriate ingress rules aren't explicitly defined.

For example, Customer creates a network policy to deny all in ingress traffic 

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```
- With NPM:  Direct connection to the pod or via ClusterIP service is blocked. However, access through NodePort or LoadBalancer is still allowed despite the deny-all policy.
- With Cilium: All ingress traffic is blocked, including traffic via NodePort or LoadBalancer, unless explicitly allowed.

**Action Required:** 

- Review all ingress policies for workloads behind LoadBalancer or NodePort services using externalTrafficPolicy=Cluster.
- Ensure that ingress rules explicitly allow traffic from the expected external sources (for example, IP ranges, namespaces, or labels).
- If your policy currently relies on the implicit allow behavior under NPM, you must add explicit ingress rules to maintain connectivity after migration.

## Upgrade to Azure CNI Powered by Cilium

To use Cilium Network Policy, your AKS cluster must be running Azure CNI powered by Cilium. When you enable Cilium in a cluster currently using NPM, the existing NPM engine is automatically uninstalled and replaced with Cilium.

> [!Warning]
> The upgrade process triggers each node pool to be reimaged simultaneously. Upgrading each node pool separately isn't supported. Any disruptions to cluster networking are similar to a node image upgrade or [Kubernetes version upgrade](upgrade-cluster.md) where each node in a node pool is reimaged. Cilium will begin enforcing network policies only after all nodes are reimaged.

> [!IMPORTANT]
> These instructions apply to clusters upgrading from Azure CNI to Azure CNI with the Cilium dataplane. Upgrades from bring-your-own CNIs or changes the IPAM mode aren't covered here. For more information, see [Upgrade Azure CNI documentation](update-azure-cni.md).

To perform the upgrade, you need Azure CLI version 2.52.0 or later. Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

Use the following command to upgrade an existing cluster to Azure CNI Powered by Cilium. Replace the values for `clusterName` and `resourceGroupName`:
```
az aks update --name <clusterName> --resource-group <resourceGroupName> --network-dataplane cilium
```

## Next steps


- For more information about using Cilium FQDN network policy on AKS, see [Set up FQDN filtering feature for Container Network Security in Advanced Container Networking Services](how-to-apply-fqdn-filtering-policies.md).

- For more information about using Cilium L7 network policy on AKS, see [Set up Layer 7(L7) policies with Advanced Container Networking Services](how-to-apply-l7-policies.md).

- For more information about network policy best practices on aks, see [Best practices for network policies in Azure Kubernetes Service (AKS)](network-policy-best-practices.md)

