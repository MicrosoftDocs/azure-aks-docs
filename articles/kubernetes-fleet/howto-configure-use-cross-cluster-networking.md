---
title: "How to Configure and use cross-cluster networking for Azure Kubernetes Fleet Manager"
description: Learn how to use Azure Kubernetes Fleet Manager to set up multi-cluster networking for highly available global services and service discovery. 
ms.topic: how-to
ms.date: 05/14/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a platform engineer, I want to configure cross-cluster networking in Azure Kubernetes Fleet Manager, so that I can deploy global services to achieve high availability using multiple member clusters."
---

# Configure and use cross-cluster networking for Azure Kubernetes Fleet Manager (preview)

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Cross-cluster networking for Azure Kubernetes Fleet Manager provides managed Cilium multi-cluster that extends Cilium's eBPF-based networking and observability across multiple clusters.

Fleet Manager supports creation of multiple cross-cluster networking profiles with each supporting up to 255 member clusters. Clusters in a profile participate in a managed federated network with access to global services and service discovery and observability via Hubble.

Platform engineers label member clusters that should participate in a single cross-cluster network, specifying the label in a selector when defining the network profile. To allow for bulk membership management and avoid unintended interruptions, the cross-cluster network is only updated when explicitly requested by an authorized user.  

This article provides instructions on how to configure a cross-cluster networking profile, add member clusters and how to expose global services.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

> [!NOTE]
> Cross-cluster networking is currently available in the following regions: `westcentralus`, `eastasia`, `uksouth`, and `eastus`. Global availability across all Azure regions is expected by June 5, 2026.

## Prerequisites and limitations

* A cross-cluster network can have up to 255 member clusters.
* Fleet Manager member clusters can only participate in a single cross-cluster network at any time.
* Clusters must run Kubernetes v1.32 or above and have [Advanced Container Networking Services (ACNS)][aks-acns-enabled] with Cilium enabled.
* Clusters must be connected to a [single flat network][flat-network] (virtual network or multiple peered networks).
* Overlay networking with tunnels isn't supported.
* Self-managed Cilium multi-cluster can't be deployed at the same time.
* ACNS sets the Cilium version and enabled features which are read-only and can't be modified by users.

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

Install the [Cilium CLI][cilium-cli-install] so you can verify the cross-cluster network on the dataplane in a later step.

Set the following environment variables:

```bash
export GROUP=<resource-group>
export FLEET=<fleet-name>
export MEMBER_CLUSTER_1=mbr-aks-member-1
export MEMBER_CLUSTER_2=mbr-aks-member-2
export NETWORK_NAME=demo-network
export NETWORK_PROFILE_NAME=fccnp-demo-01
```

## Create AKS clusters

Create two member AKS clusters (`mbr-aks-member-1` and `mbr-aks-member-2`) on a flat network. See [Azure CNI with dynamic IP allocation][azure-cni-dynamic-ip-allocation] for a recommended approach to achieve this setup.

After the clusters are created, join them to a Fleet. See [Create an Azure Kubernetes Fleet Manager resource and join member clusters][fleet-quickstart].

## Label the member clusters

Label both member clusters so they're configured to be included in the cross-cluster network.

```azurecli-interactive
az fleet member update \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${MEMBER_CLUSTER_1} \
    --labels "mesh=${NETWORK_NAME}"
```

```azurecli-interactive
az fleet member update \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${MEMBER_CLUSTER_2} \
    --labels "mesh=${NETWORK_NAME}"
```

## Create a cross-cluster network profile

