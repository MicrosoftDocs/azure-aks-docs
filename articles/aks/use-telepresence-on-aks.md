---
title: Use Telepresence to develop and test microservices locally
description: Learn how to use Telepresence to debug microservices on AKS
ms.topic: tutorial
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 01/16/2025
---

# Tutorial: Use Telepresence to develop and test microservices locally

[Telepresence] is a Cloud Native Computing Foundation (CNCF) Sandbox project created by the team at Ambassador Labs. Telepresence allows developers to run services locally on their development machine while connected to a remote Azure Kubernetes Service (AKS) cluster. This setup makes it easier to develop, debug, and test applications that interact with other services in the cluster without having to redeploy or rebuild the entire application in Kubernetes every time changes are made.

> [!NOTE]
> Telepresence is an open-source CNCF project. Microsoft doesn't offer support for problems you might have using Telepresence. If you do have problems using Telepresence, visit their [Telepresence GitHub issue page] and open an issue.

In this tutorial, you connect an AKS cluster to Telepresence and then modify a sample application running locally.

## How Telepresence works

Telepresence injects Traffic Agents into the workload pod as a sidecar. The Traffic Agents act as a proxy, rerouting inbound and outbound network traffic from the AKS cluster to your local machine. Then, you can develop and test in your local environment as though your local machine were in the AKS cluster. The process involves:

- Connecting to your AKS cluster to Telepresence.
- Specifying the service or deployment you want to intercept inbound and outbound traffic for and then reroute to your local environment.
- Running the local version of the service. Telepresence connects the local version of the service to the cluster through the proxy pod.



## Prerequisites

