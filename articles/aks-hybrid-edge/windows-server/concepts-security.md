---
title: Security concepts in AKS on Windows Server
description: Learn about securing the infrastructure and applications on a Kubernetes cluster in AKS on Windows Server.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: leslielin
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to improve the security of the applications and infrastructure in AKS on Windows Server.
# Keyword: security concepts infrastructure security

---

# Security concepts in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Security in AKS on Windows Server involves securing the infrastructure and the applications running on the Kubernetes cluster. AKS on Windows Server supports hybrid deployment options for Azure Kubernetes Service (AKS). This article describes the security-hardening measures and the built-in security features used to secure the infrastructure and the applications on Kubernetes clusters.

## Infrastructure security

AKS on Windows Server applies various security measures to secure its infrastructure. The following diagram highlights these measures:

:::image type="content" source="../media/concepts-security/security-infrastructure.png" alt-text="Illustration showing the infrastructure security of Azure Kubernetes Service." lightbox="../media/concepts-security/security-infrastructure.png":::

The following table describes the security-hardening aspects of AKS on Windows Server that are shown in the previous diagram. For conceptual background information on the infrastructure for an AKS deployment, see [Clusters and workloads](./kubernetes-concepts.md).

| Security aspect |  Description  |
| ------  | --------|
| 1  | Because the AKS host has access to all of the workload (target) clusters, this cluster can be a single point of compromise. However, access to the AKS host is carefully controlled as the management cluster's purpose is limited to provisioning workload clusters and collecting aggregated cluster metrics. |
| 2 | To reduce deployment cost and complexity, workload clusters share the underlying Windows Server. However, depending on the security needs, admins can choose to deploy a workload cluster on a dedicated Windows Server. When workload clusters share the underlying Windows Server, each cluster is deployed as a virtual machine, which ensures strong isolation guarantees between the workload clusters. |
| 3 |  Customer workloads are deployed as containers and share the same virtual machine. The containers are process-isolated from one another, which is a weaker form of isolation compared to strong isolation guarantees offered by virtual machines.  |
| 4 | Containers communicate with each other over an overlay network. Admins can configure Calico policies to define networking isolation rules between containers. Calico policy support on AKS is only for Linux containers, and is supported as-is. |
| 5 | Communication between built-in Kubernetes components of AKS on Windows Server, including communication between the API server and the container host, is encrypted via certificates. AKS offers an out-of-the-box certificate provisioning, renewal, and revocation for built-in certificates.    |
| 6 | Communication with the API server from Windows client machines is secured using Microsoft Entra credentials for users.  |
| 7 | For every release, Microsoft provides the VHDs for AKS VMs on Windows Server and applies the appropriate security patches when needed.  |

## Application security

The following table describes the different application security options available in AKS on Windows Server:

> [!NOTE]
> You have the option to use the open source application-hardening options available in the open source ecosystem you choose.

| Option |  Description  |
| ------- | -----------|
| Build security | The goal for securing builds is to prevent vulnerabilities from being introduced in the application code or in the container images when the images are generated. Integration with Azure GitOps of Kubernetes, which is Azure Arc-enabled, helps with analysis and observation, which gives developers the opportunity to fix security issues. For more information, see [Deploy configurations using GitOps on an Azure Arc enabled Kubernetes cluster](/azure/azure-arc/kubernetes/tutorial-use-gitops-connected-cluster).  |
| Container registry security| The goal for container registry security is to ensure vulnerabilities are not introduced when uploading container images into the registry, while the image is stored in the registry, and during image downloads from the registry. AKS recommends using Azure Container Registry. Azure Container Registry comes with vulnerability scanning and other security features. For more information, see the [Azure Container Registry documentation](/azure/container-registry/).  |
| Microsoft Entra identities for Windows workloads using gMSA for containers | Windows container workloads can inherit the identity of the container host and use that for authentication. With the new enhancements, the container host doesn't need to be domain-joined. For more information, see [gMSA integration for Windows workloads](./prepare-windows-nodes-gmsa.md). |

## Built-in security features

This section describes the built-in security features that are currently available in AKS on Windows Server:

|  Security objective  |   Feature  |
|-----------   |  --------- |
| Protect access to API server.  | [Active Directory single sign-in](./ad-sso.md) support for PowerShell and Windows Admin Center clients. This feature is currently enabled only for workload clusters.  |
|  Ensure all communication between built-in Kubernetes components of the control plane is secure. This includes making sure that communication between the API server and workload cluster is also secure.| Zero touch built-in certificate solution to provision, renew, and revoke certificates. For more information, see [Secure communication with certificates](/azure/aks/aksarc/secure-communication). |
| Rotate encryption keys of the Kubernetes secret store (etcd) using the Key Management Server (KMS) plug-in. | Plug-in for integrating and orchestrating key rotation with specified KMS provider. To learn more, see [Encrypt etcd secrets](./encrypt-secrets.md). |
| Real-time threat monitoring for containers that supports workloads for both Windows and Linux containers.  | Integration with Azure Defender for Kubernetes connected to Azure Arc, which is offered as a public preview feature until the GA release of Kubernetes threat detection for Kubernetes connected to Azure Arc. For more information, see [Defend Azure Arc enabled Kubernetes clusters](/azure/security-center/defender-for-kubernetes-azure-arc?tabs=k8s-deploy-asc%2ck8s-verify-asc%2ck8s-remove-arc). |
| Microsoft Entra identity for Windows workloads.  | Use [gMSA integration for Windows workloads](./prepare-windows-nodes-gmsa.md) to configure the Microsoft Entra identity. |
| Support for Calico policies to secure traffic between pods  | Containers communicate with each other over an overlay network. Admins can configure Calico policies to define networking isolation rules between containers. Calico policy support on AKS is only for Linux containers, and is supported as-is. |

## Next steps

In this article, you learned about the concepts for securing AKS on Windows Server, and about securing applications on Kubernetes clusters.

- [Secure communication with certificates](/azure/aks/aksarc/secure-communication)
- [Encrypt etcd secrets](./encrypt-secrets.md)
