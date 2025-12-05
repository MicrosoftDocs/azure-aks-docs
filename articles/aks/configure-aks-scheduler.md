---
title: Configure Scheduler Profiles on Azure Kubernetes Service (AKS) (preview)
description: Learn how to set scheduler profiles to achieve advanced scheduling behaviors on Azure Kubernetes Service (AKS).
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 09/30/2025
ms.author: sachidesai
author: sachidesai
# Customer intent: "As a Kubernetes cluster operator, I want to implement advanced scheduling strategies using one or more configurable profiles, so that I can effectively manage workload distribution and resource allocation across my AKS clusters."
---

# Configure advanced scheduler profiles on Azure Kubernetes Service (AKS) (preview)

In this article, you learn how to deploy example scheduler profiles in Azure Kubernetes Service (AKS) to configure advanced scheduling behavior using in-tree scheduling plugins. This guide also explains how to verify the successful application of custom scheduler profiles targeting specific node pools or the entire AKS cluster.



## Limitations

- AKS currently doesn't manage the deployment of third-party schedulers or out-of-tree scheduling plugins.
- AKS doesn't support in-tree scheduling plugins targeting the `aks-system` scheduler. This restriction is in place to help prevent unexpected changes to AKS add-ons enabled on your cluster.

## Prerequisites

