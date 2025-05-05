---
title: "How to set up multi-cluster DNS load balancing across Azure Kubernetes Fleet Manager member clusters"
description: Learn how to use Azure Kubernetes Fleet Manager to set up multi-cluster Layer 4 and 7 load balancing for workloads deployed on multiple member clusters.
ms.topic: how-to
ms.date: 04/28/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Set up DNS load balancing across Azure Kubernetes Fleet Manager member clusters (preview)

Azure Kubernetes Fleet Manager DNS load balancing can help increase availability and spread load across a workload deployed across multiple member clusters. As this capability is delivered via DNS, it can be used to provide layer 4 and 7 load balancing as required.

Follow the steps in this document to set up DNS-based load balancing for multi-cluster applications hosted in your fleet.

[!INCLUDE [preview features note](./includes/preview/preview-callout-data-plane-network.md)]

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-dns-load-balancing.md), which provides an explanation of `TrafficManagerProfile` and `TrafficManagerBackend` objects referenced in this document.

* A Kubernetes Fleet Manager with a hub cluster and managed identity. If you don't have one, see [Create an Azure Kubernetes Fleet Manager and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).

* Two member clusters `aks-member-1` and `aks-member-2` onto which you deploy the same workload using Fleet Manager's [cluster resource placement (CRP)](./intelligent-resource-placement.md).

* The user completing the configuration has permissions to perform Azure role assignments and to access the Fleet Manager hub cluster Kubernetes API. For more information, see [Access the Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md) for more details.

* An existing Azure resource group which will host the provisioned Azure Traffic Manager resource. 

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

* Obtain the credentials to access the Fleet Manager hub cluster Kubernetes API:

    ```azurecli-interactive
    az fleet get-credentials \
        --resource-group ${GROUP} \
        --name ${FLEET}
    ```

## Configure Fleet Manager permissions

During preview, you need to perform extra steps to enable Fleet Manager to create and manage Azure Traffic Manager resources and to obtain public IP addresses of services exposed on member clusters.

In order to complete this step, you must create your Fleet Manager with managed identity enabled. Your user must have Azure RBAC role assignment permissions. 

* Obtain the identity information of your Fleet Manager resource.

    ```azurecli-interactive
    az fleet show \ 
        --resource-group ${GROUP} \
        --name ${FLEET} \
        --query identity
    ```

  Your output should look similar to the example output:

    ```output
    {
      "principalId": "<FLEET-PRINCIPAL-ID>",
      "tenantId": "<ENTRA-ID-TENANT>",
      "type": "SystemAssigned",
      "userAssignedIdentities": null
    }
    ```

* Assign the `Traffic Manager Contributor` role to the Fleet Manager hub cluster identity, limiting the scope to the existing resource group where the Traffic Manager resource is created.

    ```azurecli-interactive
    az role assignment create \
        --assignee "<FLEET-PRINCIPAL-ID>" \
        --role "Traffic Manager Contributor" \
        --scope ${TRAFFIC_MANAGER_RG_ID}
    ```

* The Fleet Manager hub cluster identity also needs the Azure `Reader` role for any member cluster so Fleet Manager can read the public IP address for member clusters when they're added to a `TrafficMangerBackend` via a `ServiceExport`.

    ```azurecli-interactive
    az role assignment create \
        --assignee "<FLEET-PRINCIPAL-ID>" \
        --role "Reader" \
        --scope /full/path/to/member-cluster
    ```

## Deploy a workload across member clusters of the Fleet resource

> [!NOTE]
>
> * The steps in this how-to guide refer to a sample application for demonstration purposes only. You can substitute this workload for any of your own existing Deployment and Service objects.
>
> * These steps deploy the sample workload from the Fleet Manager hub cluster to member clusters using Fleet Manager's cluster resource placement (CRP). Alternatively, you can choose to deploy these Kubernetes configurations to each member cluster separately, one at a time.

1. Create a namespace on the Fleet Manager hub cluster.

    ```bash
    kubectl create namespace kuard-demo
    ```

    Output looks similar to:

    ```console
    namespace/kuard-demo created
    ```

1. Stage the Deployment, Service, ServiceExport objects to the Fleet Manager hub cluster by saving the following into a file called `kuard-export-service.yaml`:

    ```yml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: kuard
      namespace: kuard-demo
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: kuard
      template:
        metadata:
          labels:
            app: kuard
        spec:
          containers:
            - name: kuard
              image: gcr.io/kuar-demo/kuard-amd64:blue
              resources:
                requests:
                  cpu: 100m
                  memory: 128Mi
                limits:
                  cpu: 250m
                  memory: 256Mi
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: kuard-svc
      namespace: kuard-demo
      labels:
        app: kuard
    spec:
      selector:
        app: kuard
      ports:
        - protocol: TCP
          port: 80
          targetPort: 80
      type: LoadBalancer
    ---
    apiVersion: networking.fleet.azure.com/v1alpha1
    kind: ServiceExport
    metadata:
      name: kuard-export
      namespace: kuard-demo
    ```
    
    Stage the objects on the Fleet Manager hub cluster:

    ```bash
    kubectl apply -f kuard-export-service.yaml
    ```

    The `ServiceExport` specification in the sample allows you to export a service from member clusters to the Fleet Manager hub cluster. Once successfully exported, the service and all its endpoints are synced to the Fleet Manager hub cluster and can then be used to set up DNS load balancing across these endpoints. The output looks similar to the following example:

    ```console
    deployment.apps/kuard created
    service/kuard-svc created
    serviceexport.networking.fleet.azure.com/kuard-export created
    ```

