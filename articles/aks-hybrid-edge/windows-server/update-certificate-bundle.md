---
title: Update a certificate bundle on container hosts
description: Learn how to add a certificate chain of trust (root, intermediate and lead certificates) with public key in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: sulahiri
ms.custom: windows-server

---

# Update certificate bundle on container hosts

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

An AKS cluster needs to trust other on-premises resources such as the container registry. This article describes how to add a certificate chain of trust (root, intermediate and lead certificates) with a public key, for the endpoints the cluster is expected to trust and allow communication. The certificates are added on the Linux hosts.

This scenario uses a modified version of the [noProxy settings](proxy-change.md) command.

## Prerequisites and details

- An AKS on Windows Server deployment running the October 2022 release or later.
- The certificates aren't immediately available upon running the command; they're deployed on the next update.
- You can check if there's an update available using the PowerShell cmdlet [Get-AksHciClusterUpdates](/azure/aks/aksarc/reference/ps/get-akshciclusterupdates).
- Currently there's no command to view, change, or delete scheduled update. Once the update is applied, it's possible to SSH into the container host and see the certs installed, then delete them.

## Certificate format

- The certificates should be specified in a single .crt file in PEM format. This format is applicable for updating certificates on Linux container hosts.
- It's important to make sure the certificates are added in the right order in a single .crt file. For example, `<.leaf.crt>`, `<intermediate.crt>`,`<root.crt>`.
- The contents of the certificate file aren't validated. You must ensure that the file contains the right certificates and is in the correct format.

## Example: create a single certificate bundle

For Linux hosts:

```bash
cat [leaf].crt  [intermediate].crt [Root].crt >  [your single cert file].crt
```

PowerShell:

```powershell
$noProxy = "" # keep this as an empty string
$certFile ="/../[bundle].crt" # path to the bundled .crt file
Set-AksHciProxySetting -noProxy $noProxy -certFile $certFile
```

## Next steps

[AKS overview](overview.md)
