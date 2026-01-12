---
title: Use external identity providers with AKS structured authentication (Preview)
description: Learn about structured authentication for Azure Kubernetes Service (AKS) and how to configure external identity providers for control plane access.
author: shashankbarsin
ms.author: shasb
ms.topic: overview
ms.subservice: aks-security
ms.custom: preview
ms.date: 01/12/2026
# Customer intent: As a platform engineer, I want to understand how to use external identity providers for AKS control plane authentication using structured authentication, so that I can integrate with my organization's existing identity infrastructure.
---

# Use external identity providers with AKS structured authentication (Preview)

Azure Kubernetes Service (AKS) supports structured authentication, which allows you to configure external identity providers for authenticating users to the Kubernetes API server. This feature is based on the upstream Kubernetes structured authentication configuration and enables organizations to integrate AKS with their existing identity infrastructure beyond Microsoft Entra ID.

Structured authentication extends AKS beyond traditional Microsoft Entra ID integration by supporting industry-standard OpenID Connect (OIDC) identity providers. This feature allows you to:

- Authenticate users with external identity providers like Google, GitHub, or any OIDC-compliant provider
- Maintain centralized identity management across your organization
- Implement custom claim validation and user mapping rules
- Support multiple identity providers simultaneously on a single cluster

The feature is based on the [Kubernetes structured authentication configuration][k8s-structured-auth], which moved to beta in Kubernetes 1.30. AKS implements this functionality through JSON Web Token (JWT) authenticators that validate tokens from external identity providers according to your configuration.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## How external identity providers work

When a user attempts to access the Kubernetes API server:

- **Authentication**: The following steps validate the user's identity:

  - **Token presentation**: The user presents a JWT token from their configured identity provider

  - **Token validation**: The API server validates the token's signature, issuer, audience, and expiration

  - **Claim processing**: Custom claim validation rules are applied to ensure the token meets your requirements

  - **User mapping**: Claims are mapped to Kubernetes user identity (username, groups, and extra attributes)

- **Authorization**: Standard Kubernetes Role-Based Access Control (RBAC) determines what actions the authenticated user can perform

:::image type="content" source="media/external-identity-provider-authentication/conceptual-diagram.png" alt-text="Conceptual diagram showing how external identity provider-based authentication works with AKS clusters." lightbox="media/external-identity-provider-authentication/conceptual-diagram.png":::

## Identity providers

While AKS structured authentication allows any OIDC-compliant identity provider, common examples include:

- **GitHub**: Authenticate using GitHub identities or GitHub Actions
- **Google OAuth 2.0**: Use Google accounts for authentication
- **Generic OIDC providers**: Any provider implementing OIDC standards
- **Custom identity solutions**: Organization-specific OIDC implementations

> [!NOTE]
> Microsoft Entra ID isn't supported as an external identity provider through structured authentication. Use the existing [AKS-managed Microsoft Entra integration][aks-managed-entra-id] for Microsoft Entra ID authentication.

### Identity provider requirements

External identity providers must:

- Support OIDC standards
- Provide publicly accessible OIDC discovery endpoints
- Issue JWT tokens with appropriate claims
- Be accessible from AKS cluster nodes for token validation

## Key concepts

### JWT authenticators

A JWT authenticator is a configuration object that defines how to validate and process tokens from a specific identity provider. Each authenticator specifies:

- **Issuer configuration**: The identity provider's OIDC issuer URL and expected audiences
- **Claim validation rules**: Custom validation logic using CEL (Common Expression Language) expressions
- **Claim mappings**: How to map token claims to Kubernetes user attributes
- **User validation rules**: More validation logic applied after claim mapping

### CEL expressions

Structured authentication uses [CEL (Common Expression Language)][k8s-cel] expressions for flexible claim validation and mapping. CEL provides a secure sandbox environment for evaluating custom logic against JWT claims.

Example CEL expressions:

```cel
// Validate that the 'sub' claim exists
has(claims.sub)

// Map username with AKS prefix
'aks:jwt:' + claims.sub

// Map groups from comma-separated string
claims.groups.split(',').map(g, 'aks:jwt:' + g)

// Conditional mapping based on claim verification
'aks:jwt:' + (claims.email_verified ? claims.email : claims.sub)
```

## Security best practices

- **Use strong claim validation**: Implement comprehensive validation rules to ensure only
  authorized tokens are accepted.
- **Limit token scope**: Configure your identity provider to issue tokens with minimal necessary
  claims.
- **Regular rotation**: Rotate client secrets and certificates regularly.
- **Monitor access**: Enable [resource logs][monitor-resource-logs] and turn on `kube-apiserver`
  logs to inspect any potential issues with the configured JWT authenticators and track
  authentication events.
- **Test configurations**: Validate your JWT authenticator configuration in a nonproduction
  environment first.

## Security considerations

### Network access

Identity provider endpoints must be accessible from:

- AKS cluster nodes for token validation
- Client systems for token acquisition
- Any network paths involved in the authentication flow

### Prefix requirements

All usernames and groups mapped through structured authentication must be prefixed with `aks:jwt:` to prevent conflicts with other authentication methods and system accounts.

### Validation layers

Structured authentication provides multiple validation layers:

- **Token signature validation**: Ensures token authenticity
- **Standard claim validation**: Verifies issuer, audience, and expiration
- **Custom claim validation**: Applies your organization's specific requirements
- **User validation**: Final checks after claim mapping

## Next steps

- [Configure structured authentication for AKS][configure-structured-auth]
- [Kubernetes structured authentication configuration][k8s-structured-auth]
- [CEL expressions in Kubernetes][k8s-cel]
- [OpenID Connect specification][oidc-spec]

<!-- LINKS - external -->
[k8s-structured-auth]: https://kubernetes.io/blog/2024/04/25/structured-authentication-moves-to-beta/
[k8s-cel]: https://kubernetes.io/docs/reference/using-api/cel/
[oidc-spec]: https://openid.net/specs/openid-connect-core-1_0.html

<!-- LINKS - internal -->
[aks-managed-entra-id]: enable-authentication-microsoft-entra-id.md
[configure-structured-auth]: external-identity-provider-authentication-configure.md
[monitor-resource-logs]: monitor-aks-reference.md#resource-logs
