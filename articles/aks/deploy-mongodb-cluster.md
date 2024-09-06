---
title: 'Configure and deploy a MongoDB cluster on Azure Kubernetes Service (AKS)'
description: In this article, you configure and deploy a MongoDB cluster on AKS.
ms.topic: how-to
ms.date: 09/05/2024
author: fossygirl
ms.author: carols
ms.custom: aks-related-content
---

# Configure and deploy a MongoDB cluster on Azure Kubernetes Service (AKS)

In this article, we configure and deploy a MongoDB cluster on Azure Kubernetes Service (AKS).

## Configure workload identity

1. Create a namespace for the MongoDB cluster using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace ${AKS_MONGODB_NAMESPACE} --dry-run=client --output yaml | kubectl apply -f -
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    namespace/mongodb created
    ```

2. Create a service account and configure workload identity using the `kubectl apply` command.

    ```bash
    export TENANT_ID=$(az account show --query tenantId -o tsv)
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      annotations:
        azure.workload.identity/client-id: "${MY_IDENTITY_NAME_CLIENT_ID}"
        azure.workload.identity/tenant-id: "${TENANT_ID}"
      name: "${SERVICE_ACCOUNT_NAME}"
      namespace: "${AKS_MONGODB_NAMESPACE}"
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
     ```output
    serviceaccount/mongodb created
    ```

## Install the External Secrets Operator

In this section, we use Helm to install the External Secrets Operator. The External Secrets Operator is a Kubernetes operator that manages the lifecycle of external secrets stored in external secret stores like Azure Key Vault.

1. Add the External Secrets Helm repository and update the repository using the `helm repo add` and `helm repo update` commands.

    ```bash
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    ```

    Example output:
    <!-- expected_similarity=0.1 -->
    ```output
    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "external-secrets" chart repository
    ```

2. Install the External Secrets Operator using the `helm install` command.

    ```bash
    helm install external-secrets \
    external-secrets/external-secrets \
    --namespace ${AKS_MONGODB_NAMESPACE} \
    --create-namespace \
    --set installCRDs=true \
    --wait
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME: external-secrets
    LAST DEPLOYED: Tue Jun 11 11:55:32 2024
    NAMESPACE: mongodb
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    external-secrets has been deployed successfully in namespace mongodb!
    
    In order to begin using ExternalSecrets, you will need to set up a SecretStore
    or ClusterSecretStore resource (for example, by creating a 'vault' SecretStore).
    
    More information on the different types of SecretStores and how to configure them
    can be found in our Github: https://github.com/external-secrets/external-secrets
    ```

3. Generate a random password for the mongodb cluster and store it in your Azure Key Vault using the [`az keyvault secret set`](/cli/azure/keyvault/secret#az-keyvault-secret-set) command.

    ```azurecli-interactive
    #MongoDB connection strings can contain special characters in the password which need to be URL encoded. 
    #This is because the connection string is a URI, and special characters can interfere with the URI structure.
    #This function generates secrets of 32 characters using only alphanumeric characters

    generateRandomPasswordString() {
        cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
    }

    #The following script will generate random passwords and store them as secrets in the Key Vault.
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-BACKUP-USER --value MONGODB_BACKUP_USER --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-BACKUP-PASSWORD --value $(generateRandomPasswordString) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-DATABASE-ADMIN-USER --value MONGODB_DATABASE_ADMIN_USER --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-DATABASE-ADMIN-PASSWORD --value $(generateRandomPasswordString) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-CLUSTER-ADMIN-USER --value MONGODB_CLUSTER_ADMIN_USER --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-CLUSTER-ADMIN-PASSWORD --value $(generateRandomPasswordString) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-CLUSTER-MONITOR-USER --value MONGODB_CLUSTER_MONITOR_USER --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-CLUSTER-MONITOR-PASSWORD --value $(generateRandomPasswordString) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-USER-ADMIN-USER --value MONGODB_USER_ADMIN_USER --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name MONGODB-USER-ADMIN-PASSWORD --value $(generateRandomPasswordString) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name PMM-SERVER-API-KEY --value $(openssl rand -base64 32) --output table
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AZURE-STORAGE-ACCOUNT-NAME --value $AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME --output table
    ```

    Example output:
    <!-- expected_similarity=0.5 -->
    ```output
    Name                Value
    ------------------  --------------------------------------------
    PMM-SERVER-API-KEY  KH4uE6MlJ6fbhVbVT5sz...
    ```

## Create secrets

1. Create a `SecretStore` resource to access the MongoDB passwords stored in your key vault using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: azure-store
      namespace: ${AKS_MONGODB_NAMESPACE}
    spec:
      provider:
        # provider type: azure keyvault
        azurekv:
          authType: WorkloadIdentity
          vaultUrl: "${KEYVAULTURL}"
          serviceAccountRef:
            name: ${SERVICE_ACCOUNT_NAME}
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    secretstore.external-secrets.io/azure-store created
    ```

2. Create an `ExternalSecret` resource, which creates a Kubernetes `Secret` in the `mongodb` namespace with the `MongoDB` secrets stored in your key vault, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${AKS_MONGODB_SECRETS_NAME}
      namespace: ${AKS_MONGODB_NAMESPACE}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: SecretStore
        name: azure-store

      target:
        name: "${AKS_MONGODB_SECRETS_NAME}"
        creationPolicy: Owner

      data:
        # name of the SECRET in the Azure KV (no prefix is by default a SECRET)
        - secretKey: MONGODB_BACKUP_USER
          remoteRef:
            key: MONGODB-BACKUP-USER
        - secretKey: MONGODB_BACKUP_PASSWORD
          remoteRef:
            key: MONGODB-BACKUP-PASSWORD
        - secretKey: MONGODB_DATABASE_ADMIN_USER
          remoteRef:
            key: MONGODB-DATABASE-ADMIN-USER
        - secretKey: MONGODB_DATABASE_ADMIN_PASSWORD
          remoteRef:
            key: MONGODB-DATABASE-ADMIN-PASSWORD
        - secretKey: MONGODB_CLUSTER_ADMIN_USER
          remoteRef:
            key: MONGODB-CLUSTER-ADMIN-USER
        - secretKey: MONGODB_CLUSTER_ADMIN_PASSWORD
          remoteRef:
            key: MONGODB-CLUSTER-ADMIN-PASSWORD
        - secretKey: MONGODB_CLUSTER_MONITOR_USER
          remoteRef:
            key: MONGODB-CLUSTER-MONITOR-USER
        - secretKey: MONGODB_CLUSTER_MONITOR_PASSWORD
          remoteRef:
            key: MONGODB-CLUSTER-MONITOR-PASSWORD
        - secretKey: MONGODB_USER_ADMIN_USER
          remoteRef:
            key: MONGODB-USER-ADMIN-USER
        - secretKey: MONGODB_USER_ADMIN_PASSWORD
          remoteRef:
            key: MONGODB-USER-ADMIN-PASSWORD
        - secretKey: PMM_SERVER_API_KEY
          remoteRef:
            key: PMM-SERVER-API-KEY
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    externalsecret.external-secrets.io/cluster-aks-mongodb-secrets created
    ```

3. Create an `ExternalSecret` resource, which creates a Kubernetes `Secret` in the `mongodb` namespace for `Azure Blob Storage` secrets stored in your key vault, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${AKS_AZURE_SECRETS_NAME}
      namespace: ${AKS_MONGODB_NAMESPACE}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: SecretStore
        name: azure-store

      target:
        name: "${AKS_AZURE_SECRETS_NAME}"
        creationPolicy: Owner

      data:
        # name of the SECRET in the Azure KV (no prefix is by default a SECRET)
        - secretKey: AZURE_STORAGE_ACCOUNT_NAME
          remoteRef:
            key: AZURE-STORAGE-ACCOUNT-NAME
        - secretKey: AZURE_STORAGE_ACCOUNT_KEY
          remoteRef:
            key: AZURE-STORAGE-ACCOUNT-KEY
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    externalsecret.external-secrets.io/cluster-aks-azure-secrets created
    ```

4. Create a federated credential using the [`az identity federated-credential create`](/cli/azure/identity/federated-credential#az-identity-federated-credential-create) command.

    ```azurecli-interactive
    az identity federated-credential create \
                --name external-secret-operator \
                --identity-name ${MY_IDENTITY_NAME} \
                --resource-group ${MY_RESOURCE_GROUP_NAME} \
                --issuer ${OIDC_URL} \
                --subject system:serviceaccount:${AKS_MONGODB_NAMESPACE}:${SERVICE_ACCOUNT_NAME} \
                --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Issuer                                                                                                                   Name                      ResourceGroup                     Subject
    -----------------------------------------------------------------------------------------------------------------------  ------------------------  --------------------------------  -------------------------------------
    https://australiaeast.oic.prod-aks.azure.com/07fa200c-6006-411f-bb29-a43bdf1a2bcc/d0709689-42d4-49a4-a6c8-5caa0b2384ba/  external-secret-operator  myResourceGroup-rg-australiaeast  system:serviceaccount:mongodb:mongodb
    ```

5. Give permission to the user-assigned identity to access the secret using the [`az keyvault set-policy`](/cli/azure/keyvault#az-keyvault-set-policy) command.

    ```bash
    az keyvault set-policy --name $MY_KEYVAULT_NAME --object-id $MY_IDENTITY_NAME_PRINCIPAL_ID --secret-permissions get --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location       Name            ResourceGroup
    -------------  --------------  --------------------------------
    australiaeast  vault-cjcfc-kv  myResourceGroup-rg-australiaeast
    ```

## Install the Percona Operator and CRDS

The Percona Operator is typically distributed as a Kubernetes `Deployment` or `Operator`. You can deploy it using a `kubectl apply -f` command with a manifest file. You can find the latest manifests in the [Percona GitHub repository](https://github.com/percona/percona-server-mongodb-operator) or [official documentation](https://docs.percona.com/percona-operator-for-mongodb/aks.html).

```bash
#Deploy the Operator and crds
kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mongodb-operator/v1.16.0/deploy/bundle.yaml -n "${AKS_MONGODB_NAMESPACE}"
```

``` Example output:
<!-- expected_similarity=0.8 -->
```output
customresourcedefinition.apiextensions.k8s.io/perconaservermongodbbackups.psmdb.percona.com serverside-applied
customresourcedefinition.apiextensions.k8s.io/perconaservermongodbrestores.psmdb.percona.com serverside-applied
customresourcedefinition.apiextensions.k8s.io/perconaservermongodbs.psmdb.percona.com serverside-applied
role.rbac.authorization.k8s.io/percona-server-mongodb-operator serverside-applied
serviceaccount/percona-server-mongodb-operator serverside-applied
rolebinding.rbac.authorization.k8s.io/service-account-percona-server-mongodb-operator serverside-applied
deployment.apps/percona-server-mongodb-operator serverside-applied
```

## Deploy the MongoDB cluster

 1. We deploy a MongoDB cluster with the Percona Operator. To ensure high availability, the MongoDB cluster is deployed with a replica set, sharding enabled and in multiple availability zones. The MongoDB cluster is deployed with a backup solution that stores the backups in an Azure Blob storage account.

The script deploys a MongoDB cluster with the following configuration:

```bash
kubectl apply -f - <<EOF
apiVersion: psmdb.percona.com/v1
kind: PerconaServerMongoDB
metadata:
  name: ${AKS_MONGODB_CLUSTER_NAME}
  namespace: ${AKS_MONGODB_NAMESPACE}
  finalizers:
    - delete-psmdb-pods-in-order
spec:
  crVersion: 1.16.0
  image: ${MY_ACR_REGISTRY}.azurecr.io/percona-server-mongodb:7.0.8-5
  imagePullPolicy: Always
  updateStrategy: SmartUpdate
  upgradeOptions:
    versionServiceEndpoint: https://check.percona.com
    apply: disabled
    schedule: "0 2 * * *"
    setFCV: false
  secrets:
    users: "${AKS_MONGODB_SECRETS_NAME}"
    encryptionKey: "${AKS_MONGODB_SECRETS_ENCRYPTION_KEY}"
  pmm:
    enabled: false
    image: ${MY_ACR_REGISTRY}.azurecr.io/pmm-client:2.41.2
    serverHost: monitoring-service
  replsets:
    - name: rs0
      size: 3
      affinity:
        antiAffinityTopologyKey: "failure-domain.beta.kubernetes.io/zone"
      podDisruptionBudget:
        maxUnavailable: 1
      expose:
        enabled: false
        exposeType: ClusterIP
      resources:
        limits:
          cpu: "300m"
          memory: "0.5G"
        requests:
          cpu: "300m"
          memory: "0.5G"
      volumeSpec:
        persistentVolumeClaim:
          storageClassName: managed-csi-premium
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
      nonvoting:
        enabled: false
        size: 3
        affinity:
          antiAffinityTopologyKey: "failure-domain.beta.kubernetes.io/zone"
        podDisruptionBudget:
          maxUnavailable: 1
        resources:
          limits:
            cpu: "300m"
            memory: "0.5G"
          requests:
            cpu: "300m"
            memory: "0.5G"
        volumeSpec:
          persistentVolumeClaim:
            storageClassName: managed-csi-premium
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 1Gi
      arbiter:
        enabled: false
        size: 1
        affinity:
          antiAffinityTopologyKey: "failure-domain.beta.kubernetes.io/zone"
        resources:
          limits:
            cpu: "300m"
            memory: "0.5G"
          requests:
            cpu: "300m"
            memory: "0.5G"
  sharding:
    enabled: true
    configsvrReplSet:
      size: 3
      affinity:
        antiAffinityTopologyKey: "failure-domain.beta.kubernetes.io/zone"
      podDisruptionBudget:
        maxUnavailable: 1
      expose:
        enabled: false
      resources:
        limits:
          cpu: "300m"
          memory: "0.5G"
        requests:
          cpu: "300m"
          memory: "0.5G"
      volumeSpec:
        persistentVolumeClaim:
          storageClassName: managed-csi-premium
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
    mongos:
      size: 3
      affinity:
        antiAffinityTopologyKey: "failure-domain.beta.kubernetes.io/zone"
      podDisruptionBudget:
        maxUnavailable: 1
      resources:
        limits:
          cpu: "300m"
          memory: "0.5G"
        requests:
          cpu: "300m"
          memory: "0.5G"
      expose:
        exposeType: ClusterIP
  backup:
    enabled: true
    image: ${MY_ACR_REGISTRY}.azurecr.io/percona-backup-mongodb:2.4.1
    storages:
      azure-blob:
        type: azure
        azure:
          container: "${AKS_MONGODB_BACKUP_STORAGE_CONTAINER_NAME}"
          prefix: psmdb
          endpointUrl: https://${AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME}.blob.core.windows.net
          credentialsSecret: "${AKS_AZURE_SECRETS_NAME}"
    pitr:
      enabled: false
      oplogOnly: false
      compressionType: gzip
      compressionLevel: 6
    tasks:
      - name: daily-azure-us-east
        enabled: true
        schedule: "0 0 * * *"
        keep: 3
        storageName: azure-blob		
        compressionType: gzip
        compressionLevel: 6
EOF
```  

Example output:
<!-- expected_similarity=0.8 -->
```output
perconaservermongodb.psmdb.percona.com/cluster-aks-mongodb created
```

2. Wait for the process to complete. The following script will wait until the MongoDB cluster is ready.

    ```bash
    while [ "$(kubectl get psmdb -n ${AKS_MONGODB_NAMESPACE} -o jsonpath='{.items[0].status.state}')" != "ready" ]; do echo "waiting for MongoDB cluster to be ready"; sleep 10; done
    ```
    When the process is over, your cluster will obtain the ready status.
    
    ```bash
    kubectl get psmdb -n ${AKS_MONGODB_NAMESPACE}
    ```
    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME                  ENDPOINT                                               STATUS   AGE
    cluster-aks-mongodb   cluster-aks-mongodb-mongos.mongodb.svc.cluster.local   ready    3m1s
    ```
3. To ensure high availability the MongoDB cluster will be deployed in multiple availability zones. To view this information, run the following command:

    ```bash
    kubectl get pods -n mongodb -l app.kubernetes.io/instance=cluster-aks-mongodb -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
    ```
    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME                           NODE
    cluster-aks-mongodb-cfg-0      aks-nodepool1-28994785-vmss000001
    cluster-aks-mongodb-cfg-1      aks-nodepool1-28994785-vmss000002
    cluster-aks-mongodb-cfg-2      aks-nodepool1-28994785-vmss000000
    cluster-aks-mongodb-mongos-0   aks-nodepool1-28994785-vmss000001
    cluster-aks-mongodb-mongos-1   aks-nodepool1-28994785-vmss000002
    cluster-aks-mongodb-mongos-2   aks-nodepool1-28994785-vmss000000
    cluster-aks-mongodb-rs0-0      aks-nodepool1-28994785-vmss000000
    cluster-aks-mongodb-rs0-1      aks-nodepool1-28994785-vmss000002
    cluster-aks-mongodb-rs0-2      aks-nodepool1-28994785-vmss000001
    ```

    ```bash
    kubectl get node -o custom-columns=Name:.metadata.name,Zone:".metadata.labels.topology\.kubernetes\.io/zone"
    ```

    This is the expected output:
    <!-- expected_similarity=0.8 -->
    ```output
    Name                                Zone
    aks-nodepool1-28994785-vmss000000   australiaeast-1
    aks-nodepool1-28994785-vmss000001   australiaeast-2
    aks-nodepool1-28994785-vmss000002   australiaeast-3
    ```

## Verifying the MongoDB cluster

1. To connect to Percona Server for MongoDB you need to construct the MongoDB connection URI string. It includes the credentials of the admin user, which are stored in the Secrets object:

    List the Secrets objects.
    ```bash
    #List the Secrets objects
    kubectl get secrets -n ${AKS_MONGODB_NAMESPACE}
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME                                                 TYPE                 DATA   AGE
    cluster-aks-azure-secrets                            Opaque               2      2m56s
    cluster-aks-mongodb-mongodb-keyfile                  Opaque               1      2m54s
    cluster-aks-mongodb-secrets                          Opaque               11     2m56s
    cluster-aks-mongodb-secrets-mongodb-encryption-key   Opaque               1      2m54s
    cluster-aks-mongodb-ssl                              kubernetes.io/tls    3      2m55s
    cluster-aks-mongodb-ssl-internal                     kubernetes.io/tls    3      2m54s
    external-secrets-webhook                             Opaque               4      3m49s
    internal-cluster-aks-mongodb-users                   Opaque               11     2m56s
    sh.helm.release.v1.external-secrets.v1               helm.sh/release.v1   1      3m49s
    ```

2. View the Secret contents to retrieve the admin user credentials:

    ```bash
    #View the Secret contents to retrive the admin user credentials.
    kubectl get secret ${AKS_MONGODB_SECRETS_NAME} -o yaml -n ${AKS_MONGODB_NAMESPACE}
    ```

    Example output:
    <!-- expected_similarity=0.1 -->
    ```output
    apiVersion: v1
    data:
    MONGODB_BACKUP_PASSWORD: SmhBRFo4aXNI...
    MONGODB_BACKUP_USER: TU9OR09EQl9...
    MONGODB_CLUSTER_ADMIN_PASSWORD: cE1oOFRMS1p0VkRQc...
    MONGODB_CLUSTER_ADMIN_USER: TU9OR09EQl9DTFV...
    MONGODB_CLUSTER_MONITOR_PASSWORD: emRuc0tPSVdWR0ZtS01i...
    MONGODB_CLUSTER_MONITOR_USER: TU9OR09EQl9DTFV...
    MONGODB_DATABASE_ADMIN_PASSWORD: cmZDZ2xEbDR2SVI...
    MONGODB_DATABASE_ADMIN_USER: TU9OR09EQl9EQVRB...
    MONGODB_USER_ADMIN_PASSWORD: ZE1uQW9tOXVNVGdyMVh...
    MONGODB_USER_ADMIN_USER: TU9OR09EQl9VU0...
    PMM_SERVER_API_KEY: S0g0dUU2TWxKNmZiaFZiVlQ1c...
    immutable: false
    kind: Secret
    metadata:
    annotations:
        kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"external-secrets.io/v1beta1","kind":"ExternalSecret","metadata":{"annotations":{},"name":"cluster-aks-mongodb-secrets","namespace":"mongodb"},"spec":{"data":[{"remoteRef":{"key":"MONGODB-BACKUP-USER"},"secretKey":"MONGODB_BACKUP_USER"},{"remoteRef":{"key":"MONGODB-BACKUP-PASSWORD"},"secretKey":"MONGODB_BACKUP_PASSWORD"},{"remoteRef":{"key":"MONGODB-DATABASE-ADMIN-USER"},"secretKey":"MONGODB_DATABASE_ADMIN_USER"},{"remoteRef":{"key":"MONGODB-DATABASE-ADMIN-PASSWORD"},"secretKey":"MONGODB_DATABASE_ADMIN_PASSWORD"},{"remoteRef":{"key":"MONGODB-CLUSTER-ADMIN-USER"},"secretKey":"MONGODB_CLUSTER_ADMIN_USER"},{"remoteRef":{"key":"MONGODB-CLUSTER-ADMIN-PASSWORD"},"secretKey":"MONGODB_CLUSTER_ADMIN_PASSWORD"},{"remoteRef":{"key":"MONGODB-CLUSTER-MONITOR-USER"},"secretKey":"MONGODB_CLUSTER_MONITOR_USER"},{"remoteRef":{"key":"MONGODB-CLUSTER-MONITOR-PASSWORD"},"secretKey":"MONGODB_CLUSTER_MONITOR_PASSWORD"},{"remoteRef":{"key":"MONGODB-USER-ADMIN-USER"},"secretKey":"MONGODB_USER_ADMIN_USER"},{"remoteRef":{"key":"MONGODB-USER-ADMIN-PASSWORD"},"secretKey":"MONGODB_USER_ADMIN_PASSWORD"},{"remoteRef":{"key":"PMM-SERVER-API-KEY"},"secretKey":"PMM_SERVER_API_KEY"}],"refreshInterval":"1h","secretStoreRef":{"kind":"SecretStore","name":"azure-store"},"target":{"creationPolicy":"Owner","name":"cluster-aks-mongodb-secrets"}}}
        reconcile.external-secrets.io/data-hash: 66c2c896ca641ffd72afead32fc24239
    creationTimestamp: "2024-07-01T12:24:38Z"
    labels:
        reconcile.external-secrets.io/created-by: d2ddd20e883057790bca8dc5f304303d
    name: cluster-aks-mongodb-secrets
    namespace: mongodb
    ownerReferences:
    - apiVersion: external-secrets.io/v1beta1
        blockOwnerDeletion: true
        controller: true
        kind: ExternalSecret
        name: cluster-aks-mongodb-secrets
        uid: 2e24dbbd-7144-4227-9015-5bd69468953a
    resourceVersion: "1872"
    uid: 3b37617f-b3e3-40df-8dff-d9e5c1916275
    type: Opaque
    ```

3. Decode login name and password on the output that are base64-encoded.

    ```bash
    #Decode login name and password on the output which are base64-encoded
    export databaseAdmin=$(kubectl get secret ${AKS_MONGODB_SECRETS_NAME} -n ${AKS_MONGODB_NAMESPACE} -o jsonpath="{.data.MONGODB_DATABASE_ADMIN_USER}" | base64 --decode)
    export databaseAdminPassword=$(kubectl get secret ${AKS_MONGODB_SECRETS_NAME} -n ${AKS_MONGODB_NAMESPACE} -o jsonpath="{.data.MONGODB_DATABASE_ADMIN_PASSWORD}" | base64 --decode)

    echo $databaseAdmin
    echo $databaseAdminPassword
    echo $AKS_MONGODB_CLUSTER_NAME
    ```

    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    MONGODB_DATABASE_ADMIN_USER
    rfCglDl4vIR3W...
    cluster-aks-mongodb
    ```
4. In order to verify your MongoDB cluster, run a container with a MongoDB client and connect its console output to your terminal.

    ```bash
    kubectl -n "${AKS_MONGODB_NAMESPACE}" run -i --rm --tty percona-client --image=${MY_ACR_REGISTRY}.azurecr.io/percona-server-mongodb:7.0.8-5 --restart=Never -- bash -il
    ```
5. Running the above command creates a Pod with Name `percona-client` under `${AKS_MONGODB_NAMESPACE}` namespace in your cluster. You can verify it by running following command in a different terminal window.

    ```bash
    kubectl get pod percona-client -n ${AKS_MONGODB_NAMESPACE}
    ```
    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    NAME             READY   STATUS    RESTARTS   AGE
    percona-client   1/1     Running   0          39s
    ```
6. Run the following command to connect to the MongoDB cluster using the admin user credentials that are printed earlier in step 3 in a terminal window used in step 4.

    ```bash
    #Note: Replace variables `databaseAdmin` , `databaseAdminPassword` and `AKS_MONGODB_CLUSTER_NAME` with actual values printed in step 3.

    mongosh "mongodb://${databaseAdmin}:${databaseAdminPassword}@${AKS_MONGODB_CLUSTER_NAME}-mongos.mongodb.svc.cluster.local/admin?replicaSet=rs0&ssl=false&directConnection=true"
    ```
    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    Current Mongosh Log ID: 66c76906115c6c831866efba
    Connecting to:          mongodb://<credentials>@cluster-aks-mongodb-mongos.mongodb.svc.cluster.local/admin?replicaSet=rs0&ssl=false&directConnection=true&appName=mongosh+2.1.5
    Using MongoDB:          7.0.8-5
    Using Mongosh:          2.1.5

    For mongosh info see: https://docs.mongodb.com/mongodb-shell/
    ...
    ```
7. Execute the following command to list the databases in the cluster.

    ```bash
    show dbs
    ```
    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    rs0 [direct: mongos] admin> show dbs
    admin   960.00 KiB
    config    3.45 MiB
    rs0 [direct: mongos] admin>
    ```

## Create MongoDB Backup

You can backup your data to Azure in two ways:

- On-demand. You can do them manually at any moment.
- Scheduled backups. Configure backups and their schedule in the crd yaml. The Operator makes them automatically according to the specified schedule.

The Operator can do either logical or physical backups.

***Logical backup*** means querying the Percona Server for MongoDB for the database data and writing the retrieved data to the remote backup storage.

***Physical backup*** means copying physical files from the Percona Server for MongoDB dbPath data directory to the remote backup storage.

Logical backups use less storage, but are slower than physical backup/restore.

To store backups on the Azure Blob storage, you need to create a Secret , this was already created above

#### Making scheduled backups
Backups schedule is defined in the backup section of the Custom Resource and can be configured via the [deploy/cr.yaml.](https://github.com/percona/percona-server-mongodb-operator/blob/main/deploy/cr.yaml)

- The **backup.enabled** key should be set to true,

- The **backup.storages** subsection should contain at least one configured storage.

- The **backup.tasks** subsection allows to actually schedule backups

Please see docs [(Making scheduled backups)](https://docs.percona.com/percona-operator-for-mongodb/backups-scheduled.html)

#### Making on-demand backups
To make an on-demand backup, you should first check your Custom Resource for the necessary options and make changes, if needed, using the [deploy/cr.yaml.](https://github.com/percona/percona-server-mongodb-operator/blob/main/deploy/cr.yaml) configuration file:

- the ***backup.enabled*** key should be set to true,

- ***backup.storages*** subsection should contain at least one configured storage.

Please see docs [(Making on-demand backups)](https://docs.percona.com/percona-operator-for-mongodb/backups-ondemand.html)

## Deploy MongoDB backup

1. Deploy your MongoDB backup using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: psmdb.percona.com/v1
    kind: PerconaServerMongoDBBackup
    metadata:
      finalizers:
      - delete-backup
      name: az-backup1
      namespace: ${AKS_MONGODB_NAMESPACE}
    spec:
      clusterName: ${AKS_MONGODB_CLUSTER_NAME}
      storageName: azure-blob
      type: logical
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
   perconaservermongodbbackup.psmdb.percona.com/az-backup1 created
    ```

2. Wait for the MongoDB backup deployment process to complete using the following script.

    ```bash
    while [ "$(kubectl get psmdb-backup -n ${AKS_MONGODB_NAMESPACE} -o jsonpath='{.items[0].status.state}')" != "ready" ]; do echo "waiting for the backup to be ready"; sleep 10; done
    ```
    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    waiting for the backup to be ready
    ```

3. When the process completes, the backup should return the `ready` status. Verify the backup deployment was successful using the `kubectl get` command.

    ```bash
    kubectl get psmdb-backup -n ${AKS_MONGODB_NAMESPACE}
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME         CLUSTER               STORAGE      DESTINATION                                                                       TYPE      STATUS   COMPLETED   AGE
    az-backup1   cluster-aks-mongodb   azure-blob   https://mongodbsacjcfc.blob.core.windows.net/backups/psmdb/2024-07-01T12:27:57Z   logical   ready    3h3m        3h3m
    ```

4. If you have any issues with the backup, you can view logs from the `backup-agent` container of the appropriate pod using the following command.

    ```bash
    kubectl logs pod/${AKS_MONGODB_CLUSTER_NAME}-rs0-0 -c backup-agent -n ${AKS_MONGODB_NAMESPACE}
    ```

## Next steps

To learn more about deploying open-source software on Azure Kubernetes Service (AKS), see the following articles:

* [Deploy a highly available PostgreSQL database on AKS](postgresql-ha-overview.md)
* [Build and deploy data and machine learning pipelines with Flyte on AKS](use-flyte.md)