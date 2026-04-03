---
title: Considerations for Pod Sandboxing on Azure Kubernetes Service (AKS)
description: Learn about some considerations that should be taken into account when deploying Pod Sandboxing.
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli, ignite-2025
ms.date: 11/18/2025
author: jackjiang
ms.author: jackjiang
---

# Pod Sandboxing considerations

For Pod Sandboxing deployments on Azure Kubernetes Service (AKS) there are several items to consider in regard to resource management, memory management, CPU management, and security.

## Resource management

Memory and CPU management behavior with Pod Sandboxing might be unfamiliar to some users. These considerations are relevant when specifying resources in a deployment, especially for larger and resource sensitive workloads.

### Kata components

In a Kata deployment, there are generally two families of components that get deployed. You have **host components** and **guest components**.

- The main **host components** comprise of the _Kata shim_, _Cloud Hypervisor_, and _virtiofsd_.
   - The _Kata shim_ manages a pod VM lifecycle.
   - _Cloud Hypervisor_ is the Virtual Machine Monitor (VMM) used by the Kata shim.
   - _virtiofsd_ is a daemon used to share files between each Pod VM and its container host.
- The main **guest components** include the _user's workloads_, _pod VM kernel_, and the _Kata agent_.
   - The _Kata agent_ manages containers inside of the Pod VMs

### Memory management

With Kata pods, you have the ability to specify the amount of memory of the Pod VM that hosts your workloads. It's crucial that you configure the values accordingly so that a pod has sufficient resources, but doesn't result in unused memory being allocated to the pod.

### Pod VM memory size

There's an amount of memory allocated to each pod VM that runs a container. This VM memory size is inclusive of all the memory necessary to run Kata guest components. Users should take care to ensure that they buffer some extra memory beyond the expected consumption of their workloads to account for the consumption of other guest components, such as the kata agent or VM kernel. Examples are given on typical memory values later on in this article.

The pod VM memory size is equivalent to the [Kubernetes pod memory limit][pod-limit] the user specifies. A user can change the value by changing their pod memory limit; if no values are specified, a default size of 512Mi is applied. Once the pod starts, this size becomes fixed.

As the pod VM memory size increases, the runtime class memory overhead should be expected to increase alongside it.

### Runtime class memory overhead

Pod Sandboxing workloads come with a default kata runtime class (`kata-vm-isolation`) which comes with default overheads for resources. Users that want finer grain control of their resource quotas can [set up a custom runtime class][runtime-class-setup] with specific resource overheads. When doing so, users should ensure that the memory overhead value of the runtime class is enough that covers all expected usage for the **host components** of a kata deployment. The runtime class memory overhead does _not_ need to account for the expected memory consumption of the **guest components**.

You can create a specialized runtime and specify the memory overhead in your runtime class through the `overhead` field in your `RuntimeClass` manifest. [As an example][runtime-overhead], let's assume I want to create a runtime for workloads I expect to be smaller in consumption:

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

Specifying overheads isn't required, and suggested if you want finer control over the resources being set aside for your workloads. If you use the default `kata-vm-isolation` runtime class and don't specify any overheads in your YAML, the overhead of the Pod VM size defaults to 512Mi and the runtime class overhead defaults to 600Mi. This default runtime overhead is calculated with the default pod VM size (512Mi) plus to approximate memory needed by host components for such a VM size (~88Mi).

### User workloads

When a user deploys a Kata workload, they're able to use memory up to the configured _pod VM memory size_ minus the other guest components, such as the Kata agent or the guest VM kernel.

If you would like to get an approximation of the memory used by these components:

1. Connect to the pod VM (either via `kubectl exec` or `kubectl debug` to open a shell inside your pod).
1. Run the `free` command.
1. Inspect the "used" column in the output to get an idea of the memory consumed by the guest kernel/kata agent.

### Memory cgroups

When a Kata pod is scheduled to run, kubelet assigns the pod to a memory `cgroup`. This `cgroup` enforces the pod's memory limits/requests, allowing a user to define the resource quotas available to a pod.

Within the memory `cgroup`, there are two important fields to consider:

- `memory.current` defines how many bytes of memory the host components and the pod VM memory size allocates.
- `memory.max` optional, user defined upper limit of memory.current for pods where users want to impose a memory limit.
   - The kubelet computes this value as the sum of a pod's memory limit and its runtime class memory overhead.

At any point, if the `memory.current` value exceeds that of `memory.max`, [the kernel might trigger an OOMKill on the pod if memory pressure is detected][requests-and-limits].

### Reference usage values

Users can utilize these values to serve as a reference for the typical memory usage and values across the different variables covered. Pod VM memory sizes under 128Mi aren't supported.

| Pod VM Memory Size | Runtime class overhead | memory.current | memory.max | Free memory available to Host components |
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

## CPU management

In a similar vein to memory, you can also allocate CPU resources to your Kata workloads. Doing so is recommended; without declaring a CPU limit for your Kata pod, Kata host components are able to use any CPU capacity available on the node.

### Reserving CPU

When reserving CPUs for your Kata workloads, you have two fields you can choose to set.

- The _runtime class CPU overhead_
- The _pod CPU limit_

When at least one of the two values is specified, the control plane reserves the specified number of CPUs on the node for your workload. Other pods on the same node can't access this reserved capacity.

### Pod CPU limit

