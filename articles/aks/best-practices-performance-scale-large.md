---
title: Performance and scaling best practices for large workloads in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn the best practices for performance and scaling for large workloads in Azure Kubernetes Service (AKS).
ms.topic: best-practice
ms.date: 04/17/2026
author: schaffererin
ms.author: schaffererin

# Customer intent: As a cloud architect, I want to implement performance and scaling best practices for large workloads in Kubernetes, so that I can ensure optimal resource utilization and reliability of the applications deployed in Azure Kubernetes Service.
---

# Best practices for performance and scaling for large workloads in Azure Kubernetes Service (AKS)

> [!NOTE]
> This article focuses on general best practices for **large workloads**. For best practices specific to **small to medium workloads**, see [Performance and scaling best practices for small to medium workloads in Azure Kubernetes Service (AKS)](./best-practices-performance-scale.md).

As you deploy and maintain clusters in AKS, you can use the following best practices to help you optimize performance and scaling.

Keep in mind that *large* is a relative term. Kubernetes has a multi-dimensional scale envelope, and the scale envelope for your workload depends on the resources you use. For example, a cluster with 100 nodes and thousands of pods or CRDs might be considered large. A 1,000 node cluster with 1,000 pods and various other resources might be considered small from the control plane perspective. The best signal for scale of a Kubernetes control plane is API server HTTP request success rate and latency, as that's a proxy for the amount of load on the control plane.

In this article, you learn about:

> [!div class="checklist"]
> - Node scaling.
> - AKS and Kubernetes control plane scalability.
> - Kubernetes client best practices, including backoff, watches, and pagination.
> - Azure API and platform throttling limits.
> - Feature limitations.
> - Networking best practices.

## Node scaling

As you scale your AKS clusters to larger scale points, keep the following node scaling best practices in mind:

- When running at-scale AKS clusters, use the [cluster autoscaler](./cluster-autoscaler.md) or [node auto-provisioning](./node-auto-provisioning.md) whenever possible to ensure dynamic scaling of nodes based on the demand for compute resources.
- If you're scaling beyond 1,000 nodes and are *not* using the cluster autoscaler, we recommend scaling in batches of 500-700 nodes at a time. The scaling operations should have a two-minute to five-minute wait time between scale up operations to prevent Azure API throttling. For more information, see [API management: Caching and throttling policies](https://azure.microsoft.com/blog/api-management-advanced-caching-and-throttling-policies/).
- For system node pools, use the *Standard_D16ds_v5* SKU or an equivalent core/memory VM SKU with ephemeral OS disks to provide sufficient compute resources for kube-system pods.
- Since AKS has a limit of 1,000 nodes per node pool, we recommend creating at least five user node pools to scale up to 5,000 nodes.

## AKS and Kubernetes control plane scalability

In Kubernetes, all objects running in a cluster are managed by the control plane, which is managed by AKS. While AKS optimizes the Kubernetes control plane and its components for scalability and performance, it's still bound by the upstream project limits.

Kubernetes has a multi-dimensional scale envelope, with each resource type representing a dimension, and not all resources are alike in their cost. For example, Secrets are often watched by multiple controllers and pods, each of which makes an initial LIST call to sync state. Because secrets are typically large and frequently updated, they place more load on the control plane than less frequently watched resources.

The more you scale the cluster within a given dimension, the less you can scale within other dimensions. For example, running hundreds of thousands of pods in an AKS cluster impacts how much pod churn rate (pod mutations per second) the control plane can support.

AKS supports three control plane tiers as part of the Base SKU: Free, Standard, and Premium tier. For more information, see [Free, Standard, and Premium pricing tiers for AKS cluster management](./free-standard-pricing-tiers.md).

> [!IMPORTANT]
>  Use Standard or Premium tier for production or at-scale workloads. AKS automatically scales up the Kubernetes control plane to support the following scale limits:
> - Up to 5,000 nodes per AKS cluster
> - 200,000 pods per AKS cluster (with Azure CNI Overlay)

