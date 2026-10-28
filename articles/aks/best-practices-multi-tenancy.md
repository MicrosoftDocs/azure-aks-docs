---
title: Multi-Tenancy Best Practices in Azure Kubernetes Service (AKS)
description: Implementation best practices for multi-tenancy in AKS, including namespace isolation, Kubernetes RBAC with Microsoft Entra ID, ACNS Cilium network policies, resource quotas, pod security admission, node pool isolation, and Azure Monitor.
ms.topic: best-practice
ms.date: 07/24/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Best practices: Implement multi-tenancy in Azure Kubernetes Service (AKS)

This guide provides practitioner-grade implementation steps for configuring Kubernetes for multi-tenancy on Azure Kubernetes Service (AKS). It builds directly upon the isolation spectrum and primitives defined in [Concepts: Multi-tenancy in AKS](./concepts-multi-tenancy.md).

## Prerequisites

Before implementing the configurations in this guide, ensure you have:

- Azure CLI version 2.53.0 or later installed and configured. To check your version, run `az version`. To install or update, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- Azure permissions to create AKS clusters and Kubernetes objects in the cluster (for example, `Owner` or `Contributor` on the resource group plus sufficient Kubernetes authorization to create namespaces, roles, and role bindings).
- An understanding of the multi-tenancy primitives defined in the [Concepts overview](./concepts-multi-tenancy.md).

## Baseline cluster creation

To support modern multitenancy, your cluster must be provisioned with the correct network plugin and data plane. The following [`az aks create`](/cli/azure/aks#az-aks-create) command establishes a baseline cluster with Azure CNI Overlay and ACNS Cilium enabled for advanced network isolation.

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myMultiTenantCluster \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --enable-managed-identity \
    --enable-aad \
    --generate-ssh-keys
```

---

## 1. Managed namespaces

**Problem**: By default, all workloads deploy into the `default` namespace, leading to naming collisions, lack of access boundaries, and shared blast radii.

**Solution**: Create dedicated namespaces for each tenant. Use labels to identify tenant ownership for billing and policy enforcement.

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a-production
  labels:
    tenant: "tenant-a"
    environment: "production"
    pod-security.kubernetes.io/enforce: "restricted"
```

> **AKS advantage**: AKS integrates namespace labels directly with Azure Policy and Azure Monitor, allowing you to filter compliance states and telemetry by tenant without extra tooling.

**Verify isolation**:

```bash
kubectl get namespaces --show-labels
```

---

## 2. Kubernetes RBAC with Microsoft Entra ID

**Problem**: Tenants need access to deploy and manage their applications, but providing cluster-wide admin access compromises the entire environment.

**Solution**: Bind Microsoft Entra ID groups to specific namespaces using Kubernetes `Role` and `RoleBinding` manifests.

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: tenant-a-production
  name: tenant-a-developer-role
rules:
- apiGroups: ["", "apps", "autoscaling"]
  resources: ["pods", "services", "deployments", "replicasets", "horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-a-developer-binding
  namespace: tenant-a-production
subjects:
- kind: Group
  name: "00000000-0000-0000-0000-000000000000" # Microsoft Entra ID Group Object ID
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: tenant-a-developer-role
  apiGroup: rbac.authorization.k8s.io
```

> **AKS advantage**: By integrating Kubernetes RBAC with Microsoft Entra ID identities, you avoid managing local user accounts in the cluster and can centralize user lifecycle operations in Microsoft Entra.

**Verify isolation**:

Sign in with a user that is a member of the tenant group, then run:

```bash
kubectl auth can-i create deployments --namespace tenant-a-production
```

---

## 3. ACNS Cilium network policies

**Problem**: Kubernetes allows all pods to communicate with each other by default. A compromised pod in Tenant A's namespace could probe or attack Tenant B's workloads.

**Solution**: Implement a tenant namespace isolation policy using ACNS Cilium to allow tenant workloads to communicate only with workloads in the same namespace unless explicitly allowed by additional policies.

```yml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: tenant-a-namespace-isolation
  namespace: tenant-a-production
spec:
  endpointSelector:
    matchLabels: {}
  ingress:
  - fromEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: tenant-a-production
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: tenant-a-production
```

> **AKS advantage**: ACNS Cilium policies process traffic at the eBPF layer, providing high-performance enforcement for multi-tenant network isolation compared to standard iptables-based approaches.

**Verify isolation**: Attempt to `curl` a pod in `tenant-a-production` from a pod in `tenant-b-production`, and attempt egress from `tenant-a-production` to a workload in another namespace. Both connections should fail unless a separate allow policy exists.

---

## 4. Resource quotas

**Problem**: A single tenant deploying a runaway workload or memory leak can consume all node resources, starving other tenants (the "noisy neighbor" problem).

**Solution**: Apply a `ResourceQuota` to cap total namespace consumption, and a `LimitRange` to enforce default requests/limits on individual pods.

```yml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-quota
  namespace: tenant-a-production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "50"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-a-limit-range
  namespace: tenant-a-production
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 256Mi
    type: Container
```

> **AKS advantage**: `ResourceQuota` and `LimitRange` provide enforceable per-tenant boundaries at admission time, while the cluster autoscaler independently scales nodes for pending pods that remain schedulable within those limits.

**Verify isolation**:

```bash
kubectl describe quota tenant-a-quota --namespace tenant-a-production
```

---

## 5. Pod security admission

**Problem**: Tenants might attempt to deploy privileged containers, mount host file systems, or run as root, which could compromise the underlying AKS node.

**Solution**: Enforce the Kubernetes Pod Security Standards (PSS) at the namespace level to block privileged workloads.

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a-production
  labels:
    pod-security.kubernetes.io/enforce: "restricted"
    pod-security.kubernetes.io/audit: "restricted"
    pod-security.kubernetes.io/warn: "restricted"
```

> **AKS advantage**: You can enforce these standards globally across all tenant namespaces simultaneously using Azure Policy for Kubernetes, preventing cluster admins from accidentally creating unsecured namespaces.

**Verify isolation**: Attempt to deploy a pod with `securityContext.privileged: true` into the namespace. The API server will reject the deployment.

---

## 6. Node pool isolation

**Problem**: For hard multi-tenancy, logical namespace isolation is insufficient. Highly regulated tenants often require stronger compute separation and reduced noisy-neighbor risk.

**Solution**: Create dedicated node pools for specific tenants and use Kubernetes taints and tolerations to schedule workloads onto those nodes. This improves compute isolation, but control plane and cluster-level components remain shared.

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myMultiTenantCluster \
    --name tenanta \
    --node-taints tenant=tenant-a:NoSchedule \
    --labels tenant=tenant-a
```

Tenants must then include the corresponding toleration in their pod manifests:

```yml
tolerations:
- key: "tenant"
  operator: "Equal"
  value: "tenant-a"
  effect: "NoSchedule"
```

> **AKS advantage**: AKS allows you to scale, upgrade, and manage the lifecycle of tenant-specific node pools independently, meaning you can patch Tenant A's nodes without causing downtime for Tenant B.

**Verify isolation**:

```bash
kubectl get nodes -l tenant=tenant-a
```

---

## 7. Azure Monitor

**Problem**: In a shared cluster, platform administrators need to track resource utilization, application logs, and performance metrics on a per-tenant basis.

**Solution**: Enable Azure Monitor Container Insights and use namespace labels to filter KQL queries.

```azurecli-interactive
az aks enable-addons -a monitoring -n myMultiTenantCluster -g myResourceGroup
```

> **AKS advantage**: Azure Monitor automatically captures Kubernetes namespace metadata. You can build custom Azure Dashboards that filter `KubePodInventory` and `ContainerLog` tables by the `Namespace` column, providing each tenant with a dedicated observability pane.

**Verify isolation**: Run a KQL query in Log Analytics filtering by `Namespace == "tenant-a-production"`.

---

## Enterprise isolation considerations

For large-scale enterprise deployments, consider these additional architectural boundaries:

- **Subscription hierarchy**: Place multi-tenant clusters in dedicated landing zone subscriptions to isolate Azure API limits and billing at the cloud-provider level.
- **Private clusters**: Use [AKS private clusters](./private-clusters.md) with [Azure Private Link](/azure/private-link/private-link-overview) to ensure the Kubernetes API server is only accessible from trusted internal networks, shielding the control plane from public internet threats.
- **Multi-zone node pools**: Distribute tenant node pools across [Azure Availability Zones](./reliability-availability-zones-configure.md) to ensure tenant workloads survive datacenter-level failures.
- **Cost isolation**: Use [Azure tags](./use-tags.md) on node pools and integrate tools like Kubecost to perform chargebacks, attributing exact compute and storage costs to specific tenant namespaces.

## Production readiness checklist

Before onboarding tenants to your AKS cluster, verify the following:

- **Layer 1**: Managed namespaces are created with appropriate billing and ownership labels.
- **Layer 2**: Kubernetes RBAC role bindings are mapped to Microsoft Entra ID groups for namespace-scoped access.
- **Layer 3**: ACNS Cilium tenant namespace isolation policies are applied to all tenant namespaces.
- **Layer 4**: `ResourceQuota` and `LimitRange` objects are active in every namespace.
- **Layer 5**: Pod Security Admission is set to `restricted` via namespace labels or Azure Policy.
- **Layer 6**: (If required) Dedicated node pools are provisioned with taints for hard multi-tenancy.
- **Layer 7**: Azure Monitor is enabled and platform teams have namespace-filtered dashboards.

## Next steps

To review the architectural theory and isolation spectrum that informs these best practices, return to the conceptual overview.

- [Concepts: Multitenancy in AKS](./concepts-multi-tenancy.md)
