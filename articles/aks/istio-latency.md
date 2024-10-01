---
title: Istio service mesh Azure Kubernetes Service add-on latency comparison
description: Istio service mesh Azure Kubernetes Service add-on latency compared across addon versions
ms.topic: article
ms.custom:
ms.service: azure-kubernetes-service
ms.date: 09/30/2024
ms.author: shalierxia
---

# Latency comparison across versions
This document compares Container Network Interface (CNI) plugins: Azure CNI Overlay and Azure CNI Overlay with Cilium [ (recommended network plugins for large scale clusters) ](/azure/aks/azure-cni-overlay?tabs=kubectl#choosing-a-network-model-to-use) across Istio add-on versions and respective latest Kubernetes version. The latency difference shown represents the latency with traffic going through the sidecar minus the latency with traffic directly going to the pod.
- Traffic going through the sidecar: client --> client-sidecar --> server-sidecar --> server
- Traffic directly going to the pod: client --> server

## Test Specifications
- Node SKU - Standard D16 v5 (16 vCPU, 64-GB memory)
- 25 user nodes
- 5 system nodes
- Two proxy workers
- 1-KB payload
- 1,000 queries per second (QPS) at 16 client connections
- `http/1.1` protocol 
- mTLS enabled

| P99 Latency Difference | P90 Latency Difference |
|:-------------------------:|:-------------------------:|
[ ![Diagram that compares P99 Latency Difference vs Istio \| Kubernetes Version across CNI Plugins.](./media/aks-istio-addon/latency-comparison/p99.png) ](./media/aks-istio-addon/latency-comparison/p99.png#lightbox) |  [ ![Diagram that compares P90 Latency Difference vs Istio \| Kubernetes Version across CNI Plugins.](./media/aks-istio-addon/latency-comparison/p90.png) ](./media/aks-istio-addon/latency-comparison/p90.png#lightbox)