In most cases, crossing the scale limit threshold results in degraded performance, but doesn't cause the cluster to immediately fail over. To manage load on the Kubernetes control plane, consider scaling in batches of up to 10-20% of the current scale. For example, for a 5,000 node cluster, scale in increments of 500-1,000 nodes. While AKS does autoscale your control plane, it doesn't happen instantaneously.  

To confirm if your control plane has been scaled up, look for the configmap `large-cluster-control-plane-scaling-status`.

```bash
kubectl describe configmap large-cluster-control-plane-scaling-status -n kube-system
```

## Kubernetes scale envelope and control plane considerations

Kubernetes clients are application components, such as operators or monitoring agents, that run in the cluster and communicate with the kube-apiserver to read or modify resources. It's important to optimize how these clients behave to reduce the load they place on the kube-apiserver and the Kubernetes control plane. 

The number of requests actively being processed by the API server at any given moment is determined by `--max-requests-inflight` and `--max-mutating-requests-inflight` flags. AKS uses the default values of 400 and 200 requests for these flags, allowing a total of 600 requests to be dispatched at a given time. As we scale the API server to larger sizes we correspondingly increase the inflight requests too.

Two Kubernetes object types, [PriorityLevelConfiguration and FlowSchema (APF)](https://kubernetes.io/docs/concepts/cluster-administration/flow-control/), determine how the API server divides total request capacity across request types. AKS uses the default configuration. 

Each PriorityLevelConfiguration is assigned a share of the total allowed requests. To view the PriorityLevelConfiguration objects in your cluster and their allocated request shares, run the following command.

```bash
kubectl get --raw /metrics | grep apiserver_flowcontrol_nominal_limit_seats
```
FlowSchema maps API server requests to a PriorityLevelConfiguration. If multiple FlowSchema objects match a request, the API server selects the one with the lowest matching precedence.

The mapping of FlowSchemas to PriorityLevelConfigurations can be viewed using this command:

```bash
kubectl get flowschemas
```

To confirm if any requests are being dropped due to APF, run the following command:

```bash
kubectl get --raw /metrics | grep apiserver_flowcontrol_rejected_requests_total
```

### Kubernetes client best practices

LIST calls issued by unoptimized clients are often one of the biggest factors limiting a cluster's scalability. When working with lists that might have more than a few thousand small objects or more than a few hundred large objects, you should consider the following guidelines:

- **Consider the number of objects (CRs) you expect to eventually exist** when defining a new resource type (CRD).
- **The load on etcd and API server primarily relies on the size of the response.** This guidance applies whether the client issues a small number of LIST requests for large objects or a large number of LIST requests for smaller objects.

#### Use informers

- If your code needs to maintain an updated list of objects in memory, using an [informer](https://pkg.go.dev/k8s.io/client-go/informers) from the client-go library will give you benefits of watching for changes to the resources based on events instead of polling for changes. This is the best approach to avoid unoptimized and repeated LISTs.

#### Use API server cache

- Use `resourceVersion=0` to return results from the API server cache. This can prevent objects being fetched from etcd thereby reducing etcd load, **but it doesn't support pagination**.

  ```
  /api/v1/namespaces/default/pods?resourceVersion=0
  ```
#### Efficient Kubernetes API usage

- It's recommended to use the watch argument whenever possible. With no arguments the default behavior is to list objects. Refer to the example below.
  
  ```
  /api/v1/namespaces/default/pods?watch=true
  ```
  
  Use watch with a `resourceVersion` set to be the most recent known value received from preceding list or watch. This is handled automatically in client-go. But verify if you are using a Kubernetes client in other languages.

  ```
  /api/v1/namespaces/default/pods?watch=true&resourceVersion=<resourceversion>
  ```

- If controllers or operators must use LIST calls, they should avoid polling cluster-wide resources without label or field selectors, especially in large clusters. The following examples show optimized and unoptimized LIST calls.

  **Optimized LIST:**
  
  ```
  /api/v1/namespaces/default/pods?fieldSelector=status.phase=Running
  ```
  
  **Unoptimized LIST:**
  
  ```
  /api/v1/pods
  ```

- **Use pagination** to reduce the size of LIST responses if the client must fetch data from etcd. The following example uses the limit argument to restrict the response to 100 objects.

  ```
  /api/v1/namespaces/default/pods?fieldSelector=status.phase=Running&limit=100
  ```
  
  If you want the LIST to continue returning all the pod objects in the example above use the continue argument with limit.
  
  ```
  /api/v1/namespaces/default/pods?fieldSelector=status.phase=Running&limit=100&continue=<continue_token>
  ```
  
  If kubectl is being utilized, `--chunk-size` argument can be directly applied to paginate responses.
  
  ```bash
  kubectl get pods -n default --chunk-size=100
  ```

- If your controllers or operators use lease updates for leader election, make sure they are resilient to transient connectivity issues by tuning `leaseDuration`, `renewDeadline`, and `retryPeriod` that are optimal for your workloads. For Kubernetes controllers that use client-go leader election, use the following formula:
 
  ``` 
  lease_duration > renew_deadline > retry_period
  ```

#### Daemonsets

- There is a significant difference between a single controller listing objects and a DaemonSet running on every node doing the same thing. If multiple instances of your client application periodically list large numbers of objects, the solution won't scale well in large clusters.
- On clusters with thousands of nodes, creating a new DaemonSet, updating a DaemonSet, or increasing the number of nodes can result in a high load placed on the control plane. If DaemonSet pods issue expensive API server requests on pod start-up, they can cause high resource use on the control plane from a large number of concurrent requests.
- Use a RollingUpdate strategy to roll out new DaemonSet pods gradually. When the DaemonSet template is updated, the controller replaces old pods with new ones in a controlled manner. When rolling update strategy isn't explicitly configured, Kubernetes will default to creating a RollingUpdate with maxUnavailable as 1, maxSurge as 0, and minReadySeconds as 0s. Refer to the following example.
  
  ```yaml
    minReadySeconds: 30
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 0
        maxUnavailable: 1
  ```
- The RollingUpdate strategy only applies to existing DaemonSet pods. It doesn't limit the impact of adding new nodes, which creates additional DaemonSet pods, or deploying entirely new DaemonSets.
- To prevent DaemonSets from issuing simultaneous LIST requests to the API server during startup after node scale-out or new DaemonSet deployments, implement startup jitter in the container entrypoint and configure appropriate [exponential backoff](https://pkg.go.dev/k8s.io/apimachinery/pkg/util/wait) and [retry policies](https://pkg.go.dev/k8s.io/client-go/util/retry) for 5xx or 429 responses to prevent repeated retry of large LIST requests.
  
  ```yaml
    spec:
      template:
        spec:
          containers:
          - name: my-daemonset-container
            image: <image>
            command: ["/bin/sh", "-c", "sleep $(( (RANDOM % 60) + 1 )); exec /path/to/your/app --args"]
  ```
> [!NOTE]
> You can analyze API server traffic and client behavior through Kube Audit logs. For more information, see [Troubleshoot the Kubernetes control plane](/troubleshoot/azure/azure-kubernetes/troubleshoot-apiserver-etcd).

### etcd optimizations

- **Keep the overall etcd size small and don't use etcd as a general-purpose database**. AKS provides 8 GB of etcd storage by default, but larger etcd databases increase defragmentation time, which can lead to read and write performance issues. Larger etcd databases can also increase the probability of API server and etcd reliability issues if an unoptimized client fetches large numbers of objects from etcd frequently. If your etcd database size exceeds 2 GB, consider using the object size reduction techniques listed below.
- To reduce pod specification sizes, move environment variables from pod specifications to ConfigMaps.
- Split large secrets or ConfigMaps into smaller, more manageable pieces.
- Store secrets in [Azure Key Vault](/azure/key-vault/general/overview) instead of Kubernetes Secrets when possible to reduce the number of secrets stored in etcd.
- Clean up unused objects
  - Delete stale Jobs and completed Pods. Use ttlSecondsAfterFinished on Jobs so finished objects are removed automatically.
  - Make sure controllers set ownerReferences. This enables Kubernetes garbage collection to remove dependent objects automatically when the parent resource is deleted.
  - Limit CronJob history by setting successfulJobsHistoryLimit and failedJobsHistoryLimit to keep only a small number of completed Job records.
  - Reduce Deployment rollout history. Old ReplicaSets are stored as API objects too. The default value is 10.
- Reduce Helm revision history with the `--history-max` argument. In large clusters, keep it below 5.

## Monitor AKS control plane metrics and logs

Monitoring control plane metrics in large AKS clusters is crucial for ensuring the stability and performance of Kubernetes workloads. These metrics provide visibility into the health and behavior of critical components like the API server, etcd, controller manager, and scheduler. In large-scale environments, where resource contention and high API call volumes are common, monitoring control plane metrics helps identify bottlenecks, detect anomalies, and optimize resource usage. By analyzing these metrics, operators can proactively address issues such as API server latency, high etcd objects, or excessive control plane resource consumption, ensuring efficient cluster operation and minimizing downtime.

Azure Monitor offers comprehensive metrics and logs on the health of the control plane through [Azure Managed Prometheus](./monitor-control-plane-metrics.md#monitor-aks-control-plane-metrics-preview) and [Diagnostic settings](./monitor-control-plane-metrics.md#azure-monitor-resource-logs).

- For a list of alerts to configure for health of the control plane, please check out [Best practices for AKS control plane monitoring](./best-practices-monitoring-proactive.md#kubernetes-control-plane-alerts)
- To get the list of user agents having the highest latency, you can use the [Control Plane logs/Diagnostic Settings](/troubleshoot/azure/azure-kubernetes/troubleshoot-apiserver-etcd)

### Key control plane platform metrics

AKS exposes the following platform metrics in Azure Monitor for monitoring API server and etcd health. These metrics are available without enabling Managed Prometheus and can be viewed directly in the Azure portal under **Metrics** for your AKS cluster.

**API Server metrics:**

| Metric | Description |
|---|---|
| `apiserver_cpu_usage_percentage` | Maximum CPU percentage (based off current limit) used by the API server pod across instances. |
| `apiserver_memory_usage_percentage` | Maximum memory percentage (based off current limit) used by the API server pod across instances. |
| `apiserver_current_inflight_requests` (Preview) | Maximum number of currently active inflight requests on the API server, per request kind. |

**Etcd metrics:**

| Metric | Description |
|---|---|
| `etcd_cpu_usage_percentage` | Maximum CPU percentage (based off current limit) used by the etcd pod across instances. |
| `etcd_memory_usage_percentage` | Maximum memory percentage (based off current limit) used by the etcd pod across instances. |
| `etcd_database_usage_percentage` | Maximum utilization of the etcd database across instances. Monitor this closely to avoid exceeding the etcd storage limit. |

Consistently monitor `apiserver_cpu_usage_percentage` and `apiserver_memory_usage_percentage` to detect resource pressure on the API server. If `etcd_database_usage_percentage` is consistently above 50%, review the [Etcd Optimizations](#etcd-optimizations) section to reduce database size. For the full list of available metrics, see [AKS monitoring data reference](/azure/aks/monitor-aks-reference#metrics).

## Feature limitations
As you scale your AKS clusters to larger scale points, keep the following feature limitations in mind:

- AKS supports scaling up to 5,000 nodes by default for all Standard Tier / LTS clusters. AKS scales your cluster's control plane at runtime based on cluster size and API server resource utilization. If you can't scale up to the supported limit, enable [control plane metrics (Preview)](./monitor-control-plane-metrics.md) with the [Azure Monitor managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) to monitor the control plane. To help troubleshoot scaling performance or reliability issues, see the following resources:
  - [AKS at scale troubleshooting guide](/troubleshoot/azure/azure-kubernetes/aks-at-scale-troubleshoot-guide) 
  - [Troubleshoot the Kubernetes control plane](/troubleshoot/azure/azure-kubernetes/troubleshoot-apiserver-etcd)

  > [!NOTE]
  > During the operation to scale the control plane, you might encounter elevated API server latency or timeouts for up to 15 minutes. If you continue to have problems scaling to the supported limit, open a [support ticket](/azure/azure-portal/supportability/how-to-create-azure-support-request).

- [Azure Network Policy Manager (Azure npm)](/azure/virtual-network/kubernetes-network-policies) only supports up to 250 nodes.
- Some AKS node metrics, including node disk usage, node CPU/memory usage, and network in/out, won't be accessible in [Azure monitor platform metrics](/azure/azure-monitor/reference/supported-metrics/microsoft-containerservice-managedclusters-metrics) after the control plane is scaled up. 
- You can't use the Stop and Start feature with clusters that have more than 100 nodes. For more information, see [Stop and start an AKS cluster](./start-stop-cluster.md).

## Azure API and platform throttling

The load on a cloud application can vary over time based on factors such as the number of active users or the types of actions that users perform. If the processing requirements of the system exceed the capacity of the available resources, the system can become overloaded and suffer from poor performance and failures.

To handle varying load sizes in a cloud application, you can allow the application to use resources up to a specified limit and then throttle them when the limit is reached. On Azure, throttling happens at two levels. Azure Resource Manager (ARM) throttles requests for the subscription and tenant. If the request is under the throttling limits for the subscription and tenant, ARM routes the request to the resource provider. The resource provider then applies throttling limits tailored to its operations. For more information, see [ARM throttling requests](/azure/azure-resource-manager/management/request-limits-and-throttling).

### Manage throttling in AKS

Azure API limits are usually defined at a subscription-region combination level. For example, all clients within a subscription in a given region share API limits for a given Azure API, such as Virtual Machine Scale Sets PUT APIs. Every AKS cluster has several AKS-owned clients, such as cloud provider or cluster autoscaler, or customer-owned clients, such as Datadog or self-hosted Prometheus, that call Azure APIs. When running multiple AKS clusters in a subscription within a given region, all the AKS-owned and customer-owned clients within the clusters share a common set of API limits. Therefore, the number of clusters you can deploy in a subscription region is a function of the number of clients deployed, their call patterns, and the overall scale and elasticity of the clusters.

Keeping the above considerations in mind, customers are typically able to deploy between 20-40 small to medium scale clusters per subscription-region. You can maximize your subscription scale using the following best practices:

Always upgrade your Kubernetes clusters to the latest version. Newer versions contain many improvements that address performance and throttling issues. If you're using an upgraded version of Kubernetes and still see throttling due to the actual load or the number of clients in the subscription, you can try the following options:

- **Analyze errors using AKS Diagnose and Solve Problems**: You can use [AKS Diagnose and Solve Problems](./aks-diagnostics.md) to analyze errors, identify the root cause, and get resolution recommendations.
  - **Increase the Cluster Autoscaler scan interval**: If the diagnostic reports show that [Cluster Autoscaler throttling has been detected](/troubleshoot/azure/azure-kubernetes/429-too-many-requests-errors#analyze-and-identify-errors-by-using-aks-diagnose-and-solve-problems), you can [increase the scan interval](./cluster-autoscaler.md#update-the-cluster-autoscaler-settings) to reduce the number of calls to Virtual Machine Scale Sets from the Cluster Autoscaler.
  - **Reconfigure third-party applications to make fewer calls**: If you filter by *user agents* in the ***View request rate and throttle details*** diagnostic and see that [a third-party application, such as a monitoring application, makes a large number of GET requests](/troubleshoot/azure/azure-kubernetes/429-too-many-requests-errors#analyze-and-identify-errors-by-using-aks-diagnose-and-solve-problems), you can change the settings of these applications to reduce the frequency of the GET calls. Make sure the application clients use exponential backoff when calling Azure APIs.
- **Split your clusters into different subscriptions or regions**: If you have a large number of clusters and node pools that use Virtual Machine Scale Sets, you can split them into different subscriptions or regions within the same subscription. Most Azure API limits are shared at the subscription-region level, so you can move or scale your clusters to different subscriptions or regions to get unblocked on Azure API throttling. This option is especially helpful if you expect your clusters to have high activity. There are no generic guidelines for these limits. If you want specific guidance, you can create a support ticket.

## Networking

As you scale your AKS clusters to larger scale points, keep the following networking best practices in mind:

- Use Managed NAT for cluster egress with at least two public IPs on the NAT gateway. For more information, see [Create a managed NAT gateway for your AKS cluster](./nat-gateway.md).
- If you are using Azure Standard Load Balancer, use at least [2 Outbound Public IPs](./configure-load-balancer-standard.md#calculate-and-verify-outbound-ports-and-ips-needed). Also consider LoadBalancer service backend rule limits when planning for large clusters. Azure Standard Load Balancers support up to 10,000 backend IP configurations per frontend IP. Each type: LoadBalancer service creates one load balancing rule per exposed port and associates all cluster nodes with the load balancer backend pool. For example, exposing 5 ports for a single service will hit this limit at 2000 nodes.

  ```
  1 service * 5 ports * 2000 nodes = 10000 backend IP configurations
  ```

- Use Azure CNI Overlay to scale up to 200,000 pods and 5,000 nodes per cluster. For more information, see [Configure Azure CNI Overlay networking in AKS][azure-cni-overlay].
- If your application needs direct pod-to-pod communication across clusters, use Azure CNI with dynamic IP allocation and scale up to 50,000 application pods per cluster with one routable IP per pod. For more information, see [Configure Azure CNI networking for dynamic IP allocation in AKS][azure-cni-dynamic-ip].
- When using internal Kubernetes services behind an internal load balancer, we recommend creating an internal load balancer or service below a 750 node scale for optimal scaling performance and load balancer elasticity.
- Azure Network Policy Manager (NPM) only supports up to 250 nodes. If you want to enforce network policies for larger clusters, consider using [Azure CNI powered by Cilium](./azure-cni-powered-by-cilium.md), which combines the robust control plane of Azure CNI with the Cilium data plane to provide high performance networking and security.
- Enable [LocalDNS](./localdns-custom.md) on your node pools to reduce DNS resolution latency and offload centralized CoreDNS pods. In large clusters with high DNS query volumes, centralized DNS resolution can become a bottleneck. LocalDNS deploys a DNS proxy as a `systemd` service on each node, resolving queries locally, eliminating `conntrack` table pressure, and upgrading connections to TCP to avoid `conntrack` race conditions. LocalDNS also supports serving stale cached responses when upstream DNS is unavailable, improving workload resilience during transient failures. For more information, see [DNS resolution in AKS](./dns-concepts.md).

## Cluster upgrade considerations and best practices

- When a cluster reaches the 5,000 node limit, cluster upgrades are blocked. This limit prevents an upgrade because there isn't available node capacity to perform rolling updates within the max surge property limit. If you have a cluster at this limit, we recommend [scaling down the cluster](./concepts-scale.md) under 3,000 nodes before attempting a cluster upgrade. This will provide extra capacity for node churn and minimize load on the control plane.
- When upgrading clusters with more than 500 nodes, it's recommended to use a [max surge configuration](./upgrade-aks-cluster.md#set-max-surge-value) of 10-20% of the node pool's capacity. AKS configures upgrades with a default value of 10% for max surge. You can customize the max surge settings per node pool to enable a trade-off between upgrade speed and workload disruption. When you increase the max surge settings, the upgrade process completes faster, but you might experience disruptions during the upgrade process. For more information, see [Customize node surge upgrade](upgrade-aks-cluster.md#customize-node-surge-upgrade).
- For more cluster upgrade information, see [Upgrade an AKS cluster](upgrade-cluster.md).

<!-- LINKS - Internal --->
[run-aks-at-scale]: ./operator-best-practices-run-at-scale.md
[managed-nat-gateway]: ./nat-gateway.md
[azure-cni-dynamic-ip]: ./configure-azure-cni-dynamic-ip-allocation.md
[azure-cni-overlay]: ./azure-cni-overlay.md
[pricing-tiers]: ./free-standard-pricing-tiers.md
[cluster-autoscaler]: cluster-autoscaler.md
[azure-npm]: /azure/virtual-network/kubernetes-network-policies
[cluster upgrades]: upgrade-cluster.md
[max surge]: upgrade-aks-cluster.md#customize-node-surge-upgrade

<!-- LINKS - External -->
[throttling-policies]: https://azure.microsoft.com/blog/api-management-advanced-caching-and-throttling-policies/
