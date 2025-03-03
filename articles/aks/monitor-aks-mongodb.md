---
title: Monitoring for MongoDB cluster on Azure Kubernetes Service (AKS)
description: In this article, you learn how to monitor a MongoDB cluster on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 01/07/2025
author: schaffererin
ms.author: schaffererin
zone_pivot_groups: azure-cli-or-terraform
---

# Monitoring for MongoDB cluster on Azure Kubernetes Service (AKS)

In this article, you learn how to monitor a MongoDB cluster on Azure Kubernetes Service (AKS) using [Percona Monitoring and Management (PMM)][PMM]. Monitoring is essential for ensuring the health and performance of your MongoDB cluster. By monitoring key metrics, you can identify issues early and take corrective actions to prevent downtime and data loss.

## Set up Percona Monitoring and Management (PMM) for MongoDB

PMM operates as a client/server application, consisting of a [PMM Server][PMM-Server] and multiple [PMM Clients][PMM-Client] installed on each node of the database you want to monitor. The PMM Clients gather essential metrics and transmit this data to the PMM Server. You can then connect to the PMM Server to view database metrics across various dashboards.

### Enable monitoring Percona Server for MongoDB with PMM

1. To enable monitoring for Percona Server for MongoDB, you need to make sure that the `pmm.enabled` field is set to `true` in the PerconaServerMongoDB custom resource. You can check this setting using the `kubectl describe` command.

    ```bash
    kubectl describe PerconaServerMongoDB ${AKS_MONGODB_CLUSTER_NAME} -n ${AKS_MONGODB_NAMESPACE}
    ```

    Example output:

    ```output
    Name:         cluster-aks-mongodb
    Namespace:    mongodb
    ...
    Spec:
      ...
      Pmm:
        Enabled:      true
        Image:        <your-acr-name>.azurecr.io/pmm-client:2.41.2
        Server Host:  monitoring-service
      ...
    ```

2. If the `pmm.enabled` field is set to `false`, you can enable it using the `kubectl patch` command.

    ```bash
    kubectl patch PerconaServerMongoDB ${AKS_MONGODB_CLUSTER_NAME} -n ${AKS_MONGODB_NAMESPACE} --type='merge' -p '{"spec":{"pmm":{"enabled":true}}}'
    ```

### Create a node pool for PMM server

:::zone pivot="azure-cli"

Create a dedicated node pool for the PMM server using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command.

```azurecli-interactive
az aks nodepool add \
--resource-group $MY_RESOURCE_GROUP_NAME \
--cluster-name $MY_CLUSTER_NAME \
--name pmmsrvpool \
--node-vm-size Standard_DS4_v2 \
--node-count 3 \
--zones 1 2 3 \
--mode User \
--output table
```
:::zone-end

:::zone pivot="terraform"

Create a dedicated node pool for the PMM server using terraform.

1. Run the following command to update the `mongodb.tfvars` file created earlier with the following configuration:

      ```bash
      sed -i '/mongodbserver = {/,/}/s/^\( *}\)/  }, \
      pmmserver = {\
        name       = "pmmsrvpool" \
        vm_size    = "Standard_D2ds_v4" \
        node_count = 3 \
        zones      = [1, 2, 3] \
        os_type    = "Linux" \
      }/' mongodb.tfvars
      ```

2. Apply the terraform configuration to the target resource.
    ```bash
    terraform fmt
    terraform apply -var-file="mongodb.tfvars" -target module.default
    ```

:::zone-end
## Install PMM server

1. Add and update the Percona Helm repository using the `helm repo add` and `helm repo update` commands.

    ```bash
    helm repo add percona https://percona.github.io/percona-helm-charts/
    helm repo update
    ```

2. Install the PMM server using the `helm install` command.

    ```bash
    helm install pmm --namespace mongodb \
    --set nodeSelector."kubernetes\.azure\.com/agentpool"="pmmsrvpool" \
    --set service.type="LoadBalancer" \
    --version 1.3.13 \
    percona/pmm
    ```

3. Get the external IP address of the PMM server using the `kubectl get svc` command.

    ```bash
    export SERVICE_IP=$(kubectl get svc --namespace mongodb monitoring-service -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
      echo https://$SERVICE_IP:
    ```

