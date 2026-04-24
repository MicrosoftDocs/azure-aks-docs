---
title: AKS service permissions reference
titleSuffix: Azure Kubernetes Service
description: Reference for the Azure permissions required by the identity creating an AKS cluster, the cluster identity at runtime, and AKS node access.
ms.topic: reference
ms.subservice: aks-security
ms.date: 04/19/2026
author: shashankbarsin
ms.author: shasb
ai-usage: ai-assisted
# Customer intent: As an Azure Kubernetes Service (AKS) administrator, I want a reference of the Azure permissions used by AKS so that I can grant the right roles to the identity creating the cluster and to the cluster identity at runtime.
---

# AKS service permissions reference

When creating a cluster, AKS generates or modifies resources it needs (like VMs and NICs) to create and run the cluster on behalf of the user. This identity is distinct from the cluster's identity permission, which is created during cluster creation.

For the built-in roles used to grant these permissions, see [Azure built-in roles for Containers](/azure/role-based-access-control/built-in-roles#containers). For a worked example of granting a service principal the permissions needed for a custom virtual network, see [Use a service principal with AKS](kubernetes-service-principal.md). For an orientation across the four AKS identity scenarios, see [Access and identity options for AKS](concepts-identity.md).

## Identity creating and operating the cluster permissions

The following permissions are needed by the identity creating and operating the cluster.

> [!div class="mx-tableFixed"]
> | Permission | Reason |
> |---|---|
> | `Microsoft.Compute/diskEncryptionSets/read` | Required to read disk encryption set ID. |
> | `Microsoft.Compute/proximityPlacementGroups/write` | Required for updating proximity placement groups. |
> | `Microsoft.Network/applicationGateways/read` <br/> `Microsoft.Network/applicationGateways/write` <br/> `Microsoft.Network/virtualNetworks/subnets/join/action` | Required to configure application gateways and join the subnet. |
> | `Microsoft.Network/virtualNetworks/subnets/join/action` | Required to configure the Network Security Group for the subnet when using a custom VNET.|
> | `Microsoft.Network/publicIPAddresses/join/action` <br/> `Microsoft.Network/publicIPPrefixes/join/action` | Required to configure the outbound public IPs on the Standard Load Balancer. |
> | `Microsoft.OperationalInsights/workspaces/sharedkeys/read` <br/> `Microsoft.OperationalInsights/workspaces/read` <br/> `Microsoft.OperationsManagement/solutions/write` <br/> `Microsoft.OperationsManagement/solutions/read` <br/> `Microsoft.ManagedIdentity/userAssignedIdentities/assign/action` | Required to create and update Log Analytics workspaces and Azure monitoring for containers. |
> | `Microsoft.Network/virtualNetworks/joinLoadBalancer/action` | Required to configure the IP-based Load Balancer Backend Pools. |

## AKS cluster identity permissions

The following permissions are used by the AKS cluster identity, which is created and associated with the AKS cluster. Each permission is used for the reasons below:

> [!div class="mx-tableFixed"]
> | Permission | Reason |
> |---|---|
> | `Microsoft.ContainerService/managedClusters/*`  <br/> | Required for creating users and operating the cluster
> | `Microsoft.Network/loadBalancers/delete` <br/> `Microsoft.Network/loadBalancers/read` <br/> `Microsoft.Network/loadBalancers/write` | Required to configure the load balancer for a LoadBalancer service. |
> | `Microsoft.Network/publicIPAddresses/delete` <br/> `Microsoft.Network/publicIPAddresses/read` <br/> `Microsoft.Network/publicIPAddresses/write` | Required to find and configure public IPs for a LoadBalancer service. |
> | `Microsoft.Network/publicIPAddresses/join/action` | Required for configuring public IPs for a LoadBalancer service. |
> | `Microsoft.Network/networkSecurityGroups/read` <br/> `Microsoft.Network/networkSecurityGroups/write` | Required to create or delete security rules for a LoadBalancer service. |
> | `Microsoft.Compute/disks/delete` <br/> `Microsoft.Compute/disks/read` <br/> `Microsoft.Compute/disks/write` <br/> `Microsoft.Compute/locations/DiskOperations/read` | Required to configure AzureDisks. |
> | `Microsoft.Storage/storageAccounts/delete` <br/> `Microsoft.Storage/storageAccounts/listKeys/action` <br/> `Microsoft.Storage/storageAccounts/read` <br/> `Microsoft.Storage/storageAccounts/write` <br/> `Microsoft.Storage/operations/read` | Required to configure storage accounts for AzureFile or AzureDisk. |
> | `Microsoft.Network/routeTables/read` <br/> `Microsoft.Network/routeTables/routes/delete` <br/> `Microsoft.Network/routeTables/routes/read` <br/> `Microsoft.Network/routeTables/routes/write` <br/> `Microsoft.Network/routeTables/write` | Required to configure route tables and routes for nodes. |
> | `Microsoft.Compute/virtualMachines/read` | Required to find information for virtual machines in a VMAS, such as zones, fault domain, size, and data disks. |
> | `Microsoft.Compute/virtualMachines/write` | Required to attach AzureDisks to a virtual machine in a VMAS. |
> | `Microsoft.Compute/virtualMachineScaleSets/read` <br/> `Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read` <br/> `Microsoft.Compute/virtualMachineScaleSets/virtualmachines/instanceView/read` | Required to find information for virtual machines in a virtual machine scale set, such as zones, fault domain, size, and data disks. |
> | `Microsoft.Network/networkInterfaces/write` | Required to add a virtual machine in a VMAS to a load balancer backend address pool. |
> | `Microsoft.Compute/virtualMachineScaleSets/write` | Required to add a virtual machine scale set to a load balancer backend address pools and scale out nodes in a virtual machine scale set. |
> | `Microsoft.Compute/virtualMachineScaleSets/delete` | Required to delete a virtual machine scale set to a load balancer backend address pools and scale down nodes in a virtual machine scale set. |
> | `Microsoft.Compute/virtualMachineScaleSets/virtualmachines/write` | Required to attach AzureDisks and add a virtual machine from a virtual machine scale set to the load balancer. |
> | `Microsoft.Network/networkInterfaces/read` | Required to search internal IPs and load balancer backend address pools for virtual machines in a VMAS. |
> | `Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/read` | Required to search internal IPs and load balancer backend address pools for a virtual machine in a virtual machine scale set. |
> | `Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/ipconfigurations/publicipaddresses/read` | Required to find public IPs for a virtual machine in a virtual machine scale set. |
> | `Microsoft.Network/virtualNetworks/read` <br/> `Microsoft.Network/virtualNetworks/subnets/read` | Required to verify if a subnet exists for the internal load balancer in another resource group. |
> | `Microsoft.Compute/snapshots/delete` <br/> `Microsoft.Compute/snapshots/read` <br/> `Microsoft.Compute/snapshots/write` | Required to configure snapshots for AzureDisk. |
> | `Microsoft.Compute/locations/vmSizes/read` <br/> `Microsoft.Compute/locations/operations/read` | Required to find virtual machine sizes for finding AzureDisk volume limits. |

## Additional AKS cluster identity permissions

When creating a cluster with specific attributes, you will need the following additional permissions for the cluster identity. Since these permissions are not automatically assigned, you must add them to the cluster identity after it's created.

> [!div class="mx-tableFixed"]
> | Permission | Reason |
> |---|---|
> | `Microsoft.Network/networkSecurityGroups/write` <br/> `Microsoft.Network/networkSecurityGroups/read` | Required if using a network security group in another resource group. Required to configure security rules for a LoadBalancer service. |
> | `Microsoft.Network/virtualNetworks/subnets/read` <br/> `Microsoft.Network/virtualNetworks/subnets/join/action` | Required if using a subnet in another resource group such as a custom VNET. |
> | `Microsoft.Network/routeTables/routes/read` <br/> `Microsoft.Network/routeTables/routes/write` | Required if using a subnet associated with a route table in another resource group such as a custom VNET with a custom route table. Required to verify if a subnet already exists for the subnet in the other resource group. |
> | `Microsoft.Network/virtualNetworks/subnets/read` | Required if using an internal load balancer in another resource group. Required to verify if a subnet already exists for the internal load balancer in the resource group. |
> | `Microsoft.Network/privatednszones/*` | Required if using a private DNS zone in another resource group such as a custom privateDNSZone. |

## AKS node mapped identity

The kubelet managed identity assigned to AKS nodes is used to pull images from Azure Container Registry. The required data actions depend on the registry's [role assignment permissions mode](/azure/container-registry/container-registry-rbac-built-in-roles-overview).

### Registries configured with "RBAC Registry Permissions"

> [!div class="mx-tableFixed"]
> | Permission | Reason |
> |---|---|
> | `Microsoft.ContainerRegistry/registries/pull/read` | Required to pull container images from Azure Container Registry. Granted by the [`AcrPull`](/azure/role-based-access-control/built-in-roles/containers#acrpull) built-in role. |

### Registries configured with "RBAC Registry + ABAC Repository Permissions"

ABAC-enabled mode is becoming the default for new Azure Container Registries. In this mode, the legacy `AcrPull` role isn't honored and you must grant the equivalent ABAC-enabled role permissions to the kubelet identity. For more information, see [Azure ABAC repository permissions in Azure Container Registry](/azure/container-registry/container-registry-rbac-abac-repository-permissions).

> [!div class="mx-tableFixed"]
> | Permission | Reason |
> |---|---|
> | `Microsoft.ContainerRegistry/registries/repositories/content/read` <br/> `Microsoft.ContainerRegistry/registries/repositories/metadata/read` | Required to pull container images and read image tags and metadata from repositories. Granted by the [`Container Registry Repository Reader`](/azure/container-registry/container-registry-rbac-built-in-roles-directory-reference#container-registry-repository-reader) built-in role, which can be optionally scoped to specific repositories using ABAC conditions. |
> | `Microsoft.ContainerRegistry/registries/catalog/repositories/read` | Required only if the kubelet identity needs to list all repositories in the registry. Granted by the [`Container Registry Repository Catalog Lister`](/azure/container-registry/container-registry-rbac-built-in-roles-directory-reference#container-registry-repository-catalog-lister) built-in role. This role doesn't support ABAC conditions. |

## Next steps

* [Access and identity options for AKS](concepts-identity.md)
* [Managed identities in AKS](use-managed-identity.md)
* [Use a service principal with AKS](kubernetes-service-principal.md)
* [Azure built-in roles for Containers](/azure/role-based-access-control/built-in-roles#containers)
