---
title: Cilium mutual TLS authentication and encryption with Advanced Container Networking Services (ACNS)
description: An overview of Advanced Container Networking Services' Cilium mTLS encryption capabilities on Azure Kubernetes Service (AKS).
author: josephyostos
ms.author: Josephyostos
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 03/16/2026
---

# Cilium mTLS encryption (public preview)

Cilium mTLS encryption provides transparent, mutual TLS (mTLS) encryption and authentication for pod-to-pod traffic in Kubernetes without requiring application changes or introducing any extra networking stack.

It ensures that both the source and destination workloads are cryptographically authenticated before any traffic is exchanged. This approach enables a zero-trust networking model for Kubernetes workloads.

All encryption and authentication happens below the application layer, meaning workloads don't need to be modified, rebuilt, or restarted to benefit from mTLS.

Cilium mTLS encryption for AKS is part of the [Advanced Container Networking Services (ACNS)](advanced-container-networking-services-overview.md) feature set, and its implementation is based on [Cilium](https://docs.cilium.io/en/stable/).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Architecture

At a high level, Cilium mTLS secures traffic by combining identity issuance, transparent traffic interception, and workload-level encryption enforcement.

Each workload gets assigned a cryptographic identity derived from Kubernetes attributes such as namespace and ServiceAccount. When pod-to-pod TCP traffic is initiated, the traffic is transparently intercepted at the node level. The traffic is then authenticated and encrypted using mutual TLS before being forwarded to the destination workload.

The system is composed of three cooperating components:

- **SPIRE** - Provides workload identity and certificate issuance.
- **ztunnel** - Enforces mTLS in the data plane.
- **Cilium** - Installs iptables rules that redirect outbound traffic to ztunnel on port 15001.

Together, these components ensure that authentication and encryption happen transparently and consistently across the cluster.

## Identity and authentication model

Cilium mTLS uses mutual authentication based on SPIFFE workload identity.

Each workload gets assigned a SPIFFE identity (SVID) derived from:

- Kubernetes namespace
- Kubernetes ServiceAccount

When a workload initiates a connection:

1. The source ztunnel retrieves a valid SVID for the workload.
2. The destination ztunnel validates the presented identity.
3. Both sides complete mutual verification before traffic is allowed to flow.

Authentication decisions are based on workload identity rather than network location. This design ensures that:

- Only authenticated workloads can communicate.
- Identity remains consistent across rescheduling and scaling.
- Trust isn't dependent on IP addressing or network topology.


## Encryption flow

After successful authentication, traffic is protected using mutual TLS.

1. Traffic intercepted inside the pod network namespace and redirected to the local ztunnel instance. 
2. The source ztunnel initiates an mTLS session with the destination ztunnel.
3. Certificates are exchanged and validated.
4. Application data is encrypted before transmission.
5. The destination ztunnel decrypts the traffic and delivers it to the target pod. 

:::image type="content" source="./media/advanced-container-networking-services/mutual-tls-authentication-diagram.png" alt-text="Diagram of mutual-tls authentication process." lightbox="./media/advanced-container-networking-services/mutual-tls-authentication-diagram.png":::

Every packet from an enrolled pod is encrypted. There is no plaintext window, and no dropped first packets. The connection is held inline by ztunnel until the mTLS tunnel is established, then traffic flows bidirectionally through an HBONE (HTTP/2 CONNECT) tunnel.

## Core components

### SPIRE (identity and trust)

SPIRE (SPIFFE Runtime Environment) is responsible for workload identity and certificate management. SPIRE has two major components: the SPIRE server and the SPIRE agent.

The **SPIRE server** acts as the cluster Certificate Authority (CA). It issues short-lived X.509 certificates (SVIDs) to only workloads that are allowed to receive identities. It uses Kubernetes-native attestation, binding identity to attributes such as namespace and ServiceAccount rather than to network properties like IP addresses.

On each node, the **SPIRE agent** is responsible for attesting the node to the SPIRE server and retrieving certificates on behalf of local workloads. Workloads only communicate with the SPIRE agent and never directly with the SPIRE server.

SPIRE ensures that every workload identity is:

- Cryptographically verifiable.
- Automatically issued and rotated.
- Bound to Kubernetes primitives, not IP addresses.
- Stable across pod restarts and rescheduling events.

This identity foundation enables strong, topology-independent trust decisions.

### Ztunnel (mTLS data plane)

Ztunnel is a lightweight, node-level Layer 4 proxy responsible for enforcing mTLS between workloads. It runs as a DaemonSet, with one instance per node, eliminating the need for per-pod sidecar proxies.

When a workload initiates a TCP connection, ztunnel establishes a mutually authenticated TLS session with the peer node's ztunnel instance. It uses certificates obtained from SPIRE to authenticate both sides of the connection before allowing traffic to flow.

Ztunnel enforces the following guarantees:

- Both sides of a connection must present valid workload certificates.
- Certificates are verified against the cluster trust domain.
- Traffic is always encrypted on the wire.
- No plaintext fallback is permitted for enrolled workloads.

By centralizing mTLS enforcement at the node level, ztunnel provides strong security properties without increasing per-pod operational overhead.

### Cilium (redirection rules and pod enrollment)

Cilium is responsible for making mTLS transparent to applications.

When a namespace is labelled with “io.cilium/mtls-enabled=true”, the Cilium agent enrolls all pods in that namespace. It enters each pod's network namespace and installs iptables rules that redirect outbound traffic to ztunnel on port 15001.  

Cilium also passes workload metadata, such as the Pod UID, to ztunnel and integrates with the Cilium Operator to register workload identities with SPIRE.

From the application's perspective, communication continues using standard TCP sockets. Encryption and authentication are enforced entirely underneath the application layer, requiring no code changes.


## Scope and trust boundaries

### Namespace enrollment

Cilium mTLS is opt-in and scoped at the namespace level. A namespace must be explicitly labeled to enable mTLS enforcement. Once enabled, all pods within that namespace are subject to mandatory authentication and encryption.

Pods in non-enrolled namespaces aren't affected. This design allows incremental rollout and staged adoption across environments.

### Enforcement model

Encryption is applied only when both pods are enrolled. Traffic between enrolled and non‑enrolled workloads continues in plaintext without causing connectivity issues or hard failures.

| Source | Destination | Result |
|--------|-------------|--------|
| Enrolled | Enrolled | **Encrypted** (mTLS over HBONE) |
| Enrolled | Non-enrolled | Plaintext passthrough |
| Non-enrolled | Enrolled | Plaintext (captured by ztunnel, but not encrypted) |
| Non-enrolled | Non-enrolled | Normal Cilium datapath (no ztunnel involvement) |

## Considerations and limitations

- The feature is available only on clusters using Azure CNI powered by Cilium with [Advanced Container Networking Services (ACNS)](advanced-container-networking-services-overview.md) enabled.
- mTLS is enabled at the namespace level. All pods in an enrolled namespace participate in mTLS. Pod-level opt-in or opt-out isn't supported.
- Cilium mTLS currently protects TCP-based pod-to-pod traffic. It doesn't currently encrypt or authenticate other protocols, including UDP.
- In the current phase, L4/L7 network policy enforcement isn't supported with mTLS.
- You can't bring a custom CA. SPIRE acts as the cluster Certificate Authority and manages certificate issuance and rotation.
- Enabling both mTLS and WireGuard on the same cluster isn't supported.
- Enabling both Istio and Cilium mTLS encryption isn't supported.
- mTLS encryption for cross-cluster traffic isn't supported.
- The integration requires iptables support in the kernel and can't be used with environments that don't support iptables (such as some minimal container runtimes).
- Pods without a network namespace path (such as host-networked pods) can't be enrolled in ztunnel and are excluded during the enrollment process.

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Next steps

- Learn how to apply [Cilium mTLS encryption](container-network-security-cilium-mutual-tls-how-to.md) on AKS.

- For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).

