---
title: Certificate Management and Rotation in Azure Kubernetes Service (AKS) Overview
description: Learn about certificate management and rotation in Azure Kubernetes Service (AKS) clusters, including how to manually rotate certificates and enable autorotation for enhanced security.
author: schaffererin
ms.author: schaffererin
ms.topic: overview
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 07/13/2026
# Customer intent: "As a Kubernetes administrator, I want to implement certificate rotation in my AKS cluster, so that I can ensure the security and compliance of my cluster by managing certificate expirations and maintaining secure communication between components."
---

# Overview of certificate management and rotation in Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) clusters use certificates for authentication between various components, including AKS managed control plane components and data plane components. This article provides an overview of certificate management and rotation in AKS.

[!INCLUDE [kubelet-serving-cert-retirement](./includes/kubelet-serving-cert-retirement.md)]

> [!NOTE]
> Certificate autorotation for node client and serving certificates is enabled by default for clusters that enable [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/).
>
> - AKS clusters created **before May 2019** have cluster CA certificates that expire after two years.
> - AKS clusters created **after May 2019** have cluster CA certificates that expire after 30 years.

## What is certificate rotation?

Certificate rotation is the process of replacing digital certificates with new ones to maintain security and prevent disruptions. It's a crucial security practice performed to replace expired certificates, mitigate risks from compromised keys, and respond to new security requirements. This process can involve automatically renewing certificates or manually replacing them. Often, it requires a planned maintenance window for complex replacements, especially when a root certificate is involved.

## Certificates, certificate authorities, and service account tokens in AKS

AKS generates and uses the following certificates, certificate authorities (CA), and service accounts (SA) tokens:

| Certificate | Description | Rotation method |
| ----------- | ----------- | --------------- |
| Cluster certificate authority | Created by AKS on your behalf and is unique to your cluster. This CA certificate is used to issue both client and server certificates to the kubelets running in your data plane and the certificate used by the API server. | Manual |
| Service account token | JSON Web Tokens (JWT) signed by the cluster CA certificate. The kubelets running on your agent nodes automatically request and renew these tokens. For more information, see [Launch a Pod using service account token projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#launch-a-pod-using-service-account-token-projection). | Automatically refreshed as part of manual cluster CA rotation |
| API server certificate | Signed and issued by the cluster CA certificate. This certificate is used whenever establishing TLS-based connections with the API server, such as with `kubectl`. | Automatically refreshed as part of manual cluster CA rotation |
| Kubelet serving certificate | In clusters that enable [kubelet serving certificate rotation](https://aka.ms/aks/kubelet-serving-certificate-rotation), the cluster CA certificate issues and signs this certificate. Otherwise, the agent node generates and self-signs this certificate. This certificate establishes TLS-based connections with components that need to connect to any one of the kubelet serving endpoints, such as _metrics-server_. | Automatic for clusters enabled with kubelet serving certificate rotation |
| Kubelet client certificate | Signed and issued by the cluster CA certificate. This certificate uses an AKS-specific [TLS bootstrapping protocol](#tls-bootstrapping-for-the-kubelet-client-certificate) that provides kubelet its client certificate and corresponding kubeconfig before kubelet starts. The AKS TLS protocol is only enabled on Kubernetes clusters version 1.32 or higher. | Automatically refreshed by default using vanilla TLS bootstrapping and as part of manual cluster CA rotation |
| `kubectl` client certificate | Used for certificate-based authentication with the API server. | Manually rotate after manual cluster CA rotation |

> [!NOTE]
> AKS doesn't manage any certificate created for or specific to a customer's workload.

## Certificate autorotation in AKS

AKS automatically rotates the following certificates:

- Clusters created **after March 2022 with Kubernetes RBAC enabled** enable kubelet client certificate autorotation by default.

> [!NOTE]
> You might need to periodically rotate these certificates manually for security or policy reasons. For example, you might have a policy to rotate all your certificates every 90 days. By default, kubelet client certificate autorotation occurs manually.

### Limitations for certificate autorotation

The following limitations apply to certificate autorotation:

- The cluster must use [vanilla TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/) or AKS secure TLS bootstrapping, which is enabled by default in all Azure regions.
- For existing clusters, you need to upgrade the cluster to enable certificate autorotation.

## Manual certificate rotation in AKS

You must [manually rotate](./rotate-certificates.md) the following certificates:

- Cluster CA certificates using the [`az aks rotate-certs`](/cli/azure/aks#az-aks-rotate-certs).
- `kubectl` client certificates using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command (after manual rotation of the cluster CA certificate).

When you rotate the cluster CA certificate, the following child certificates are also refreshed:

- Service account (SA) tokens
- API server certificates
- Kubelet client certificates
- Kubelet server certificates (if kubelet serving certificate rotation is enabled on the cluster)

After you rotate the cluster CA certificate, you must also manually rotate the `kubectl` client certificates to ensure continued access to the API server.

## TLS bootstrapping for the kubelet client certificate

Kubelet uses an AKS-specific TLS bootstrapping protocol and relies on the node's identity within Entra ID. This identity provides kubelet its client certificate and corresponding kubeconfig before kubelet starts. This change aims to harden the AKS node security posture by eliminating kubelet's dependency on a static bootstrap token secret to register itself with the API server. If the secure TLS bootstrapping protocol fails for any reason, kubelet can still register itself with the API server by using a bootstrap token, and the node eventually becomes ready. You see `aksService` (instead of `system:bootstrap:<>`) as the requestor field on the certificate signing request (CSR) objects created by the protocol.

The kubelet client certificate is still located within _/var/lib/kubelet/pki/kubelet-client-current.pem_ on Linux nodes and _C:\k\pki\kubelet-client-current.pem_ on Windows nodes. The _bootstrap-kubeconfig_ is still located in the same spot. AKS continues to automatically rotate this certificate as part of its certificate rotation process.

## Kubelet serving certificate rotation

Kubelet serving certificate rotation enables AKS to use kubelet server TLS bootstrapping for both bootstrapping and rotating serving certificates that the cluster CA signs.  

For more information, see [Manage and rotate certificates in Azure Kubernetes Service (AKS)](./rotate-certificates.md).

### Kubelet serving certificate rotation limitations

- Supported on Kubernetes version 1.27 and above.
- Not supported when the node pool is using a node pool snapshot based on any node image older than `202501.12.0`.
- You can't manually enable this feature. Existing node pools have kubelet serving certificate rotation enabled by default after they perform their first upgrade to any Kubernetes version 1.27 or greater. New node pools on Kubernetes version 1.27 or greater have kubelet serving certificate rotation enabled by default. To see if kubelet serving certificate rotation is enabled in your region, see [AKS Releases](https://github.com/Azure/AKS/releases).
- Kubernetes RBAC must be enabled on the cluster for kubelet serving certificate rotation to be enabled. If you have an existing cluster, you must upgrade that cluster to enable Kubernetes RBAC.

## Next step

> [!div class="nextstepaction"]
> [Manage and rotate certificates in Azure Kubernetes Service (AKS)](./rotate-certificates.md)
