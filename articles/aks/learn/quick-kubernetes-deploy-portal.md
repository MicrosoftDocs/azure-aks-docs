---
title: 'Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using the Azure portal'
titleSuffix: Azure Kubernetes Service
description: Learn how to quickly deploy a Kubernetes cluster and deploy an application in Azure Kubernetes Service (AKS) using the Azure portal.
ms.topic: quickstart
ms.date: 05/13/2024
ms.custom: mvc, mode-ui
ms.author: schaffererin
author: schaffererin
#Customer intent: As a developer or cluster operator, I want to quickly deploy an AKS cluster and deploy an application so that I can see how to run and monitor applications using the managed Kubernetes service in Azure.
---

# Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using Azure portal

Azure Kubernetes Service (AKS) is a managed Kubernetes service that lets you quickly deploy and manage clusters. In this quickstart, you:

- Deploy an AKS cluster using the Azure portal.
- Run a sample multi-container application with a group of microservices and web front ends simulating a retail scenario.

> [!NOTE]
> To get started with quickly provisioning an AKS cluster, this article includes steps to deploy a cluster with default settings for evaluation purposes only. Before deploying a production-ready cluster, we recommend that you familiarize yourself with our [baseline reference architecture][baseline-reference-architecture] to consider how it aligns with your business requirements.

## Before you begin

This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)][kubernetes-concepts].

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
- If you're unfamiliar with the Azure Cloud Shell, review [Overview of Azure Cloud Shell](/azure/cloud-shell/overview).
- Make sure that the identity you use to create your cluster has the appropriate minimum permissions. For more details on access and identity for AKS, see [Access and identity options for Azure Kubernetes Service (AKS)](../concepts-identity.md).

> [!NOTE]
> The Azure Linux node pool is now generally available (GA). To learn about the benefits and deployment steps, see the [Introduction to the Azure Linux Container Host for AKS][intro-azure-linux].

## Create an AKS cluster

1. Sign in to the [Azure portal][azure-portal].
1. On the Azure portal home page, select **Create a resource**.
1. In the **Categories** section, select **Containers** > **Azure Kubernetes Service (AKS)**.
1. On the **Basics** tab, configure the following settings:
    - Under **Project details**:
        - **Subscription**: Select the Azure subscription you want to use for this AKS cluster.
        - **Resource group**: Select **Create new**, enter a resource group name, such as *myResourceGroup*, and then select **Ok**. While you can select an existing resource group, for testing or evaluation purposes, we recommend creating a resource group to temporarily host these resources and avoid impacting your production or development workloads.
    - Under **Cluster details**:
      - **Cluster preset configuration**: Select **Dev/Test**. For more details on preset configurations, see [Cluster configuration presets in the Azure portal][preset-config].

        > [!NOTE]
        > You can change the preset configuration when creating your cluster by selecting **Compare presets** and choosing a different option.
        > :::image type="content" source="media/quick-kubernetes-deploy-portal/cluster-presets.png" alt-text="Screenshot of Create AKS cluster - portal preset options." lightbox="media/quick-kubernetes-deploy-portal/cluster-presets.png":::

      - **Kubernetes cluster name**: Enter a cluster name, such as *myAKSCluster*.
      - **Region**: Select a region, such as *East US 2*.
      - **Availability zones**: Select **None**.
      - **AKS pricing tier**: Select **Free**.
      - Leave the default values for the remaining settings, and select **Next**.

        :::image type="content" source="media/quick-kubernetes-deploy-portal/create-cluster.png" alt-text="Screenshot showing how to configure an AKS cluster in Azure portal." lightbox="media/quick-kubernetes-deploy-portal/create-cluster.png":::

1. On the **Node pools** tab, configure the following settings:
    - Select **Add node pool** and enter a **Node pool name**, such as *nplinux*.
    - **Mode**: Select **User**.
    - **OS SKU**: Select **Ubuntu Linux**.
    - **Availability zones**: Select **None**.
    - Leave the **Enable Azure Spot instances** checkbox unchecked.
    - **Node size**: Select **Choose a size**. On the **Select a VM size** page, select **D2s_v3**, and then select **Select**.
    - Leave the default values for the remaining settings, and select **Add**.

        :::image type="content" source="media/quick-kubernetes-deploy-portal/create-linux-node-pool.png" alt-text="Screenshot showing how to create a node pool running Ubuntu Linux." lightbox="media/quick-kubernetes-deploy-portal/create-linux-node-pool.png":::

