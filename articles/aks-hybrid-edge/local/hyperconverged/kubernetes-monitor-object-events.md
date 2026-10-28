---
title: Monitor Kubernetes object events in AKS Hybrid and Edge
description: Learn how to monitor real-time Kubernetes object events.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 01/16/2024
ms.reviewer: guanghu
ms.custom: hyperconverged

# Intent: As an IT Pro, I want to learn how to monitor and view Kubernetes object events for AKS.
# Keyword: monitor and logging data, Prometheus

---

# Monitor Kubernetes object events

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

Kubernetes events are real-time notifications that provide insights into actions and changes occurring within a Kubernetes cluster, helping you monitor and troubleshoot the health and behavior of their applications. These events capture and record information about the lifecycle of various Kubernetes objects, such as pods, nodes, services, and deployments. Kubernetes events don't persist throughout your cluster lifecycle, as there's no mechanism for retention. They are short-lived, only available for one hour after the event is generated. To store events for a longer time period, enable [Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable).

## Kubernetes event objects

For a comprehensive list of all fields in a Kubernetes event, see [the official Kubernetes documentation](https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/).

### Access events

You can find events for your cluster and its components by using `kubectl`:

```powershell
kubectl get events
```

To see a specific pod's events, first find the name of the pod, and then use `kubectl describe` to list events:

```powershell
kubectl get pods
kubectl describe pods <pod-name>
```

## Best practices

This section describes some best practices to follow when you monitor Kubernetes events.

### Filter events for relevance

In your Kubernetes cluster, you might have various namespaces and running services. To help you narrow down your focus to what's most relevant to your applications, you can filter events based on object type, namespace, or reason. For example, you can use the following command to filter events within a specific namespace:

```powershell
kubectl get events -n <namespace>
```

### Automate event notifications

To ensure a timely response to critical events in your cluster, you can set up automated notifications. Azure offers integration with monitoring and alerting services such as [Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable). You can configure alerts to trigger based on specific event patterns. This way, you're immediately informed about crucial issues that require attention.

### Review events regularly

It's a good practice to regularly review events in your Kubernetes cluster. This proactive approach can help you identify trends, catch potential problems early, and prevent escalations. By staying on top of events, you can maintain the stability and performance of your applications.

## Next steps

Now that you understand Kubernetes events, you can continue your monitoring and observability journey by [enabling Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable).
