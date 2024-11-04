---
title: Deploy SpinKube to Azure Kubernetes Service (AKS) to run serverless WebAssembly (Wasm) workloads
description: Learn how to deploy the open-source stack SpinKube to Azure Kubernetes Service (AKS) to run serverless WebAssembly (Wasm) workload on Kubernetes.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 11/04/2024
author: ThorstenHans
ms.author: ThorstenHans
---

# Deploy SpinKube to Azure Kubernetes Service (AKS) to run serverless WebAssembly (Wasm) workloads

This article shows you how to deploy SpinKube to Azure Kubernetes Service (AKS) to run serverless WebAssembly (Wasm) workloads.

## Overview

[WebAssembly (Wasm)][wasm] is a binary format optimized for fast download and near-native execution speed. It runs in a sandbox isolated from the host computer provided by a Wasm runtime. By default, WebAssembly modules can't access resources, including sockets and environment variables, on the host outside of the sandbox unless they're explicitly allowed. The [WebAssembly System Interface (WASI)][wasi] standard defines a set of interfaces for Wasm runtimes to provide access to WebAssembly modules to the environment and resources outside the host using a capability-based security model.

[SpinKube][spinkube] is a open-source project that runs serverless Wasm workloads (Spin Apps) built with open-source [Spin][spin] in Kubernetes. In contrast to earlier Wasm runtimes for Kubernetes, SpinKube executes Spin Apps natively on the underlying Kubernetes nodes and doesn't rely on containers. Spin Apps are regular Wasm modules that align with the [WebAssembly Component Model][wasm-component-model] specification.

By running Spin Apps on Kubernetes with SpinKube, you can achieve the following:

* Run Wasm workloads next to existing containerized applications.
* Run similar workloads while consuming fewer resources.
* Run more workloads on a given set of resources.
* Run workloads on different architectures (e.g. `amd64` and `arm64`) without cross-compiling them.

SpinKube consists of two top-level components:

* **`spin-operator`**: A Kubernetes operator allowing the deployment and management of Spin Apps by using custom resources.
* **`kube` plugin for `spin`**: A `spin` CLI plugin allowing users to scaffold Kubernetes deployment manifests for Spin Apps.

## Prerequisites

* Azure CLI version `2.64.0` or later. To install or upgrade, see [Install the Azure CLI][install-azure-cli].
* [`kubectl`][kubectl] version `1.31.0` or later.
* [`helm`][helm] version `3.15.4` or later.
* [`spin`][spin-cli] version `2.7.0` or later.
* [Node.js][node-js] version `21.6.2`.
* An existing AKS cluster. If you don't have one, see [Create an AKS cluster](./learn/quick-kubernetes-deploy-cli.md).

## Limitations

* The Kubernetes node `os-type` must be Linux.
* You can't use the Azure portal to deploy SpinKube to an AKS cluster.

## Deploy SpinKube to an existing cluster

### Connect to your AKS cluster

* Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --name <aks-cluster-name> --resource-group <resource-group-name>
    ```

### Deploy `cert-manager`

If you haven't deployed [`cert-manager`][cert-manager] to your AKS cluster yet, you can install it by deploying its Custom Resource Definitions (CRDs) followed by the `cert-manager` Helm chart provided through the `jetstack` repository.

1. Deploy the `cert-manager` CRDs and Helm chart using the `kubectl apply` command.

    ```bash
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml
    ```

1. Add and update the Jetstack repository using the `helm repo add` and `helm repo update` commands.

    ```bash
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    ```

1. Install the `cert-manager` Helm chart using the `helm install` command.

    ```bash
    helm install \
      cert-manager jetstack/cert-manager --version v1.14.3 \
      --namespace cert-manager --create-namespace \
      --wait
    ```

### Deploy `runtime-class-manager` (aka KWasm)

The `runtime-class-manager` (aka [KWasm][kwasm]) is responsible for deploying and managing [`containerd-shim`][containerd-shim] on the desired Kubernetes nodes.

1. Add the KWasm Helm repository using the `helm repo add` command.

    ```bash
    helm repo add kwasm http://kwasm.sh/kwasm-operator/
    ```

1. Install the KWasm operator using the `helm install` command.

    ```bash
    helm install \
      kwasm-operator kwasm/kwasm-operator \
      --namespace kwasm --create-namespace \
      --version 0.2.3 \
      --set kwasmOperator.installerImage=ghcr.io/spinkube/containerd-shim-spin/node-installer:v0.15.1
    ```

#### Provision containerd-shim-spin to Kubernetes nodes

Once `runtime-class-manager` is installed on your AKS cluster, you must annotate the Kubernetes nodes that should be able to run Spin Apps with `kwasm.sh/kwasm-node=true`. You can use `kubectl annotate node` to annotate all the nodes or only specific nodes in your AKS cluster. In this example, we annotate all nodes in the AKS cluster with the `kwasm.sh/kwasm-node=true` annotation.

1. Provision `containerd-shim-spin` to all nodes in the AKS cluster using the `kubectl annotate node --all` command.

    ```bash
    kubectl annotate node --all kwasm.sh/kwasm-node=true
    ```

1. After annotating the Kubernetes nodes, `runtime-class-manager` uses a Kubernetes *Job* to modify the desired nodes. After successful deployment of `containerd-shim-spin`, the nodes are labeled with a `kwasm.sh/kwasm-provisioned` label. You can check if the desired nodes have the `kwasm.sh/kwasm-provisioned` label assigned using the `kubectl get nodes --show-labels` command.

    ```bash
    kubectl get nodes --show-labels
    ```

### Deploy the `spin-operator`

The `spin-operator` consists of two Custom Resource Definitions (CRDs) that you need to deploy to your AKS cluster: the RuntimeClass for `spin` and a `SpinAppExecutor`.

1. Deploy the CRDs and the RuntimeClass for `spin` using the `kubectl apply` command.

    ```bash
    kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.crds.yaml
    kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.runtime-class.yaml
    ```

1. Deploy the `spin-operator` using the `helm install` command.

    ```bash
    helm install spin-operator --version 0.2.0 \
      --namespace spin-operator --create-namespace \
      --wait oci://ghcr.io/spinkube/charts/spin-operator
    ```

1. Create a `SpinAppExecutor` in the default namespace using the `kubectl apply` command.

    ```bash
    kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.shim-executor.yaml
    ```

## Run a Spin App on AKS

In this section, you verify the SpinKube installation by creating a simple Spin App using the `spin` CLI and JavaScript.

### Create a new Spin App

1. Create a new Spin App using the `spin new` command with the `http-js` template.

    ```bash
    spin new -t http-js --accept-defaults hello-spinkube
    ```

1. Change to the `hello-spinkube` directory using the `cd` command.

    ```bash
    cd hello-spinkube
    ```

1. Install the dependencies using the `npm install` command.

    ```bash
    npm install
    ```

1. Use the `spin` CLI create a basic *Hello, World* application.

    ```bash
    spin build
    ```

### Create container registry and authenticate the `spin` CLI

1. Spin Apps are packaged as OCI artifacts and distributed via an OCI compliant registry like Azure Container Registry (ACR). Create a new ACR instance using the [`az acr create`][az-acr-create] command.

    ```azurecli-interactive
    az acr create --name <acr-name> --resource-group <resource-group-name> --location <location> --sku Basic --admin-enabled true
    ```

1. Get the ACR login server endpoint and the admin password using the [`az acr show`][az-acr-show] and [`az acr credential show`][az-acr-credential-show] commands.

    ```azurecli-interactive
    ACR_LOGIN_SERVER=$(az acr show -n <acr-name> -g <resource-group-name> --query 'loginServer' -otsv)
    ACR_PASSWORD=$(az acr credential show -n <acr-name> -g <resource-group-name> --query 'passwords[0].value' -otsv)
    ```

1. Authenticate your `spin` CLI using the `spin registry login` command.

    ```bash
    spin registry login -u $ACR_NAME -p $ACR_PASSWORD $ACR_LOGIN_SERVER
    ```

### Package, distribute, and deploy the Spin App

1. Now that the `spin` CLI is authenticated against the ACR instance, you can package and distribute the Spin App using the `spin registry push` command followed by an OCI artifact reference (which follows the `<your acr login server>/<repository-name>:<tag>` naming scheme).

    ```bash
    spin registry push $ACR_LOGIN_SERVER/hello-spinkube:0.0.1
    ```

1. Create a Kubernetes Secret of type `docker-registry` which will be referenced when deploying the Spin App to your AKS cluster using the `kubectl create secret` command. In this example, the secret is named `spinkube-on-aks`.

    ```bash
    kubectl create secret docker-registry spinkube-on-aks \
      --docker-server=$ACR_LOGIN_SERVER \
      --docker-username=$ACR_NAME\
      --docker-password $ACR_PASSWORD
    ```

1. Create the necessary Kubernetes deployment manifests using the `spin kube scaffold` command.

    ```bash
    spin kube scaffold --from $ACR_LOGIN_SERVER/hello-spinkube:0.0.1 -s spinkube-on-aks > spinapp.yaml
    ```

    The `spinapp.yaml` file contains a preconfigured instance of the `SpinApp` CRD, which should look like this:

    ```yaml
    apiVersion: core.spinoperator.dev/v1alpha1
    kind: SpinApp
    metadata:
      name: hello-spinkube
    spec:
      image: "<your acr name>.azurecr.io/hello-spinkube:0.0.1"
      executor: containerd-shim-spin
      replicas: 2
      imagePullSecrets:
        - name: spinkube-on-aks
    ```

1. Deploy the Spin App to the AKS cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f spinapp.yaml
    ```

