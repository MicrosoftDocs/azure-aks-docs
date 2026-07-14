---
title: Node Disruption Policy in Azure Kubernetes Service (AKS) (Preview)
description: Learn about Node Disruption Policy and how to control when operations that require node reimage are allowed in Azure Kubernetes Service (AKS).
author: yudian
ms.author: yudian
ms.topic: overview
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 03/11/2026
# Customer intent: As a cluster operator, I want to understand Node Disruption Policy so I can control when disruptive operations that require node reimage are allowed and minimize workload disruption.
---

# Node Disruption Policy in Azure Kubernetes Service (AKS) (Preview)

As you manage and maintain your AKS clusters, certain configuration changes require nodes to be reimaged. This reimage operation triggers a rolling update that recreates nodes. During a reimage operation, AKS cordons the node (prevents new pod scheduling), drains existing pods (evicting and rescheduling them on other available nodes while respecting Pod Disruption Budgets), and then reimages the node with the updated configuration. This process is a full node recreation, not a reboot - the underlying VM is reimaged with a new OS image. While properly configured persistent volumes (using Azure Disks, Azure Files, or other external storage) aren't affected, any data stored in the node's local ephemeral storage (such as EmptyDir volumes or local paths) is permanently lost. These operations are necessary to apply important updates, but they can disrupt running workloads and impact application availability. Node Disruption Policy gives you fine-grained control over when these disruptive operations are allowed to proceed, helping you balance the need for updates with operational stability.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What is Node Disruption Policy?

Node Disruption Policy is a cluster-level configuration that governs when operations requiring node reimage and redeployment can be executed. It acts as a control gate, allowing you to:

- Align disruptive operations with your maintenance windows.
- Block configuration changes during critical business periods while still allowing node image upgrades and security patches to proceed.
- Maintain predictable cluster behavior during high-traffic events.

The policy applies to user-initiated configuration changes that require node recreation, such as updating custom certificate authority (CA) trust certificates, modifying security profile settings, or changing node OS configuration. 

