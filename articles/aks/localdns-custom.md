---
title: Configure LocalDNS in Azure Kubernetes Service (AKS)
description: Learn how to improve your Domain Name System (DNS) resolution performance and resiliency in AKS using localDNS.
ms.subservice: aks-networking
author: vaibhavarora
ms.topic: how-to
ms.date: 07/31/2025
ms.author: vaibhavarora

# Customer intent: As a cluster operator or developer, I want to improve my DNS resolution performance and resiliency for my AKS cluster.
---

# Configure LocalDNS in Azure Kubernetes Service

## Introduction

LocalDNS is a feature in Azure Kubernetes Service (AKS) designed to enhance the Domain Name System (DNS) resolution performance and resiliency for workloads running in your cluster. By deploying a DNS proxy on each node, LocalDNS reduces DNS query latency, improves reliability during network disruptions, and provides advanced configuration options for DNS caching and forwarding. This article explains how LocalDNS works, its configuration options, and how to enable, verify, and troubleshoot LocalDNS in your AKS clusters.

To learn about what LocalDNS is, including architecture details, and key capabilities, refer to [DNS Resolution in Azure Kubernetes Service (AKS)](./dns-concepts.md).

## Before you begin

* This article assumes that you have an existing AKS cluster with Kubernetes versions 1.31+. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* This article requires version 2.80.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
* Your AKS cluster can't have node autoprovisioning enabled to use LocalDNS.
* LocalDNS requires your AKS cluster to be running Kubernetes version 1.31 or later.
* LocalDNS is only supported on node pools running Azure Linux or Ubuntu 22.04 or newer.
* LocalDNS only supports Virtual Machine Scale Set node pools.
* The Virtual Machine (VM) SKU used for your node pool must have at least 4 vCPUs (cores) to support LocalDNS.