- An AKS cluster. If you don't have a cluster you can use for this tutorial, create one using [Tutorial - Create an Azure Kubernetes Service (AKS) cluster](./tutorial-kubernetes-deploy-cluster.md).
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) is installed and on the path in command-line environment you use for development. This tutorial uses `kubectl` to manage the Kubernetes cluster. `kubectl` is already installed if you use Azure Cloud Shell. To install `kubectl` locally, use the [`az aks install-cli`](/cli/azure/aks#az_aks_install_cli) command. 
- Install [Node.js LTS](https://nodejs.org). Run the command `node --version` to verify that Node.js is installed.

## Connect to cluster using kubectl

> [!NOTE]
> Set the values of $MY_RESOURCE_GROUP_NAME and $MY_AKS_CLUSTER_NAME accordingly.

Before you can install Telepresence and interact with your AKS cluster, make sure you're connected to your cluster. If you didn't install `kubectl` in the _Prerequisites_ section, do that before continuing.

1. Configure `kubectl` to connect to your AKS cluster using the [az aks get-credentials](/cli/azure/aks#az_aks_get_credentials) command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME
    ```

1. Verify the connection to your cluster using the [kubectl cluster-info](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command. This command displays the name of the cluster so you can confirm you're connected to the cluster you want to work with.

    ```azurecli-interactive
    kubectl cluster-info
    ```

## Clone the sample app and deploy it your AKS cluster

The [aks-store-demo app] used in this tutorial is a basic store front app including the following Kubernetes deployments and services:

:::image type="content" source="./media/container-service-kubernetes-tutorials/aks-store-architecture.png" alt-text="Screenshot of Azure Store sample architecture." lightbox="./media/container-service-kubernetes-tutorials/aks-store-architecture.png":::

* **Store front**: Web application for customers to view products and place orders.
* **Product service**: Shows product information.
* **Order service**: Places orders.
* **Rabbit MQ**: Message queue for an order queue.


1. Use [git] to clone the sample application to your development environment.

    ```console
    git clone https://github.com/Azure-Samples/aks-store-demo.git
    ```

2. Change into the cloned directory.

    ```console
    cd aks-store-demo
    ```

3. Deploy the app to your AKS cluster.

    ```console
    kubectl apply -f aks-store-quickstart.yaml
    ```

## Install Telepresence
To intercept traffic to and from your AKS cluster, you need to install the Telepresence client on your local machine and the traffic manager to your AKS cluster.

### Install the Telepresence client

Choose the OS you're using on your local machine and install that version of Telepresence. 

- [GNU/Linux]
- [Mac]
- [Windows]

Refer to the Telepresence documentation for installation instructions. 

### Install the Telepresence traffic manager

To route cloud traffic to your local machine, Telepresence uses a traffic manager. Helm is used to deploy the traffic manager into your Kubernetes cluster.

```console
telepresence helm install
```

### Intercept traffic to your service

Complete the following steps to intercept traffic going to your service in the AKS cluster and route it to your local machine.

1. From the command line on your local machine, run `telepresence connect` to connect to your AKS cluster and the Kubernetes API server.

    ```console
    telepresence connect
    ```

    A successful response from `telepresence connect` shows the cluster name and default namespace that Telepresence connected to, similar to the following example.

    ```
    Connected to context myAKSCluster, namespace default (https://myAKSCluster-dns-ck7w5t5h.hcp.eastus2.azmk8s.io:443)
    ```

2. Use the `telepresence list` command to display a list of the services you can intercept.

    ```console
    telepresence list
    ```

    A successful response displays available services, similar to the following example.

    ```
    order-service  : ready to intercept (traffic-agent not yet installed)
    product-service: ready to intercept (traffic-agent not yet installed)
    rabbitmq       : ready to intercept (traffic-agent not yet installed)
    store-front    : ready to intercept (traffic-agent not yet installed)
    ```

3. Find the name of the port you need to intercept traffic from using `kubectl get service service-name --output yaml`. For this tutorial, enter the following command in the command line.

    ```console
    kubectl get service store-front -ojsonpath='{.spec.ports[0].port}'
    ```

    In this example, the port to intercept, 80, is returned.

    ```
    80
    ```

4. Intercept the traffic from your service in your AKS cluster using the `telepresence intercept` command with the following format: `$ telepresence intercept <service-name> --port <local-port>[:<remote-port>] --env-file <path-to-env-file>`

    - `--port` specifies the local port and the remote port for your AKS cluster. 
    - `--env-file` specifies the path where Telepresence creates an env file containing the environment variables needed to intercept traffic. This file must exist to properly intercept your service's traffic to your local machine. If a file doesn't exist, telepresence creates it for you.

    > [!NOTE]
    > `sshfs` is required in order for volume mounts to work correctly during intercepts for both Linux and macOS versions of Telepresence. If you don't have it installed, see the [Telepresence documentation](https://www.telepresence.io/docs/troubleshooting#volume-mounts-are-not-working-on-macos) for more information.

    For this tutorial, enter the following command to intercept the traffic.

    ```console
    cd src/store-front
    telepresence intercept store-front --port 8080:80 --env-file .env
    ```
    
    A successful response displays which connections Telepresence is intercepting, similar to the following example.

    ```
    Using Deployment store-front
    Intercept name         : store-front
    State                  : ACTIVE
    Workload kind          : Deployment
    Destination            : 127.0.0.1:8080
    Service Port Identifier: 80/TCP
    Volume Mount Point     : /tmp/telfs-3392425241
    Intercepting           : all TCP connections
    ```

## Modify your local code and see real-time changes

1. Navigate and open `components/TopNav.Vue` in the application you cloned previously.

1. Change the `Products` navigation item to `New Products`, as seen in the following example, and save the changes.

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

1. Run the following commands to run the app locally.
    1. `npm install` - Installs the dependencies. 
    1. `npm run serve` - Starts the development server. 

When you go to the public IP of the `store-front` service in your AKS cluster, the updated navigation is present and traffic is being routed to your locally running version of the service. Your local changes are reflected in real-time and interact with other services in your AKS cluster.

## Video demo

The following video provides a clear and concise walkthrough of Telepresence's F5 debugging capabilities.

> [!VIDEO https://youtu.be/hbQfKwFeUtE?si=tpjiC2aIny3AAx-5]

## Next step

This tutorial explains how to use Telepresence with a sample application on AKS. Telepresence offers more in-depth documentation on their [website](https://www.telepresence.io/docs/quick-start/#gsc.tab=0). Their content covers FAQs, troubleshooting, technical reference, core concepts, tutorials, and links to the community.  



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