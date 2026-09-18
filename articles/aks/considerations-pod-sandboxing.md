---
title: Pod sandboxing on Azure Kubernetes Service (AKS) considerations
description: Learn about resource management, memory management, CPU management, and security considerations for pod sandboxing on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli, ignite-2025
ms.date: 09/17/2026
ms.author: davidsmatlak
author: davidsmatlak
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Pod sandboxing considerations on Azure Kubernetes Service (AKS)

Pod sandboxing on Azure Kubernetes Service (AKS) has resource management, memory management, CPU management, and security considerations.

## Resource management in Pod sandboxing

Review these considerations when you specify resources for a deployment, especially for large or resource-sensitive workloads.

### Kata components

A Kata deployment includes components that run on the AKS node and components that run inside the pod virtual machine (VM). This host and guest split determines how memory and CPU usage is accounted for.

| Component | Runs in | Purpose | Resource impact |
| --- | --- | --- | --- |
| Kata shim | AKS node (host) | Manages the pod VM lifecycle. | Uses host-side resources accounted for by `RuntimeClass` overhead. |
| Cloud Hypervisor | AKS node (host) | Provides the Virtual Machine Monitor (VMM) that creates and runs the pod VM. | Uses host-side resources accounted for by `RuntimeClass` overhead. |
| `virtiofsd` | AKS node (host) | Shares files between the pod VM and its container host. | Uses host-side resources accounted for by `RuntimeClass` overhead. |
| Kata agent | Pod VM (guest) | Manages containers inside the pod VM. | Uses guest-side resources from the pod VM memory and CPU allocation. |
| Pod VM kernel | Pod VM (guest) | Provides the guest operating system kernel. | Uses guest-side resources from the pod VM memory and CPU allocation. |
| Workload containers | Pod VM (guest) | Run the user workload. | Use the remaining guest-side resources, subject to the pod's resource limits. |

## Memory management in Pod sandboxing

Set the pod VM memory limit high enough to support your workload and Kata guest components without allocating unused memory.

### Pod VM memory size

