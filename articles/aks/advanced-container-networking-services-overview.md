---
title: Advanced Container Networking Services for Azure Kubernetes Service (AKS) Overview
description: Learn about Advanced Container Networking Services for Azure Kubernetes Service (AKS), including features like Container Network Observability and Container Network Security.
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 11/04/2026
ai-usage: ai-assisted
# Customer intent: "As a cloud engineer, I want to implement Advanced Container Networking Services in my AKS clusters, so that I can enhance network observability and security for my containerized applications, ensuring they are secure, compliant, and perform optimally."
---

# Advanced Container Networking Services for Azure Kubernetes Service (AKS) overview

Advanced Container Networking Services is a suite of services designed to enhance the networking capabilities of Azure Kubernetes Service (AKS) clusters. Advanced Container Networking Services offers the following key feature sets: [**Container Network Observability**](#container-network-observability), [**Container Network Security**](#container-network-security), and [**Container Network Performance**](#container-network-performance). These features provide deep insights into network traffic, strengthen security measures, and optimize network performance for containerized applications running in AKS.

## Container Network Observability

Container Network Observability helps you answer three questions: which workloads
are communicating, where traffic is being dropped, and what to investigate next.
Use metrics to spot changes in network health and logs to examine the traffic
involved.

Metric collection and on-demand flow inspection are available across supported
Cilium and non-Cilium data planes. **Stored logs and source-level metric filtering
require Cilium.** Platform and protocol requirements vary by capability; the
linked guides explain them.

Key benefits of Container Network Observability include:

- Collection across supported AKS networking configurations.
- [_Container network metrics_](#container-network-metrics), including node-level metrics and Hubble metrics for detailed network insights.
- Hubble metrics for pod-to-pod communication and service interactions, including
  Domain Name System (DNS) observations when DNS visibility is configured.
- [_Container network logs_](#container-network-logs) that capture selected flow metadata for troubleshooting, monitoring, and policy verification.
- Integration with the managed service for Prometheus in Azure Monitor and Azure Managed Grafana for simplified metrics storage and visualization.

:::image type="content" source="./media/advanced-container-networking-services/advanced-network-observability.png" alt-text="Diagram of the Container Network Observability architecture." lightbox="./media/advanced-container-networking-services/advanced-network-observability.png":::

### Choose where to start

| Your goal | Start here |
| --- | --- |
| Monitor network health, drops, or DNS behavior over time | [Set up container network metrics](container-network-observability-how-to.md). |
| Focus metric collection on an application or namespace | [Configure metric filtering](how-to-configure-container-network-metrics-filtering.md). |
| Keep records of selected traffic for later investigation | [Set up stored logs](how-to-configure-container-network-logs.md#end-to-end-setup). |
| Inspect live traffic during an incident | [Configure on-demand logs](how-to-configure-container-network-logs.md#configure-on-demand-logs-mode). |

### Container network metrics

Container network metrics help you detect network issues and identify the workloads
involved. Monitor traffic, packet drops, and DNS behavior. Move from node-level
health signals to pod-level insights to narrow your investigation.

On Cilium clusters, **collect the metrics you need at the source** by selecting
specific workloads, namespaces, or traffic. Focus monitoring on critical
applications and reduce unnecessary metrics ingestion, helping control monitoring
costs. When you need deeper insight, selectively enable metrics for external
destinations and destination ports.

Store and query metrics with Azure Monitor managed service for Prometheus or your
own Prometheus instance. Visualize network health with Azure Managed Grafana or
your existing Grafana deployment.

For supported platforms, available metrics, and configuration steps, see the
[container network metrics overview](container-network-observability-metrics.md).

### Container network logs

Container network logs help you understand how your applications communicate and troubleshoot connectivity issues. See which workloads are communicating, which destinations they reach, and where traffic is dropped. Inspect live traffic during an incident with on-demand logs, or collect stored logs for later investigation.

On Cilium clusters, capture the traffic that matters and tailor the detail you retain. Filter stored logs to focus on specific workloads or traffic, and customize flow log aggregation to balance investigation detail with data volume and cost.

Forward stored logs to Azure Monitor or your existing logging backend for historical analysis. Combine logs with network metrics to move from detecting an issue to investigating the traffic involved.

For collection requirements and examples, see the [container network logs overview](container-network-observability-logs.md).

## Container Network Security

Container Network Security enhances the security posture of AKS clusters by providing advanced network security features. It leverages eBPF technology to enforce network policies at the kernel level, ensuring efficient and effective security controls for containerized applications. **Container Network Security is available only on clusters with Azure CNI Powered by Cilium**.

### FQDN-based filtering

FQDN-based filtering allows you to create network policies based on fully qualified domain names (FQDNs) rather than IP addresses. This capability simplifies policy management, especially in dynamic environments where IP addresses frequently change. By using FQDNs, you can ensure that your applications communicate only with trusted external services, enhancing security and compliance.

For more information, see the [FQDN-based filtering overview](container-network-security-fqdn-filtering-concepts.md).

### Layer 7 policy

Layer 7 policy enables application-layer traffic control, allowing you to define policies based on specific application protocols. This feature provides granular control over network traffic, enabling you to enforce security policies that align with application behavior. With Layer 7 policy, you can monitor and restrict traffic based on HTTP methods, URLs, headers, and other application-level attributes.

For more information, see the [Layer 7 policy overview](container-network-security-l7-policy-concepts.md).

### WireGuard encryption

WireGuard Encryption leverages the WireGuard protocol to provide secure, encrypted communication between Cilium-managed endpoints within your AKS cluster. This feature ensures that data transmitted over the network is protected from eavesdropping and tampering, enhancing the overall security of your containerized applications.

For more information, see the [WireGuard encryption overview](container-network-security-wireguard-encryption-concepts.md).

### Cilium mTLS encryption
Cilium mTLS encryption provides transparent, mutual TLS (mTLS) encryption and authentication for pod-to-pod traffic in Kubernetes without requiring application changes or introducing any extra networking stack.

For more information, see the [Cilium mTLS encryption overview](container-network-security-cilium-mutual-tls-concepts.md).

## Container Network Performance

Container Network Performance optimizes network performance for containerized applications running in AKS clusters. It leverages eBPF technology to enhance network routing and reduce latency, ensuring that applications can communicate efficiently and effectively. **Container Network Performance is available only on clusters with Azure CNI Powered by Cilium**.

### eBPF host routing

eBPF Host Routing uses extended Berkeley Packet Filter (eBPF) technology to optimize traffic flow in AKS clusters.

For more information, see the [eBPF Host Routing overview](container-network-performance-ebpf-host-routing.md).

## Container Network Connectivity

## Cross Cluster Networking (Preview)

Cross-cluster networking enables direct pod-to-pod communication across multiple AKS clusters, providing seamless east-west connectivity, multi-cluster observability, and consistent security enforcement. It uses a managed offering of Cilium Cluster Mesh through Azure Kubernetes Fleet Manager to create a flat pod network across clusters without overlays or gateways.

For more information, see the [Cross-cluster networking use cases for Azure Kubernetes Fleet Manager](cross-cluster-networking-fleet-use-cases.md).

## Related content

- [Set up Advanced Container Networking Services on your Azure Kubernetes Service (AKS) cluster](use-advanced-container-networking-services.md)
- [Advanced Container Networking Services pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/)
