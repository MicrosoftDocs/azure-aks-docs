---
title: Create WebAssembly System Interface (WASI) node pools in Azure Kubernetes Service (AKS) to run your WebAssembly (Wasm) workload (preview)
description: Learn how to create a WebAssembly System Interface (WASI) node pool in Azure Kubernetes Service (AKS) to run your WebAssembly (Wasm) workload on Kubernetes.
ms.topic: article
ms.custom: devx-track-azurecli
ms.date: 05/17/2023
author: schaffererin
ms.author: schaffererin

---

# Create WebAssembly System Interface (WASI) node pools in Azure Kubernetes Service (AKS) to run your WebAssembly (Wasm) workload (preview)

[WebAssembly (Wasm)][wasm] is a binary format that is optimized for fast download and maximum execution speed in a Wasm runtime. A Wasm runtime is designed to run on a target architecture and execute Wasm components in a sandbox, isolated from the host computer, at near-native performance. By default, Wasm components can't access resources on the host outside of the sandbox unless it is explicitly allowed. For example, Wasm components can't communicate over sockets, receive or send HTTP traffic, or even to access things like environment variables without explicit approval. The [WebAssembly System Interface (WASI)][wasi] standard defines an API for Wasm runtimes to provide access to Wasm components to the environment and resources outside the host using a capabilities model.

> [!IMPORTANT]
> WASI nodepools now use [SpinKube containerd shim][containerd-shim-spin] to run Wasm workloads. Previously, AKS used [Krustlet][krustlet] to allow Wasm modules to be run on Kubernetes. If you are still using Krustlet-based WASI nodepools, you can migrate to containerd shims by creating a new WASI nodepool and migrating your workloads to the new nodepool.

## Before you begin

You must have the latest version of Azure CLI installed.

## Install the aks-preview Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

To install the aks-preview extension, run the following command:

```azurecli-interactive
az extension add --name aks-preview
```

Run the following command to update to the latest version of the extension released:

```azurecli-interactive
az extension update --name aks-preview
```

## Register the 'WasmNodePoolPreview' feature flag

Register the `WasmNodePoolPreview` feature flag by using the [az feature register][az-feature-register] command, as shown in the following example:

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "WasmNodePoolPreview"
```

It takes a few minutes for the status to show *Registered*. Verify the registration status by using the [az feature show][az-feature-show] command:

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "WasmNodePoolPreview"
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register][az-provider-register] command:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

## Limitations

* Currently, WASI Node Pools only support [Spin][spin] applications, which use the [Wasmtime][wasmtime] runtime and native Linux containers.
* The SpinKube operator is not supported on Wasm/WASI node pools.
* The Wasm/WASI node pools can't be used for system node pool.
* The *os-type* for Wasm/WASI node pools must be Linux.
* You can't use the Azure portal to create Wasm/WASI node pools.

## Add a Wasm/WASI node pool to an existing AKS Cluster

To add a Wasm/WASI node pool, use the [az aks nodepool add][az-aks-nodepool-add] command. The following example creates a WASI node pool named *mywasipool* with one node.

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name mywasipool \
    --node-count 1 \
    --workload-runtime WasmWasi
```

> [!NOTE]
> The default value for the *workload-runtime* parameter is *ocicontainer*. To create a node pool that runs container workloads, omit the *workload-runtime* parameter or set the value to *ocicontainer*.

Verify the *workloadRuntime* value using `az aks nodepool show`. For example:

```azurecli-interactive
az aks nodepool show -g myResourceGroup --cluster-name myAKSCluster -n mywasipool --query workloadRuntime
```

The following example output shows the *mywasipool* has the *workloadRuntime* type of *WasmWasi*.

```azurecli-interactive
az aks nodepool show -g myResourceGroup --cluster-name myAKSCluster -n mywasipool --query workloadRuntime
```
```output
"WasmWasi"
```

Configure `kubectl` to connect to your Kubernetes cluster using the [az aks get-credentials][az-aks-get-credentials] command. The following command:

```azurecli-interactive
az aks get-credentials -n myakscluster -g myresourcegroup
```

Use `kubectl get nodes` to display the nodes in your cluster.