### Explore the Spin App in AKS

### Retrieve the list of Spin Apps

* Retrieve the list of Spin Apps using the `kubectl get spinapps` command.

    ```bash
    kubectl get spinapps
    ```

    ```output
    NAME             READY   DESIRED   EXECUTOR
    hello-spinkube   2       2         containerd-shim-spin
    ```

### Retrieve the Kubernetes primitives created by the `spin-operator`

Upon deployment, the `spin-operator` creates underlying Kubernetes primitives such as a *Service*, a *Deployment* and corresponding *Pods*.

1. Retrieve the list of services using the `kubectl get service` command.

    ```bash
    kubectl get service
    ```

    ```output
    NAME             TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
    hello-spinkube   ClusterIP   10.43.35.78   <none>        80/TCP    24s
    ```

1. Retrieve the list of deployments using the `kubectl get deployment` command.

    ```bash
    kubectl get deployment
    ```

    ```output
    NAME             READY   UP-TO-DATE   AVAILABLE   AGE
    hello-spinkube   2/2     2            2           38s
    ```

1. Retrieve the list of pods using the `kubectl get pod` command.

    ```bash
    kubectl get pod
    ```

    ```output
    NAME                              READY   STATUS    RESTARTS   AGE
    hello-spinkube-5b8579448d-zmc6x   1/1     Running   0          51s
    hello-spinkube-5b8579448d-bhkp9   1/1     Running   0          51s
    ```

### Invoke the Spin App

To invoke the Spin App, you configure port-forwarding to the service provisioned by the `spin-operator` and use `curl` for sending HTTP requests.

1. Establish port forwarding to the `hello-spinkube` service using the `kubectl port-forward` command.

    ```bash
    kubectl port-forward svc/hello-spinkube 8080:80
    ```

    ```output
    Forwarding from 127.0.0.1:8080 -> 80
    Forwarding from [::1]:8080 -> 80
    ```

1. Open a new terminal instance and use the following `curl` command to send an HTTP request to `localhost:8080`.

    ```bash
    curl -iX GET localhost:8080
    ```

    ```output
    HTTP/1.1 200 OK
    content-type: text/plain
    content-length: 17
    date: Tue, 28 May 2024 08:55:50 GMT
    Hello from JS-SDK
    ```

## Clean up resources

1. Remove the Spin App from the AKS cluster using the `kubectl delete` command.

    ```bash
    kubectl delete spinapp hello-spinkube
    ```

1. Remove the docker-registry Secret (spinkube-on-aks) using the `kubectl delete secret` command.

    ```bash
    kubectl delete secret spinkube-on-aks
    ```

1. Remove the ACR instance you created as part of this tutorial using the [`az acr delete`][az-acr-delete] command.

    ```azurecli-interactive
    az acr delete --name <acr-name> --resource-group <resource-group-name> --yes
    ```

1. Remove the SpinKube components from the AKS cluster using the following commands.

    ```bash
    # Remove the spin-operator
    helm delete spin-operator --namespace spin-operator
    
    # Remove the SpinAppExecutor
    kubectl delete -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.shim-executor.yaml
    
    # Remove the RuntimeClass for Spin
    kubectl delete -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.runtime-class.yaml
    
    # Remove the SpinKube CRDs
    kubectl delete -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.crds.yaml
    
    # Remove runtime-class-manager (aka KWasm)
    helm delete kwasm-operator --namespace kwasm
    
    # Remove cert-manager Helm Release
    helm delete cert-manager --namespace cert-manager
    
    # Remove cert-manager CRDs
    kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml
    ```

## Next steps

In this article, you learned how to deploy SpinKube to Azure Kubernetes Service (AKS) to run serverless WebAssembly (Wasm) workloads. To deploy more workloads on AKS, see the following articles:

* [Deploy a MongoDB cluster on Azure Kubernetes Service (AKS)](./mongodb-overview.md)
* [Deploy a PostgreSQL database on Azure Kubernetes Service (AKS)](./postgresql-overview.md)

<!-- EXTERNAL LINKS -->
[wasm]: https://webassembly.org/
[wasi]: https://wasi.dev/
[spinkube]: https://spinkube.dev/
[spin]: https://spin.fermyon.dev/
[wasm-component-model]: https://github.com/WebAssembly/component-model
[kubectl]: https://kubernetes.io/docs/tasks/tools/
[helm]: https://helm.sh
[spin-cli]: https://developer.fermyon.com/spin/v2/install
[node-js]: https://nodejs.org/en
[kwasm]: https://kwasm.sh
[cert-manager]: https://cert-manager.io/
[containerd-shim]: https://github.com/containerd/containerd/blob/main/core/runtime/v2/README.md#runtime-shim
[run-wasi]: https://github.com/deislabs/runwasi
[wasmtime]: https://wasmtime.dev/

<!-- INTERNAL LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials