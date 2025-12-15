---
title: Customize the node configuration for Azure Kubernetes Service (AKS) node pools
description: Learn how to customize the configuration on Azure Kubernetes Service (AKS) cluster nodes and node pools.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 04/24/2023
ms.author: schaffererin
author: schaffererin
ms.subservice: aks-nodes
# Customer intent: "As a cloud engineer, I want to customize node configurations on my Kubernetes cluster, so that I can optimize performance and resource management for my specific workloads."
---

# Customize the node configuration for Azure Kubernetes Service (AKS) node pools

Customizing your node configuration allows you to adjust operating system (OS) settings or kubelet parameters to match the needs of your workloads. When you create an AKS cluster or add a node pool to your cluster, you can customize a subset of commonly used OS and kubelet settings. To configure settings beyond this subset, you can [use a daemon set to customize your needed configurations without losing AKS support for your nodes](support-policies.md#shared-responsibility).

## Create custom node configuration files for AKS node pools

OS and kubelet configuration changes require you to create a new configuration file with the parameters and your desired settings. If a value for a parameter isn't specified, then the value is set to the default.

> [!NOTE]
> The following examples show common configuration settings. You can modify the settings to meet your workload requirements. For a full list of supported custom configuration parameters, see the [Supported custom configuration parameters](#supported-custom-configuration-parameters) section.

### Kubelet configuration

#### [Linux node pools](#tab/linux-node-pools)

Create a `linuxkubeletconfig.json` file with the following contents:

```json
{
 "cpuManagerPolicy": "static",
 "cpuCfsQuota": true,
 "cpuCfsQuotaPeriod": "200ms",
 "imageGcHighThreshold": 90,
 "imageGcLowThreshold": 70,
 "topologyManagerPolicy": "best-effort",
 "allowedUnsafeSysctls": [
  "kernel.msg*",
  "net.*"
],
 "failSwapOn": false
}
```

#### [Windows node pools](#tab/windows-node-pools)

> [!NOTE]
> Windows kubelet custom configuration only supports the parameters `imageGcHighThreshold`, `imageGcLowThreshold`, `containerLogMaxSizeMB`, and `containerLogMaxFiles`.

Create a `windowskubeletconfig.json` file with the following contents:

```json
{
 "imageGcHighThreshold": 90,
 "imageGcLowThreshold": 70,
 "containerLogMaxSizeMB": 20,
 "containerLogMaxFiles": 6
}
```

---

### OS configuration

#### [Linux node pools](#tab/linux-node-pools)

Create a `linuxosconfig.json` file with the following contents:

```json
{
 "transparentHugePageEnabled": "madvise",
 "transparentHugePageDefrag": "defer+madvise",
 "swapFileSizeMB": 1500,
 "sysctls": {
  "netCoreSomaxconn": 163849,
  "netIpv4TcpTwReuse": true,
  "netIpv4IpLocalPortRange": "32000 60000"
 }
}
```

#### [Windows node pools](#tab/windows-node-pools)

Currently unsupported.

---

## Create an AKS cluster using custom configuration files

> [!NOTE]
> Keep the following information in mind when using custom configuration files when creating a new AKS cluster:
>
> - If you specify a configuration when creating a cluster, the configuration applies only to the nodes in the initial node pool. Any settings not configured in the JSON file retain their default values.
> - `CustomLinuxOsConfig` isn't supported for the Windows OS type.

Create a new cluster using custom configuration files using the [`az aks create`][az-aks-create] command and specifying your configuration files for the `--kubelet-config` and `--linux-os-config` parameters. The following example command creates a new cluster with the custom `./linuxkubeletconfig.json` and `./linuxosconfig.json` files:

```azurecli-interactive
az aks create --name <cluster-name> --resource-group <resource-group-name> --kubelet-config ./linuxkubeletconfig.json --linux-os-config ./linuxosconfig.json
```

## Add a node pool using custom configuration files

> [!NOTE]
> Keep the following information in mind when using custom configuration files when adding a new node pool to an existing AKS cluster:
>
> - When you add a Linux node pool to an existing cluster, you can specify the kubelet configuration, OS configuration, or both. When you add a Windows node pool to an existing cluster, you can only specify the kubelet configuration. If you specify a configuration when adding a node pool, the configuration applies only to the nodes in the new node pool. Any settings not configured in the JSON file retain their default values.
> - `CustomKubeletConfig` is supported for Linux and Windows node pools.

### [Linux node pools](#tab/linux-node-pools)

Create a new Linux node pool using the [`az aks nodepool add`][az-aks-create] command and specifying your configuration files for the `--kubelet-config` and `--linux-os-config` parameters. The following example command creates a new Linux node pool with the custom `./linuxkubeletconfig.json` file:

```azurecli-interactive
az aks nodepool add --name <node-pool-name> --cluster-name <cluster-name> --resource-group <resource-group-name> --kubelet-config ./linuxkubeletconfig.json
```

### [Windows node pools](#tab/windows-node-pools)

Create a new Windows node pool using the [`az aks nodepool add`][az-aks-create] command and specifying your configuration file for the `--kubelet-config` parameter. The following example command creates a new Windows node pool with the custom `./windowskubeletconfig.json` file:

```azurecli-interactive
az aks nodepool add --name <node-pool-name> --cluster-name <cluster-name> --resource-group <resource-group-name> --os-type Windows --kubelet-config ./windowskubeletconfig.json
```

---

## Confirm settings were applied

After you apply custom node configuration, you can confirm the settings were applied to the nodes by [connecting to the host][node-access] and verifying `sysctl` or configuration changes were made on the filesystem.

## Supported custom configuration parameters

### Linux kubelet custom configuration

| Parameter | Allowed values/interval | Default | Description |
| --------- | ----------------------- | ------- | ----------- |
| `cpuManagerPolicy` | none, static | none | The static policy allows containers in [guaranteed pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/) with integer CPU requests access to exclusive CPUs on the node. |
| `cpuCfsQuota` | true, false | true |  Enable/disable CPU CFS quota enforcement for containers that specify CPU limits. |
| `cpuCfsQuotaPeriod` | Interval in milliseconds (ms) | `100ms` | Sets CPU CFS quota period value. |
| `imageGcHighThreshold` | 0-100 | 85 | The percent of disk usage after which image garbage collection is always run. Minimum disk usage that triggers garbage collection. To disable image garbage collection, set to 100. |
| `imageGcLowThreshold` | 0-100, no higher than `imageGcHighThreshold` | 80 | The percent of disk usage before which image garbage collection is never run. Minimum disk usage that _can_ trigger garbage collection. |
| `topologyManagerPolicy` | none, best-effort, restricted, single-numa-node | none | Optimize NUMA node alignment. For more information, see [Control Topology Management Policies on a node](https://kubernetes.io/docs/tasks/administer-cluster/topology-manager/). |
| `allowedUnsafeSysctls` | `kernel.shm*`, `kernel.msg*`, `kernel.sem`, `fs.mqueue.*`, `net.*` | None | Allowed list of unsafe sysctls or unsafe sysctl patterns. |
| `containerLogMaxSizeMB` | Size in megabytes (MB) | 50 | The maximum size (for example, 10 MB) of a container log file before it gets rotated. |
| `containerLogMaxFiles` | ≥ 2 | 5 | The maximum number of container log files that can be present for a container. |
| `podMaxPids` | -1 to kernel PID limit | -1 (∞)| The maximum number of process IDs that can run in a Pod. |
| [`seccompDefault`][secure-container-access] | `Unconfined`, `RuntimeDefault` | `Unconfined` | Sets the default seccomp profile for all workloads. `RuntimeDefault` uses containerd's default seccomp profile, restricting certain system calls to enhance security. Restricted syscalls fail. `Unconfined` places no restrictions on syscalls, allowing all system calls are allowed and reducing security. For more information, see the [containerd default seccomp profile](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51). This parameter is in preview. [Register][register-preview] the "KubeletDefaultSeccompProfilePreview" feature flag using the [`az feature register`][az-feature-register] command with `--namespace "Microsoft.ContainerService"`.|

### Windows kubelet custom configuration

| Parameter | Allowed values/interval | Default | Description |
| --------- | ----------------------- | ------- | ----------- |
| `imageGcHighThreshold` | 0-100 | 85 | The percent of disk usage after which image garbage collection is always run. Minimum disk usage that triggers garbage collection. To disable image garbage collection, set to 100. |
| `imageGcLowThreshold` | 0-100, no higher than `imageGcHighThreshold` | 80 | The percent of disk usage before which image garbage collection is never run. Minimum disk usage that _can_ trigger garbage collection. |
| `containerLogMaxSizeMB` | Size in megabytes (MB) | 10 | The maximum size (for example, 10 MB) of a container log file before it gets rotated. |
| `containerLogMaxFiles` | ≥ 2 | 5 | The maximum number of container log files that can be present for a container. |

## Linux custom OS configuration settings

> [!IMPORTANT]
> To simplify search and readability, the OS settings are displayed in this article by their name, but they should be added to the configuration JSON file or AKS API using the [camelCase capitalization convention](/dotnet/standard/design-guidelines/capitalization-conventions).
>
> For example, if you modify the `vm.max_map_count setting`, you should reformat to `vmMaxMapCount` in the configuration JSON file.

### Linux file handle limits

When serving high amounts of traffic, that traffic commonly comes from a large number of local files. You can adjust the following kernel settings and built-in limits to allow you to handle more, at the cost of some system memory.

The following table lists the file handle limits that you can customize per node pool:

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | ----------------------- | ----------------------- | -------------------------- | ----------- |
| `fs.file-max` | 8192 - 9223372036854775807 | 9223372036854775807 | 9223372036854775807 | 9223372036854775807 | Maximum number of file-handles that the Linux kernel allocates. This value is set to the maximum possible value (2^63-1) to prevent file descriptor exhaustion and ensure unlimited system-wide file handles for containerized workloads. |
| `fs.inotify.max_user_watches` | 781250 - 2097152 | 1048576 | 1048576 | 1048576 | Maximum number of file watches allowed by the system. Each _watch_ is roughly 90 bytes on a 32-bit kernel, and roughly 160 bytes on a 64-bit kernel. |
| `fs.aio-max-nr` | 65536 - 6553500 | 65536 | 65536 | 65536 | The aio-nr shows the current system-wide number of asynchronous io requests. aio-max-nr allows you to change the maximum value aio-nr can grow to. |
| `fs.nr_open` | 8192 - 20000500 | 1048576 | 1048576 | 1073741816 | The maximum number of file-handles a process can allocate. |

> [!NOTE]
> The `fs.file-max` parameter is set to 9223372036854775807 (the maximum value for a signed 64-bit integer) across Ubuntu and Azure Linux based on upstream defaults. This configuration:
>
> - **Prevents denial-of-service attacks** based on system-wide file descriptor exhaustion.
> - **Ensures container workloads** are never bottlenecked by system-wide file handle limits.
> - **Maintains security** through per-process limits (`fs.nr_open` and `ulimit`) which still apply to individual processes.
> - **Optimizes for container platforms** where many containers might run simultaneously, each potentially opening many files and network connection.

### Linux socket and network tuning

For agent nodes, which are expected to handle large numbers of concurrent sessions, you can use following TCP and network options and adjust them per node pool:

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | ----------------------- | ----------------------- | -------------------------- | ----------- |
| `net.core.somaxconn` | 4096 - 3240000 | 16384 | 16384 | 16384 | Maximum number of connection requests that can be queued for any given listening socket. An upper limit for the value of the backlog parameter passed to the [listen(2)](http://man7.org/linux/man-pages/man2/listen.2.html) function. If the backlog argument is greater than the `somaxconn`, then it's silently truncated to this limit. |
| `net.core.netdev_max_backlog` | 1000 - 3240000 | 1000 | 1000 | 1000 | Maximum number of packets, queued on the INPUT side, when the interface receives packets faster than kernel can process them. |
| `net.core.rmem_max` | 212992 - 134217728 | 1048576 | 1048576 | 212992 | The maximum receive socket buffer size in bytes. |
| `net.core.wmem_max` | 212992 - 134217728 | 212992 | 212992 | 212992 | The maximum send socket buffer size in bytes. |
| `net.core.optmem_max` | 20480 - 4194304 | 20480 | 131072 | 20480 | Maximum ancillary buffer size (option memory buffer) allowed per socket. Socket option memory is used in a few cases to store extra structures relating to usage of the socket. |
| `net.ipv4.tcp_max_syn_backlog` | 128 - 3240000 | 16384 | 16384 | 16384 | The maximum number of queued connection requests that haven't received an acknowledgment from the connecting client. If this number is exceeded, the kernel begins dropping requests. |
| `net.ipv4.tcp_max_tw_buckets` | 8000 - 1440000 | 262144 | 262144 | 131072 | Maximal number of `timewait` sockets held by system simultaneously. If this number is exceeded, time-wait socket is immediately destroyed and warning is printed. |
| `net.ipv4.tcp_fin_timeout` | 5 - 120 | 60 | 60 | 60 | The length of time an orphaned (no longer referenced by any application) connection remains in the FIN_WAIT_2 state before it's aborted at the local end. |
| `net.ipv4.tcp_keepalive_time` | 30 - 432000 | 7200 | 7200 | 7200 | How often TCP sends out `keepalive` messages when `keepalive` is enabled. |
| `net.ipv4.tcp_keepalive_probes` | 1 - 15 | 9 | 9 | 9 | How many `keepalive` probes TCP sends out, until it decides that the connection is broken. |
| `net.ipv4.tcp_keepalive_intvl` | 10 - 90 | 75 | 75 | 75 | How frequently the probes are sent out. Multiplied by `tcp_keepalive_probes` it makes up the time to kill a connection that isn't responding, after probes started. |
| `net.ipv4.tcp_tw_reuse` | | 2 | 2 | 2 | Allow to reuse `TIME-WAIT` sockets for new connections when it's safe from protocol viewpoint. |
| `net.ipv4.ip_local_port_range` | First: 1024 - 60999 and Last: 32768 - 65535] | First: 32768 and Last: 60999 | First: 32768 and Last: 60999 | First: 32768 and Last: 60999 | The local port range that is used by TCP and UDP traffic to choose the local port. Comprised of two numbers: The first number is the first local port allowed for TCP and UDP traffic on the agent node, the second is the last local port number. |
| `net.ipv4.neigh.default.gc_thresh1`| 	128 - 80000 | 4096 | 4096 | 4096 | Minimum number of entries that can be in the ARP cache. Garbage collection isn't triggered if the number of entries is below this setting. |
| `net.ipv4.neigh.default.gc_thresh2`| 	512 - 90000 | 8192 | 8192 | 8192 | Soft maximum number of entries that can be in the ARP cache. This setting is arguably the most important, as ARP garbage collection triggers about 5 seconds after reaching this soft maximum. |
| `net.ipv4.neigh.default.gc_thresh3`| 	1024 - 100000 | 16384 | 16384 | 16384 | Hard maximum number of entries in the ARP cache. |
| `net.netfilter.nf_conntrack_max` | 131072 - 2097152 | 524288 | 524288 | 262144 | `nf_conntrack` is a module that tracks connection entries for NAT within Linux. The `nf_conntrack` module uses a hash table to record the _established connection_ record of the TCP protocol. `nf_conntrack_max` is the maximum number of nodes in the hash table, that is, the maximum number of connections supported by the `nf_conntrack` module or the size of connection tracking table. |
| `net.netfilter.nf_conntrack_buckets` | 65536 - 524288 | 262144 | 262144 | 262144 | `nf_conntrack` is a module that tracks connection entries for NAT within Linux. The `nf_conntrack` module uses a hash table to record the _established connection_ record of the TCP protocol. `nf_conntrack_buckets` is the size of hash table. |

### Linux worker limits

Like file descriptor limits, the number of workers or threads that a process can create are limited by both a kernel setting and user limits. The user limit on AKS is unlimited. The following table lists the kernel setting that you can customize per node pool:

| Setting | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | ----------------------- | ----------------------- | -------------------------- |
| `kernel.threads-max` | 1030425 | 1030462 | 256596 | Processes can spin up worker threads. The maximum number of all threads that can be created is set with the kernel setting `kernel.threads-max`. |

### Linux virtual memory

The following table lists the kernel settings that you can customize per node pool to tune the operation of the virtual memory (VM) subsystem of the Linux kernel and the `writeout` of dirty data to disk"

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | ----------------------- | ----------------------- | -------------------------- | ----------- |
| `vm.max_map_count` | | 65530 | 1048576 | 1048576 | This file contains the maximum number of memory map areas a process can have. Memory map areas are used as a side-effect of calling `malloc`, directly by `mmap`, `mprotect`, and `madvise`, and also when loading shared libraries. |
| `vm.vfs_cache_pressure` | 1 - 100 | 100 | 100 | 100 | This percentage value controls the tendency of the kernel to reclaim the memory, which is used for caching of directory and inode objects. |
| `vm.swappiness` | 0 - 100 | 60 | 60 | 60 | This control is used to define how aggressive the kernel swaps memory pages. Higher values increase aggressiveness, lower values decrease the amount of swap. A value of 0 instructs the kernel not to initiate swap until the amount of free and file-backed pages is less than the high water mark in a zone. |
| `swapFileSizeMB` | 1 MB - Size of the [temporary disk](/azure/virtual-machines/managed-disks-overview#temporary-disk) (/dev/sdb) | None | None | None | SwapFileSizeMB specifies the size in MB of a swap file to create on the agent nodes from this node pool. |
| `transparentHugePageEnabled` | `always`, `madvise`, `never` | `always` | `always` | `madvise` | [Transparent Hugepages](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html#admin-guide-transhuge) is a Linux kernel feature intended to improve performance by making more efficient use of your processor's memory-mapping hardware. When enabled the kernel attempts to allocate `hugepages` whenever possible and any Linux process receives 2-MB pages if the `mmap` region is 2 MB naturally aligned. In certain cases when `hugepages` are enabled system wide, applications might end up allocating more memory resources. An application might `mmap` a large region but only touch 1 byte of it, in that case a 2-MB page might be allocated instead of a 4k page for no good reason. This scenario is why it's possible to disable `hugepages` system-wide or to only have them inside `MADV_HUGEPAGE madvise` regions. |
| `transparentHugePageDefrag` | `always`, `defer`, `defer+madvise`, `madvise`, `never` | `madvise` | `madvise` | `madvise` | This value controls whether the kernel should make aggressive use of memory compaction to make more `hugepages` available. |

## Related content

- Learn [how to configure your AKS cluster](./concepts-clusters-workloads.md).
- Learn how [upgrade the node images](node-image-upgrade.md) in your cluster.
- See [Upgrade an Azure Kubernetes Service (AKS) cluster](upgrade-cluster.md) to learn how to upgrade your cluster to the latest version of Kubernetes.
- See the list of [Frequently asked questions about AKS](faq.yml) to find answers to some common AKS questions.

<!-- LINKS - internal -->
[node-access]: node-access.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-feature-register]: /cli/azure/feature#az-feature-register
[register-preview]: /azure/azure-resource-manager/management/preview-features?tabs=azure-cli#register-preview-feature
[secure-container-access]: secure-container-access.md