- The Azure CLI version `2.76.0` or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- Kubernetes version `1.33` or later running on your AKS cluster.
- The [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) version `18.0.0b27` or later.
- [Register the `UserDefinedSchedulerConfigurationPreview` feature flag](#register-the-user-defined-scheduler-configuration-preview-feature-flag) in your Azure subscription.
- Review the [supported advanced scheduling concepts](./concepts-scheduler-configuration.md) and in-tree scheduling plugins on AKS.


### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Install the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.


    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the `aks-preview` extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.


    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the User Defined Scheduler Configuration Preview feature flag

1. Register the `UserDefinedSchedulerConfigurationPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

## Enable scheduler profile configuration on an AKS cluster

You can enable schedule profile configuration on a new or existing AKS cluster.

### [Enable on a new cluster](#tab/new-cluster)

1. Create an AKS cluster with scheduler profile configuration enabled using the [`az aks create`][az-aks-create] command with the `--enable-upstream-kubescheduler-user-configuration` flag.
    
    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<aks-cluster-name>
    
    # Create an AKS cluster with schedule profile configuration enabled
    az aks create \
    --resource-group $RESOURCE_GROUP \ 
    --name $CLUSTER_NAME \
    --enable-upstream-kubescheduler-user-configuration \
    --generate-ssh-keys
    ```

1. Once the creation process completes, connect to the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

### [Enable on an existing cluster](#tab/existing-cluster)

- Enable scheduler profile configuration on an existing cluster using the [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    # Set environment variables
    export SUBSCRIPTION_ID=<subscription-id>
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<aks-cluster-name>

    # Enable schedule profile configuration on an existing AKS cluster
    az aks update --subscription="${SUBSCRIPTION_ID}" \
    --resource-group="${RESOURCE_GROUP}" \
    --name="${CLUSTER_NAME}" \
    --enable-upstream-kubescheduler-user-configuration
    ```

---



## Verify installation of the scheduler controller

- After enabling the feature on your AKS cluster, verify the custom resource definition (CRD) of the scheduler controller was successfully installed using the `kubectl get` command.

    ```bash
    kubectl get crd schedulerconfigurations.aks.azure.com
    ```

    > [!NOTE]
    > This command won't succeed if the feature wasn't successfully enabled in the [previous section](#enable-scheduler-profile-configuration-on-an-aks-cluster).

## Configure node bin-packing 

Node bin-packing is a scheduling strategy that maximizes resource utilization by increasing pod density on nodes, within the set configuration. This strategy helps improve cluster efficiency by minimizing wasted resources and lowering the operational cost of maintaining idle or underutilized nodes.

In this example, the configured scheduler prioritizes scheduling pods on nodes with high CPU usage. Explicitly, this configuration avoids underutilizing nodes that still have free resources and helps to make better use of the resources already allocated to nodes. 

1. Create a file named `aks-scheduler-customization.yaml` and paste in the following manifest:

    ```yaml
    apiVersion: aks.azure.com/v1alpha1
    kind: SchedulerConfiguration
    metadata:
      name: upstream
    spec:
      rawConfig: |
        apiVersion: kubescheduler.config.k8s.io/v1
        kind: KubeSchedulerConfiguration
        profiles:
      - schedulerName: node-binpacking-scheduler
        pluginConfig:
        - name: NodeResourcesFit
          args:
            scoringStrategy:
              type: MostAllocated
              resources:
              - name: cpu
                weight: 1
    ```

    - `NodeResourcesFit` ensures that the scheduler checks if a node has enough resources to run the pod. 
    - `scoringStrategy: MostAllocated` tells the scheduler to prefer nodes with high CPU resource usage. This helps achieve **better resource utilization** by placing new pods on nodes that are already "highly used".
    - `Resources` specifies that `CPU` is the primary resource being considered for scoring, and with a weight of `1`, CPU usage is prioritized with a relatively equal level of importance in the scheduling decision.

1. Apply the scheduling configuration manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

1. To target this scheduling mechanism for specific workloads, update your pod deployments with the following `schedulerName`:

    ```yaml
    ...
    ...
        spec:
          schedulerName: node-binpacking-scheduler
    ...
    ...
    ```


## Configure pod topology spread

Pod topology spread is a scheduling strategy that seeks to distribute pods evenly across failure domains (such as availability zones or regions) to ensure high availability and fault tolerance in the event of zone or node failures. This strategy helps prevent the risk of all replicas of a pod being placed in the same failure domain. For more configuration guidance, see the [Kubernetes Pod Topology Spread Constraints documentation] (https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/).

1. Create a file named `aks-scheduler-customization.yaml` and paste in the following manifest:

    ```yaml
    apiVersion: aks.azure.com/v1alpha1
    kind: SchedulerConfiguration
    metadata:
      name: upstream
    spec:
      rawConfig: |
        apiVersion: kubescheduler.config.k8s.io/v1
        kind: KubeSchedulerConfiguration
        profiles:
        - schedulerName: pod-distribution-scheduler
          - pluginConfig:
              - name: PodTopologySpread
                args:
                  apiVersion: kubescheduler.config.k8s.io/v1
                  kind: PodTopologySpreadArgs
                  defaultingType: List
                  defaultConstraints:
                    - maxSkew: 1
                      topologyKey: topology.kubernetes.io/zone
                      whenUnsatisfiable: ScheduleAnyway
    ```

    - `PodTopologySpread` plugin instructs the scheduler to try and distribute pods as evenly as possible across availability zones. 
    - `whenUnsatisfiable: ScheduleAnyway` specifies schedule to schedule pods despite the inability to meet the topology constraints. This avoids pod scheduling failures when exact distribution isn't feasible.
    -  `List` type applies the default constraints as a list of rules. The scheduler uses the rules in the order they're defined, and they apply to all pods that don’t specify custom topology spread constraints.
    -  `maxSkew: 1` means the number of pods can differ by at most _1_ between any two zones.
    -  `topologyKey: topology.kubernetes.io/zone` indicates that the scheduler should spread pods across availability zones.

1. Apply the scheduling configuration manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

1. To target this scheduling mechanism for specific workloads, update your pod deployments with the following `schedulerName`:

    ```yaml
    ...
    ...
        spec:
          schedulerName: pod-distribution-scheduler
    ...
    ...
    ```


## Assign a scheduler profile to an entire AKS cluster

1. In your scheduler profile configuration, update the `schedulerName` field as follows:

    ```yaml
    ...
    ...
    `- schedulerName: default_scheduler` 
    ...
    ...
    ```

1. Reapply the manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

    Now, this configuration will become the **default** scheduling operation for your entire AKS cluster.


## Configure multiple scheduler profiles

You can customize the upstream scheduler with multiple profiles and customize each profile with multiple plugins while using the same configuration file. In the following example, we create two scheduling profiles called **scheduler-one** and **scheduler-two**:

- **scheduler-one** prioritizes placing pods across zones and nodes for balanced distribution with the following settings:

     - Enforces strict zonal distribution and _preferred_ node distribution using `PodTopologySpread`.
     - Honors hard pod affinity rules and considers the soft affinity rules with `InterPodAffinity`.
     -  _Prefers_ nodes in specific zones to reduce cross-zone networking using `NodeAffinity`.

- **scheduler-two** prioritizes placing pods on nodes with available storage, CPU, and memory resources for timely resource-efficient resource usage with the following settings:

    - Ensures pods are placed on nodes where PVCs can bind to PVs using `VolumeBinding`.
    - Validates that nodes and volumes satisfy zonal requirements using `VolumeZone` to avoid cross-zone storage access.
    - Prioritizes nodes based on CPU, memory, and ephemeral storage utilization, with `NodeResourcesFit`.
    - Favors nodes that already have the required container images using `ImageLocality`.

> [!NOTE] 
> You might need to adjust zones and other parameters based on your workload type.

1. Create a file named `aks-scheduler-customization.yaml` and paste in the following manifest:

    ```yaml
    apiVersion: aks.azure.com/v1alpha1
    kind: SchedulerConfiguration
    metadata:
      name: upstream
    spec:
      rawConfig: |
        apiVersion: kubescheduler.config.k8s.io/v1
        kind: KubeSchedulerConfiguration
        percentageOfNodesToScore: 40
        podInitialBackoffSeconds: 1
        podMaxBackoffSeconds: 8
        profiles:
          - schedulerName: scheduler-one
            plugins:
              multiPoint:
                enabled:
                  - name: PodTopologySpread
                  - name: InterPodAffinity
                  - name: NodeAffinity
            pluginConfig:
              # PodTopologySpread with strict zonal distribution        
              - name: PodTopologySpread
                args:
                  defaultingType: List
                  defaultConstraints:
                    - maxSkew: 2
                      topologyKey: topology.kubernetes.io/zone
                      whenUnsatisfiable: DoNotSchedule
                    - maxSkew: 1
                      topologyKey: kubernetes.io/hostname
                      whenUnsatisfiable: ScheduleAnyway                  
              - name: InterPodAffinity
                args:
                  hardPodAffinityWeight: 1
                  ignorePreferredTermsOfExistingPods: false
              - name: NodeAffinity
                args:
                  addedAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                      - weight: 100
                        preference:
                          matchExpressions:
                            - key: topology.kubernetes.io/zone
                              operator: In
                              values: [westus3-1, westus3-2, westus3-3]
          - schedulerName: scheduler-two
            plugins:
              multiPoint:
                enabled:
                  - name: VolumeBinding
                  - name: VolumeZone
                  - name: NodeAffinity
                  - name: NodeResourcesFit
                  - name: PodTopologySpread
                  - name: ImageLocality
            pluginConfig:
              - name: PodTopologySpread
                args:
                  defaultingType: List
                  defaultConstraints:
                    - maxSkew: 1
                      topologyKey: kubernetes.io/hostname
                      whenUnsatisfiable: DoNotSchedule 
              - name: VolumeBinding
                args:
                  apiVersion: kubescheduler.config.k8s.io/v1
                  kind: VolumeBindingArgs
                  bindTimeoutSeconds: 300
              - name: NodeAffinity
                args:
                  apiVersion: kubescheduler.config.k8s.io/v1
                  kind: NodeAffinityArgs
                  addedAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                      - weight: 100
                        preference:
                          matchExpressions:
                            - key: topology.kubernetes.io/zone
                              operator: In
                              values: [westus3-1, westus3-2]
              - name: NodeResourcesFit
                args:
                  apiVersion: kubescheduler.config.k8s.io/v1
                  kind: NodeResourcesFitArgs
                  scoringStrategy:
                    type: MostAllocated
                    resources:
                      - name: cpu
                        weight: 3
                      - name: memory
                        weight: 1
                      - name: ephemeral-storage
                        weight: 2
    ```

1. Apply the manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```


## Disable an AKS scheduler profile configuration

1. To disable the AKS scheduler profile configuration and revert to AKS scheduler default configuration on the cluster, first delete the `schedulerconfiguration` resource using the `kubectl delete` command.

    ```bash
    kubectl delete schedulerconfiguration upstream || true
    ```

    > [!NOTE]
    > Ensure that the previous step is complete and confirm that the `schedulerconfiguration` resource was deleted before proceeding to disable this feature.

1. Disable the feature using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-upstream-kubescheduler-user-configuration` flag.

    ```azurecli-interactive
    az aks update --subscription="${SUBSCRIPTION_ID}" \
    --resource-group="${RESOURCE_GROUP}" \
    --name="${CLUSTER_NAME}" \
    --disable-upstream-kubescheduler-user-configuration
    ```

1. Verify the feature is disabled using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show --resource-group="${RESOURCE_GROUP}" \
    --name="${CLUSTER_NAME}" \
    --query='properties.schedulerProfile'
    ```


    Your output should indicate that the feature is no longer enabled on your AKS cluster.

## Frequently asked questions (FAQ)

### What happens if I apply misconfigured scheduler profile to my AKS cluster?

Once you apply a scheduler profile, AKS checks if it contains a valid configuration of plugins and arguments. If the configuration targets a disallowed scheduler or sets the in-tree scheduling plugins improperly, AKS rejects the configuration and reverts to the last known "accepted" scheduler configuration. This check aims to limit impact on new and existing AKS clusters due to scheduler misconfiguration.

### How can I monitor and validate that the scheduler honored my configuration?

There are _three_ recommended methods for observing the results of your applied scheduler profile:

- View the AKS `kube-scheduler` control plane logs to ensure that the scheduler received the configuration from the CRD.
- Run the `kubectl get schedulerconfiguration` command. The output displays the status of the `configuration: pending` during the rollout and `Succeeded` or `Failed` after the configuration is accepted or rejected by the scheduler.
- Run the `kubectl describe schedulerconfiguration` command. The output displays a more detailed state of the scheduler, including any error during the reconciliation, and the current scheduler configuration in effect. 


## Next steps

To learn more about the AKS scheduler and best practices, see the following resources:

- [Azure Kubernetes Service (AKS) scheduler best practices](./operator-best-practices-scheduler.md)
- [Best practices for advanced scheduling policies](./operator-best-practices-advanced-scheduler.md)
- [Monitor your AKS resource metrics and logs](./monitor-aks.md)

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[aks-quickstart-cli]: ./learn/quick-windows-container-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-windows-container-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-windows-container-deploy-powershell.md
[install-azure-cli]: /cli/azure/install-azure-cli
[azureml-aks]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[azureml-deploy]: /azure/machine-learning/how-to-deploy-managed-online-endpoints
[azureml-triton]: /azure/machine-learning/how-to-deploy-with-triton
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add

[az-extension-update]: /cli/azure/extension#az-extension-update
