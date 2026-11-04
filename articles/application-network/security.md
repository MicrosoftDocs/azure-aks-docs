---
title: Security Overview for Azure Kubernetes Application Network (Preview)
description: Learn about the security features in Azure Kubernetes Application Network, including mTLS, workload identities, certificate management, and authorization policies for secure service-to-service communication in AKS.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: overview
ms.date: 11/03/2026
ai-usage: ai-assisted
---

# Overview of Azure Kubernetes Application Network security (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network secures communication between services in connected Azure Kubernetes Service (AKS) clusters through automatic mutual TLS (mTLS) and identity-based authorization. It issues workload identities and manages certificate issuance, rotation, and validation to enable encrypted, authenticated, and explicitly authorized service-to-service communication without manual configuration, with FIPS-compliant encryption in transit.

This article provides an overview of the security features in Azure Kubernetes Application Network, including mTLS, workload identities, certificate management, and authorization policies. It also outlines limitations and next steps for implementing secure communication in your Azure Kubernetes Application Network environment.

## Limitations

- Certificates are currently issued by an Azure Kubernetes Application Network-managed certificate authority (CA) and aren't chained to a public CA.

## mTLS

Application Network uses mTLS to provide identity-based, encrypted communication between workloads. Each service in an Application Network connected cluster automatically receives a certificate that allows it to prove its identity and establish trusted, encrypted connections with other services in the same Application Network. Encryption in transit uses FIPS-compliant cryptography.

### mTLS migration strategy

Application Network currently allows both encrypted and unencrypted traffic. This approach ensures that existing workloads continue to operate normally while new or updated workloads automatically use mTLS for secure communication. This means you can adopt mTLS for secure communication across your workloads without downtime. After the migration is complete, you can change to strict mode so that authentication is enforced.

### Benefits of mTLS in Azure Kubernetes Application Network

mTLS in Azure Kubernetes Application Network helps you:

- **Protect data in transit**: All service-to-service traffic can be encrypted automatically (FIPS-compliant).
- **Verify service identity**: Each Application Network has a unique root CA, and each member has a dedicated intermediate CA chained to that root. Workloads prove their identities with short-lived workload certificates signed by their member's intermediate CA.
- **Simplify operations**: Application Network handles certificate issuance, rotation, and revocation for users.

## Certificate management

Azure Kubernetes Application Network provides certificate management backed by Azure Key Vault that issues and maintains the certificates used for mTLS. This service establishes a shared trust boundary across all AKS clusters connected to the same Application Network resource.

Application Network automatically manages the entire certificate lifecycle for root and intermediate certificates including provisioning, renewal, and rotation. This ensures that workload identities remain valid, and communication stays secure over time. You don't need to create, store, or rotate certificates manually.

The following diagram shows how the AppNet root CA signs a separate intermediate CA for each member. Each intermediate CA issues workload certificates with namespace and service account identities:

:::image type="content" source="./media/security/certificate-management.svg" alt-text="Diagram of the Application Network certificate hierarchy, with one Key Vault-backed root CA, a separate intermediate CA for each member, and workload certificates that carry namespace and service account identities." lightbox="./media/security/certificate-management.svg":::

### Certificate hierarchy and lifecycle

When an Application Network resource is created, a unique **root CA** is provisioned as its trust anchor. Each Application Network member receives a dedicated **intermediate CA** signed by that root CA. The member's intermediate CA issues short-lived **workload certificates** to workloads in its connected AKS cluster.

All workload certificates inherit trust from the Application Network root CA, maintaining a unified trust boundary across the resource. The rotation of root and intermediate certificates is handled transparently for users without causing any downtime or traffic disruptions. This managed hierarchy ensures consistent, verifiable trust across all clusters in an Application Network while automatically maintaining the validity of each certificate.

From any member cluster, you can get the root CA certificate from config map `istio-root-cert` under namespace `applink-system`.

### Certificate types and rotation periods

| **Certificate type**     | **Scope**                            | **Validity period** | **Rotation period** | **Purpose**                                                                                           |
| ------------------------ | ------------------------------------ | ------------------- | ------------------- | ----------------------------------------------------------------------------------------------------- |
| **Root CA**              | Azure Kubernetes Application Network | 12 months           | 6 months            | Establishes the trust boundary for all clusters connected to the Azure Kubernetes Application Network |
| **Intermediate CA**      | Application Network member           | 90 days             | 45 days             | Issues workload certificates for workloads associated with that member                                |
| **Workload certificate** | Workload                             | 24 hours            | 12 hours            | Authenticates workloads and secures service-to-service communication                                  |

## Workload identity and authorization

As applications grow, services often need to communicate securely across different namespaces and environments within the same deployment. Managing certificates and ensuring that each service can verify who it’s talking to can quickly become complex and error-prone. Azure Kubernetes Application Network eliminates this overhead by automatically assigning and managing workload identities.

Within an Application Network-connected environment, workloads communicate securely inside and across namespaces. To ensure each service can be trusted and authenticated, Application Network assigns every workload a **verifiable identity** that represents its namespace and service account.

Each Application Network workload automatically receives a unique identity in the [SPIFFE](https://spiffe.io/docs/latest/spiffe-about/overview/) format, which includes its namespace and service account. The identity is formatted as follows:

```text
spiffe://cluster.local/ns/<namespace>/sa/<service-account>
```

This identity is embedded in the workload certificate and is used to prove the service’s identity when communicating with other workloads. Azure Kubernetes Application Network uses this SPIFFE-based identity model with Istio authorization policies so you can define clear, consistent rules for which services are allowed to communicate.

### Define access policies

You can use Istio `AuthorizationPolicies` to control which workloads are allowed to communicate within your environment. These policies let you define access based on verified workload identities rather than network locations or IP addresses. This approach helps you enforce consistent access controls even as services scale and move across nodes. For example, you might allow only specific gateways or workloads from trusted namespaces to call a service by referencing their SPIFFE identities in the policy’s principals list as shown in the following example:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-gateway-to-app
  namespace: default
spec:
  selector:
    matchLabels:
      app: myApp
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/myapp-gateway  # See SPIFFE format above.
```

### Policy design guidance

When designing authorization policies, keep the following best practices in mind:

- Always specify both namespace and service account to prevent unintended cross-namespace access.
- Use **principals** to define explicit workload identities for fine-grained access.
- Use **namespaces** to define broader trust boundaries when appropriate.
- Avoid rules that match only service account names without namespaces, as this might grant access across clusters or environments.
- Combine `AuthorizationPolicies` with Kubernetes `NetworkPolicies` to enforce both identity-based and network-based isolation.

> [!NOTE]
> Azure Kubernetes Application Network authorization is based on verified workload identity rather than IP address. This ensures consistent enforcement even as workloads scale or move across nodes.

By combining Azure Kubernetes Application Network-managed identities, certificates, and policy controls, you can implement identity-based, least-privilege service communication, ensuring authenticated, encrypted, and explicitly authorized traffic between workloads across clusters.

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Overview of Azure Kubernetes Application Network observability](./observability.md)
