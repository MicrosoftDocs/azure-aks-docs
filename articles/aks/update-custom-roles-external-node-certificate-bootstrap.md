---
title: Update custom Azure roles for external-node certificate bootstrap
description: Update custom Azure roles with the DataAction required for external-node bootstrap and kubelet client certificate renewal in AKS.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 10/13/2026
ai-usage: ai-assisted
# Customer intent: "As an AKS administrator, I want to update custom Azure roles used by external nodes so that node bootstrap and kubelet client certificate renewal continue to work."
---

# Update custom Azure roles for external-node certificate bootstrap

Starting on November 30, 2026, Azure Kubernetes Service (AKS) requires a dedicated Azure role-based access control (Azure RBAC) DataAction to authorize kubelet client certificate issuance.

> [!IMPORTANT]
> Update affected custom Azure roles before **November 30, 2026**. Otherwise, new external nodes might fail to join the AKS cluster, and existing external nodes might fail to renew their kubelet client certificates.

This requirement applies to custom Azure roles used for external-node bootstrap or kubelet client certificate renewal, including AKS Stretch integrations. AKS-managed nodes aren't expected to be affected.

Previously, the broader `certificatesigningrequests/write` DataAction also authorized kubelet client certificate issuance. AKS is separating these permissions to help prevent principals with general certificate signing request write access from obtaining certificates that authenticate them as Kubernetes nodes.

## Determine whether a custom role is affected

A custom role is affected if it's used for either of the following operations:

- External-node bootstrap.
- Kubelet client certificate renewal for an external node.

If a custom role is used only for general certificate signing request operations, you don't need to add the new permission.

Review the role IDs in your Azure Service Health notification or your role inventory, and determine how each role is used. Retain each affected role's existing certificate signing request and API discovery permissions.

## Add the required DataAction

Add the DataAction that corresponds to the resource endpoint used by your integration:

| Resource endpoint | Required DataAction |
| --- | --- |
| Managed cluster | `Microsoft.ContainerService/managedClusters/certificates.k8s.io/certificatesigningrequests/nodeclient/action` |
| Fleet hub | `Microsoft.ContainerService/fleets/certificates.k8s.io/certificatesigningrequests/nodeclient/action` |
| Fleet member | `Microsoft.ContainerService/fleets/members/certificates.k8s.io/certificatesigningrequests/nodeclient/action` |
| AI Manager | `Microsoft.ContainerService/aiManagers/certificates.k8s.io/certificatesigningrequests/nodeclient/action` |

For example, a custom role used for external-node bootstrap through a managed-cluster endpoint includes the following permissions:

```json
{
  "DataActions": [
    "Microsoft.ContainerService/managedClusters/certificates.k8s.io/certificatesigningrequests/write",
    "Microsoft.ContainerService/managedClusters/certificates.k8s.io/certificatesigningrequests/read",
    "Microsoft.ContainerService/managedClusters/certificates.k8s.io/certificatesigningrequests/delete",
    "Microsoft.ContainerService/managedClusters/apis/certificates.k8s.io/read",
    "Microsoft.ContainerService/managedClusters/apis/certificates.k8s.io/v1beta1/read",
    "Microsoft.ContainerService/managedClusters/certificates.k8s.io/certificatesigningrequests/nodeclient/action"
  ]
}
```

For Fleet hub, Fleet member, or AI Manager access, use the corresponding resource path from the preceding table.

To update an affected role:

1. Retrieve the current role definition.
1. Add the applicable `certificatesigningrequests/nodeclient/action` permission to the role's `DataActions` property.
1. Confirm that all existing certificate signing request and API discovery permissions remain unchanged.
1. [Update the custom role definition](/azure/role-based-access-control/custom-roles).
1. Allow time for the Azure RBAC update to propagate.

## Validate the role update

After you update an affected custom role:

1. Retrieve the role definition, and confirm that the applicable `certificatesigningrequests/nodeclient/action` permission appears in `DataActions`.
1. Confirm that all existing certificate signing request and API discovery permissions remain unchanged.
1. In a test environment, perform an end-to-end external-node bootstrap test, and confirm that the node reaches the `Ready` state.
1. For an existing integration, verify that the kubelet client certificate can be renewed successfully through your normal validation process.

Allow approximately one hour for the end-to-end external-node bootstrap test. The total time required might vary depending on your organization's change-management process and the number of roles being updated.

## Next steps

- [Learn about certificate management and rotation in AKS](./certificate-rotation.md).
- [Learn about Azure custom roles](/azure/role-based-access-control/custom-roles).
