---
title: 'Quickstart: Create an Azure Kubernetes Service (AKS) Automatic cluster'
description: Learn how to quickly deploy a Kubernetes cluster and deploy an application in Azure Kubernetes Service (AKS) Automatic.
ms.topic: quickstart
ms.custom: build-2024, devx-track-azurecli, devx-track-bicep, ignite-2024
ms.date: 10/10/2025
author: wangyira
ms.author: wangamanda
zone_pivot_groups: bicep-azure-cli-portal
# Customer intent: As a DevOps engineer, I want to create and manage an Azure Kubernetes Service (AKS) Automatic cluster, so that I can efficiently deploy and operate containerized applications with best practice configurations automatically.
---

# Quickstart: Create an Azure Kubernetes Service (AKS) Automatic cluster

**Applies to**: :heavy_check_mark: AKS Automatic

[Azure Kubernetes Service (AKS) Automatic][what-is-aks-automatic] is a managed Kubernetes experience that automates AKS cluster setup and operations and embeds best practice configurations. AKS Automatic also includes a [pod readiness SLA][azure-sla] that guarantees 99.9% of qualifying pod readiness operations complete within 5 minutes, guaranteeing reliable, self-healing infrastructure for your applications. In this quickstart, you learn how to:

- Deploy an AKS Automatic cluster.
- Run a sample multi-container application with a group of microservices and web front ends simulating a retail scenario.

## Before you begin

- This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)][kubernetes-concepts].
- AKS Automatic [enables Azure Policy on your AKS cluster][policy-for-kubernetes], but you should preregister the `Microsoft.PolicyInsights` resource provider in your subscription. For more information, see [Azure resource providers and types][az-provider-register].

:::zone target="docs" pivot="azure-cli"

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- Azure CLI version 2.77.0 or later. Find your version using the `az --version` command. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli). If you're using Azure Cloud Shell, the latest version is already installed there.
- If you have multiple Azure subscriptions, select the appropriate subscription ID to bill resources to using the [`az account set`](/cli/azure/account#az-account-set) command.

:::zone-end

:::zone target="docs" pivot="bicep"

- To deploy a Bicep file, you need write access on the resources you create and access to all operations on the `Microsoft.Resources/deployments` resource type. For example, to create a virtual machine (VM), you need `Microsoft.Compute/virtualMachines/write` and `Microsoft.Resources/deployments/*` permissions. For a list of roles and permissions, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).

:::zone-end

[!INCLUDE [Automatic limitations](../includes/aks-automatic/aks-automatic-limitations.md)]

:::zone target="docs" pivot="azure-cli,bicep"

## Create a resource group

An [Azure resource group][azure-resource-group] is a logical group in which Azure resources are deployed and managed.

Create a resource group using the [`az group create`][az-group-create] command. The following example creates a resource group named _myResourceGroup_ in the _eastus_ location:

```azurecli-interactive
az group create --name myResourceGroup --location eastus
```

The following sample output resembles successful creation of the resource group:

```output
{
  "id": "/subscriptions/<guid>/resourceGroups/myResourceGroup",
  "location": "eastus",
  "managedBy": null,
  "name": "myResourceGroup",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null
}
```

:::zone-end

:::zone target="docs" pivot="azure-cli"

## Create an AKS Automatic cluster

Create an AKS Automatic cluster using the [`az aks create`][az-aks-create] command with the `--sku` parameter set to `automatic`. The following example creates a cluster named _myAKSAutomaticCluster_ with Managed Prometheus and the Container Insights integration enabled:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSAutomaticCluster \
    --sku automatic
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Create Automatic Kubernetes cluster

1. To create an AKS Automatic cluster, search for and select **Kubernetes services**. This takes you to the **Kubernetes center (preview)** page.
1. On the **Kubernetes center (preview)** page, select **Create** > **Automatic Kubernetes cluster**.

    :::image type="content" source="../media/automatic/quick-automatic-managed-network/create-automatic-cluster.png" alt-text="The screenshot of the Create Automatic AKS cluster button in the Azure portal.":::

1. On the **Basics** tab, fill in all the required fields (Subscription, Resource group, Kubernetes cluster name, and Region), and then select **Next**.

    :::image type="content" source="../media/automatic/quick-automatic-managed-network/create-automatic-cluster-basics.png" alt-text="The screenshot of the Create - Basics Tab for an AKS Automatic cluster in the Azure portal.":::