> [!NOTE]
> Importantly, the policy doesn't block node image version updates (including `SecurityPatch` and `NodeImage` upgrade channels) or Kubernetes version upgrades. These operations continue to proceed according to their configured schedules even when the policy is set to `Block`. For details, see [Upgrade operations not controlled by Node Disruption Policy](#upgrade-operations-not-controlled-by-node-disruption-policy). Additionally, certain recovery operations aren't controlled by this policy to ensure cluster health and availability. For details, see [Recovery operations not controlled by Node Disruption Policy](#recovery-operations-not-controlled-by-node-disruption-policy).

## How Node Disruption Policy works

You configure Node Disruption Policy at the cluster level through the `nodeDisruptionProfile` property. When you attempt an operation that requires node reimage, AKS checks the current policy setting:

- **Policy evaluation**: AKS evaluates whether the operation is allowed based on the current policy.
- **Maintenance window check** (if applicable): If using `AllowDuringMaintenanceWindow`, AKS verifies whether the current time falls within the configured maintenance window.
- **Operation execution or blocking**: The node-disruptive operation proceeds if allowed or is rejected with an error message if blocked.

## Policy options

Node Disruption Policy supports three policy configurations:

| Policy | Description | Use case |
|--------|-------------|----------|
| `Allow` | Allows operations that require node reimage to proceed at any time. This is the default behavior. | Use when you want to prioritize applying updates quickly and can tolerate workload disruption. |
| `AllowDuringMaintenanceWindow` | Blocks operations that require node reimage unless they occur within the `aksManagedNodeOSUpgradeSchedule` maintenance window. | Use when you want to limit disruptions to specific maintenance windows that align with your operational schedule. |
| `Block` | Blocks all operations that require node reimage. | Use when you need to prevent any node disruptions, such as during critical business periods or high-traffic events. |

> [!NOTE]
> When you use `AllowDuringMaintenanceWindow`, you must configure an `aksManagedNodeOSUpgradeSchedule` maintenance window. For more information on setting up maintenance windows, see [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance]. If you don't configure the maintenance window, the node-disruptive operations are allowed.

## Considerations

Keep the following considerations in mind when using Node Disruption Policy:

- **Scope**: The policy applies to user-initiated operations that require node reimage, not to AKS-initiated system maintenance. For details, see [Recovery operations not controlled by Node Disruption Policy](#recovery-operations-not-controlled-by-node-disruption-policy).
- **Blocked operations**: When a disruptive operation is blocked, the API call fails with an error message. You need to either change the policy or wait for the maintenance window.
- **Emergency maintenance**: Azure reserves the right to perform urgent or critical maintenance operations regardless of the policy setting.
- **Update planning**: Setting the policy to `Block` prevents certain cluster updates. For details, see [Operations covered by node disruption policy](#operations-covered-by-node-disruption-policy). Plan accordingly to ensure you can apply necessary updates when needed. 
- **Maintenance window dependency**: The `AllowDuringMaintenanceWindow` policy requires an `aksManagedNodeOSUpgradeSchedule` maintenance window to be configured. For details, see [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance].

## Operations covered by Node Disruption Policy

### Cluster-level operations

#### [Network policy][concepts-network] enablement and [Azure CNI Overlay][azure-cni-overlay] upgrade

To install the required networking components and configure network rules that secure and manage pod-to-pod communication, you need to reimage the nodes.

The following table outlines **network policy upgrades that trigger reimage**:

| From | To |
|----|---|
| None (no network policy) | Azure Network Policy |
| None (no network policy) | Calico |
| Azure CNI | Azure CNI Overlay |
| Azure Network Policy | None (no network policy) |
| Calico | None (no network policy) |

> [!NOTE]
> Changing between Azure and Calico network policies after one is already enabled doesn't require a reimage.

#### [Node OS upgrade channel][auto-upgrade-node-os] changes
   
Each channel uses a different OS patching infrastructure and configuration that you **can't modify** on running nodes.

The following table outlines **node OS upgrade channel changes that trigger reimage**:

| From | To |
|----|---|
| Unmanaged | None |
| Unspecified | Unmanaged |
| SecurityPatch | Unmanaged |
| NodeImage | Unmanaged |
| None | Unmanaged |
| Unspecified | Unmanaged |
| Unmanaged | SecurityPatch |
| Unmanaged | NodeImage | 

#### [IPv6 dual-stack][configure-dual-stack] enablement
   
To support dual-stack communication, nodes need both IPv4 and IPv6 IP configurations and networking stack updates (such as nftables rules).

The following table outlines **IP configuration and networking stack updates that trigger reimage**:

| From | To |
|----|---|
| IPv4 only | IPv4 + IPv6 (dual-stack) |

#### [Cilium data plane][azure-cni-cilium] changes
   
You need to install or remove eBPF programs that handle packet processing at the kernel level.

The following table outlines **Cilium data plane changes that trigger reimage**:

| From | To |
|----|---|
| None | Cilium |
| Cilium | None |

#### [HTTP proxy][http-proxy] configuration updates
   
All node components (containerd, kubelet, system services) need the updated proxy configuration applied system-wide. When you update HTTP proxy configuration, AKS automatically reimages all node pools in the cluster.
   
Node Disruption Policy **triggers reimage** when you modify any of the following HTTP proxy configuration properties or perform any of the following operations:

- `httpProxy`: Proxy URL for HTTP connections
- `httpsProxy`: Proxy URL for HTTPS connections  
- `noProxy`: List of destinations to exclude from proxying
- `trustedCa`: Base64 encoded alternative CA certificate
- Enable HTTP proxy on a cluster (with `--enable-http-proxy`)
- Disable HTTP proxy on a cluster (with `--disable-http-proxy`)
- Reenable HTTP proxy on a cluster that previously had it disabled

#### [Custom CA certificates][custom-ca] updates

You must install new CA certificates in the OS trust store to affect TLS validation for internal services and private registries.

Node Disruption Policy **triggers reimage** when you add, remove, or update custom CA certificates.

#### [Kubelet identity][concepts-identity] changes
   
You must apply new identity credentials to the node configuration. This includes initial identity assignment, identity updates, and service principal profile resets.

Node Disruption Policy **triggers reimage** when you update a managed identity or user-assigned managed identity for the kubelet.

#### [Private DNS zone][access-private-cluster] changes

You must update DNS resolver settings to resolve the private API server endpoint using the new DNS zone.

Node Disruption Policy **triggers reimage** when you modify a private DNS zone configuration in a private cluster.

#### [API Server VNet Integration][api-server-vnet-integration] enablement

You must reconfigure the nodes to communicate with the API server through the internal load balancer IP that's projected into the delegated subnet.

Node Disruption Policy **triggers reimage** when you enable API Server VNet Integration on an existing cluster that didn't previously use it. This change corresponds to changing the `apiServerAccessProfile.enableVnetIntegration` property (internally the `privateConnectProfile.enabled` field) from `false` (or unset) to `true`:

| From | To |
|----|---|
| `apiServerAccessProfile.enableVnetIntegration`: `false` or unset | `apiServerAccessProfile.enableVnetIntegration`: `true` |

#### [eBPF host routing][advanced-container-networking] changes
    
You need to install or remove eBPF programs that provide high-performance packet forwarding (BpfVeth acceleration mode).

The following table outlines **eBPF host routing changes that trigger reimage**:

| From | To |
|----|---|
| Standard routing | eBPF host routing enabled |
| eBPF host routing enabled | Standard routing |

### Node pool-level operations

These operations affect only the specific node pools where you make changes. They trigger a rolling reimage within those node pools:

#### [Local DNS][localdns-custom] profile updates
    
You need to apply changes to the DNS caching daemon and DNS forwarding rules at the node level.

Node Disruption Policy **triggers reimage** when you modify a LocalDNS profile configuration.

#### [Trusted Launch][use-trusted-launch] security changes
    
You can't change VM firmware configuration and boot process settings on running VMs. These changes require you to recreate the VMs.

The following table outlines **Trusted Launch security changes that trigger reimage**:

| Configuration | From | To |
|--------------|------|-----|
| vTPM (virtual Trusted Platform Module) | Disabled | Enabled |
| vTPM (virtual Trusted Platform Module) | Enabled | Disabled |
| Secure Boot | Disabled | Enabled |
| Secure Boot | Enabled | Disabled |

#### [Artifact streaming][artifact-streaming] changes
    
You need to install or remove artifact streaming components to enable faster container image pulling by streaming image layers on-demand.

The following table outlines **artifact streaming changes that trigger reimage**:

| From | To |
|----|---|
| Disabled | Enabled |
| Enabled | Disabled |

#### [Windows GMSA][use-gmsa] profile updates (Windows node pools only)

You need to apply new GMSA settings, DNS server configuration, and domain join credentials for Active Directory integration on the Windows nodes.

Node Disruption Policy **triggers reimage** of the Windows node pools when a GMSA change requires applying new node configuration:

| From | To | Triggers reimage |
|----|---|---|
| GMSA disabled | GMSA enabled | Yes |
| GMSA enabled (DNS server / root domain set or changed) | GMSA enabled with updated DNS server or root domain | Yes |
| GMSA enabled (DNS server set) | GMSA disabled | Yes |
| GMSA enabled (no DNS server set) | GMSA disabled | No (no node configuration to apply) |

#### [Capacity Reservation Group][capacity-reservation-groups] attachment

You need to recreate the underlying VMs so they're allocated from the reserved capacity in the Capacity Reservation Group (CRG). Existing nodes weren't provisioned against the CRG, so AKS must reimage the node pool to associate them with the reservation.

Node Disruption Policy **triggers reimage** when you attach a Capacity Reservation Group to an existing node pool that doesn't already have one. 

| From | To | Triggers reimage |
|----|---|---|
| No Capacity Reservation Group attached | Capacity Reservation Group attached | Yes |

### Operations not yet covered by Node Disruption Policy

The following configuration changes require node reimage but **aren't yet covered by Node Disruption Policy**. A future Kubernetes minor version update will cover these changes as this change introduces new behavior.  
After making these configuration changes, you must manually run [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] with `--node-image-only` to apply the changes to your nodes.

- **[SSH configuration][manage-ssh-access] changes**: Changing SSH access methods (Disabled SSH, Entra ID based SSH, or Local User SSH) or updating SSH public keys on node pools.
- **[IMDS restriction][imds-restriction] changes**: Enabling or disabling Instance Metadata Service (IMDS) restriction to block pod access to the IMDS endpoint.
- **Bootstrap profile changes**: Changing the bootstrap profile, such as switching the `artifactSource` between `Direct` and `Cache`, or changing the `containerRegistryId` (the Azure Container Registry used for [network isolated clusters][network-isolated]).
- **[Outbound type][egress-outboundtype] changes**: Modifying the cluster's outbound connectivity type (loadBalancer, userDefinedRouting, managedNATGateway, or userAssignedNATGateway).

### Upgrade operations not controlled by Node Disruption Policy

Node Disruption Policy **doesn't control** the following upgrade operations. These upgrade operations proceed regardless of your policy setting. Upgrades are either customer-initiated or initiated by AKS within planned maintenance windows. To allow these operations to proceed as scheduled, keep them intentionally out of Node Disruption Policy scope. Addtionally, if operations covered by Node Disruption Policy are included in the same configuration changes with upgrades, they will not be controlled by Node Disruption Policy. 

- **[Node image version][auto-upgrade-node-os] updates**: Upgrading to a new node OS image version (manually or through automatic upgrade channels). This operation is the most common reimage operation and includes security patches, OS updates, and AKS node image releases.  
- **[Kubernetes version][auto-upgrade-cluster] upgrades**: Upgrading the Kubernetes version on a node pool, which applies new Kubernetes binaries, updated kubelet configuration, and OS-level changes.

### Recovery operations not controlled by Node Disruption Policy

Node Disruption Policy **doesn't control** the following automated recovery operations. These operations can occur regardless of your policy setting to ensure cluster health and recovery.

- **Node pool configuration rollback**: When a node pool update operation fails due to invalid configuration or infrastructure issues, AKS automatically rolls back to the last known good state and reimages nodes to revert configuration.
- **Admin cluster restore operations**:  When Azure support engineers perform administrative cluster restoration during incident resolution, nodes are reimaged to ensure consistency between control plane state and node configuration.
- **Node identity credential updates**: AKS periodically updates node identity credentials for security and compliance. These system-initiated updates trigger node reimages to apply the new credentials across all node pools.

## Integration with planned maintenance

Node Disruption Policy works seamlessly with [AKS planned maintenance][planned-maintenance] windows. When you set the policy to `AllowDuringMaintenanceWindow`, disruptive operations align with your `aksManagedNodeOSUpgradeSchedule` maintenance window, ensuring that:

- Changes occur only during approved time windows.
- Operations coordinate with other scheduled maintenance.
- Teams are aware of when disruptions might occur.

This integration provides a comprehensive approach to managing cluster changes and minimizing impact on running workloads.

> [!NOTE]
> When you use `AllowDuringMaintenanceWindow`, you must configure an `aksManagedNodeOSUpgradeSchedule` maintenance window. Using the `default` maintenance window or `aksManagedAutoUpgradeSchedule` (cluster auto-upgrade) doesn't satisfy this requirement. If you set `AllowDuringMaintenanceWindow` without an `aksManagedNodeOSUpgradeSchedule` window configured, all disruptive operations are allowed (the policy has no window to gate against). For more information on setting up maintenance windows, see [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance].

## Best practices

Consider these recommendations when implementing Node Disruption Policy:

- **Use `AllowDuringMaintenanceWindow` for production**: Combine with planned maintenance windows to control when disruptions occur in production environments.
- **Set `Block` during critical periods**: Temporarily block disruptive operations during high-traffic events, product launches, or incident response. Don't use `Block` indefinitely. While `Block` is appropriate for short-term freezes (planned events, incident response).
- **Allow flexibility in non-production**: Use `Allow` in development and testing environments where rapid iteration is more important than stability.
- **Communicate policy changes**: Ensure your team understands the current policy and knows when operations might be blocked.
- **Plan maintenance windows appropriately**: Size your maintenance windows to accommodate the operations you need to perform.
- **Test policy behavior**: Validate policy settings in non-production environments before applying them to production clusters.
- **Monitor blocked operations**: Track when operations are blocked to optimize your maintenance schedule.

## Related content

- Learn how to [configure Node Disruption Policy](use-node-disruption-policy.md).
- Understand [planned maintenance in AKS][planned-maintenance].

<!-- LINKS INTERNAL -->
[planned-maintenance]: ./planned-maintenance.md
[aks-upgrade]: ./auto-upgrade-cluster.md
[concepts-network]: ./concepts-network.md
[azure-cni-overlay]: ./azure-cni-overlay.md
[auto-upgrade-node-os]: ./auto-upgrade-node-os-image.md
[configure-dual-stack]: ./configure-dual-stack.md
[azure-cni-cilium]: ./azure-cni-powered-by-cilium.md
[http-proxy]: ./http-proxy.md
[custom-ca]: ./custom-certificate-authority.md
[concepts-identity]: ./concepts-identity.md
[access-private-cluster]: ./access-private-cluster.md
[api-server-vnet-integration]: ./api-server-vnet-integration.md
[advanced-container-networking]: ./advanced-container-networking-services-overview.md
[localdns-custom]: ./localdns-custom.md
[certificate-rotation]: ./certificate-rotation.md
[auto-upgrade-cluster]: ./auto-upgrade-cluster.md
[use-trusted-launch]: ./use-trusted-launch.md
[artifact-streaming]: ./artifact-streaming.md
[use-gmsa]: ./use-group-managed-service-accounts.md
[capacity-reservation-groups]: ./use-capacity-reservation-groups.md
[manage-ssh-access]: ./manage-ssh-node-access.md
[imds-restriction]: ./imds-restriction.md
[network-isolated]: ./concepts-network-isolated.md
[egress-outboundtype]: ./egress-outboundtype.md
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az-aks-nodepool-upgrade
[az-aks-update]: /cli/azure/aks#az-aks-update
