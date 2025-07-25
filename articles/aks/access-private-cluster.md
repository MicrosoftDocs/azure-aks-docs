---
title: 'Access a private Azure Kubernetes Service (AKS) cluster using the command invoke or Run command feature'
description: Learn how to access a private Azure Kubernetes Service (AKS) cluster using the Azure CLI command invoke feature or the Azure portal Run command feature.
ms.topic: concept-article
ms.subservice: aks-security
ms.custom: devx-track-azurecli, innovation-engine, copilot-scenario-highlight, annual
ms.date: 06/10/2025

author: schaffererin
ms.author: schaffererin
# Customer intent: As a cloud administrator, I want to access a private Azure Kubernetes Service cluster using the command invoke feature, so that I can run management commands without configuring complex network setups like VPNs or Express Routes.
---

# Access a private Azure Kubernetes Service (AKS) cluster using the command invoke or Run command feature

When you access a private AKS cluster, you need to connect to the cluster from the cluster virtual network, a peered network, or a configured private endpoint. These approaches require configuring a VPN, Express Route, deploying a *jumpbox* within the cluster virtual network, or creating a private endpoint inside of another virtual network.

With the Azure CLI, you can use `command invoke` to access private clusters without the need to configure a VPN or Express Route. `command invoke` allows you to remotely invoke commands, like `kubectl` and `helm`, on your private cluster through the Azure API without directly connecting to the cluster. The `Microsoft.ContainerService/managedClusters/runcommand/action` and `Microsoft.ContainerService/managedclusters/commandResults/read` actions control the permissions for using `command invoke`.

With the Azure portal, you can use the `Run command` feature to run commands on your private cluster. The `Run command` feature uses the same `command invoke` functionality to run commands on your cluster.

