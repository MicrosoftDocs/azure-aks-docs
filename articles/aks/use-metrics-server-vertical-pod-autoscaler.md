---
title: Configure Metrics Server VPA in Azure Kubernetes Service (AKS)
description: Learn how to vertically autoscale your Metrics Server pods on an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.date: 08/12/2025
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: As a Kubernetes administrator, I want to configure the Vertical Pod Autoscaler for the Metrics Server on my Azure Kubernetes Service cluster, so that I can optimize resource allocation and ensure consistent performance without manual intervention.
---

# Configure Metrics Server VPA in Azure Kubernetes Service (AKS)

[Metrics Server][metrics-server-overview] is a scalable, efficient source of container resource metrics for Kubernetes built-in autoscaling pipelines. With Azure Kubernetes Service (AKS), vertical pod autoscaling is enabled for the Metrics Server. The Metrics Server is commonly used by other Kubernetes add-ons, like the [Horizontal Pod Autoscaler][horizontal-pod-autoscaler].

Vertical Pod Autoscaler (VPA) enables you to adjust the resource limit when the Metrics Server is experiencing consistent CPU and memory resource constraints.

## Prerequisites

- An AKS cluster with Kubernetes version 1.24 or higher.
- The Kubernetes command-line tool `kubectl` installed on your computer or use Azure Cloud Shell to run `kubectl` commands.


## Get credentials

To run the `kubectl` commands, you need your AKS credentials merged into your profile's `.kube/config` file. Replace `<resourceGroupName>` and `<clusterName>` with your cluster's values.

   ```azurecli
   az aks get-credentials --resource-group <resourceGroupName> --name <clusterName>
   ``` 

## Metrics server throttling

If the Metrics Server throttling rate is high, and the memory usage of its two pods is unbalanced, it's an indication that the Metrics Server needs more resources than the default values.

To update the coefficient values, create a `ConfigMap` in the overlay `kube-system` namespace to override the values in the Metrics Server specification. Perform the following steps to update the metrics server.

1. Create a `ConfigMap` file named _metrics-server-config.yaml_ and copy the manifest code into the file.

    ```yml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: metrics-server-config
      namespace: kube-system
      labels:
        kubernetes.io/cluster-service: "true"
        addonmanager.kubernetes.io/mode: EnsureExists
    data:
      NannyConfiguration: |-
        apiVersion: nannyconfig/v1alpha1
        kind: NannyConfiguration
        baseCPU: 100m
        cpuPerNode: 1m
        baseMemory: 100Mi
        memoryPerNode: 8Mi
    ```

    In the `ConfigMap` example, the resource limit and request are changed to the following values where `n` is the number of nodes:

    - cpu: (100+1n) millicores
    - memory: (100+8n) mebibytes

    If you're using Cloud Shell, use **Manage files** and select **Upload** so the file is available in your Bash session. 

1. Create the `ConfigMap` using the [kubectl apply][kubectl-apply] command and specify the name of your YAML manifest:

   ```bash
   kubectl apply -f metrics-server-config.yaml
   ```

1. Restart the two Metrics Server pods using [kubectl rollout restart][kubectl-rollout]. The following command deletes both pods and new pods are created.

   ```bash
   kubectl rollout restart -n kube-system deployment metrics-server
   ```

   The new Metrics Server pods are created before the old pods are terminated so there isn't downtime.

1. List the pods using [kubectl get][kubectl-get] to get the new Metrics Server pod names that are used in the next command.

   ```bash
   kubectl get pods --namespace kube-system
   ```

   ```output
   NAME                              READY   STATUS   RESTARTS       AGE
   metrics-server-1a2b333c44-wxyz5   2/2     Running  0              15s
   metrics-server-1a2b333c44-abcd6   2/2     Running  0              15s
   ```

   If you notice a third Metrics Server pod with a longer age value, it's because the termination occurs after the new pods are available. 

