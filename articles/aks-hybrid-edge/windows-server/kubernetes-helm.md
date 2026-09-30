---
title: Install existing applications with Helm
description: Learn how to use the Helm packaging tool to deploy containers on Azure Kubernetes Service (AKS) clusters in AKS on Windows Server.
services: container-service
author: davidsmatlak
ms.topic: how-to
ms.custom: linux-related-content, windows-server
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: scooley
# Keyword: Helm charts deploy Helm
# Customer intent: As a cluster operator or developer, I want to learn how to deploy Helm into an AKS cluster and then install and manage applications using Helm charts.
---

# Install existing applications with Helm

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to configure and use Helm to install and manage Kubernetes applications in a Kubernetes cluster in AKS on Windows Server.

[Helm][helm] is an open-source packaging tool that helps you install and manage the lifecycle of Kubernetes applications. Similar to Linux package managers such as **APT** and **Sum**, Helm manages Kubernetes charts, which are packages of pre-configured Kubernetes resources.

## Before you begin

Verify that you have set up the following requirements:

* A [Kubernetes cluster](./setup.md) with at least one Linux worker node that's up and running.
* You configured your local `kubectl` environment to point to your cluster. You can use the [Get-AksHciCredential](/azure/aks/aksarc/reference/ps/get-akshcicredential) PowerShell command to access your cluster using `kubectl`.
* [Helm v3](https://helm.sh/docs/intro/install/) command line and prerequisites are installed.
* You can use [Azure CLI](/cli/azure/install-azure-cli) to run commands, if you prefer this to PowerShell.

> [!IMPORTANT]
> [!INCLUDE [helm-charts-in-mixed-linux-windows-clusters](../includes/helm-charts-in-mixed-linux-windows-clusters.md)]

## Verify your version of Helm

Use the `helm version` command to verify you have Helm 3 installed:

```console
helm version
```

The following example shows Helm version 3.5.4 installed:

```output
version.BuildInfo{Version:"v3.5.4", GitCommit:"1b5edb69df3d3a08df77c9902dc17af864ff05d1", GitTreeState:"clean", GoVersion:"go1.15.11"}
```

## Install an application with Helm v3

### Add Helm repositories

Use the [helm repo][helm-repo-add] command to add the *ingress-nginx* repository.

```console
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### Find Helm charts

Helm charts are used to deploy applications into a Kubernetes cluster. To search for pre-created Helm charts, use the [helm search][helm-search] command:

```console
helm search repo ingress-nginx
```

The following condensed example output shows some of the Helm charts available for use:

```output
NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                       
ingress-nginx/ingress-nginx     3.30.0          0.46.0          Ingress controller for Kubernetes using NGINX a...
```

To update the list of charts, use the [helm repo update][helm-repo-update] command.

```console
helm repo update
```

The following example shows a successful repo update:

```output
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
Update Complete. Happy Helming!
```

### Run Helm charts

To install charts with Helm, use the [helm install][helm-install-command] command, and specify a release name and the name of the chart to install. To see a Helm chart installation in action, install a basic nginx deployment using a Helm chart.

The following command is provided twice, one for use in Azure CLI, and one for use in a PowerShell console:

```azurecli
helm install my-nginx-ingress ingress-nginx/ingress-nginx \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

```powershell
helm install my-nginx-ingress ingress-nginx/ingress-nginx `
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux `
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

The following condensed example output shows the deployment status of the Kubernetes resources created by the Helm chart:

```output
>     --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
>     --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

NAME: my-nginx-ingress
LAST DEPLOYED: Fri May 14 17:43:27 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The nginx-ingress controller has been installed.
It may take a few minutes for the LoadBalancer IP to be available.
You can watch the status by running 'kubectl --namespace default get services -o wide -w my-nginx-ingress-ingress-nginx-controller'
...
```

Use the `kubectl get services` command to get the **EXTERNAL-IP** of your service:

```console
kubectl --namespace default get services -o wide -w my-nginx-ingress-ingress-nginx-controller
```

For example, the following command shows the **EXTERNAL-IP** for the **my-nginx-ingress-ingress-nginx-controller** service:

```output
NAME                                        TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)                      AGE   SELECTOR
my-nginx-ingress-ingress-nginx-controller   LoadBalancer   10.98.53.215 <EXTERNAL-IP>    80:31553/TCP,443:30784/TCP   72s   app.kubernetes.io/component=controller,app.kubernetes.io/instance=my-nginx-ingress,app.kubernetes.io/name=ingress-nginx
```

### List releases

To see a list of releases installed on your cluster, use the `helm list` command.

```console
helm list
```

The following example shows the **my-nginx-ingress** release deployed in the previous step:

```output
NAME                NAMESPACE    REVISION    UPDATED                                 STATUS      CHART                   APP VERSION
my-nginx-ingress    default      1           2021-05-14 17:43:27.1670709 +0000 UTC    deployed    nginx-ingress-3.30.0    0.46.0 
```

### Clean up resources

When you deploy a Helm chart, many Kubernetes resources are created. These resources include pods, deployments, and services. To clean up these resources, use the [helm uninstall][helm-cleanup] command and specify your release name, as found in the previous `helm list` command:

```console
helm uninstall my-nginx-ingress
```

The following example output shows that the release **my-nginx-ingress** has been uninstalled:

```output
release "my-nginx-ingress" uninstalled
```

## Next steps

For more information about managing Kubernetes application deployments with Helm, see the Helm documentation.

> [!div class="nextstepaction"]
> [Helm documentation][helm-documentation]

<!-- LINKS - external -->
[helm]: https://github.com/kubernetes/helm/
[helm-cleanup]: https://helm.sh/docs/intro/using_helm/#helm-uninstall-uninstalling-a-release
[helm-documentation]: https://helm.sh/docs/
[helm-install-command]: https://helm.sh/docs/intro/using_helm/#helm-install-installing-a-package
[helm-repo-add]: https://helm.sh/docs/intro/quickstart/#initialize-a-helm-chart-repository
[helm-search]: https://helm.sh/docs/intro/using_helm/#helm-search-finding-charts
[helm-repo-update]: https://helm.sh/docs/intro/using_helm/#helm-repo-working-with-repositories