* LocalDNS does not work with customers using Azure CNI powered by Cilium (ACNS) with the FQDN filtering feature. For details, see [Apply FQDN filtering policies in AKS](https://learn.microsoft.com/en-us/azure/aks/how-to-apply-fqdn-filtering-policies?tabs=non-cilium).

## Create or update an AKS node pool with LocalDNS

LocalDNS is configured at the node pool level in AKS, meaning you can enable or disable LocalDNS independently for each node pool in your cluster. This tailors DNS resolution behavior based on the specific requirements of different workloads or environments. To enable LocalDNS on a node pool, you need to provide a configuration file: _localdnsconfig.json_ that defines how LocalDNS should operate for that node pool. If you don't specify a custom configuration file, AKS automatically applies a default LocalDNS configuration. For details on default configurations and how to configure CoreDNS plugins and server blocks, refer to [Configuring LocalDNS](#configure-localdns).

### Enable LocalDNS on a new node pool

To enable LocalDNS during node pool creation, use the following command with your custom configuration file:

```azure-cli-interactive
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

### Enable LocalDNS on an existing node pool

To enable LocalDNS on an existing node pool, use the following command with your custom configuration file:

```azure-cli-interactive
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

> [!IMPORTANT]
> Enabling LocalDNS on a node pool initiates a reimage operation on all nodes within that pool. This process can cause temporary disruption to running workloads and may lead to application downtime if not properly managed. You should plan for potential service interruptions and ensure that the applications are configured for high availability or have appropriate disruption budgets in place before enabling this setting.

## Configure LocalDNS

LocalDNS uses a JSON-based configuration file _localdnsconfig.json_ to define DNS resolution behavior for each node pool. This file allows you to specify operational modes, server blocks for different DNS domains, and plugin settings such as caching, forwarding, and logging.

### Default LocalDNS configuration
The default LocalDNS configuration provides a balanced setup that optimizes both internal and external DNS resolution for most AKS workloads. You can use this configuration as a starting point and customize it to better suit your cluster's specific DNS requirements.

> [!NOTE]
> When customizing LocalDNS, use the following configuration format as your template. You can add additional server blocks, however adding unsupported or additional top-level properties will cause validation failures.

```json
{
  "mode": "Required",
  "vnetDNSOverrides": {
    ".": {
      "queryLogging": "Error",
      "protocol": "PreferUDP",
      "forwardDestination": "VnetDNS",
      "forwardPolicy": "Sequential",
      "maxConcurrent": 1000,
      "cacheDurationInSeconds": 3600,
      "serveStaleDurationInSeconds": 3600,
      "serveStale": "Immediate"
    },
    "cluster.local": {
      "queryLogging": "Error",
      "protocol": "ForceTCP",
      "forwardDestination": "ClusterCoreDNS",
      "forwardPolicy": "Sequential",
      "maxConcurrent": 1000,
      "cacheDurationInSeconds": 3600,
      "serveStaleDurationInSeconds": 3600,
      "serveStale": "Immediate"
    }
  },
  "kubeDNSOverrides": {
    ".": {
      "queryLogging": "Error",
      "protocol": "PreferUDP",
      "forwardDestination": "ClusterCoreDNS",
      "forwardPolicy": "Sequential",
      "maxConcurrent": 1000,
      "cacheDurationInSeconds": 3600,
      "serveStaleDurationInSeconds": 3600,
      "serveStale": "Immediate"
    },
    "cluster.local": {
      "queryLogging": "Error",
      "protocol": "ForceTCP",
      "forwardDestination": "ClusterCoreDNS",
      "forwardPolicy": "Sequential",
      "maxConcurrent": 1000,
      "cacheDurationInSeconds": 3600,
      "serveStaleDurationInSeconds": 3600,
      "serveStale": "Immediate"
    }
  }
}
```

### Configure the `mode` for LocalDNS

LocalDNS can be enabled in three possible modes that define the extent of enforcement of LocalDNS for the workload:
* `Required`: In this mode, LocalDNS is enforced on the node pool if all prerequisites are satisfied. If the requirements aren't met, the deployment fails.
* `Disabled`: Disables the local DNS feature, meaning DNS queries aren't resolved locally within the AKS cluster.
* `Preferred`: In this mode, AKS manages LocalDNS enablement based on the Kubernetes version of the node pool. The configuration is always validated and included, but LocalDNS isn't enabled unless the correct Kubernetes version is used.

The following table summarizes LocalDNS behavior for each mode and Kubernetes version:

| Kubernetes Version | Preferred                | Required                              | Disabled                          |
|--------------------|------------------------------------|---------------------------------------|-----------------------------------|
| < 1.31             | Not supported                      | Not supported                         | Not supported                     |
| > 1.31             | Config validated, not installed    | Installed and enforced                | Config validated, not installed   |

### Server blocks and supported plugins for LocalDNS

The default configuration applies to queries from pods using `dnsPolicy:default` (under `vnetDNSOverrides`) and pods using `dnsPolicy:ClusterFirst` (under `kubeDNSOverrides`). Within each, there are two default server blocks defined: `.` and  `cluster.local`. 

* `.` represents all external DNS queries from pods that are trying to resolve public or non cluster domains (for example, *microsoft.com*).
* `cluster.local` represents all internal Kubernetes service discovery queries from pods that are trying to resolve kubernetes service names or internal cluster resources. These queries are routed through CoreDNS for resolution within the cluster.

### Supported plugins

| Plugin                                                            | Description                                                                             | Default                                                              | Allowed Inputs                     | 
|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------|----------------------------------------------------------------------|------------------------------------|
| [`queryLogging`](https://coredns.io/plugins/log/)                 | Define the logging level for DNS queries.                                               | `Error`                                                              | `Error` `Log`                      | 
| [`protocol`](https://coredns.io/plugins/forward/)                 | Sets the protocol used for DNS queries (UDP/TCP preference).                            | `ForceTCP` for cluster.local, else `PreferUDP`                       | `PreferUDP` `ForceTCP`             | 
| [`forwardDestination`](https://coredns.io/plugins/forward/)       | Specifies the DNS server to forward queries to.                                         | `ClusterCoreDNS` for cluster.local and kubeDNS traffic, else `VnetDNS` | `VnetDNS` `ClusterCoreDNS`         |
| [`forwardPolicy`](https://coredns.io/plugins/forward/)            | Determines the policy to use when selecting the upstream DNS server. | `Sequential`                                                         | `Random` `RoundRobin` `Sequential`|
| [`maxConcurrent`](https://coredns.io/plugins/forward/)            | Maximum number of concurrent DNS queries handled by LocalDNS.                          | `1000`                                                               | Integer                            | 
| [`cacheDurationInSeconds`](https://coredns.io/plugins/cache)      | Maximum TTL (Time To Live) in seconds for which DNS responses are cached.                | `3600`                                                               | Integer                            |
| [`serveStaleDurationInSeconds`](https://coredns.io/plugins/cache) | Duration (in seconds) to serve stale DNS responses if upstream is unavailable.          | `3600`                                                               | Integer                            |
| [`serveStale`](https://coredns.io/plugins/cache)                  | Policy for serving stale DNS responses during upstream failures.                        | `Immediate`                                                             | `Verify` `Immediate` `Disabled`               | 

### Configuration validation rules

When creating your LocalDNS configuration, be aware of these validation rules to avoid deployment failures:

- **Root zone (`.`) restrictions**: Under `vnetDNSOverrides`, the `forwardDestination` for the root zone can't be `ClusterCoreDNS`.
- **Cluster.local zone restrictions**: Under both `vnetDNSOverrides` and `kubeDNSOverrides`, the `forwardDestination` for `cluster.local` can't be `VnetDNS`.
- **Protocol and serveStale compatibility**: When `protocol` is set to `ForceTCP`, `serveStale` can't be set to `Verify`. Use `Immediate` instead.

> [!NOTE]
> These validation rules are enforced during configuration deployment. Violating them causes the LocalDNS configuration to fail validation. 

### Create a custom server block in LocalDNS

CoreDNS matches queries to a specific server block based on an exact match for domain being queried and not on partial matches. If you have the need for custom server blocks, you can add them to your LocalDNS configuration by creating a file called _localdnsconfig.json_ with the added configurations.

For example, if you have specific DNS needs when accessing microsoft.com, you could use the following server block:

```json
"microsoft.com": {
  "queryLogging": "Error",
  "protocol": "ForceTCP",
  "forwardDestination": "ClusterCoreDNS",
  "forwardPolicy": "Sequential",
  "maxConcurrent": 1000,
  "cacheDurationInSeconds": 3600,
  "serveStaleDurationInSeconds": 3600,
  "serveStale": "Immediate"
}
```

## Verify if LocalDNS is enabled

Once LocalDNS is enabled, you can verify its operation by running DNS queries from pods in the specified node pool and inspecting the `SERVER` field in the responses to confirm LocalDNS addresses are returned (169.254.10.10 or 169.254.10.11).

Before running the validation steps, ensure the following conditions are met:
1. You have `kubectl` installed and configured to access your AKS cluster.
1. Your user account has sufficient permissions to create and exec into pods.
1. The node pool where you want to validate LocalDNS is in a Ready state.
1. The BusyBox image (`busybox:1.28`) is accessible from your cluster nodes.

Here's an example of how to verify:

Create a debug pod in the node pool where LocalDNS is enabled:
   ```azure-cli-interactive
   kubectl run dnstest --image=busybox:1.28 -- sleep 3600
   ```

Once the pod is running, execute the following command to check DNS resolution:
   ```azure-cli-interactive
   kubectl exec -it dnstest -- nslookup kubernetes.default
   ```

Check the output. If localDNS is working correctly, you should see a response with the server address of 169.254.10.10 or 169.254.10.11:
   ```
   Server:    169.254.10.10
   Address 1: 169.254.10.10

   Name:      kubernetes.default
   Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local
   ```

## Monitor LocalDNS

LocalDNS exposes Prometheus metrics, which you can use for monitoring and alerting. These [metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default#coredns) are exposed on port `9253` of the Node IP and can be scraped from there.

The following example YAML shows a scrape configuration you can use with the [Azure Managed Prometheus add on as a DaemonSet](/azure/azure-monitor/essentials/prometheus-metrics-scrape-configuration):

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: ama-metrics-prometheus-config-node
  namespace: kube-system
data:
  prometheus-config: |-
    global:
      scrape_interval: 1m
    scrape_configs:
    - job_name: localdns-metrics
      scrape_interval: 1m
      scheme: http
      metrics_path: /metrics
      relabel_configs:
      - source_labels: [__metrics_path__]
        regex: (.*)
        target_label: metrics_path
      - source_labels: [__address__]
        replacement: '$NODE_NAME'
        target_label: instance
      static_configs:
      - targets: ['$NODE_IP:9253']
```

## Disable LocalDNS

To disable LocalDNS for a node pool, you must update your _localdnsconfig.json_ file by setting the `"mode"` property to `"Disabled"`. This change instructs AKS to turn off the local DNS proxy on all nodes in the specified pool, reverting DNS resolution to the default cluster behavior. After updating the configuration file, apply it to the node pool using the Azure CLI to ensure the change takes effect.

```azure-cli-interactive
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

## Best practices for LocalDNS configuration

When implementing LocalDNS in your AKS clusters, consider the following best practices:

- **Start with a minimal configuration**: Begin with a simple configuration that uses the `Preferred` mode before moving to `Required` mode. This setup allows you to validate that LocalDNS works as expected without breaking your cluster.

- **Implement proper caching strategies**: Configure cache settings based on your workload characteristics:
  - For frequently changing records, use shorter `cacheDurationInSeconds` values. When doing so, it's important to note that cacheDurationInSeconds acts as a cap on the DNS record TTL but doesn't increase it. The resulting TTL is the smaller of what is returned from upstream or what is set in the cache plugin.
  - For stable records, use longer cache durations to reduce DNS queries.
  - Enable `serveStale` with appropriate settings to maintain service during DNS outages.
  - Caching with LocalDNS operates on a best effort basis and doesn't guarantee stale responses. The cache is divided into 256 shards and with a default maximum of 10,000 entries, allowing each shard to hold about 39 entries. When a shard is full and a new entry needs to be added, one of the existing entries is chosen at random to be evicted. There's no preference for older or expires entries. As a result, a stale record might not always be available, especially under high query volume.

- **Monitor DNS performance**: After enabling LocalDNS, monitor your application's DNS performance using:
  - Application performance metrics.
  - Node metrics to detect reduced network pressure.
  - Log entries when `queryLogging` is set to `Log`.

- **Follow least privilege principle**: When configuring DNS forwarding rules, only allow access to the required DNS servers and domains.

- **Test before production deployment**: Always test LocalDNS configuration in a nonproduction environment before rolling it out to production clusters.

- **Use Infrastructure as Code (IaC)**: Store your _localdnsconfig.json_ file in your infrastructure repository and include it in your AKS deployment templates.

- **Network configuration for TCP forwarding**: When using TCP for DNS forwarding to VnetDNS, ensure that your Network Security Groups (NSGs), firewalls, or Network Virtual Appliances (NVAs) don't block TCP traffic between CoreDNS/LocalDNS and VnetDNS servers.

- **Avoid enabling both NodeLocal DNSCache and LocalDNS**: It isn't recommended to enable both the upstream Kubernetes NodeLocal DNSCache and LocalDNS in your node pool. While AKS doesn't block this configuration, all DNS traffic is routed through LocalDNS, which may lead to unexpected behavior or reduced benefits from NodeLocal DNSCache.

## Troubleshoot LocalDNS

### DNS queries to specific domains are failing

If DNS queries to specific domains are failing after enabling LocalDNS:

1. Check if you have domain-specific overrides in your _localdnsconfig.json_ that might be misconfigured.
1. Temporarily try removing domain-specific overrides and using only the default `.` configuration.
1. Check if the issue occurs with both User Datagram Protocol (UDP) and Transmission Control Protocol (TCP) by adjusting the `protocol` setting.

### Update VNet DNS servers for LocalDNS

After updating custom VNet DNS servers directly in the VNet configuration (using the Azure portal or CLI), DNS changes aren't reflected in your AKS cluster nodes. This is because modifying DNS servers at the VNet level only updates the Network Resource Provider (NRP) and doesn't notify the AKS Resource Provider, so AKS nodes continue using the old DNS settings.

To ensure AKS nodes pick up the new VNet DNS server settings:

1. Update the VNet DNS configuration using the Azure portal or APIs as needed.
2. Reimage the node pool through the AKS Resource Provider to apply and persist the DNS changes:

  ```azurecli-interactive
  az aks nodepool upgrade --resource-group myResourceGroup --cluster-name myAKSCluster --name mynodepool --node-image-only
  ```

This process ensures the AKS Resource Provider is aware of the DNS changes and applies them to all nodes in the node pool.

## Next steps

For information on LocalDNS in AKS, see [LocalDNS in Azure Kubernetes Service (conceptual)](./dns-concepts.md).

For comprehensive troubleshooting guidance on DNS issues when using LocalDNS, see [Troubleshoot LocalDNS issues in AKS](https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/connectivity/dns/troubleshoot-localdns).

For details on how to customize CoreDNS in AKS, refer to the [CoreDNS customization guide](./coredns-custom.md).

For information on the CoreDNS project, see [the CoreDNS upstream project page][coreDNS].

To learn more about core network concepts, see [Network concepts for applications in AKS][concepts-network].

<!-- LINKS - external -->
[coreDNS]: https://coredns.io/

<!-- LINKS - internal -->
[concepts-network]: concepts-network.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
