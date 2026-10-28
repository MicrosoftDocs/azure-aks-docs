---
title: Inspektor Gadget gadget catalog for AKS (preview)
description: Browse the catalog of official gadgets available with the Inspektor Gadget cluster extension on Azure Kubernetes Service (AKS), grouped by category.
author: mqasimsarfraz
ms.author: qasimsarfraz
ms.date: 06/26/2026
ms.topic: concept-article
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a Kubernetes administrator, I want to browse the available Inspektor Gadget gadgets so that I can choose the right one to inspect my AKS workloads.
---

# Inspektor Gadget gadget catalog for AKS (preview)

[Inspektor Gadget](https://go.microsoft.com/fwlink/?LinkId=2260072) ships a catalog of *gadgets*. Each gadget is a self-contained, eBPF-based tool that captures one kind of system activity and correlates it with Kubernetes metadata. This article lists the official gadgets, grouped by category, so you can pick the right tool for your specific task. The applications of the gadgets are far reaching, from DNS troubleshooting to file access observability, so feel free to explore the full catalog.

You run any gadget with the `kubectl gadget run <gadget>` command. For example, `kubectl gadget run trace_dns`. To learn how to scope and run gadgets, see [Run gadgets to inspect workloads on AKS](./inspektor-gadget-run-gadgets.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Gadget categories

Gadgets are named by the kind of observation they perform. The prefix tells you how a gadget behaves:

| Category | Prefix | Behavior |
|----------|--------|----------|
| [Trace](#trace-gadgets) | `trace_` | Streams events continuously as they happen. |
| [Snapshot](#snapshot-gadgets) | `snapshot_` | Returns a point-in-time view of the current state. |
| [Top](#top-gadgets) | `top_` | Periodically reports the busiest resources, like a `top` command. |
| [Profile](#profile-gadgets) | `profile_` | Aggregates data over a period, often as a histogram. |
| [Advise](#advise-gadgets) | `advise_` | Observes activity and recommends a configuration. |
| [Audit](#audit-gadgets) | `audit_` | Records security-relevant audit events. |
| [Other](#other-gadgets) | — | Specialized tools that don't fit the categories above. |

## Trace gadgets

Trace gadgets stream events in real time. Use them to watch activity as it happens.

| Gadget | What it traces |
|--------|----------------|
| `trace_bind` | Socket `bind()` calls, to see which ports processes listen on. |
| `trace_capabilities` | Linux capability checks, to find the capabilities a workload needs. |
| `trace_dns` | DNS queries and responses, with the originating pod. |
| `trace_exec` | New process executions (`execve`), with the command and arguments. |
| `trace_fsslower` | Filesystem operations slower than a configurable threshold. |
| `trace_init_module` | Kernel module loads (`init_module`). |
| `trace_lsm` | Linux Security Module (LSM) hook decisions. |
| `trace_malloc` | User-space memory allocations and frees (`malloc`/`free`). |
| `trace_oomkill` | Out-of-memory (OOM) killer events. |
| `trace_open` | Files opened (`open`/`openat`), with the file name and flags. |
| `trace_signal` | Signals sent between processes. |
| `trace_sni` | TLS Server Name Indication (SNI) values from the ClientHello. |
| `trace_ssl` | SSL/TLS data through uprobes on the TLS libraries. |
| `trace_tcp` | TCP connect, accept, and close events. |
| `trace_tcpdrop` | TCP packets dropped by the kernel. |
| `trace_tcpretrans` | TCP retransmissions. |

## Snapshot gadgets

Snapshot gadgets return the current state when you run them.

| Gadget | What it captures |
|--------|------------------|
| `snapshot_process` | The processes currently running. |
| `snapshot_socket` | The active network sockets. |
| `snapshot_file` | The files currently open per process. |

## Top gadgets

Top gadgets refresh periodically and rank resources by activity, similar to the Linux `top` command.

| Gadget | What it ranks |
|--------|---------------|
| `top_process` | Processes by CPU and memory usage. |
| `top_file` | Processes by file read and write activity. |
| `top_tcp` | TCP connections by traffic volume. |
| `top_blockio` | Processes by block I/O. |
| `top_cpu_throttle` | Processes throttled by their cgroup CPU limits. |
| `top_cuda_memory` | Processes by GPU (CUDA) memory usage. |

## Profile gadgets

Profile gadgets aggregate measurements over a period and summarize them, often as a histogram.

| Gadget | What it profiles |
|--------|------------------|
| `profile_cpu` | CPU usage by sampling stack traces, for flame graph analysis. |
| `profile_blockio` | Block I/O latency distribution. |
| `profile_tcprtt` | TCP round-trip time (RTT) distribution. |
| `profile_qdisc_latency` | Queueing discipline (qdisc) latency distribution. |
| `profile_cuda` | GPU (CUDA) kernel activity. |

## Advise gadgets

Advise gadgets observe your workloads over time and generate a recommended configuration.

| Gadget | What it recommends |
|--------|--------------------|
| `advise_networkpolicy` | A set of Kubernetes network policies based on observed traffic. |
| `advise_seccomp` | A seccomp profile based on the system calls a workload makes. |

## Audit gadgets

Audit gadgets capture security-relevant events for review.

| Gadget | What it audits |
|--------|----------------|
| `audit_seccomp` | Seccomp events, such as syscalls blocked or logged by a seccomp profile. |

## Other gadgets

These specialized gadgets address specific debugging scenarios.

| Gadget | What it does |
|--------|--------------|
| `bpfstats` | Reports statistics about the eBPF programs running on the node, such as runtime and memory usage. |
| `tcpdump` | Captures packets in `tcpdump` style and writes them to a pcap file. |
| `traceloop` | Continuously records system calls in a ring buffer for postmortem replay. |
| `deadlock` | Detects potential mutex deadlocks in a target process. |
| `fdpass` | Traces file descriptors passed between processes through `SCM_RIGHTS`. |
| `fsnotify` | Traces `fsnotify` and `inotify` filesystem notification events. |
| `ttysnoop` | Mirrors the input and output of a terminal (tty or pts) session. |

> [!NOTE]
> Each gadget has its own fields and kernel requirements. Some gadgets, such as the GPU-related ones, require nodes with the matching hardware.

## Next steps

- [Run gadgets to inspect workloads on AKS](./inspektor-gadget-run-gadgets.md)
- [Install and configure the Inspektor Gadget extension on AKS](./inspektor-gadget-configure.md)
- [Troubleshoot the Inspektor Gadget extension on AKS](./inspektor-gadget-troubleshoot.md)
