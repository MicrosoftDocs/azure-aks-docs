---
title: Run gadgets to inspect workloads on AKS (preview)
description: Learn how to use the kubectl gadget plugin to run gadgets and inspect DNS, file, process, and network activity on Azure Kubernetes Service (AKS).
author: mqasimsarfraz
ms.author: qasimsarfraz
ms.date: 06/26/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a Kubernetes administrator, I want to run gadgets on my AKS cluster so that I can inspect the system-level behavior of my workloads.
---

# Run gadgets to inspect workloads on AKS (preview)

After you install the Inspektor Gadget cluster extension, use the `kubectl gadget` plugin to run *gadgets*. A gadget is a purpose-built tool that captures a specific kind of system activity, such as DNS queries, file access, process execution, or network connections, and correlates it with Kubernetes metadata.

To install the extension, see [Install and configure the Inspektor Gadget extension on AKS](./inspektor-gadget-configure.md).

> [!TIP]
> The examples in this article use a few common gadgets. To browse all available gadgets and choose the right one for your task, see [the Inspektor Gadget gadget catalog](./inspektor-gadget-catalog.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- The Inspektor Gadget extension installed on your AKS cluster. See [Install and configure the Inspektor Gadget extension on AKS](./inspektor-gadget-configure.md).
- The `kubectl gadget` plugin to run gadgets. You can run gadgets without any local setup by using Azure Cloud Shell, which has the `kubectl gadget` plugin preinstalled. Select **Try it** on any code block in this article to open Cloud Shell. To learn more, see [Overview of Azure Cloud Shell](/azure/cloud-shell/overview).

  To run gadgets from your own workstation instead, install the `kubectl gadget` plugin with [Krew](https://krew.sigs.k8s.io/):

  ```bash-interactive
  kubectl krew install gadget
  ```

  Alternatively, download the `kubectl-gadget` binary from the [Inspektor Gadget releases page](https://go.microsoft.com/fwlink/?LinkId=2370532) and add it to your `PATH`. Verify the installation:

  ```bash-interactive
  kubectl gadget version
  ```

> [!TIP]
> The `kubectl gadget` plug-in is also available from the Microsoft Cloud-Native package repository at `packages.microsoft.com` for Azure Linux and Ubuntu. After you add the repository, install it by using the OS package manager, such as `tdnf install -y kubectl-gadget` on Azure Linux or `apt install -y kubectl-gadget` on Ubuntu.

## Scope a gadget

You can scope a gadget to a namespace, a pod, or the entire cluster:

- Use `--namespace <namespace>` to limit a gadget to a single namespace.
- Use `--all-namespaces` to run a gadget across the whole cluster.
- Use `--timeout <seconds>` to stop the gadget after a set duration.
- Use `--fields <field-list>` to choose which columns appear in the output.

## Trace DNS queries

Capture DNS queries and responses with the originating pod:

```bash-interactive
kubectl gadget run trace_dns \
    --namespace default \
    --timeout 30 \
    --fields k8s.node,k8s.podName,id,qr,name,rcode,nameserver
```

Successful lookups show an `rcode` of `NoError`.

## Trace file access

Record file open events, including the file name and access flags:

```bash-interactive
kubectl gadget run trace_open \
    --namespace default \
    --timeout 30 \
    --fields k8s.node,k8s.podName,comm,fname,flags,error
```

The `flags` field shows the access mode, such as `O_RDONLY` for reads and `O_WRONLY` for writes.

## Trace process execution

Report process creation events with the command, PID, and arguments:

```bash-interactive
kubectl gadget run trace_exec \
    --namespace default \
    --timeout 30 \
    --fields k8s.node,k8s.podName,comm,pid,args
```

The `comm` field shows the name of the executed binary.

## Trace TCP connections

Capture TCP accept and close events with source and destination addresses across all namespaces:

```bash-interactive
kubectl gadget run trace_tcp \
    --all-namespaces \
    --timeout 30
```

## Next steps

- [Browse the Inspektor Gadget gadget catalog](./inspektor-gadget-catalog.md)
- [Troubleshoot the Inspektor Gadget extension on AKS](./inspektor-gadget-troubleshoot.md)
- [Install and configure the Inspektor Gadget extension on AKS](./inspektor-gadget-configure.md)