```bash
kubectl get nodes -o wide
```
```output
NAME                                 STATUS   ROLES   AGE    VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-mywasipool-12456878-vmss000000   Ready    agent   123m   v1.23.12   <WASINODE_IP> <none>        Ubuntu 22.04.1 LTS   5.15.0-1020-azure   containerd://1.5.11+azure-2
aks-nodepool1-12456878-vmss000000    Ready    agent   133m   v1.23.12   <NODE_IP>     <none>        Ubuntu 22.04.1 LTS   5.15.0-1020-azure   containerd://1.5.11+azure-2
```

Use `kubectl describe node` to show the labels on a node in the WASI node pool. The following example shows the details of *aks-mywasipool-12456878-vmss000000*.

```bash
kubectl describe node aks-mywasipool-12456878-vmss000000
```
```output
Name:               aks-mywasipool-12456878-vmss000000
Roles:              agent
Labels:             agentpool=mywasipool
...
                    kubernetes.azure.com/wasmtime-spin-v2=true
...
```

## Running Wasm/WASI Workload

Create a file named *spin.yaml* with the following content:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wasm-spin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wasm-spin
  template:
    metadata:
      labels:
        app: wasm-spin
    spec:
      runtimeClassName: wasmtime-spin-v2
      containers:
        - name: spin-hello
          image: ghcr.io/spinkube/containerd-shim-spin/examples/spin-rust-hello:v0.15.1
          command: ["/"]
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 100m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: wasm-spin
spec:
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: wasm-spin
```

> [!NOTE]
> If you want to know more about how to develop Spin applications, see the [spin][spin] documentation.

Use `kubectl` to run your example deployment:

```bash
kubectl apply -f spin.yaml
```

Use `kubectl get svc` to get the external IP address of the service.

```bash
kubectl get svc
```
```output
NAME          TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)        AGE
kubernetes    ClusterIP      10.0.0.1       <none>         443/TCP        10m
wasm-spin     LoadBalancer   10.0.133.247   <EXTERNAL-IP>  80:30725/TCP   2m47s
```

Access the example application at `http://EXTERNAL-IP/hello`. The following example uses `curl`.

```output
curl http://EXTERNAL-IP/hello
Hello world from Spin!
```

> [!NOTE]
> If your request times out, use `kubectl get pods` and `kubectl describe pod <POD_NAME>` to check the status of the pod. If the pod is not running, use `kubectl get rs` and `kubectl describe rs <REPLICA_SET_NAME>` to see if the replica set is having issues creating a new pod.

## Clean up

To remove the example deployment, use `kubectl delete`.

```bash
kubectl delete -f spin.yaml
```

To remove the Wasm/WASI node pool, use `az aks nodepool delete`.

```azurecli-interactive
az aks nodepool delete --name mywasipool -g myresourcegroup --cluster-name myakscluster
```

## Supported runtime classes

The following RuntimeClass are supported on WASI node pools:

- wasmtime-spin-v2 (alias to wasmtime-spin-v0-15-1)
- wasmtime-spin-v1 (alias to wasmtime-spin-v0-8-0)
- wasmtime-spin-v0-15-1
- wasmtime-spin-v0-8-0
- wasmtime-spin-v0-5-1
- wasmtime-spin-v0-3-0

The suffix `-v0-15-1`, `-v0-8-0`, `-v0-5-1`, and `-v0-3-0` are the versions of the spin shim. You can find the supported versions of the spin shim in the following table:


| **shim version** | v0.15.1                                                                          | v0.8                                                                             | v0.5.1                                                                    | v0.3.0                                                                    |
| ---------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **[Spin](spin)**         | [v2.6.0](https://github.com/fermyon/spin/releases/tag/v2.6.0)                    | [v1.4.1](https://github.com/fermyon/spin/releases/tag/v1.4.1)                    | [v1.0.0](https://github.com/fermyon/spin/releases/tag/v1.0.0)             | [v0.4.0](https://github.com/fermyon/spin/releases/tag/v0.4.0)             |

<!-- EXTERNAL LINKS -->
[krustlet]: https://krustlet.dev/
[wasm]: https://webassembly.org/
[wasi]: https://wasi.dev/
[containerd-shim-spin]: https://github.com/spinkube/containerd-shim-spin
[spin]: https://spin.fermyon.dev/
[wasmtime]: https://wasmtime.dev/
<!-- INTERNAL LINKS -->

[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register