1. To verify the updated resources took effect for each pod, run the following command to review the Metrics Server VPA log. Replace `<metrics-server-pod-name>` with the name of each of your metrics server pods.

   ```bash
   kubectl -n kube-system logs <metrics-server-pod-name> -c metrics-server-vpa
   ```

   The following example output resembles the results showing the updated throttling settings were applied.

   ```output
   I0811 19:08:34.930865       1 pod_nanny.go:86] Invoked by [/pod_nanny --config-dir=/etc/config --cpu=150m --extra-cpu=0.5m --memory=100Mi --extra-memory=4Mi --poll-period=180000 --threshold=5 --deployment=metrics-server --container=metrics-server]
   I0811 19:08:34.931128       1 pod_nanny.go:87] Version: 1.8.23
   I0811 19:08:34.931200       1 pod_nanny.go:109] Watching namespace: kube-system, pod: <metrics-server-pod-name>, container: metrics-server.
   I0811 19:08:34.931249       1 pod_nanny.go:110] storage: MISSING, extra_storage: 0Gi
   I0811 19:08:34.932085       1 pod_nanny.go:144] cpu: 100m, extra_cpu: 1m, memory: 100Mi, extra_memory: 8Mi
   I0811 19:08:34.932177       1 pod_nanny.go:278] Resources: [{Base:{i:{value:100 scale:-3} d:{Dec:<nil>} s:100m Format:DecimalSI} ExtraPerResource:{i:{value:1 scale:-3} d:{Dec:<nil>} s:1m Format:DecimalSI} Name:cpu} {Base:{i:{value:104857600 scale:0} d:{Dec:<nil>} s:100Mi Format:BinarySI} ExtraPerResource:{i:{value:8388608 scale:0} d:{Dec:<nil>} s: Format:BinarySI} Name:memory}]
   ```

Be cautious of the `baseCPU`, `cpuPerNode`, `baseMemory`, and the `memoryPerNode`, because AKS doesn't validate the `ConfigMap`. As a recommended practice, increase the value gradually to avoid unnecessary resource consumption. Proactively monitor resource usage when updating or creating the `ConfigMap`. A large number of resource requests could negatively affect the node.

## Manually configure Metrics Server resource usage

The Metrics Server VPA adjusts resource usage by the number of nodes. If the cluster scales up or down often, the Metrics Server might restart frequently. In this case, you can bypass VPA and manually control its resource usage. This method to configure VPA isn't to be performed in addition to the steps described in the previous section.

If you would like to bypass VPA for Metrics Server and manually control its resource usage, perform the following steps.

1. Create a `ConfigMap` file named _metrics-server-config.yaml_ and copy in the following manifest.

    ```yml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: metrics-server-config
      namespace: kube-system
      labels:
        kubernetes.io/cluster-service: "true"
        addonmanager.kubernetes.io/mode: EnsureExists
    data:
      NannyConfiguration: |-
        apiVersion: nannyconfig/v1alpha1
        kind: NannyConfiguration
        baseCPU: 100m
        cpuPerNode: 0m
        baseMemory: 100Mi
        memoryPerNode: 0Mi
    ```

   In this `ConfigMap` example, the resource limit and request are changed to the following values that don't trigger autoscaling:

   - cpu: 100 millicores
   - memory: 100 mebibytes

   If you're using Cloud Shell, use **Manage files** and select **Upload** so the file is available in your Bash session. 

1. Create the `ConfigMap` using the [kubectl apply][kubectl-apply] command and specify the name of your YAML manifest:

   ```bash
   kubectl apply -f metrics-server-config.yaml
   ```

1. Restart the two Metrics Server pods using [kubectl rollout restart][kubectl-rollout]. The following command deletes both pods and new pods are created. 

   ```bash
   kubectl rollout restart -n kube-system deployment metrics-server
   ```

   The new Metrics Server pods are created before the old pods are terminated so there isn't downtime.

1. List the pods using [kubectl get][kubectl-get] to get the new Metrics Server pod names that are used in the next command.

   ```bash
   kubectl get pods --namespace kube-system
   ```

   ```output
   NAME                              READY   STATUS   RESTARTS       AGE
   metrics-server-1a2b333c44-wxyz5   2/2     Running  0              15s
   metrics-server-1a2b333c44-abcd6   2/2     Running  0              15s
   ```

   If you notice a third Metrics Server pod with a longer age value, it's because the termination occurs after the new pods are available. 