1. On the **Monitoring** tab, select your desired monitoring configurations from Azure Monitor (Container Insights), Managed Prometheus, Grafana Dashboards, Container Network Observability (ACNS), and Alerts, and then select **Next**.

    :::image type="content" source="../media/automatic/quick-automatic-managed-network/create-automatic-cluster-monitoring.png" alt-text="The screenshot of the Monitoring Tab while creating an AKS Automatic cluster in the Azure portal.":::

1. On the **Advanced** tab, select your desired advanced configurations Private access, Azure Virtual Networking, Managed identity, Container Network Security (ACNS), and Managed Kubernetes Namespaces, and then select **Review + create**.

    :::image type="content" source="../media/automatic/quick-automatic-managed-network/create-automatic-cluster-advanced.png" alt-text="The screenshot of the Advanced Tab while creating an AKS Automatic cluster in the Azure portal.":::

1. Review the configurations on the **Review + create** tab, and then select **Create** to deploy the AKS Automatic cluster.
1. Get started with configuring your first application from GitHub and set up an automated deployment pipeline.

    :::image type="content" source="../learn/media/quick-automatic-kubernetes-portal/automatic-overview.png" alt-text="The screenshot of the Get Started Tab on Overview Blade after creating an AKS Automatic cluster in the Azure portal.":::

:::zone-end

:::zone target="docs" pivot="bicep"

## Review the Bicep file

The following Bicep file defines an AKS Automatic cluster:

```bicep
@description('The name of the managed cluster resource.')
param clusterName string = 'myAKSAutomaticCluster'

@description('The location of the managed cluster resource.')
param location string = resourceGroup().location

resource aks 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = {
  name: clusterName
  location: location  
  sku: {
  name: 'Automatic'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
  count: 3
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}
```

For more information about the resource defined in the Bicep file, see the [**Microsoft.ContainerService/managedClusters**](/azure/templates/microsoft.containerservice/managedclusters?tabs=bicep&pivots=deployment-language-bicep) reference.

## Deploy the Bicep file

1. Save the Bicep file as **main.bicep** to your local computer.

    > [!IMPORTANT]
    > The Bicep file sets the `clusterName` param to the string _myAKSAutomaticCluster_. If you want to use a different cluster name, make sure to update the string to your preferred cluster name before saving the file to your computer.

1. Deploy the Bicep file using the [`az deployment group create`][az-deployment-group-create] command.

      ```azurecli-interactive
    az deployment group create --resource-group myResourceGroup --template-file main.bicep
    ```

    It takes a few minutes to create the AKS cluster. Wait for the cluster to be successfully deployed before you move on to the next step.

:::zone-end

## Connect to the cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, [kubectl][kubectl]. `kubectl` is already installed if you use Azure Cloud Shell. You can install `kubectl` locally using the [`az aks install-cli`][az-aks-install-cli] command. AKS Automatic clusters are configured with [Microsoft Entra ID for Kubernetes role-based access control (RBAC)][aks-entra-rbac].

