---
title: Migrate AWS Web Application to AKS
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

# Migrate AWS Web Application to AKS

Since the [Yelb][yelb] application is self-contained and does not rely on external services, migrating it from AWS to Azure can be done without any code changes. On AWS, [Amazon ElastiCache][aws-cache] and [DynamoDB][aws-dynamodb] can be used as replacements for the Redis Cache and PostgreSQL instances deployed on [Amazon Elastic Kubernetes Service (EKS)][aws-eks]. On Azure, [Azure Cache for Redis][azure-redis] and [Azure Database for PostgreSQL][azure-postgresql] can be used as replacements for the Redis Cache and PostgreSQL services deployed on [Azure Kubernetes Service (AKS)][aks].

## Handling Cloud Platform API Dependencies
In a real-world scenario, migrating a web application from AWS to Azure may require refactoring the code if the application relies on specific cloud platform APIs or SDKs. For example, if the web application uses [Amazon Simple Storage Service (S3)][aws-s3] storage to store unstructured data and you plan to use [Azure Bob Storage][azure-blob] as a replacement on the Azure platform, you have two alternative solutions:

1. Refactor the code to replace the Amazon S3 API with the [Azure Storage REST API][azure-blob-api] or the [Microsoft Azure Storage SDK][azure-storage-sdk] for one of the supported programming languages (.NET, Java, JavaScript, Python, and Go). This solution involves modifying the codebase to use the equivalent Azure Storage APIs.
2. Use an S3 gateway to access AWS S3 and Azure Storage seamlessly, without requiring any code changes. Here are two S3 gateways:
- [MinIO Gateway](https://min.io/): Minio is an open-source S3-compatible object storage server that can be used as a gateway to Azure Storage. It allows you to access Azure Blob storage using the S3 API. Minio provides a simple and lightweight solution for S3 API compatibility on Azure.
- [S3Proxy](https://github.com/andrewgaul/s3proxy): S3Proxy is an open-source S3-compatible proxy server that can be used as a gateway to various storage backends, including Azure Storage. It translates S3 API calls to the appropriate Azure Storage API calls, providing compatibility and flexibility for accessing Azure Storage using the S3 API.

## Migrating from AWS IAM to Azure RBAC

If the web application on AWS utilizes an [AWS Identity and Access Management (IAM)][aws-iam] role for accessing managed services, the role needs to be assigned to [EKS][aws-eks] pods to grant access to AWS resources such as [Amazon Simple Storage Service (S3)][aws-s3]. In contrast, Azure implements [role-based access control (RBAC)][azure-rbac] differently from AWS. In Azure, you can assign a [role][azure-role-assignment] to users, groups, service principals, or managed identities at a specific scope: management group, subscription, resource group, or resource. This allows you to grant specific permissions to the workload identity on a Microsoft Entra protected resource. To achieve this, follow these steps:

- Create a [user-assigned managed identity][azure-user-assigned-managed-identity] [Kubernetes service account][kubernetes-sa] for the workload.
- Assign the necessary [roles][azure-role-assignment] to the managed identity to let the AKS-hosted workload access the required Microsoft Entra protected resources.
- Enable the OpenID Connect issuer and Microsoft Entra Workload ID on your AKS cluster. For detailed instructions, refer to [Deploy and configure workload identity on an Azure Kubernetes Service (AKS) cluster][aks-oidc]
- Create a token federation for the managed identity with the [Kubernetes service account][kubernetes-sa] used by the workload on AKS.

[Microsoft Entra Workload ID][entra] uses [Service Account Token Volume Projection][token-projection], specifically a service account, to enable pods to use a Kubernetes identity. A Kubernetes token is issued and [OIDC federation][oidc-federation] enables Kubernetes applications to access Azure resources securely with Microsoft Entra ID, based on annotated service accounts. 

Microsoft Entra Workload ID works particularly well with the [Azure Identity client libraries][identity-libraries] or the [Microsoft Authentication Library][msal], along with [application registration][app-registration]. These libraries enable your workload to authenticate seamlessly and access Azure cloud resources. For more information, see [Use Microsoft Entra Workload ID with Azure Kubernetes Service (AKS)][aks-workload-id].

## Next steps

> [!div class="nextstepaction"]
> [Prepare to Deploy Web Application Workload to Azure][eks-web-prepare]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

<!-- LINKS -->
[yelb]: https://github.com/mreferre/yelb/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-dynamodb]: https://aws.amazon.com/it/dynamodb/
[aws-cache]: https://aws.amazon.com/it/elasticache/
[aws-s3]: https://aws.amazon.com/s3
[aws-iam]: https://aws.amazon.com/iam/
[kubernetes-sa]: https://kubernetes.io/docs/concepts/security/service-accounts/
[aks]: ./what-is-aks.md
[azure-redis]: /azure/azure-cache-for-redis/cache-overview
[azure-postgresql]: /azure/postgresql/flexible-server/service-overview
[azure-blob]: /azure/storage/blobs/storage-blobs-overview
[azure-blob-api]: /rest/api/storageservices/blob-service-rest-api
[azure-storage-sdk]: /azure/storage/common/storage-srp-overview?tabs=dotnet
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