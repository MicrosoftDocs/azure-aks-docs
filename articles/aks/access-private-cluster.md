---
title: 'Access a private Azure Kubernetes Service (AKS) cluster using the command invoke or Run command feature'
description: Learn how to access a private Azure Kubernetes Service (AKS) cluster using the Azure CLI command invoke feature or the Azure portal Run command feature.
ms.topic: concept-article
ms.subservice: aks-security
ms.custom: devx-track-azurecli, innovation-engine, copilot-scenario-highlight, annual
ms.date: 06/10/2025
ms.service: azure-kubernetes-service
author: schaffererin
ms.author: schaffererin
# Customer intent: As a cloud administrator, I want to access a private Azure Kubernetes Service cluster using the command invoke feature, so that I can run management commands without configuring complex network setups like VPNs or Express Routes.
---

# Access a private Azure Kubernetes Service (AKS) cluster using the command invoke or Run command feature

> [!div class="nextstepaction"]
> [Deploy and Explore](https://go.microsoft.com/fwlink/?linkid=2331629)

When you access a private Azure Kubernetes Service (AKS) cluster, you need to connect to the cluster from the cluster virtual network (VNet), a peered network, or a configured private endpoint. These approaches require extra configuration, such as setting up a VPN or Express Route.

With the Azure CLI, you can use `command invoke` to access private clusters without the need to configure a VPN or Express Route. `command invoke` allows you to remotely invoke commands, like `kubectl` and `helm`, on your private cluster through the Azure API without directly connecting to the cluster. The `Microsoft.ContainerService/managedClusters/runcommand/action` and `Microsoft.ContainerService/managedclusters/commandResults/read` actions control the permissions for using `command invoke`.

With the Azure portal, you can use the `Run command` feature to run commands on your private cluster. The `Run command` feature uses the same `command invoke` functionality to run commands on your cluster. The pod created by `Run command` provides `kubectl` and `helm` for operating your cluster. `jq`, `xargs`, `grep`, and `awk` are available for Bash support.

> [!TIP]
> You can use Azure Copilot to run `kubectl` commands in the Azure portal. For more information, see [Work with AKS clusters efficiently using Azure Copilot](/azure/copilot/work-aks-clusters#run-cluster-commands).

## Prerequisites

To use the `command invoke` or `Run command` feature to access a private AKS cluster, you need the following prerequisites:

- An existing private AKS cluster. If you don't have one, see [Create a private AKS cluster](./private-clusters.md).
- The Azure CLI version 2.24.0 or later. Check your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- Access to the `Microsoft.ContainerService/managedClusters/runcommand/action` and `Microsoft.ContainerService/managedclusters/commandResults/read` roles on the cluster.

### Limitations

This feature is designed to simplify cluster access and is **_not designed for programmatic access_**. You should use direct API access via Bastion, VPN, or Express Route for programmatic calls to your cluster.

If you have a program invoke Kubernetes using `Run command`, the following disadvantages apply:

- You only get _exitCode_ and _text output_, and you lose API level details.
- One extra hop introduces extra failure points.

The pod created by `Run command` has `200m CPU` and `500Mi memory` requests, and `500m CPU` and `1Gi memory` limits. In cases where all your nodes are full or over committed, the pod might be unable to be scheduled within the Azure Resource Manager (ARM) API timeout of 60 seconds, which means the `Run command` invocation fails.

`command invoke` runs the commands from your cluster, so any commands you run in this manner are subject to your configured networking restrictions and any other configured restrictions. Make sure there are enough nodes and resources in your cluster to schedule the command pod.

> [!NOTE]
> The output for `command invoke` is limited to 512kB in size.

## Use `command invoke` on a private AKS cluster with the Azure CLI

- Set environment variables for your resource group and cluster name to use in subsequent commands.

    ```bash
    export AKS_RESOURCE_GROUP="<resource-group-name>"
    export AKS_CLUSTER_NAME="<cluster-name>"
    ```

    These environment variables allow you to run AKS commands without having to rewrite their names.

### Use `command invoke` to run a single command

- Run a single command on your cluster using the [`az aks command invoke`](/cli/azure/aks/command#az-aks-command-invoke) command and the `--command` parameter to specify the command to run. The following example gets the pods in the `kube-system` namespace.

    ```azurecli-interactive
    az aks command invoke \
      --resource-group $AKS_RESOURCE_GROUP \
      --name $AKS_CLUSTER_NAME \
      --command "kubectl get pods -n kube-system"
    ```

### Use `command invoke` to run multiple commands

- Run multiple commands on your cluster using the [`az aks command invoke`](/cli/azure/aks/command#az-aks-command-invoke) command and the `--command` parameter to specify the commands to run. The following example adds the Bitnami Helm chart repository, updates the repository, and installs the `nginx` chart.

    ```azurecli-interactive
    az aks command invoke \
      --resource-group $AKS_RESOURCE_GROUP \
      --name $AKS_CLUSTER_NAME \
      --command "helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update && helm install my-release bitnami/nginx"
    ```

### Use `command invoke` to run commands with an attached file

If you want to run a command with an attached file, the file must exist and be accessible in your current working directory. In the following example, we create a minimal deployment file for demonstration.

1. Create a Kubernetes manifest file named `deployment.yaml`. The following example deployment file deploys an `nginx` pod.

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
    ```

1. Apply the deployment file to your cluster using the [`az aks command invoke`](/cli/azure/aks/command#az-aks-command-invoke) command with the `--file` parameter to attach the file. The following example applies the `deployment.yaml` file to the `default` namespace.

    ```azurecli-interactive
    az aks command invoke \
      --resource-group $AKS_RESOURCE_GROUP \
      --name $AKS_CLUSTER_NAME \
      --command "kubectl apply -f deployment.yaml -n default" \
      --file deployment.yaml
    ```

### Use `command invoke` to run commands with all files in the current directory

> [!NOTE]
> Use only small, necessary files to avoid exceeding system size limits.

In the following example, we create two minimal deployment files for demonstration.

1. Create two Kubernetes manifest files named `deployment.yaml` and `configmap.yaml`. The following example deployment files deploy an `nginx` pod and create a ConfigMap with a welcome message.

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
    ```

1. Apply the deployment files to your cluster using the [`az aks command invoke`](/cli/azure/aks/command#az-aks-command-invoke) command with the `--file` parameter to attach the file. The following example applies the `deployment.yaml` and `configmap.yaml` files to the `default` namespace.

    ```azurecli-interactive
    az aks command invoke \
      --resource-group $AKS_RESOURCE_GROUP \
      --name $AKS_CLUSTER_NAME \
      --command "kubectl apply -f deployment.yaml -f configmap.yaml -n default" \
      --file deployment.yaml \
      --file configmap.yaml
    ```

## Use `Run command` on a private AKS cluster in the Azure portal

You can use the following `kubectl` commands with the `Run command` feature:

- `kubectl get nodes`
- `kubectl get deployments`
- `kubectl get pods`
- `kubectl describe nodes`
- `kubectl describe pod <pod-name>`
- `kubectl describe deployment <deployment-name>`
- `kubectl apply -f <file-name>`

### Use `Run command` to run a single command

1. In the Azure portal, navigate to your private cluster.
1. From the service menu, under **Kubernetes resources**, select **Run command**.
1. Enter the command you want to run and select **Run**.

### Use `Run command` to run commands with attached files

1. In the Azure portal, navigate to your private cluster.
1. From the service menu, under **Kubernetes resources**, select **Run command**.
1. Select **Attach files** > **Browse for files**.

    :::image type="content" source="media/access-private-cluster/azure-portal-run-command-attach-files.png" alt-text="Screenshot of attaching files to the Azure portal Run command.":::

1. Select the file or files you want to attach, and then select **Attach**.
1. Enter the command you want to run and select **Run**.

## Disable `Run command`

You can disable the `Run command` feature by setting [`.properties.apiServerAccessProfile.disableRunCommand` to `true`](/rest/api/aks/managed-clusters/create-or-update).

## Troubleshoot `command invoke` issues

For information on the most common issues with `az aks command invoke` and how to fix them, see [Resolve `az aks command invoke` failures][command-invoke-troubleshoot].

## Related content

In this article, you learned how to access a private cluster and run commands on that cluster. For more information on AKS clusters, see the following articles:

- [Use a private endpoint connection in AKS](./private-cluster-connect.md#use-a-private-endpoint-connection)
- [Virtual network peering in AKS](./private-cluster-connect.md#connect-using-virtual-network-vnet-peering)

<!-- links - internal -->
[command-invoke-troubleshoot]: /troubleshoot/azure/azure-kubernetes/resolve-az-aks-command-invoke-failures
