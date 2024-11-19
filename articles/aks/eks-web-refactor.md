---
title: Migrate AWS web application to AKS
description: Step-by-step guide on updating and migrating the AWS web application to Azure Kubernetes Service (AKS).
author: paolosalvatori
ms.author: paolos
ms.topic: how-to
ms.date: 10/31/2024
ms.service: azure-kubernetes-service
ms.custom: 
    - migration
    - aws-to-azure
    - eks-to-aks
---

# Migrate AWS web application to AKS

This article outlines key considerations for migrating the Yelb application from AWS to AKS. Remember that since the [Yelb][yelb] application is self-contained and doesn't rely on external services, migrating it from AWS to Azure can be done without any code changes. 

## Migrating from AWS IAM to Azure RBAC

If the web application on AWS uses an [AWS Identity and Access Management (IAM)][aws-iam] role for accessing managed services, you need to assign the role to the [EKS][aws-eks] pods to grant access to AWS resources. In contrast, Azure implements [role-based access control (RBAC)][azure-rbac] differently than AWS. In Azure, you can assign a [role][azure-role-assignment] to users, groups, service principals, or managed identities at a specific scope: management group, subscription, resource group, or resource. This allows you to grant specific permissions to the workload identity on a Microsoft Entra protected resource.

You can configure Azure RBAC using the following steps:

1. Create a [user-assigned managed identity][azure-user-assigned-managed-identity] and [Kubernetes service account][kubernetes-sa] for the workload.
1. Assign the necessary [roles][azure-role-assignment] to the managed identity to let the AKS-hosted workload access the required Microsoft Entra protected resources.
1. Enable the OpenID Connect (OIDC) issuer and Microsoft Entra Workload ID on your AKS cluster. For detailed instructions, see [Deploy and configure workload identity on an Azure Kubernetes Service (AKS) cluster][aks-oidc]
1. Create a token federation for the managed identity with the [Kubernetes service account][kubernetes-sa] used by the workload on AKS.

[Microsoft Entra Workload ID][entra] uses [Service Account Token Volume Projection][token-projection], specifically a service account, to enable pods to use a Kubernetes identity. A Kubernetes token is issued and [OIDC federation][oidc-federation] enables Kubernetes applications to securely access Azure resources with Microsoft Entra ID based on annotated service accounts. 

Microsoft Entra Workload ID works well with the [Azure Identity client libraries][identity-libraries] or the [Microsoft Authentication Library][msal], along with [application registration][app-registration]. These libraries enable your workload to authenticate seamlessly and access Azure cloud resources. For more information, see [Use Microsoft Entra Workload ID with Azure Kubernetes Service (AKS)][aks-workload-id].

## Next step

> [!div class="nextstepaction"]
> [Prepare to deploy web application workload to Azure][eks-web-prepare]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

Principal author:
- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

Other contributors:
- [Erin Schaffer](https://www.linkedin.com/in/erin-schaffer-65800215b/) | Content Developer 2

<!-- LINKS -->
[yelb]: https://github.com/mreferre/yelb/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-iam]: https://aws.amazon.com/iam/
[kubernetes-sa]: https://kubernetes.io/docs/concepts/security/service-accounts/
[azure-user-assigned-managed-identity]: /entra/identity/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azp
[azure-rbac]: /azure/role-based-access-control/overview
[azure-role-assignment]: /azure/role-based-access-control/role-assignments-portal
[aks-oidc]: /azure/aks/workload-identity-deploy-cluster
[aks-workload-id]:/azure/aks/workload-identity-overview?tabs=dotnet
[eks-web-prepare]: ./eks-web-prepare.md
[entra]: /azure/active-directory/develop/workload-identities-overview
[token-projection]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection
[oidc-federation]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens
[identity-libraries]: /azure/aks/workload-identity-overview?tabs=dotnet#azure-identity-client-libraries
[msal]: /azure/active-directory/develop/msal-overview
[app-registration]: /azure/active-directory/develop/application-model#register-an-application