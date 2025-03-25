---
title: 'Deploy a highly available PostgreSQL database on AKS with Azure CLI'
description: In this article, you deploy a highly available PostgreSQL database on AKS using the CloudNativePG operator.
ms.topic: how-to
ms.date: 06/07/2024
author: kenkilty
ms.author: kkilty
ms.custom: innovation-engine, aks-related-content
---

# Deploy a highly available PostgreSQL database on AKS

In this article, you deploy a highly available PostgreSQL database on AKS.

* If you haven't already created the required infrastructure for this deployment, follow the steps in [Create infrastructure for deploying a highly available PostgreSQL database on AKS][create-infrastructure] to get set up, and then you can return to this article.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Create secret for bootstrap app user

1. Generate a secret to validate the PostgreSQL deployment by interactive login for a bootstrap app user using the [`kubectl create secret`][kubectl-create-secret] command.

    ```bash
    PG_DATABASE_APPUSER_SECRET=$(echo -n | openssl rand -base64 16)

    kubectl create secret generic db-user-pass \
        --from-literal=username=app \
        --from-literal=password="${PG_DATABASE_APPUSER_SECRET}" \
        --namespace $PG_NAMESPACE \
        --context $AKS_PRIMARY_CLUSTER_NAME
    ```

1. Validate that the secret was successfully created using the [`kubectl get`][kubectl-get] command.

    ```bash
    kubectl get secret db-user-pass --namespace $PG_NAMESPACE --context $AKS_PRIMARY_CLUSTER_NAME
    ```

## Set environment variables for the PostgreSQL cluster

* Deploy a ConfigMap to set environment variables for the PostgreSQL cluster using the following [`kubectl apply`][kubectl-apply] command:

    ```bash
    cat <<EOF | kubectl apply --context $AKS_PRIMARY_CLUSTER_NAME -n $PG_NAMESPACE -f -
    apiVersion: v1
    kind: ConfigMap
    metadata:
        name: cnpg-controller-manager-config
    data:
        ENABLE_AZURE_PVC_UPDATES: 'true'
    EOF
    ```

## Install the Prometheus PodMonitors

Prometheus creates PodMonitors for the CNPG instances using a set of default recording rules stored on the CNPG GitHub samples repo. In a production environment, these rules would be modified as needed.

1. Add the Prometheus Community Helm repo using the [`helm repo add`][helm-repo-add] command.

    ```bash
    helm repo add prometheus-community \
        https://prometheus-community.github.io/helm-charts
    ```

2. Upgrade the Prometheus Community Helm repo and install it on the primary cluster using the [`helm upgrade`][helm-upgrade] command with the `--install` flag.

    ```bash
    helm upgrade --install \
        --namespace $PG_NAMESPACE \
        -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml \
        prometheus-community \
        prometheus-community/kube-prometheus-stack \
        --kube-context=$AKS_PRIMARY_CLUSTER_NAME
    ```

## Create a federated credential

In this section, you create a federated identity credential for PostgreSQL backup to allow CNPG to use AKS workload identity to authenticate to the storage account destination for backups. The CNPG operator creates a Kubernetes service account with the same name as the cluster named used in the CNPG Cluster deployment manifest.

1. Get the OIDC issuer URL of the cluster using the [`az aks show`][az-aks-show] command.

    ```bash
    export AKS_PRIMARY_CLUSTER_OIDC_ISSUER="$(az aks show \
        --name $AKS_PRIMARY_CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --query "oidcIssuerProfile.issuerUrl" \
        --output tsv)"
    ```

2. Create a federated identity credential using the [`az identity federated-credential create`][az-identity-federated-credential-create] command.

    ```bash
    az identity federated-credential create \
        --name $AKS_PRIMARY_CLUSTER_FED_CREDENTIAL_NAME \
        --identity-name $AKS_UAMI_CLUSTER_IDENTITY_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --issuer "${AKS_PRIMARY_CLUSTER_OIDC_ISSUER}" \
        --subject system:serviceaccount:"${PG_NAMESPACE}":"${PG_PRIMARY_CLUSTER_NAME}" \
        --audience api://AzureADTokenExchange
    ```

## Deploy a highly available PostgreSQL cluster

In this section, you deploy a highly available PostgreSQL cluster using the [CNPG Cluster custom resource definition (CRD)][cluster-crd].

### Cluster CRD parameters

The following table outlines the key properties set in the YAML deployment manifest for the Cluster CRD:

