---
title: Deploy a Windows Server Container on an Azure Kubernetes Service (AKS) Cluster using Azure CLI
description: Learn how to quickly deploy a Kubernetes cluster and deploy an application in a Windows Server container in Azure Kubernetes Service (AKS) using Azure CLI.
ms.topic: quickstart
ms.custom: devx-track-azurecli, innovation-engine
ms.date: 07/03/2025
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cloud developer, I want to deploy a Windows Server container on an Azure Kubernetes Service (AKS) cluster using the command line, so that I can efficiently manage containerized applications in a scalable environment.
---

# Deploy a Windows Server container on an Azure Kubernetes Service (AKS) cluster using Azure CLI

Azure Kubernetes Service (AKS) is a managed Kubernetes service that lets you quickly deploy and manage clusters. In this article, you use Azure CLI to deploy an AKS cluster that runs Windows Server containers. You also deploy an ASP.NET sample application in a Windows Server container to the cluster.

> [!NOTE]
> To get started with quickly provisioning an AKS cluster, this article includes steps to deploy a cluster with default settings for evaluation purposes only. Before deploying a production-ready cluster, we recommend that you familiarize yourself with our [baseline reference architecture][baseline-reference-architecture] to consider how it aligns with your business requirements.

## Before you begin

This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)](../concepts-clusters-workloads.md).

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- This article requires version 2.0.64 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- Make sure that the identity you're using to create your cluster has the appropriate minimum permissions. For more details on access and identity for AKS, see [Access and identity options for Azure Kubernetes Service (AKS)](../concepts-identity.md).
- If you have multiple Azure subscriptions, select the appropriate subscription ID in which the resources should be billed using the [`az account set`](/cli/azure/account#az-account-set) command. For more information, see [How to manage Azure subscriptions – Azure CLI](/cli/azure/manage-azure-subscriptions-azure-cli?tabs=bash#change-the-active-subscription).
- If you're using `--os-sku Windows2025`, you need to install the `aks-preview` extension and register the preview flag. The minimum version is 18.0.0b40.

### Install the `aks-preview` extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

  ```azurecli-interactive
  az extension add --name aks-preview
  ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Windows Server 2025 requires a minimum of 18.0.0b40**.

  ```azurecli-interactive
  az extension update --name aks-preview
  ```

### Register the `AksWindows2025Preview` feature flag

1. Register the `AksWindows2025Preview` feature flag using the [`az feature register`][az-feature-register] command.

  ```azurecli-interactive
  az feature register --name AksWindows2025Preview --namespace Microsoft.ContainerService
  ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

  ```azurecli-interactive
  az feature show --name AksWindows2025Preview --namespace Microsoft.ContainerService
  ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Create a resource group

An [Azure resource group](/azure/azure-resource-manager/management/overview) is a logical group in which Azure resources are deployed and managed. When you create a resource group, you're asked to specify a location. This location is where resource group metadata is stored and where your resources run in Azure if you don't specify another region during resource creation.

- Create a resource group using the [`az group create`][az-group-create] command. The following example creates a resource group named _myResourceGroup_ in the _WestUS2_ location.

    ```azurecli-interactive
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export REGION="canadacentral"
    export MY_RESOURCE_GROUP_NAME="myAKSResourceGroup$RANDOM_SUFFIX"
    az group create --name $MY_RESOURCE_GROUP_NAME --location $REGION
    ```

    Results:

    <!-- expected_similarity=0.3 -->

    ```output
    {
      "id": "/subscriptions/xxxxx-xxxxx-xxxxx-xxxxx/resourceGroups/myResourceGroupxxxxx",
      "location": "WestUS2",
      "managedBy": null,
      "name": "myResourceGroupxxxxx",
      "properties": {
        "provisioningState": "Succeeded"
      },
      "tags": null,
      "type": "Microsoft.Resources/resourceGroups"
    }
    ```

## Create an AKS cluster

In this section, we create an AKS cluster with the following configuration:

- The cluster is configured with two nodes to ensure it operates reliably. A [node](../concepts-clusters-workloads.md#nodes) is an Azure virtual machine (VM) that runs the Kubernetes node components and container runtime.
- The `--windows-admin-password` and `--windows-admin-username` parameters set the administrator credentials for any Windows Server nodes on the cluster and must meet [Windows Server password requirements][windows-server-password].
- The node pool uses `VirtualMachineScaleSets`.

Use the following steps to create the AKS cluster with Azure CLI:

1. Create a username to use as administrator credentials for the Windows Server nodes on your cluster.

    ```bash
    export WINDOWS_USERNAME="winadmin"
    ```

1. Create a password for the administrator username you created in the previous step. The password must be a minimum of 14 characters and meet the [Windows Server password complexity requirements][windows-server-password].

    ```bash
    export WINDOWS_PASSWORD=$(echo "P@ssw0rd$(openssl rand -base64 10 | tr -dc 'A-Za-z0-9!@#$%^&*()' | cut -c1-6)")
    ```

1. Create your cluster using the [`az aks create`][az-aks-create] command and specify the `--windows-admin-username` and `--windows-admin-password` parameters. The following example command creates a cluster using the values from `WINDOWS_USERNAME` and `WINDOWS_PASSWORD` you set in the previous commands. A random suffix is appended to the cluster name for uniqueness.

    ```azurecli-interactive
    export MY_AKS_CLUSTER="myAKSCluster$RANDOM_SUFFIX"
    az aks create \
        --resource-group $MY_RESOURCE_GROUP_NAME \
        --name $MY_AKS_CLUSTER \
        --node-count 2 \
        --enable-addons monitoring \
        --generate-ssh-keys \
        --windows-admin-username $WINDOWS_USERNAME \
        --windows-admin-password $WINDOWS_PASSWORD \
        --vm-set-type VirtualMachineScaleSets \
        --network-plugin azure
    ```

    After a few minutes, the command completes and returns JSON-formatted information about the cluster. Occasionally, the cluster can take longer than a few minutes to provision. Allow up to 10 minutes for provisioning.

    If you get a password validation error, and the password that you set meets the length and complexity requirements, try creating your resource group in another region. Then try creating the cluster with the new resource group.

    If you don't specify an administrator username and password when creating the node pool, the username is set to _azureuser_ and the password is set to a random value. For more information, see the [Windows Server FAQ](../windows-faq.yml)

    You can't change the administrator username, but you can change the administrator password that your AKS cluster uses for Windows Server nodes using `az aks update`. For more information, see [Windows Server FAQ](../windows-faq.yml).

    To run an AKS cluster that supports node pools for Windows Server containers, your cluster needs to use a network policy that uses [Azure CNI (advanced)][azure-cni] network plugin. The `--network-plugin azure` parameter specifies Azure CNI.

## Add a node pool

By default, all AKS clusters are created with a node pool that can run Linux containers. You must add a Windows node pool that can run Windows Server containers alongside the Linux node pool. To check if you have a Windows node pool in your cluster, you can view the nodes on your cluster using the `kubectl get nodes -o wide` command.

To create a Windows node pool, you need to specify a supported `OsType` and `OsSku`. Use the information in the following table to determine which is appropriate for your cluster:

| `OsType` | `OsSku` | Default | Supported K8s versions | Details |
|--|--|--|--|--|
| `windows` | `Windows2025` | Currently in preview. Not default. | 1.32+ | Updated defaults: containerd 2.0, Generation 2 image is used by default. |
| `windows` | `Windows2022` | Default in K8s 1.25-1.34 | Not available in K8s 1.35+ | Retires in March 2027. Updated defaults: FIPS is enabled by default. |
| `windows` | `Windows2019` | Default in K8s 1.24 and below | Not available in K8s 1.32+ | Retires in March 2026. |

Windows Server 2022 is the default operating system for Kubernetes versions 1.25-1.34. Windows Server 2019 is the default OS for earlier versions. If you don't specify a particular OS SKU, Azure creates the new node pool with the default SKU for the version of Kubernetes used by the cluster.

> [!NOTE]
>
> - Windows Server 2022 retires after Kubernetes version 1.34 reaches end of support and won't be supported in Kubernetes version 1.35 and above.
> - Windows Server 2019 retires after Kubernetes version 1.32 reaches end of support and won't be supported in Kubernetes version 1.33 and above.
>
> For more information, see [AKS release notes][aks-release-notes]. To stay up to date on the latest Windows Server OS versions and learn more about our roadmap of what's planned for support on AKS, see our [AKS public roadmap](https://github.com/azure/aks/projects/1).

- Add a Windows node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with a specified `OsType` and `OsSku`. If you don't specify a particular OS SKU, Azure creates the new node pool with the default SKU for the version of Kubernetes used by the cluster.

    ```azurecli-interactive
    az aks nodepool add \
      --resource-group $MY_RESOURCE_GROUP_NAME \
      --cluster-name $MY_AKS_CLUSTER \
      --os-type Windows \
      --os-sku Windows2022 \
      --name npwin \
      --node-count 1
    ```

    This command creates a new node pool named _npwin_ and adds it to _myAKSCluster_. The command also uses the default subnet in the default virtual network created when running `az aks create`.

## Connect to the cluster

You use [kubectl][kubectl], the Kubernetes command-line client, to manage your Kubernetes clusters. If you use Azure Cloud Shell, `kubectl` is already installed. If you want to install and run `kubectl` locally, use the [`az aks install-cli`][az-aks-install-cli] command.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command, which returns a list of the cluster nodes.

    ```bash
    kubectl get nodes -o wide
    ```

    The following example output shows all nodes in the cluster. Make sure the status of all nodes is _Ready_:

    <!-- expected_similarity=0.3 -->

    ```output
    NAME                                STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION      CONTAINER-RUNTIME
    aks-nodepool1-20786768-vmss000000   Ready    agent   22h   v1.27.7   10.224.0.4    <none>        Ubuntu 22.04.3 LTS               5.15.0-1052-azure   containerd://1.7.5-1
    aks-nodepool1-20786768-vmss000001   Ready    agent   22h   v1.27.7   10.224.0.33   <none>        Ubuntu 22.04.3 LTS               5.15.0-1052-azure   containerd://1.7.5-1
    aksnpwin000000                      Ready    agent   20h   v1.27.7   10.224.0.62   <none>        Windows Server 2022 Datacenter   10.0.20348.2159     containerd://1.6.21+azure
    ```

    > [!NOTE]
    > The container runtime for each node pool is shown under _CONTAINER-RUNTIME_. The container runtime values begin with `containerd://`, which means that they each use `containerd` for the container runtime.

## Deploy the application

A Kubernetes manifest file defines a desired state for the cluster, such as what container images to run. In this article, you use a manifest to create all objects needed to run the ASP.NET sample application in a Windows Server container. This manifest includes a [Kubernetes deployment][kubernetes-deployment] for the ASP.NET sample application and an external [Kubernetes service][kubernetes-service] to access the application from the internet.

The ASP.NET sample application is provided as part of the [.NET Framework Samples][dotnet-samples] and runs in a Windows Server container. AKS requires Windows Server containers to be based on images of _Windows Server 2019_ or greater. The Kubernetes manifest file must also define a [node selector][node-selector] to tell your AKS cluster to run your ASP.NET sample application's pod on a node that can run Windows Server containers.

1. Create a file named `sample.yaml` and copy in the following YAML definition:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: sample
      labels:
        app: sample
    spec:
      replicas: 1
      template:
        metadata:
          name: sample
          labels:
            app: sample
        spec:
          nodeSelector:
            "kubernetes.io/os": windows
          containers:
          - name: sample
            image: mcr.microsoft.com/dotnet/framework/samples:aspnetapp
            resources:
              limits:
                cpu: 1
                memory: 800M
            ports:
              - containerPort: 80
      selector:
        matchLabels:
          app: sample
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: sample
    spec:
      type: LoadBalancer
      ports:
      - protocol: TCP
        port: 80
      selector:
        app: sample
    ```

    For a breakdown of YAML manifest files, see [Deployments and YAML manifests](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

    If you create and save the YAML file locally, then you can upload the manifest file to your default directory in CloudShell by selecting the **Upload/Download files** button and selecting the file from your local file system.

1. Deploy the application using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f sample.yaml
    ```

    The following example output shows the deployment and service created successfully:

    <!-- expected_similarity=0.3 -->

    ```output
    {
      "deployment.apps/sample": "created",
      "service/sample": "created"
    }
    ```

## Test the application

When the application runs, a Kubernetes service exposes the application front end to the internet. This process can take a few minutes to complete. Occasionally, the service can take longer than a few minutes to provision. Allow up to 10 minutes for provisioning.

1. Check the status of the deployed pods using the [`kubectl get pods`][kubectl-get] command. Make sure all pods are `Running` before proceeding.

    ```bash
    kubectl get pods
    ```

1. Monitor progress using the [`kubectl get service`][kubectl-get] command with the `--watch` argument.

    ```bash
    while true; do
      export EXTERNAL_IP=$(kubectl get service sample -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
      if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "<pending>" ]]; then
        kubectl get service sample
        break
      fi
      echo "Still waiting for external IP assignment..."
      sleep 5
    done
    ```

    Initially, the output shows the _EXTERNAL-IP_ for the sample service as _pending_:

    <!-- expected_similarity=0.3 -->

    ```output
    NAME     TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)        AGE
    sample   LoadBalancer   xx.xx.xx.xx    pending          xx:xxxx/TCP     2m
    ```

1. When the _EXTERNAL-IP_ address changes from _pending_ to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

    The following example output shows a valid public IP address assigned to the service:

    ```output
    {
      "NAME": "sample",
      "TYPE": "LoadBalancer",
      "CLUSTER-IP": "10.0.37.27",
      "EXTERNAL-IP": "52.179.23.131",
      "PORT(S)": "80:30572/TCP",
      "AGE": "2m"
    }
    ```

1. See the sample app in action by opening a web browser to the external IP address of your service after a few minutes.

    :::image type="content" source="media/quick-windows-container-deploy-cli/asp-net-sample-app.png" alt-text="Screenshot of browsing to ASP.NET sample application." lightbox="media/quick-windows-container-deploy-cli/asp-net-sample-app.png":::
    
## Next steps

In this quickstart, you deployed a Kubernetes cluster and then deployed an ASP.NET sample application in a Windows Server container to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see [AKS solution guidance][aks-solution-guidance].

To learn more about AKS, and to walk through a complete code-to-deployment example, continue to the Kubernetes cluster tutorial.

> [!div class="nextstepaction"]
> [AKS tutorial][aks-tutorial]

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[node-selector]: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/
[dotnet-samples]: https://hub.docker.com/_/microsoft-dotnet-framework-samples/
[azure-cni]: https://github.com/Azure/azure-container-networking/blob/master/docs/cni.md
[aks-release-notes]: https://github.com/Azure/AKS/releases

<!-- LINKS - internal -->
[aks-tutorial]: ../tutorial-kubernetes-prepare-app.md
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-aks-install-cli]: /cli/azure/aks#az_aks_install_cli
[az-group-create]: /cli/azure/group#az_group_create
[aks-solution-guidance]: /azure/architecture/reference-architectures/containers/aks-start-here?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
[kubernetes-deployment]: ../concepts-clusters-workloads.md#deployments-and-yaml-manifests
[kubernetes-service]: ../concepts-network-services.md
[windows-server-password]: /windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
[baseline-reference-architecture]: /azure/architecture/reference-architectures/containers/aks/baseline-aks?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
