---
title: Configure Autoscaling for CoreDNS in Azure Kubernetes Service (AKS)
description: Learn how to configure and customize CoreDNS autoscaling in Azure Kubernetes Service (AKS) clusters.
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
author: schaffererin
ms.topic: how-to
ms.date: 09/08/2025
ms.author: schaffererin
# Customer intent: As a cluster operator or developer, I want to learn how to configure and customize CoreDNS autoscaling in my AKS cluster to ensure optimal DNS performance and resource utilization.
---

# Autoscaling CoreDNS in Azure Kubernetes Service (AKS)

This article explains how to configure and customize CoreDNS autoscaling in Azure Kubernetes Service (AKS) clusters.

## Configure CoreDNS horizontal pod scaling

Due to the elastic nature of AKS, it's common to experience sudden spikes in DNS traffic within your clusters. These spikes can lead to an increase in memory consumption by CoreDNS pods. In some cases, this increased memory consumption can cause `Out of memory` issues.

To preempt this issue, AKS clusters autoscale CoreDNS pods to reduce memory usage per pod. The default settings for this autoscaling logic are stored in the `coredns-autoscaler` ConfigMap. However, you might observe that the default autoscaling of CoreDNS pods isn't always aggressive enough to prevent `Out of memory` issues for your CoreDNS pods. In this case, you can directly modify the `coredns-autoscaler` ConfigMap. Keep in mind that simply increasing the number of CoreDNS pods without addressing the root cause of the `Out of memory` issue might only provide a temporary fix. If there's not enough memory available across the nodes where the CoreDNS pods are running, increasing the number of CoreDNS pods won't help. You might need to investigate further and implement appropriate solutions such as optimizing resource usage, adjusting resource requests and limits, or adding more memory to the nodes.

CoreDNS uses the [horizontal cluster proportional autoscaler][cluster-proportional-autoscaler] for pod autoscaling. You can edit the `coredns-autoscaler` to configure the scaling logic for the number of CoreDNS pods. The `coredns-autoscaler` ConfigMap currently supports two different ConfigMap key values: `linear` and `ladder`, which correspond to two supported control modes.

- The `linear` controller yields a number of replicas in [min,max] range equivalent to `max( ceil( cores * 1/coresPerReplica ) , ceil( nodes * 1/nodesPerReplica ) )`.
- The `ladder` controller calculates the number of replicas by consulting two different step functions, one for core scaling and another for node scaling, yielding the max of the two replica values.

For more information on the control modes and ConfigMap format, see the [upstream documentation][cluster-proportional-autoscaler-control-patterns].

> [!IMPORTANT]
> We recommend a minimum of _two_ CoreDNS pod replicas per cluster.

### View the current `coredns-autoscaler` ConfigMap

- Get the current `coredns-autoscaler` ConfigMap using the [`kubectl get configmaps`][kubectl-get] command.

    ```bash
    kubectl get configmap coredns-autoscaler --namespace kube-system --output yaml
     ```

    Your output should resemble the following example output:

    ```output
    apiVersion: v1
    data:
      ladder: '{"coresToReplicas":[[1,2],[512,3],[1024,4],[2048,5]],"nodesToReplicas":[[1,2],[8,3],[16,4],[32,5]]}'
    kind: ConfigMap
    metadata:
      name: coredns-autoscaler
      namespace: kube-system
      resourceVersion: "..."
      creationTimestamp: "..."
    ```

> [!NOTE]
> The configuration provided serves as a potential starting point, but you should customize the values based on your specific cluster requirements and DNS traffic patterns. One way to determine the appropriate number of replicas for your environment is to use the linear scaling formula: `replicas = max( ceil( cores * 1/coresPerReplica ) , ceil( nodes * 1/nodesPerReplica ) )` to determine replica counts based on core / node count in the cluster.

## CoreDNS vertical pod autoscaling behavior

CoreDNS uses the original provided resource requests/limits when enabling the [add-on autoscaling feature](./optimized-addon-scaling.md) to prevent service unavailability during the CoreDNS pod restart process.

The following table outlines the default requests/limits and request-to-limit ratios for the AKS CoreDNS add-on:

| Resource | Requests/limits | Request-to-limit ratio |
|----------|-----------------|------------------------|
| CPU      | `100 m / 3 cores`  | Approximately _1:30_|
| Memory   | `70 Mi / 500 Mi`    | Approximately _1:7_|

If the recommended CPU requests are _500 m_, VPA adjusts the CPU limits to _15_ to maintain this ratio. Similarly, if the recommended memory requests are _700 Mi_, VPA adjusts the memory limit to _5000 Mi_.

VPA sets CoreDNS CPU and memory limits to large values based on the VPA recommended CPU/Memory request and AKS defined request-to-limit ratio. These adjustments are beneficial for handling multiple requests during peak service times. The drawback is that CoreDNS might consume all the CPU and memory available resource on the node when the peak service time.

It's difficult to set a single ideal CPU and memory requests/limits value to meet the requirements of both large cluster and small cluster at the same time. By enabling optimized add-on scaling, you have the flexibility to customize the CoreDNS CPU and memory requests/limits or use VPA to autoscale CoreDNS to meet specific cluster requirements. Keep the following scenarios in mind when deciding whether to customize the resource configuration or use VPA:

- You're considering whether VPA is suitable for your CoreDNS service and want to only view the VPA recommendations. You can disable VPA for CoreDNS by enabling the override VPA update mode to _Off_ if you don't want VPA to automatically update the pods. [Customize the resource configuration in Deployment](./customize-resource-configuration.md) to set the CPU/Memory requests/limits to the value you prefer.
- You're considering using VPA but want to restrict the ratio of request-to-limit so VPA won't bump the CPU and Memory limit to large values at one time. You can customize resources in the Deployment and update the CPU and Memory requests/limits value to keep the ratio of request-to-limit to _1:2_ or _1:3_.
- If a VPA container policy sets maxAllowed CPU and Memory, the recommended resource requests won't exceed those limits. Customizing the resource configuration allows you to increase or decrease the maxAllowed values and control the recommendations of VPA.

For more information, see [Enable add-on autoscaling on your AKS cluster (Preview)](./optimized-addon-scaling.md).

## Next steps

To learn how to troubleshoot CoreDNS issues, see [Troubleshoot issues with CoreDNS on Azure Kubernetes Service (AKS)](./coredns-troubleshoot.md).

<!-- LINKS -->
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[cluster-proportional-autoscaler]: https://github.com/kubernetes-sigs/cluster-proportional-autoscaler
[cluster-proportional-autoscaler-control-patterns]: https://github.com/kubernetes-sigs/cluster-proportional-autoscaler#control-patterns-and-configmap-formats
