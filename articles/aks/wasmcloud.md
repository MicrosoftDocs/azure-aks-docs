---
title: Deploy wasmCloud to Azure Kubernetes Service (AKS) to run distributed WebAssembly (Wasm) workloads
description: Learn how to deploy and use wasmCloud on an Azure Kubernetes Service (AKS) cluster to deploy distributed WebAssembly applications.
author: protochron
ms.topic: article
ms.date: 11/07/2024
---

# Use wasmCloud on Azure Kubernetes Service (AKS)
[WebAssembly](https://webassembly.org/) components are a new way to build and deploy applications. They are designed to be a portable compilation target for programming languages and can run in a variety of environments. WebAssembly components are sandboxed by design and expose their functionality using defined interfaces. Components differ from containers in that they single binaries that are much smaller and faster to start. The full description of the model and what a component is can be found in the [specification](https://github.com/WebAssembly/component-model).

[wasmCloud][wasmcloud] is a CNCF project designed to fast-track the development, deployment and orchestration of WebAssembly components. This document details instructions on how to deploy wasmCloud on an Azure Kubernetes Service (AKS) cluster.

## Before you begin

* This article assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)](./concepts-clusters-workloads.md).
* You need an active Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/) before you begin.
* You need an AKS cluster. If you don't have an existing cluster, you can create one using the [Azure CLI](./learn/quick-kubernetes-deploy-cli.md), [Azure PowerShell](./learn/quick-kubernetes-deploy-powershell.md), or [Azure portal](./learn/quick-kubernetes-deploy-portal.md).
* You need to install the wasmCloud CLI (wash) at version 0.39.0 or later. For installation options, see [wasmcloud-cli][wasmcloud-cli].

## Prerequisites

* You can't use the Azure portal to deploy wasmCloud to an AKS cluster.

## Deploy wasmCloud

To deploy wasmCloud on an AKS cluster, you will need to install the all in one Helm chart into your cluster. This installs the following services into a single namespace:
* [NATS]: NATS provides the backbone for all communication between components in wasmCloud.
* [wadm] -- the wasmCloud Application Manager, otherwise known as wadm is the orchestrator for managing applications running on top of wasmCloud.
* [the wasmCloud Operator][wasmcloud-operator] -- the wasmCloud Operator is a Kubernetes operator that manages the lifecycle of wasmCloud hosts.

We recommend deploying wasmCloud into a dedicated Kubernetes namespace.

1.  Create a namespace for wasmCloud using `kubectl`:

    ```
    kubectl create namespace wasmcloud
    ```
2. Install NATS and wadm into the wasmCloud namespace using the `helm upgrade` command:

    ```azurecli-interactive
    # By default, the chart installs NATS, Wadm, and wasmCloud Operator subcharts
     helm upgrade --install \
          wasmcloud-platform \
          --values https://raw.githubusercontent.com/wasmCloud/wasmcloud/main/charts/wasmcloud-platform/values.yaml \
          oci://ghcr.io/wasmcloud/charts/wasmcloud-platform:0.1.2 \
          --dependency-update
    ```
    The output from this command should look similar to the following:

    ```output
    NAME: wasmcloud-platform
    LAST DEPLOYED: Thu Nov  7 14:58:54 2024
    NAMESPACE: default
    STATUS: deployed
    REVISION: 1
    NOTES:
    ```

3. Wait for all of the pods to start using `kubectl`:

   ```azurecli-interactive
   kubectl rollout status deploy,sts -l app.kubernetes.io/name=nats
   kubectl wait --for=condition=available --timeout=600s deploy -l app.kubernetes.io/name=wadm
   kubectl wait --for=condition=available --timeout=600s deploy -l app.kubernetes.io/name=wasmcloud-operator
   ```

4. Start a wasmCloud host using a CRD and `kubectl`:

    ```azurecli-interactive
    cat << EOF | kubectl apply -f -
    apiVersion: k8s.wasmcloud.dev/v1alpha1
    kind: WasmCloudHostConfig
    metadata:
      name: wasmcloud-host
    spec:
      lattice: default
      version: "1.4.1"
    EOF

    ```
5. Verify that the wasmCloud host is running:

    ```azurecli-interactive
    kubectl get pod -l app.kubernetes.io/instance=wasmcloud-host
    ```

    Your output should look similar to the following:

    ```output
    NAME                             READY   STATUS    RESTARTS   AGE
wasmcloud-host-f9d67b8cf-lvsq6   2/2     Running   0          84s
    ```

