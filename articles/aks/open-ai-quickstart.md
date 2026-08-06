---
title: Deploy an application that uses OpenAI on Azure Kubernetes Service (AKS)
description: Learn how to deploy an application that uses OpenAI on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 08/06/2026
ms.custom: template-how-to, devx-track-azurecli
ms.subservice: aks-developer
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
# Customer intent: As a developer, I want to deploy an application using OpenAI on a Kubernetes service, so that I can leverage AI capabilities for functionalities such as automated content generation in my application.
---

# Deploy an application that uses OpenAI on Azure Kubernetes Service (AKS)

In this article, you deploy the AKS Store Demo application on Azure Kubernetes Service (AKS) and configure Azure OpenAI or the OpenAI API to generate product descriptions.

The sample cloud-native application comprises services written in multiple languages and frameworks, including:

- Golang with Gin
- Rust with Actix-Web
- JavaScript with Vue.js and Fastify
- Python with FastAPI

These applications provide front ends for shoppers and store administrators, REST APIs that send data to a RabbitMQ message queue and DocumentDB database, and console apps that simulate traffic.

> [!NOTE]
> Don't run stateful containers, such as DocumentDB and RabbitMQ, without persistent storage in production. This article uses them without persistent storage for simplicity. For production workloads, use managed services such as Azure Cosmos DB or Azure Service Bus.

To access the GitHub codebase for the sample application, see [AKS Store Demo][aks-store-demo].

## Before you begin

- You need an Azure account with an active subscription. If you don't have one, [create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- For this demo, use either Azure OpenAI or the OpenAI API.
  - To use Azure OpenAI, you need permissions to create an Azure OpenAI resource and deploy a model. Registration is required only for [limited-access models or modified safeguards][aoai-limited-access].
  - To use the OpenAI API, sign up on the [OpenAI website][open-ai-landing].

[!INCLUDE [azure-cli-prepare-your-environment.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment.md)]

## Create a resource group

An [Azure resource group][azure-resource-group] is a logical group in which you deploy and manage Azure resources. When you create a resource group, you're prompted to specify a location. This location is the storage location of your resource group metadata and where your resources run in Azure if you don't specify another region during resource creation.

The following example creates a resource group named _myResourceGroup_ in the _eastus_ location.

