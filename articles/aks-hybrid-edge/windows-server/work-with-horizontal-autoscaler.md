---
title: Use PowerShell for cluster autoscaling in AKS on Windows Server
description: Learn how to use PowerShell for cluster autoscaling in AKS on Windows Server.
ms.topic: how-to
author: davidsmatlak
ms.author: davidsmatlak
ms.lastreviewed: 06/27/2024
ms.reviewer: mikek
ms.date: 09/01/2026
ms.custom: windows-server

# Intent: As a Kubernetes user, I want to use cluster autoscaling to grow my nodes to keep up with application demand.
# Keyword: cluster autoscaling Kubernetes

---

# Use PowerShell for cluster autoscaling in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

You can use PowerShell to enable the autoscaler and to manage automatic scaling of node pools in your target clusters in AKS on Windows Server. You can also use PowerShell to configure and manage cluster autoscaling.

## Create a new AksHciAutoScalerConfig object

To create a new **AksHciAutoScalerConfig** object to pass into the `New-AksHciCluster` or `Set-AksHciCluster` command, use this command:

```powershell
New-AksHciAutoScalerProfile -Name asp1 -AutoScalerProfileConfig @{ "min-node-count"=2; "max-node-count"=7; 'scale-down-unneeded-time'='1m'}
```

You can provide the **autoscalerconfig** object when creating your cluster. The object contains the parameters for your autoscaler. For parameter information, see [How to use the autoscaler profiles](work-with-autoscaler-profiles.md).

## Change an existing AksHciAutoScalerConfig profile object

When you update an existing **AksHciAutoScalerConfig profile** object, clusters using that object are updated to use the new parameters:

```powershell
Set-AksHciAutoScalerProfile -name myProfile -autoScalerProfileConfig @{ "max-node-count"=5; "min-node-count"=2 }
```

You can update the **autoscalerconfig** object, which contains the parameters for your autoscaler. For parameter information, see [How to use the autoscaler profiles](work-with-autoscaler-profiles.md).

## Enable autoscaling for new clusters

To enable autoscaling automatically on all newly-created node pools, use the following parameters with the `New-AksHciCluster` command:

```powershell
New-AksHciCluster -name mycluster -enableAutoScaler -autoScalerProfileName myAutoScalerProfile
```

## Enable autoscaling on an existing cluster

To enable autoscaling automatically on each newly created node pool on an existing cluster, use the `enableAutoScaler` parameter with the `Set-AksHciCluster` command:

```powershell
Set-AksHciCluster -Name <string> [-enableAutoScaler <boolean>] [-autoScalerProfileName <String>] 
```

### Enable autoscaling on an existing node pool

To enable autoscaling on an existing node pool, use the `autoScaler` parameter with the `Set-AksHciNodePool` command:

```powershell
Set-AksHciNodePool -clusterName <Your-Cluster-Name> -name <Your-NodePool-Name> -autoScaler $true
```

## Disable autoscaling

To disable autoscaling on all existing and newly created node pools on an existing cluster, set `enableAutoScaler` to false using the `Set-AksHciCluster` command:

```powershell
Set-AksHciCluster -Name <string> -enableAutoScaler $false
```

## Making effective use of the horizontal autoscaler

Now that the cluster and node pool are configured to automatically scale, you can configure a workload to also scale in a way that makes use of the horizontal autoscaler capabilities.

Two methods are available for workload scaling:

* **Kubernetes Horizontal Pod Autoscaler**: Based on load characteristics, the Horizontal Pod Autoscaler (also known as the *horizontal autoscaler*) scales the pods of an application deployment to available nodes in the Kubernetes cluster. If no more nodes are available to be scheduled, the horizontal autoscaler instantiates a new node to which to schedule the pods. If application load goes down, the nodes are scaled back again.
* **Kubernetes node anti-affinity rules**: Anti-affinity rules for a Kubernetes deployment can specify that a set of pods can't be scaled on the same node, and a different node is required to scale the workload. In combination with either load characteristics or the number of target pods for the application instances, the horizontal autoscaler instantiates new nodes in the node pool to satisfy requests. If application demand subsides, the horizontal autoscaler scales down the node pool again.

This section contains some examples.

### Horizontal Pod Autoscaler

Prerequisites:

