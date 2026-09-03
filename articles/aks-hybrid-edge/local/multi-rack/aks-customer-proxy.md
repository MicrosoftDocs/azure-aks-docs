---
title: Configure a customer HTTPS proxy for AKS on Azure Local for multi-rack deployments
description: Learn how to bring your own HTTPS proxy to provide internet connectivity for AKS on Azure Local multi-rack clusters.
ms.topic: how-to
ms.date: 09/01/2026
ms.author: jpalombo
ms.custom: multi-rack
author: jpalombo
---

# Configure a customer HTTPS proxy for AKS on Azure Local for multi-rack deployments

This article describes how to configure a bring-your-own (BYO) HTTPS proxy for an AKS on Azure Local for multi-rack deployments cluster. By providing your own proxy, you ensure that all traffic from your cluster's workload nodes goes through your organization's proxy server and remains compliant with your organization's policies.

## Why use a customer proxy?

In a multi-rack deployment, the workload cluster nodes run on a logical network that might not have a direct path to the internet. Without internet connectivity, the cluster can't reach the Azure endpoints required for Azure Arc onboarding, container image pulls, and other management-plane operations.

You have two options to provide this connectivity:

| Option | Description |
| --- | --- |
| **Direct internet on the logical network** | Configure the logical network so that nodes have a routable path to the internet. No proxy configuration is needed. |
| **Bring your own HTTPS proxy** (this article) | Deploy and manage your own proxy server that has internet access, and tell the cluster to route outbound traffic through it. |

## Prerequisites

Before you configure a customer proxy, make sure you have:

