---
title: Upgrade the Operating System (OS) Version for your Azure Kubernetes Service (AKS) Windows Workloads
description: Learn how to upgrade the OS version for Windows workloads on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 07/13/2026
author: allyford
ms.author: allyford
# Customer intent: "As a cloud operations engineer, I want to upgrade the OS version for Windows workloads on Azure Kubernetes Service, so that I can ensure my applications use the latest features and security enhancements while maintaining compatibility and performance."
---

# Upgrade the operating system (OS) version for your Azure Kubernetes Service (AKS) Windows workloads

When upgrading the OS version of a running Windows workload on Azure Kubernetes Service (AKS), you need to deploy a new node pool to ensure the Windows versions match on each node pool. This article describes the steps to upgrade the OS version for Windows workloads on AKS.

## Windows Server OS version support

When a new Windows Server OS version is released, AKS is committed to supporting it. We recommend that you upgrade to the latest version to take advantage of the fixes, improvements, and new functionality. AKS provides a five-year support lifecycle for every Windows Server version, starting with Windows Server 2022. During this period, AKS releases a new version that supports a newer version of Windows Server OS for you to upgrade to. After the five-year lifecycle ends, you must migrate workloads to newer supported versions to ensure compatibility, security updates, and continued support from AKS.

[!INCLUDE [windows server 2022 retirement](./includes/windows-server-2022-retirement.md)]

## Limitations

- Node pool update to migrate from one Windows Server version to another isn't supported.
- Different Windows Server versions can't coexist on the same node pool on AKS. You need to create a new node pool to host the new OS version. It's important that you match the permissions and access of the previous node pool to the new one.
- Windows Server 2025 is supported starting in Kubernetes version 1.32.

## Before you begin

- Update the `FROM` statement in your Dockerfile to the new OS version.
- Check your application and verify the container app works on the new OS version.
- Deploy the verified container app on AKS to a development or testing environment.
- Take note of the new image name or tag for use in this article.

> [!NOTE]
> To learn how to build a Dockerfile for Windows workloads, see [Dockerfile on Windows](/virtualization/windowscontainers/manage-docker/manage-windows-dockerfile) and [Optimize Windows Dockerfiles](/virtualization/windowscontainers/manage-docker/optimize-windows-dockerfile).

## Add a new node pool to an existing cluster

Add a node pool with your desired OS version to your existing cluster:

- [Use CLI to add a Windows node pool](./learn/quick-windows-container-deploy-cli.md) to an existing cluster.
- [Use Portal to add a Windows node pool](./learn/quick-windows-container-deploy-portal.md) to an existing cluster.
- [Use PowerShell to add a Windows node pool](./learn/quick-windows-container-deploy-powershell.md) to an existing cluster.
- [Use Terraform to add a Windows node pool](./learn/quick-windows-container-deploy-terraform.md) to an existing cluster.

Windows Server 2025 node pools require a FIPS-enabled image. When you add a Windows Server 2025 node pool, include `--enable-fips-image` (Azure CLI) or `-EnableFIPS` (Azure PowerShell).

## Update the YAML file

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

## Apply the updated YAML file to the existing workload

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

## Security and authentication considerations

If you're using Group Managed Service Accounts (gMSA), you need to update the Managed Identity configuration for the new node pool. gMSA uses a secret (user account and password) so the node that runs the Windows pod can authenticate the container against Microsoft Entra ID. To access that secret on Azure Key Vault, the node uses a Managed Identity that allows the node to access the resource. Since Managed Identities are configured per node pool, and the pod now resides on a new node pool, you need to update that configuration. For more information, see [Enable Group Managed Service Accounts (GMSA) for your Windows Server nodes on your Azure Kubernetes Service (AKS) cluster](./use-group-managed-service-accounts.md).

The same principle applies to Managed Identities for any other pod or node pool when accessing other Azure resources. You need to update any access that Managed Identity provides to reflect the new node pool. To view update and sign-in activities, see [How to view Managed Identity activity](/azure/active-directory/managed-identities-azure-resources/how-to-view-managed-identity-activity).

## Next steps

In this article, you learned how to upgrade the OS version for Windows workloads on AKS. To learn more about Windows workloads on AKS, see [Deploy a Windows container application on Azure Kubernetes Service (AKS)](./learn/quick-windows-container-deploy-cli.md).

<!-- LINKS - External -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
