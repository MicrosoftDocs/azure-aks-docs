---
title: Pod Sandboxing with Azure Kubernetes Service (AKS)
description: Learn about and deploy Pod Sandboxing on an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.subservice: aks-security
ms.custom: devx-track-azurecli, build-2023
ms.date: 11/18/2025
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: As a cloud administrator, I want to implement Pod Sandboxing on an Azure Kubernetes Service cluster, so that I can enhance the security of container workloads by isolating them from untrusted or potentially malicious code/workloads.
---


# Pod Sandboxing with Azure Kubernetes Service (AKS)

To help secure and protect your container workloads from untrusted or potentially malicious code, AKS now includes a mechanism called Pod Sandboxing. Pod Sandboxing provides an isolation boundary between the container application and the shared kernel and compute resources of the container host such as CPU, memory, and networking. Applications are spun up in isolated, lightweight pod virtual machines (VMs). Pod Sandboxing complements other security measures or data protection controls with your overall architecture to help you meet regulatory, industry, or governance compliance requirements for securing sensitive information.

This article helps you understand this new feature, and how to implement it.

## Prerequisites

- The Azure CLI version 2.44.1 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

- AKS supports Pod Sandboxing on Kubernetes version 1.27.0 and higher.

- To manage a Kubernetes cluster, use the Kubernetes command-line client [kubectl][kubectl]. Azure Cloud Shell comes with `kubectl`. You can install kubectl locally using the [az aks install-cli][az-aks-install-cmd] command.

## Limitations

The following are constraints applicable to Pod Sandboxing:

* Kata containers might not reach the IOPS performance limits that traditional containers can reach on Azure Files and high-performance local SSD.


* [Microsoft Defender for Containers][defender-for-containers] doesn't support assessing Kata runtime pods.

* [Kata][kata-network-limitations] host-network access isn't supported. It isn't possible to directly access the host networking configuration from within the VM.

* CPU and memory allocation with Pod Sandboxing has other considerations compared to `runc`. Reference the memory management sections in the [considerations page][kata-considerations].

## How it works

Pod Sandboxing on AKS builds on top of the open-source [Kata Containers][kata-containers-overview] project. Kata Containers running on the Azure Linux container host for AKS provides VM based isolation and a separate kernel for each pod. Pod Sandboxing allows users to allocate resources for each pod and doesn't share them with other Kata Containers or namespace containers running on the same host.

The solution architecture is based on the following main components:

* The [Azure Linux container host for AKS][azurelinux-overview]
* Microsoft Hyper-V Hypervisor
* Open-source [Cloud-Hypervisor][cloud-hypervisor] Virtual Machine Monitor (VMM)
* Integration with [Kata Container][kata-container] for the runtime

Deploying Pod Sandboxing using Kata Containers is similar to the standard `containerd` workflow to deploy containers. Clusters with Pod Sandboxing enabled come with a specific runtime class that can be referenced in a pod manifest (`runtimeClassName: kata-vm-isolation`).

To use this feature with a pod, the only difference is to add the **runtimeClassName**, `kata-vm-isolation` to the pod spec. When a pod uses the `kata-vm-isolation` runtimeClass, the hypervisor spins up a lightweight virtual machine with its own kernel, for the workload to operate in.

## Deploy new cluster

Perform the following steps to deploy an Azure Linux AKS cluster using the Azure CLI.

1. Create an AKS cluster using the [az aks create][az-aks-create] command and specifying the following parameters:

   * **--workload-runtime**: Specify *KataVmIsolation* to enable the Pod Sandboxing feature on the node pool. With this parameter, these other parameters should satisfy the following requirements. Otherwise, the command fails and reports an issue with the corresponding parameters.
    * **--os-sku**: *AzureLinux*. Only the Azure Linux os-sku supports this feature.
    * **--node-vm-size**: Any Azure VM size that is a generation 2 VM and supports nested virtualization works. For example, [Dsv3][dv3-series] VMs.

   The following example creates a cluster named *myAKSCluster* with one node in the *myResourceGroup*:

    ```azurecli-interactive
    az aks create
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --os-sku AzureLinux \
        --workload-runtime KataVmIsolation \
        --node-vm-size Standard_D4s_v3 \
        --node-count 3 \
        --generate-ssh-keys
    ```

1. Run the following command to get access credentials for the Kubernetes cluster. Use the [az aks get-credentials][aks-get-credentials] command and replace the values for the cluster name and the resource group name.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

1. List all Pods in all namespaces using the [kubectl get pods][kubectl-get-pods] command.

    ```bash
    kubectl get pods --all-namespaces
    ```

## Deploy to an existing cluster

To use this feature with an existing AKS cluster, the following requirements must be met:

* Verify the cluster is running Kubernetes version 1.27.0 and higher.

Use the following command to enable Pod Sandboxing by creating a node pool to host it.

