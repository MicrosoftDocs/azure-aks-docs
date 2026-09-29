---
title: AKS Hybrid and Edge data collection
description: Learn about the data exchanged between Kubernetes clusters and Azure.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.reviewer: rbaziwane
ms.custom: overview

# Intent: As an IT Pro, I want to learn about the data exchanged between Kubernetes clusters and Azure.
# Keyword: security concepts infrastructure security

---

# AKS Hybrid and Edge data collection

[AKS Hybrid and Edge](windows-server/overview.md) is a service that enables you to run Kubernetes clusters in your own infrastructure, using Azure Arc to connect and manage them. AKS collects data from clusters and connected machines to provide you with features such as monitoring, policy enforcement, and security updates. This article explains what data is collected, how it's classified, and how you can control it.

During the deployment of AKS, you must furnish a subscription and an Azure region in which data is stored. The Azure region is a virtual representation of your on-premises resources and doesn't correspond to the actual physical on-premises location. It represents the region in which Microsoft-operated datacenters store this data.

> [!IMPORTANT]
> Microsoft does not collect any sensitive information that might be classified as [Personally Identifiable Information (PII)](https://www.microsoft.com/microsoft-365-life-hacks/privacy-and-safety/what-is-pii). For more information, see the following [data collection section](#data-collection-and-residency).

There are three separate tiers to consider when curating data collection and exchange for on-premises deployments. This article describes the data exchanged between Kubernetes clusters (Tier 2) and Azure. See the public documentation for descriptions of data collection and exchange between [tier 1](/azure/azure-arc/kubernetes/conceptual-data-exchange) and [tier 3](/azure-stack/hci/concepts/data-collection).

- Tier 1: Azure Arc-enabled services such as Azure Monitor, Azure Defender, Event Grid, etc.
- Tier 2: Kubernetes clusters: AKS Hybrid and Edge.
- Tier 3: Physical host, such as Windows Server or Azure Local.

## Data collection and residency

AKS data is sent in JSON format, and is stored in a secure Microsoft-operated datacenter, as follows:

- Billing data is sent to the respective resource of that region in which you registered the device.
- Telemetry data (classified as "non-personal data") is stored within the region you selected at the time of deployment, and is forwarded to a central US store for the engineering team to use for product improvement and business analytics.

For information about how Microsoft stores diagnostic data in Azure, see [Data residency in Azure](https://azure.microsoft.com/global-infrastructure/data-residency/).

## Data retention

After AKS collects this data, it's retained for 28 days. AKS might keep aggregated, de-identified data for a longer period in order to track reliability of the service and inform product improvements.

## What data is collected?

AKS collects the following types of data:

- **Events related to the Hyper-V host operating systems**: Details such as the operating system name, version, and model. Identifiers include event names and event dates for precise event tracking. Various flags, both integer and Boolean, denote specific conditions or statuses, device, and operating system attributes. These flags include the name, device ID, and ISO country code. The data schema for these events incorporates a range of data types, including strings, integers, datetimes, and Booleans.
- **Events associated with the Kubernetes clusters control plane**: Specific metrics include cluster creation timestamps, pods, and node counts, and resource metrics including vCore counts. This data is used for monitoring and management of the Kubernetes cluster. The data schema for these events includes a range of data types, including Boolean, string, integer, and double.
- **Events pertaining to Hyper-V host operating system**: Emitted errors are captured for diagnostic and monitoring purposes. The predominant data schema used is the string format to encapsulate both the error message and the associated stack trace. Support is currently extended to the Windows Server and Azure Local platforms.
- **Events pertaining to Mariner Linux VMs**: Includes system boot and shutdown, service status changes, kernel messages, application errors, and user authentication activities only for system namespaces.
- **Billing events**: Events related to metering or billing of core usage. This set of events includes the event datetime and the quantity of cores. The data types include datetime for the event timing, and a floating-point number for the quantity.
- **Security events**: Aggregated events related to renewal of digital certificates and the functioning of the Key Management Service (KMS) plugin. These events enable tracking of certificate lifecycles, encryption key statuses, revocations, and renewals. The underlying data schema employs string data types to encapsulate this important information.
- **Diagnostics settings**: By installing the **Microsoft.AKSArc.AzureMonitor** Arc Kubernetes extension, you can enable the collection of Kubernetes audit and diagnostic data via Azure Monitor from the cluster control plane. See the [kube-apiserver audit configuration documentation](https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/#resource-types). This data is saved to customer-configured storage, and any intermediate data that Microsoft collects to facilitate export to customer storage is deleted within 48 hours.

> [!NOTE]
> All events use either the Windows Universal Telemetry Client (UTC) or the Mariner Azure Device Health Service (ADHS).

For more information about Azure data collection and privacy policies, see the [Microsoft Privacy Statement](https://privacy.microsoft.com/privacystatement).

## Next steps

[AKS Hybrid and Edge overview](aks-overview.md)
