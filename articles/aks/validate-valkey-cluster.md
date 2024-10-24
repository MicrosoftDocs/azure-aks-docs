---
title: Validate the resiliency of the Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, you learn how to connect to a Valkey cluster on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 10/15/2024
author: schaffererin
ms.author: schaffererin
---

# Validate the resiliency of the Valkey cluster on Azure Kubernetes Service (AKS)

## Build and run a sample client application for Valkey

The following steps show how to build a sample client application for Valkey and push the Docker image of the application to an Azure Container Registry.
The sample client application uses the [Locust load testing framework](https://docs.locust.io/en/stable/) to simulate a workload on the Valkey cluster.

1. Create the `Dockerfile` and `requirements.txt` and place them in a new directory:

    ```bash
    mkdir valkey-client
    cd valkey-client

    cat > Dockerfile <<EOF
    FROM python:3.10-slim-bullseye
    COPY requirements.txt .
    COPY locustfile.py .
    RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt
    EOF

    cat > requirements.txt <<EOF
    valkey
    locust
    EOF
    ```
2. Create the `locustfile.py` file with the following content:

    ```bash
    cat > locustfile.py <<EOF
    import time
    from locust import between, task, User, events,tag
    from valkey import ValkeyCluster


    class ValkeyLocust(User):

        def __init__(self, *args, **kwargs):
            super(ValkeyLocust, self).__init__(*args, **kwargs)
            self.client = ValkeyClient()
        @task
        @tag("set")
        def set_value(self):
            self.client.set_value("set_value")
        @task
        @tag("get")
        def get_value(self):
            self.client.get_value("get_value")

    class ValkeyClient(object):
         # Read the Valkey password from the Secret Store CSI driver mounted file
        f = open("/etc/valkey-password/valkey-password-file.conf", "r")
        password = f.readlines()[0].split(" ")[1].strip()
        f.close()
        host = "valkey-cluster.valkey.svc.cluster.local"
        port = 6379
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.host = self.host
            self.port = self.port
            self.password = self.password
            self.vc = ValkeyCluster(host=self.host, port=self.port, password=self.password, username="default")

        def set_value(self, key, command='SET'):
            # Start time for the 'set' operation with high-resolution timer
            start_time = time.perf_counter()
            try:
                # Execute the set operation
                result = self.vc.set("locust", "python")
                length = len(str(result))
                if not result:
                    result = ''
                # Success event
                total_time = (time.perf_counter()- start_time) * 1000
                events.request.fire(
                    request_type=command,  # You can give it any name
                    name=key,  # Operation name
                    response_time=total_time,
                    response_length=length,  # Optionally, track response size
                )
            except Exception as e:
                # Failure event
                total_time = (time.perf_counter()- start_time) * 1000
                events.request.fire(
                    request_type=command,  # You can give it any name
                    name=key,  # Operation name
                    response_time=total_time,
                    exception=e  # Pass the exception to register a failure
                )
            return result
        def get_value(self, key, command='GET'):
            # Start time for the 'get' operation with high-resolution timer
            start_time = time.perf_counter()
            try:
                # Execute the get operation
                result = self.vc.get("locust")
                length = len(str(result))
                if not result:
                    result = ''
                # Success event
                total_time = (time.perf_counter()- start_time) * 1000
                events.request.fire(
                    request_type=command,  # You can give it any name
                    name=key,  # Operation name
                    response_time=total_time,
                    response_length=length,  # Optionally, track response size
                )
            except Exception as e:
                # Failure event
                total_time = (time.perf_counter()- start_time) * 1000
                events.request.fire(
                    request_type=command,  # You can give it any name
                    name=key,  # Operation name
                    response_time=total_time,
                    exception=e  # Pass the exception to register a failure
                )
            return result

        def on_stop(self):
            self.vc.close()
    EOF
    ```
    This python class is implementing a Locust User class that connects to the Valkey cluster and performs a set and get operation.
    You can expand this class to implement more complex operations.

3. Build the Docker image and upload it to the Azure Container Registry (ACR):

    ```bash
    az acr build --image valkey-client --registry ${MY_ACR_REGISTRY} .
    ```

## Test the Valkey cluster on Azure Kubernetes Service (AKS)

1. Create a Pod that uses the Valkey client image we built in the previous step.
    The pod spec contains also the Secret Store CSI volume with the valkey password the client will use to connect to the Valkey cluster.

    ```bash
    kubectl apply -f - <<EOF
    ---
    kind: Pod
    apiVersion: v1
    metadata:
      name: valkey-client
      namespace: valkey
    spec:
        containers:
        - name: valkey-client
          image: ${MY_ACR_REGISTRY}.azurecr.io/valkey-client
          command: ["locust"]
          volumeMounts:
            - name: valkey-password
              mountPath: "/etc/valkey-password"
        volumes:
        - name: valkey-password
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "valkey-password"
    EOF
    ```

2. Port forward the port 8089 to access the Locust web interface on your local machine:

    ```bash
     kubectl port-forward -n valkey valkey-client 8089:8089
    ```

    Access the Locust web interface at `http://localhost:8089` and start the test.

    :::image type="content" source="media/valkey-stateful-workload/locust.png" alt-text="Screenshot of a web page showing the Locust test dashboard.":::


3. To simulate an outage lets delete the StatefulSet with the option [`--cascade=orphan`](https://kubernetes.io/docs/tasks/run-application/delete-stateful-set/).

    The goal is to be able to delete a single Pod without having the StatefulSet recreating that Pod immediately.

    ```bash
    kubectl delete statefulset valkey-masters --cascade=orphan
    ```
    Now let's delete the `valkey-masters-0` Pod:

    ```bash
    kubectl delete pod valkey-masters-0
    ```
    When you run `kubectl get pods`, you will see that the Pod `valkey-masters-0`has been deleted.

    ```bash
        NAME                READY   STATUS    RESTARTS   AGE
        valkey-client       1/1     Running   0          6m34s
        valkey-masters-1    1/1     Running   0          16m
        valkey-masters-2    1/1     Running   0          16m
        valkey-replicas-0   1/1     Running   0          16m
        valkey-replicas-1   1/1     Running   0          16m
        valkey-replicas-2   1/1     Running   0          16m
    ```


    When we read the logs of the `valkey-replicas-0` Pod, by running `kubectl logs valkey-replicas-0`, we observe that the complete event lasts for about 18 seconds:

    ```
    1:S 18 Oct 2024 14:40:26.324 * Connection with primary lost.
    1:S 18 Oct 2024 14:40:26.324 * Caching the disconnected primary state.
    1:S 18 Oct 2024 14:40:26.324 * Reconnecting to PRIMARY 10.224.0.167:6379
    1:S 18 Oct 2024 14:40:26.324 * PRIMARY <-> REPLICA sync started
    1:S 18 Oct 2024 14:40:26.326 # Error condition on socket for SYNC: Connection refused
    1:S 18 Oct 2024 14:40:27.227 * Connecting to PRIMARY 10.224.0.167:6379
    1:S 18 Oct 2024 14:40:27.227 * PRIMARY <-> REPLICA sync started
    1:S 18 Oct 2024 14:40:42.617 * NODE 89e262203ce6e6884f383bd1382f67c0d3f8515b () possibly failing.
    1:S 18 Oct 2024 14:40:43.987 * FAIL message received from 05dfbb00751465db264d59caf904856cd7fec0ab () about 89e262203ce6e6884f383bd1382f67c0d3f8515b ()
    1:S 18 Oct 2024 14:40:43.987 # Cluster state changed: fail
    1:S 18 Oct 2024 14:40:44.026 * Start of election delayed for 659 milliseconds (rank #0, offset 3234599075).
    1:S 18 Oct 2024 14:40:44.127 * Currently unable to failover: Waiting the delay before I can start a new failover.
    1:S 18 Oct 2024 14:40:44.630 * Node 05dfbb00751465db264d59caf904856cd7fec0ab () reported node 89e262203ce6e6884f383bd1382f67c0d3f8515b () as not reachable.
    1:S 18 Oct 2024 14:40:44.730 * Starting a failover election for epoch 7.
    1:S 18 Oct 2024 14:40:44.767 * Currently unable to failover: Waiting for votes, but majority still not reached.
    1:S 18 Oct 2024 14:40:44.768 * Needed quorum: 2. Number of votes received so far: 1
    1:S 18 Oct 2024 14:40:44.768 * Failover election won: I'm the new primary.
    1:S 18 Oct 2024 14:40:44.768 * configEpoch set to 7 after successful failover
    1:M 18 Oct 2024 14:40:44.768 * Discarding previously cached primary state.
    1:M 18 Oct 2024 14:40:44.768 * Setting secondary replication ID to d388030cb4bd3b28aabaec0392bf6190635be431, valid up to offset: 3234599076. New replication ID is 721ae1f7f6d9c918b7cc2ee424a723bf559d9452
    1:M 18 Oct 2024 14:40:44.769 * Cluster state changed: ok
    ```

    During this time window of 18 seconds, we observe a short outage from ` 14:40:43.987 # Cluster state changed: fail` to `14:40:44.768 * Failover election won: I'm the new primary.` of about 1 second. The requests to the cluster did not fail, but we see a spike in the request latency where the 95th percentile spikes to 970ms.

    :::image type="content" source="media/valkey-stateful-workload/percentile.png" alt-text="Screenshot of a graph showing the 95th percentile of request latencies spiking to 970ms.":::

## Conclusion

In this article, we learned how to build a simple test application with Locust, and how to simulate a failure of a Valkey primary Pod.
We observed that the Valkey cluster was able to recover from the failure and continue to serve requests with a short spike in latency.
