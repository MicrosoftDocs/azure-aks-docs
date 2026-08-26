---
title: Custom Node Configuration Parameters for Azure Kubernetes Service (AKS)
description: Lists supported kubelet and OS configuration parameters for Azure Kubernetes Service (AKS) node pools using Custom Node Configuration.
ms.service: azure-kubernetes-service
ms.topic: reference
ms.date: 08/06/2026
ms.author: davidsmatlak
author: davidsmatlak
ms.subservice: aks-nodes
ai-usage: ai-assisted
# Customer intent: "As a cloud engineer, I want to review custom node configuration parameters for AKS node pools, so that I can choose supported settings for my workloads."
---

# Custom node configuration parameters for Azure Kubernetes Service (AKS)

This article lists supported custom node configuration parameters for Azure Kubernetes Service (AKS) node pools. To learn how to create and apply configuration files, see [Customize the node configuration for AKS node pools](custom-node-configuration.md).

## Kubelet custom configuration parameters

> [!IMPORTANT]
> When enabling unsafe sysctls, you assume responsibility for node stability and workload behavior. Unsafe sysctls can potentially cause node instability or security vulnerabilities if misconfigured. Ensure you understand the implications of enabling specific unsafe sysctls and monitor your cluster's health closely after making changes.

### Linux kubelet custom configuration