| Property | Definition |
| --------- | ------------ |
| `inheritedMetadata` | Specific to the CNPG operator. Metadata is inherited by all objects related to the cluster. |
| `annotations: service.beta.kubernetes.io/azure-dns-label-name` | DNS label for use when exposing the read-write and read-only Postgres cluster endpoints. |
| `labels: azure.workload.identity/use: "true"` | Indicates that AKS should inject workload identity dependencies into the pods hosting the PostgreSQL cluster instances. |
| `topologySpreadConstraints` | Require different zones and different nodes with label `"workload=postgres"`. |
| `resources` | Configures a Quality of Service (QoS) class of *Guaranteed*. In a production environment, these values are key for maximizing usage of the underlying node VM and vary based on the Azure VM SKU used. |
| `bootstrap` | Specific to the CNPG operator. Initializes with an empty app database. |
| `storage` / `walStorage` | Specific to the CNPG operator. Defines storage templates for the PersistentVolumeClaims (PVCs) for data and log storage. It's also possible to specify storage for tablespaces to shard out for increased IOPs. |
| `replicationSlots` | Specific to the CNPG operator. Enables replication slots for high availability. |
| `postgresql` | Specific to the CNPG operator. Maps settings for `postgresql.conf`, `pg_hba.conf`, and `pg_ident.conf config`. |
| `serviceAccountTemplate` | Contains the template needed to generate the service accounts and maps the AKS federated identity credential to the UAMI to enable AKS workload identity authentication from the pods hosting the PostgreSQL instances to external Azure resources. |
| `barmanObjectStore` | Specific to the CNPG operator. Configures the barman-cloud tool suite using AKS workload identity for authentication to the Azure Blob Storage object store. |

### PostgreSQL performance parameters

PostgreSQL performance heavily depends on your cluster's underlying resources. The following table provides some suggestions on how to calculate key parameters for high performance:

| Property | Recommended value | Definition |
| --------- | ------------ | -------------------- |
| `wal_compression` | lz4 | Compresses full-page writes written in WAL file with specified method |
| `max_wal_size` | 6GB | Sets the WAL size that triggers a checkpoint |
| `checkpoint_timeout` | 15min | Sets the maximum time between automatic WAL checkpoints |
| `checkpoint_flush_after` | 2MB | Number of pages after which previously performed writes are flushed to disk |
| `wal_writer_flush_after` | 2MB | Amount of WAL written out by WAL writer that triggers a flush |
| `min_wal_size` | 4GB | Sets the minimum size to shrink the WAL to |
| `shared_buffers` | 25% of node memory | Sets the number of shared memory buffers used by the server |
| `effective_cache_size` | 75% of node memory | Sets the planner's assumption about the total size of the data caches |
| `work_mem` | 1/256th of node memory | Sets the maximum memory to be used for query workspaces |
| `maintenance_work_mem` | 6.25% of node memory | Sets the maximum memory to be used for maintenance operations |
| `autovacuum_vacuum_cost_limit` | 2400 | Vacuum cost amount available before napping, for autovacuum |
| `random_page_cost` | 1.1 | Sets the planner's estimate of the cost of a nonsequentially fetched disk page |
| `effective_io_concurrency` | 64 | Number of simultaneous requests that can be handled efficiently by the disk subsystem |
| `maintenance_io_concurrency` | 64 | A variant of "effective_io_concurrency" that is used for maintenance work |

### Deploying PostgreSQL

1. Deploy the PostgreSQL cluster with the Cluster CRD using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    cat <<EOF | kubectl apply --context $AKS_PRIMARY_CLUSTER_NAME -n $PG_NAMESPACE -v 9 -f -
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: $PG_PRIMARY_CLUSTER_NAME
    spec:
      inheritedMetadata:
        annotations:
          service.beta.kubernetes.io/azure-dns-label-name: $AKS_PRIMARY_CLUSTER_PG_DNSPREFIX
          acstor.azure.com/accept-ephemeral-storage: "true"
        labels:
          azure.workload.identity/use: "true"

      instances: 3
      startDelay: 30
      stopDelay: 30
      minSyncReplicas: 1
      maxSyncReplicas: 1
      replicationSlots:
        highAvailability:
          enabled: true
        updateInterval: 30

      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            cnpg.io/cluster: $PG_PRIMARY_CLUSTER_NAME
            
      affinity:
        nodeSelector:
          workload: postgres

      resources:
        requests:
          memory: '8Gi'
          cpu: 2
        limits:
          memory: '8Gi'
          cpu: 2

      bootstrap:
        initdb:
          database: appdb
          owner: app
          secret:
            name: db-user-pass
          dataChecksums: true

      storage:
        size: 32Gi
        pvcTemplate:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 32Gi
          storageClassName: $POSTGRES_STORAGE_CLASS

      walStorage:
        size: 32Gi
        pvcTemplate:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 32Gi
          storageClassName: $POSTGRES_STORAGE_CLASS

      monitoring:
        enablePodMonitor: true

      postgresql:
        parameters:
          wal_compression: lz4
          max_wal_size: 6GB
          checkpoint_timeout: 15min
          checkpoint_flush_after: 2MB
          wal_writer_flush_after: 2MB
          min_wal_size: 4GB
          shared_buffers: 4GB
          effective_cache_size: 12GB
          work_mem: 62MB
          maintenance_work_mem: 1GB
          autovacuum_vacuum_cost_limit: 2400
          random_page_cost: 1.1
          effective_io_concurrency: 64
          maintenance_io_concurrency: 64
        pg_hba:
          - host all all all scram-sha-256

      serviceAccountTemplate:
        metadata:
          annotations:
            azure.workload.identity/client-id: "$AKS_UAMI_WORKLOAD_CLIENTID"
          labels:
            azure.workload.identity/use: "true"

      backup:
        barmanObjectStore:
          destinationPath: "https://${PG_PRIMARY_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/backups"
          azureCredentials:
            inheritFromAzureAD: true
        retentionPolicy: '7d'
    EOF
    ```

1. Validate that the primary PostgreSQL cluster was successfully created using the [`kubectl get`][kubectl-get] command. The CNPG Cluster CRD specified three instances, which can be validated by viewing running pods once each instance is brought up and joined for replication. Be patient as it can take some time for all three instances to come online and join the cluster.

    ```bash
    kubectl get pods --context $AKS_PRIMARY_CLUSTER_NAME --namespace $PG_NAMESPACE -l cnpg.io/cluster=$PG_PRIMARY_CLUSTER_NAME
    ```

    Example output

    ```output
    NAME                         READY   STATUS    RESTARTS   AGE
    pg-primary-cnpg-r8c7unrw-1   1/1     Running   0          4m25s
    pg-primary-cnpg-r8c7unrw-2   1/1     Running   0          3m33s
    pg-primary-cnpg-r8c7unrw-3   1/1     Running   0          2m49s
    ```

> [!IMPORTANT]  
> If you're using local NVMe with Azure Container Storage and your pod is stuck in the init state with a multi-attach error, it's likely still searching for the volume on a lost node. Once the pod starts running, it will enter a `CrashLoopBackOff` state because a new replica has been created on the new node without any data and CNPG cannot find the pgdata directory. To resolve this, you need to destroy the affected instance and bring up a new one. Run the following command:  
>  
> ```bash  
> kubectl cnpg destroy [cnpg-cluster-name] [instance-number]  
> ```  

### Validate the Prometheus PodMonitor is running

The CNPG operator automatically creates a PodMonitor for the primary instance using the recording rules created during the [Prometheus Community installation](#install-the-prometheus-podmonitors).

1. Validate the PodMonitor is running using the [`kubectl get`][kubectl-get] command.

    ```bash
    kubectl --namespace $PG_NAMESPACE \
        --context $AKS_PRIMARY_CLUSTER_NAME \
        get podmonitors.monitoring.coreos.com \
        $PG_PRIMARY_CLUSTER_NAME \
        --output yaml
    ```

    Example output

    ```output
     kind: PodMonitor
     metadata:
      annotations:
        cnpg.io/operatorVersion: 1.23.1
    ...
    ```

If you are using Azure Monitor for Managed Prometheus, you will need to add another pod monitor using the custom group name. Managed Prometheus does not pick up the custom resource definitions (CRDs) from the Prometheus community. Aside from the group name, the CRDs are the same. This allows pod monitors for Managed Prometheus to exist side-by-side those that use the community pod monitor. If you are not using Managed Prometheus, you can skip this. Create a new pod monitor:

```bash
cat <<EOF | kubectl apply --context $AKS_PRIMARY_CLUSTER_NAME --namespace $PG_NAMESPACE -f -
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: cnpg-cluster-metrics-managed-prometheus
  namespace: ${PG_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
    cnpg.io/cluster: ${PG_PRIMARY_CLUSTER_NAME}
spec:
  selector:
    matchLabels:
      azure.workload.identity/use: "true"
      cnpg.io/cluster: ${PG_PRIMARY_CLUSTER_NAME}
  podMetricsEndpoints:
    - port: metrics
EOF
```

Verify that the pod monitor is created (note the difference in the group name).

```bash
kubectl --namespace $PG_NAMESPACE \
    --context $AKS_PRIMARY_CLUSTER_NAME \
    get podmonitors.azmonitoring.coreos.com \
    -l cnpg.io/cluster=$PG_PRIMARY_CLUSTER_NAME \
    -o yaml
```

#### Option A - Azure Monitor Workspace

Once you have deployed the Postgres cluster and the pod monitor, you can view the metrics using the Azure portal in an Azure Monitor workspace.

:::image source="./media/deploy-postgresql-ha/prometheus-metrics.png" alt-text="Screenshot showing metrics in an Azure Monitor workspace." lightbox="./media/deploy-postgresql-ha/prometheus-metrics.png":::

#### Option B - Managed Grafana

Alternatively, Once you have deployed the Postgres cluster and pod monitors, you can create a metrics dashboard on the Managed Grafana instance created by the deployment script to visualize the metrics exported to the Azure Monitor workspace. You can access the Managed Grafana via the Azure portal. Navigate to the Managed Grafana instance created by the deployment script and click on the Endpoint link as shown here:

:::image source="./media/deploy-postgresql-ha/grafana-metrics-1.png" alt-text="Screenshot showing an Azure Managed Grafana instance." lightbox="./media/deploy-postgresql-ha/grafana-metrics-1.png":::

Clicking on the Endpoint link will cause a new browser window to open where you can create dashboards on the Managed Grafana instance. Following the instructions to [configure an Azure Monitor data source](/azure/azure-monitor/visualize/grafana-plugin#configure-an-azure-monitor-data-source-plug-in), you can then add visualizations to create a dashboard of metrics from the Postgres cluster. After setting up the data source connection, from the main menu, click the Data sources option and you should see a set of data source options for the data source connection as shown here:

:::image source="./media/deploy-postgresql-ha/grafana-metrics-2.png" alt-text="Screenshot showing data source options." lightbox="./media/deploy-postgresql-ha/grafana-metrics-2.png":::

On the Managed Prometheus option, click the option to build a dashboard to open the dashboard editor. Once the editor window opens, click the Add visualization option then click the Managed Prometheus option to browse the metrics from the Postgres cluster. Once you have selected the metric you want to visualize, click the Run queries button to fetch the data for the visualization as shown here:

:::image source="./media/deploy-postgresql-ha/grafana-metrics-3.png" alt-text="Screenshot showing construct dashboard." lightbox="./media/deploy-postgresql-ha/grafana-metrics-3.png":::

Click the Save button to add the panel to your dashboard. You can add other panels by clicking the Add button in the dashboard editor and repeating this process to visualize other metrics. Adding the metrics visualizations, you should have something that looks like this:

:::image source="./media/deploy-postgresql-ha/grafana-metrics-4.png" alt-text="Screenshot showing save dashboard." lightbox="./media/deploy-postgresql-ha/grafana-metrics-4.png":::

Click the Save icon to save your dashboard.

---

## Next steps

> [!div class="nextstepaction"]
> [Test and validate PostgreSQL database on AKS][validate-postgresql]

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Ken Kilty | Principal TPM
* Russell de Pina | Principal TPM
* Adrian Joian | Senior Customer Engineer
* Jenny Hayes | Senior Content Developer
* Carol Smith | Senior Content Developer
* Erin Schaffer | Content Developer 2
* Adam Sharif | Customer Engineer 2

<!-- LINKS -->

[helm-upgrade]: https://helm.sh/docs/helm/helm_upgrade/
[create-infrastructure]: ./create-postgresql-ha.md
[validate-postgresql]: ./validate-postgresql-ha.md
[kubectl-create-secret]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret/
[kubectl-get]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/
[kubectl-apply]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/
[helm-repo-add]: https://helm.sh/docs/helm/helm_repo_add/
[az-aks-show]: /cli/azure/aks#az_aks_show
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az_identity_federated_credential_create
[cluster-crd]: https://cloudnative-pg.io/documentation/1.23/cloudnative-pg.v1/#postgresql-cnpg-io-v1-ClusterSpec
