---
title: Deploy and run workflows with the Dapr extension for Azure Kubernetes Service (AKS)
description: Learn how to deploy and run Dapr Workflow on your Azure Kubernetes Service (AKS) clusters via the Dapr extension.
author: hhunter-ms
ms.author: hannahhunter
ms.reviewer: nuversky
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 11/11/2025
ms.subservice: aks-developer
ms.custom: devx-track-azurecli
# Customer intent: As a developer, I want to deploy and run Dapr Workflows on Azure Kubernetes Service, so that I can efficiently orchestrate microservices and handle state management in my applications.
---

# Deploy and run workflows with the Dapr extension for Azure Kubernetes Service (AKS)

With Dapr Workflow, you can easily orchestrate messaging, state management, and failure-handling logic across various microservices. Dapr Workflow can help you create long-running, fault-tolerant, and stateful applications.  

In this guide, you use the [provided order processing workflow example][dapr-workflow-sample] to:

> [!div class="checklist"]
> - Create an Azure Container Registry and an AKS cluster for this sample.
> - Install the Dapr extension on your AKS cluster.
> - Deploy the sample application to AKS. 
> - Start and query workflow instances using HTTP API calls.

The workflow example is an ASP.NET Core project with:
- A [`Program.cs` file][dapr-program] that contains the setup of the app, including the registration of the workflow and workflow activities.
- Workflow definitions found in the [`Workflows` directory][dapr-workflow-dir].
- Workflow activity definitions found in the [`Activities` directory][dapr-activities-dir].

## Prerequisites

- An [Azure subscription](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) with Owner or Admin role.
- [An Azure Kubernetes Service Role-Based Access Control Admin role](/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-rbac-admin) 
- The latest version of the [Azure CLI][install-cli]
- The latest version of [Dapr][dapr]
- Latest [Docker][docker]
- Latest [Helm][helm]

## Set up the environment

### Clone the sample project

Clone the example workflow application. 

```sh
git clone https://github.com/Azure-Samples/dapr-workflows-aks-sample.git
```

Navigate to the sample's root directory.

```sh
cd dapr-workflows-aks-sample
```

### Create a Kubernetes cluster

Create a resource group to hold the AKS cluster.

```sh
az group create --name myResourceGroup --location eastus
```

Create an AKS cluster.

```sh
az aks create --resource-group myResourceGroup --name myAKSCluster --node-count 2 --generate-ssh-keys 
```

[Make sure `kubectl` is installed and pointed to your AKS cluster.][kubectl] If you use the Azure Cloud Shell, `kubectl` is already installed. 

For more information, see the [Deploy an AKS cluster][cluster] tutorial.

## Deploy the application to AKS

### Install Dapr on your AKS cluster

Install the Dapr extension on your AKS cluster. Before you start, make sure you have:
- [Installed or updated the `k8s-extension`][k8s-ext]. 
- [Registered the `Microsoft.KubernetesConfiguration` service provider][k8s-sp]

```sh
az k8s-extension create --cluster-type managedClusters --cluster-name myAKSCluster --resource-group myResourceGroup --name dapr --extension-type Microsoft.Dapr
```

After a few minutes, you'll see output showing the Dapr connection to your AKS cluster. Next, initialize Dapr on your cluster.

```sh
dapr init -k
```

Verify Dapr is installed:

```sh
kubectl get pods -A
```

### Deploy the Redis Actor state store component

Navigate to the `Deploy` directory in your forked version of the sample:

```sh
cd Deploy
```