| Parameter | Allowed values/interval | Default | Description |
| --------- | ----------------------- | ------- | ----------- |
| `cpuManagerPolicy` | none, static | none | The static policy allows containers in [guaranteed pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/) with integer CPU requests access to exclusive CPUs on the node. |
| `cpuCfsQuota` | true, false | true | Enable/disable CPU CFS quota enforcement for containers that specify CPU limits. |
| `cpuCfsQuotaPeriod` | Interval in milliseconds (ms) | `100ms` | Sets CPU CFS quota period value. |
| `imageGcHighThreshold` | 0-100 | 85 | The percent of disk usage after which image garbage collection is always run. Minimum disk usage that triggers garbage collection. To disable image garbage collection, set to 100. |
| `imageGcLowThreshold` | 0-100, no higher than `imageGcHighThreshold` | 80 | The percent of disk usage before which image garbage collection is never run. Minimum disk usage that *can* trigger garbage collection. |
| `topologyManagerPolicy` | none, best-effort, restricted, single-numa-node | none | Optimize NUMA node alignment. For more information, see [Control Topology Management Policies on a node](https://kubernetes.io/docs/tasks/administer-cluster/topology-manager/). |
| `allowedUnsafeSysctls` | `kernel.shm*`, `kernel.msg*`, `kernel.sem`, `fs.mqueue.*`, `net.*` | None | Allowed list of unsafe sysctls or unsafe sysctl patterns. |
| `containerLogMaxSizeMB` | Size in megabytes (MB) | 50 | The maximum size (for example, 10 MB) of a container log file before it gets rotated. |
| `containerLogMaxFiles` | 2 or greater | 5 | The maximum number of container log files to retain for a container. |
| `podMaxPids` | -1 to kernel PID limit | -1 (infinite) | The maximum number of process IDs that can run in a pod. |
| [`seccompDefault`][secure-container-access] | `Unconfined`, `RuntimeDefault` | `Unconfined` | Sets the default seccomp profile for all workloads. `RuntimeDefault` uses containerd's default seccomp profile, restricting certain system calls to enhance security. Restricted syscalls fail. `Unconfined` places no restrictions on syscalls, allowing all system calls and reducing security. For more information, see the [containerd default seccomp profile](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51). This parameter is in preview. [Register][register-preview] the "KubeletDefaultSeccompProfilePreview" feature flag using the [`az feature register`][az-feature-register] command with `--namespace "Microsoft.ContainerService"`. |
| `kubeReserved.cpuMillicores` | 1 to the node pool CPU capacity in millicores | None | Reserves CPU for Kubernetes system daemons on Linux node pools. This parameter is in preview and requires the `CustomNodeConfigPreview` feature flag. |
| `kubeReserved.memoryMB` | 1 to the node pool memory capacity in MiB | None | Reserves memory for Kubernetes system daemons on Linux node pools. This parameter is in preview and requires the `CustomNodeConfigPreview` feature flag. |
| `hardEvictionThreshold.memoryAvailable` | `<number>Ki`, `<number>Mi`, `<number>Gi`, or `<number>%` where percentage is no more than 100 | None | Sets the kubelet hard eviction threshold for available memory on Linux node pools. This parameter is in preview and requires the `CustomNodeConfigPreview` feature flag. |
| `hardEvictionThreshold.nodeFsAvailable` | `<number>Ki`, `<number>Mi`, `<number>Gi`, or `<number>%` where percentage is no more than 100 | None | Sets the kubelet hard eviction threshold for available node filesystem space on Linux node pools. This parameter is in preview and requires the `CustomNodeConfigPreview` feature flag. |
| `hardEvictionThreshold.nodeFsInodesFree` | `<number>` or `<number>%` where percentage is no more than 100 | None | Sets the kubelet hard eviction threshold for free node filesystem inodes on Linux node pools. This parameter is in preview and requires the `CustomNodeConfigPreview` feature flag. |

### Windows kubelet custom configuration

| Parameter | Allowed values/interval | Default | Description |
| --------- | ----------------------- | ------- | ----------- |
| `imageGcHighThreshold` | 0-100 | 85 | The percent of disk usage after which image garbage collection is always run. Minimum disk usage that triggers garbage collection. To disable image garbage collection, set to 100. |
| `imageGcLowThreshold` | 0-100, no higher than `imageGcHighThreshold` | 80 | The percent of disk usage before which image garbage collection is never run. Minimum disk usage that *can* trigger garbage collection. |
| `containerLogMaxSizeMB` | Size in megabytes (MB) | 10 | The maximum size (for example, 10 MB) of a container log file before it gets rotated. |
| `containerLogMaxFiles` | 2 or greater | 5 | The maximum number of container log files to retain for a container. |

## Linux custom OS configuration parameters

> [!IMPORTANT]
> To simplify search and readability, the OS settings are displayed in this article by their name, but they should be added to the configuration JSON file or AKS API using the [camelCase capitalization convention](/dotnet/standard/design-guidelines/capitalization-conventions).
>
> For example, if you modify the `vm.max_map_count` setting, you should reformat it to `vmMaxMapCount` in the configuration JSON file.

### Linux file handle limits

When serving high amounts of traffic, that traffic commonly comes from a large number of local files. You can adjust the following kernel settings and built-in limits to allow you to handle more, at the cost of some system memory.

The following table lists the file handle limits that you can customize per node pool:

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | -------------------- | -------------------- | ----------------------- | ----------- |
| `fs.file-max` | 8192 - 9223372036854775807 | 9223372036854775807 | 9223372036854775807 | 9223372036854775807 | Maximum number of file-handles that the Linux kernel allocates. This value is set to the maximum possible value (2^63-1) to prevent file descriptor exhaustion and ensure unlimited system-wide file handles for containerized workloads. |
| `fs.inotify.max_user_watches` | 781250 - 2097152 | 1048576 | 1048576 | 1048576 | Maximum number of file watches allowed by the system. Each *watch* is roughly 90 bytes on a 32-bit kernel, and roughly 160 bytes on a 64-bit kernel. |
| `fs.aio-max-nr` | 65536 - 6553500 | 65536 | 65536 | 65536 | The aio-nr shows the current system-wide number of asynchronous I/O requests. aio-max-nr allows you to change the maximum value aio-nr can grow to. |
| `fs.nr_open` | 8192 - 20000500 | 1048576 | 1048576 | 1073741816 | The maximum number of file-handles a process can allocate. |

> [!NOTE]
> The `fs.file-max` parameter is set to 9223372036854775807 (the maximum value for a signed 64-bit integer) across Ubuntu and Azure Linux based on upstream defaults. This configuration:
>
> - **Prevents denial-of-service attacks** based on system-wide file descriptor exhaustion.
> - **Ensures container workloads** are never bottlenecked by system-wide file handle limits.
> - **Maintains security** through per-process limits (`fs.nr_open` and `ulimit`) which still apply to individual processes.
> - **Optimizes for container platforms** where many containers might run simultaneously, each potentially opening many files and network connections.

### Linux socket and network tuning

For agent nodes, which are expected to handle large numbers of concurrent sessions, you can use following TCP and network options and adjust them per node pool:

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | -------------------- | -------------------- | ----------------------- | ----------- |
| `net.core.somaxconn` | 4096 - 3240000 | 16384 | 16384 | 16384 | Maximum number of connection requests that can be queued for any given listening socket. An upper limit for the value of the backlog parameter passed to the [listen(2)](http://man7.org/linux/man-pages/man2/listen.2.html) function. If the backlog argument is greater than the `somaxconn`, then it's silently truncated to this limit. |
| `net.core.netdev_max_backlog` | 1000 - 3240000 | 1000 | 1000 | 1000 | Maximum number of packets, queued on the INPUT side, when the interface receives packets faster than kernel can process them. |
| `net.core.rmem_max` | 212992 - 134217728 | 1048576 | 1048576 | 212992 | The maximum receive socket buffer size in bytes. |
| `net.core.wmem_max` | 212992 - 134217728 | 212992 | 212992 | 212992 | The maximum send socket buffer size in bytes. |
| `net.core.optmem_max` | 20480 - 4194304 | 20480 | 131072 | 20480 | Maximum ancillary buffer size (option memory buffer) allowed per socket. Socket option memory is used in a few cases to store extra structures relating to usage of the socket. |
| `net.ipv4.tcp_max_syn_backlog` | 128 - 3240000 | 16384 | 16384 | 16384 | The maximum number of queued connection requests that haven't received an acknowledgment from the connecting client. If this number is exceeded, the kernel begins dropping requests. |
| `net.ipv4.tcp_max_tw_buckets` | 8000 - 1440000 | 262144 | 262144 | 131072 | Maximum number of `TIME-WAIT` sockets held by the system simultaneously. If this number is exceeded, time-wait socket is immediately destroyed and warning is printed. |
| `net.ipv4.tcp_fin_timeout` | 5 - 120 | 60 | 60 | 60 | The length of time an orphaned (no longer referenced by any application) connection remains in the FIN_WAIT_2 state before it's aborted at the local end. |
| `net.ipv4.tcp_keepalive_time` | 30 - 432000 | 7200 | 7200 | 7200 | How often TCP sends out `keepalive` messages when `keepalive` is enabled. |
| `net.ipv4.tcp_keepalive_probes` | 1 - 15 | 9 | 9 | 9 | How many `keepalive` probes TCP sends out, until it decides that the connection is broken. |
| `net.ipv4.tcp_keepalive_intvl` | 10 - 90 | 75 | 75 | 75 | How frequently the probes are sent out. Multiplied by `tcp_keepalive_probes` it makes up the time to kill a connection that isn't responding, after probes started. |
| `net.ipv4.tcp_tw_reuse` | | 2 | 2 | 2 | Allows reuse of `TIME-WAIT` sockets for new connections when it's safe from a protocol viewpoint. |
| `net.ipv4.ip_local_port_range` | First: 1024 - 60999 and Last: 32768 - 65535] | First: 32768 and Last: 60999 | First: 32768 and Last: 60999 | First: 32768 and Last: 60999 | The local port range that is used by TCP and UDP traffic to choose the local port. The range is composed of two numbers: the first local port allowed for TCP and UDP traffic on the agent node, and the last local port number. |
| `net.ipv4.neigh.default.gc_thresh1` | 128 - 80000 | 4096 | 4096 | 4096 | Minimum number of entries that can be in the ARP cache. Garbage collection isn't triggered if the number of entries is below this setting. |
| `net.ipv4.neigh.default.gc_thresh2` | 512 - 90000 | 8192 | 8192 | 8192 | Soft maximum number of entries that can be in the ARP cache. This setting is arguably the most important, as ARP garbage collection triggers about 5 seconds after reaching this soft maximum. |
| `net.ipv4.neigh.default.gc_thresh3` | 1024 - 100000 | 16384 | 16384 | 16384 | Hard maximum number of entries in the ARP cache. |
| `net.netfilter.nf_conntrack_max` | 131072 - 2097152 | Dynamically calculated | Dynamically calculated | Dynamically calculated | `nf_conntrack` is a module that tracks connection entries for NAT within Linux. The `nf_conntrack` module uses a hash table to record the *established connection* record of the TCP protocol. `nf_conntrack_max` is the maximum number of nodes in the hash table, that is, the maximum number of connections supported by the `nf_conntrack` module or the size of connection tracking table. **Default value** is dynamically calculated based on system memory using the formula: `RAM_in_bytes / 16384` (or `RAM_in_MB * 64`). For example, a virtual machine with 8 GB RAM has a default of approximately 524,288 connections. Actual values vary based on the virtual machine size and available memory. |
| `net.netfilter.nf_conntrack_buckets` | 65536 - 524288 | Dynamically calculated | Dynamically calculated | Dynamically calculated | `nf_conntrack` is a module that tracks connection entries for NAT within Linux. The `nf_conntrack` module uses a hash table to record the *established connection* record of the TCP protocol. `nf_conntrack_buckets` is the size of hash table. **Default value** is dynamically calculated based on system memory using the formula: `RAM_in_bytes / 16384`, with a minimum of 1,024 buckets and a maximum of 262,144 buckets. The default `nf_conntrack_max` is typically set to `nf_conntrack_buckets * 4`. Actual values vary based on the virtual machine size and available memory. |

### Linux worker limits

Like file descriptor limits, the number of workers or threads that a process can create are limited by both a kernel setting and user limits. The user limit on AKS is unlimited. The following table lists the kernel setting that you can customize per node pool:

| Setting | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | -------------------- | -------------------- | ----------------------- | ----------- |
| `kernel.threads-max` | Dynamically calculated | Dynamically calculated | Dynamically calculated | Processes can spin up worker threads. The maximum number of all threads that can be created is set with the kernel setting `kernel.threads-max`. **Default value is dynamically calculated** based on system memory using the formula: `total_ram_pages / 4` (where each page is typically 4 KB). Actual values vary based on the virtual machine size and available memory. |

### Linux virtual memory

The following table lists the kernel settings that you can customize per node pool to tune the operation of the virtual memory (VM) subsystem of the Linux kernel and the `writeout` of dirty data to disk:

| Setting | Allowed values/interval | Ubuntu 22.04 default | Ubuntu 24.04 default | Azure Linux 3.0 default | Description |
| ------- | ----------------------- | -------------------- | -------------------- | ----------------------- | ----------- |
| `vm.max_map_count` | | 65530 | 1048576 | 1048576 | This file contains the maximum number of memory map areas a process can have. Memory map areas are used as a side-effect of calling `malloc`, directly by `mmap`, `mprotect`, and `madvise`, and also when loading shared libraries. |
| `vm.vfs_cache_pressure` | 1 - 100 | 100 | 100 | 100 | This percentage value controls the tendency of the kernel to reclaim the memory, which is used for caching of directory and inode objects. |
| `vm.swappiness` | 0 - 100 | 60 | 60 | 60 | This control is used to define how aggressively the kernel swaps memory pages. Higher values increase aggressiveness, lower values decrease the amount of swap. A value of 0 instructs the kernel not to initiate swap until the amount of free and file-backed pages is less than the high water mark in a zone. |
| `swapFileSizeMB` | 1 MB - Size of the [temporary disk](/azure/virtual-machines/managed-disks-overview#temporary-disk) (/dev/sdb) | None | None | None | SwapFileSizeMB specifies the size in MB of a swap file to create on the agent nodes from this node pool. |
| `transparentHugePageEnabled` | `always`, `madvise`, `never` | `always` | `always` | `madvise` | [Transparent Hugepages](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html#admin-guide-transhuge) is a Linux kernel feature intended to improve performance by making more efficient use of your processor's memory-mapping hardware. When enabled the kernel attempts to allocate `hugepages` whenever possible and any Linux process receives 2-MB pages if the `mmap` region is 2 MB naturally aligned. In certain cases when `hugepages` are enabled system wide, applications might end up allocating more memory resources. An application might `mmap` a large region but only touch 1 byte of it, in that case a 2-MB page might be allocated instead of a 4k page for no good reason. This scenario is why it's possible to disable `hugepages` system-wide or to only have them inside `MADV_HUGEPAGE madvise` regions. |
| `transparentHugePageDefrag` | `always`, `defer`, `defer+madvise`, `madvise`, `never` | `madvise` | `madvise` | `madvise` | This value controls whether the kernel should make aggressive use of memory compaction to make more `hugepages` available. |

<!-- LINKS - internal -->
[az-feature-register]: /cli/azure/feature#az-feature-register
[register-preview]: /azure/azure-resource-manager/management/preview-features?tabs=azure-cli#register-preview-feature
[secure-container-access]: secure-container-access.md