1. Add a node pool to your AKS cluster using the [az aks nodepool add][az-aks-nodepool-add] command. Specify the following parameters:

   * **--resource-group**: Enter the name of an existing resource group to create the AKS cluster in.
   * **--cluster-name**: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
   * **--name**: Enter a unique name for your clusters node pool, such as *nodepool2*.
   * **--workload-runtime**: Specify *KataVmIsolation* to enable the Pod Sandboxing feature on the node pool. Along with the `--workload-runtime` parameter, these other parameters shall satisfy the following requirements. Otherwise, the command fails and reports an issue with the corresponding parameter.
     * **--os-sku**: *AzureLinux*. Only the Azure Linux os-sku supports this feature.
     * **--node-vm-size**: Any Azure VM size that is a generation 2 VM and supports nested virtualization works. For example, [Dsv3][dv3-series] VMs.

   The following example adds a node pool to *myAKSCluster* with one node in *nodepool2* in the *myResourceGroup*:

    ```azurecli-interactive
    az aks nodepool add --cluster-name myAKSCluster --resource-group myResourceGroup --name nodepool2 --os-sku AzureLinux --workload-runtime KataVmIsolation --node-vm-size Standard_D4s_v3
    ```

1. Run the [az aks update][az-aks-update] command to enable pod sandboxing on the cluster.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup
    ```
## Deploying your applications

With Pod Sandboxing, you can deploy a mix of "normal" pods that don't utilize the Kata runtime alongside Kata pods that do utilize the runtime. The main difference between the two, when deploying, lies in the fact that a Kata pod has the line `runtimeClassName: kata-vm-isolation` in its spec.

### Deploy an application with the Kata runtime

To deploy a pod with the Kata runtime on your AKS cluster, perform the following steps.

1. Create a file named *kata-app.yaml* to describe your kata pod, and then paste the following manifest.

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

   The value for **runtimeClassNameSpec** is `kata-vm-isolation`.

1. Deploy the Kubernetes pod by running the [kubectl apply][kubectl-apply] command and specify your *kata-app.yaml* file:

    ```bash
    kubectl apply -f kata-app.yaml
    ```

   The output of the command resembles the following example:

    ```output
    pod/isolated-pod created
    ```

## (Optional) Verify Kernel Isolation configuration

If you would like to verify the difference between the kernel of a Kata and non-Kata pod, you can spin up another workload that doesn't have the Kata runtime.

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

1. To access a container inside the AKS cluster, start a shell session by running the [kubectl exec][kubectl-exec] command. In this example, you're accessing the container inside *kata-pod*.

    ```bash
    kubectl exec -it isolated-pod -- /bin/sh
    ```

   Kubectl connects to your cluster, runs `/bin/sh` inside the first container within `isolated-pod`, and forwards your terminal's input and output streams to the container's process. You can also start a shell session to the container hosting the non-Kata pod to see the differences.

1. After starting a shell session to the container from *kata-pod*, you can run commands to verify that the *kata* container is running in a pod sandbox. Notice that it has a different kernel version compared to the non-Kata container outside the sandbox.

   To see the kernel version run the following command:

    ```bash
    uname -r
    ```

   The following example resembles output from the pod sandbox kernel:

    ```output
    [user]/# uname -r
    6.6.96.mshv1
    ```

1. Start a shell session to the container from *normal-pod* to verify the kernel output:

    ```bash
    kubectl exec -it normal-pod -- /bin/bash
    ```

   To see the kernel version run the following command:

    ```bash
    uname -r
    ```

   The following example resembles output from the VM that's running *normal-pod*, which is a different kernel than the Kata pod running within the pod sandbox:

    ```output
    6.6.100.mshv1-1.azl3
    ```

## Cleanup

When you're finished evaluating this feature, to avoid Azure charges, clean up your unnecessary resources. If you deployed a new cluster as part of your evaluation or testing, you can delete the cluster using the [az aks delete][az-aks-delete] command.

```azurecli-interactive
az aks delete --resource-group myResourceGroup --name myAKSCluster
```

If you deployed Pod Sandboxing on an existing cluster, you can remove the pods using the [kubectl delete pod][kubectl-delete-pod] command.

```bash
kubectl get pods
kubectl delete pod <kata-pod-name>
```

## Next steps

- Learn more about [Azure Dedicated hosts][azure-dedicated-hosts] for nodes with your AKS cluster to use hardware isolation and control over Azure platform maintenance events.
- To further explore Pod Sandboxing isolation and explore workload scenarios, try out the [Pod Sandboxing labs][kata-labs].

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
[install-azure-cli]: /cli/azure
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-deployment-group-create]: /cli/azure/deployment/group#az-deployment-group-create
[connect-to-aks-cluster-nodes]: node-access.md
[dv3-series]: /azure/virtual-machines/dv3-dsv3-series#dsv3-series
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[create-ssh-public-key-linux]: ../virtual-machines/linux/mac-create-ssh-keys.md
[az-aks-delete]: /cli/azure/aks#az-aks-delete
[cvm-on-aks]: use-cvm.md
[azure-dedicated-hosts]: use-azure-dedicated-hosts.md
[container-insights]: ../azure-monitor/containers/container-insights-overview.md
[defender-for-containers]: /azure/defender-for-cloud/defender-for-containers-introduction
[az-aks-install-cmd]: /cli/azure/aks#az-aks-install-cli
[azurelinux-overview]: use-azure-linux.md
[csi-storage-driver]: csi-storage-drivers.md
[csi-secret-store driver]: csi-secrets-store-driver.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[azurelinux-cluster-config]: cluster-configuration.md#azure-linux-container-host-for-aks
[register-the-katavmisolationpreview-feature-flag]: #register-the-katavmisolationpreview-feature-flag
[kata-considerations]: considerations-pod-sandboxing.md