1. To verify the updated resources took effect for each pod, run the following command to review the Metrics Server VPA log. Replace `<metrics-server-pod-name>` with the name of each of your metrics server pods.

   ```bash
   kubectl -n kube-system logs <metrics-server-pod-name> -c metrics-server-vpa
   ```

   The following example output resembles the results showing the updated throttling settings were applied.

   ```output
   I0811 19:19:06.235018       1 pod_nanny.go:86] Invoked by [/pod_nanny --config-dir=/etc/config --cpu=150m --extra-cpu=0.5m --memory=100Mi --extra-memory=4Mi --poll-period=180000 --threshold=5 --deployment=metrics-server --container=metrics-server]
   I0811 19:19:06.235105       1 pod_nanny.go:87] Version: 1.8.23
   I0811 19:19:06.235136       1 pod_nanny.go:109] Watching namespace: kube-system, pod: <metrics-server-pod-name>, container: metrics-server.
   I0811 19:19:06.235171       1 pod_nanny.go:110] storage: MISSING, extra_storage: 0Gi
   I0811 19:19:06.235899       1 pod_nanny.go:144] cpu: 100m, extra_cpu: 0m, memory: 100Mi, extra_memory: 0Mi
   I0811 19:19:06.235917       1 pod_nanny.go:278] Resources: [{Base:{i:{value:100 scale:-3} d:{Dec:<nil>} s:100m Format:DecimalSI} ExtraPerResource:{i:{value:0 scale:-3} d:{Dec:<nil>} s: Format:DecimalSI} Name:cpu} {Base:{i:{value:104857600 scale:0} d:{Dec:<nil>} s:100Mi Format:BinarySI} ExtraPerResource:{i:{value:0 scale:0} d:{Dec:<nil>} s: Format:BinarySI} Name:memory}]
   ```

## Troubleshooting

### ConfigMap error

If you apply the following `ConfigMap`, the Metrics Server VPA customizations aren't applied. You need add a unit for `baseCPU` like `baseCPU: 100m` that includes the `m` unit.

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: metrics-server-config
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
data:
  NannyConfiguration: |-
    apiVersion: nannyconfig/v1alpha1
    kind: NannyConfiguration
    baseCPU: 100
    cpuPerNode: 1m
    baseMemory: 100Mi
    memoryPerNode: 8Mi
```

The following example output resembles the results showing the updated throttling settings aren't applied.

   ```output
   I0811 19:25:33.992691       1 pod_nanny.go:86] Invoked by [/pod_nanny --config-dir=/etc/config --cpu=150m --extra-cpu=0.5m --memory=100Mi --extra-memory=4Mi --poll-period=180000 --threshold=5 --deployment=metrics-server --container=metrics-server]
   I0811 19:25:33.992890       1 pod_nanny.go:87] Version: 1.8.23
   I0811 19:25:33.992918       1 pod_nanny.go:109] Watching namespace: kube-system, pod: <metrics-server-pod-name>, container: metrics-server.
   I0811 19:25:33.992937       1 pod_nanny.go:110] storage: MISSING, extra_storage: 0Gi
   I0811 19:25:33.993586       1 pod_nanny.go:217] Unable to decode Nanny Configuration from config map, using default parameters
   I0811 19:25:33.993602       1 pod_nanny.go:144] cpu: 150m, extra_cpu: 0.5m, memory: 100Mi, extra_memory: 4Mi
   I0811 19:25:33.993610       1 pod_nanny.go:278] Resources: [{Base:{i:{value:150 scale:-3} d:{Dec:<nil>} s:150m Format:DecimalSI} ExtraPerResource:{i:{value:5 scale:-4} d:{Dec:<nil>} s: Format:DecimalSI} Name:cpu} {Base:{i:{value:104857600 scale:0} d:{Dec:<nil>} s:100Mi Format:BinarySI} ExtraPerResource:{i:{value:4194304 scale:0} d:{Dec:<nil>} s:4Mi Format:BinarySI} Name:memory}]
   ```

### PodDisruptionBudget

For Kubernetes version 1.23 and higher clusters, Metrics Server has a `PodDisruptionBudget`. It ensures the number of available Metrics Server pods is at least one. If you get something like this after running `kubectl get pods --namespace kube-system`, it's possible that the customized resource usage is small. Increase the coefficient values to resolve it.

```output
metrics-server-1a2b333c44-wxyz5       1/2     CrashLoopBackOff   6 (36s ago)   6m33s
metrics-server-1a2b333c44-abcd6       1/2     CrashLoopBackOff   6 (54s ago)   6m33s
metrics-server-5d69966543-hcrff       2/2     Running            0             37m
```

## Next steps

Metrics Server is a component in the core metrics pipeline. For more information, see [Metrics Server API design][metrics-server-api-design].

<!-- EXTERNAL LINKS -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-rollout]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout
[metrics-server-overview]: https://kubernetes-sigs.github.io/metrics-server/
[metrics-server-api-design]: https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/

<!--- INTERNAL LINKS --->
[horizontal-pod-autoscaler]: concepts-scale.md#horizontal-pod-autoscaler



