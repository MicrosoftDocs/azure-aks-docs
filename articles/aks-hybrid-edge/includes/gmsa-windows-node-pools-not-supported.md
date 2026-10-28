---
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
---

### gMSA authentication isn't supported for Windows node pools on Azure Local 23H2 and 24H2

[Group Managed Service Account (gMSA)](/windows-server/identity/ad-ds/manage/group-managed-service-accounts/group-managed-service-accounts/group-managed-service-accounts-overview) authentication for Windows node pools isn't supported on AKS on Azure Local 23H2 and 24H2 or Windows node pools that require gMSA-based authentication for Active Directory access.

The gMSA components are preinstalled on Windows node pools, but the configuration path to set up gMSA authentication isn't available through CLI commands, APIs, or other management tools. Customers who follow standard Kubernetes documentation for Windows containers and create a credential spec receive anonymous sign-in failures because the required `HostAccountConfig` configuration isn't supported.

For example, after deploying a Windows container workload that requires gMSA-based authentication (Kerberos or NTLM), pods fail to authenticate against Active Directory. Applications receive `NT AUTHORITY\ANONYMOUS LOGON` errors for all Kerberos and NTLM authentication calls from the container.

An option to resolve this limitation is to move workloads to a platform that supports gMSA for Windows nodes, like Azure Kubernetes Service (AKS). For more information, see how to [enable gMSA for Windows Server nodes on an Azure Kubernetes Service (AKS) cluster](/azure/aks/use-group-managed-service-accounts).
