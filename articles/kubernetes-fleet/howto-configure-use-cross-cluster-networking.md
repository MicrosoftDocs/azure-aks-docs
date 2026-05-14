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

Cross-cluster networking for Azure Kubernetes Fleet Manager provides delivers managed Cilium multi-cluster that extends Cilium's eBPF-based networking and observability across multiple clusters.

Fleet Manager supports creation of multiple cross-cluster networking profiles with each supporting up to 255 member clusters. Clusters in a profile participate in a managed federated network with access to global services and service discovery and observability via Hubble.

Platform engineers label member clusters that should participate in a single cross-cluster network, specifying the label in a selector when defining the network profile. To allow for bulk membership management and avoid unintended interruptions, the cross-cluster network is only updated when explicitly requested by an authorized user.  

This article provides instructions on how to configure a cross-cluster networking profile, add member clusters and how to expose global services.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites and limitations

* A cross-cluster network can have up to 255 member clusters.
* Fleet Manager member clusters can only participate in a single cross-cluster network at any time.
* Clusters must run Kubernetes v1.32 or above and have [Advanced Container Networking Services (ACNS)][aks-acns-enabled] with Cilium enabled.
* Clusters must be connected to a [single flat network][flat-network] (virtual network or multiple peered networks).
* Overlay networking with tunnels isn't supported.
* Self-managed Cilium multi-cluster can't be deployed at the same time.
* ACNS sets the Cilium version and enabled features. These can't currently be directly modified.

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

Create two member AKS clusters `mbr-aks-member-1` and `mbr-aks-member-2` with [Advanced Container Networking Services (ACNS)][aks-acns-enabled] enabled.

Set the following environment variables:

```bash
export GROUP=<resource-group>
export FLEET=<fleet-name>
export MEMBER_CLUSTER_1=mbr-aks-member-1
export MEMBER_CLUSTER_2=mbr-aks-member-2
export TRAFFIC_MANAGER_GROUP=rg-flt-tm-demo
export NETWORK_NAME=demo-network
export NETWORK_PROFILE_NAME=fccnp-demo-01
```

## Label the member clusters

Label both member clusters so they are included in the cross-cluster network when it's created.

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

Create a cross-cluster network profile using the [`az fleet clustermeshprofile create`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.

```azurecli-interactive
az fleet clustermeshprofile create \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --member-label-selector "mesh=${NETWORK_NAME}"
```

While a network profile is created as an Azure Resource, no Cilium multi-cluster configuration is applied on clusters.

## Validate the selected clusters

Before creating the cross-cluster network you can validate which clusters will be included.

Supply the `whatif` parameter to the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.

```azurecli-interactive
az fleet clustermeshprofile apply
    --what-if \
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} \
    --output table
```

As we are creating a new cross-cluster network, the results show that two clusters will join the network.

```output
ClusterResourceId    	            ETag        Name  		       Action   MeshMembershipState
----------------------------------  ----------  -----------------  -------  -------------------
/subscription/…/…/mbr-aks-member-1  "fd009cd9"  mbr-aks-member-1   Add       -
/subscription/…/…/mbr-aks-member-2  "a400f86e"  mbr-aks-member-2   Add       -
```

## Create cross-cluster network

You can now apply the cross-cluster networking changes by omitting the `what-if` parameter from the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.

```azurecli-interactive
az fleet clustermeshprofile apply
    --fleet-name ${FLEET} \
    --resource-group ${GROUP} \
    --name ${NETWORK_PROFILE_NAME} 
```

The cross-cluster network creation starts and Cilium multi-cluster configuration is applied to selected member clusters. The creation process is asynchronous, with the process duration determined by the number of clusters being updated.

The apply operation runs to completion and can't be interrupted.

## Test load balancing and service discovery

Once the cross-cluster network is created successfully, you can test load balancing out by following the [official Cilium multi-cluster example][cilium-example], or using the steps shown next. The steps in this document provide additional guidance on working with AKS clusters and Fleet Manager.

* Obtain the Kubernetes access credentials for both member clusters using [`az aks get-credentials`][az-aks-get-credentials], setting `context` appropriately.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER_1 \
        --context cluster1
    ```

* On `mbr-aks-member-1` apply the `Deployment` and `Service` resources required, ensuring to use the `cluster1.yaml` manifest.

    ```bash
    kubectl --context=cluster1 apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster1.yaml
    kubectl --context=cluster1 apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml
    ```

* On `mbr-aks-member-2` apply the equivalent, but this time use the `cluster2.yaml` manifest.

    ```bash
    kubectl --context=cluster2 apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster2.yaml
    kubectl --context=cluster2 apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml
    ```

* Run the following command multiple times on each cluster. You will see the serving cluster change, demonstrating where the request is being served from.

    ```bash
    kubectl --context=cluster1 exec -ti deployment/x-wing -- curl rebel-base
    ```
    
    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    ```

* Remove the share annotation of the service from  `mbr-aks-member-1` (cluster 1).

    ```bash
    kubectl --context=cluster1 annotate service rebel-base service.cilium.io/shared="false" --overwrite
    ```

* Let's validate `mbr-aks-member-1` (cluster 1) can still use the service, and `mbr-aks-member-2` (cluster 2) can't.

    ```bash
    kubectl --context=cluster1 exec -ti deployment/x-wing -- curl rebel-base
    ```

    On cluster 1 we still receive responses from both clusters.
    
    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    ```
        
    ```bash
    kubectl --context=cluster2 exec -ti deployment/x-wing -- curl rebel-base
    ```
    
    On cluster 2 we now only see local responses and the service on cluster1 is no longer shared.
    
    ```output
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    {"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
    ```

## Updating a cross-cluster network

The process of adding or removing clusters is the same as shown above, but can be summarized as:

1. Modify labels on the Fleet Manager one or more member cluster.
1. Review changes by using the `whatif` parameter with the [`az fleet clustermeshprofile apply`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.
1. If happy, apply the change be re-running the command and omitting `whatif`.

Step 2 is optional, but recommended, especially for larger cross-cluster networks where any change can take some time to complete.

## Next steps

* [Overview of Fleet Manager multi-cluster networking](./concepts-multi-cluster-networking-overview.md).
* [Fleet Manager Frequently Asked Questions (FAQs)](./faq.md).

<!-- INTERNAL LINKS -->
[aks-acns-enabled]: ../aks/use-advanced-container-networking-services.md?pivots=cilium
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[flat-network]: ../aks/concepts-network-cni-overview.md#flat-networks

<!-- EXTERNAL LINKS -->
[cilium-example]: https://docs.cilium.io/en/stable/network/clustermesh/services/#deploying-a-simple-example-service