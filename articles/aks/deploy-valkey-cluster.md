---
title: Configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, you learn how to configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: schaffererin
ms.author: schaffererin
zone_pivot_groups: azure-cli-or-terraform

---

# Configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS)

In this article, we configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS), including the creation of a Valkey cluster ConfigMap, primary and secondary cluster pods to ensure redundancy and zone replication, and a Pod Disruption Budget (PDB) to ensure high availability.

> [!NOTE]
> This article contains references to the terms *master* and *slave*, which are terms that Microsoft no longer uses. When the term is removed from the Valkey software, we’ll remove it from this article.

## Connect to the AKS cluster
> [!NOTE]
> Ensure that if you're using Terraform, you've replaced the placeholders in the code with the actual outputs from the terraform commands that was deployed in the previous step [deploying the infrastructure][create-valkey-cluster]. 

* Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --overwrite-existing --output table
    ```

## Create a namespace

1. Create a namespace for the Valkey cluster using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace valkey --dry-run=client --output yaml | kubectl apply -f -
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    namespace/valkey created
    ```

## Create secrets

:::zone pivot="azure-cli"

1. Generate a random password for the Valkey cluster using openssl and store it in your Azure key vault using the [`az keyvault secret set`][az-keyvault-secret-set] command.
   Set the policy to allow the user-assigned identity to get the secret using the [`az keyvault set-policy`][az-keyvault-set-policy] command.

    ```azurecli-interactive
    SECRET=$(openssl rand -base64 32)
    echo requirepass $SECRET > /tmp/valkey-password-file.conf
    echo primaryauth $SECRET >> /tmp/valkey-password-file.conf
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name valkey-password-file --file /tmp/valkey-password-file.conf --output none
    rm /tmp/valkey-password-file.conf
    az keyvault set-policy --name $MY_KEYVAULT_NAME --object-id $userAssignedObjectID --secret-permissions get --output table
    ```
:::zone-end

:::zone pivot="terraform"

1. Get the Identity ID and the Object ID created by the Azure KeyVault Secret Provider Addon, using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    export userAssignedIdentityID=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId --output tsv)
    export userAssignedObjectID=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId --output tsv)

    ```
:::zone-end

2. Create a `SecretProviderClass` resource to access the Valkey password stored in your key vault using the `kubectl apply` command.

    ```bash
    export TENANT_ID=$(az account show --query tenantId --output tsv)
    kubectl apply -f - <<EOF
    ---
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: valkey-password
      namespace: valkey
    spec:
      provider: azure
      parameters:
        usePodIdentity: "false"
        useVMManagedIdentity: "true"
        userAssignedIdentityID: "${userAssignedIdentityID}"
        keyvaultName: ${MY_KEYVAULT_NAME}              # the name of the AKV instance
        objects: |
          array:
            - |
              objectName: valkey-password-file
              objectAlias: valkey-password-file.conf
              objectType: secret
        tenantId: "${TENANT_ID}" # the tenant ID of the AKV instance
    EOF
    ```

## Create the Valkey configuration file

1. Create a `ConfigMap` resource to store the Valkey configuration file.

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
        protected-mode yes
        dir /data
        port 6379
        include /etc/valkey-password/valkey-password-file.conf
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    configmap/valkey-cluster created
    ```