You can declare your [pod CPU limit][pod-cpu-limit] in your application's manifest. A specified pod CPU limit defines the limit of the CPUs that containers in the associated pod VM can use.

If you specify fractions of CPUs for the pod CPU limit, those fractions will get rounded up to the next integer. The rounded up number becomes the number of vCPUs allocated to the Pod VM, but a `cgroup` will limit the workload to only consume the fraction specified in the pod CPU limit.

If no number is declared, one vCPU will be allocated to the pod VM if the capacity is available on the node. There's no limit on the CPU consumption of the Kata host components.

### Runtime class CPU overhead

The runtime class overhead should be specified if you'd like to preemptively reserve some node capacity for the Kata host components.

You can specify the memory overhead in your runtime class through the `overhead` field in your `RunTimeClass` manifest. [As an example][runtime-overhead]:

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

### Best practices

#### Memory management

- Ensure you specify pod VM memory sizes (defined by the `limits.memory` in your manifest) and suitable resource quotas for all your deployments.
   - Ensure you use a nonzero _pod request_ if you want to ensure that some node capacity is reserved for the pod VM before that VM starts up. The request should account for the pod VM and containers that are expected to run on it.
   - Ensure you use a nonzero _runtime class overhead_ if you want to reserve some node capacity for the Kata host components before those components start up.
- If you expect your pod workloads to be especially resource hungry, you can specify limits accordingly for the pod VM to ensure that there are ample resources available for your workloads.
- Declare a suitable runtime class memory overhead such that it gives enough memory for your host components but doesn't take too much to avoid allocating unused memory.

#### CPU management

- If your node typically has plenty of free CPU capacity, these reservations might be unnecessary.
- If your nodes typically run to the limit with CPU consumption, then a nonzero reservation ensures your pods can be executed more reliably.
   - You can utilize pod CPU requests to ensure that some CPU node capacity is reserved for the Kata host components. Reserved capacity for a specific workload is _not_ available to other workloads on the node.
- Make sure you specify CPU requests that your infrastructure can accommodate. If your available capacity runs near 0, or your request is too large, your workloads might [fail to start][cpu-request-too-big]
- Align your CPU requests with your CPU limits. The Kata shim doesn't have visibility into requests. Therefore, if no CPU limit is declared, the pod VM is limited to one vCPU. The Kata host components, which do have visibility into request values, consumes the rest of the requested CPU count and have no limit to CPU consumption.

- Reserved capacity for a specific workload is _not_ available to other workloads on the node.

### Example declarations

| Runtime class CPU overhead | Pod CPU Request/Limit | Expected behavior |
| --- | --- | --- |
| 1                         |  1                  | The control plane reserves two CPUs on the node. The pod VM gets one CPU, and containers on the pod can use up to the one vCPU capacity. The Kata host components and pod VM together can use up to two CPUs from the reserved capacity on the node. |
| 1                         | 2.5                 | The control plane reserves 3.5 CPUs on the node. The pod VM gets three vCPUs, but containers on the pod VM can use up to 2.5 vCPU capacity. The Kata host components and pod VM together can use up to 3.5 CPUs from the reserved capacity on the node. |
| None                      | 1                   | The control plane reserves one CPU on the node. The pod VM gets one vCPU, and containers on the pod VM can use up to one vCPU capacity. The Kata host components and the pod VM together are allowed to use up to one CPU from the reserved capacity on the node. One CPU is always available to the pod VM due to the CPU request. |
| 1                         | None                | The control plane reserves one CPU on the node. The pod VM gets one vCPU, and containers on the pod VM can use up to one vCPU capacity. The kata host components and the pod VM can use any CPU capacity available on the node. At least one CPU is always available due to the overhead reservation. |

## Security

Pod Sandboxing offers users a compelling option to isolate their workloads from other workloads and the host. There are, nonetheless, important security concerns that should be taken into account.

### Privileged pods

There are scenarios in which privileged pods might be required. Users are able to spin up privileged pods, but no [host devices are attached to the pod][privileged-containerd].

Using privileged containers lead to root access in the guest VM, but remain isolated from the host.

Privileged pods, even on Pod Sandboxing, should only be used when necessary. Privileged pods should continue to be [managed by trusted users][privileged-users].

### Host path storage volumes

`hostPath` volumes can be mounted into Kata pods. In Pod Sandboxing, using `hostPath` volumes can potentially undermine the isolation that Kata provides; since part of the host filesystem is exposed directly to the container, a potential attack vector is opened. The warnings posed by [upstream][upstream-hostpath] should be considered as relevant for Pod Sandboxing as well.

There are some exceptions; files under `/dev` are mounted into the container from the guest system instead of the host system. This helps maintain pod isolation for situations where this path must be mounted to function.

> [!WARNING]
> Unless necessary, the recommendation is to _avoid_ using hostPath storage volumes.


#### Blocking hostPath via Azure Policy

[Azure Policy][azure-policy] allows users to apply at-scale enforcements and safeguards on their cluster components in a centralized, consistent manner.

There is a set of [built-in policy sets][azure-policy-reference] for AKS that enforce best practices. Users can take advantage of one of these policies to block deployments that attempt to mount hostPaths.

## Next steps

Once you're ready, learn how to [deploy pod sandboxing on AKS][deploy-pod-sandboxing].

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
[azure-policy-reference]: policy-reference.md

<!--- Internal Links --->
[deploy-pod-sandboxing]: use-pod-sandboxing.md
