---
title: Pod sandboxing with Azure Kubernetes Service (AKS)
description: Learn how to deploy Pod sandboxing on an Azure Kubernetes Service (AKS) cluster to isolate workloads in lightweight pod virtual machines (VMs) for stronger compute isolation.
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli, build-2023
ms.date: 09/17/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a cloud administrator, I want to implement Pod sandboxing on an Azure Kubernetes Service cluster, so that I can enhance the security of container workloads by isolating them from untrusted or potentially malicious code/workloads.
---

# Pod sandboxing with Azure Kubernetes Service (AKS)

Pod sandboxing on AKS uses Kata Containers to run each sandboxed pod in a lightweight virtual machine (VM) with its own guest kernel. This compute boundary isolates the workload from the host kernel and workloads in other pod VMs. To learn about the architecture, benefits, and use cases, see [Overview of Pod sandboxing in Azure Kubernetes Service (AKS)][pod-sandboxing-overview].

In this article, you deploy Pod sandboxing on a new or existing Azure Linux AKS cluster, deploy an application with the Kata runtime, and optionally verify kernel isolation.

## Prerequisites

- The Azure CLI version 2.80.0 or later. Run `az --version` to find the version of your Azure CLI, and run `az upgrade` to upgrade. For more details, see the steps at [Install Azure CLI][install-azure-cli].
- AKS supports Pod sandboxing on Kubernetes version 1.27.0 and higher.
- To manage a Kubernetes cluster, use the Kubernetes command-line client [`kubectl`][kubectl]. Azure Cloud Shell comes with `kubectl`. You can install `kubectl` locally using the [`az aks install-cli`][az-aks-install-cmd] command.
- The `Microsoft.Network/AllowBringYourOwnPublicIpAddress` feature must be registered in your subscription. This feature is required for Pod sandboxing workloads that use the Kata runtime.

### Register the `Microsoft.Network/AllowBringYourOwnPublicIpAddress` feature

1. Register the `Microsoft.Network/AllowBringYourOwnPublicIpAddress` feature in your subscription by using the [`az feature register`][az-feature-register] command. Registration can take several minutes.

    ```azurecli-interactive
    az feature register --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress
    ```

1. Verify that the registration state is `Registered` by using the [`az feature show`][az-feature-show] command before you deploy Pod sandboxing.

    ```azurecli-interactive
    az feature show --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress --query properties.state --output tsv
    ```

