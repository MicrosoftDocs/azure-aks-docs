---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 06/12/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> Starting on September 14, 2026, the preview property `enableCustomCATrust` will retire. After that date, the `enableCustomCATrust=true` node pool-level field will no longer enable the Custom Certificate Authority (CA) feature in AKS. The last preview API that supports this property is `2025-08-02-preview`. Existing node pools that still rely on `enableCustomCATrust=true` might experience failures during scaling operations or when certificates are updated. To avoid service disruption, update the impacted clusters and node pools and remove the preview property before September 14, 2026. For migration steps, see [`enableCustomCATrust` (preview) retirement migration](../custom-certificate-authority.md#enablecustomcatrust-preview-retirement-migration). For more information on this retirement, see the [Retirement GitHub issue](https://github.com/Azure/AKS/issues/5826). To stay informed about announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).
