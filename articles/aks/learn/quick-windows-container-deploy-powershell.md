---
title: Deploy a Windows Server Container on an Azure Kubernetes Service (AKS) Cluster using PowerShell
description: Learn how to quickly deploy a Kubernetes cluster and deploy an application in a Windows Server container in Azure Kubernetes Service (AKS) using PowerShell.
ms.topic: quickstart
ms.date: 07/07/2025
author: schaffererin
ms.author: schaffererin
ms.custom: devx-track-azurepowershell
ms.service: azure-kubernetes-service
# Customer intent: As a developer or cluster operator, I want to quickly deploy an AKS cluster and deploy a Windows Server container so that I can see how to run applications running on a Windows Server container using the managed Kubernetes service in Azure.
---

# Deploy a Windows Server container on an Azure Kubernetes Service (AKS) cluster using PowerShell

Azure Kubernetes Service (AKS) is a managed Kubernetes service that lets you quickly deploy and manage clusters. In this article, you use Azure PowerShell to deploy an AKS cluster that runs Windows Server containers. You also deploy an ASP.NET sample application in a Windows Server container to the cluster.

> [!NOTE]
> To get started with quickly provisioning an AKS cluster, this article includes steps to deploy a cluster with default settings for evaluation purposes only. Before deploying a production-ready cluster, we recommend that you familiarize yourself with our [baseline reference architecture][baseline-reference-architecture] to consider how it aligns with your business requirements.

## Before you begin

This quickstart assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for Azure Kubernetes Service (AKS)](../concepts-clusters-workloads.md).

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
- For ease of use, try the PowerShell environment in [Azure Cloud Shell](/azure/cloud-shell/overview). For more information, see [Quickstart for Azure Cloud Shell](/azure/cloud-shell/quickstart).

    If you want to use PowerShell locally, then install the [Az PowerShell](/powershell/azure/new-azureps-module-az) module and connect to your Azure account using the [Connect-AzAccount](/powershell/module/az.accounts/Connect-AzAccount) cmdlet. Make sure that you run the commands with administrative privileges. For more information, see [Install Azure PowerShell][install-azure-powershell].