1. After the feature is registered, refresh the `Microsoft.Network` resource provider registration by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.Network
    ```

## Limitations

The following constraints apply to Pod sandboxing:

- Kata containers might not reach the IOPS performance limits that traditional containers can reach on Azure Files and high-performance local SSD.
- [Microsoft Defender for Containers][defender-for-containers] doesn't support assessing Kata runtime pods.
- [Kata][kata-network-limitations] host-network access isn't supported. You can't directly access the host networking configuration from within the VM.
- CPU and memory allocation with Pod sandboxing differs from `runc`. Each Kata pod runs in a pod VM whose fixed memory size is based on the pod memory limit, or defaults to 512Mi if you don't specify a limit. CPU limits determine the pod VM's vCPU allocation, and fractional limits are rounded up to a whole vCPU for that allocation. For more information, see [Pod sandboxing considerations][kata-considerations].
- Pod sandboxing is supported only on Azure Linux. Ubuntu and Windows aren't supported. For more information, see [Azure Linux container host for AKS][azurelinux-cluster-config].
- You can't enable [Federal Information Processing Standard (FIPS)](./enable-fips-nodes.md) or [Trusted Launch](./use-trusted-launch.md) on a node pool that uses Pod sandboxing. For more information, see [Pod sandboxing considerations][kata-considerations].
- Arm64 architecture isn't supported on a node pool that uses Pod sandboxing.

## How it works

Pod sandboxing on AKS builds on top of the open-source [Kata Containers][kata-containers-overview] project. Kata Containers running on the Azure Linux container host for AKS provides VM-based isolation and a separate kernel for each pod. Pod sandboxing allows you to allocate resources for each pod and doesn't share them with other Kata Containers or namespace containers running on the same host.

The solution architecture is based on the following main components:

- The [Azure Linux container host for AKS][azurelinux-overview]
- Microsoft Hyper-V Hypervisor
- Open-source [Cloud-Hypervisor][cloud-hypervisor] Virtual Machine Monitor (VMM)
- Integration with [Kata Containers][kata-container] for the runtime

Deploying Pod sandboxing by using Kata Containers is similar to the standard `containerd` workflow to deploy containers. Clusters with Pod sandboxing enabled come with a specific runtime class that you can reference in a pod manifest (`runtimeClassName: kata-vm-isolation`). For more information about runtime class defaults and customization, see [Considerations for Pod sandboxing][kata-considerations].

To use this feature with a pod, the only difference is to add the **runtimeClassName**, `kata-vm-isolation` to the pod spec. When a pod uses the `kata-vm-isolation` runtimeClass, the hypervisor spins up a lightweight virtual machine with its own kernel, for the workload to operate in.

## Create a cluster with Pod sandboxing

Perform the following steps to deploy an Azure Linux AKS cluster using the Azure CLI.

1. Create an AKS cluster by running the [`az aks create`][az-aks-create] command with the following parameters:

   | Parameter | Required value | Notes |
   | --- | --- | --- |
   | `--workload-runtime` | `KataVmIsolation` | Enables Pod sandboxing on the node pool. |
   | `--os-sku` | `AzureLinux` | Pod sandboxing supports only the Azure Linux OS SKU. |
   | `--node-vm-size` | A generation 2 VM size that supports nested virtualization | For example, use a [Dsv3-series][dv3-series] VM size. |
   | `--node-count` | `3` | Creates three nodes for this example. Adjust the value for your workload. |

   The following example creates a cluster named _myAKSCluster_ with three nodes in _myResourceGroup_:

    ```azurecli-interactive
    az aks create \
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --os-sku AzureLinux \
        --workload-runtime KataVmIsolation \
        --node-vm-size Standard_D4s_v3 \
        --node-count 3 \
        --generate-ssh-keys
    ```

1. Run the following command to get access credentials for the Kubernetes cluster. Use the [`az aks get-credentials`][aks-get-credentials] command and replace the values for the cluster name and the resource group name.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

1. List all Pods in all namespaces by running the [`kubectl get pods`][kubectl-get-pods] command.

    ```bash
    kubectl get pods --all-namespaces
    ```

## Enable Pod sandboxing on an existing cluster

To use this feature with an existing AKS cluster, the following requirements must be met:

- The cluster runs Kubernetes version 1.27.0 or higher.

- Use the following command to enable Pod sandboxing by creating a node pool to host it.

1. Add a node pool to your AKS cluster by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the following parameters:

    | Parameter | Required value | Notes |
    | --- | --- | --- |
    | `--resource-group` | The resource group that contains the existing AKS cluster | For example, use `myResourceGroup`. |
    | `--cluster-name` | The name of the existing AKS cluster | For example, use `myAKSCluster`. |
    | `--name` | A unique node pool name | For example, use `nodepool2`. |
    | `--workload-runtime` | `KataVmIsolation` | Enables Pod sandboxing on the node pool. |
    | `--os-sku` | `AzureLinux` | Pod sandboxing supports only the Azure Linux OS SKU. |
    | `--node-vm-size` | A generation 2 VM size that supports nested virtualization | For example, use a [Dsv3-series][dv3-series] VM size. |
    | `--node-count` | `1` | Creates one node for this example. Adjust the value for your workload. |

   The following example adds a node pool to _myAKSCluster_ with one node in _nodepool2_ in the _myResourceGroup_:

    ```azurecli-interactive
    az aks nodepool add --cluster-name myAKSCluster --resource-group myResourceGroup --name nodepool2 --os-sku AzureLinux --workload-runtime KataVmIsolation --node-vm-size Standard_D4s_v3 --node-count 1
    ```

1. Run the [`az aks update`][az-aks-update] command to reconcile the cluster configuration so the cluster recognizes the new node pool with the `KataVmIsolation` workload runtime.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup
    ```

