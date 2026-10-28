---
title: Upgrade the Operating System (OS) Version for your Azure Kubernetes Service (AKS) Windows Workloads
description: Learn how to upgrade the OS version for Windows workloads on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 09/24/2026
author: allyford
ms.author: allyford
ai-usage: ai-assisted
# Customer intent: "As a cloud operations engineer, I want to upgrade the OS version for Windows workloads on Azure Kubernetes Service, so that I can ensure my applications use the latest features and security enhancements while maintaining compatibility and performance."
---

# Upgrade the operating system (OS) version for your Azure Kubernetes Service (AKS) Windows workloads

When you upgrade the OS version of a running Windows workload on Azure Kubernetes Service (AKS), use one of the following migration methods:

- **In-place migration**: Update the OS SKU on an existing node pool to migrate from Windows Server 2022 to Windows Server 2025.
- **Manual migration**: Create a new node pool with your desired Windows Server OS version, move your workloads to the new node pool, and delete the old node pool.

When a new Windows Server OS version is released, AKS is committed to supporting it. We recommend that you upgrade to the latest version to take advantage of the fixes, improvements, and new functionality. AKS provides a five-year support lifecycle for every Windows Server version, starting with Windows Server 2022. During this period, AKS releases a new version that supports a newer version of Windows Server OS for you to upgrade to. After the five-year lifecycle ends, you must migrate workloads to newer supported versions to ensure compatibility, security updates, and continued support from AKS.

[!INCLUDE [windows server 2022 retirement](./includes/windows-server-2022-retirement.md)]

The following limitations apply to Windows Server OS version migration:

- Node pool update to migrate from one Windows Server version to another is supported only for Windows Server 2022-to-Windows Server 2025 migration by using the `aks-preview` Azure CLI extension version 22.0.0b6 or later. For all other Windows Server OS version migrations, create a new node pool.
- Different Windows Server versions can't coexist on the same node pool on AKS. If you create a new node pool to host the new OS version, ensure that you match the permissions and access of the previous node pool to the new one.
- Windows Server 2025 is supported starting in Kubernetes version 1.32.0.

## Prerequisites

- Update the `FROM` statement in your Dockerfile to the new OS version.
- Check your application and verify the container app works on the new OS version.
- Deploy the verified container app on AKS to a development or testing environment.
- Take note of the new image name or tag for use in this article.
- For in-place migration from Windows Server 2022 to Windows Server 2025, install or update the `aks-preview` Azure CLI extension to version 22.0.0b6 or later.

> [!NOTE]
> To learn how to build a Dockerfile for Windows workloads, see [Dockerfile on Windows](/virtualization/windowscontainers/manage-docker/manage-windows-dockerfile) and [Optimize Windows Dockerfiles](/virtualization/windowscontainers/manage-docker/optimize-windows-dockerfile).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Install the `aks-preview` Azure CLI extension

- To install the aks-preview extension, run the following command:

    
## In-place migration from Windows Server 2022 to Windows Server 2025

You can migrate an existing Windows Server 2022 node pool to Windows Server 2025 in place by updating the OS SKU on the existing node pool with the `az aks nodepool update` command. This migration path uses the `aks-preview` Azure CLI extension version 22.0.0b6 or later. The cluster must run Kubernetes version 1.32 to 1.36 where both OS versions are supported.


### In-place migration considerations

Consider the following details before you migrate a Windows Server 2022 node pool to Windows Server 2025:

- Windows Server 2025 uses FIPS-enabled images by default. If your Windows Server 2022 node pool doesn't already use a FIPS-enabled image, include `--enable-fips-image` when you run the update command.
- The update command triggers an automatic reimage of the existing node pool.
- Windows Server 2025 uses Generation 2 VMs by default. You don't need to have an existing Generation 2 Windows Server 2022 node pool to migrate in place. Standard Windows Server 2022 `containerd` node pools are supported.
- If the existing VM size supports Generation 2, AKS can select a Windows Server 2025 Generation 2 image during migration. This default image selection might affect image compatibility for some configurations.

