---
title: Configure LocalDNS in Azure Kubernetes Service (AKS)
description: Learn how to improve your Domain Name System (DNS) resolution performance and resiliency in AKS using localDNS.
ms.subservice: aks-networking
author: vaibhavarora
ms.topic: how-to
ms.date: 07/01/2025
ms.author: vaibhavarora

# Customer intent: As a cluster operator or developer, I want to improve my DNS resolution performance and resiliency for my AKS cluster.
---

# Configure LocalDNS in Azure Kubernetes Service (Preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Introduction

LocalDNS is a feature in Azure Kubernetes Service (AKS) designed to enhance the Domain Name System (DNS) resolution performance and resiliency for workloads running in your cluster. By deploying a local DNS proxy on each node, LocalDNS reduces DNS query latency, improves reliability during network disruptions, and provides advanced configuration options for DNS caching and forwarding. This article explains how LocalDNS works, its configuration options, and how to enable, verify, and troubleshoot LocalDNS in your AKS clusters.

To learn about what LocalDNS is, including architecture details, and key capabilities, refer to [DNS Resolution in Azure Kubernetes Service (AKS)](./dns-concepts.md).

## Before you begin

* This article assumes that you have an existing AKS cluster with Kubernetes versions 1.33+. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* This article requires version X.X.X or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
* This article requires the `aks-preview` Azure CLI extension version X.X.XXX or later
* Your AKS cluster can't have node autoprovisioning enabled to use LocalDNS.
* LocalDNS requires your AKS cluster to be running Kubernetes version 1.33 or later.
* LocalDNS is only supported on node pools running Ubuntu 22.04 or newer.

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `LocalDNS` feature flag

1. Register the `LocalDNS` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "LocalDNSPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "LocalDNSPreview"
    ```

3. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Create or Update an AKS Node Pool with LocalDNS

LocalDNS is configured at the node pool level in AKS, meaning you can enable or disable LocalDNS independently for each node pool in your cluster. This tailors DNS resolution behavior based on the specific requirements of different workloads or environments. To enable LocalDNS on a node pool, you need to provide a configuration file: _localdnsconfig.json_ that defines how LocalDNS should operate for that node pool. If you don't specify a custom configuration file, AKS automatically applies a default LocalDNS configuration. For details on default configurations and how to configure CoreDNS plugins and server blocks, refer to [Configuring LocalDNS](#configuring-localdns).

### Create a new node pool with LocalDNS enabled

To enable LocalDNS during node pool creation, use the following command with your custom configuration file:

```azure-cli-interactive
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

### Update an existing node pool to enable LocalDNS

To enable LocalDNS on an existing node pool, use the following command with your custom configuration file:

