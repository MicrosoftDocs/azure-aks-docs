---
title: Use Telepresence to debug microservices on AKS
description: Learn how to use Telepresence to debug microservices on AKS
ms.topic: article
ms.custom: devx-track-azurecli
ms.subservice: aks-devx
ms.date: 10/23/2024
---

# Use Telepresence to debug microservices on AKS

[Telepresence] is a Cloud Native Computing Foundation Sandbox project created by the team at Ambassador Labs. It allows developers to run services locally on their development machine while still connecting to a remote Kubernetes cluster. This setup makes it easier to develop, debug, and test applications that interact with other services in the cluster without having to redeploy or rebuild the entire application in Kubernetes every time changes are made.

> [!NOTE]
> Telepresence is an open-source CNCF project. Microsoft does **not** offer support if you run into troubles using Telepresence. If you run into issues using Telepresence, visit their official [Telepresence GitHub issue page] and open an issue.


# How Telepresence works

Telepresence essentially swaps out a pod in your Kubernetes cluster with a proxy pod. This proxy pod reroutes network traffic from the Kubernetes cluster to your local machine, where you have your development environment set up. The process involves:

- Connecting to your Kubernetes cluster with Telepresence.
- Specifying the service or deployment you want to intercept.
- Running the local version of the service, which Telepresence connects to the cluster through the proxy pod.


# Using Telepresence with a sample app running on an AKS cluster

## Prerequisites

- An AKS cluster. If you don't know how to create a cluster, please follow [aks-tutorial-deploy-cluster].
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and on the path in a command-line environment of your choice
- An application to deploy. In this tutorial we will be using the [aks-store-demo app].
- [Telepresence] installed


## Connect to the cluster

