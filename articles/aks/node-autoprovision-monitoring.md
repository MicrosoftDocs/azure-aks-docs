---
title: Monitor node autoprovisioning
description: Learn how to monitor Azure Kubernetes Service (AKS) node autoprovisioning events and troubleshoot provisioning decisions.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
---

# Monitor node autoprovisioning

This article explains how to monitor Azure Kubernetes Service (AKS) node autoprovisioning (NAP) events and troubleshoot provisioning and scheduling decisions.

## Monitoring selection events

Node autoprovision produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```bash
kubectl get events -A --field-selector source=karpenter -w
```

This command displays events from Karpenter across all namespaces and watches for new events in real-time.

## Understanding NAP events

The events provide insights into:

- Node provisioning decisions
- Pod scheduling activities
- Consolidation actions
- Configuration issues
- Resource constraints

## Common event examples

When monitoring NAP events, you might see messages like:

- Node provisioning success and failure events
- Pod scheduling decisions
- Consolidation opportunities and blockers
- Resource availability issues

## Filtering events

You can filter events to focus on specific areas:

```bash
# View events from the last period
kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp'

# Watch events in real-time for troubleshooting
kubectl get events -A --field-selector source=karpenter -w
```

## Troubleshooting with events

NAP events help identify common issues:

- **Provisioning failures**: May indicate capacity constraints or configuration issues
- **Scheduling conflicts**: Can reveal resource request mismatches
- **Consolidation blocks**: Often show Pod Disruption Budget or affinity constraints

## Best practices for monitoring

1. **Regular monitoring**: Check NAP events regularly to understand cluster behavior patterns
2. **Event correlation**: Combine NAP events with application performance metrics
3. **Historical tracking**: Maintain event logs for trend analysis
4. **Alert setup**: Configure alerts for critical provisioning failures

## Next steps

- [Configure disruption policies](node-autoprovision-disruption.md)
- [Configure node pools](node-autoprovision-node-pools.md)
- [Learn about networking configuration](node-autoprovision-networking.md)