6. Verify that you can connect to the wasmCloud host using `wash`:


    In a separate shell use run the following command to port forward to one of the running NATS pods:

    ```azurecli-interactive
    kubectl port-forward nats-0 4222
    ```
    This forwards all traffic on port 4222 locally to the NATS pod running in your cluster. You must have this port forwarded in order to connect to wasmCloud using `wash`.

    In your original shell, run the following command with `wash` to verify that your wasmCloud host is running:

    ```azurecli-interactive
    wash get hosts
    ```

    Your output should look similar to the following:

    ```output
      Host ID                                                      Friendly name           Uptime (seconds)
  ND2G4FRXLBCV3YL52OD4NRSS66Z5YOR3JOSL3Q7T5I6ZJM4EII3Y73CZ     frosty-resonance-6227   312
    ```

## Deploy a wasmCloud application

Now that you have wasmCloud running on your AKS cluster, you can deploy a wasmCloud application. A wasmCloud application is a collection of WebAssembly components that are orchestrated by the wasmCloud Application Manager (wadm).

1. Create a wasmCloud application manifest file. This file describes compoents that comprise your application. Save the following yaml file as `hello-world.yaml`.

    ```yaml
    apiVersion: core.oam.dev/v1beta1
    kind: Application
    metadata:
      name: hello-world
      annotations:
        description: 'HTTP hello world demo in Rust, using the WebAssembly Component Model and WebAssembly Interfaces Types (WIT)'
    spec:
      components:
        - name: http-component
          type: component
          properties:
            image: ghcr.io/wasmcloud/components/http-hello-world-rust:0.1.0
          traits:
            # Govern the spread/scheduling of the component
            - type: spreadscaler
              properties:
                instances: 1

        # Add a capability provider that enables HTTP access
        - name: httpserver
          type: capability
          properties:
            image: ghcr.io/wasmcloud/http-server:0.23.2
          traits:
            # Establish a unidirectional link from this http server provider (the "source")
            # to the `http-component` component (the "target") so the component can handle incoming HTTP requests,
            #
            # The source (this provider) is configured such that the HTTP server listens on 0.0.0.0:8080
            - type: link
              properties:
                target: http-component
                namespace: wasi
                package: http
                interfaces: [incoming-handler]
                source_config:
                  - name: default-http
                    properties:
                      address: 0.0.0.0:8080
    ```

2. Deploy the wasmCloud application using `wash`:

    ```azurecli-interactive
    wash app deploy hello-world.yaml
    ```

    Your output should look similar to the following:
    ```output
    Deployed application "hello-world", version "01JC44TVDBC2V6MJ1NJTKNNX1J"
    ```
3. Verify that the application is running using `wash`:

    ```azurecli-interactive
    wash app status hello-world
    ```

    Your output should look similar to the following:

    ```output
    Name                                         Kind           Status
    http_component                               SpreadScaler   Deployed
    httpserver -(wasi:http)-> http_component     LinkScaler     Deployed
    httpserver                                   SpreadScaler   Deployed
    ```

    Repeat this command if necessary until all components are in the `Deployed` state.

4. Invoke the http component using `curl` and `kubectl port-forward`:

    In a separate shell, run the following command to port forward to the `hello-world` application

    ```azurecli-interactive
    kubectl port-forward port-forward deployment/wasmcloud-host 8080
    ```

    This forwards all traffic on port 8080 locally to the wasmCloud host running in your cluster. You must have this port forwarded in order to connect to wasmCloud using `curl`.

    In your original shell, run the following command to invoke the http component:

    ```azurecli-interactive
    curl http://localhost:8080
    ```

    Your output should look similar to the following:

    ```output
    Hello from Rust!
    ```
5. Clean up the installed resources

    To clean up the resources you created, run the following commands:

    ```azurecli-interactive
    kubectl delete namespace wasmcloud
    ```

    This removes the wasmCloud components from your AKS cluster.

## Next steps
You can continue to learn by following the [wasmCloud Quickstart Guide][wasmcloud-quickstart], which walks you though creating a WebAssembly component from scratch, using using different wasmCloud capabilities and scaling your application.

<!--- LINKS - external --->
[wasmcloud]: https://wasmcloud.com/
[wasmcloud-cli]: https://wasmcloud.com/docs/installation
[nats]: https://nats.io/
[wadm]: https://wasmcloud.com/docs/ecosystem/wadm/
[wasmcloud-operator]: https://wasmcloud.com/docs/deployment/k8s/
[wasmcloud-quickstart]: https://wasmcloud.com/docs/tour/hello-world
