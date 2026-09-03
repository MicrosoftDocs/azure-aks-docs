---
title: Network validation error due to .local domain
description: Learn how to troubleshoot network validation errors due to the .local domain.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: troubleshooting
ms.date: 09/01/2026
ms.reviewer: pradwivedi
ms.lastreviewed: 04/30/2025
ms.custom: hyperconverged

---

# Troubleshoot network validation error due to .local domain

This article describes how to resolve the `Not able to connect to http://cloudagent.contoso.local:50000` error. This error occurs when you try to create and deploy an AKS on Azure Local cluster.

## Symptoms

You can deploy `.local` domains on Azure Local but might sometimes encounter failures during AKS scenarios, such as create, scale, update, upgrade, and delete. You might see the following error message:

`Error: Network validation failed during cluster creation. Detailed message: Not able to connect to http://cloudagent.contoso.local:50000. Error returned: action failed after 5 attempts: Get "http://cloudagent.contoso.local:50000": dial tcp: lookup http://cloudagent.contoso.local: Temporary failure in name resolution`

## Possible causes

There are two possible causes for this error:

1. Because `.local` is an officially reserved special-use domain name, host names with this top-level label are only resolvable via the multicast DNS name resolution protocol. Other mechanisms such as unicast DNS can also be used to resolve this name.

   When a URL ending with `.local` for the failover cluster is used, a fully qualified domain name (FQDN) ending with `.local` is also used for the MOC cloud agent. The Azure Local 2503 release consists of various network validation tests. One of the tests tries to connect to the MOC cloud FQDN from the AKS control plane VM. This specific test fails when the MOC cloud agent FQDN uses the `.local` domain name. This is because the **Go HTTP** client relies on standard DNS resolution, so it doesn't automatically resolve the `.local` address via mDNS.

1. When the on-premises directory is synchronized with Microsoft 365, you must have a verified domain in Microsoft Entra ID. Only the user principal names (UPNs) that are associated with the on-premises Active Directory Domain Services (AD DS) domain are synchronized. However, any UPN that contains a non-routable domain, such as `.local` (for example, `billa@contoso.local`), is synchronized to an `.onmicrosoft.com` domain (for example, `billa@contoso.onmicrosoft.com`). For more information, see [Prepare a nonroutable domain for directory synchronization](/microsoft-365/enterprise/prepare-a-non-routable-domain-for-directory-synchronization?view=o365-worldwide&preserve-view=true).

## Mitigation

If you are on Azure Local 2503 or a later release, don't use `.local` in the domain name.

Per the [possible cause #2](#possible-causes), if you currently use a `.local` domain for your user accounts in AD DS, we recommend that you change them to use a verified domain; for example, `billa@contoso.com`, to properly synchronize with your Microsoft 365 domain.

As a temporary mitigation, the checks for the `.local` domain are disabled in the Azure Local 2504 release. For more information, see [What's new in Azure Local, version 2504](/azure/azure-local/whats-new?view=azloc-2504&preserve-view=true).

## Next steps

[Troubleshoot issues in AKS Hybrid and Edge](aks-troubleshoot.md)
