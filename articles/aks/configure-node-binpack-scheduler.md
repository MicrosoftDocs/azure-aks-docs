---
title: Bin Pack Nodes with Scheduler Profiles on Azure Kubernetes Service (AKS) (preview)
description: Learn how to configure scheduler profiles to reduce idle costs and improve node utilization on Azure Kubernetes Service (AKS).
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 03/04/2026
ms.author: colinmixon
author: colinmixon
# Customer intent: "As a Kubernetes cluster operator, I want to improve node utilization by scheduling more pods on provisioined nodes using one or more configurable bin packing profiles, so that I can effectively manage provisioned resources across my AKS clusters."
---

# Bin Pack Nodes with scheduler profiles on Azure Kubernetes Service (AKS) (preview)

In this article, you learn how to bin pack your nodes to improve node utilization by deploying three different scheduler profiles in Azure Kubernetes Service (AKS) using in-tree scheduling plugins. The default AKS scheduler operates in a LestAllocated mode which ensures pods are placed nodes with lower utilization. The AKS configurable scheduler profiles allows you to change this default behavior. This documentation will cover three different scheduler profiles while highlighting the best practice recommendation to improve utilization while reducing node hot spots.  

Node bin-packing is a scheduling strategy that maximizes resource utilization by increasing pod density on nodes. Bin packing helps improve cluster efficiency by minimizing wasted resources and lowering the operational cost of maintaining idle or underutilized nodes. Improving node utilization is critical as data shows that CPU and memory are both over-requested resources. Additionally, as GPU usage increases, utilization of accelerators is also critical given resource scarcity.

## Limitations

- AKS currently doesn't manage the deployment of third-party schedulers or out-of-tree scheduling plugins.
- AKS doesn't support in-tree scheduling plugins targeting the `aks-system` scheduler. This restriction is in place to help prevent unexpected changes to AKS add-ons enabled on your cluster. Additionally, you can't define a `profile` called `aks-system`.

## Prerequisites

- The Azure CLI version `2.76.0` or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- Kubernetes version `1.33` or later running on your AKS cluster.
- The [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) version `18.0.0b27` or later.
- [Register the `UserDefinedSchedulerConfigurationPreview` feature flag](#register-the-user-defined-scheduler-configuration-preview-feature-flag) in your Azure subscription.
- Review the [supported advanced scheduling concepts](./concepts-scheduler-configuration.md) and in-tree scheduling plugins on AKS.

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

## Configure node bin-packing with RequestedtoCapacity Plugin

Of the three profiles, `RequestedToCapacityRatio` provides the most granular control of how nodes are scored based on specific resource utilization. For this reason this is the best practice recommendation for node bin backing on AKS. The CRD must be named `upstream`.

  - `NodeResourcesFit` ensures that the scheduler checks if a node has enough resources to run the pod. 
  - `scoringStrategy: RequestedToCapacityRatio` tells the scheduler to prefer nodes with high CPU resource usage. This helps achieve **better resource utilization** by placing new pods on nodes that are already "highly used".
  - `Resources` specifies that `CPU` is the primary resource being considered for scoring, and with a weight of `8`, nodes with CPU usage are scored 8x higher than memory during the score cycle. This increases the likelihood that nodes with high utilization are selected for a given pod.
  - `shape:` type applies the default constraints as a list of rules. The scheduler uses the rules in the order they're defined, and they apply to all pods that don’t specify custom topology spread constraints.

1. Create a file named `bin-packing-scheduler.yaml`, with the CRD named `upstream`, and paste in the following manifest:

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
      - schedulerName: cpu-binpack-scheduler-RtC
        plugins:
          multiPoint:
            enabled:
              - name: NodeResourcesFit
            disabled:
              - name: PodTopologySpread
        pluginConfig:
          - name: NodeResourcesFit
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesFitArgs
              scoringStrategy:
                type: RequestedToCapacityRatio
                resources:
                  - name: cpu
                    weight: 8
                  - name: memory
                    weight: 1
                requestedToCapacityRatio:
                  shape:
                    - utilization: 0
                      score: 0
                    - utilization: 10
                      score: 8
                    - utilization: 30
                      score: 9
                    - utilization: 50
                      score: 10
                    - utilization: 80
                      score: 10
                    - utilization: 90
                      score: 5
                    - utilization: 100
                      score: 1
```

## Configure node bin-packing with MostAllocated Plugin
In this example, the configured scheduler prioritizes scheduling pods on nodes with high CPU usage. Explicitly, this configuration avoids underutilizing nodes that still have free resources and helps to make better use of the resources already allocated to nodes. The CRD must be named `upstream`.

  - `NodeResourcesFit` ensures that the scheduler checks if a node has enough resources to run the pod. 
  - `scoringStrategy: MostAllocated` tells the scheduler to prefer nodes with high CPU resource usage. This helps achieve **better resource utilization** by placing new pods on nodes that are already "highly used".
  - `Resources` specifies that `CPU` is the primary resource being considered for scoring, and with a weight of `8`, nodes with higher CPU usage are scored 8x the value of nodes with mmeroy usage during the scoring cycle in the scheduling decision.

1. Create a file named `binpack-cpu-scheduler.yaml`, with the CRD named `upstream`, and paste in the following manifest:

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
      - schedulerName: cpu-binpack-scheduler-mA
        plugins:
          multiPoint:
            enabled:
              - name: NodeResourcesFit
            disabled:
              - name: PodTopologySpread
        pluginConfig:
          # NodeResourcesFit configuration
          - name: NodeResourcesFit
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesFitArgs
              scoringStrategy:
                type: MostAllocated
                resources:
                  - name: cpu
                    weight: 8
                  - name: memory
                    weight: 1
```

## Configure node bin-packing with MostAllocated and ResourceBalancedAllocation Plugins

This configuration looks to achieve a middle ground between RequestedtoCapacity and MostAllocated by scoreing nodes based on additional resources and their asymetric utilization. The CRD must be named `upstream`.

  - `NodeResourcesBalancedAllocation` 

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
      - schedulerName: cpu-binpack-scheduler-mA-BalancedAllocation
        plugins:
          multiPoint:
            enabled:
              - name: NodeResourcesFit
              - name: ResourceBalancedAllocation
            disabled:
              - name: PodTopologySpread
        pluginConfig:
          # NodeResourcesFit configuration
          - name: NodeResourcesFit
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesFitArgs
              scoringStrategy:
                type: MostAllocated
                resources:
                  - name: cpu
                    weight: 8
                  - name: memory
                    weight: 1
          - name: NodeResourcesBalancedAllocation
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesBalancedAllocationArgs
              resources:
                - name: cpu
                  weight: 1
                - name: memory
                  weight: 1
```

## Assign a scheduler profile to an entire AKS cluster

1. Apply the scheduling configuration manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f cpu-bin-packing-scheduler.yaml
    ```

2. To target this scheduling mechanism for specific workloads, update your pod deployments with the following `schedulerName`:

    ```yaml
    ...
    ...
        spec:
          schedulerName: binpacking-scheduler
    ...
    ...
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


## Next steps

To learn more about the AKS scheduler, other configruations and best practices, see the following resources:

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

<!-- LINKS - external -->
[topology-spread-constraints/]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/