1. Each service needs a unique DNS label so that it can be exposed via Azure Traffic Manager. Use a Fleet Manager cluster resource placement `ResourceOverride` to modify the service definition per member cluster to create a unique name based on the Azure region and cluster name. You need to create an override per cluster selector (in our example, per Azure region).

     ```yml
    apiVersion: placement.kubernetes-fleet.io/v1alpha1
    kind: ResourceOverride
    metadata:
      name: ro-kuard-demo-eastus
      namespace: kuard-demo
    spec:
      placement:
        name: crp-kuard-demo
      resourceSelectors:
        -  group: ""
           kind: Service
           version: v1
           name: kuard-svc
      policy:
        overrideRules:
          - clusterSelector:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      fleet.azure.com/location: eastus
            jsonPatchOverrides:
              - op: add
                path: /metadata/annotations
                value:
                  {"service.beta.kubernetes.io/azure-dns-label-name":"fleet-${MEMBER-CLUSTER-NAME}-eastus"}
    ```

    > [!NOTE]
    > "${MEMBER-CLUSTER-NAME}" is a resource placement override [reserved variable](./resource-override.md#reserved-variables-in-the-json-patch-override-value) which is replaced with the name of the member cluster at run time.
    
    ```bash
    kubectl apply -f ro-kuard-demo-eastus.yaml
    ```

1. Create the following Fleet Manager [cluster resource placement][fleet-crp] (CRP) in a file called `crp-dns-demo.yaml`. Notice we're selecting a maximum of two clusters in the `eastus` region:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp-dns-demo
    spec:
      resourceSelectors:
        - group: ""
          version: v1
          kind: Namespace
          name: kuard-demo
      policy:
        placementType: PickN
        numberOfClusters: 2
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      fleet.azure.com/location: eastus
    ```

    Apply the CRP:

    ```bash
    kubectl apply -f crp-dns-demo.yaml
    ```

    If successful, the output looks similar to:

    ```console
    clusterresourceplacement.placement.kubernetes-fleet.io/crp-dns-demo created
    ```

## Configure DNS load balancing with Azure Traffic Manager

1. Define the `TrafficManagerProfile` to define the parameters to be used by Traffic Manager and save it to the file `kuard-atm-demo.yaml`.

    ```yml
    apiVersion: networking.fleet.azure.com/v1beta1
    kind: TrafficManagerProfile
    metadata:
      name: kuard-atm-demo
      namespace: kuard-demo
    spec:
      resourceGroup: "rg-flt-tm-demo"
      monitorConfig:
        port: 80
    ```

    Apply the configuration:
    
    ```bash
    kubectl apply -f kuard-atm-demo.yaml
    ```

1. Define a corresponding `TrafficManagerBackend` that is used to group together exported `Service` entries from member clusters.

    ```yml
    apiVersion: networking.fleet.azure.com/v1beta1
    kind: TrafficManagerBackend
    metadata:
      name: kuard-atm-demo-backend
      namespace: kuard-demo
    spec:
      profile:
        name: "kuard-atm-demo"
      backend:
        name: "kuard-svc"
      weight: 100
    ```

    Apply the configuration:
    
    ```bash
    kubectl apply -f kuard-atm-demo-backend.yaml
    ```

1. Verify the service is available via Azure Traffic Manager by running the following command:

    ```bash
    nslookup kuard-atm-demo.trafficmanager.net
    ```

    The output should look similar to the following example:

    ```console
    Server:         10.X.X.254
    Address:        10.X.X.254#53
    
    Non-authoritative answer:
    Name:   kuard-atm-demo.trafficmanger.net
    Address: 123.X.X.16
    Name:   kuard-atm-demo.trafficmanger.net
    Address: 74.X.X.78
    Name:   kuard-atm-demo.trafficmanger.net
    Address: 173.X.X.164
    ```

1. Use a web browser to visit the URL and see how Kuard responds. Try flushing your DNS and retrying to see if you're served another service instance from another cluster.

:::image type="content" source="./media/howto-dns-load-balancing/fleet-dns-load-balance-kuard-sample.png" alt-text="A screenshot of a web page displaying details from the Kuard demo application." lightbox="./media/howto-dns-load-balancing/fleet-dns-load-balance-kuard-sample.png":::


<!-- INTERNAL LINKS -->
[fleet-crp]: ./concepts-resource-propagation.md