The following table describes which source configurations support in-place migration with the update command. For unsupported configurations, use [manual migration](#manual-migration-to-a-new-node-pool) instead.

| Existing configuration | Support | Result |
| -- | -- | -- |
| Standard Windows Server 2022 `containerd` Generation 1 image with a Generation 1-only VM size | Yes | Migrates to Windows Server 2025 Generation 1. |
| Standard Windows Server 2022 `containerd` Generation 1 image with a Generation 2-capable VM size | Yes | Migrates to Windows Server 2025 Generation 2. |
| Standard Windows Server 2022 `containerd` Generation 2 image with a Generation 2-capable VM size | Yes | Migrates to Windows Server 2025 Generation 2. |

### Update existing Windows Server 2022 node pool to Windows Server 2025

1. Update the node pool OS SKU to `Windows2025` by using the [`az aks nodepool update`][az-aks-nodepool-update] command.

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --os-sku Windows2025 \
        --enable-fips-image
    ```

1. Verify that a node in the updated node pool uses the `Windows2025` OS SKU and a Windows Server 2025 image by using the `kubectl describe node` command.

    ```bash
    kubectl describe node <node-name>
    ```

    The following condensed example output shows the `Windows2025` OS SKU label and Windows Server 2025 OS image:

    ```output
    Labels:
      kubernetes.azure.com/os-sku=Windows2025
      kubernetes.io/os=windows
    ...
    System Info:
      OS Image:                   Windows Server 2025 Datacenter
      Container Runtime Version:  containerd://2.0.4+azure
    ```

## Manual migration to a new node pool

Manual migration uses a new node pool instead of updating the existing node pool. Use manual migration for Windows Server OS version migrations that don't support in-place migration, or when your source configuration isn't supported for in-place migration. To manually migrate, create a new node pool with your desired Windows Server OS version and move your workloads to the new node pool.

### Add a new node pool to an existing cluster

Add a node pool with your desired OS version to your existing cluster:

- [Use CLI to add a Windows node pool](./learn/quick-windows-container-deploy-cli.md) to an existing cluster.
- [Use Portal to add a Windows node pool](./learn/quick-windows-container-deploy-portal.md) to an existing cluster.
- [Use PowerShell to add a Windows node pool](./learn/quick-windows-container-deploy-powershell.md) to an existing cluster.
- [Use Terraform to add a Windows node pool](./learn/quick-windows-container-deploy-terraform.md) to an existing cluster.

Windows Server 2025 node pools require a FIPS-enabled image. When you add a Windows Server 2025 node pool, include `--enable-fips-image` (Azure CLI) or `-EnableFIPS` (Azure PowerShell).

### Update the YAML file

Node Selector is the most common and recommended option for placement of Windows pods on Windows nodes.

1. Add Node Selector to your YAML file by adding the following annotation:

    ```yaml
          nodeSelector:
            "kubernetes.io/os": windows
    ```

    The annotation finds any available Windows node and places the pod on that node (following all other scheduling rules). When upgrading your OS version, you need to enforce the placement on a Windows node and a node running the latest OS version. To accomplish this, one option is to use a different annotation. Update `<OSSKU>` to match the ossku your desired Windows OS version, for example `Windows2025`.

    ```yaml
          nodeSelector:
            "kubernetes.azure.com/os-sku": <OSSKU>
    ```

1. Once you update the `nodeSelector` in the YAML file, you also need to update the container image you want to use. You can get this information from the previous step in which you created a new version of the containerized application by changing the `FROM` statement on your Dockerfile.

    > [!NOTE]
    > You should use the same YAML file you used to initially deploy the application. This ensures that no other configuration changes besides the `nodeSelector` and container image.

### Apply the updated YAML file to the existing workload

1. View the nodes on your cluster using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes -o wide
    ```

    The following example output shows all nodes on the cluster, including the new node pool you created and the existing node pools:

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
    aks-agentpool-18877473-vmss000000   Ready    agent   5h40m   v1.33.12   10.240.0.4     <none>        Ubuntu 22.04.5 LTS               5.15.0-1116-azure  containerd://1.7.33-1
    akspoolws000000                     Ready    agent   3h15m   v1.33.12   10.240.0.208   <none>        Windows Server 2022 Datacenter   10.0.20348.825     containerd://1.6.6+azure
    akspoolws000001                     Ready    agent   3h17m   v1.33.12   10.240.0.239   <none>        Windows Server 2022 Datacenter   10.0.20348.825     containerd://1.6.6+azure
    akspoolws000002                     Ready    agent   3h17m   v1.33.12   10.240.1.14    <none>        Windows Server 2022 Datacenter   10.0.20348.825     containerd://1.6.6+azure
    akswspool000000                     Ready    agent   5h37m   v1.33.12   10.240.0.115   <none>        Windows Server 2025 Datacenter   10.0.26100.32995    containerd://2.0.4+azure
    akswspool000001                     Ready    agent   5h37m   v1.33.12   10.240.0.146   <none>        Windows Server 2025 Datacenter   10.0.26100.32995    containerd://2.0.4+azure
    akswspool000002                     Ready    agent   5h37m   v1.33.12   10.240.0.177   <none>        Windows Server 2025 Datacenter   10.0.26100.32995    containerd://2.0.4+azure
    ```

1. Apply the updated YAML file to the existing workload using the `kubectl apply` command and specify the name of the YAML file.

    ```bash
    kubectl apply -f <filename>
    ```

    The following example output shows a _configured_ status for the deployment:

    ```output
    deployment.apps/sample configured
    service/sample unchanged
    ```

    At this point, AKS starts the process of terminating the existing pods and deploying new pods to the nodes with the `nodeSelector` annotation.

1. Check the status of the deployment using the `kubectl get pods` command.

    ```bash
    kubectl get pods -o wide
    ```

    The following example output shows the pods in the `default` namespace:

    ```output
    NAME                      READY   STATUS    RESTARTS   AGE     IP             NODE              NOMINATED NODE   READINESS GATES
    sample-7794bfcc4c-k62cq   1/1     Running   0          2m49s   10.240.0.238   akspoolws000000   <none>           <none>
    sample-7794bfcc4c-rswq9   1/1     Running   0          2m49s   10.240.1.10    akspoolws000001   <none>           <none>
    sample-7794bfcc4c-sh78c   1/1     Running   0          2m49s   10.240.0.228   akspoolws000000   <none>           <none>
    ```

### Update security and authentication configuration

If you're using Group Managed Service Accounts (gMSA), you need to update the Managed Identity configuration for the new node pool. gMSA uses a secret (user account and password) so the node that runs the Windows pod can authenticate the container against Microsoft Entra ID. To access that secret on Azure Key Vault, the node uses a Managed Identity that allows the node to access the resource. Since Managed Identities are configured per node pool, and the pod now resides on a new node pool, you need to update that configuration. For more information, see [Enable Group Managed Service Accounts (GMSA) for your Windows Server nodes on your Azure Kubernetes Service (AKS) cluster](./use-group-managed-service-accounts.md).

The same principle applies to Managed Identities for any other pod or node pool when accessing other Azure resources. You need to update any access that Managed Identity provides to reflect the new node pool. To view update and sign-in activities, see [How to view Managed Identity activity](/azure/active-directory/managed-identities-azure-resources/how-to-view-managed-identity-activity).

## Next steps

In this article, you learned how to upgrade the OS version for Windows workloads on AKS. To learn more about Windows workloads on AKS, see [Deploy a Windows container application on Azure Kubernetes Service (AKS)](./learn/quick-windows-container-deploy-cli.md).

<!-- LINKS - External -->
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
