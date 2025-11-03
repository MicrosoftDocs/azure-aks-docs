---
title: Overview of managed namespaces (preview)
description: Learn how to simplify namespace management and resource isolation in Azure Kubernetes Service (AKS) with managed namespaces.
ms.topic: concept-article
ms.date: 08/04/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
---

# Overview of managed namespaces (preview) in Azure Kubernetes Service (AKS)

**Applies to:** :heavy_check_mark: AKS Automatic (preview) :heavy_check_mark: AKS Standard

As you manage clusters in Azure Kubernetes Service (AKS), you often need to isolate teams and workloads. With logical isolation, you can use a single AKS cluster for multiple workloads, teams, or environments. Kubernetes namespaces form the logical isolation boundary for workloads and resources. Performing logical isolation involves implementing scripts and processes to create namespaces, set resource limits, apply network policies, and grant team access via role-based access control. Learn how to use managed namespaces in Azure Kubernetes Service (AKS) to simplify namespace management, cluster multi-tenancy, and resource isolation.

Logical separation of clusters usually provides a higher pod density than physically isolated clusters, with less excess compute capacity sitting idle in the cluster. When combined with [cluster autoscaler][cluster-autoscaler] or [Node Auto Provisioning][node-auto-provisioning], you can scale the number of nodes up or down to meet demands. This best practice approach minimizes costs by running only the required number of nodes.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Network policies

[Network Policies][aks-network-policies] are Kubernetes resources that are used to control the flow of traffic between pods, namespaces, and external endpoints. Network policies allow you to define rules for ingress (incoming) and egress (outgoing) traffic, ensuring that only authorized communication is permitted. By applying network policies, you can enhance the security and isolation of workloads within your cluster.

> [!NOTE]
> The default ingress network policy rule of **Allow same namespace** opts for a secure by default stance. If you need your Kubernetes Services, ingresses, or gateways to be accessible from outside of the namespace where they're deployed, for example from an ingress controller deployed in a separate namespace, you need to select **Allow all**. You may then apply your own network policy to restrict ingress to be from that namespace only.

Managed namespaces come with a set of built-in policies.
- **Allow all**: Allows all network traffic.
- **Allow same namespace**: Allows all network traffic within the same namespace.
- **Deny all**: Denies all network traffic. 

You can apply any of the built-in policies on both **ingress** and **egress** rules and they have the following default values.

| Policy | Default value |
| ------- | -------------|
| Ingress | Allow same namespace |
| Egress | Allow all |

## Resource quotas

[Resource Quotas][aks-resource-quotas] are Kubernetes resources that are used to manage and limit the resource consumption of namespaces within a cluster. They allow administrators to define constraints on the amount of CPU, memory, storage, or other resources that will be used by workloads in a namespace. By applying resource quotas, you can ensure fair resource distribution, prevent resource overuse, and maintain cluster stability.

Managed namespaces can be created with the following resource quotas:

* **CPU requests and limits**: Define the minimum and maximum amount of CPU resources that workloads in the namespace can request or consume. The quota ensures that workloads have sufficient CPU resources to operate while preventing overuse that could impact other namespaces. The quota is defined in the [milliCPU form][meaning-of-cpu],
* **Memory requests and limits**: Specify the minimum and maximum amount of memory resources that workloads in the namespace can request or consume. The quota helps maintain stability by avoiding memory overcommitment and ensuring fair resource allocation across namespaces. The quota is defined in [power-of-two equivalents form][meaning-of-memory] such as `Ei`,`Pi`, `Ti`, `Gi`, `Mi`, `Ki`.

## Labels and annotations

Kubernetes [Labels][labels] and [Annotations][annotations] are metadata attached to Kubernetes objects, such as namespaces, to provide additional information. Labels are key-value pairs used to organize and select resources, enabling efficient grouping and querying. Annotations, on the other hand, are used to store nonidentifying metadata, such as configuration details or operational instructions, that will be consumed by tools or systems.

You can optionally set Kubernetes Labels and Annotations to be applied on the namespace. 

## Adoption policy

The adoption policy determines how an existing namespace in Kubernetes is handled when creating a managed namespace.