* AKS on Windows Server is installed.
* Target cluster is installed and connected to Azure.
* One Linux node pool is deployed, with at least one active Linux worker node.
* Horizontal node autoscaler is enabled on the target cluster and the Linux node pool, as described previously.

We make use of the [Kubernetes Horizontal Pod Autoscaler Walkthrough example](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) to show how the Horizontal Pod Autoscaler works.

For the Horizontal Pod Autoscaler to work, you must deploy the Metrics Server component in your target cluster.

To deploy the metrics server to a target cluster called `mycluster`, run the following commands:

```powershell
Get-AksHciCredential -name mycluster
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

After the Kubernetes Metrics Server is deployed, you can deploy an application to the node pool, which you use to scale. We use a test application from the Kubernetes community website for this example:

```powershell  
kubectl apply -f https://k8s.io/examples/application/php-apache.yaml
deployment.apps/php-apache created
service/php-apache created
```

This command creates a deployment of an Apache web server-based PHP application that will return an "OK" message to a calling client.

Next, configure the Horizontal Pod Autoscaler to schedule a new pod when the CPU usage of the current pod reaches 50 percent, and scale from 1 to 50 pods:

```powershell
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
horizontalpodautoscaler.autoscaling/php-apache autoscaled
```

You can check the current status of the newly made Horizontal Pod Autoscaler by running the following command:

```powershell
kubectl get hpa
```

```output
NAME         REFERENCE                     TARGET    MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   0% / 50%  1         10        1          18s
```

Finally, increase the load on the web server to see it scale out. Open a new PowerShell window, and run the following command:

```powershell
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

If you go back to the previous PowerShell window and run the following command, you should see the number of pods change within a short period:

```powershell
kubectl get hpa php-apache --watch
```

```output
NAME         REFERENCE                     TARGET      MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   305% / 50%  1         10        1          3m
```

In this example, the number of pods changes from 1 to 7, as shown here:

```output
NAME         REFERENCE                     TARGET      MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   305% / 50%  1         10        7          3m
```

If this isn't enough to trigger the node autoscaler because all the pods fit on one node, open more PowerShell windows and run more load generator commands. Make sure to change the name of the pod you're creating each time you run the command. For example, use `load-generator-2` instead of `load-generator`, as shown in the following command.

```powershell
kubectl run -i --tty load-generator-2 --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

Then check the number of nodes instantiated with the following command:

```powershell
kubectl get nodes
```

```output
NAME              STATUS   ROLES                  AGE    VERSION
moc-laondkmydzp   Ready    control-plane,master   3d4h   v1.22.4
moc-lorl6k76q01   Ready    <none>                 3d4h   v1.22.4
moc-lorl4323d02   Ready    <none>                   9m   v1.22.4
moc-lorl43bc3c3   Ready    <none>                   2m   v1.22.4
```

To watch a scale-down, press CTRL-C to end the load generator pods and close the PowerShell windows associated with them. After about 30 minutes, you should see the number of pods go down. About 30 minutes later, the nodes are deprovisioned.

For more information about the Kubernetes Horizontal Pod Autoscaler, see [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

### Node affinity rules

You can use node affinity rules to enable the Kubernetes scheduler to run pods only on a specific set of nodes in a cluster or node pool based on certain characteristics of the node. To show the function of the Horizontal Node Autoscaler, you can use the same rules to ensure that only one instance of a given pod runs on each node.

Prerequisites:

* AKS is installed.
* Target cluster is installed and connected to Azure.
* One Linux node pool is deployed, with at least one active Linux Worker node.
* Horizontal Node Autoscaler is enabled on the target cluster, and the Linux node pool, as described previously.

Create a YAML file with the following content, and save it as **node-anti-affinity.yaml** in a local folder.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
spec:
  selector:
    matchLabels:
      app: store
  replicas: 4
  template:
    metadata:
      labels:
        app: store
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - store
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: redis-server
        image: redis:3.2-alpine
```

Open a PowerShell window, and load the credentials for your target cluster. In this example, the cluster is named `mycluster`:

```powershell
Get-AksHciCredential -name mycluster
```

Now, apply the YAML file to the target cluster:

```powershell
kubectl apply -f node-anti-affinity.yaml
```

After a few minutes, you can use the following command to check that the new nodes have come online:

