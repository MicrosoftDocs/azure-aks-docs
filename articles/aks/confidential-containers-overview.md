---
title: Confidential Containers (preview) with Azure Kubernetes Service (AKS)
description: Learn about Confidential Containers (preview) on an Azure Kubernetes Service (AKS) cluster to maintain security and protect sensitive information.
ms.topic: concept-article
ms.subservice: aks-security
ms.date: 03/18/2024
author: schaffererin
ms.author: schaffererin

# Customer intent: As a cloud architect, I want to implement Confidential Containers on an Azure Kubernetes Service cluster so that I can enhance the security and privacy of sensitive workloads while meeting compliance requirements.
---

# Confidential Containers (preview) with Azure Kubernetes Service (AKS)

> [!IMPORTANT]
> The Confidential Containers preview is set to sunset in **March 2026**. After this date, customers with existing Confidential Container node pools should expect to see reduced functionality, and you won't be able to spin up any new nodes with the `KataCcIsolation` runtime. Customers currently using Confidential Container node pools can continue using them as normal. If you want to move off Confidential Containers, consider the following alternatives:
>
> - [Confidential VMs on AKS][use-confidential-vms]: Offers a similar hardware-based TEE that leverages AMD SEV-SNP security features, without the addition of per-VM isolation for workloads seen in Confidential Containers.
> - [Application enclave support][intel-sgx-confidential-nodes]: Provides users with Intel SGX confidential computing VM nodes that support hardware-based, process-level container isolation through the Intel SGX trusted execution environment.
> - [Confidential Containers on Azure Container Instances][aci-confidential-containers]: Allows for lift-and-shift deployments on containers backed by AMD SEV-SNP. Functionality includes performing full guest attestation, access to toolings to generate policies, and utilizing sidecar containers for secure key releases. ACI nodes can be run on AKS via [virtual nodes][aci-virtual-nodes].
> - [Azure RedHat OpenShift Confidential Containers][aro-confidential-containers]: Offers a similar AMD SEV-SNP backed TEE and utilizes the Kata runtime for per-container level isolation.
> - [Open source Confidential Containers][oss-cc]: Gives a similar AMD SEV-SNP backed TEE that comes with per-container isolation through Kata.
>
> If you have additional questions, please create a [support request](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade/newsupportrequest) or post an issue in [AKS issues][aks-issues].

Confidential Containers provide a set of features and capabilities to further secure your standard container workloads to achieve higher data security, data privacy and runtime code integrity goals. Azure Kubernetes Service (AKS) includes Confidential Containers (preview) on AKS.

Confidential Containers builds on Kata Confidential Containers and hardware-based encryption to encrypt container memory. It establishes a new level of data confidentiality by preventing data in memory during computation from being in clear text, readable format. Trust is earned in the container through hardware attestation, allowing access to the encrypted data by trusted entities.

Together with [Pod Sandboxing][pod-sandboxing-overview], you can run sensitive workloads isolated in Azure to protect your data and workloads. What makes a container confidential:

* Transparency: The confidential container environment where your sensitive application is shared, you can see and verify if it's safe. All components of the Trusted Computing Base (TCB) are to be open sourced.
* Auditability: You have the ability to verify and see what version of the CoCo environment package including Linux Guest OS and all the components are current. Microsoft signs to the guest OS and container runtime environment for verifications through attestation. It also releases a secure hash algorithm (SHA) of guest OS builds to build a string audibility and control story.
* Full attestation: Anything that is part of the TEE shall be fully measured by the CPU with ability to verify remotely. The hardware report from AMD SEV-SNP processor shall reflect container layers and container runtime configuration hash through the attestation claims. Application can fetch the hardware report locally including the report that reflects Guest OS image and container runtime.
* Code integrity: Runtime enforcement is always available through customer defined policies for containers and container configuration, such as immutable policies and container signing.
* Isolation from operator: Security designs that assume least privilege and highest isolation shielding from all untrusted parties including customer/tenant admins. It includes hardening existing Kubernetes control plane access (kubelet) to confidential pods.

With other security measures or data protection controls, as part of your overall architecture, these capabilities help you meet regulatory, industry, or governance compliance requirements for securing sensitive information.

This article helps you understand the Confidential Containers feature, and how to implement and configure the following:

* Deploy or upgrade an AKS cluster using the Azure CLI
* Add an annotation to your pod YAML to mark the pod as being run as a confidential container
* Add a [security policy][confidential-containers-security-policy] to your pod YAML
* Deploy your application in confidential computing

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Supported scenarios

