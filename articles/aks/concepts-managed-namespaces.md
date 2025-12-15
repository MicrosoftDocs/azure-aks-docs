---
title: Overview of Managed Namespaces in Azure Kubernetes Service (AKS)
description: Learn how to simplify namespace management and resource isolation in Azure Kubernetes Service (AKS) with managed namespaces.
ms.topic: overview
ms.date: 11/18/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
---

# Overview of managed namespaces in Azure Kubernetes Service (AKS)

**Applies to:** :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

As you manage clusters in Azure Kubernetes Service (AKS), you often need to isolate teams and workloads. With logical isolation, you can use a single AKS cluster for multiple workloads, teams, or environments. Kubernetes namespaces form the logical isolation boundary for workloads and resources. Performing logical isolation involves implementing scripts and processes to create namespaces, set resource limits, apply network policies, and grant team access via role-based access control. Learn how to use managed namespaces in Azure Kubernetes Service (AKS) to simplify namespace management, cluster multi-tenancy, and resource isolation.

Logical separation of clusters usually provides a higher pod density than physically isolated clusters, with less excess compute capacity sitting idle in the cluster. When combined with [cluster autoscaler][cluster-autoscaler] or [Node Auto Provisioning][node-auto-provisioning], you can scale the number of nodes up or down to meet demands. This best practice approach minimizes costs by running only the required number of nodes.

## Network policies

[Network Policies][aks-network-policies] are Kubernetes resources you can use to control the flow of traffic between pods, namespaces, and external endpoints. Network policies allow you to define rules for ingress (incoming) and egress (outgoing) traffic, ensuring that only authorized communication is permitted. By applying network policies, you can enhance the security and isolation of workloads within your cluster.

> [!NOTE]
> The default ingress network policy rule of **Allow same namespace** opts for a secure by default stance. If you need your Kubernetes Services, ingresses, or gateways to be accessible from outside of the namespace where they're deployed, for example from an ingress controller deployed in a separate namespace, you need to select **Allow all**. You might then apply your own network policy to restrict ingress to be from that namespace only.

Managed namespaces come with a set of built-in policies.

- **Allow all**: Allows all network traffic.
- **Allow same namespace**: Allows all network traffic within the same namespace.
- **Deny all**: Denies all network traffic.

You can apply any of the built-in policies on both **ingress** and **egress** rules and they have the following default values.

| Policy | Default value |
| ------- | -------------|
| Ingress | Allow same namespace |
| Egress | Allow all |

> [!NOTE]
> Users with a `Microsoft.ContainerService/managedClusters/networking.k8s.io/networkpolicies/write` action, such as `Azure Kubernetes Service RBAC Writer`, on the Microsoft Entra ID role they're assigned can add more network policies through the Kubernetes API.
>
> For example, if an admin applies a `Deny All` policy for ingress/egress, and a user applies an `Allow` policy for a namespace via the Kubernetes API, the `Allow` policy takes priority over the `Deny All` policy, and traffic is allowed to flow for the namespace.

## Resource quotas

[Resource Quotas][aks-resource-quotas] are Kubernetes resources that are used to manage and limit the resource consumption of namespaces within a cluster. They allow administrators to define constraints on the amount of CPU, memory, storage, or other resources that are used by workloads in a namespace. By applying resource quotas, you can ensure fair resource distribution, prevent resource overuse, and maintain cluster stability.

Managed namespaces can be created with the following resource quotas:

- **CPU requests and limits**: Define the minimum and maximum amount of CPU resources that workloads in the namespace can request or consume. The quota ensures that workloads have sufficient CPU resources to operate while preventing overuse that could affect other namespaces. The quota is defined in the [milliCPU form][meaning-of-cpu].
- **Memory requests and limits**: Specify the minimum and maximum amount of memory resources that workloads in the namespace can request or consume. The quota helps maintain stability by avoiding memory overcommitment and ensuring fair resource allocation across namespaces. The quota is defined in [power-of-two equivalents form][meaning-of-memory] such as `Ei`,`Pi`, `Ti`, `Gi`, `Mi`, `Ki`.

## Labels and annotations

Kubernetes [Labels][labels] and [Annotations][annotations] are metadata attached to Kubernetes objects, such as namespaces, to provide additional information. Labels are key-value pairs used to organize and select resources, enabling efficient grouping and querying. Annotations store nonidentifying metadata, such as configuration details or operational instructions, that are consumed by tools or systems.

You can optionally set Kubernetes Labels and Annotations to be applied on the namespace.

## Adoption policy

The adoption policy determines how an existing namespace in Kubernetes is handled when creating a managed namespace.

> [!WARNING]
> Onboarding an existing namespace to be managed can cause disruption. If the **resource quota** applied is less than what is already being requested by pods, new deployments and pods that exceed the quota is denied. Existing deployments aren't affected, but scaling is denied. Applying **network policies** to an existing namespace can affect existing traffic. Ensure that the policies are tested and validated to avoid unintended disruptions to communication between pods or external endpoints.

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
| [Azure Kubernetes Service Namespace User][aks-namespace-user] | Allows read-only access to a managed namespace on a cluster. Allows access to list credentials on the namespace.  |

Managed namespaces uses the following built-in roles for the data plane.

| Role | Description |
| ---- | ------------|
| [Azure Kubernetes Service RBAC Reader][aks-rbac-reader] | Allows read-only access to see most objects in a namespace. It doesn't allow viewing roles or role bindings. This role doesn't allow viewing Secrets, since reading the contents of Secrets enables access to ServiceAccount credentials in the namespace, which would allow API access as any ServiceAccount in the namespace (a form of privilege escalation).|
| [Azure Kubernetes Service RBAC Writer][aks-rbac-writer] | Allows read/write access to most objects in a namespace. This role doesn't allow viewing or modifying roles or role bindings. However, this role allows accessing Secrets and running Pods as any ServiceAccount in the namespace, so it can be used to gain the API access levels of any ServiceAccount in the namespace. |
| [Azure Kubernetes Service RBAC Admin][aks-rbac-admin] |  Allows read/write access to most resources in a namespace, including the ability to create roles and role bindings within the namespace. This role doesn't allow write access to resource quota or to the namespace itself. |

