---
title: Deploy an App with Dapr Extension for Kubernetes
description: Use the Dapr extension for Azure Kubernetes Service (AKS) or Arc-enabled Kubernetes to deploy an application.
author: greenie-msft
ms.author: nigreenf
ms.topic: quickstart
ms.subservice: dapr-aks
ms.date: 02/11/2026
ms.custom: template-quickstart, mode-other, devx-track-js, devx-track-python
ai-usage: ai-assisted
# Customer intent: As a cloud developer, I want to deploy a sample application using Dapr on Azure Kubernetes Service or Arc-enabled Kubernetes, so that I can learn how to configure microservices and integrate them with state management effectively.
---

# Quickstart: Deploy an application using the Dapr extension for Azure Kubernetes Service (AKS) or Arc-enabled Kubernetes

In this quickstart, you use the [Dapr extension][dapr-overview] in an AKS or Arc-enabled Kubernetes cluster. You deploy [a `hello world` example][hello-world-gh], which consists of a Python application that generates messages and a Node.js application that consumes and persists the messages.

## Prerequisites

- An Azure subscription. If you don't have one, you can [create a free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- [Azure CLI][azure-cli-install] installed
- An AKS cluster with:
  - [Workload identity][workload-identity] enabled
  - [Managed identity][managed-identity] created in the same subscription
  - [A Kubernetes service account][service-account]
  - [Federated identity credential][federated-identity-cred]
  - [Dapr extension][dapr-overview] installed on the AKS cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed locally

## Clone the repository

1. Clone the [Dapr quickstart repository][hello-world-gh] using the `git clone` command.

    ```bash
    git clone https://github.com/Azure-Samples/dapr-aks-extension-quickstart.git
    ```

1. Change to the `dapr-aks-extension-quickstart` directory. 

    ```bash
    cd dapr-aks-extension-quickstart
    ```

## Create and configure a Redis store

Open the [Azure portal][azure-portal-cache] to start the Azure Managed Redis creation flow. 

1. Fill out the recommended information according to the [Create an Azure Managed Redis instance][azure-managed-redis] quickstart.

1. Select **Create** to start the Redis instance deployment.

### Verify resource information

1. Once the Redis resource is deployed, navigate to its overview page. 

1. Take note of:
    - The hostname, found in the **Essentials** section of the resource overview page. The hostname format looks similar to: `<your-cache-name>.<region>.redis.azure.net`.
    - The SSL port, found in **Settings** > **Advanced settings**. The default value is `10000`.

1. In your terminal, enable access-key authentication on the default database.

   ```bash
   az redisenterprise database update \
       --cluster-name <REDIS_NAME> \
       --resource-group <RESOURCE_GROUP> \
       --access-keys-auth Enabled
   ```

1. Retrieve the primary key for the default database and save it to an environment variable.

   ```bash
   export REDIS_PRIMARY_KEY=$(az redisenterprise database list-keys \
       --cluster-name <REDIS_NAME> \
       --resource-group <RESOURCE_GROUP> \
       --query primaryKey \
       -o tsv)
   ```

### Enable public network access

