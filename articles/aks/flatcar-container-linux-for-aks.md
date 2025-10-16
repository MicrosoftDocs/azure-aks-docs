---

title: Use Flatcar Container Linux for Azure Kubernetes Service (AKS) (preview)
description: Learn how to use Flatcar Container Linux for Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.date: 10/16/2025
author: allyford
ms.author: allyford

# Customer intent: "As a cloud developer, I want to deploy and manage AKS clusters built using Flatcar Container Linux, so that I can ensure reliable and efficient container workloads with reduced maintenance and enhanced security across multiple cloud providers."
---

# Use Flatcar Container Linux for Azure Kubernetes Service (AKS) (preview)

Flatcar Container Linux for AKS is a Cloud Native Compute Foundation (CNCF) project that provides security, reliability, and cross-cloud capabilities. Flatcar Container Linux is available as an OS option on AKS in preview. You can deploy Flatcar Container Linux node pools in a new AKS cluster or add Flatcar Container Linux node pools to your existing clusters. To learn more about Flatcar Container Linux, see [Flatcar documentation][flatcar-docs].

## Why use Flatcar Container Linux for AKS

Built with an immutable filesystem, Flatcar eliminates configuration drift and prevents unauthorized changes, ensuring robust protection for your workloads across multiple cloud platforms. Designed for versatility, Flatcar enables cross-cloud deployment, empowering businesses to scale effortlessly and securely.

## How to use Flatcar Container Linux for AKS

To get started using the Flatcar Container Linux for AKS, see:

* Creating a cluster with Flatcar Container Linux
* Add a node pool with Flatcar Container Linux to your existing cluster

## Limitations

Flatcar Container Linux for AKS does not support the following configurations:

* [FIPS][fips] is not supported with Flatcar Container Linux
* [Trusted Launch][trusted-launch] is not supported with Flatcar Container Linux
* [Confidential VM sizes][cvm] are not supported using Flatcar Container Linux
* [Node OS Upgrade Channel][automatic-upgrade-node], `SecurityPatch` is not supported with Flatcar Container Linux
* During preview, AKS will not support in-place updates with Flatcar Container Linux
* [Artifact Streaming][artifact-streaming] (preview) is not supported with Flatcar Container Linux
* [Generation 1 VMs][vm-support] are not supported for Flatcar Container Linux. This means that you will not be able to use VM sizes that only support Generation 1.
* [Pod Sandboxing (preview)][pod-sandboxing] is not supported for Flatcar Container Linux

> [!NOTE]
> If you have an existing cluster with any of the above features enabled, you may not be able to add a node pool using Flatcar Container Linux.

## OS Migrations and upgrades

AKS does not support in-place migrations from existing Linux clusters or node pools to Flatcar Container Linux clusters or node pools. To migrate existing workloads to Flatcar Container Linux for AKS, you'll need to re-create your node pools using `--ossku flatcar`.

Flatcar Container Linux for AKS will release weekly AKS node images. Versioning will follow AKS's date-based format (e.g., 202506.13.0). This will be visible in the release notes and by using `az aks nodepool list` to view the `nodeImageVersion`.

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <aks-cluster-name> --query '[].{name: name, nodeImageVersion: nodeImageVersion}'
    ```

    ```output
    [
    {
        "name": "nodes",
        "nodeImageVersion": "AKSFlatcar-flatcargen2-202508.06.0"
    }
    ]
    ```

The Flatcar version number (e.g., Flatcar 4344.0.0) will be visible in the release notes and by using `kubectl get nodes` command.

    ```bash
    kubectl get nodes -o wide
    ```

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

<!-- LINKS - External -->
[flatcar-docs]: https://www.flatcar.org/