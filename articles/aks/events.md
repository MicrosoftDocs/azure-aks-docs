---
title: Use Kubernetes events for troubleshooting
description: Learn about Kubernetes events, which provide details on pods, nodes, and other Kubernetes objects.
ms.topic: how-to
ms.author: nickoman
author: nickomang
ms.subservice: aks-monitoring
ms.date: 06/13/2024
ms.custom: innovation-engine
---

# Use Kubernetes events for troubleshooting in Azure Kubernetes Service (AKS)

This article shows you how to use Kubernetes events to monitor and troubleshoot issues in your Azure Kubernetes Service (AKS) clusters.

## What are Kubernetes events?

Events are one of the most prominent sources for monitoring and troubleshooting issues in Kubernetes. They capture and record information about the lifecycle of various Kubernetes objects, such as pods, nodes, services, and deployments. By monitoring events, you can gain visibility into your cluster's activities, identify issues, and troubleshoot problems effectively.

Kubernetes events don't persist throughout your cluster lifecycle, as there's no retention mechanism. Events are **only available for *one hour* after the event is generated**. To store events for a longer time period, enable [Container insights][container-insights].

## Kubernetes event objects

The following table lists some key Kubernetes event objects:

|Field name|Description|
|----------|------------|
|type |The type is based on the severity of the event:<br/>**Warning** events signal potentially problematic situations, such as a pod repeatedly failing or a node running out of resources. They require attention, but might not result in immediate failure.<br/>**Normal** events represent routine operations, such as a pod being scheduled or a deployment scaling up. They usually indicate healthy cluster behavior.|
|reason|The reason why the event was generated. For example, *FailedScheduling* or *CrashLoopBackoff*.|
|message|A human-readable message that describes the event.|
|namespace|The namespace of the Kubernetes object that the event is associated with.|
|firstSeen|Timestamp when the event was first observed.|
|lastSeen|Timestamp of when the event was last observed.|
|reportingController|The name of the controller that reported the event. For example, `kubernetes.io/kubelet`.|
|object|The name of the Kubernetes object that the event is associated with.|

For more information, see the official [Kubernetes documentation][k8s-events].

## View Kubernetes events

### [Azure CLI](#tab/azure-cli)

List all events in your cluster using the `kubectl get events` command.

Assuming your cluster is already created and available (per doc prerequisites), get credentials (note the `--overwrite-existing` flag is set to avoid kubeconfig errors):

```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing
```

Now list all events in your cluster:

```bash
kubectl get events
```

Results:

<!-- expected_similarity=0.3 -->

```output
LAST SEEN   TYPE      REASON              OBJECT                      MESSAGE
xxm         Normal    Scheduled           pod/my-pod-xxxxx            Successfully assigned default/my-pod-xxxxx to aks-nodepoolxx-xxxxxxx-vmss000000
xxm         Normal    Pulled              pod/my-pod-xxxxx            Container image "nginx" already present on machine
xxm         Normal    Created             pod/my-pod-xxxxx            Created container nginx
xxm         Normal    Started             pod/my-pod-xxxxx            Started container nginx
...
```

Look at a specific pod's events by first finding the name of the pod and then using the `kubectl describe pod` command.

List the pods in the current namespace:

```bash
kubectl get pods
```

Results:

<!-- expected_similarity=0.3 -->

```output
NAME                             READY   STATUS    RESTARTS   AGE
my-pod-xxxxx                     1/1     Running   0          xxm
nginx-deployment-xxxxx           1/1     Running   0          xxm
...
```

Replace `<pod-name>` below with your actual pod name. For automation, here's an example for the first pod in the list:

```shell
POD_NAME=$(kubectl get pods -o jsonpath="{.items[0].metadata.name}")
kubectl describe pod $POD_NAME
```

### [Azure portal](#tab/azure-portal)

1. Open the Azure portal and navigate to your AKS cluster resource.
1. From the service menu, under **Kubernetes resources**, select **Events**.
1. The **Events** page displays a list of events in your cluster. You can filter events by type, reason, source, object, or namespace. You can combine filters to narrow down the results.

---

## Best practices for troubleshooting with events

### Filtering events for relevance

You might have various namespaces and services running in your AKS cluster. Filtering events based on object type, namespace, or reason can help narrow down the results to the most relevant information.

For example, you can use the following command to filter events within the default namespace:

```bash
kubectl get events --namespace default
```

### Automating event notifications

To ensure timely response to critical events in your AKS cluster, set up automated notifications. Azure offers integration with monitoring and alerting services like [Azure Monitor][aks-azure-monitor]. You can configure alerts to trigger based on specific event patterns. This way, you're immediately informed about crucial issues that require attention.

### Regularly reviewing events

Make a habit of regularly reviewing events in your AKS cluster. This proactive approach can help you identify trends, catch potential problems early, and prevent escalations. By staying on top of events, you can maintain the stability and performance of your applications.

## Next steps

Now that you understand Kubernetes events, you can continue your monitoring and observability journey by [enabling Container insights][container-insights].

<!-- LINKS -->
[aks-azure-monitor]: ./monitor-aks.md
[container-insights]: /azure/azure-monitor/containers/container-insights-enable-aks
[k8s-events]: https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/