4. Get the password for the admin user using the `kubectl get secret` command.

    ```bash
      export ADMIN_PASS=$(kubectl get secret pmm-secret --namespace mongodb -o jsonpath='{.data.PMM_ADMIN_PASSWORD}' | base64 --decode)
      echo $ADMIN_PASS
    ```

5. You can now access the PMM server by using the external IP address and the "admin" user password. You can also access the PMM server on your local machine using the `kubectl port-forward` command.

    ```bash
    kubectl port-forward svc/monitoring-service -n mongodb 8080:80
    ```

6. Once port forwarding is enabled, you can access the PMM server by navigating to `http://localhost:8080`.

## Configure PMM server

1. Access the PMM server using the admin user and the password you obtained earlier.
2. From the side menu, select **Configuration** > **API keys**.

   :::image type="content" source="media/monitor-aks-mongodb/pmm-api-keys-menu.png" alt-text="Screenshot of a web page showing the PMM Mongodb dashboard menu.":::

3. On the *Configuration* page, select **Add API Key**.
4. Enter the following information:

    * Key name (you can give any desired name)
    * Select the Admin role from the drop-down
    * Enter a value in the Time to live text box (hover on the tooltip for more information)

   :::image type="content" source="media/monitor-aks-mongodb/pmm-api-key-generated.png" alt-text="Screenshot of a web page showing the PMM Mongodb dashboard with API key generated.":::

5. Select **Add**.
6. Copy your key from the *API Key Created window* and export it to the environment variable as shown below.

   ```bash
   export API_KEY="Paste your API Key here"
   ```

### Set API key as secret and refresh ExternalSecret resource with the new secret

:::zone pivot="azure-cli"
1. Set the API key as a secret in Azure Key Vault using the following command.  

    ```azurecli-interactive
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name PMM-SERVER-API-KEY --value $API_KEY --output table
    ```
    
:::zone-end

:::zone pivot="terraform"

1. Run the following command to update the `mongodb.tfvars` file created earlier and apply the terraform configuration to the target resource with the following commands:
    ```bash
    sed -i "/mongodb_kv_secrets = {/,/^ *}/s/\(PMM-SERVER-API-KEY *= *\"\)[^\"]*\"/\1$API_KEY\"/" mongodb.tfvars

    terraform fmt
    
    terraform apply -var-file="mongodb.tfvars" -target module.mongodb[0].azurerm_key_vault_secret.this
    ```  
:::zone-end


2. Refresh the secret in the ExternalSecret resource with the new secret key using the `kubectl annotate` command.

    ```bash
    kubectl annotate es ${AKS_MONGODB_SECRETS_NAME} force-sync=$(date +%s) --overwrite -n ${AKS_MONGODB_NAMESPACE}
    ```

## Test PMM server

Once you configure the PMM server, you can generate test data using Locust, as described in [Validate resiliency of MongoDB cluster on Azure Kubernetes Service (AKS)][resiliency-mongodb]. After generating test data, you can monitor the performance of your MongoDB cluster on the PMM server.

:::image type="content" source="media/monitor-aks-mongodb/pmm-mongodb-1.png" alt-text="Screenshot of a web page showing the PMM Mongodb dashboard.":::

:::image type="content" source="media/monitor-aks-mongodb/pmm-mongodb-2.png" alt-text="Screenshot of another web page showing the PMM Mongodb dashboard.":::

## Next steps

In this article, you learned how to monitor a MongoDB cluster on Azure Kubernetes Service (AKS) using Percona Monitoring and Management (PMM). To learn more about deploying stateful workloads on AKS, see the following articles:

* [Deploy a highly available PostgreSQL database on Azure Kubernetes Service (AKS)](./postgresql-ha-overview.md)
* [Deploy a Valkey cluster on Azure Kubernetes Service (AKS)](./valkey-overview.md)
* [Deploy Apache Airflow on Azure Kubernetes Service (AKS)](./airflow-overview.md)

<!-- LINKS - external -->
[PMM]: https://docs.percona.com/percona-operator-for-mongodb/monitoring.html
[PMM-Server]: https://docs.percona.com/percona-monitoring-and-management/details/architecture.html#pmm-server
[PMM-Client]: https://docs.percona.com/percona-monitoring-and-management/details/architecture.html#pmm-client
[resiliency-mongodb]: ./resiliency-mongodb-cluster.md