Create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create --name myResourceGroup --location eastus
```

The following example output shows successful creation of the resource group:

```output
{
  "id": "/subscriptions/<guid>/resourceGroups/myResourceGroup",
  "location": "eastus",
  "managedBy": null,
  "name": "myResourceGroup",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## Create an AKS cluster

The following example creates a cluster named _myAKSCluster_ in _myResourceGroup_.

Create an AKS cluster using the [`az aks create`][az-aks-create] command.

```azurecli-interactive
az aks create --resource-group myResourceGroup --name myAKSCluster --generate-ssh-keys
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

## Connect to the cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, [`kubectl`][kubectl]. If you use Azure Cloud Shell, `kubectl` is already installed.

1. Install `kubectl` locally using the [`az aks install-cli`][az-aks-install-cli] command.

    ```azurecli-interactive
    az aks install-cli
    ```

    > [!NOTE]
    > If your Linux-based system requires elevated permissions, use the `sudo az aks install-cli` command.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    This command runs the following operations:

    - Downloads credentials and configures the Kubernetes CLI to use them.
    - Uses `~/.kube/config`, the default location for the [Kubernetes configuration file][kubeconfig-file]. Specify a different location for your Kubernetes configuration file by using the _--file_ argument.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command. This command returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The following example output shows the nodes created in the preceding steps. Verify that each node has a status of _Ready_.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-nodepool1-31469198-vmss000000   Ready    agent   3h29m   v1.25.6
    aks-nodepool1-31469198-vmss000001   Ready    agent   3h29m   v1.25.6
    aks-nodepool1-31469198-vmss000002   Ready    agent   3h29m   v1.25.6
    ```

> [!NOTE]
> For a private AKS cluster, connect from an endpoint in the same virtual network as the cluster. For configuration instructions, see [Create a private AKS cluster][create-private-cluster].

## Deploy the application

The [AKS Store application][aks-store-demo] manifest includes the following Kubernetes deployments and services:

- **Product service**: Shows product information.
- **Order service**: Places orders.
- **Makeline service**: Processes orders from the queue and completes the orders.
- **Store front**: Web application for customers to view products and place orders.
- **Store admin**: Web application for store employees to view orders in the queue and manage product information.
- **Virtual customer**: Simulates order creation on a scheduled basis.
- **Virtual worker**: Simulates order completion on a scheduled basis.
- **DocumentDB**: NoSQL instance for persisted data.
- **RabbitMQ**: Message queue for an order queue.

> [!NOTE]
> Don't run stateful containers, such as DocumentDB and RabbitMQ, without persistent storage in production. This article uses them without persistent storage for simplicity. For production workloads, use managed services such as Azure Cosmos DB or Azure Service Bus.

1. Review the [YAML manifest](https://github.com/Azure-Samples/aks-store-demo/blob/main/aks-store-all-in-one.yaml) for the application.
1. Deploy the application using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml
    ```

## Deploy an OpenAI service

Choose Azure OpenAI or the OpenAI API for the application running on AKS.

### [Azure OpenAI](#tab/aoai)

1. In the Azure portal, create an Azure OpenAI instance.
1. Sign in to [Microsoft Foundry][aoai-studio].
1. Turn off the **New Foundry** toggle, and then select **View all resources** under **Keep building with Foundry**.
1. Select the Azure OpenAI resource you created, and then select **Deployments** under **Shared resources**.
1. Select **Deploy model** > **Deploy base model**.
1. Select the **gpt-4o-mini** base model, enter a deployment name, and then deploy the model. Save the deployment name for the next section.

For more information about creating an Azure OpenAI deployment, see [Get started generating text using Azure OpenAI][aoai-get-started].

### [OpenAI](#tab/openai)

1. [Generate an OpenAI key][open-ai-new-key] by selecting **Create new secret key** and save the key. You need this key in the [Deploy the AI microservice](#deploy-the-ai-microservice) section.
1. [Start a paid plan][openai-paid] to use OpenAI API.

---

## Deploy the AI microservice

Deploy the Python-based AI microservice that uses OpenAI to automatically generate product descriptions. This microservice connects to the AKS Store application you deployed in the previous section.

### [Azure OpenAI](#tab/aoai)

Use the Azure OpenAI resource and model deployment you created in the [Deploy an OpenAI service](#deploy-an-openai-service) section. Configure the following environment variables in the AI microservice manifest:

| Environment variable | Value |
| --- | --- |
| `USE_AZURE_OPENAI` | Set to `"True"` to use Azure OpenAI. |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | The name of your `gpt-4o-mini` model deployment in Microsoft Foundry. |
| `AZURE_OPENAI_ENDPOINT` | The endpoint from the **Keys and Endpoint** page of your Azure OpenAI resource. |
| `OPENAI_API_KEY` | An API key from the **Keys and Endpoint** page of your Azure OpenAI resource. |

1. Create a file named `ai-service.yaml` and copy in the following manifest:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ai-service
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ai-service
      template:
        metadata:
          labels:
            app: ai-service
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
            - name: ai-service
              image: ghcr.io/azure-samples/aks-store-demo/ai-service:2.2.0
              ports:
                - containerPort: 5001
              env:
                - name: USE_AZURE_OPENAI
                  value: "True"
                - name: AZURE_OPENAI_DEPLOYMENT_NAME
                  value: ""
                - name: AZURE_OPENAI_ENDPOINT
                  value: ""
                - name: OPENAI_API_KEY
                  value: ""
              resources:
                requests:
                  cpu: 20m
                  memory: 50Mi
                limits:
                  cpu: 50m
                  memory: 128Mi
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ai-service
    spec:
      type: ClusterIP
      ports:
        - name: http
          port: 5001
          targetPort: 5001
      selector:
        app: ai-service
    ```

1. Set the environment variable `USE_AZURE_OPENAI` to `"True"`.
1. In [Microsoft Foundry][aoai-studio], copy the Azure OpenAI deployment name and set the `AZURE_OPENAI_DEPLOYMENT_NAME` value.
1. In the Azure portal, select **Keys and Endpoint** in your Azure OpenAI resource. Copy the endpoint and API key, and then set the `AZURE_OPENAI_ENDPOINT` and `OPENAI_API_KEY` values.
1. Deploy the application using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f ai-service.yaml
    ```

    The following example output shows the successfully created deployments and services:

    ```output
      deployment.apps/ai-service created
      service/ai-service created
    ```

### [OpenAI](#tab/openai)

Use the OpenAI secret key and organization ID from the [Deploy an OpenAI service](#deploy-an-openai-service) section. Configure the following environment variables in the AI microservice manifest:

| Environment variable | Value |
| --- | --- |
| `USE_AZURE_OPENAI` | Set to `"False"` to use OpenAI. |
| `OPENAI_API_KEY` | The OpenAI secret key generated on the [OpenAI API keys page][open-ai-new-key]. |
| `OPENAI_ORG_ID` | Your organization ID from the [OpenAI organization settings page][open-ai-org-id]. |

1. Create a file named `ai-service.yaml` and copy in the following manifest:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ai-service
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ai-service
      template:
        metadata:
          labels:
            app: ai-service
        spec:
          nodeSelector:
            "kubernetes.io/os": linux
          containers:
            - name: ai-service
              image: ghcr.io/azure-samples/aks-store-demo/ai-service:2.2.0
              ports:
                - containerPort: 5001
              env:
                - name: USE_AZURE_OPENAI
                  value: "False"
                - name: OPENAI_API_KEY
                  value: ""
                - name: OPENAI_ORG_ID
                  value: ""
              resources:
                requests:
                  cpu: 20m
                  memory: 50Mi
                limits:
                  cpu: 50m
                  memory: 128Mi
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ai-service
    spec:
      type: ClusterIP
      ports:
        - name: http
          port: 5001
          targetPort: 5001
      selector:
        app: ai-service
    ```

1. Set the environment variable `USE_AZURE_OPENAI` to `"False"`.
1. Set `OPENAI_API_KEY` to the OpenAI secret key you generated on the [OpenAI API keys page][open-ai-new-key] in the [Deploy an OpenAI service](#deploy-an-openai-service) section.
1. Set `OPENAI_ORG_ID` to the organization ID from your [OpenAI organization settings page][open-ai-org-id].
1. Deploy the application using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f ai-service.yaml
    ```

    The following example output shows the successfully created deployments and services:

    ```output
      deployment.apps/ai-service created
      service/ai-service created
    ```

---

> [!NOTE]
> Storing API keys directly in Kubernetes manifests is insecure and can expose secrets in source control. This example uses manifest values for simplicity. For production workloads, authenticate to Azure OpenAI by using a [managed identity][managed-identity], or store secrets in [Azure Key Vault][key-vault].

## Test the application

1. Check the status of the deployed pods using the [`kubectl get pods`][kubectl-get] command.

    ```bash
    kubectl get pods
    ```

    Verify that all pods have a status of _Running_ before you continue.

1. Get the external IP address for Store Admin by using the `kubectl get service` command.

    ```bash
    kubectl get service store-admin
    ```

    A Kubernetes service exposes Store Admin through a public load balancer. The load balancer might take a few minutes to assign an address. The **EXTERNAL-IP** value displays _pending_ until the address is available.

    ```output
    NAME          TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
    store-admin   LoadBalancer   10.0.142.228   40.64.86.161    80:32494/TCP   50m
    ```

1. Repeat the preceding step for the `store-front` service.
1. In a web browser, go to the external IP address for Store Admin. In this example, the address is _40.64.86.161_.
1. In Store Admin, select **Products** > **Add Product**.
1. After `ai-service` starts, the **Ask AI Assistant** button appears next to the description field. Enter the name, price, and keywords, select **Ask AI Assistant** to generate a product description, and then select **Save Product**.
1. Verify that Dog Smart Collar appears in Store Admin.

    :::image type="content" source="media/ai-walkthrough/new-product-store-admin.png" alt-text="Screenshot showing the new product in Store Admin.":::

1. Go to the external IP address for Store Front and verify that Dog Smart Collar appears.

    :::image type="content" source="media/ai-walkthrough/new-product-store-front.png" alt-text="Screenshot showing the new product in Store Front.":::

## Next steps

Now that you added OpenAI functionality to an AKS application, you can [Secure access to Azure OpenAI from Azure Kubernetes Service (AKS)](./open-ai-secure-access-quickstart.md).

To learn more about generative AI use cases, see the following resources:

- [Azure OpenAI documentation][aoai]
- [Introduction to Azure OpenAI][learn-aoai]
- [OpenAI Platform][openai-platform]
- [Project Miyagi - Envisioning sample for Copilot stack][miyagi]

<!-- Links external -->

[aks-store-demo]: https://github.com/Azure-Samples/aks-store-demo
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubeconfig-file]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[aoai-studio]: https://ai.azure.com/
[open-ai-landing]: https://openai.com/
[open-ai-new-key]: https://platform.openai.com/account/api-keys
[open-ai-org-id]: https://platform.openai.com/account/org-settings
[openai-paid]: https://platform.openai.com/account/billing/overview
[openai-platform]: https://platform.openai.com/
[miyagi]: https://github.com/Azure-Samples/miyagi

<!-- Links internal -->

[azure-resource-group]: /azure/azure-resource-manager/management/overview
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[aoai-get-started]: /azure/ai-services/openai/quickstart
[aoai-limited-access]: /azure/foundry/responsible-ai/openai/limited-access
[managed-identity]: /azure/ai-services/openai/how-to/managed-identity#authorize-access-to-managed-identities
[key-vault]: csi-secrets-store-driver.md
[aoai]: /azure/ai-services/openai/
[learn-aoai]: /training/modules/explore-azure-openai
[create-private-cluster]: private-clusters.md
