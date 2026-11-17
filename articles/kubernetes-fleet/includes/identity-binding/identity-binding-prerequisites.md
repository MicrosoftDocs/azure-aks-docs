---
ms.author: yoobinshin
ms.topic: include
ms.date: 10/06/2026
ms.service: azure-kubernetes-fleet-manager
---

* Member clusters must have [workload identity](/azure/aks/workload-identity-overview) and OIDC issuer enabled.
* Member clusters configured with [API server VNet integration](/azure/aks/api-server-vnet-integration) aren't supported.
* Arc-enabled Kubernetes clusters aren't supported.
* An identity binding profile can authorize a maximum of 100 subjects.
* Identity Binding properties (name and managed identity) can't be changed after creation.
* Fleet Manager doesn't take over identity bindings that already exist on a member cluster.
* Identity bindings configured and distributed by Fleet Manager can't be directly modified on member clusters.
