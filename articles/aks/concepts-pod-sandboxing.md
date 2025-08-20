---
title: Overview of Pod Sandboxing
description: Learn how to spin up Kata pods to enforce compute isolation across your various workloads
ms.topic: how-to
ms.date: 11/01/2025
ms.service: azure-kubernetes-service
ms.author: jackjiang
author: jakjang
---

# Overview of Pod Sandboxing in Azure Kubernetes Service (AKS)

As customer workloads proliferate on a cluster and different users across teams or tenants get mixed on the cluster, different concerns may arise from having clusters that run a wide plethora of workloads. Customers may want to separate the resource intensive, bursty workloads from more stable/less resource intensive ones to avoid disruptions. There may be the desire to separate different workloads from one another due to security concerns. Customers today can opt for either logical or physical isolation; with logical isolation, the setup can be really involved, and isolation not as in depth. With physical isolation, customer costs can balloon as different clusters are spun up and not necessarily utilized to it's full capacity. 

Pod Sandboxing on AKS comes in and introduces the ability to spun up your workloads in separate Kata virtual machines (VMs). Each Kata VM is isolated from other Kata VMs and the host kernel/resources, providing customers effective compute level isolation for their workloads. 

Pod Sandboxing is built on the open-source [kata containers](kata-containers) project.

> [!IMPORTANT]
> Pod Sandboxing provides effective compute isolation, but there are additional considerations, such as control plane or storage isolation, that one should take into account if hard multi-tenancy is required.
> Take a look at the [AKS guidance for a multi-tenant solution](multi-tenant-guidance) to learn more about considerations to take into account for multi-tenant setups.

# How Pod Sandboxing works

Pod Sandboxing utilizes a few key components to introduce a new workload runtime for Kata containers. 
- Users can specify in their pod's YAML to utilize the Kata specific runtime
- The Kata runtime triggers AKS to activate the Kata shim (containerd-shim-kata) instead of the regular containerd-shim
- The Kata shim instructs Cloud Hypervisor to create a Kata VM with the Kata Agent running inside it.
- Creation and management of containers is delegated to the Kata Agent, which in turn creates and excutes container workloads inside the Kata VM.
- When a Kata VM is deleted, the Kata shim shuts down the VM and releases the resources associated with it back to the container host.

[insert image here] 

## Why Pod Sandboxing?

Pod Sandboxing introduces an easy and straight-forward manner to isolate your workloads in individual Kata VMs. The boundary of workloads isolated on Kata VMs is the VM itself, effectively cutting it off from other workloads and the host. Along with other security measures and/or data protection controls, Pod Sandboxing can help augment one's architecture to meet regulatory, industry, or governance compliance for protection of workloads and/or information. 

### Workload Isolation

By using Pod Sandboxing, cluster operators can feel more at ease with bin-packing their clusters to take full advantage of the hardware prowess. With the isolation boundary of a workload being the Kata VM, the blast radius by extension is also limited to the Kata VM. If one workload is excessively resource hungry (e.g. a noisy neighbor), it would be limited to the resources that are allocated to the Kata VM it sits on. Alternatively, if a workload brings down the VM, other workloads sitting on the cluster will remain unaffected. 

### Lift and Shift

A touted benefit of Kata is the ease of integration. An operator can simply take their existing deployments and add one line to the pod's deployment YAML to have it spun up as a Kata pod. 

### Flexibility 

Kata pods are also extremely flexible, in the sense they can be plugged into most workloads and placed on cluster alongside normal, non-Kata workloads. A user can opt to mix Kata and non-Kata workloads on the same cluster with relatively little impact to either type of workloads.  

# Next Steps

- Pod Sandboxing has unique memory management considerations and techniques. Learn more about how Kata consumes resources, how to config resource consumption for Kata workloads, and how to deploy Pod Sandboxing [here](deploy-pod-sandboxing).

<!--- External Links --->
[create-azure-subscription]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[kata-containers]: https://katacontainers.io/


<!--- Internal Links --->
[deploy-pod-sandboxing]: use-pod-sandboxing.md
[multi-tenant-guidance]: azure/architecture/guide/multitenant/service/aks