## Create Valkey primary cluster pods
1. Create a `StatefulSet` resource with a `spec.affinity` goal is to keep all primaries in zone 1 and zone 2, preferably in different nodes, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    ---
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: valkey-masters
      namespace: valkey
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
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                    - ${MY_LOCATION}-1
                - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                    - valkey
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                    - ${MY_LOCATION}-2
            podAntiAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: app
                      operator: In
                      values:
                      - valkey
                  topologyKey: topology.kubernetes.io/zone
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
          - name: role-master-checker
            image: "${MY_ACR_REGISTRY}.azurecr.io/valkey:latest"
            command:
              - "/bin/bash"
              - "-c"
            args:
              [
                "while true; do role=\$(valkey-cli --pass \$(cat /etc/valkey-password/valkey-password-file.conf | awk '{print \$2; exit}') role | awk '{print \$1; exit}');     if [ \"\$role\" = \"slave\" ]; then valkey-cli --pass \$(cat /etc/valkey-password/valkey-password-file.conf | awk '{print \$2; exit}') cluster failover; fi; sleep 30; done"
              ]
            volumeMounts:
            - name: valkey-password
              mountPath: /etc/valkey-password
              readOnly: true
          - name: valkey
            image: "${MY_ACR_REGISTRY}.azurecr.io/valkey:latest"
            env:
            - name: VALKEY_PASSWORD_FILE
              value: "/etc/valkey-password/valkey-password-file.conf"
            - name: MY_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            command:
              - "valkey-server"
            args:
              - "/conf/valkey.conf"
              - "--cluster-announce-ip"
              - "\$(MY_POD_IP)"
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
            - name: valkey-password
              mountPath: /etc/valkey-password
              readOnly: true
          volumes:
          - name: valkey-password
            csi:
              driver: secrets-store.csi.k8s.io
              readOnly: true
              volumeAttributes:
                secretProviderClass: valkey-password
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

## Create Valkey replica cluster pods
1. Create a second `StatefulSet` resource for the Valkey secondaries with a `spec.affinity` goal to keep all replicas in zone 3, preferably in different nodes, using the `kubectl apply` command.

    ```bash
    kubectl apply -f - <<EOF
    ---
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: valkey-replicas
      namespace: valkey
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
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                    - ${MY_LOCATION}-3
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
            image: "${MY_ACR_REGISTRY}.azurecr.io/valkey:latest"
            env:
            - name: VALKEY_PASSWORD_FILE
              value: "/etc/valkey-password/valkey-password-file.conf"
            - name: MY_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            command:
              - "valkey-server"
            args:
              - "/conf/valkey.conf"
              - "--cluster-announce-ip"
              - "\$(MY_POD_IP)"
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
            - name: valkey-password
              mountPath: /etc/valkey-password
              readOnly: true
          volumes:
          - name: valkey-password
            csi:
              driver: secrets-store.csi.k8s.io
              readOnly: true
              volumeAttributes:
                secretProviderClass: valkey-password
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
## Verify pod and node distribution

1. Verify that `master-N` and `replica-N` are running in different nodes and zones using the `kubectl get nodes` and `kubectl get pods` commands.

    ```bash
    kubectl get pods -n valkey -o wide
    kubectl get node -o custom-columns=Name:.metadata.name,Zone:".metadata.labels.topology\.kubernetes\.io/zone"
    ```

    Example output:
    <!-- expected_similarity=0.4 -->
    ```output
    NAME                READY   STATUS    RESTARTS   AGE     IP             NODE                             NOMINATED NODE   READINESS GATES
    valkey-masters-0    1/1     Running   0          2m55s   10.224.0.4     aks-valkey-18693609-vmss000004   <none>           <none>
    valkey-masters-1    1/1     Running   0          2m31s   10.224.0.137   aks-valkey-18693609-vmss000000   <none>           <none>
    valkey-masters-2    1/1     Running   0          2m7s    10.224.0.222   aks-valkey-18693609-vmss000001   <none>           <none>
    valkey-replicas-0   1/1     Running   0          88s     10.224.0.237   aks-valkey-18693609-vmss000005   <none>           <none>
    valkey-replicas-1   1/1     Running   0          70s     10.224.0.18    aks-valkey-18693609-vmss000002   <none>           <none>
    valkey-replicas-2   1/1     Running   0          48s     10.224.0.242   aks-valkey-18693609-vmss000005   <none>           <none>
    Name                                Zone
    aks-nodepool1-17621399-vmss000000   centralus-1
    aks-nodepool1-17621399-vmss000001   centralus-2
    aks-nodepool1-17621399-vmss000003   centralus-3
    aks-valkey-18693609-vmss000000      centralus-1
    aks-valkey-18693609-vmss000001      centralus-2
    aks-valkey-18693609-vmss000002      centralus-3
    aks-valkey-18693609-vmss000003      centralus-1
    aks-valkey-18693609-vmss000004      centralus-2
    aks-valkey-18693609-vmss000005      centralus-3
    ```

    Wait for all pods to be running before proceeding to the next step.

## Create headless services
1. Create three headless `Service` resources (the first for the entire cluster, the second for the primaries, and the third for the secondaries) to use to get the IP addresses of the Valkey pods using the `kubectl apply` command.

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

## Create Pod Disruption Budget (PDB)
1. Create a Pod Disruption Budget (PDB) to ensure always that one pod at most is unavailable during voluntary disruptions, such as upgrades or maintenance. This helps maintain the stability and availability of the Valkey application within the Kubernetes cluster.

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: valkey
      namespace: valkey
    spec:
      maxUnavailable: 1
      selector:
        matchLabels:
          app: valkey
    EOF
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    poddisruptionbudget.policy/valkey created
    ```