1. Select **Review + create** to run validation on the cluster configuration. After validation completes, select **Create**.

    It takes a few minutes to create the AKS cluster. When your deployment is complete, navigate to your resource by selecting **Go to resource**, or by browsing to the AKS cluster resource group and selecting the AKS resource.

## Connect to the cluster

You use the Kubernetes command-line client, [kubectl][kubectl], to manage Kubernetes clusters. `kubectl` is already installed if you use Azure Cloud Shell. If you're unfamiliar with the Cloud Shell, review [Overview of Azure Cloud Shell](/azure/cloud-shell/overview).

If you're using Cloud Shell, open it with the `>_` button on the top of the Azure portal. If you're using PowerShell locally, connect to Azure via the `Connect-AzAccount` command. If you're using Azure CLI locally, connect to Azure via the `az login` command.

### [Azure CLI](#tab/azure-cli)

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

1. Verify the connection to your cluster using `kubectl get` to return a list of the cluster nodes.

    ```azurecli-interactive
    kubectl get nodes
    ```

    The following example output shows the single node created in the previous steps. Make sure the node status is *Ready*.

    ```output
    NAME                       STATUS   ROLES   AGE     VERSION
    aks-nodepool1-31718369-0   Ready    agent   6m44s   v1.15.10
    ```

