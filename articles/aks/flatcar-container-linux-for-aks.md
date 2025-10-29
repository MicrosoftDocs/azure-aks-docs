---
title: Flatcar Container Linux for Azure Kubernetes Service (AKS) (preview) overview
description: Learn about Flatcar Container Linux for Azure Kubernetes Service (AKS), including limitations, migration information, and resources to get started.
ms.topic: overview
ms.date: 10/16/2025
author: allyford
ms.author: allyford
ms.service: azure-kubernetes-service
# Customer intent: "As a cloud developer, I want to deploy and manage AKS clusters built using Flatcar Container Linux, so that I can ensure reliable and efficient container workloads with reduced maintenance and enhanced security across multiple cloud providers."
---

# Use Flatcar Container Linux for Azure Kubernetes Service (AKS) (preview)

Flatcar Container Linux for AKS is a Cloud Native Compute Foundation (CNCF) project that provides security, reliability, and cross-cloud capabilities. Flatcar Container Linux is available in preview as an OS option on AKS. You can deploy Flatcar Container Linux node pools in a new AKS cluster or add Flatcar Container Linux node pools to your existing clusters. To learn more about Flatcar Container Linux, see [Flatcar documentation][flatcar-docs].

## Flatcar Container Linux for AKS benefits

Flatcar is built with an immutable filesystem, and it eliminates configuration drift and prevents unauthorized changes, ensuring robust protection for your workloads across multiple cloud platforms. Designed for versatility, Flatcar enables cross-cloud deployment, empowering businesses to scale effortlessly and securely.

## Limitations

Flatcar Container Linux for AKS has the following limitations:

- [FIPS][fips] isn't supported with Flatcar Container Linux.
- [Trusted Launch][trusted-launch] isn't supported with Flatcar Container Linux.
- [Confidential VM sizes][cvm] aren't supported with Flatcar Container Linux.
- The `SecurityPatch` [node OS upgrade channel][automatic-upgrade-node] isn't supported with Flatcar Container Linux.
- During preview, AKS doesn't support in-place updates with Flatcar Container Linux.
- [Artifact Streaming][artifact-streaming] (preview) isn't supported with Flatcar Container Linux.
- [Generation 1 VMs][vm-support] aren't supported with Flatcar Container Linux, which means can't use VM sizes that only support Generation 1.
- [Pod Sandboxing (preview)][pod-sandboxing] isn't supported with Flatcar Container Linux.
- [Node auto-provisioning][NAP] isn't supported with Flatcar Container Linux.

> [!NOTE]
> If you have an existing cluster with any of the above features enabled, you might not be able to add a node pool using Flatcar Container Linux.

## Get started with Flatcar Container Linux for AKS

To get started using the Flatcar Container Linux for AKS, see the following resources:

- Deploy an Azure Kubernetes Service (AKS) cluster with Flatcar Container Linux for AKS (preview) using [Azure CLI][flatcar-deploy-cli]
- Deploy an Azure Kubernetes Service (AKS) cluster with Flatcar Container Linux for AKS (preview) using an [ARM template][flatcar-deploy-arm]
- Create an AKS cluster with a single Flatcar Container Linux for AKS (preview) node pool using [Azure CLI or an ARM template][create-node-pools]
- Add a Flatcar Container Linux for AKS (preview) node pool to an existing cluster using [Azure CLI or an ARM template][create-node-pools]


## OS migrations and upgrades with Flatcar Container Linux

AKS doesn't support in-place migrations from existing Linux clusters or node pools to Flatcar Container Linux clusters or node pools. To migrate existing workloads to Flatcar Container Linux for AKS, you need to recreate your node pools using `--ossku flatcar`.

Flatcar Container Linux for AKS releases weekly AKS node images. Versioning follows the AKS date-based format (for example: 202506.13.0). You can check the node images in the release notes and by using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command to view the `nodeImageVersion`. For example:

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <aks-cluster-name> --query '[].{name: name, nodeImageVersion: nodeImageVersion}'
    ```

Example output:

    ```output
    [
    {
        "name": "nodes",
        "nodeImageVersion": "AKSFlatcar-flatcargen2-202508.06.0"
    }
    ]
    ```

You can check the Flatcar version number (for example: Flatcar 4344.0.0) in the release notes and by using `kubectl get nodes` command. For example:

    ```bash
    kubectl get nodes -o wide
    ```

Example output:

    ```output
    NAME                            STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                             KERNEL-VERSION    CONTAINER-RUNTIME
    aks-nodes-16363508-vmss000000   Ready    <none>   2m33s   v1.32.6   10.224.0.4    <none>        Flatcar Container Linux by Kinvolk 4372.0.1 (Oklo)   6.12.35-flatcar   containerd://2.0.4
    ```

## Next steps

To learn more about Flatcar Container Linux, see the [Flatcar documentation][flatcar-docs].

<!-- LINKS - Internal -->
[azurelinux-doc]: /azure/azure-linux/intro-azure-linux
[azurelinux-capabilities]: /azure/azure-linux/intro-azure-linux#azure-linux-container-host-key-benefits
[azurelinux-cluster-config]: /azure/azure-linux/quickstart-azure-cli
[azurelinux-node-pool]: create-node-pools.md#add-an-azure-linux-node-pool
[ubuntu-to-azurelinux]: create-node-pools.md#migrate-ubuntu-nodes-to-azure-linux-nodes
[auto-upgrade-aks]: auto-upgrade-cluster.md
[kured]: node-updates-kured.md
[azurelinuxdocumentation]: /azure/azure-linux/intro-azure-linux
[fips]: ./enable-fips-nodes.md
[trusted-launch]: ./use-trusted-launch.md
[automatic-upgrade-node]: ./auto-upgrade-node-os-image.md
[use-nvidia-gpus]: ./use-nvidia-gpu.md
[artifact-streaming]: ./artifact-streaming.md
[vm-support]: ./aks-virtual-machine-sizes.md
[cvm]: ./use-cvm.md
[pod-sandboxing]: ./use-pod-sandboxing.md
[flatcar-deploy-cli]: ./learn/quick-flatcar-deploy-cli.md
[flatcar-deploy-arm]: ./learn/quick-flatcar-deploy-arm-template.md
[create-node-pools]: ./create-node-pools.md
[NAP]: ./node-autoprovision.md

<!-- LINKS - External -->
[flatcar-docs]: https://www.flatcar.org/