Each pod VM gets memory for the workload and all Kata guest components. Include memory beyond the expected workload consumption for guest components such as the Kata agent and VM kernel. See the [reference usage values](#reference-usage-values) for typical memory values.

The [Kubernetes pod memory limit][pod-limit] determines the pod VM memory size. Change the pod memory limit to change the pod VM memory size.

> [!IMPORTANT]
> If you don't specify a pod memory limit, AKS applies the default pod VM memory size of 512Mi. After the pod starts, the pod VM memory size is fixed.

`RuntimeClass` memory overhead typically increases with the pod VM memory size.

### `RuntimeClass` memory overhead

Pod sandboxing workloads come with a default Kata `RuntimeClass` (`kata-vm-isolation`) that includes default resource overhead values. For finer-grained control of resource quotas, [set up a custom `RuntimeClass`][runtime-class-setup] with specific resource overheads. The pod memory limit sizes the guest-side memory available to the pod VM. `RuntimeClass` overhead reserves node capacity for host-side Kata components and doesn't need to account for the expected memory consumption of guest components.

You can create a specialized runtime and specify the memory overhead through the `overhead` field in your `RuntimeClass` manifest. [For example][runtime-overhead], the following manifest creates a runtime for workloads expected to have lower resource consumption:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: small-kata-pods
handler: kata
overhead:
  podFixed:
    memory: "120Mi"
```

The `memory: "120Mi"` value adds 120Mi of fixed pod overhead when Kubernetes schedules the pod and sizes its `cgroup`. The `handler: kata` value must match the Kata runtime handler configured on the AKS nodes.

Before you use a custom `RuntimeClass`, run `kubectl get runtimeclass` and verify that its handler is supported in your AKS cluster.

Specifying overhead isn't required, but it's recommended if you want finer control over the resources reserved for your workloads. If you use the default `kata-vm-isolation` `RuntimeClass` and don't specify a pod memory limit, the pod VM size defaults to 512Mi. The default `RuntimeClass` adds approximately 88Mi of memory overhead for host components, which results in a 600Mi pod `cgroup` limit.

### User workloads

Your Kata workload can use the configured _pod VM memory size_ minus the memory that guest components, such as the Kata agent and guest VM kernel, consume.

To estimate the memory these components use:

1. Connect to the pod VM (either via `kubectl exec` or `kubectl debug` to open a shell inside your pod).
1. Run the `free` command.
1. Inspect the **used** column to estimate the memory that the guest kernel and Kata agent consume.

### Memory cgroups

When Kubernetes schedules a Kata pod, kubelet assigns the pod to a memory `cgroup`. The `cgroup` enforces the pod's memory requests and limits so you can define the resources available to the pod.

The memory `cgroup` has two important fields:

| cgroup field | Description |
| --- | --- |
| `memory.current` | Reports the current memory used by the pod VM, including guest components and Kata host components. |
| `memory.max` | Defines the upper memory limit for the pod `cgroup`. The kubelet computes this value as the sum of the pod memory limit and RuntimeClass memory overhead. |

At any point, if the `memory.current` value exceeds that of `memory.max`, [the kernel might trigger an OOMKill on the pod if memory pressure is detected][requests-and-limits].

### Reference usage values

Use the following values as typical memory usage examples. Pod VM memory sizes under 128 MiB aren't supported.

**How to read this table**: `memory.current` includes the pod VM memory allocation and current host-component usage. The kubelet computes `memory.max` from the pod memory limit plus `RuntimeClass` overhead. The difference between these values indicates the capacity available for extra host-component usage.

| Pod VM memory size | `RuntimeClass` overhead | memory.current | memory.max | Free memory available to host components |
| ---- | ---- | ---- | ---- | ---- |
| 128Mi            | 16Mi                     | 133Mi                  | 144Mi              | 11Mi                                            |
| 256Mi            | 32Mi                     | 263Mi                  | 288Mi              | 25Mi                                            |
| 1Gi              | 128Mi                    | 1034Mi                 | 1152Mi             | 118Mi                                           |
| 2Gi              | 256Mi                    | 2063Mi                 | 2304Mi             | 241Mi                                           |
| 4Gi              | 374Mi                    | 4122Mi                 | 4470Mi             | 348Mi                                           |
| 8Gi              | 512Mi                    | 8232Mi                 | 8704Mi             | 472Mi                                           |
| 32Gi             | 640Mi                    | 32918Mi                | 33408Mi            | 490Mi                                           |
| 64Gi             | 768Mi                    | 65825Mi                | 66304Mi            | 479Mi                                           |
| 96Gi             | 896Mi                    | 98738Mi                | 99200Mi            | 462Mi                                           |
| 128Gi            | 1Gi                      | 131646Mi               | 132096Mi           | 450Mi                                           |

### Memory management best practices

- Specify pod VM memory sizes by setting `limits.memory` in your manifests, and define suitable resource quotas for all deployments.
  - Use a nonzero pod memory request to reserve node capacity for the pod VM before the VM starts. The request should account for the pod VM and the containers that run in it.
  - Use nonzero `RuntimeClass` memory overhead to account for the node capacity that Kata host components consume.
- For resource-intensive workloads, set a pod memory limit that provides enough memory for the workload and guest components.
- Set `RuntimeClass` memory overhead high enough for Kata host components without reserving substantially more node capacity than they require.

## CPU management in Pod sandboxing

Allocate CPU resources to Kata workloads by setting pod CPU limits and `RuntimeClass` overhead. Without a CPU limit, Kata host components can use any CPU capacity available on the node.

### Reserving CPU

Set one or both of the following fields to reserve CPU capacity for your Kata workloads:

- The `RuntimeClass` CPU overhead
- The pod CPU limit

When at least one of the two values is specified, the control plane reserves the specified number of CPUs on the node for your workload. Other pods on the same node can't access this reserved capacity.

### Pod CPU limit

Declare the [pod CPU limit][pod-cpu-limit] in your application's manifest. The limit controls how many CPUs the containers in the associated pod VM can use.

> [!IMPORTANT]
> Fractional pod CPU limits are rounded up to the next whole vCPU for pod VM allocation. The pod's CPU `cgroup` still enforces the fractional limit for the workload. Account for this rounding when planning cost and node density.

If you don't declare a pod CPU limit, AKS allocates one vCPU to the pod VM when the node has sufficient capacity. Kata host components have no CPU consumption limit.

### `RuntimeClass` CPU overhead

Specify the `RuntimeClass` overhead to reserve node capacity for the Kata host components before you deploy a workload.

You can specify the CPU overhead through the `overhead` field in your `RuntimeClass` manifest. [For example][runtime-overhead]:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: custom-kata-runtime
handler: kata
overhead:
  podFixed:
    cpu: "250m"
```

The `cpu: "250m"` value adds 0.25 vCPU of fixed pod overhead when Kubernetes schedules the pod and sizes its `cgroup`. Tune this value based on the expected CPU consumption of the Kata host components.

### CPU management best practices

- If your node typically has plenty of free CPU capacity, these reservations might be unnecessary.
- If your nodes typically run to the limit with CPU consumption, then a nonzero reservation ensures your pods can be executed more reliably.
   - Pod CPU requests help the Kubernetes scheduler reserve sufficient node capacity for a workload. Reserved capacity for a specific workload isn't available to other workloads on the node.
- Specify CPU requests that your infrastructure can accommodate. If your available capacity runs near zero, or your request is too large, your workloads might [fail to start][cpu-request-too-big].
- Align your CPU requests with your CPU limits. Requests affect Kubernetes scheduling, but the Kata shim doesn't use them to size the pod VM. The CPU limit determines the pod VM's vCPU allocation. If no CPU limit is declared, the pod VM receives one vCPU, and Kata host components have no CPU consumption limit.

### Example declarations

| `RuntimeClass` CPU overhead | Pod CPU request or limit | Expected behavior |
| --- | --- | --- |
| 1                         |  1                  | The control plane reserves two CPUs on the node. The pod VM gets one vCPU, and containers in the pod can use up to one vCPU. The Kata host components and pod VM together can use up to two CPUs from the reserved node capacity. |
| 1                         | 2.5                 | The control plane reserves 3.5 CPUs on the node. The pod VM gets three vCPUs, but containers in the pod VM can use up to 2.5 vCPUs. The Kata host components and pod VM together can use up to 3.5 CPUs from the reserved node capacity. |
| None                      | 1                   | The control plane reserves one CPU on the node. The pod VM gets one vCPU, and containers in the pod VM can use up to one vCPU. The Kata host components and pod VM together can use up to one CPU from the reserved node capacity. The CPU request makes one CPU available to the pod VM. |
| 1                         | None                | The control plane reserves one CPU on the node. The pod VM gets one vCPU, and containers in the pod VM can use up to one vCPU. The Kata host components and pod VM can use any CPU capacity available on the node. The overhead reservation makes at least one CPU available. |

## Security considerations for Pod sandboxing

Pod sandboxing isolates workloads from other workloads and the host, but you must still consider the following security risks.

### Privileged pods

Some workloads require privileged pods. You can create privileged pods, but [host devices aren't attached to the pods][privileged-containerd].

Using privileged containers gives root access in the guest VM, but the containers stay isolated from the host.

Use privileged pods only when necessary, even with Pod sandboxing. [Allow only trusted users to manage privileged pods][privileged-users].

### Host path storage volumes

Mounting `hostPath` volumes into Kata pods exposes part of the host file system directly to the container and can weaken Pod sandboxing isolation. Apply the [upstream `hostPath` security guidance][upstream-hostpath] to Pod sandboxing workloads.

Files under `/dev` are an exception because they're mounted into the container from the guest system instead of the host system. This behavior maintains pod isolation when a workload requires this path.

> [!WARNING]
> Avoid `hostPath` storage volumes unless your workload requires them.


#### Block `hostPath` volumes with Azure Policy

[Azure Policy][azure-policy] provides centralized, consistent enforcement and safeguards for your cluster components.

AKS provides [built-in policy definitions][azure-policy-reference] that enforce best practices. Assign the **Kubernetes cluster pods should only use allowed volume types** policy with the `Deny` effect, and exclude `hostPath` from the allowed volume types to block pods that attempt to mount `hostPath` volumes.

## Next steps

Learn how to [deploy Pod sandboxing on AKS][deploy-pod-sandboxing].

<!--- External Links --->
[upstream-hostpath]: https://kubernetes.io/docs/concepts/storage/volumes/#hostpath
[kata-containers]: https://katacontainers.io/
[privileged-users]: https://kubernetes.io/docs/concepts/security/pod-security-standards/#privileged
[privileged-containerd]: https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/privileged.md#containerd
[memory-overhead]: https://kubernetes.io/docs/concepts/containers/runtime-class/#pod-overhead
[pod-cpu-limit]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
[runtime-overhead]: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-overhead/#usage-example
[pod-limit]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/#specify-a-memory-request-and-a-memory-limit
[cpu-request-too-big]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/#specify-a-cpu-request-that-is-too-big-for-your-nodes
[requests-and-limits]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits
[runtime-class-setup]: https://kubernetes.io/docs/concepts/containers/runtime-class/#setup

<!-- Internal Links --->
[azure-policy]: /azure/governance/policy/concepts/policy-for-kubernetes
[azure-policy-reference]: /azure/aks/policy-reference

<!--- Internal Links --->
[deploy-pod-sandboxing]: use-pod-sandboxing.md