1. Verify that the cluster update completed successfully and that the Pod sandboxing node pool uses the expected workload runtime, OS SKU, and VM size.

    ```azurecli-interactive
    az aks show \
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --query provisioningState \
        --output tsv

    az aks nodepool show \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --name nodepool2 \
        --query "{workloadRuntime:workloadRuntime, osSKU:osSKU, vmSize:vmSize}" \
        --output table
    ```

    The cluster provisioning state should be `Succeeded`. The node pool output should show `KataVmIsolation`, `AzureLinux`, and the VM size you selected.

## Deploy applications using Pod sandboxing

By using Pod sandboxing, you can deploy a mix of standard pods that don't use the Kata runtime alongside Kata pods that use the runtime. A Kata pod specifies `runtimeClassName: kata-vm-isolation` in its pod specification.

The runtime class selects the Kata runtime, but you should also define scheduling constraints when you need workloads to run on a specific Pod sandboxing node pool. For example, use the built-in AKS node pool label in a `nodeSelector`. Replace `nodepool2` with the name of your Pod sandboxing node pool.

```yaml
spec:
  runtimeClassName: kata-vm-isolation
  nodeSelector:
    kubernetes.azure.com/agentpool: nodepool2
```

For stronger separation, you can taint the Pod sandboxing node pool and add a matching toleration to Kata workloads. A taint without a matching toleration prevents other workloads from scheduling on that node pool. For more information, see [Use node taints in an AKS cluster][use-node-taints].

### Deploy an application with the Kata runtime

To deploy a pod with the Kata runtime on your AKS cluster, perform the following steps.

1. Create a file named _kata-app.yaml_ to describe your kata pod, and then paste the following manifest.

    ```yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name: isolated-pod
    spec:
      runtimeClassName: kata-vm-isolation
      containers:
      - name: kata
        image: mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
        command: ["/bin/sh", "-ec", "while :; do echo '.'; sleep 5 ; done"]
    ```

    The pod spec value for `runtimeClassName` is `kata-vm-isolation`.

1. Deploy the Kubernetes pod by running the [`kubectl apply`][kubectl-apply] command and specify your *kata-app.yaml* file:

    ```bash
    kubectl apply -f kata-app.yaml
    ```

   The output of the command resembles the following example:

    ```output
    pod/isolated-pod created
    ```

## Verify kernel isolation (optional)

1. To compare the kernels of Kata and non-Kata pods, create a file named _normal-app.yaml_. The following manifest defines a standard pod without the Kata runtime:

  ```yaml
  kind: Pod
  apiVersion: v1
  metadata:
    name: normal-pod
  spec:
    containers:
    - name: non-kata
      image: mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
      command: ["/bin/sh", "-ec", "while :; do echo '.'; sleep 5 ; done"]
  ```