### [Azure PowerShell](#tab/azure-powershell)

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`Import-AzAksCredential`][import-azakscredential] cmdlet. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurepowershell-interactive
    Import-AzAksCredential -ResourceGroupName myResourceGroup -Name myAKSCluster
    ```

1. Verify the connection to your cluster using `kubectl get` to return a list of the cluster nodes.

    ```azurepowershell-interactive
    kubectl get nodes
    ```

    The following example output shows the single node created in the previous steps. Make sure the node status is *Ready*.

    ```output
    NAME                       STATUS  ROLES   AGE     VERSION
    aks-nodepool1-31718369-0   Ready   agent   6m44s   v1.15.10
    ```

---

## Deploy the application

You use a manifest file to create all the objects required to run the [AKS Store application](https://github.com/Azure-Samples/aks-store-demo). A Kubernetes manifest file defines a cluster's desired state, such as which container images to run. The manifest includes the following Kubernetes deployments and services:

:::image type="content" source="media/quick-kubernetes-deploy-portal/aks-store-architecture.png" alt-text="Screenshot of Azure Store sample architecture." lightbox="media/quick-kubernetes-deploy-portal/aks-store-architecture.png":::

- **Store front**: Web application for customers to view products and place orders.
- **Product service**: Shows product information.
- **Order service**: Places orders.
- **Rabbit MQ**: Message queue for an order queue.

> [!NOTE]
> We don't recommend running stateful containers, such as Rabbit MQ, without persistent storage for production. These are used here for simplicity, but we recommend using managed services, such as Azure CosmosDB or Azure Service Bus.

1. In the Cloud Shell, open an editor and create a file named `aks-store-quickstart.yaml`.
2. Paste the following manifest into the editor:

    ```YAML
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: rabbitmq
    spec:
      serviceName: rabbitmq
      replicas: 1
      selector:
        matchLabels:
          app: rabbitmq
      template:
        metadata:
          labels:
            app: rabbitmq
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
          - name: rabbitmq
            image: mcr.microsoft.com/mirror/docker/library/rabbitmq:3.10-management-alpine
            ports:
            - containerPort: 5672
              name: rabbitmq-amqp
            - containerPort: 15672
              name: rabbitmq-http
            env:
            - name: RABBITMQ_DEFAULT_USER
              value: "username"
            - name: RABBITMQ_DEFAULT_PASS
              value: "password"
            resources:
              requests:
                cpu: 10m
                memory: 128Mi
              limits:
                cpu: 250m
                memory: 256Mi
            volumeMounts:
            - name: rabbitmq-enabled-plugins
              mountPath: /etc/rabbitmq/enabled_plugins
              subPath: enabled_plugins
          volumes:
          - name: rabbitmq-enabled-plugins
            configMap:
              name: rabbitmq-enabled-plugins
              items:
              - key: rabbitmq_enabled_plugins
                path: enabled_plugins
    ---
    apiVersion: v1
    data:
      rabbitmq_enabled_plugins: |
        [rabbitmq_management,rabbitmq_prometheus,rabbitmq_amqp1_0].
    kind: ConfigMap
    metadata:
      name: rabbitmq-enabled-plugins            
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: rabbitmq
    spec:
      selector:
        app: rabbitmq
      ports:
        - name: rabbitmq-amqp
          port: 5672
          targetPort: 5672
        - name: rabbitmq-http
          port: 15672
          targetPort: 15672
      type: ClusterIP
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: order-service
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: order-service
      template:
        metadata:
          labels:
            app: order-service
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
          - name: order-service
            image: ghcr.io/azure-samples/aks-store-demo/order-service:latest
            ports:
            - containerPort: 3000
            env:
            - name: ORDER_QUEUE_HOSTNAME
              value: "rabbitmq"
            - name: ORDER_QUEUE_PORT
              value: "5672"
            - name: ORDER_QUEUE_USERNAME
              value: "username"
            - name: ORDER_QUEUE_PASSWORD
              value: "password"
            - name: ORDER_QUEUE_NAME
              value: "orders"
            - name: FASTIFY_ADDRESS
              value: "0.0.0.0"
            resources:
              requests:
                cpu: 1m
                memory: 50Mi
              limits:
                cpu: 75m
                memory: 128Mi
            startupProbe:
              httpGet:
                path: /health
                port: 3000
              failureThreshold: 5
              initialDelaySeconds: 20
              periodSeconds: 10
            readinessProbe:
              httpGet:
                path: /health
                port: 3000
              failureThreshold: 3
              initialDelaySeconds: 3
              periodSeconds: 5
            livenessProbe:
              httpGet:
                path: /health
                port: 3000
              failureThreshold: 5
              initialDelaySeconds: 3
              periodSeconds: 3
          initContainers:
          - name: wait-for-rabbitmq
            image: busybox
            command: ['sh', '-c', 'until nc -zv rabbitmq 5672; do echo waiting for rabbitmq; sleep 2; done;']
            resources:
              requests:
                cpu: 1m
                memory: 50Mi
              limits:
                cpu: 75m
                memory: 128Mi    
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: order-service
    spec:
      type: ClusterIP
      ports:
      - name: http
        port: 3000
        targetPort: 3000
      selector:
        app: order-service
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: product-service
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: product-service
      template:
        metadata:
          labels:
            app: product-service
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
          - name: product-service
            image: ghcr.io/azure-samples/aks-store-demo/product-service:latest
            ports:
            - containerPort: 3002
            env: 
            - name: AI_SERVICE_URL
              value: "http://ai-service:5001/"
            resources:
              requests:
                cpu: 1m
                memory: 1Mi
              limits:
                cpu: 2m
                memory: 20Mi
            readinessProbe:
              httpGet:
                path: /health
                port: 3002
              failureThreshold: 3
              initialDelaySeconds: 3
              periodSeconds: 5
            livenessProbe:
              httpGet:
                path: /health
                port: 3002
              failureThreshold: 5
              initialDelaySeconds: 3
              periodSeconds: 3
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: product-service
    spec:
      type: ClusterIP
      ports:
      - name: http
        port: 3002
        targetPort: 3002
      selector:
        app: product-service
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: store-front
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: store-front
      template:
        metadata:
          labels:
            app: store-front
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
          - name: store-front
            image: ghcr.io/azure-samples/aks-store-demo/store-front:latest
            ports:
            - containerPort: 8080
              name: store-front
            env: 
            - name: VUE_APP_ORDER_SERVICE_URL
              value: "http://order-service:3000/"
            - name: VUE_APP_PRODUCT_SERVICE_URL
              value: "http://product-service:3002/"
            resources:
              requests:
                cpu: 1m
                memory: 200Mi
              limits:
                cpu: 1000m
                memory: 512Mi
            startupProbe:
              httpGet:
                path: /health
                port: 8080
              failureThreshold: 3
              initialDelaySeconds: 5
              periodSeconds: 5
            readinessProbe:
              httpGet:
                path: /health
                port: 8080
              failureThreshold: 3
              initialDelaySeconds: 3
              periodSeconds: 3
            livenessProbe:
              httpGet:
                path: /health
                port: 8080
              failureThreshold: 5
              initialDelaySeconds: 3
              periodSeconds: 3
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: store-front
    spec:
      ports:
      - port: 80
        targetPort: 8080
      selector:
        app: store-front
      type: LoadBalancer
    ```

    For a breakdown of YAML manifest files, see [Deployments and YAML manifests](../concepts-clusters-workloads.md#deployments-and-yaml-manifests).

    If you create and save the YAML file locally, then you can upload the manifest file to your default directory in CloudShell by selecting the **Upload/Download files** button and selecting the file from your local file system.

3. Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest:

    ```bash
    kubectl apply -f aks-store-quickstart.yaml
    ```

    The following example output shows the deployments and services:

    ```output
    deployment.apps/rabbitmq created
    service/rabbitmq created
    deployment.apps/order-service created
    service/order-service created
    deployment.apps/product-service created
    service/product-service created
    deployment.apps/store-front created
    service/store-front created
    ```

## Test the application

When the application runs, a Kubernetes service exposes the application front end to the internet. This process can take a few minutes to complete.

1. Check the status of the deployed pods using the [`kubectl get pods`][kubectl-get] command. Make sure all pods are `Running` before proceeding.

    ```bash
    kubectl get pods
    ```

1. Check for a public IP address for the `store-front` application. Monitor progress using the [`kubectl get service`][kubectl-get] command with the `--watch` argument.

    ```azurecli-interactive
    kubectl get service store-front --watch
    ```

    The **EXTERNAL-IP** output for the `store-front` service initially shows as *pending*:

    ```output
    NAME          TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
    store-front   LoadBalancer   10.0.100.10   <pending>     80:30025/TCP   4h4m
    ```

    Once the **EXTERNAL-IP** address changes from *pending* to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

    The following example output shows a valid public IP address assigned to the service:

    ```output
    NAME          TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
    store-front   LoadBalancer   10.0.100.10   20.62.159.19   80:30025/TCP   4h5m
    ```

1. Open a web browser to the external IP address of your service to see the Azure Store app in action.

    :::image type="content" source="media/quick-kubernetes-deploy-portal/aks-store-application.png" alt-text="Screenshot of AKS Store sample application." lightbox="media/quick-kubernetes-deploy-portal/aks-store-application.png":::

## Delete the cluster

If you don't plan on going through the [AKS tutorial series][aks-tutorial], clean up unnecessary resources to avoid Azure charges.

1. In the Azure portal, navigate to your AKS cluster resource group.
1. Select **Delete resource group**.
1. Enter the name of the resource group to delete, and then select **Delete** > **Delete**.

    > [!NOTE]
    > The AKS cluster was created with a system-assigned managed identity. This identity is managed by the platform and doesn't require removal.

## Next steps

In this quickstart, you deployed a Kubernetes cluster, and then deployed a simple multi-container application to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see [AKS solution guidance][aks-solution-guidance].

To learn more about AKS and walk through a complete code-to-deployment example, continue to the Kubernetes cluster tutorial series.

> [!div class="nextstepaction"]
> [AKS tutorial series][aks-tutorial]

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[azure-portal]: https://portal.azure.com
[kubernetes-concepts]: ../concepts-clusters-workloads.md
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[import-azakscredential]: /powershell/module/az.aks/import-azakscredential
[aks-tutorial]: ../tutorial-kubernetes-prepare-app.md
[preset-config]: ../quotas-skus-regions.md#cluster-configuration-presets-in-the-azure-portal
[intro-azure-linux]: /azure/azure-linux/intro-azure-linux
[baseline-reference-architecture]: /azure/architecture/reference-architectures/containers/aks/baseline-aks?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
[aks-solution-guidance]: /azure/architecture/reference-architectures/containers/aks-start-here?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
