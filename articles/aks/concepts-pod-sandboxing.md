---
title: Overview of Pod Sandboxing
description: Learn how to spin up Kata pods to enforce compute isolation across your various workloads
ms.topic: how-to
ms.date: 11/18/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
---

# Overview of Pod Sandboxing in Azure Kubernetes Service (AKS)

As clusters scale and host workloads from multiple teams or tenants, shared infrastructure can introduce complexity. Customers often need mechanisms to enforce stronger isolation between workloads. This isolation might be driven by performance considerations like separating resource-intensive or bursty workloads from more predictable workloads to avoid disruptions. Or by security requirements that call for isolating sensitive workloads from others.

Customers today can opt for either logical or physical isolation. Customers who use logical isolation can [set up different namespaces][kubernetes-namespaces] to divide their deployments. The setup of these namespaces can be involved, and isolation isn't as in depth. With physical isolation, customer costs can increase as different clusters are spun up and not necessarily used to their full capacity.

Pod Sandboxing on AKS introduces the ability to spin up your workloads into separate lightweight pod virtual machines (VMs). Each Pod VM is isolated from other Pod VMs and the host kernel/resources, providing customers effective compute level isolation for their workloads.

Pod Sandboxing is built on the open-source [kata containers][kata-containers] project.

> [!IMPORTANT]
> Alongside Pod Sandboxing, there are other considerations, such as control plane or storage isolation, that one should consider if hard multitenancy is required.
> Take a look at the [AKS guidance for a multitenant solution][multi-tenant-guidance] to learn more about considerations to take into account for multitenant setups.

## How Pod Sandboxing works

Pod Sandboxing utilizes a few key components to introduce a new workload runtime for Kata containers.
- Users can specify in their pod's YAML to utilize the Kata specific runtime.
- The Kata runtime triggers AKS to activate the Kata shim (containerd-shim-kata) instead of the regular containerd-shim.
- The Kata shim instructs the Virtual Machine Manager to create a Pod VM with the Kata Agent running inside it.
- Creation and management of containers is delegated to the Kata Agent, which in turn creates and executes container workloads inside the Pod VM.
- When a Pod VM is deleted, the Kata shim shuts down the VM and releases the resources associated with it back to the container host.

### Why Pod Sandboxing?

Pod Sandboxing introduces an easy method to isolate your workloads in individual Pod VMs. The boundary of workloads isolated on Pod VMs is the VM itself, effectively cutting it off from other workloads and the host. Each VM also comes with its own guest kernel, separate from the host kernel. Along with other security measures and/or data protection controls, Pod Sandboxing can help augment a cluster's security posture for more defense compared to traditional deployments.

#### Workload isolation

By using Pod Sandboxing, cluster operators can feel more at ease collocating workloads on their clusters to take full advantage of the resources. With the isolation boundary of a workload being the Pod VM, the blast radius by extension is also limited to the Pod VM.

Pod Sandboxing allows a user to declare resource limits and requests for their workloads. If no quotas are declared, default values are used. If one workload is excessively resource hungry (for example, a noisy neighbor), isolating it in a pod VM would limit the workload to the resources that are allocated to that pod VM. Likewise, if a workload brings down the pod VM, other workloads sitting on the cluster remains unaffected.

#### Lift and shift

A touted benefit of Kata is the ease of integration. An operator can take their existing deployments and add one line to the pod's deployment YAML to spin it up as a Kata pod.

#### Flexibility

Kata pods are also flexible, in the sense they can be plugged into most workloads and placed on cluster alongside normal, non-Kata workloads. A user can opt to mix Kata and non-Kata workloads on the same cluster with relatively little effect to either type of workloads.

#### Open source

Many of the components that Pod Sandboxing is based on are open source. That includes components such as the [Cloud Hypervisor][cloud-hypervisor] Virtual Machine Monitor (VMM), [Kata runtime][kata-containers], and the [guest/host kernels][azure-linux].

## Next steps

- Learn about some considerations that should be taken into account before you deploy your pods on Pod Sandboxing [here][considerations-pod-sandboxing].
- Once you're ready, [deploy Pod Sandboxing on AKS][deploy-pod-sandboxing].

<!--- External Links --->
[create-azure-subscription]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[kata-containers]: https://katacontainers.io/
[cloud-hypervisor]: https://github.com/cloud-hypervisor/cloud-hypervisor
[azure-linux]: https://github.com/microsoft/azurelinux
[kubernetes-namespaces]: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/

<!--- Internal Links --->
[deploy-pod-sandboxing]: use-pod-sandboxing.md
[multi-tenant-guidance]: /azure/architecture/guide/multitenant/service/aks
[considerations-pod-sandboxing]: considerations-pod-sandboxing.md
