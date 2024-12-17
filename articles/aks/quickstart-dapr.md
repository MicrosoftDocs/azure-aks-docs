---
title: Deploy an application with the Dapr cluster extension for Azure Kubernetes Service (AKS) or Arc-enabled Kubernetes
description: Use the Dapr cluster extension for Azure Kubernetes Service (AKS) or Arc-enabled Kubernetes to deploy an application.
author: nickomang
ms.author: nickoman
ms.topic: quickstart
ms.date: 12/17/2024
ms.custom: template-quickstart, mode-other, devx-track-js, devx-track-python
---

# Quickstart: Deploy an application using the Dapr cluster extension for Azure Kubernetes Service (AKS) or Arc-enabled Kubernetes

In this quickstart, you use the [Dapr cluster extension][dapr-overview] in an AKS or Arc-enabled Kubernetes cluster. You deploy [a `hello world` example][hello-world-gh], which consists of a Python application that generates messages and a Node.js application that consumes and persists the messages.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- [Azure CLI][azure-cli-install] or [Azure PowerShell][azure-powershell-install] installed.
- An AKS Cluster with:
  - [Workload Identity][workload-identity] enabled.
  - [Managed identity][managed-identity]
  - [A Kubernetes service account][service-account]
  - [Federated identity credential][federated-identity-cred]
  - [Dapr cluster extension][dapr-overview] installed on the AKS cluster.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed locally.

## Clone the repository

1. Clone the [Dapr quickstarts repository][hello-world-gh] using the `git clone` command.

    ```bash
    git clone https://github.com/Azure-Samples/dapr-aks-extension-quickstart.git
    ```

1. Change to the `dapr-aks-extension-quickstart` directory. 

## Create and configure a Redis store

Open the [Azure portal][azure-portal-cache] to start the Azure Cache for Redis creation flow. 

1. Fill out the recommended information according to [the "Create an open-source Redis cache" quickstart instructions][azure-redis-cache].
1. Select **Create** to start the Redis instance deployment.

### Verify resource information

1. Once the Redis resource is deployed, navigate to its overview page. 
1. Take note of:
    - The hostname, found in the **Essentials** section of the overview page. The hostname format looks similar to: `xxxxxx.redis.cache.windows.net`.
    - The SSL port, found in the **Advanced Settings** blade. The default value is `6380`.
1. Navigate to the **Authentication** blade and verify Microsoft Entra Authentication has been enabled on your resource.

### Add managed identity