For this scenario, your Azure Managed Redis instance uses public network access. Be sure to [clean up resources](#clean-up-resources) after you finish with this quickstart.

1. In the resource menu, under **Settings**, select **Networking**.

1. Set **Public network access** to **Enabled**.

## Configure the Dapr components

In the *redis.yaml* file, you configure the component to use access-key authentication with TLS. 

```yml
- name: redisPassword
    secretKeyRef:
        name: redis-secret
        key: redisPassword
- name: useEntraID
    value: "false"
- name: enableTLS
  value: true
```

1. In your preferred code editor, navigate to the *deploy* directory in the sample repo and open *redis.yaml*.

1. For `redisHost`, replace the placeholder `<REDIS_HOST>:10000` value with the Azure Managed Redis hostname [you saved earlier from the Azure portal](#verify-resource-information). 

   ```yml
   - name: redisHost
     value: <your-cache-name>.<region>.redis.azure.net:10000
   ```

1. Create the Kubernetes secret used by `redisPassword`.

   ```bash
   kubectl create secret generic redis-secret \
       --from-literal=redisPassword="$REDIS_PRIMARY_KEY"
   ```

### Apply the configuration

Apply the *redis.yaml* file using the `kubectl apply` command.

```bash
kubectl apply -f ./deploy/redis.yaml
```

**Expected output**

```output
component.dapr.io/statestore created
```

## Deploy the Node.js app with the Dapr sidecar

### Configure the Node.js app

1. Go to the `deploy` directory and open *workload-identity.yaml*.

1. Replace `<MANAGED_IDENTITY_CLIENT_ID>` with the client ID of the user-assigned managed identity you created.

1. Apply the service account manifest before you deploy app manifests.

    ```bash
    kubectl apply -f ./deploy/workload-identity.yaml
    ```

In *node.yaml*, the pod spec uses the workload identity label and the shared `workload-sa` service account:

```yaml
labels:
  app: node
  azure.workload.identity/use: "true"
```

### Apply the configuration

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

1. Make note of the `EXTERNAL-IP` in the output, and set it as an environment variable.

    ```bash
    export EXTERNAL_IP=<EXTERNAL-IP>
    ```

### Verify the Node.js service

1. Using `curl`, call the service with your `EXTERNAL-IP`.

    ```bash
    curl $EXTERNAL_IP/ports
    ```

    **Example output**

    ```output
    {"DAPR_HTTP_ENDPOINT":"http://localhost:3500","DAPR_GRPC_ENDPOINT":"http://localhost:50001"}
    ```

1. Submit an order to the application.

    ```bash
    curl --request POST --data "@sample.json" --header Content-Type:application/json $EXTERNAL_IP/neworder
    ```

1. Confirm the order.

    ```bash
    curl $EXTERNAL_IP/order
    ```

    **Expected output**

    ```output
    { "orderId": "42" }
    ```

## Deploy the Python app with the Dapr sidecar

### Configure the Python app

In *python.yaml*, the pod spec uses the workload identity label and the shared `workload-sa` service account:

```yaml
labels:
    app: python
    azure.workload.identity/use: "true"
```

### Apply the configuration

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

If you no longer plan to use the resources from this quickstart, you can remove the resource group, cluster, namespace, and all related resources using the [az group delete][az-group-delete] command.

```bash
az group delete --name <your-resource-group>
```

## Next step

> [!div class="nextstepaction"]
> [Install the Dapr extension][dapr-create-extension]

<!-- LINKS -->
<!-- INTERNAL -->
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-powershell-install]: /powershell/azure/install-az-ps
[cluster-extensions]: ./cluster-extensions.md
[dapr-overview]: ./dapr-overview.md
[az-group-delete]: /cli/azure/group#az-group-delete
[remove-azresourcegroup]: /powershell/module/az.resources/remove-azresourcegroup
[dapr-create-extension]: ./dapr.md
[workload-identity]: ./workload-identity-deploy-cluster.md#enable-oidc-issuer-and-microsoft-entra-workload-id-on-an-aks-cluster
[managed-identity]: ./workload-identity-deploy-cluster.md#create-a-managed-identity
[service-account]: ./workload-identity-deploy-cluster.md#create-a-kubernetes-service-account
[federated-identity-cred]: ./workload-identity-deploy-cluster.md#create-the-federated-identity-credential
[azure-managed-redis]: /azure/redis/quickstart-create-managed-redis

<!-- EXTERNAL -->
[hello-world-gh]: https://github.com/Azure-Samples/dapr-aks-extension-quickstart
[azure-portal-cache]: https://portal.azure.com/#create/Microsoft.Cache/redisEnterprise
[dapr-component-secrets]: https://docs.dapr.io/operations/components/component-secrets/