1. Deploy the standard pod by using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f normal-app.yaml
    ```

1. To access a container inside the AKS cluster, start a shell session by running the [`kubectl exec`][kubectl-exec] command. In this example, you're accessing the container inside _isolated-pod_.

    ```bash
    kubectl exec -it isolated-pod -- /bin/sh
    ```

   Kubectl connects to your cluster, runs `/bin/sh` inside the first container within `isolated-pod`, and forwards your terminal's input and output streams to the container's process. You can also start a shell session to the container hosting the non-Kata pod to see the differences.

1. After starting a shell session to the container from _isolated-pod_, run commands to verify that the _kata_ container is running in a pod sandbox. It has a different kernel version compared to the non-Kata container outside the sandbox.

   To see the kernel version run the following command:

    ```bash
    uname -r
    ```

   The following example resembles output from the pod sandbox kernel:

    ```output
    [user]/# uname -r
    6.6.96.mshv1
    ```

1. Start a shell session to the container from _normal-pod_ to verify the kernel output:

    ```bash
    kubectl exec -it normal-pod -- /bin/bash
    ```

   To see the kernel version run the following command:

    ```bash
    uname -r
    ```

   The following example resembles output from the VM that's running _normal-pod_, which is a different kernel than the Kata pod running within the pod sandbox:

    ```output
    6.6.100.mshv1-1.azl3
    ```

## Clean up resources

1. When you finish evaluating this feature, clean up resources you no longer need to avoid Azure charges. If you deployed a new cluster as part of your evaluation or testing, run the following [`az aks delete`][az-aks-delete] command to delete the AKS cluster.

    ```azurecli-interactive
    az aks delete --resource-group myResourceGroup --name myAKSCluster
    ```

1. If you deployed Pod sandboxing on an existing cluster, you can remove the pods using the [`kubectl delete pod`][kubectl-delete-pod] command.

    ```bash
    kubectl get pods
    kubectl delete pod <kata-pod-name>
    ```

1. To remove the Pod sandboxing compute resources, you can also delete the Kata node pool by using the [`az aks nodepool delete`][az-aks-nodepool-delete] command. Before deleting the node pool, ensure no workloads that you want to retain are running on it.

    ```azurecli-interactive
    az aks nodepool delete \
      --cluster-name myAKSCluster \
      --resource-group myResourceGroup \
      --name nodepool2
    ```

## Next steps

- Learn more about [Azure Dedicated hosts][azure-dedicated-hosts] for nodes with your AKS cluster to use hardware isolation and control over Azure platform maintenance events.
- To further explore Pod sandboxing isolation and explore workload scenarios, try out the [Pod sandboxing labs][kata-labs].

<!-- EXTERNAL LINKS -->
[kata-containers-overview]: https://katacontainers.io/
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[azurerm-azurelinux]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool#os_sku
[kubectl-get-pods]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-exec]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
[container-resource-manifest]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
[kubectl-delete-pod]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kata-network-limitations]: https://github.com/kata-containers/kata-containers/blob/main/docs/Limitations.md#host-network
[cloud-hypervisor]: https://www.cloudhypervisor.org
[kata-container]: https://katacontainers.io
[kata-labs]: https://azure-samples.github.io/aks-labs/docs/security/pod-sandboxing-on-aks

<!-- INTERNAL LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-deployment-group-create]: /cli/azure/deployment/group#az-deployment-group-create
[connect-to-aks-cluster-nodes]: node-access.md
[dv3-series]: /azure/virtual-machines/dv3-dsv3-series#dsv3-series
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[create-ssh-public-key-linux]: ../virtual-machines/linux/mac-create-ssh-keys.md
[az-aks-delete]: /cli/azure/aks#az-aks-delete
[cvm-on-aks]: use-cvm.md
[azure-dedicated-hosts]: use-azure-dedicated-hosts.md
[container-insights]: ../azure-monitor/containers/container-insights-overview.md
[defender-for-containers]: /azure/defender-for-cloud/defender-for-containers-introduction
[az-aks-install-cmd]: /cli/azure/aks#az-aks-install-cli
[pod-sandboxing-overview]: concepts-pod-sandboxing.md
[azurelinux-overview]: use-azure-linux.md
[csi-storage-driver]: csi-storage-drivers.md
[csi-secret-store driver]: csi-secrets-store-driver.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[azurelinux-cluster-config]: cluster-configuration.md#azure-linux-container-host-for-aks
[register-the-katavmisolationpreview-feature-flag]: #register-the-katavmisolationpreview-feature-flag
[kata-considerations]: considerations-pod-sandboxing.md
[use-node-taints]: use-node-taints.md
