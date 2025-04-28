---
title: "How to set up multi-cluster Layer 4 load balancing across Azure Kubernetes Fleet Manager member clusters (preview)"
description: Learn how to use Azure Kubernetes Fleet Manager to set up multi-cluster Layer 4 load balancing across workloads deployed on multiple member clusters.
ms.topic: how-to
ms.date: 03/20/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - devx-track-azurecli
---

# Set up DNS load balancing across Azure Kubernetes Fleet Manager member clusters (preview)

For applications deployed across multiple clusters, admins often want to route incoming traffic to them across clusters.

You can follow this document to set up layer 4 load balancing for such multi-cluster applications.

[!INCLUDE [preview features note](./includes/preview/preview-callout-data-plane-network-alpha.md)]

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-dns-load-balancing.md), which provides an explanation of `TrafficManagerProfile` and `TrafficManagerBackend` objects referenced in this document.

* A Kubernetes Fleet Manager with a hub cluster and managed identity. If you don't have one, see [Create an Azure Kubernetes Fleet Manager and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).

* The user completing the configuration has permissions to perform Azure role assignments and to access the Fleet Manager hub cluster Kubernetes API. See [Access the Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md) for more details.

* A namespace already deployed on the Fleet Manager hub cluster.

* An existing Azure resource group that the Azure Traffic Manager resource will be provisioned into. 

* Set the following environment variables:

    ```bash
    export SUBSCRIPTION_ID=<subscription>
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export MEMBER_CLUSTER_1=aks-member-1
    export MEMBER_CLUSTER_2=aks-member-2
    export TRAFFIC_MANAGER_GROUP=rg-flt-tm-demo
    export TRAFFIC_MANAGER_RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${TRAFFIC_MANAGER_GROUP}
    ```

* Obtain the kubeconfigs for the fleet and all member clusters:

    ```azurecli-interactive
    az fleet get-credentials --resource-group ${GROUP} --name ${FLEET} --file fleet

    az aks get-credentials --resource-group ${GROUP} --name ${MEMBER_CLUSTER_1} --file aks-member-1

    az aks get-credentials --resource-group ${GROUP} --name ${MEMBER_CLUSTER_2} --file aks-member-2
    ```