```azure-cli-interactive
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

> [!IMPORTANT]
> Enabling LocalDNS on a node pool initiates a reimage operation on all nodes within that pool. This process can cause temporary disruption to running workloads and may lead to application downtime if not properly managed. You should plan for potential service interruptions and ensure that your applications are configured for high availability or have appropriate disruption budgets in place before enabling this setting.

## Configuring LocalDNS

LocalDNS uses a JSON-based configuration file _localdnsconfig.json_ to define DNS resolution behavior for each node pool. This file allows you to specify operational modes, server blocks for different DNS domains, and plugin settings such as caching, forwarding, and logging.

### Default LocalDNS Configuration
The default LocalDNS configuration provides a balanced setup that optimizes both internal and external DNS resolution for most AKS workloads. You can use this configuration as a starting point and customize it to better suit your cluster's specific DNS requirements.

```json
{
  "localDNSProfile": {
    "mode": "Preferred",
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
}
```

### Setting the `mode` for LocalDNS

LocalDNS can be enabled in three possible modes that define the extent of enforcement of LocalDNS for the workload:
* `Preferred` (default): In this mode, LocalDNS is enabled if the node pool is running Kubernetes version 1.33 or later. If the version requirement isn't met, LocalDNS won't be activated, but the configuration is still added to the image and validated for correctness.
* `Required`: In this mode, LocalDNS is enforced on the node pool if all prerequisites are satisfied. If the requirements aren't met, the deployment fails.
* `Disabled`: Disables the local DNS feature, meaning DNS queries aren't resolved locally within the AKS cluster.

### Server Blocks and Supported Plugins for LocalDNS 

The default configuration applies to queries from pods using `dnsPolicy:default` (under `vnetDNSOverrides`) and pods using `dnsPolicy:ClusterFirst` (under `kubeDNSOverrides`). Within each, there are two default server blocks defined: `.` and  `cluster.local`. 

* `.` represents all external DNS queries from pods that are trying to resolve public or non cluster domains (for example, *microsoft.com*)
* `cluster.local` represents all internal Kubernetes service discovery queries from pods that are trying to resolve kubernetes service names or internal cluster resources. These queries are routed through CoreDNS for resolution within the cluster.

### Supported Plugins

| Plugin                                                            | Description                                                                             | Default                                                              | Allowed Inputs                     | 
|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------|----------------------------------------------------------------------|------------------------------------|
| [`queryLogging`](https://coredns.io/plugins/log/)                 | Define the logging level for DNS queries.                                               | `Error`                                                              | `Error` `Log`                      | 
| [`protocol`](https://coredns.io/plugins/forward/)                 | Sets the protocol used for DNS queries (UDP/TCP preference).                            | `ForceTCP` for cluster.local, else `PreferUDP`                       | `PreferUDP` `ForceTCP`             | 
| [`forwardDestination`](https://coredns.io/plugins/forward/)       | Specifies the DNS server to forward queries to.                                         | `ClusterCoreDNS` for cluster.local & kubeDNS traffic, else `VnetDNS` | `VnetDNS` `ClusterCoreDNS`         |
| [`forwardPolicy`](https://coredns.io/plugins/forward/)            | Determines the policy to use when selecting the upstream DNS server. Default is `random`| `Sequential`                                                         | `random` `round_robin` `sequential`|
| [`maxConcurrent`](https://coredns.io/plugins/forward/)            | Maximum number of concurrent DNS queries handled by the proxy.                          | `1000`                                                               | Integer                            | 
| [`cacheDurationInSeconds`](https://coredns.io/plugins/cache)      | Maximum TTL (Time To Live) in seconds for which DNS responses are cached                | `3600`                                                               | Integer                            |
| [`serveStaleDurationInSeconds`](https://coredns.io/plugins/cache) | Duration (in seconds) to serve stale DNS responses if upstream is unavailable.          | `3600`                                                               | Integer                            |
| [`serveStale`](https://coredns.io/plugins/cache)                  | Policy for serving stale DNS responses during upstream failures.                        | `Immediate`                                                          | `verify` `immediate`               | 

### Defining a custom server block in LocalDNS

CoreDNS matches queries to a specific server block based on an exact match for the domain being queried and not on partial matches. If you have the need for custom server blocks, you can add them to your LocalDNS configuration by creating a file called _localdnsconfig.json_ with the added configurations.

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

1. Create a debug pod in the node pool where LocalDNS is enabled:
   ```azure-cli-interactive
   kubectl run dnstest --image=busybox:1.28 -- sleep 3600
   ```

1. Once the pod is running, execute the following command to check DNS resolution:
   ```azure-cli-interactive
   kubectl exec -it dnstest -- nslookup kubernetes.default
   ```

1. Check the output. If LocalDNS is working correctly, you should see a response with the server address of 169.254.10.10 or 169.254.10.11:
   ```
   Server:    169.254.10.10
   Address 1: 169.254.10.10

   Name:      kubernetes.default
   Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local
   ```

## Disable LocalDNS

To disable LocalDNS for a node pool, you must update your _localdnsconfig.json_ file by setting the `"mode"` property to `"Disabled"`. This change instructs AKS to turn off the local DNS proxy on all nodes in the specified pool, reverting DNS resolution to the default cluster behavior. After updating the configuration file, apply it to the node pool using the Azure CLI to ensure the change takes effect.

```azure-cli-interactive
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

## Best Practices for LocalDNS Configuration

When implementing LocalDNS in your AKS clusters, consider the following best practices:

1. **Start with a minimal configuration**: Begin with a simple configuration that uses the `Preferred` mode before moving to `Required` mode. This setup allows you to validate that LocalDNS works as expected without breaking your cluster.

1. **Implement proper caching strategies**: Configure cache settings based on your workload characteristics:
   * For frequently changing records, use shorter `cacheDurationInSeconds` values.
   * For stable records, use longer cache durations to reduce DNS queries.
   * Enable `serveStale` with appropriate settings to maintain service during DNS outages.

1. **Monitor DNS performance**: After enabling LocalDNS, monitor your application's DNS performance using:
   * Application performance metrics
   * Node metrics to detect reduced network pressure
   * Log entries when `queryLogging` is set to `Log`

1. **Follow least privilege principle**: When configuring DNS forwarding rules, only allow access to the required DNS servers and domains.

1. **Test before production deployment**: Always test LocalDNS configuration in a nonproduction environment before rolling it out to production clusters.

1. **Use Infrastructure as Code (IaC)**: Store your _localdnsconfig.json_ file in your infrastructure repository and include it in your AKS deployment templates.

## Troubleshooting LocalDNS

### DNS queries to specific domains are failing

If DNS queries to specific domains are failing after enabling LocalDNS:

1. Check if you have domain-specific overrides in your _localdnsconfig.json_ that might be misconfigured.
1. Temporarily try removing domain-specific overrides and using only the default `.` configuration.
1. Check if the issue occurs with both User Datagram Protocol (UDP) and Transmission Control Protocol (TCP) by adjusting the `protocol` setting.

## Next steps

For information on LocalDNS in AKS, see [LocalDNS in Azure Kubernetes Service (conceptual)](./dns-concepts.md).

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