Deploy the Redis component:

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis
kubectl apply -f redis.yaml
```

### Run the application

Once Redis is deployed, deploy the application to AKS:

```sh
kubectl apply -f deployment.yaml
```

Expose the Dapr sidecar and the sample app:

```sh
kubectl apply -f service.yaml
export APP_URL=$(kubectl get svc/workflows-sample -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DAPR_URL=$(kubectl get svc/workflows-sample-dapr -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Verify that the above commands were exported:

```sh
echo $APP_URL
echo $DAPR_URL
```

## Start the workflow

Now that the application and Dapr are deployed to the AKS cluster, you can now start and query workflow instances. Restock items in the inventory using the following API call to the sample app:

```sh
curl -X GET $APP_URL/stock/restock
```

Start the workflow:

```sh
curl -i -X POST $DAPR_URL/v1.0/workflows/dapr/OrderProcessingWorkflow/start \
  -H "Content-Type: application/json" \
  -H "dapr-app-id: dwf-app" \
  -d '{"Name": "Paperclips", "TotalCost": 99.95, "Quantity": 1}'
```

Expected output includes an auto-generated instance ID:

```
HTTP/1.1 202 Accepted
Content-Type: application/json
Traceparent: 00-00000000000000000000000000000000-0000000000000000-00
Date: Tue, 23 Apr 2024 15:35:00 GMT
Content-Length: 21

 {"instanceID":"<generated-id>"}
```

Check the workflow status:

```sh
curl -i -X GET $DAPR_URL/v1.0/workflows/dapr/OrderProcessingWorkflow/<instance-id> \
  -H "dapr-app-id: dwf-app"
```

Expected output:

```json
HTTP/1.1 200 OK
Content-Type: application/json
Traceparent: 00-00000000000000000000000000000000-0000000000000000-00
Date: Tue, 23 Apr 2024 15:51:02 GMT
Content-Length: 580
```

Monitor the application logs:

```sh
kubectl logs -l run=workflows-sample -c workflows-sample --tail=20
```

Expected output:

```
{
  "instanceID":"1234",
  "workflowName":"OrderProcessingWorkflow",
  "createdAt":"2024-04-23T15:35:00.156714334Z",
  "lastUpdatedAt":"2024-04-23T15:35:00.176459055Z",
  "runtimeStatus":"COMPLETED",
  "dapr.workflow.input":"{ \"input\" : {\"Name\": \"Paperclips\", \"TotalCost\": 99.95, \"Quantity\": 1}}",
  "dapr.workflow.output":"{\"Processed\":true}"
}
```

Notice that the workflow status is marked as completed.

## Next steps

- [Configure the Dapr extension on your AKS cluster][dapr-config].
- [Determine if you need to migrate from Dapr open source to the Dapr extension][dapr-migration].

<!-- Links Internal -->
[deploy-cluster]: ./tutorial-kubernetes-deploy-cluster.md
[install-cli]: /cli/azure/install-azure-cli
[k8s-ext]: ./dapr.md#add-the-azure-cli-extension-for-cluster-extensions
[cluster]: ./tutorial-kubernetes-deploy-cluster.md
[k8s-sp]: ./dapr.md#register-the-kubernetesconfiguration-resource-provider
[dapr-config]: ./dapr-settings.md
[dapr-migration]: ./dapr-migration.md
[kubectl]: ./tutorial-kubernetes-deploy-cluster.md#connect-to-cluster-using-kubectl

<!-- Links External -->
[dapr-program]: https://github.com/Azure-Samples/dapr-workflows-aks-sample/blob/main/Program.cs
[dapr-workflow-sample]: https://github.com/Azure-Samples/dapr-workflows-aks-sample
[dapr-workflow-dir]: https://github.com/Azure-Samples/dapr-workflows-aks-sample/blob/main/Workflows/OrderProcessingWorkflow.cs
[dapr-activities-dir]: https://github.com/Azure-Samples/dapr-workflows-aks-sample/tree/main/Activities
[deployment-yaml]: https://github.com/Azure/dapr-workflows-aks-sample/blob/main/Deploy/deployment.yaml
[docker]: https://docs.docker.com/get-docker/
[helm]: https://helm.sh/docs/intro/install/
[dapr]: https://docs.dapr.io/getting-started/install-dapr-cli/
