---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.reviewer: leslielin
ms.lastreviewed: 07/31/2024

---

AKS provides the following five built-in roles. They are similar to the [Kubernetes built-in roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles), with a few differences, such as supporting CRDs. See the full list of actions allowed by each [Azure built-in role](/azure/role-based-access-control/built-in-roles).

| Role                                                     | Description                                              |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [Azure Arc-enabled Kubernetes Cluster User](/azure/role-based-access-control/built-in-roles/containers#azure-arc-enabled-kubernetes-cluster-user-role) | Allows you to retrieve the Cluster Connect-based kubeconfig file to manage clusters from anywhere. |
| [Azure Arc Kubernetes Viewer](/azure/role-based-access-control/built-in-roles/containers#azure-arc-kubernetes-viewer) | Allows read-only access to see most objects in a namespace. <br /> Doesn't allow viewing secrets, because **read** permission on secrets enables access to **ServiceAccount** credentials in the namespace. These credentials in turn allow API access through that **ServiceAccount** value (a form of privilege escalation). |
| [Azure Arc Kubernetes Writer](/azure/role-based-access-control/built-in-roles/containers#azure-arc-kubernetes-writer) | Allows read/write access to most objects in a namespace. <br />Doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing secrets and running pods as any **ServiceAccount** value in the namespace, so it can be used to gain the API access levels of any such **ServiceAccount** value in the namespace. |
| [Azure Arc Kubernetes Admin](/azure/role-based-access-control/built-in-roles/containers#azure-arc-kubernetes-admin) | Allows admin access. It's intended to be granted within a namespace through **RoleBinding**. If you use it in **RoleBinding**, it allows read/write access to most resources in a namespace, including the ability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. |
| [Azure Arc Kubernetes Cluster Admin](/azure/role-based-access-control/built-in-roles/containers#azure-arc-kubernetes-cluster-admin) | Allows "superuser" access to execute any action on any resource. When you use it in **ClusterRoleBinding**, it gives full control over every resource in the cluster and in all namespaces. When you use it in **RoleBinding**, it gives full control over every resource in the role binding namespace, including the namespace itself.|
