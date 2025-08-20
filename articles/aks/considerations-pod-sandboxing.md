---
title: Considerations for Pod Sandboxing on AKS
description: Learn about some considerations that should be taken into account when deploying Pod Sandboxing.
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli, ignite-2025
ms.date: 11/17/2025
author: jackjiang
ms.author: jackjiang
---

# Pod Sandboxing Considerations

## Memory management

For larger scale or memory sensitive workloads, there are memory related considerations that come with utilizing Pod Sandboxing which should be accounted for. 

### Host Components 

The main host components of a Kata deployment are the _Kata Shim_, _Cloud Hypervisor_, and _virtiofsd_. The total memory usage of these components is limited by a memory cgroup field.

### Guest components 

In a Kata deployment, the main guest components that are expected to use memory are the _user's workloads_, _pod VM kernel_, and the _kata agent_. 
- Together, the memory size used by all these Guest components must be smaller than the pod VM memory size, which is fixed when a pod starts. The pod VM memory size is also limited by the same memory cgroup field that limits the host components memory usage.
- The pod VM memory size is equivalent to the [Kubernetes pod memory limit](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/#specify-a-memory-request-and-a-memory-limit) the user specifies. A user can change the VM memory size by changing the value of their pod memory limit.
   - Pods without a memory limit get a default Pod VM memory size of 512Mi.

### Pod memory cgroup

The kubelet assigns each Pod to a memory cgroup. Two of the cgroup fields are very significant:

- **memory.current** – how many bytes of memory have been allocated by all of the host components alongside the pod VM memory size.
- ***memory.max** – the upper limit of memory.current, for Pods having a memory limit specified by their users.

For a Pod having a memory limit specified by its user:

- kubelet computes the value of memory.max as the total of:
   - Pod’s memory limit, specified by the user, plus
   - Pod’s Runtime Class memory overhead.
- If the memory.current value becomes larger than the memory.max, the Pod cannot start, or it is killed.

### Runtime class memory

Users configure AKS-Kata and AKS-CC Pods to use a particular Runtime Class. Users must [specify a memory overhead](https://kubernetes.io/docs/concepts/containers/runtime-class/#pod-overhead) for each Runtime Class they use. Without specifying an appropriate overhead value, the Pods using that Runtime Class might fail to start, or might be prematurely killed, etc.

The memory overhead value of the Runtime Class used by a Pod must be large enough to cover the largest expected Host memory usage corresponding to that Pod. The memory overhead value of the Runtime Class is not expected to cover the Pod VM memory size. Typical Runtime Class overhead values corresponding to typical Pod memory limit values are provided at the end of this paper.

### User workload memory

Containers in a pod can use memory up to approximately:

- The pod VM memory size **minus** the memory used by other Pod VM components (such as the Pod VM kernel and the Kata Agent)

The memory used by other Pod VM components can be approximated by:

1. Connecting to a Pod VM
1. Executing the free command
1. Inspecting the value of the Used column from the command output.

### Recommendations

It is recommended that users: 

- Specify memory limits for every Kata pod they spin up.
- Declare a runtime class memory overhead that is appropriate for each pod memory limit.