> [!TIP]
> You can use Microsoft Copilot in Azure to run `kubectl` commands in the Azure portal. For more information, see [Work with AKS clusters efficiently using Microsoft Copilot in Azure](/azure/copilot/work-aks-clusters#run-cluster-commands).

The pod created by the `Run command` provides `kubectl` and `helm` for operating your cluster. `jq`, `xargs`, `grep`, and `awk` are available for Bash support.

## Before you begin

Before you begin, make sure you have the following resources and permissions:

* An existing private cluster. If you don't have one, see [Create a private AKS cluster](./private-clusters.md).
* The Azure CLI version 2.24.0 or later. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* Access to the `Microsoft.ContainerService/managedClusters/runcommand/action` and `Microsoft.ContainerService/managedclusters/commandResults/read` roles on the cluster.

### Limitations

This feature is designed to simplify cluster access and is ***not designed for programmatic access***. You should leverage direct API access via Bastion, VPN, or Express Route for programmatic calls to your cluster.

If you have a program invoke Kubernetes using `Run command`, the following disadvantages apply:

* You only get *exitCode* and *text output*, and you lose API level details.
* One extra hop introduces extra failure points.

The pod created by the `Run command` has `200m CPU` and `500Mi memory` requests, and a `500m CPU` and `1Gi memory` limits. In cases where all your node is full or over committed, the pod might be unable to be scheduled within the ARM API timeout of 60 seconds. This means that the `Run command` invocation would fail.

`command invoke` runs the commands from your cluster, so any commands ran in this manner are subject to your configured networking restrictions and any other configured restrictions. Make sure there are enough nodes and resources in your cluster to schedule this command pod.

> [!NOTE]
> The output for `command invoke` is limited to 512kB in size. 

## Run commands on your AKS cluster

### [Azure CLI - `command invoke`](#tab/azure-cli)

Below are examples of how to use `az aks command invoke` to execute commands against a private AKS cluster. These examples assume you have an existing resource group and AKS cluster.

#### Use `command invoke` to run a single command

You can run a command on your cluster using the `az aks command invoke --command` command. The following example command runs the `kubectl get pods -n kube-system` command on the *myPrivateCluster* cluster in *myResourceGroup*.

First, set environment variables for your resource group and cluster name to use in subsequent commands.

```bash
export AKS_RESOURCE_GROUP="myResourceGroup"
export AKS_CLUSTER_NAME="myPrivateCluster"
```

The environment variables above will allow you to run AKS commands in the next sections without having to rewrite their names.

To run a single kubectl command on your AKS cluster:

```azurecli
az aks command invoke \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --command "kubectl get pods -n kube-system"
```

#### Use `command invoke` to run multiple commands

You can also run multiple commands. The following example executes three `helm` commands in sequence on the cluster.

```azurecli
az aks command invoke \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --command "helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update && helm install my-release bitnami/nginx"
```

#### Use `command invoke` to run commands with an attached file

When using the `--file` parameter with `az aks command invoke`, the file must exist and be accessible in your current working directory. Below, we create a minimal deployment file for demonstration.

To run a command with a file attached, first create a Kubernetes manifest file named `deployment.yaml`. The following example creates a small nginx deployment and applies it with `command invoke`:

```bash
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.6
        ports:
        - containerPort: 80
EOF

az aks command invoke \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --command "kubectl apply -f deployment.yaml -n default" \
  --file deployment.yaml
```

#### Use `command invoke` to run commands with all files in the current directory attached

Use only small, necessary files to avoid exceeding system size limits. Below, two minimal YAML files are created before attaching them.

```bash
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.6
        ports:
        - containerPort: 80
EOF

cat <<EOF > configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  welcome-message: "Hello from configmap"
EOF

az aks command invoke \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --command "kubectl apply -f deployment.yaml -f configmap.yaml -n default" \
  --file deployment.yaml \
  --file configmap.yaml
```

### [Azure portal - `Run command`](#tab/azure-portal)

To get started with `Run command`, navigate to your private cluster in the Azure portal. In the service menu, under **Kubernetes resources**, select **Run command**.

### `Run command` commands

You can use the following kubectl commands with the `Run command` feature:

* `kubectl get nodes`
* `kubectl get deployments`
* `kubectl get pods`
* `kubectl describe nodes`
* `kubectl describe pod <pod-name>`
* `kubectl describe deployment <deployment-name>`
* `kubectl apply -f <file-name>`

### Use `Run command` to run a single command

1. In the Azure portal, navigate to your private cluster.
2. In the service menu, under **Kubernetes resources**, select **Run command**.
3. Enter the command you want to run and select **Run**.

### Use `Run command` to run commands with attached files

1. In the Azure portal, navigate to your private cluster.
2. In the service menu, under **Kubernetes resources**, select **Run command**.
3. Select **Attach files** > **Browse for files**.

    :::image type="content" source="media/access-private-cluster/azure-portal-run-command-attach-files.png" alt-text="Screenshot of attaching files to the Azure portal Run command.":::

4. Select the file(s) you want to attach and then select **Attach**.
5. Enter the command you want to run and select **Run**.

---

## Disable `Run command`

You can disable the `Run command` feature by setting [`.properties.apiServerAccessProfile.disableRunCommand` to `true`](/rest/api/aks/managed-clusters/create-or-update).


## Troubleshooting

For information on the most common issues with `az aks command invoke` and how to fix them, see [Resolve `az aks command invoke` failures][command-invoke-troubleshoot].

## Next steps

In this article, you learned how to access a private cluster and run commands on that cluster. For more information on AKS clusters, see the following articles:

* [Use a private endpoint connection in AKS](./private-clusters.md#use-a-private-endpoint-connection)
* [Virtual networking peering in AKS](./private-clusters.md#virtual-network-peering)
* [Hub and spoke with custom DNS in AKS](./private-clusters.md#hub-and-spoke-with-custom-dns)

<!-- links - internal -->
[command-invoke-troubleshoot]: /troubleshoot/azure/azure-kubernetes/resolve-az-aks-command-invoke-failures