## Managed namespaces use cases

Properly setting up [namespaces][upstream-namespaces] with associated [quotas][upstream-quotas] or [network policies][upstream-network-policies] can be complex and time-consuming. Managed namespaces allow you to set up preconfigured namespaces in your AKS clusters that you can interact with using the Azure CLI.

The following sections outline some common use cases for managed namespaces.

### Manage teams and resources on AKS

Let's say you're an admin at a small startup. You have an AKS cluster provisioned and want to set up namespaces for developers from your _finance_, _legal_, and _design_ teams. As you're setting up your company's environment, you want to make sure that access is tightly controlled, resources are rightly scoped, and environments are organized properly.

- The _finance_ team intakes forms and files from teams all across the company, but they hold sensitive information that ideally shouldn't leave their environment. Their applications and workflows are lighter on the computing side but consume a lot of memory. As a result, you decide to set up a namespace that allows for all network ingress, network egress only within their namespace, and scope their resources accordingly. A label to the namespace helps easily identify which team is using it.

  ```azurecli-interactive
   az aks namespace add \
     --name $FINANCE_NAMESPACE \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cpu-request 250m \
     --cpu-limit 500m \
     --memory-request 512Mi \
     --memory-limit 2Gi \
     --ingress-policy AllowAll \
     --egress-policy AllowSameNamespace \
     --labels team=finance
   ```

- The _legal_ team deals primarily with sensitive data. Their applications use a fair amount of memory but require little compute resources. You decide to set up a namespace that's extremely restrictive for both the ingress/egress policies, and scope their resource quotas accordingly.

   ```azurecli-interactive
   az aks namespace add \
     --name $LEGAL_NAMESPACE \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cpu-request 250m \
     --cpu-limit 500m \
     --memory-request 2Gi \
     --memory-limit 5Gi \
     --ingress-policy DenyAll \
     --egress-policy DenyAll \
     --labels team=legal
   ```

- The _design_ team needs the ability to freely flow data to showcase their work across the company. They also encourage teams to send them content for reference. Their applications are intensive and require a large chunk of memory and CPU. You decide to set them up with a minimally restrictive namespace and allocate a sizeable amount of resources for them.

   ```azurecli-interactive
   az aks namespace add \
     --name $DESIGN_NAMESPACE \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cpu-request 2000m \
     --cpu-limit 2500m \
     --memory-request 5Gi \
     --memory-limit 8Gi \
     --ingress-policy AllowAll \
     --egress-policy AllowAll \
     --labels team=design
   ```

With these namespaces set up, you now have environments for the three teams in your organization that should allow each team to get up and running in an environment that best suits their needs. Admins can use [Azure CLI calls][managed-namespaces-cli] to update the namespaces as needs shift.

### View managed namespaces

As the number of teams you deal with expands, or as your organization grows, you might find yourself needing to review the namespaces you set up.

Let's say you want to review the namespaces in your cluster from the [previous section](#manage-teams-and-resources-on-aks) to ensure there are three namespaces.

Use the [`az aks namespace list`][az-aks-namespace-list] command to review your namespaces.

```azurecli-interactive
az aks namespace list \
  --cluster-name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table
```

Your output should look similar to the following example output:

```output
Name                               ResourceGroup    Location
------------------                 ---------------  ----------
$CLUSTER_NAME/$DESIGN_NAMESPACE    $RESOURCE_GROUP  <LOCATION>
$CLUSTER_NAME/$LEGAL_NAMESPACE     $RESOURCE_GROUP  <LOCATION>
$CLUSTER_NAME/$FINANCE_NAMESPACE   $RESOURCE_GROUP  <LOCATION>
```

### Control access to managed namespaces

You can further use [Azure RBAC roles](#managed-namespaces-built-in-roles), scoped to each namespace, to determine which users have access to certain actions within the namespace. With the proper configuration, you can ensure users have all the access they need within the namespace, while limiting their access to other namespaces or cluster-wide resources.

## Next steps

* Learn how to [create and use managed namespaces on Azure Kubernetes Service (AKS)][managed-namespaces].
* Learn about [multi-cluster managed namespaces][fleet-managed-namespace] with Azure Kubernetes Fleet Manager.

<!--- External Links --->
[meaning-of-cpu]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-cpu
[meaning-of-memory]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-memory
[labels]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
[annotations]: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
[upstream-namespaces]: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
[upstream-network-policies]: https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource
[upstream-quotas]: https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/

<!--- Internal Links --->
[cluster-autoscaler]: cluster-autoscaler.md
[node-auto-provisioning]: node-autoprovision.md
[aks-namespace-contributor]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-contributor
[az-aks-namespace-list]: /cli/azure/aks/namespace#az-aks-namespace-list
[aks-namespace-user]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-namespace-user
[aks-rbac-reader]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-reader
[aks-rbac-writer]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-writer
[aks-rbac-admin]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-admin
[aks-network-policies]: use-network-policies.md
[aks-resource-quotas]: operator-best-practices-scheduler.md#enforce-resource-quotas
[managed-namespaces]: managed-namespaces.md
[fleet-managed-namespace]: ../kubernetes-fleet/concepts-fleet-managed-namespace.md
[managed-namespaces-cli]: /cli/azure/aks/namespace