[!INCLUDE [preview features note](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

## Configure role assignment for Traffic Manager

During preview, you need to perform additional steps to enable Fleet Manager to create and manage Azure Traffic Manager resources. It is expected this step will be removed before general availability of this capability.

In order to complete this step you must have created your Fleet Manager with managed identity enabled.

* Obtain the identity information of your Fleet Manager resource.

    ```azurecli-interactive
    az fleet show \ 
        --resource-group ${GROUP} \
        --name ${FLEET} \
        --query identity
    ```

  Your output should look similar to the following example output:

    ```output
    {
      "principalId": "<FLEET-PRINCIPAL-ID>",
      "tenantId": "<ENTRA-ID-TENANT>",
      "type": "SystemAssigned",
      "userAssignedIdentities": null
    }
    ```

* Assign the Traffic Manager Contributor role to the Fleet Manager hub cluster identity, limiting the scope to the existing resource group.

    ```azurecli-interactive
    az role assignment create \
        --assignee "<FLEET-PRINCIPAL-ID>" \
        --role "Traffic Manager Contributor" \
        --scope ${TRAFFIC_MANAGER_RG_ID}
    ```

## Deploy a workload across member clusters of the Fleet resource

> [!NOTE]
>
> * The steps in this how-to guide refer to a sample application for demonstration purposes only. You can substitute this workload for any of your own existing Deployment and Service objects.
>
> * These steps deploy the sample workload from the Fleet cluster to member clusters using Kubernetes configuration propagation. Alternatively, you can choose to deploy these Kubernetes configurations to each member cluster separately, one at a time.

1. Create a namespace on the fleet cluster:

    ```bash
    KUBECONFIG=fleet kubectl create namespace kuard-demo
    ```

    Output looks similar to the following example:

    ```console
    namespace/kuard-demo created
    ```

1. Apply the Deployment, Service, ServiceExport objects:

    ```bash
    KUBECONFIG=fleet kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-export-service.yaml
    ```

    The `ServiceExport` specification in the above file allows you to export a service from member clusters to the Fleet resource. Once successfully exported, the service and all its endpoints are synced to the fleet cluster and can then be used to set up multi-cluster load balancing across these endpoints. The output looks similar to the following example:

    ```console
    deployment.apps/kuard created
    service/kuard created
    serviceexport.networking.fleet.azure.com/kuard created
    ```

1. Create the following `ClusterResourcePlacement` in a file called `crp-2.yaml`. Notice we're selecting clusters in the `eastus` region:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: kuard-demo
    spec:
      resourceSelectors:
        - group: ""
          version: v1
          kind: Namespace
          name: kuard-demo
      policy:
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      fleet.azure.com/location: eastus
    ```

1. Apply the `ClusterResourcePlacement`:

    ```bash
    KUBECONFIG=fleet kubectl apply -f crp-2.yaml
    ```

    If successful, the output looks similar to the following example:

    ```console
    clusterresourceplacement.placement.kubernetes-fleet.io/kuard-demo created
    ```

1. Check the status of the `ClusterResourcePlacement`:


    ```bash
    KUBECONFIG=fleet kubectl get clusterresourceplacements
    ```

    If successful, the output looks similar to the following example:

    ```console
    NAME            GEN   SCHEDULED   SCHEDULEDGEN   APPLIED   APPLIEDGEN   AGE
    kuard-demo      1     True        1              True      1            20s
    ```

## Create MultiClusterService to load balance across the service endpoints in multiple member clusters

1. Check whether the service is successfully exported for the member clusters in `eastus` region:

    ```bash
    KUBECONFIG=aks-member-1 kubectl get serviceexport kuard --namespace kuard-demo
    ```

    Output looks similar to the following example:

    ```console
    NAME    IS-VALID   IS-CONFLICTED   AGE
    kuard   True       False           25s
    ```

    ```bash
    KUBECONFIG=aks-member-2 kubectl get serviceexport kuard --namespace kuard-demo
    ```

    Output looks similar to the following example:

    ```console
    NAME    IS-VALID   IS-CONFLICTED   AGE
    kuard   True       False           55s
    ```

    You should see that the service is valid for export (`IS-VALID` field is `true`) and has no conflicts with other exports (`IS-CONFLICT` is `false`).

    > [!NOTE]
    > It may take a minute or two for the ServiceExport to be propagated.

1. Create `MultiClusterService` on one member to load balance across the service endpoints in these clusters:

    ```bash
    KUBECONFIG=aks-member-1 kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-mcs.yaml
    ```

    > [!NOTE]
    > To expose the service via the internal IP instead of public one, add the annotation to the MultiClusterService:
    >  
    > ```yaml
    > apiVersion: networking.fleet.azure.com/v1alpha1
    > kind: MultiClusterService
    > metadata:
    >   name: kuard
    >   namespace: kuard-demo
    >   annotations:
    >      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    >   ...
    > ```

    Output looks similar to the following example:

    ```console
    multiclusterservice.networking.fleet.azure.com/kuard created
    ```

1. Verify the MultiClusterService is valid by running the following command:

    ```bash
    KUBECONFIG=aks-member-1 kubectl get multiclusterservice kuard --namespace kuard-demo
    ```

    The output should look similar to the following example:

    ```console
    NAME    SERVICE-IMPORT   EXTERNAL-IP     IS-VALID   AGE
    kuard   kuard            <a.b.c.d>       True       40s
    ```

    The `IS-VALID` field should be `true` in the output. Check out the external load balancer IP address (`EXTERNAL-IP`) in the output. It may take a while before the import is fully processed and the IP address becomes available.

1. Run the following command multiple times using the external load balancer IP address:

    ```bash
    curl <a.b.c.d>:8080 | grep addrs 
    ```

    Notice that the IPs of the pods serving the request is changing and that these pods are from member clusters `aks-member-1` and `aks-member-2` from the `eastus` region. You can verify the pod IPs by running the following commands on the clusters from `eastus` region:

    ```bash
    KUBECONFIG=aks-member-1 kubectl get pods -n kuard-demo -o wide
    ```

    ```bash
    KUBECONFIG=aks-member-2 kubectl get pods -n kuard-demo -o wide
    ```