> [!NOTE]
> When you create a cluster using the Azure CLI, your user is [assigned built-in roles][aks-entra-rbac-builtin-roles] for `Azure Kubernetes Service RBAC Cluster Admin`.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSAutomaticCluster
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command. This command returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The following sample output shows how you're asked to log in:

    ```output
    To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code AAAAAAAAA to authenticate.
    ```

    After you log in, the following sample output shows the managed system node pools. Make sure the node status is _Ready_.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-nodepool1-12345678-vmss000000   Ready    agent   2m26s   v1.28.5
    aks-nodepool1-12345678-vmss000001   Ready    agent   2m26s   v1.28.5
    aks-nodepool1-12345678-vmss000002   Ready    agent   2m26s   v1.28.5
    ```

## Deploy the application

To deploy the application, you use a manifest file to create all the objects required to run the [AKS Store application](https://github.com/Azure-Samples/aks-store-demo). A [Kubernetes manifest file][kubernetes-deployment] defines a cluster's desired state, such as which container images to run. The manifest includes the following Kubernetes deployments and services:

:::image type="content" source="../learn/media/quick-kubernetes-deploy-portal/aks-store-architecture.png" alt-text="Screenshot of Azure Store sample architecture." lightbox="../learn/media/quick-kubernetes-deploy-portal/aks-store-architecture.png":::

- **Store front**: Web application for customers to view products and place orders.
- **Product service**: Shows product information.
- **Order service**: Places orders.
- **Rabbit MQ**: Message queue for an order queue.

> [!NOTE]
> We don't recommend running stateful containers, such as Rabbit MQ, without persistent storage for production. These are used here for simplicity, but we recommend using managed services, such as Azure Cosmos DB or Azure Service Bus.

1. Create a namespace `aks-store-demo` to deploy the Kubernetes resources into.

    ```bash
    kubectl create ns aks-store-demo
    ```

1. Deploy the application using the [`kubectl apply`][kubectl-apply] command into the `aks-store-demo` namespace. The YAML file defining the deployment is on [GitHub](https://github.com/Azure-Samples/aks-store-demo).

    ```bash
    kubectl apply -n aks-store-demo -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-ingress-quickstart.yaml
    ```

    The following sample output shows the deployments and services:

    ```output
    statefulset.apps/rabbitmq created
    configmap/rabbitmq-enabled-plugins created
    service/rabbitmq created
    deployment.apps/order-service created
    service/order-service created
    deployment.apps/product-service created
    service/product-service created
    deployment.apps/store-front created
    service/store-front created
    ingress/store-front created
    ```

## Test the application

When the application runs, a Kubernetes service exposes the application front end to the internet. This process can take a few minutes to complete.

1. Check the status of the deployed pods using the [kubectl get pods][kubectl-get] command. Make sure all pods are `Running` before proceeding. If this is the first workload you deploy, it may take a few minutes for [node auto provisioning][node-auto-provisioning] to create a node pool to run the pods.

    ```bash
    kubectl get pods -n aks-store-demo
    ```

1. Check for a public IP address for the store-front application. Monitor progress using the [kubectl get service][kubectl-get] command with the `--watch` argument.

    ```bash
    kubectl get ingress store-front -n aks-store-demo --watch
    ```

    The **ADDRESS** output for the `store-front` service initially shows empty:

    ```output
    NAME          CLASS                                HOSTS   ADDRESS        PORTS   AGE
    store-front   webapprouting.kubernetes.azure.com   *                      80      12m
    ```

1. Once the **ADDRESS** changes from blank to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

    The following sample output shows a valid public IP address assigned to the service:

    ```output
    NAME          CLASS                                HOSTS   ADDRESS        PORTS   AGE
    store-front   webapprouting.kubernetes.azure.com   *       4.255.22.196   80      12m
    ```

1. Open a web browser to the external IP address of your ingress to see the Azure Store app in action.

    :::image type="content" source="../learn/media/quick-kubernetes-deploy-cli/aks-store-application.png" alt-text="Screenshot of AKS Store sample application." lightbox="../learn/media/quick-kubernetes-deploy-cli/aks-store-application.png":::

## Delete the cluster

If you don't plan on going through the [AKS tutorial][aks-tutorial], clean up unnecessary resources to avoid Azure charges.

Remove the resource group, container service, and all related resources using the [`az group delete`][az-group-delete] command.

```azurecli-interactive
az group delete --name myResourceGroup --yes --no-wait
```

> [!NOTE]
> The AKS cluster was created with a system-assigned managed identity, which is the default identity option used in this quickstart. The platform manages this identity, so you don't need to manually remove it.

## Related content

In this quickstart, you deployed a Kubernetes cluster using [AKS Automatic][what-is-aks-automatic] and then deployed a simple multi-container application to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see [AKS solution guidance][aks-solution-guidance].

To learn more about AKS Automatic, see the [Introduction to Azure Kubernetes Service (AKS) Automatic][what-is-aks-automatic]

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[kubernetes-concepts]: ../concepts-clusters-workloads.md
[aks-tutorial]: ../tutorial-kubernetes-prepare-app.md
[azure-resource-group]: /azure/azure-resource-manager/management/overview
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-group-create]: /cli/azure/group#az-group-create
[az-group-delete]: /cli/azure/group#az-group-delete
[node-auto-provisioning]: ../node-autoprovision.md
[kubernetes-deployment]: ../concepts-clusters-workloads.md#deployments-and-yaml-manifests
[aks-solution-guidance]: /azure/architecture/reference-architectures/containers/aks-start-here?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
[az-provider-register]: /cli/azure/provider#az-provider-register
[what-is-aks-automatic]: ../intro-aks-automatic.md
[aks-entra-rbac]: ../entra-id-authorization.md
[aks-entra-rbac-builtin-roles]: ../entra-id-authorization.md#create-role-assignments-for-cluster-access
[policy-for-kubernetes]: /azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks
