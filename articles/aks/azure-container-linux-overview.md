---
title: Azure Container Linux (ACL) for AKS Overview
description: Learn about Azure Container Linux (ACL), an immutable, container-optimized operating system for Azure Kubernetes Service (AKS) that builds on Flatcar Container Linux while integrating Azure Linux packages and platform features.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.custom: linux-related-content
ms.topic: overview
ms.date: 04/28/2026
---

# What is Azure Container Linux (ACL) for Azure Kubernetes Service (AKS)?

In this article, we provide an overview of Azure Container Linux (ACL), an immutable, container-optimized operating system (OS) for Azure Kubernetes Service (AKS). ACL is derived from the Flatcar Container Linux project, building on Flatcar's proven, container-first immutable design while layering in Azure Linux packages, servicing, and platform integration. This allows ACL to stay closely aligned with upstream Flatcar innovation while meeting Azure's production, security, and compliance requirements. To learn more about Flatcar Container Linux, see the [Flatcar documentation](https://www.flatcar.org/).

ACL is generally available (GA) as an OS option on AKS starting AKS v1.34. You can deploy ACL node pools in a new AKS cluster or add ACL node pools to your existing clusters.

[!INCLUDE [os-guard-preview-retirement](includes/os-guard-preview-retirement.md)]

## Benefits of using ACL on AKS

ACL is a secure, minimal OS including only the critical components required to run containers and using an immutable design to preserve OS integrity and reduce node configuration drift.

| Benefit | Description |
| ------- | ----------- |
| **Layered OS security** | ACL combines an immutable OS, mandatory access controls, verified boot, and trusted build processes to protect nodes from boot through runtime. For details, see [ACL security features](./azure-container-linux-security-features.md). |
| **Minimal container host** | ACL includes only the components required to run containers, reducing OS complexity and simplifying node management. |
| **Consistent node servicing** | Weekly image-based updates provide security patches and bug fixes while keeping the OS version consistent across each node image. |
| **Open-source transparency** | Flatcar as well as many of the underlying technologies (dm-verity and SELinux) are upstream or open source, and Microsoft has tooling and contributions to support these features. |

## Capabilities and compatibility

ACL supports the following AKS capabilities:

- **NVIDIA GPU node support**: ACL supports NVIDIA GPU-enabled node pools on AMD64 architectures, allowing you to run high-performance computing (HPC) and AI/ML workloads on AKS with a hardened, container-optimized OS. ACL doesn't support ARM64 architectures for GPU-enabled node pools.
- **FIPS**: ACL support FIPS enabled node pools.
- **AMD64 and ARM64 architecture support**: ACL is available for both AMD64 and ARM64 architectures on AKS.
- **[Node auto-provisioning](/azure/aks/node-auto-provisioning)**: ACL supports node auto-provisioning (NAP).
- **[Confidential VM](/azure/aks/use-cvm)**: ACL is available as a confidential VM (CVM) image for AKS, with a FIPS-enabled option.

## Unsupported features

ACL currently doesn't support the following features:

- The `SecurityPatch` and `Unmanaged` [node OS upgrade channels](/azure/aks/auto-upgrade-node-os-image).
- [Generation 1 VMs](/azure/aks/aks-virtual-machine-sizes): You can't use VM sizes that only support Generation 1 with ACL.
- [Pod Sandboxing](/azure/aks/use-pod-sandboxing).
- A non-Trusted Launch variant. ACL requires Trusted Launch.

If your existing cluster uses any of the unsupported features, you might not be able to add an ACL node pool to that cluster.

## Feature roadmap

Azure Linux publishes a [feature roadmap](https://github.com/orgs/microsoft/projects/970/views/2) that contains features that are in development and available for general availability (GA) and public preview.

## OS migrations and upgrades with ACL

AKS supports migrating existing node pools to ACL using in-place OS SKU migration or by creating new ACL node pools. For detailed migration steps, considerations, and rollback instructions, see [Migrate existing nodes to ACL](./migrate-nodes-azure-container-linux.md).

## ACL for AKS versioning

ACL for AKS releases weekly AKS node images. Versioning follows the AKS date-based format (for example: 202506.13.0). ACL currently only supports full node image updates. For more information, see [Azure Container Linux (ACL) node images](./node-images.md#azure-container-linux-acl-node-images).

You can check available node images in the release notes and view the `nodeImageVersion` for a running cluster using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command. For example:

```azurecli-interactive
az aks nodepool list --resource-group <resource-group-name> --cluster-name <aks-cluster-name> --query '[].{name: name, nodeImageVersion: nodeImageVersion}'
```

Example output:

```output
[
{
    "name": "nodes",
    "nodeImageVersion": "AKSAzureContainerLinux-202606.01.0"
}
]
```

## Related content

To get started using ACL for AKS, see the following resources:

- [Deploy an ACL cluster using the Azure CLI](./learn/quick-azure-container-linux-deploy-cli.md)
- [Deploy an ACL cluster using an ARM template](./learn/quick-azure-container-linux-deploy-arm-template.md)
- [Add an ACL node pool to an existing cluster](create-node-pools.md#add-a-second-node-pool-using-the-azure-cli)
- [Migrate existing nodes to ACL](./migrate-nodes-azure-container-linux.md)