1. In the **Authentication** blade, start typing the name of the [Managed Identity you created as a prerequisite](#prerequisites) in the field under **Enable Microsoft Entra Authentication** checkbox. 
1. Verify your managed identity has been added as a Redis User assigned Data Owner Access Policy permissions.

### Enable public network access

For this scenario, your Redis cache will use public network access. Be sure to clean up resources when finished.

1. Navigate to the **Private Endpoint** blade. 
1. Click **Enable public network access** from the top menu.

## Configure the Dapr components

1. In your preferred code editor, navigate to the **deploy** directory in the sample and open `redis.yaml`.

1. For `redisHost`, replace the placeholder `<REDIS_HOST>:<REDIS_PORT>` value with the Redis cache hostname and SSL port [you saved earlier from Azure portal](#verify-resource-information). 

   ```yml
   - name: redisHost
   value: <your-cache-name>.redis.cache.windows.net:6380
   ```

In `redis.yaml`, note that the component is configured to use Entra ID Authentication using workload identity enabled for AKS cluster. No access keys are required. 

    ```yml
    - name: useEntraID
      value: "true"
    - name: enableTLS
      value: true
    ```

### Apply the configuration

Before continuing, make sure your AKS cluster is set up with workload identity, a Kubernetes service account, and federated identity credentials. 

1. Apply the `redis.yaml` file using the `kubectl apply` command.

    ```bash
    kubectl apply -f ./deploy/redis.yaml
    ```

1. Verify your state store was successfully configured using the `kubectl get components.redis` command.

    ```bash
    kubectl get components.redis -o yaml
    ```

    You should see output similar to the following example output:

    ```output
    component.dapr.io/statestore created
    ```

## Deploy the Node.js app with the Dapr sidecar

### Configure the Node.js app

1. Navigate to the **deploy** directory and open `node.yaml`.

1. Replace the placeholder `<SERVICE_ACCOUNT_NAME>` value for `serviceAccountName` with [the service account name you created][service-account]. 
   - This value should be the same service account you used to create the federated identity credential.

In `node.yaml`, note that the pod spec has [the label added to use workload identity,](./workload-identity-deploy-cluster.md#deploy-your-application):

    ```yaml
    labels:
      app: node
      azure.workload.identity/use: "true"
    ```

### Apply the configuration

This section deploys the Node.js app to Kubernetes. The Dapr control plane automatically injects the Dapr sidecar to the pod. If you take a look at the `node.yaml` file, you can see how Dapr is enabled for that deployment:

- `dapr.io/enabled: true`: tells the Dapr control plane to inject a sidecar to this deployment.
- `dapr.io/app-id: nodeapp`: assigns a unique ID or name to the Dapr application, so it can be sent messages to and communicated with by other Dapr apps.

1. Apply the Node.js app deployment to your cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f ./deploy/node.yaml
    ```

1. Kubernetes deployments are asynchronous, so before moving on to the next steps, verify the deployment is complete with the following command:

    ```bash
    kubectl rollout status deploy/nodeapp
    ```

1. Access your service using the `kubectl get svc` command.

    ```bash
    kubectl get svc nodeapp
    ```

1. Make note of the `EXTERNAL-IP` in the output.

### Verify the Node.js service

1. Using `curl`, call the service with your `EXTERNAL-IP`.

    ```bash
    curl $EXTERNAL_IP/ports
    ```

    **Example output**

    ```output
    {"DAPR_HTTP_PORT":"3500","DAPR_GRPC_PORT":"50001"}
    ```

1. Submit an order to the application.

    ```bash
    curl --request POST --data "@sample.json" --header Content-Type:application/json $EXTERNAL_IP/neworder
    ```

1. Confirm the order has persisted by requesting it.

    ```bash
    curl $EXTERNAL_IP/order
    ```

    **Expected output**

    ```output
    { "orderId": "42" }
    ```

## Deploy the Python app with the Dapr sidecar

### Configure the Python app

1. Navigate to the **deploy** directory and open `python.yaml`.

1. Replace the placeholder `<SERVICE_ACCOUNT_NAME>` value for `serviceAccountName` with [the service account name you created][service-account]. 
   - This value should be the same service account you used to create the federated identity credential.

In `python.yaml`, note that the pod spec has [the label added to use workload identity,](./workload-identity-deploy-cluster.md#deploy-your-application):

    ```yaml
    labels:
      app: node
      azure.workload.identity/use: "true"
    ```

### Apply the configuration

In the **python** directory, `app.py` is an example of a basic Python app that posts JSON messages to `localhost:3500`, which is the default listening port for Dapr. You can invoke the Node.js application's `neworder` endpoint by posting to `v1.0/invoke/nodeapp/method/neworder`. The message contains some data with an `orderId` that increments once per second:

    ```python
    n = 0
    while True:
        n += 1
        message = {"data": {"orderId": n}}

        try:
            response = requests.post(dapr_url, json=message)
        except Exception as e:
            print(e)

        time.sleep(1)
    ```

1. Deploy the Python app to your Kubernetes cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f ./deploy/python.yaml
    ```

1. Kubernetes deployments are asynchronous, so before moving on to the next steps, verify the deployment is complete with the following command:

    ```bash
    kubectl rollout status deploy/pythonapp
    ```

## Observe messages and confirm persistence

Now that both the Node.js and Python applications are deployed, you can watch messages come through.

1. Get the logs of the Node.js app using the `kubectl logs` command.

    ```bash
    kubectl logs --selector=app=node -c node --tail=-1
    ```

    **Expected output**

    ```output
    Got a new order! Order ID: 1
    Successfully persisted state
    Got a new order! Order ID: 2
    Successfully persisted state
    Got a new order! Order ID: 3
    Successfully persisted state
    ```

1. Using `curl`, call the Node.js app's order endpoint to get the latest order.

    ```bash
    curl $EXTERNAL_IP/order
    ```

    You should see the latest JSON output in the response.

## Clean up resources

If you no longer plan to use the resources from this quickstart, you can delete all associated resources by removing the resource group.

### [Azure CLI](#tab/azure-cli)

Remove the resource group, cluster, namespace, and all related resources using the [az group delete][az-group-delete] command.

    ```azurecli-interactive
    az group delete --name MyResourceGroup
    ```

### [Azure PowerShell](#tab/azure-powershell)

Remove the resource group, cluster, namespace, and all related resources using the [Remove-AzResourceGroup][remove-azresourcegroup] command.

    ```azurepowershell-interactive
    Remove-AzResourceGroup -Name MyResourceGroup
    ```

---

## Next steps

> [!div class="nextstepaction"]
> [Learn how to create the Dapr extension][dapr-create-extension]

<!-- LINKS -->
<!-- INTERNAL -->
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-powershell-install]: /powershell/azure/install-az-ps
[cluster-extensions]: ./cluster-extensions.md
[dapr-overview]: ./dapr-overview.md
[az-group-delete]: /cli/azure/group#az-group-delete
[remove-azresourcegroup]: /powershell/module/az.resources/remove-azresourcegroup
[dapr-create-extension]: ./dapr.md
[workload-identity]: ./workload-identity-deploy-cluster#create-an-aks-cluster
[managed-identity]: ./workload-identity-deploy-cluster#create-a-managed-identity
[service-account]: ./workload-identity-deploy-cluster#create-a-kubernetes-service-account
[federated-identity-cred]: ./workload-identity-deploy-cluster#create-the-federated-identity-credential
[azure-cache-redis]: /azure-cache-for-redis/quickstart-create-redis

<!-- EXTERNAL -->
[hello-world-gh]: https://github.com/Azure-Samples/dapr-aks-extension-quickstart
[azure-portal-cache]: https://portal.azure.com/#create/Microsoft.Cache
[dapr-component-secrets]: https://docs.dapr.io/operations/components/component-secrets/