```powershell
kubectl get nodes
```

```output
NAME              STATUS   ROLES                  AGE    VERSION
moc-laondkmydzp   Ready    control-plane,master   3d4h   v1.22.4
moc-lorl6k76q01   Ready    <none>                 3d4h   v1.22.4
moc-lorl4323d02   Ready    <none>                   9m   v1.22.4
moc-lorl43bc3c3   Ready    <none>                   9m   v1.22.4
moc-lorl44ef56c   Ready    <none>                   9m   v1.22.4
```

To remove the node, delete the deployment of the redis server with this command:

```powershell
kubectl delete -f node-anti-affinity.yaml
```

For more information about Kubernetes pod affinity rules, see [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node).

## Troubleshoot horizontal autoscaler

When the Horizontal Pod Autoscaler is enabled for a target cluster, a new Kubernetes deployment called `<cluster_name>-cluster-autoscaler` is created in the management cluster. This deployment monitors the target cluster to ensure there are enough worker nodes to schedule pods.

Here are some different ways to debug issues related to the autoscaler:

* The cluster autoscaler pods running on the management cluster collect useful information about how it makes scaling decisions, the number of nodes that it needs to bring up or remove, and any general errors that it may experience. The autoscaler saves this information to logs. Run the following command to access the logs:

  ```powershell
  kubectl --kubeconfig $(Get-AksHciConfig).Kva.kubeconfig logs -l app=<cluster_name>-cluster-autoscaler
  ```

* Cloud operator logs record Kubernetes events in the management cluster, which can be helpful to understand when the autoscaler has been enabled or disabled for a cluster and a node pool. These can be viewed by running the following command:

  ```powershell
  kubectl --kubeconfig $(Get-AksHciConfig).Kva.kubeconfig get events
  ```

* The cluster autoscaler deployment creates a `configmap` in the target cluster that it manages. This `configmap` holds information about the autoscaler's status cluster-wide level and per node pool. Run the following command against the target cluster to view the status:

  > [!NOTE]
  > Ensure you have run `Get-AksHciCredentials -Name <clustername>` to retrieve the `kubeconfig` information to access the target cluster in question.

  ```powershell
  kubectl --kubeconfig ~\.kube\config get configmap cluster-autoscaler-status -o yaml
  ```

* The cluster autoscaler logs events on the cluster autoscaler status `configmap` when it scales a cluster's node pool. You can view these logs by running this command against the target cluster:

  ```powershell
  kubectl --kubeconfig ~\.kube\config describe configmap cluster-autoscaler-status
  ```

* The cluster autoscaler emits events on pods in the target cluster when it makes a scaling decision if the pod can't be scheduled. Run this command to view the events on a pod:

  ```powershell
  kubectl --kubeconfig ~\.kube\config describe pod <pod_name>
  ```

## PowerShell reference

See the following reference pages for the PowerShell cmdlets that support cluster autoscaling:

* [Get-AksHciAutoScalerProfile](/azure/aks/aksarc/reference/ps/get-akshciautoscalerprofile)
* [Get-AksHciCluster for AKS](/azure/aks/aksarc/reference/ps/get-akshcicluster)
* [Get-AksHciNodePool for AKS](/azure/aks/aksarc/reference/ps/get-akshcinodepool)
* [New-AksHciAutoScalerProfile](/azure/aks/aksarc/reference/ps/new-akshciautoscalerprofile)
* [New-AksHciCluster](/azure/aks/aksarc/reference/ps/new-akshcicluster)
* [New-AksHciNodePool](/azure/aks/aksarc/reference/ps/new-akshcinodepool)
* [Remove-AksHciAutoScalerProfile](/azure/aks/aksarc/reference/ps/remove-akshciautoscalerprofile)
* [Set-AksHciAutoScalerProfile](/azure/aks/aksarc/reference/ps/set-akshciautoscalerprofile)
* [Set-AksHciCluster](/azure/aks/aksarc/reference/ps/set-akshcicluster)
* [Set-AksHciNodePool](/azure/aks/aksarc/reference/ps/set-akshcinodepool)

## Next steps

* [Autoscaler profiles](work-with-autoscaler-profiles.md)
* [Cluster autoscaling](concepts-cluster-autoscaling.md)