- Make sure that the identity you're using to create your cluster has the appropriate minimum permissions. For more details on access and identity for AKS, see [Access and identity options for Azure Kubernetes Service (AKS)](../concepts-identity.md).
- If you have more than one Azure subscription, set the subscription that you wish to use for the quickstart by calling the [Set-AzContext](/powershell/module/az.accounts/set-azcontext) cmdlet. For more information, see [Manage Azure subscriptions with Azure PowerShell](/powershell/azure/manage-subscriptions-azureps#change-the-active-subscription).
- If you're using osSku `Windows2025`, you need to install the `aks-preview` extension and register the preview flag.
- Specifying the `OsSKU` parameter requires PowerShell Az module version 9.2.0 or higher.

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

- Create a resource group using the [`New-AzResourceGroup`][new-azresourcegroup] cmdlet. The following example creates a resource group named _myResourceGroup_ in the _eastus_ region.

    ```azurepowershell-interactive
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    ```

    The following example output shows that the resource group was created successfully:

    ```output
    ResourceGroupName : myResourceGroup
    Location          : eastus
    ProvisioningState : Succeeded
    Tags              :
    ResourceId        : /subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/myResourceGroup
    ```

## Create an AKS cluster

In this section, we create an AKS cluster with the following configuration:

- The cluster is configured with two nodes to ensure it operates reliably. A [node](../concepts-clusters-workloads.md#nodes) is an Azure virtual machine (VM) that runs the Kubernetes node components and container runtime.
- The `-WindowsProfileAdminUserName` and `-WindowsProfileAdminUserPassword` parameters set the administrator credentials for any Windows Server nodes on the cluster and must meet the [Windows Server password complexity requirements][windows-server-password].
- The node pool uses `VirtualMachineScaleSets`.

Use the following steps to create the AKS cluster with Azure PowerShell:

1. Create the administrator credentials for your Windows Server containers using the following command. This command prompts you to enter a `WindowsProfileAdminUserName` and `WindowsProfileAdminUserPassword`. The password must be a minimum of 14 characters and meet the [Windows Server password complexity requirements][windows-server-password].

    ```azurepowershell-interactive
    $AdminCreds = Get-Credential `
        -Message 'Please create the administrator credentials for your Windows Server containers'
    ```

1. Create your cluster using the [`New-AzAksCluster`][new-azakscluster] cmdlet and specify the `WindowsProfileAdminUserName` and `WindowsProfileAdminUserPassword` parameters.

    ```azurepowershell-interactive
    New-AzAksCluster -ResourceGroupName myResourceGroup `
        -Name myAKSCluster `
        -NodeCount 2 `
        -NetworkPlugin azure `
        -NodeVmSetType VirtualMachineScaleSets `
        -WindowsProfileAdminUserName $AdminCreds.UserName `
        -WindowsProfileAdminUserPassword $secureString `
        -GenerateSshKey
    ```

    After a few minutes, the command completes and returns JSON-formatted information about the cluster. Occasionally, the cluster can take longer than a few minutes to provision. Allow up to 10 minutes for provisioning.

    If you get a password validation error, and the password that you set meets the length and complexity requirements, try creating your resource group in another region. Then try creating the cluster with the new resource group.

    If you don't specify an administrator username and password when creating the node pool, the username is set to _azureuser_ and the password is set to a random value. For more information, see the [Windows Server FAQ](../windows-faq.yml).

    The administrator username can't be changed, but you can change the administrator password that your AKS cluster uses for Windows Server nodes using `az aks update`. For more information, see the [Windows Server FAQ](../windows-faq.yml).

    To run an AKS cluster that supports node pools for Windows Server containers, your cluster needs to use a network policy that uses [Azure CNI (advanced)][azure-cni] network plugin. The `-NetworkPlugin azure` parameter specifies Azure CNI.

## Add a node pool

By default, an AKS cluster is created with a node pool that can run Linux containers. You must add another node pool that can run Windows Server containers alongside the Linux node pool.

To create a Windows node pool, you need to specify a supported `OsType` and `OsSku`. Use the information in the following table to determine which is appropriate for your cluster:

| `OsType` | `OsSku` | Default | Supported K8s versions | Details |
|--|--|--|--|--|
| `windows` | `Windows2025` | Not default. Currently in preview. | 1.32+ | Updated defaults: containerd 2.0, Generation 2 image is used by default. |
| `windows` | `Windows2022` | Default in K8s 1.25-1.34 | Not available in K8s 1.35+ | Retires in March 2027. Updated defaults: FIPS is enabled by default |
| `windows` | `Windows2019` | Default in K8s 1.24 and below | Not available in K8s 1.32+ | Retires in March 2026. |

Windows Server 2022 is the default operating system for Kubernetes versions 1.25-1.34. Windows Server 2019 is the default OS for earlier versions. If you don't specify a particular OS SKU, Azure creates the new node pool with the default SKU for the version of Kubernetes used by the cluster.

> [!NOTE]
>
> - Windows Server 2022 retires after Kubernetes version 1.34 reaches end of support and won't be supported in Kubernetes version 1.35 and above.
> - Windows Server 2019 retires after Kubernetes version 1.32 reaches end of support and won't be supported in Kubernetes version 1.33 and above.
>
> For more information, see [AKS release notes][aks-release-notes]. To stay up to date on the latest Windows Server OS versions and learn more about our roadmap of what's planned for support on AKS, see our [AKS public roadmap](https://github.com/azure/aks/projects/1).

- Add a Windows Server node pool using the [`New-AzAksNodePool`][new-azaksnodepool] cmdlet. The following command creates a new node pool named _npwin_ and adds it to _myAKSCluster_. The command also uses the default subnet in the default virtual network created when running `New-AzAksCluster`:

    ```azurepowershell-interactive
    New-AzAksNodePool -ResourceGroupName myResourceGroup `
        -ClusterName myAKSCluster `
        -VmSetType VirtualMachineScaleSets `
        -OsType Windows `
        -OsSKU Windows2022 `
        -Name npwin
    ```

## Connect to the cluster

You use [kubectl][kubectl], the Kubernetes command-line client, to manage your Kubernetes clusters. If you use Azure Cloud Shell, `kubectl` is already installed. If you want to install `kubectl` locally, you can use the `Install-AzAzAksCliTool` cmdlet.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`Import-AzAksCredential`][import-azakscredential] cmdlet. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurepowershell-interactive
    Import-AzAksCredential -ResourceGroupName myResourceGroup -Name myAKSCluster
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command, which returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The following example output shows all the nodes in the cluster. Make sure the status of all nodes is **Ready**:

    ```output
    NAME                                STATUS   ROLES   AGE   VERSION
    aks-nodepool1-20786768-vmss000000   Ready    agent   22h   v1.27.7
    aks-nodepool1-20786768-vmss000001   Ready    agent   22h   v1.27.7
    aksnpwin000000                      Ready    agent   21h   v1.27.7
    ```

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

    ```output
    deployment.apps/sample created
    service/sample created
    ```

## Test the application

When the application runs, a Kubernetes service exposes the application front end to the internet. This process can take a few minutes to complete. Occasionally, the service can take longer than a few minutes to provision. Allow up to 10 minutes for provisioning.

1. Check the status of the deployed pods using the [`kubectl get pods`][kubectl-get] command. Make all pods are `Running` before proceeding.

    ```bash
    kubectl get pods
    ```

1. Monitor progress using the [`kubectl get service`][kubectl-get] command with the `--watch` argument.

    ```bash
    kubectl get service sample --watch
    ```

    Initially, the output shows the _EXTERNAL-IP_ for the sample service as _pending_:

    ```output
    NAME               TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
    sample             LoadBalancer   10.0.37.27   <pending>     80:30572/TCP   6s
    ```

1. When the _EXTERNAL-IP_ address changes from _pending_ to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

    The following example output shows a valid public IP address assigned to the service:

    ```output
    sample  LoadBalancer   10.0.37.27   52.179.23.131   80:30572/TCP   2m
    ```

1. See the sample app in action by opening a web browser to the external IP address of your service.

    :::image type="content" source="media/quick-windows-container-deploy-powershell/asp-net-sample-app.png" alt-text="Screenshot of browsing to ASP.NET sample application." lightbox="media/quick-windows-container-deploy-powershell/asp-net-sample-app.png":::

## Delete resources

If you don't plan on going through the [AKS tutorial][aks-tutorial], then delete your cluster to avoid incurring Azure charges.

- Remove the resource group, container service, and all related resources using the [`Remove-AzResourceGroup`](/powershell/module/az.resources/remove-azresourcegroup) cmdlet.

    ```azurepowershell-interactive
    Remove-AzResourceGroup -Name myResourceGroup
    ```

    > [!NOTE]
    > The AKS cluster was created with system-assigned managed identity (default identity option used in this quickstart). The Azure platform manages this identity, so it doesn't require removal.

## Next steps

In this quickstart, you deployed a Kubernetes cluster and then deployed an ASP.NET sample application in a Windows Server container to it. This sample application is for demo purposes only and doesn't represent all the best practices for Kubernetes applications. For guidance on creating full solutions with AKS for production, see [AKS solution guidance][aks-solution-guidance].

To learn more about AKS, and to walk through a complete code-to-deployment example, continue to the Kubernetes cluster tutorial.

> [!div class="nextstepaction"]
> [AKS tutorial][aks-tutorial]

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[dotnet-samples]: https://hub.docker.com/_/microsoft-dotnet-framework-samples/
[node-selector]: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[aks-release-notes]: https://github.com/Azure/AKS/releases
[azure-cni]: https://github.com/Azure/azure-container-networking/blob/master/docs/cni.md

<!-- LINKS - internal -->
[install-azure-powershell]: /powershell/azure/install-az-ps
[new-azresourcegroup]: /powershell/module/az.resources/new-azresourcegroup
[new-azakscluster]: /powershell/module/az.aks/new-azakscluster
[import-azakscredential]: /powershell/module/az.aks/import-azakscredential
[kubernetes-deployment]: ../concepts-clusters-workloads.md#deployments-and-yaml-manifests
[kubernetes-service]: ../concepts-network-services.md
[aks-tutorial]: ../tutorial-kubernetes-prepare-app.md
[aks-solution-guidance]: /azure/architecture/reference-architectures/containers/aks-start-here?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
[windows-server-password]: /windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
[new-azaksnodepool]: /powershell/module/az.aks/new-azaksnodepool
[baseline-reference-architecture]: /azure/architecture/reference-architectures/containers/aks/baseline-aks?toc=/azure/aks/toc.json&bc=/azure/aks/breadcrumb/toc.json