## Run the Valkey cluster

1. Add the Valkey primaries, in zone 1 and 2, to the cluster using the `kubectl exec` command.

    ```bash
    kubectl exec -it -n valkey valkey-masters-0 -- valkey-cli --cluster create --cluster-yes --cluster-replicas 0 \
                        valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379 \
                        valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379 \
                        valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379 \
                        --pass ${SECRET}
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

2. Add the Valkey replicas, in zone 3, to the cluster using the `kubectl exec` command.

    ```bash
    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-0.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-0.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave \
                        --pass ${SECRET}

    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-1.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-1.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave \
                        --pass ${SECRET}

    kubectl exec -ti -n valkey valkey-masters-0 -- valkey-cli --cluster add-node \
                        valkey-replicas-2.valkey-replicas.valkey.svc.cluster.local:6379 \
                        valkey-masters-2.valkey-masters.valkey.svc.cluster.local:6379  --cluster-slave \
                        --pass ${SECRET}
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
    for x in $(seq 0 2); do echo "valkey-masters-$x"; kubectl exec -n valkey valkey-masters-$x  -- valkey-cli --pass ${SECRET} role; echo; done
    for x in $(seq 0 2); do echo "valkey-replicas-$x"; kubectl exec -n valkey valkey-replicas-$x -- valkey-cli --pass ${SECRET} role; echo; done
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

> [!div class="nextstepaction"]
> [Validate the resiliency of the Valkey cluster on AKS][validate-valkey-cluster]

To learn more about deploying open-source software on Azure Kubernetes Service (AKS), see the following articles:

* [Deploy a highly available PostgreSQL database on AKS][postgresql-aks]
* [Build and deploy data and machine learning pipelines with Flyte on AKS][flyte-aks]

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Nelly Kiboi | Service Engineer
* Saverio Proto | Principal Customer Experience Engineer
* Don High | Principal Customer Engineer
* LaBrina Loving | Principal Service Engineer
* Ken Kilty | Principal TPM
* Russell de Pina | Principal TPM
* Colin Mixon | Product Manager
* Ketan Chawda | Senior Customer Engineer
* Naveed Kharadi | Customer Experience Engineer
* Erin Schaffer | Content Developer 2

<!-- Internal links -->
[az-keyvault-secret-set]: /cli/azure/keyvault/secret#az-keyvault-secret-set
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az-identity-federated-credential-create
[az-keyvault-set-policy]: /cli/azure/keyvault#az-keyvault-set-policy
[postgresql-aks]: ./postgresql-ha-overview.md
[flyte-aks]: ./use-flyte.md
[validate-valkey-cluster]: ./validate-valkey-cluster.md
[create-valkey-cluster]: ./create-valkey-infrastructure.md
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-show]: /cli/azure/aks#az-aks-show