> [!WARNING]
> On-boarding an existing namespace to be managed can cause disruption. If the **resource quota** applied is less than what is already being requested by pods, new deployments and pods that exceed the quota is denied. Existing deployments won't be affected, but scaling will be denied. Applying **network policies** to an existing namespace can impact existing traffic. Ensure that the policies are tested and validated to avoid unintended disruptions to communication between pods or external endpoints.

The following options are available:

- **Never**: If the namespace already exists in the cluster, attempts to create that namespace as a managed namespace fails.
- **IfIdentical**: Take over the existing namespace to be managed, provided there are no differences between the existing namespace and the desired configuration. 
- **Always**: Always take over the existing namespace to be managed, even if some fields in the namespace might be overwritten.

## Delete policy

The delete policy specifies how the Kubernetes namespace is handled when the managed namespace resource is deleted.

> [!WARNING]
> Deleting a managed namespace with the **Delete** policy causes all resources within that namespace, such as Deployments, Services, Ingresses, and other Kubernetes objects, to be deleted. Ensure that you back up or migrate any critical resources before proceeding.

The following options are available:

- **Keep**: Only delete the managed namespace resource while keeping the Kubernetes namespace intact. Additionally, the `ManagedByARM` label is removed from the namespace.
- **Delete**: Delete both the managed namespace resource and the Kubernetes namespace together.


## Managed namespaces built-in roles

Managed namespaces uses the following built-in roles for the control plane.

| Role | Description |
| ---- | ------------|
| [Azure Kubernetes Service Namespace Contributor][aks-namespace-contributor] | Allows access to create, update, and delete managed namespaces on a cluster. |
[Azure Kubernetes Service Namespace User][aks-namespace-user] | Allows read-only access to a managed namespace on a cluster. Allows access to list credentials on the namespace.  |

Managed namespaces uses the following built-in roles for the data plane.

| Role | Description |
| ---- | ------------|
| [Azure Kubernetes Service RBAC Reader][aks-rbac-reader] | Allows read-only access to see most objects in a namespace. It doesn't allow viewing roles or role bindings. This role doesn't allow viewing Secrets, since reading the contents of Secrets enables access to ServiceAccount credentials in the namespace, which would allow API access as any ServiceAccount in the namespace (a form of privilege escalation).|
| [Azure Kubernetes Service RBAC Writer][aks-rbac-writer] | Allows read/write access to most objects in a namespace. This role doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing Secrets and running Pods as any ServiceAccount in the namespace, so it can be used to gain the API access levels of any ServiceAccount in the namespace. |
[Azure Kubernetes Service RBAC Admin][aks-rbac-admin] |  Allows read/write access to most resources in a namespace, including the ability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. |

> [!IMPORTANT]
> When you assign these RBAC roles at a managed namespace scope, access is granted to any unmanaged Kubernetes namespaces on member clusters with the same name, regardless of whether they were placed by the managed namespace.

## Next steps

Learn how to [create and use managed namespaces on Azure Kubernetes Service (AKS)][managed-namespaces].

<!--- External Links --->
[create-azure-subscription]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[azure-portal]: https://portal.azure.com
[meaning-of-cpu]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-cpu
[meaning-of-memory]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-memory
[labels]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
[annotations]: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/

<!--- Internal Links --->
[cluster-autoscaler]: cluster-autoscaler.md
[node-auto-provisioning]: node-autoprovision.md
[quick-automatic-managed-network]: automatic/quick-automatic-managed-network.md
[deployment-safeguards]: deployment-safeguards.md
[azure-rbac-k8s]: manage-azure-rbac.md
[install-azure-cli]: /cli/azure/install-azure-cli
[azure-cli-extensions]: /cli/azure/azure-cli-extensions-overview
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-feature-show]: /cli/azure/feature#az_feature_show
[az-provider-register]: /cli/azure/provider#az_provider_register
[aks-namespace-contributor]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-contributor
[aks-namespace-user]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-user
[aks-rbac-reader]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-reader
[aks-rbac-writer]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-writer
[aks-rbac-admin]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-admin
[aks-network-policies]: use-network-policies.md
[aks-network-policy-options]: use-network-policies.md#network-policy-options-in-aks
[aks-resource-quotas]: operator-best-practices-scheduler.md#enforce-resource-quotas
[managed-namespaces]: managed-namespaces.md