Create a cross-cluster network profile using the [`az fleet clustermeshprofile create`](/cli/azure/fleet/clustermeshprofile#az-fleet-clustermeshprofile-create) command.

```azurecli-interactive
az fleet clustermeshprofile create \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --member-selector "mesh=${NETWORK_NAME}"
```

While a network profile is created as an Azure Resource, no Cilium multi-cluster configuration is yet applied on clusters. The following steps still need to be performed to apply and connect the cross-cluster network.

## Validate the selected clusters

Validate which clusters will be included in the cross-cluster network by supplying the `what-if` parameter to the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/clustermeshprofile#az-fleet-clustermeshprofile-apply) command.

```azurecli-interactive
az fleet clustermeshprofile apply \
    --what-if \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --output table
```

As we're creating a new cross-cluster network, both clusters have an Add action listed.

```output
Action    ClusterResourceId                   ETag        MeshMembershipState    Name
--------  ----------------------------------  ----------  ---------------------  ----------------
Add       /subscription/…/…/mbr-aks-member-1  "fd009cd9"  -                      mbr-aks-member-1
Add       /subscription/…/…/mbr-aks-member-2  "a400f86e"  -                      mbr-aks-member-2
```

## Connect the cross-cluster network

You can now apply the cross-cluster networking changes by omitting the `what-if` parameter from the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/clustermeshprofile#az-fleet-clustermeshprofile-apply) command.

```azurecli-interactive
az fleet clustermeshprofile apply \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} 
```

The cross-cluster network creation starts and Cilium multi-cluster configuration is applied to selected member clusters. The creation process is asynchronous, with the process duration determined by the number of clusters being updated.

The apply operation runs to completion and can't be interrupted. While it's running, you can monitor the network status of each member:

```azurecli-interactive
az fleet clustermeshprofile list-members \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --query "[].{name: name, state: meshProperties.status.state}" \
    -o table
```

```output
Name              State
----------------  ----------
mbr-aks-member-1  Connecting
mbr-aks-member-2  Connecting
```

You can also monitor the status of the overall operation:

```azurecli-interactive
az fleet clustermeshprofile show \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --query "properties.status.state" \
    -o tsv
```

## Confirm cross-cluster network connection via the dataplane

Once the members' states are showing as `Connected`, the cross-cluster network is established.

You can confirm the successful connection using standard dataplane tools such as the Cilium CLI. First, obtain the Kubernetes access credentials for both member clusters using [`az aks get-credentials`][az-aks-get-credentials], setting `context` appropriately.

```azurecli-interactive
az aks get-credentials \
    --resource-group ${GROUP} \
    --name ${MEMBER_CLUSTER_1} \
    --context cluster1
```

```azurecli-interactive
az aks get-credentials \
    --resource-group ${GROUP} \
    --name ${MEMBER_CLUSTER_2} \
    --context cluster2
```

Then, use the Cilium CLI's status command to see that all member clusters are connected:

```bash
cilium clustermesh status --context cluster1
```

```output
✅ Service "clustermesh-apiserver" of type "LoadBalancer" found
✅ Cluster access information is available:
  - 10.10.1.62:2379
✅ Deployment clustermesh-apiserver is ready
ℹ️  KVStoreMesh is enabled
✅ All 2 nodes are connected to all clusters [min:1 / avg:1.0 / max:1]
✅ All 1 KVStoreMesh replicas are connected to all clusters [min:1 / avg:1.0 / max:1]
🔌 Cluster Connections:
  - mbr-aks-member-22: 2/2 configured, 2/2 connected - KVStoreMesh: 1/1 configured, 1/1 connected
🔀 Global services: [ min:0 / avg:0.0 / max:0 ]
```

> [!NOTE]
> Fleet Manager's managed Cilium multi-cluster appends the Cilium cluster ID to the Fleet member name when registering it with the mesh, so the peer in `Cluster Connections` appears as `<member-name>` followed by a digit (for example `mbr-aks-member-22`).

## Test load balancing and service discovery

Once the cross-cluster network is created successfully, you can test load balancing out by following the [official Cilium multi-cluster example][cilium-example], or using the steps shown next. The steps in this document provide extra guidance on working with AKS clusters and Fleet Manager.

> [!NOTE]
> Fleet Manager's managed Cilium multi-cluster installation sets `clustermesh-default-global-namespace: false`, which differs from the upstream Cilium default. A `clustermesh.cilium.io/global="true"` annotation must be set on the Namespace to opt in to cross-cluster service sharing. Without it, the per-Service `service.cilium.io/global` annotation has no effect.

> [!NOTE]
> The example manifests in this section pull container images from public registries (`docker.io` and `quay.io`). If your environment uses Azure Policy or similar admission controls to restrict container image sources, the example Deployments might generate policy warnings or be blocked outright. In that case, mirror the images to a registry that is allowed by your policy (for example Azure Container Registry) and update the manifests accordingly.

* On `mbr-aks-member-1` create a dedicated namespace and annotate it so Services within it are eligible to be shared across the cross-cluster network. Then apply the `Deployment` and `Service` resources using the `cluster1.yaml` manifest.

    ```bash
    kubectl --context=cluster1 create namespace rebel-base-demo
    kubectl --context=cluster1 annotate namespace rebel-base-demo clustermesh.cilium.io/global="true" --overwrite
    kubectl --context=cluster1 -n rebel-base-demo apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster1.yaml
    kubectl --context=cluster1 -n rebel-base-demo apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml
    ```

* On `mbr-aks-member-2` apply the equivalent, but this time use the `cluster2.yaml` manifest.

    ```bash
    kubectl --context=cluster2 create namespace rebel-base-demo
    kubectl --context=cluster2 annotate namespace rebel-base-demo clustermesh.cilium.io/global="true" --overwrite
    kubectl --context=cluster2 -n rebel-base-demo apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster2.yaml
    kubectl --context=cluster2 -n rebel-base-demo apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml
    ```

* Run the following command multiple times on each cluster. Observe the serving cluster changes, demonstrating the request is being served by multiple clusters despite calling the service on only one.

    ```bash
    kubectl --context=cluster1 -n rebel-base-demo exec -ti deployment/x-wing -- curl rebel-base
    ```
    
    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    ```

* Set the `clustermesh.cilium.io/global` annotation on the `rebel-base-demo` Namespace on `mbr-aks-member-1` (cluster 1) to `"false"` so Services in that Namespace are no longer shared across the cross-cluster network from cluster 1.

    ```bash
    kubectl --context=cluster1 annotate namespace rebel-base-demo clustermesh.cilium.io/global="false" --overwrite
    ```

    > [!NOTE]
    > After changing the Namespace-level `clustermesh.cilium.io/global` annotation, reconciling each Service within that Namespace is necessary to put the new configuration into effect (e.g. with `kubectl --context=cluster1 -n rebel-base-demo apply -f <service-manifest>.yaml`). The per-Service `service.cilium.io/global` annotation, by contrast, takes effect on both clusters within a few seconds.

* Let's validate `mbr-aks-member-1` (cluster 1) can reach the `rebel-base` Service on cluster 1, and `mbr-aks-member-2` (cluster 2) can't.

    ```bash
    kubectl --context=cluster1 -n rebel-base-demo exec -ti deployment/x-wing -- curl rebel-base
    ```

    On cluster 1, we only see local responses because the Namespace is no longer global and remote endpoints aren't imported.

    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    ```

    Repeat the command on cluster 2.

    ```bash
    kubectl --context=cluster2 -n rebel-base-demo exec -ti deployment/x-wing -- curl rebel-base
    ```

    On cluster 2, we only see local responses because the Service on cluster 1 is no longer shared.
    
    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    ```

## Updating a cross-cluster network

The process of adding or removing clusters is demonstrated in this guide, but can be summarized as:

1. Modify labels on the Fleet Manager member clusters to be added or removed.
1. Review cross-cluster networking changes by using the `what-if` parameter with the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/clustermeshprofile#az-fleet-clustermeshprofile-apply) command.
1. Once satisfied with the changes, apply them by running the same command, omitting the `what-if` parameter.

Reviewing the changes is optional, but recommended, especially for larger cross-cluster networks where any change can take some time to complete.

## Clean up resources

> [!NOTE]
> To prevent unexpected outages, member clusters joined to a cross-cluster network can't be removed from a fleet. These members must be removed from the cross-cluster network before they can be deleted.

To clean up resources, first remove the members from the cross-cluster network:

1. Change the cross-cluster network profile's member selector to a value that no member cluster has, then apply the change so all members are disconnected from the cross-cluster network.

    ```azurecli-interactive
    az fleet clustermeshprofile create \
        --fleet-name ${FLEET} \
        --resource-group ${GROUP} \
        --name ${NETWORK_PROFILE_NAME} \
        --member-selector "mesh=none"
    az fleet clustermeshprofile apply \
        --fleet-name ${FLEET} \
        --resource-group ${GROUP} \
        --name ${NETWORK_PROFILE_NAME}
    ```

1. Confirm the profile reports no members before continuing.

    ```azurecli-interactive
    az fleet clustermeshprofile list-members \
        --fleet-name ${FLEET} \
        --resource-group ${GROUP} \
        --name ${NETWORK_PROFILE_NAME}
    ```

    ```output
    []
    ```

1. Delete the cross-cluster network profile.

    ```azurecli-interactive
    az fleet clustermeshprofile delete --fleet-name ${FLEET} --resource-group ${GROUP} --name ${NETWORK_PROFILE_NAME} --yes
    ```

1. Delete the member clusters from the fleet resource (or delete the fleet resource entirely with `az fleet delete`) and, when no longer needed, delete the AKS clusters and resource group.

## Troubleshooting

### Members fail to move to `Connected` and the `clustermesh-apiserver` LoadBalancer Service has no external IP

Check the `clustermesh-apiserver` Service on each affected member cluster:

```bash
kubectl --context=cluster1 -n kube-system get svc clustermesh-apiserver
```

If `EXTERNAL-IP` is shown as `<pending>`, as in the example, the Service has not been assigned an internal load balancer IP:

```output
NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
clustermesh-apiserver   LoadBalancer   10.0.221.162   <pending>     2379:31640/TCP   31s
```

Inspect the Service events to identify the underlying cause:

```bash
kubectl --context=cluster1 -n kube-system describe svc clustermesh-apiserver
```

A common cause is an `AuthorizationFailed` (HTTP 403) error, indicating that the AKS cluster identity does not have permission to read or modify the subnet that backs the cluster:

```output
Events:
  Type     Reason                  Age   From                Message
  ----     ------                  ----  ----                -------
  Normal   EnsuringLoadBalancer    6s    service-controller  Ensuring load balancer
  Warning  SyncLoadBalancerFailed  6s    service-controller  Error syncing load balancer: failed to ensure load balancer: ...
                                                             RESPONSE 403: 403 Forbidden
                                                             ERROR CODE: AuthorizationFailed
                                                             {
                                                               "error": {
                                                                 "code": "AuthorizationFailed",
                                                                 "message": "The client '...' with object id '...' does not have authorization to perform action 'Microsoft.Network/virtualNetworks/subnets/read' over scope '/subscriptions/.../virtualNetworks/<vnet>/subnets/<subnet>' or the scope is invalid..."
                                                               }
                                                             }
```

Without this permission, the AKS load balancer controller can't assign an internal IP to the `clustermesh-apiserver` Service, and the cross-cluster network can't complete the connection.

The AKS cluster identity normally receives a **Network Contributor** role assignment on the virtual network or subnet when the cluster is created, but in some configurations this assignment isn't created. Manually grant the AKS cluster identity the **Network Contributor** role on the virtual network for every affected member cluster, then force a reconcile on the cluster using the `az aks update` command so the new role takes effect.

```azurecli-interactive
AKS_IDENTITY=$(az aks show --resource-group ${GROUP} --name ${MEMBER_CLUSTER_1} --query "identity.principalId" -o tsv)
VNET_ID=$(az network vnet show --resource-group ${GROUP} --name <vnet-name> --query id -o tsv)

az role assignment create \
    --assignee-object-id ${AKS_IDENTITY} \
    --assignee-principal-type ServicePrincipal \
    --role "Network Contributor" \
    --scope ${VNET_ID}

az aks update --resource-group ${GROUP} --name ${MEMBER_CLUSTER_1}
```

Once the cluster is updated with the role assignment, run `az fleet clustermeshprofile apply` again.

## Next steps

* [Overview of Fleet Manager multi-cluster networking](./concepts-multi-cluster-networking-overview.md).
* [Fleet Manager Frequently Asked Questions (FAQs)](./faq.md).

<!-- INTERNAL LINKS -->
[aks-acns-enabled]: ../aks/use-advanced-container-networking-services.md?pivots=cilium
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[flat-network]: ../aks/concepts-network-cni-overview.md#flat-networks
[azure-cni-dynamic-ip-allocation]: ../aks/configure-azure-cni-dynamic-ip-allocation.md#configure-pod-subnet---dynamic-ip-allocation-and-enhanced-subnet-support---azure-cli
[fleet-quickstart]: ./quickstart-create-fleet-and-members.md

<!-- EXTERNAL LINKS -->
[cilium-example]: https://docs.cilium.io/en/stable/network/clustermesh/services/#deploying-a-simple-example-service
[cilium-cli-install]: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli
