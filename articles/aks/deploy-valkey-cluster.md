---
title: Configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, you learn how to configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 08/05/2024
author: schaffererin
ms.author: schaffererin
---

# Configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS)

In this article, we configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS).

## Configure workload identity

1. Create a namespace for the Valkey cluster using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace ${SERVICE_ACCOUNT_NAMESPACE} --dry-run=client --output yaml | kubectl apply -f -
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    namespace/valkey created
    ```

2. Create a service account and configure workload identity using the `kubectl apply` command.

    ```bash
    export TENANT_ID=$(az account show --query tenantId --output tsv)
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      annotations:
        azure.workload.identity/client-id: "${MY_IDENTITY_NAME_CLIENT_ID}"
        azure.workload.identity/tenant-id: "${TENANT_ID}"
      name: "${SERVICE_ACCOUNT_NAME}"
      namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    serviceaccount/valkey created
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
        --namespace external-secrets \
        --create-namespace \
       --set installCRDs=true \
       --wait
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME: external-secrets
    LAST DEPLOYED: Tue Jun 11 11:55:32 2024
    NAMESPACE: external-secrets
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    external-secrets has been deployed successfully in namespace external-secrets!
    
    In order to begin using ExternalSecrets, you will need to set up a SecretStore
    or ClusterSecretStore resource (for example, by creating a 'vault' SecretStore).
    
    More information on the different types of SecretStores and how to configure them
    can be found in our Github: https://github.com/external-secrets/external-secrets
    ```

3. Generate a random password for the Valkey cluster using open ssl and store it in your Azure key vault using the [`az keyvault secret set`][az-keyvault-secret-set] command.

    ```azurecli-interactive
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name valkey-password --value $(openssl rand -base64 32) --output table
    ```

    Example output:
    <!-- expected_similarity=0.5 -->
    ```output
    Name             Value
    ---------------  --------------------------------------------
    valkey-password  I9ebCSVLzpGXxLtz74joWtv7vRI0pcz47x8sVtx1uU8=
    ```

## Create secrets

1. Create a `SecretStore` resource to access the Valkey password stored in your key vault using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: azure-store
      namespace: valkey
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

2. Create an `ExternalSecret` resource, which creates a Kubernetes `Secret` in the Valkey namespace with the password stored in your key vault, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: valkey-password
      namespace: valkey
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: SecretStore
        name: azure-store

      target:
        name: valkey-password
        creationPolicy: Owner

      data:
      # name of the SECRET in the Azure KV (no prefix is by default a SECRET)
      - secretKey: valkey-password
        remoteRef:
          key: valkey-password
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    externalsecret.external-secrets.io/valkey-password created
    ```

3. Create a federated credential using the [`az identity federated-credential create`][az-identity-federated-credential-create] command.

    ```azurecli-interactive
    az identity federated-credential create \
                --name external-secret-operator \
                --identity-name ${MY_IDENTITY_NAME} \
                --resource-group ${MY_RESOURCE_GROUP_NAME} \
                --issuer ${OIDC_URL} \
                --subject system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME} \
                --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Issuer                                                                                                            Name                      ResourceGroup       Subject
    ----------------------------------------------------------------------------------------------------------------  ------------------------  ------------------  -----------------------------------
    https://eastus.oic.prod-aks.azure.com/72f988bf-86f1-41af-91ab-2d7cd011db47/86d8a7db-c0c9-417e-9dc1-626749e8dc88/  external-secret-operator  myResourceGroup-rg  system:serviceaccount:valkey:valkey
    ```

4. Give permission to the user-assigned identity to access the secret using the [`az keyvault set-policy`][az-keyvault-set-policy] command.

    ```azurecli-interactive
    az keyvault set-policy --name $MY_KEYVAULT_NAME --object-id $MY_IDENTITY_NAME_PRINCIPAL_ID --secret-permissions get --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location    Name            ResourceGroup
    ----------  --------------  ------------------
    eastus      vault-bbbhe-kv  myResourceGroup-rg
    ```

## Install Reloader

1. Add the [Reloader][reloader] Helm repository to reboot Valkey pods when the secret changes and update the repository using the `helm repo add` and `helm repo update` commands.

    ```bash
    helm repo add stakater https://stakater.github.io/stakater-charts
    helm repo update
    ```

    Example output:
    <!-- expected_similarity=0.1 -->
    ```output
    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "external-secrets" chart repository
    ...Successfully got an update from the "stakater" chart repository
    ```

2. Install the Reloader Helm chart using the `helm install` command.

    ```bash
    helm install reloader stakater/reloader
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME: reloader
    LAST DEPLOYED: Tue Jun 11 12:02:28 2024
    NAMESPACE: default
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    - For a `Deployment` called `foo` have a `ConfigMap` called `foo-configmap`. Then add this annotation to main metadata of your `Deployment`
      configmap.reloader.stakater.com/reload: "foo-configmap"

    - For a `Deployment` called `foo` have a `Secret` called `foo-secret`. Then add this annotation to main metadata of your `Deployment`
      secret.reloader.stakater.com/reload: "foo-secret"

    - After successful installation, your pods will get rolling updates when a change in data of configmap or secret will happen.
    ```

## Deploy the Valkey cluster

1. Create a `ConfigMap` mounted as a volume in the Valkey `StatefulSet` to use to configure the Valkey cluster using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: valkey-cluster
      namespace: valkey
    data:
      valkey.conf:  |+
        cluster-enabled yes
        cluster-node-timeout 15000
        cluster-config-file /data/nodes.conf
        appendonly yes
        protected-mode no
        dir /data
        port 6379
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    configmap/valkey-cluster created
    ```

2. Create a `StatefulSet` resource with a `spec.affinity` goal is to keep all primaries in zone 1, preferably in different nodes, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    ---
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: valkey-masters
      namespace: valkey
      annotations:
        secret.reloader.stakater.com/reload: valkey-password
    spec:
      serviceName: "valkey-masters"
      replicas: 3
      selector:
        matchLabels:
          app: valkey
      template:
        metadata:
          labels:
            app: valkey
            appCluster: valkey-masters
        spec:
          terminationGracePeriodSeconds: 20
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                    - valkey
                - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                    - ${MY_LOCATION}-1
            podAntiAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 90
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: app
                      operator: In
                      values:
                      - valkey
                  topologyKey: kubernetes.io/hostname
          containers:
          - name: valkey
            image: "${MY_ACR_REGISTRY}.azurecr.io/valkey:7.2.5"
            envFrom:
            - secretRef:
                name: valkey-password
            command:
              - "valkey-server"
            args:
              - "/conf/valkey.conf"
              - "--protected-mode"
              - "no"
            resources:
              requests:
                cpu: "100m"
                memory: "100Mi"
            ports:
                - name: valkey
                  containerPort: 6379
                  protocol: "TCP"
                - name: cluster
                  containerPort: 16379
                  protocol: "TCP"
            volumeMounts:
            - name: conf
              mountPath: /conf
              readOnly: false
            - name: data
              mountPath: /data
              readOnly: false
          volumes:
          - name: conf
            configMap:
              name: valkey-cluster
              defaultMode: 0755
      volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: [ "ReadWriteOnce" ]
          storageClassName: managed-csi-premium
          resources:
            requests:
              storage: 20Gi
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    statefulset.apps/valkey-masters created
    ```

3. Create a second `StatefulSet` resource for the Valkey secondaries with a `spec.affinity` goal to keep all replicas in zone 2, preferably in different nodes, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    ---
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: valkey-replicas
      namespace: valkey
      annotations:
        secret.reloader.stakater.com/reload: valkey-password
    spec:
      serviceName: "valkey-replicas"
      replicas: 3
      selector:
        matchLabels:
          app: valkey
      template:
        metadata:
          labels:
            app: valkey
            appCluster: valkey-replicas
        spec:
          terminationGracePeriodSeconds: 20
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                    - valkey
                - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                    - ${MY_LOCATION}-2
            podAntiAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 90
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: app
                      operator: In
                      values:
                      - valkey
                  topologyKey: kubernetes.io/hostname
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: app
                      operator: In
                      values:
                      - valkey
                  topologyKey: failure-domain.beta.kubernetes.io/zone
          containers:
          - name: valkey
            image: "${MY_ACR_REGISTRY}.azurecr.io/valkey:7.2.5"
            envFrom:
            - secretRef:
                name: valkey-password
            command:
              - "valkey-server"
            args:
              - "/conf/valkey.conf"
              - "--protected-mode"
              - "no"
            resources:
              requests:
                cpu: "100m"
                memory: "100Mi"
            ports:
                - name: valkey
                  containerPort: 6379
                  protocol: "TCP"
                - name: cluster
                  containerPort: 16379
                  protocol: "TCP"

            volumeMounts:
            - name: conf
              mountPath: /conf
              readOnly: false
            - name: data
              mountPath: /data
              readOnly: false
          volumes:
          - name: conf
            configMap:
              name: valkey-cluster
              defaultMode: 0755
      volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: [ "ReadWriteOnce" ]
          storageClassName: managed-csi-premium
          resources:
            requests:
              storage: 20Gi
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    statefulset.apps/valkey-replicas created
    ```

4. Verify that `master-N` and `replica-N` are running in different nodes and zones using the `kubectl get nodes` and `kubectl get pods` commands.

    ```bash
    kubectl get pods -n valkey -o wide
    kubectl get node -o custom-columns=Name:.metadata.name,Zone:".metadata.labels.topology\.kubernetes\.io/zone"
    ```

    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    NAME                READY   STATUS    RESTARTS   AGE     IP             NODE                                NOMINATED NODE   READINESS GATES
    valkey-masters-0    1/1     Running   0          2m22s   10.224.0.14    aks-nodepool1-11412955-vmss000000   <none>           <none>
    valkey-masters-1    1/1     Running   0          2m2s    10.224.0.247   aks-valkey-27955880-vmss000000      <none>           <none>
    valkey-masters-2    1/1     Running   0          89s     10.224.0.176   aks-valkey-27955880-vmss000002      <none>           <none>
    valkey-replicas-0   1/1     Running   0          2m2s    10.224.0.224   aks-valkey-27955880-vmss000001      <none>           <none>
    valkey-replicas-1   1/1     Running   0          80s     10.224.0.103   aks-valkey-27955880-vmss000005      <none>           <none>
    valkey-replicas-2   1/1     Running   0          50s     10.224.0.200   aks-valkey-27955880-vmss000004      <none>           <none>
    Name                                Zone
    aks-nodepool1-11412955-vmss000000   eastus-1
    aks-nodepool1-11412955-vmss000001   eastus-2
    aks-nodepool1-11412955-vmss000002   eastus-3
    aks-valkey-27955880-vmss000000      eastus-1
    aks-valkey-27955880-vmss000001      eastus-2
    aks-valkey-27955880-vmss000002      eastus-1
    aks-valkey-27955880-vmss000003      eastus-2
    aks-valkey-27955880-vmss000004      eastus-1
    aks-valkey-27955880-vmss000005      eastus-2
    ```

    Wait for all pods to be running before proceeding to the next step.

5. Create three headless `Service` resources (the first for the entire cluster, the second for the primaries, and the third for the secondaries) to use to get the IP addresses of the Valkey pods using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: valkey-cluster
      namespace: valkey
    spec:
      clusterIP: None
      ports:
      - name: valkey-port
        port: 6379
        protocol: TCP
        targetPort: 6379
      selector:
        app: valkey
      sessionAffinity: None
      type: ClusterIP
    EOF

    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: valkey-masters
      namespace: valkey
    spec:
      clusterIP: None
      ports:
      - name: valkey-port
        port: 6379
        protocol: TCP
        targetPort: 6379
      selector:
        app: valkey
        appCluster: valkey-masters
      sessionAffinity: None
      type: ClusterIP
    EOF

    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: valkey-replicas
      namespace: valkey
    spec:
      clusterIP: None
      ports:
      - name: valkey-port
        port: 6379
        protocol: TCP
        targetPort: 6379
      selector:
        app: valkey
        appCluster: valkey-replicas
      sessionAffinity: None
      type: ClusterIP
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    service/valkey-cluster created
    service/valkey-masters created
    service/valkey-replicas created
    ```

## Run the Valkey cluster

1. Add the Valkey primaries, each in a different availability zone, to the cluster using the `kubectl exec` command.

    ```bash
    kubectl exec -it -n valkey valkey-masters-0 -- valkey-cli --cluster create --cluster-yes --cluster-replicas 0 \
                        valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379 \
                        valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379 \
                        valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    >>> Performing hash slots allocation on 3 nodes...
    Master[0] -> Slots 0 - 5460
    Master[1] -> Slots 5461 - 10922
    Master[2] -> Slots 10923 - 16383
    M: ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35 valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379
       slots:[0-5460] (5461 slots) master
    M: fd1fb98db83976478e05edd3d2a02f9a13badd80 valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379
       slots:[5461-10922] (5462 slots) master
    M: ea47bf57ae7080ef03164a4d48b662c7b4c8770e valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379
       slots:[10923-16383] (5461 slots) master
    >>> Nodes configuration updated
    >>> Assign a different config epoch to each node
    >>> Sending CLUSTER MEET messages to join the cluster
    Waiting for the cluster to join
    ...
    >>> Performing Cluster Check (using node valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379)
    M: ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35 valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379
       slots:[0-5460] (5461 slots) master
    M: ea47bf57ae7080ef03164a4d48b662c7b4c8770e 10.224.0.176:6379
       slots:[10923-16383] (5461 slots) master
    M: fd1fb98db83976478e05edd3d2a02f9a13badd80 10.224.0.247:6379
       slots:[5461-10922] (5462 slots) master
    [OK] All nodes agree about slots configuration.
    >>> Check for open slots...
    >>> Check slots coverage...
    [OK] All 16384 slots covered.
    ```

2. Add the Valkey replicas, each in a different availability zone, to the cluster using the `kubectl exec` command.

    ```bash
    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-0.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave

    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-1.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave

    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-2.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    >>> Adding node valkey-replicas-0.valkey-replicas.valkey.svc.cluster.local:6379 to cluster valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379
    >>> Performing Cluster Check (using node valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379)
    M: ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35 valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379
       slots:[0-5460] (5461 slots) master
    M: ea47bf57ae7080ef03164a4d48b662c7b4c8770e 10.224.0.176:6379
       slots:[10923-16383] (5461 slots) master
    M: fd1fb98db83976478e05edd3d2a02f9a13badd80 10.224.0.247:6379
       slots:[5461-10922] (5462 slots) master
    [OK] All nodes agree about slots configuration.
    >>> Check for open slots...
    >>> Check slots coverage...
    [OK] All 16384 slots covered.
    Automatically selected master valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379
    >>> Send CLUSTER MEET to node valkey-replicas-0.valkey-replicas.valkey.svc.cluster.local:6379 to make it join the cluster.
    Waiting for the cluster to join

    >>> Configure node as replica of valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379.
    [OK] New node added correctly.
    >>> Adding node valkey-replicas-1.valkey-replicas.valkey.svc.cluster.local:6379 to cluster valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379
    >>> Performing Cluster Check (using node valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379)
    M: fd1fb98db83976478e05edd3d2a02f9a13badd80 valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379
       slots:[5461-10922] (5462 slots) master
    S: 0ebceb60cbcc31da9040159440a1f4856b992907 10.224.0.224:6379
       slots: (0 slots) slave
       replicates ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35
    M: ea47bf57ae7080ef03164a4d48b662c7b4c8770e 10.224.0.176:6379
       slots:[10923-16383] (5461 slots) master
    M: ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35 10.224.0.14:6379
       slots:[0-5460] (5461 slots) master
       1 additional replica(s)
    [OK] All nodes agree about slots configuration.
    >>> Check for open slots...
    >>> Check slots coverage...
    [OK] All 16384 slots covered.
    Automatically selected master valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379
    >>> Send CLUSTER MEET to node valkey-replicas-1.valkey-replicas.valkey.svc.cluster.local:6379 to make it join the cluster.
    Waiting for the cluster to join

    >>> Configure node as replica of valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379.
    [OK] New node added correctly.
    >>> Adding node valkey-replicas-2.valkey-replicas.valkey.svc.cluster.local:6379 to cluster valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379
    >>> Performing Cluster Check (using node valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379)
    M: ea47bf57ae7080ef03164a4d48b662c7b4c8770e valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379
       slots:[10923-16383] (5461 slots) master
    S: 0ebceb60cbcc31da9040159440a1f4856b992907 10.224.0.224:6379
       slots: (0 slots) slave
       replicates ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35
    S: fa44edff683e2e01ee5c87233f9f3bc35c205dce 10.224.0.103:6379
       slots: (0 slots) slave
       replicates fd1fb98db83976478e05edd3d2a02f9a13badd80
    M: ee6ac1d00d3f016b6f46c7ce11199bc1a7809a35 10.224.0.14:6379
       slots:[0-5460] (5461 slots) master
       1 additional replica(s)
    M: fd1fb98db83976478e05edd3d2a02f9a13badd80 10.224.0.247:6379
       slots:[5461-10922] (5462 slots) master
       1 additional replica(s)
    [OK] All nodes agree about slots configuration.
    >>> Check for open slots...
    >>> Check slots coverage...
    [OK] All 16384 slots covered.
    Automatically selected master valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379
    >>> Send CLUSTER MEET to node valkey-replicas-2.valkey-replicas.valkey.svc.cluster.local:6379 to make it join the cluster.
    Waiting for the cluster to join

    >>> Configure node as replica of valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379.
    [OK] New node added correctly.
    ```

3. Verify the roles of the pods using the following commands:

    ```bash
    for x in $(seq 0 2); do echo "valkey-masters-$x"; kubectl exec -n valkey valkey-masters-$x  -- valkey-cli role; echo; done
    for x in $(seq 0 2); do echo "valkey-replicas-$x"; kubectl exec -n valkey valkey-replicas-$x -- valkey-cli role; echo; done
    ```

    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    valkey-masters-0
    master
    84
    10.224.0.224
    6379
    84

    valkey-masters-1
    master
    84
    10.224.0.103
    6379
    84

    valkey-masters-2
    master
    70
    10.224.0.200
    6379
    70

    valkey-replicas-0
    slave
    10.224.0.14
    6379
    connected
    98

    valkey-replicas-1
    slave
    10.224.0.247
    6379
    connected
    98

    valkey-replicas-2
    slave
    10.224.0.176
    6379
    connected
    84
    ```

## Next steps

To learn more about deploying open-source software on Azure Kubernetes Service (AKS), see the following articles:

* [Deploy a highly available PostgreSQL database on AKS][postgresql-aks]
* [Build and deploy data and machine learning pipelines with Flyte on AKS][flyte-aks]

<!-- External links -->
[reloader]: https://github.com/stakater/Reloader

<!-- Internal links -->
[az-keyvault-secret-set]: /cli/azure/keyvault/secret#az-keyvault-secret-set
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az-identity-federated-credential-create
[az-keyvault-set-policy]: /cli/azure/keyvault#az-keyvault-set-policy
[postgresql-aks]: ./postgresql-ha-overview.md
[flyte-aks]: ./use-flyte.md
