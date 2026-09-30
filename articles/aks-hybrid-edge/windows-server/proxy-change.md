---
title: Update noProxy settings, certificates in Azure Kubernetes Service
description: Learn how to update proxy settings and certificates in AKS on Windows Server.
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 05/31/2022
ms.reviewer: srikantsarwa
ms.custom: windows-server
author: davidsmatlak

# Intent: As an IT Pro, I need to know how to update my proxy settings and upload new certificates for the proxy server.
# Keyword: noProxy proxy settings certificate updates

---

# Update proxy server settings and certificates

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to update proxy settings and certificates for your deployment in AKS on Windows Server. Each AKS deployment has a single global proxy configuration. You can add exclusions using the `noProxy` parameter to exclude private subnets (for example, contoso.com) from using the proxy server, and you can update proxy certificates for the deployment. You can't change HTTP or HTTPS settings.

For information about the initial proxy server setup, see [Use proxy server settings in AKS](set-proxy-settings.md).

## Proxy settings you can update

Before you begin, review current limitations to proxy setting updates you can perform in AKS on Windows Server:

- AKS on Windows Server supports one global proxy configuration per AKS deployment. When you update the proxy settings, they're updated for the entire AKS deployment.
- You can only update `noProxy` settings, which are used to exclude a private subnet from using the proxy server, and proxy certificates. HTTP and HTTPs proxy settings can't be updated.
- You can't configure different proxy settings for a specific node pool or workload cluster. Similarly, you can't update proxy settings for a specific node pool or workload cluster.
- Updates to proxy settings are only applied after you update your entire AKS deployment. You must update the AKS host management cluster and all AKS workload clusters. To check whether an update is available, use the AKS PowerShell module cmdlet [Get-AksHciClusterUpdates](/azure/aks/aksarc/reference/ps/get-akshciclusterupdates).

## Prerequisites

Before you update proxy settings for an AKS deployment, you must meet the following prerequisites:

- Your AKS deployment is running the [October 2022 update](https://github.com/Azure/aks-hybrid/releases/tag/AKS-hybrid-2210) or later.
- The most recent version of the AksHci PowerShell module is installed. For more information, see [Install the AksHci PowerShell module](kubernetes-walkthrough-powershell.md#install-the-akshci-powershell-module).
- At least one update is available for your AKS deployment. Updates to proxy settings and certificates are applied automatically after updates are applied to an AKS deployment. To check for available updates, run the [`Get-AksHciClusterUpdates`](/azure-stack/aks-hci/reference/ps/get-akshciclusterupdates) command in the AksHci PowerShell module.

## Step 1: Create a new noProxy exclusion list

You might occasionally need to update `noProxy` settings to exclude a private subnet from using the proxy server for your AKS deployment. To prepare to update the `noProxy` settings, store a new exclusion list in a PowerShell variable.

1. Before you update your `noProxy` settings, review the required `noProxy` settings in the [proxy exclusion table](set-proxy-settings.md#exclusion-list-for-excluding-private-subnets-from-being-sent-to-the-proxy). For more information, see [Exclusion list for excluding private subnets from being sent to the proxy](set-proxy-settings.md#exclusion-list-for-excluding-private-subnets-from-being-sent-to-the-proxy).

   Certain exclusions are required for your AKS deployment to function. Not excluding these URLs can cause failures in your AKS deployment.

1. Store your updated `noProxy` URL list in a PowerShell variable:

   ```powershell
   $noProxy = "localhost,127.0.0.1,.svc,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.contoso.com"
   ```

## Step 2: Create a proxy certificate bundle

To update certificates for your proxy server, create a new certificate bundle and then store the path to the file in a PowerShell variable. Bundle the certificates in a single .crt file in PEM format. This format is applicable for updating certificates on Linux container hosts.

To bundle your updated proxy server certificates:

1. Create a single .crt file with the bundled certificates for Linux hosts. Use the `concatenate` (`cat`) command with the following format:

   ```bash
   cat [leaf].crt  [intermediate].crt  [Root].crt > [bundle].crt
   ```

   You must concatenate the certificates in the order of: **leaf certificate > intermediate certificate > root certificate**. For detailed certificate requirements and an example, see [Update certificate bundle for your AKS deployment](update-certificate-bundle.md#certificate-format).

   > [!NOTE]
   > The contents of the certificate file aren't validated. Check carefully to ensure the file contains the right certificates and is in the correct format.

1. Store the path to your updated certificate bundle in a PowerShell variable:

   ```powershell
   $certFile ="/../[certificate-bundle].crt" # path to the bundled .crt file
   ```

## Step 3: Update proxy settings

The next step is to use the `Set-AksHciProxySetting` command to update your `noProxy` settings and certificates.

1. Before you update the proxy settings and certificates, confirm that your PowerShell variables have the right changes:

   ```powershell
   echo $noProxy
   echo $certFile
   ```

1. To update both your proxy settings and proxy certificates, run the following command:

   ```powershell
   Set-AksHciProxySetting -noProxy $noProxy -certFile $certFile
   ```

## Step 4: Apply updated proxy settings to your AKS deployment

The updates to your global proxy settings and certificate are applied automatically after you update the AKS deployment.

To apply the proxy updates:

1. Check whether an update is available for your AKS host management cluster by running the following command:

   ```powershell
   Get-AksHciUpdates
   ```

1. If an update is available, update your AKS host management cluster by running the following command. This command applies the proxy changes on your AKS host management cluster:

   ```powershell
   Update-AksHci
   ```

1. Update all of the workload clusters in your AKS deployment. Proxy changes won't be applied unless you update your workload clusters.

   1. To check whether workload cluster updates are available, run the following command on each of your AKS workload clusters:

      ```powershell
      Get-AksHciClusterUpdates -name mycluster
      ```

   1. If an update is available (either a Kubernetes version or an updated OS image), update each of your workload clusters by running the `Update-AksHciCluster` command.

      - To update the Kubernetes version and OS version on a workload cluster, run the following command:

        ```powershell
        Update-AksHciCluster -name mycluster
        ```

      - To update the OS without updating the Kubernetes version, include the  `-operatingSystem` parameter:

        ```powershell
        Update-AksHciCluster -name mycluster -operatingSystem
        ```

        If an OS image-only update isn't available for your workload cluster, you won't be able to apply the proxy changes unless you update the Kubernetes version.

## Next steps

For more information about networking in AKS on Windows Server, see [Kubernetes networking concepts](concepts-node-networking.md).