Confidential Containers (preview) are appropriate for deployment scenarios that involve sensitive data. For example, personally identifiable information (PII) or any data with strong security needed for regulatory compliance. Some common scenarios with containers are:

- Run big data analytics using Apache Spark for fraud pattern recognition in the financial sector.
- Running self-hosted GitHub runners to securely sign code as part of Continuous Integration and Continuous Deployment (CI/CD) DevOps practices.
- Machine Learning inferencing and training of ML models using an encrypted data set from a trusted source. It only decrypts inside a confidential container environment to preserve privacy.
- Building big data clean rooms for ID matching as part of multi-party computation in industries like retail with digital advertising.
- Building confidential computing Zero Trust landing zones to meet privacy regulations for application migrations to cloud.

## Considerations

The following are considerations with this preview of Confidential Containers:

* An increase in pod startup time compared to runc pods and kernel-isolated pods.
* Version 1 container images aren't supported.
* Ephemeral containers and other troubleshooting methods like `exec` into a container, log outputs from containers, and `stdio` require a policy modification and redeployment to enable ExecProcessRequest, ReadStreamRequest, WriteStreamRequest, and CloseStdinRequest.
* Due to container image layer measurements being encoded in the security policy, we don't recommend using the `latest` tag when specifying containers.
* Services, Load Balancers, and EndpointSlices only support the TCP protocol.
* The policy generator only supports pods that use IPv4 addresses.
* Pod environment variables based on ConfigMaps and Secrets can't be changed after the pod is deployed.
* Pod termination logs aren't supported. While pods write termination logs to `/dev/termination-log` or to a custom location if specified in the pod manifest, the host/kubelet can't read those logs. Changes from the pod to that file aren't reflected on the host.
* Confidential Containers currently only supports Azure Linux.

## Resource allocation overview

It's important you understand the memory and processor resource allocation behavior in this release.

* CPU: The shim assigns one vCPU to the base OS inside the pod. If no resource `limits` are specified, the workloads don't have separate CPU shares assigned, the vCPU is then shared with that workload. If CPU limits are specified, CPU shares are explicitly allocated for workloads.
* Memory: The Kata-CC handler uses 2 GB memory for the UVM OS and X MB additional memory where X is the resource `limits` if specified in the YAML manifest (resulting in a 2-GB VM when no limit is given, without implicit memory for containers). The [Kata][kata-technical-documentation] handler uses 256 MB base memory for the UVM OS and X MB additional memory when resource `limits` are specified in the YAML manifest. If limits are unspecified, an implicit limit of 1,792 MB is added resulting in a 2 GB VM and 1,792 MB implicit memory for containers.

In this release, specifying resource requests in the pod manifests isn't supported. containerd doesn't pass the requests to the Kata Shim, and as a result, reserving resources based on the pod manifest resource requests is not implemented. Use resource `limits` instead of resource `requests` to allocate memory or CPU resources for workloads or containers.

With the local container filesystem backed by VM memory, writing to the container filesystem (including logging) can fill up the available memory provided to the pod. This condition can result in potential pod crashes.

## Next steps

* See the overview of [Confidential Containers security policy][confidential-containers-security-policy] to learn about how workloads and their data in a pod is protected.
* [Deploy Confidential Containers on AKS][deploy-confidential-containers-default-aks] with an automatically generated security policy.
* Learn more about [Azure Dedicated hosts][azure-dedicated-hosts] for nodes with your AKS cluster to use hardware isolation and control over Azure platform maintenance events.

<!-- EXTERNAL LINKS -->
[kata-technical-documentation]: https://katacontainers.io/docs/
[aks-issues]: https://github.com/Azure/AKS/issues
[oss-cc]: https://github.com/confidential-containers

<!-- INTERNAL LINKS -->
[pod-sandboxing-overview]: use-pod-sandboxing.md
[azure-dedicated-hosts]: /azure/virtual-machines/dedicated-hosts
[deploy-confidential-containers-default-aks]: deploy-confidential-containers-default-policy.md
[confidential-containers-security-policy]: /azure/confidential-computing/confidential-containers-aks-security-policy
[use-confidential-vms]: /azure/confidential-computing/confidential-node-pool-aks
[intel-sgx-confidential-nodes]: /azure/confidential-computing/confidential-nodes-aks-overview
[aci-confidential-containers]: /azure/confidential-computing/confidential-containers
[aci-virtual-nodes]: /azure/container-instances/container-instances-virtual-nodes
[aro-confidential-containers]: /azure/openshift/confidential-containers-overview