- A working HTTPS proxy server reachable from the logical network that the cluster nodes use. The proxy must support the HTTP `CONNECT` method for TLS tunneling.
- The proxy server's IPv4 address and port.
- Network firewall or proxy ACL rules that allow traffic to the [required endpoints](#required-endpoint-allow-list).

## Set the proxy on the connected cluster

Configure the customer proxy by setting the `https-proxy` tag on the `Microsoft.Kubernetes/ConnectedClusters` resource. You can do this at cluster creation time via the ARM template or the Azure CLI, or update it after the cluster is already running.

### Set the proxy at cluster creation

Include the `https-proxy` tag in your ARM template or Bicep deployment:

```json
{
  "type": "Microsoft.Kubernetes/ConnectedClusters",
  "apiVersion": "2025-12-01-preview",
  "name": "[parameters('clusterName')]",
  "location": "[parameters('location')]",
  "kind": "ProvisionedCluster",
  "tags": {
    "https-proxy": "10.10.10.10:3128"
  },
  "identity": {
    "type": "SystemAssigned"
  },
  "properties": {
    "agentPublicKeyCertificate": ""
  }
}
```

Or use the Azure CLI:

```azurecli
az aksarc create \
  --name <cluster-name> \
  --resource-group <resource-group> \
  --custom-location <custom-location-id> \
  --tags https-proxy="10.11.12.13:3128"
  # ... plus your usual networking and agent pool flags
```

### Change the proxy after creation

You can update the proxy address on an existing cluster by updating the tag on the connected cluster resource:

```azurecli
az connectedk8s update \
  --name <cluster-name> \
  --resource-group <resource-group> \
  --tags https-proxy="10.10.10.10:3128"
```

The operator detects the annotation change and reconciles. Existing connections drain gracefully; new connections use the updated proxy.

## Supported proxy URL format

The `https-proxy` tag value must be an IPv4 address and port in the format `<IP>:<port>`. 

**Example:** `10.10.10.10:3128`

> [!IMPORTANT]
> IPv6 addresses aren't supported. The proxy address must be an IPv4 address.

## Required endpoint allow list

Your proxy must allow outbound HTTPS traffic to the following endpoints. These domains are required for Azure Arc connectivity, container image pulls, monitoring, and platform operations:

| Endpoint | Purpose |
| --- | --- |
| `*.arc.azure.net` | Azure Arc connectivity |
| `*.obo.arc.azure.com:8084` | Azure Arc on-behalf-of token service (required if [Azure RBAC](concepts-security-access-identity.md) is enabled; see note below) |
| `*.blob.core.windows.net` | Azure Blob storage (extensions, logs) |
| `*.control.monitor.azure.com` | Azure Monitor data ingestion |
| `*.dp.kubernetesconfiguration.azure.com` | Kubernetes configuration data plane |
| `*.guestconfiguration.azure.com` | Azure Guest Configuration |
| `*.guestnotificationservice.azure.com` | Guest notification service |
| `*.his.arc.azure.com` | Azure Arc hybrid identity service |
| `*.login.microsoft.com` | Microsoft authentication |
| `*.management.azure.com` | Azure Resource Manager |
| `*.mcr.microsoft.com` | Microsoft Container Registry |
| `*.opinsights.azure.com` | Azure Monitor / Log Analytics |
| `*.packages.microsoft.com` | Microsoft package repositories |
| `*.servicebus.windows.net` | Azure Service Bus (notifications) |
| `aka.ms` | Microsoft URL shortener (redirects) |
| `azure.microsoft.com` | Azure portal resources |
| `dc.services.visualstudio.com` | Application Insights telemetry |
| `*.data.azurecr.io` | Azure Container Registry data endpoint |
| `ecpacr.azurecr.io` | Edge compute platform container registry |
| `graph.microsoft.com` | Microsoft Graph API |
| `k8sconnectcsp.azureedge.net` | Kubernetes connected cluster service |
| `k8sconnecthelm.azureedge.net` | Kubernetes connected cluster Helm charts |
| `login.microsoftonline.com` | Microsoft Entra ID authentication |
| `login.windows.net` | Windows authentication |
| `nccacheacr.azurecr.io` | Network Cloud cache container registry |
| `pas.windows.net` | Azure AD Passport service |
| `sts.windows.net` | Security Token Service |

You can copy the full endpoint list below for use in your proxy or firewall configuration:

```text
*.arc.azure.net
*.obo.arc.azure.com
*.blob.core.windows.net
*.control.monitor.azure.com
*.dp.kubernetesconfiguration.azure.com
*.guestconfiguration.azure.com
*.guestnotificationservice.azure.com
*.his.arc.azure.com
*.login.microsoft.com
*.management.azure.com
*.mcr.microsoft.com
*.opinsights.azure.com
*.packages.microsoft.com
*.servicebus.windows.net
aka.ms
azure.microsoft.com
dc.services.visualstudio.com
*.data.azurecr.io
ecpacr.azurecr.io
graph.microsoft.com
k8sconnectcsp.azureedge.net
k8sconnecthelm.azureedge.net
login.microsoftonline.com
login.windows.net
nccacheacr.azurecr.io
pas.windows.net
sts.windows.net
```

### Required ports

Your proxy must allow `CONNECT` on the following ports:

| Port | Required | Usage |
| --- | --- | --- |
| 443 | Yes | HTTPS traffic to all endpoints above |
| 80 | Yes | HTTP redirects (for example, `aka.ms`) |
| 8084 | Yes, if Azure RBAC is enabled | Azure Arc on-behalf-of token service (`*.obo.arc.azure.com`) |

> [!TIP]
> If your proxy allows outbound `CONNECT` to any destination on ports 80, 443, and 8084, you don't need domain-based filtering. The per-endpoint list above is only required when your proxy restricts traffic by domain.

> [!WARNING]
> If you block any of these endpoints, cluster operations might fail. Common symptoms include Arc agent registration failures, stuck `HybridAKSFeature` resources, or container image pull errors on nodes.

## Troubleshoot common issues

| Symptom | Likely cause |
| --- | --- |
| Cluster creation fails with "annotation hybridakscluster.microsoft.com/https-proxy must be non-empty on HybridAKSCluster resources when it is used" | The `https-proxy` tag is present but set to an empty or whitespace-only value. Either set a valid proxy value, or remove the tag entirely if you don't want to use a proxy. |
| Cluster creation fails with "using a scheme other than http:// or https:// which is not allowed" | The proxy value includes a URL scheme other than `http://` or `https://` (for example, `socks5://`). Provide the value with no scheme (for example, `10.10.10.10:3128`) or with an `http://` or `https://` scheme. |
| Cluster creation fails with "must not contain an IPv6 address" | An IPv6 address was provided. Use an IPv4 address or hostname instead. |
| Arc agents fail to register or extensions fail to install | The proxy is blocking one or more required endpoints. Check your proxy logs and compare against the [required endpoint allow list](#required-endpoint-allow-list). |
| Container images fail to pull on workload nodes | The proxy isn't allowing traffic to `*.mcr.microsoft.com` or `nccacheacr.azurecr.io`. Add these to your proxy allow list. |
| Cluster is stuck in **Creating** or moves to **Failed** shortly after setting the proxy tag | The proxy endpoint is unreachable from the workload node network. Verify that the proxy IP and port are routable from the logical network, and that the proxy service is running and accepting connections. |
| Cluster was working but stopped after proxy address change | The new proxy address may be unreachable or misconfigured. Check the node-local-proxy pod logs: `kubectl logs -n nc-system -l app=node-local-proxy`. |

## Limitations

- **IPv4 only.** IPv6 proxy addresses aren't supported.
- **HTTP CONNECT required.** The proxy must support the HTTP `CONNECT` method for tunneling TLS traffic. Simple HTTP forwarding proxies that don't support `CONNECT` don't work.