To install Telepresence and to interact with your AKS cluster, it is important to make sure you are connected. To manage a Kubernetes cluster, use the Kubernetes command-line client, [kubectl][kubectl]. `kubectl` is already installed if you use Azure Cloud Shell. To install `kubectl` locally, use the [`az aks install-cli`][az-aks-install-cli] command.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [az aks get-credentials][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME
    ```

1. Verify the connection to your cluster using the [kubectl get][kubectl-get] command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl get nodes
    ```

## Clone the sample app and deploy it your AKS cluster

The [aks-store-demo app] used in this tutorial is a basic store front app including the following Kubernetes deployments and services:

:::image type="content" source="./media/container-service-kubernetes-tutorials/aks-store-architecture.png" alt-text="Screenshot of Azure Store sample architecture." lightbox="./media/container-service-kubernetes-tutorials/aks-store-architecture.png":::

* **Store front**: Web application for customers to view products and place orders.
* **Product service**: Shows product information.
* **Order service**: Places orders.
* **Rabbit MQ**: Message queue for an order queue.

### [Git](#tab/azure-cli)

1. Use [git] to clone the sample application to your development environment.

    ```console
    git clone https://github.com/Azure-Samples/aks-store-demo.git
    ```

2. Change into the cloned directory.

    ```console
    cd aks-store-demo
    ```

To deploy the app, run the following command

    ```console
    kubectl apply -f aks-store-quickstart.yaml
    ```

## Run the app locally 

As Telepresence allows developers to run services locally on their development machine while still connecting to their remote Kubernetes cluster, it is important to make sure your application is also running locally and not just in the cloud. To run the [aks-store-demo app] locally, run the following command.

    ```console
    docker compose up
    ```

## Install Telepresence

### Install the Telepresence Client

Telepresence can be installed on [GNU/Linux], [Mac], or [Windows]. Click your corresponding OS to visit the Telepresence documentation for installation instructions.

### Install the Telepresence traffic manager

To route cloud traffic to your local machine, Telepresence uses a traffic manager. Helm is used to deploy the traffic manager into your Kubernetes cluster.

    ```console
    telepresence helm install
    ```


### Intercept your services

To start using Telepresence in your AKS cluster, run the `telepresence connect` command.

    ```console
    telepresence connect
    ```

`telepresence connect` connects to your AKS cluster and connects to the Kubernetes API server. After running `telepresence connect` similar output should appear

    ```console
    Connected to context myAKSCluster, namespace default (https://myAKSCluster-dns-ck7w5t5h.hcp.eastus2.azmk8s.io:443)
    ```

Using the `telepresence list` command, you will be able to see all the services that can be interecepted.

    ```console
    telepresence list
    order-service  : ready to intercept (traffic-agent not yet installed)
    product-service: ready to intercept (traffic-agent not yet installed)
    rabbitmq       : ready to intercept (traffic-agent not yet installed)
    store-front    : ready to intercept (traffic-agent not yet installed)
    ```

To start intercepting traffic from a service in your AKS cluster, you first need to find the correct port. Running the `kubectl get service service-name --output yaml` command will help find you the port.

In the following example, we will run the command on the `store-front` service to find the appropriate port (port 80) to use in our intercepts.

    ```console
     kubectl get service store-front --output yaml
    apiVersion: v1
    kind: Service
    metadata:
      annotations:
        kubectl.kubernetes.io/last-applied-configuration: |
          {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"store-front","namespace":"default"},"spec":{"ports":[{"port":80,"targetPort":8080}],"selector":{"app":"store-front"},"type":"LoadBalancer"}}
      creationTimestamp: "2024-10-23T22:38:00Z"
      finalizers:
      - service.kubernetes.io/load-balancer-cleanup
      name: store-front
      namespace: default
      resourceVersion: "83731"
      uid: 20b989d7-57d0-4308-b686-4f1e68ca8477
    spec:
      allocateLoadBalancerNodePorts: true
      clusterIP: 10.0.190.29
      clusterIPs:
      - 10.0.190.29
      externalTrafficPolicy: Cluster
      internalTrafficPolicy: Cluster
      ipFamilies:
      - IPv4
      ipFamilyPolicy: SingleStack
      ports:
      - nodePort: 31654
        port: 80
        protocol: TCP
        targetPort: 8080
      selector:
        app: store-front
      sessionAffinity: None
      type: LoadBalancer
    status:
      loadBalancer:
        ingress:
        - ip: 135.224.138.68
    ```

To properly intercept traffic from your service in your AKS cluster, run the following command `$ telepresence intercept <service-name> --port <local-port>[:<remote-port>] --env-file <path-to-env-file>`.

The port field must have the local port and the remote-port, which is the port used in your AKS cluster.

The env-file field is the path where Telepresence will create an env file containing the appropriate environment variables needed to intercept traffic. This is **needed** to properly intercept your service's traffic to your local machine. If a file doesn't exist, telepresence will create it for you.

> [!NOTE]
> `sshfs` is required in order for volume mounts to work correctly during intercepts for both linux and macos versions of Telepresence. If you don't have it installed, view the official [documentation](https://www.telepresence.io/docs/troubleshooting#volume-mounts-are-not-working-on-macos) for more information.


    ```console
    telepresence intercept store-front --port 8080:80 --env-file store-front-service-intercept.env
   Using Deployment store-front
   Intercept name         : store-front
   State                  : ACTIVE
   Workload kind          : Deployment
   Destination            : 127.0.0.1:8080
   Service Port Identifier: 80/TCP
   Volume Mount Point     : /tmp/telfs-3392425241
   Intercepting           : all TCP connections
    ```

### Modify Your Local Code and See Real-Time Changes

Now that Telepresence is set up, you can start modifying your local code. These changes will be reflected in real-time, allowing you to test and debug directly against your AKS cluster.

To make changes to the sample app, cd into the store-front service.

    ```console
     cd src/store-front/
    ```

In `components/TopNav.Vue` change the `Products` nav item to `New Products`.


```console
<template>
  <nav>
    <div class="logo">
      <a href="/">
        <img src="/contoso-pet-store-logo.png" alt="Contoso Pet Store Logo">
      </a>
    </div>
    <button class="hamburger" @click="toggleNav">
      <span class="hamburger-icon"></span>
    </button>
    <ul class="nav-links" :class="{ 'nav-links--open': isNavOpen }">
      <li><router-link to="/" @click="closeNav">New Products</router-link></li>
      <li><router-link to="/cart" @click="closeNav">Cart ({{ cartItemCount }})</router-link></li>
    </ul>
  </nav>
</template>
```

Now, if you visit the IP of the `store-front` service in your AKS cluster, you’ll see the updated behavior, as traffic is being routed to your locally running version of the service. Your local changes are reflected in real-time and interact with other services in your AKS cluster.

# Where to learn more

This tutorial covers how to use Telepresence with a sample application on AKS. Telepresence offers more in-depth documentation at the offical [website](https://www.telepresence.io/docs/quick-start/#gsc.tab=0). Covering topics such as FAQ, Troubleshooting, Technical reference, Core concepts, Tutorials and the links to the official community. 



<!-- LINKS - external -->
[git]: https://git-scm.com/downloads
[aks-store-demo app]: https://github.com/Azure-Samples/aks-store-demo
[Telepresence]: https://www.telepresence.io/#gsc.tab=0
[Telepresence GitHub issue page]: https://github.com/telepresenceio/telepresence/issues
[Windows]: https://www.telepresence.io/docs/install/client/?os=windows#gsc.tab=0
[Mac]: https://www.telepresence.io/docs/install/client/?os=macos#gsc.tab=0
[GNU/Linux]: https://www.telepresence.io/docs/install/client/?os=gnu-linux#gsc.tab=0

<!-- LINKS - internal -->
[aks-tutorial-prepare-acr]: ./tutorial-kubernetes-prepare-acr.md
[aks-tutorial-deploy-cluster]: ./tutorial-kubernetes-deploy-cluster.md