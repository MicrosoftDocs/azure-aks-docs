---
# Required metadata
# For more information, see https://learn.microsoft.com/en-us/help/platform/learn-editor-add-metadata
# For valid values of ms.service, ms.prod, and ms.topic, see https://learn.microsoft.com/en-us/help/platform/metadata-taxonomies

title: Enable private links for cluster extensions
description: Private links for cluster extensions
author:      ponatara # GitHub alias
ms.author:   ponatara # Microsoft alias
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date:     11/18/2026
ms.subservice: aks-developer
---

# Enable private links for cluster extensions

Private endpoints bring the Kubernetes Configuration service into your virtual network, so your cluster can communicate with extension services directly without using a public virtual IP address (VIP).

> [!NOTE]
> This feature is currently in public preview. For more information, see [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

## Quick reference

| Item | Value |
|---|---|
| Private Link Scope resource name | `extension-pls` |
| Private Link Scope resource group | Any resource group |
| Resource type | `Microsoft.KubernetesConfiguration/privateLinkScopes` |
| Target subresource | `kubernetesconfiguration` |
| DNS zone format | `<region>.privatelink.dp.kubernetesconfiguration.azure.com` |

## Phase 1: Prerequisites

### 1.0 Authenticate to Azure

```azurecli
az login
```

This command opens a browser for interactive authentication. For service principal or device code flows, use `az login --service-principal` or `az login --use-device-code`.

### 1.1 Set the active subscription

```azurecli
# List available subscriptions.
az account list --output table

# Set the target subscription.
az account set --subscription <subscription-id>
```

> [!NOTE]
> Provide the subscription ID that contains the AKS cluster and related resources.

| Field | Value |
|---|---|
| Subscription ID | |

### 1.2 Check existing Private Link Scope resources (optional)

Check whether a Private Link Scope resource is already associated with the AKS cluster.

```azurecli
az network private-link-resource list --id <pls-resource-id>
```

The Private Link Scope resource ID uses the following format:

```text
/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.KubernetesConfiguration/privateLinkScopes/extension-pls
```

| Field | Value |
|---|---|
| Private Link Scope resource ID | |

### 1.3 Delete an existing Private Link Scope resource (optional)

If you need to remove an existing Private Link Scope resource before setting up a new one, delete it before continuing.

> [!CAUTION]
> Confirm that you no longer need the existing resource before deleting it.

```azurecli
az resource delete --id <pls-resource-id>
```

| Field | Value |
|---|---|
| Private Link Scope resource ID to delete | |
| Deletion confirmed | ⬜ Yes / ⬜ No |

### 1.4 Create a Private Link Scope resource

Provide the following parameters:

| Parameter | Description | Value |
|---|---|---|
| Private Link Scope name | Name of the resource. The default is `extension-pls`. | |
| Resource group | Any resource group. | |
| Location | Azure region. It must match the AKS cluster region. | |
| Cluster resource ID | ARM resource ID of the AKS cluster. | |
| Public network access | `Enabled` or `Disabled`. | |

```azurecli
az resource create \
  --name <pls-name> \
  --resource-group <resource-group> \
  --resource-type "Microsoft.KubernetesConfiguration/privateLinkScopes" \
  --location <location> \
  --properties '{"clusterResourceId":"<cluster-arm-id>","publicNetworkAccess":"<Enabled|Disabled>"}'
```

Example:

```azurecli
az resource create \
  --name extension-pls \
  --resource-group <resource-group> \
  --resource-type "Microsoft.KubernetesConfiguration/privateLinkScopes" \
  --location <location> \
  --properties '{"clusterResourceId":"/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>","publicNetworkAccess":"Enabled"}'
```

| Field | Value |
|---|---|
| Creation confirmed | ⬜ Yes / ⬜ No |
| New Private Link Scope ARM resource ID | |

### 1.5 Deploy the Flux extension on the AKS cluster

To deploy the Flux extension and configure GitOps on the AKS cluster, follow [Tutorial: Deploy applications by using GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2).

The tutorial includes the prerequisites and commands required to install the `microsoft.flux` cluster extension and create a Flux configuration.

## Phase 2: Create a private endpoint

### Scenario 1: Automatic approval workflow

#### 2.1 Create a private endpoint in the Azure portal

Create a private endpoint by connecting to the Private Link Scope resource in your Azure directory.

1. In the Azure portal, go to **Private endpoints**, and then select **Create**.
1. On the **Basics** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Subscription | Same subscription as the AKS cluster. |
   | Resource group | Any resource group. |
   | Name | For example, `<cluster-name>-pe`. |
   | Region | Must match the AKS cluster region. |

1. On the **Resource** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Connection method | **Connect to an Azure resource in my directory** |
   | Subscription | AKS cluster subscription |
   | Resource type | `Microsoft.KubernetesConfiguration/privateLinkScopes` |
   | Resource | Select `extension-pls` from its resource group |
   | Target subresource | `kubernetesconfiguration` |

1. On the **Virtual Network** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Virtual network | AKS virtual network or another connected virtual network |
   | Subnet | An appropriate subnet for the private endpoint |

1. On the **DNS** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Integrate with private DNS zone | **Yes** |
   | Private DNS zone | Create a new zone or select an existing zone |

1. Select **Review + create**, and then select **Create**.

| Validation | Result |
|---|---|
| Private endpoint name | |
| Private endpoint resource ID | |
| Connection status | Expected: **Approved** |
| Private IP address | |

#### 2.2 Validate the Private Link Scope configuration

Verify the Private Link Scope resource configuration and confirm that the automatically approved private endpoint connection appears on the resource.

```azurecli
az resource show --ids "<pls-resource-id>"
```

Example:

```azurecli
az resource show --ids "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.KubernetesConfiguration/privateLinkScopes/extension-pls"
```

Verify the following fields:

| Field | Expected value |
|---|---|
| `properties.clusterResourceId` | Matches the AKS cluster ARM resource ID |
| `properties.publicNetworkAccess` | `Enabled` or `Disabled`, as configured |
| `properties.provisioningState` | `Succeeded` |
| `properties.privateEndpointConnections` | Contains the private endpoint |
| `properties.privateEndpointConnections[].privateLinkServiceConnectionState.status` | `Approved` |

| Validation | Result |
|---|---|
| Cluster resource ID matches | ⬜ Yes / ⬜ No |
| Provisioning state | |
| Private endpoint connection status | Expected: **Approved** |

### Scenario 2: Manual approval workflow

#### 2.3 Create a private endpoint that requires manual approval

Create a private endpoint by specifying the Private Link Scope resource ID or alias. This workflow requires the private endpoint connection to be approved separately.

1. In the Azure portal, go to **Private endpoints**, and then select **Create**.
1. On the **Basics** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Subscription | Same subscription as the AKS cluster. |
   | Resource group | Any resource group. |
   | Name | For example, `<cluster-name>-pe-manual`. |
   | Region | Must match the AKS cluster region. |

1. On the **Resource** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Connection method | **Connect to an Azure resource by resource ID or alias** |
   | Resource ID or alias | Private Link Scope ARM resource ID |
   | Target subresource | `kubernetesconfiguration` |

1. On the **Virtual Network** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Virtual network | AKS virtual network or another connected virtual network |
   | Subnet | An appropriate subnet for the private endpoint |

1. On the **DNS** tab, enter the following values:

   | Field | Value |
   |---|---|
   | Integrate with private DNS zone | **Yes** |
   | Private DNS zone | Create a new zone or select an existing zone |

1. Select **Review + create**, and then select **Create**.

> [!NOTE]
> The private endpoint connection remains in the `Pending` state until it is approved.

| Validation | Result |
|---|---|
| Private endpoint name | |
| Private endpoint resource ID | |
| Connection status | Expected: **Pending** |

#### 2.4 List pending private endpoint connections

List the private endpoint connections on the Private Link Scope resource to obtain the connection ID required for approval.

```azurecli
az network private-endpoint-connection list --id <pls-resource-id>
```

Example:

```azurecli
az network private-endpoint-connection list \
  --id /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.KubernetesConfiguration/privateLinkScopes/extension-pls
```

Look for a connection where `privateLinkServiceConnectionState.status` is `Pending`:

```json
[
  {
    "id": "/subscriptions/.../privateEndpointConnections/<connection-name>",
    "name": "<connection-name>",
    "properties": {
      "privateLinkServiceConnectionState": {
        "status": "Pending",
        "description": "...",
        "actionsRequired": "None"
      }
    }
  }
]
```

> [!NOTE]
> Copy the full connection `id` for use in the approval step.

| Validation | Result |
|---|---|
| Connection name | |
| Connection ID | |
| Connection status | Expected: **Pending** |

#### 2.5 Approve the private endpoint connection

Approve the pending private endpoint connection to establish the private link.

```azurecli
az network private-endpoint-connection approve \
  --id "<private-endpoint-connection-id>" \
  --description "Approved from Azure CLI"
```

The connection ID uses the following format:

```text
<pls-resource-id>/privateEndpointConnections/<connection-name>
```

The command should change `privateLinkServiceConnectionState.status` from `Pending` to `Approved`.

| Validation | Result |
|---|---|
| Connection ID | |
| Approval description | |
| Connection status after approval | Expected: **Approved** |

#### 2.6 Manage private endpoint connections (optional)

Reject a pending or approved connection:

```azurecli
az network private-endpoint-connection reject \
  --id "<private-endpoint-connection-id>" \
  --description "Rejected"
```

Delete a private endpoint connection:

```azurecli
az network private-endpoint-connection delete \
  --id "<private-endpoint-connection-id>"
```

Use `reject` to deny access while retaining the connection record. Use `delete` to remove the connection record.

## Phase 3: Validate Flux pods and runtime traffic

### 3.1 Get AKS cluster credentials

Connect to the AKS cluster to validate Flux pods and extension agent traffic.

| Parameter | Description | Value |
|---|---|---|
| Resource group | Resource group that contains the AKS cluster | |
| Cluster name | Name of the AKS cluster | |

```azurecli
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Example:

```azurecli
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Expected output:

```text
Merged "<cluster-name>" as current context in C:\Users\<user>\.kube\config
```

### 3.2 Validate Flux agent communication with the data plane

Check the Flux agent logs to confirm successful communication with the Kubernetes Configuration data plane service.

Get the Flux agent pod name:

```bash
kubectl get pods -n flux-system
```

Review the Flux agent logs:

```bash
kubectl logs -n flux-system <fluxconfig-agent-pod-name> --since 5m
```

Example:

```bash
kubectl logs -n flux-system fluxconfig-agent-59cbf99d6f-v5zdg --since 5m
```

Look for log entries similar to the following:

```json
{"Message":"URL:> https://<region>.dp.kubernetesconfiguration.azure.com/subscriptions/<subscription-id>/resourceGroups/<resource-group>/provider/Microsoft.ContainerService-managedclusters/clusters/<cluster-name>/configurations/getPendingConfigs?api-version=..."}
{"Message":"Successful DP call. Endpoint: getPendingConfigs, ResponseCode: 200"}
```

| Validation | Result |
|---|---|
| Fluxconfig agent pod name | |
| Data plane URL present in logs | ⬜ Yes / ⬜ No |
| Successful data plane call with HTTP 200 | ⬜ Yes / ⬜ No |
| Errors present in logs | ⬜ Yes / ⬜ No |

### 3.3 Verify DNS resolution to a private IP address

Confirm that the Kubernetes Configuration data plane endpoint resolves to a private IP address.

| Parameter | Description | Value |
|---|---|---|
| Fluxconfig agent pod name | Pod name from step 3.2 | |
| Region | AKS cluster region | |

```bash
kubectl exec -it -n flux-system <fluxconfig-agent-pod-name> -c fluxconfig-agent -- \
  timeout 5 openssl s_client -connect <region>.dp.kubernetesconfiguration.azure.com:443 -brief
```

Example:

```bash
kubectl exec -it -n flux-system fluxconfig-agent-59cbf99d6f-v5zdg -c fluxconfig-agent -- \
  timeout 5 openssl s_client -connect centraluseuap.dp.kubernetesconfiguration.azure.com:443 -brief
```

Expected output includes a successful TLS connection:

```text
CONNECTION ESTABLISHED
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: ...
```

| Result | Meaning | Status |
|---|---|---|
| Resolves to `10.x.x.x` | Private endpoint is working | |
| Resolves to a public IP address | Traffic isn't using the private endpoint | |

| Validation | Result |
|---|---|
| Resolved IP address | |
| Private IP address (`10.x.x.x`) | ⬜ Yes / ⬜ No |

### 3.4 Disable public network access on the Private Link Scope resource

After completing steps 3.1 through 3.3, disable public network access on the Private Link Scope resource to enforce private-only connectivity.

```azurecli
az resource update \
  --ids "<pls-resource-id>" \
  --set properties.publicNetworkAccess="Disabled"
```

Example:

```azurecli
az resource update \
  --ids "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.KubernetesConfiguration/privateLinkScopes/extension-pls" \
  --set properties.publicNetworkAccess="Disabled"
```

Expected results:

- `properties.publicNetworkAccess` is set to `Disabled`.
- Extension agent traffic routes through the private endpoint.
- Public network requests are blocked.

| Validation | Result |
|---|---|
| Private Link Scope resource ID | |
| Public network access | Expected: **Disabled** |

## Troubleshooting

### Private Link Scope resource isn't created

- Check whether hidden resource types are enabled in the Azure portal.
- Confirm that the `Microsoft.KubernetesConfiguration` resource provider is registered.
- Review the Azure CLI output for permission or resource property errors.

### Private endpoint connection remains pending

- Check if manual approval is required.
- Verify your permissions on the Private Link Scope resource.
- Ensure you're using the correct connection ID in the approval command.

### DNS doesn't resolve to a private IP address

- Verify that the private DNS zone is linked to the virtual network.
- Confirm that the required DNS `A` record exists.
- Review custom DNS settings for the virtual network.

### Agent logs show errors

- Check the agent pod status.
- Verify that network policies allow required egress traffic.
- Confirm that the private endpoint connection is approved.
- Confirm that the data plane endpoint resolves through the private DNS zone.

## References

- [Tutorial: Deploy applications by using GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Private endpoints overview](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)
- [Create or update a private AKS cluster](https://learn.microsoft.com/azure/aks/private-clusters)
