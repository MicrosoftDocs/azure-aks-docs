---
title: Troubleshoot common issues in AKS Edge Essentials 
description: Learn about common issues and workarounds in AKS Edge Essentials. 
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: troubleshooting-general
ms.date: 09/01/2026
ms.custom: template-concept, edge-essentials
---

# Troubleshoot common issues in AKS Edge Essentials

This article describes how to find solutions for issues you encounter when using AKS Edge Essentials. Known issues and errors are organized by functional area. You can use the links provided in this article to find solutions and workarounds to resolve them.

## Open a support request

See the [Get support](/azure/aks/hybrid/help-support?tabs=aksee) article for information about how to use the Azure portal to get support or open a support request for AKS Edge Essentials.

## Deployment issues

### Untrusted publisher issue

Error message: "Do you want to run software from this untrusted publisher? ....."

Workaround: Update your PowerShell execution policy to **RemoteSigned**:

```powershell
# Get the execution policy on the system
Get-ExecutionPolicy
# Set the execution policy for this process only
if ((Get-ExecutionPolicy) -ne "RemoteSigned") { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force }
```

### Low disk space causes previously cached container images to be deleted

When the node runs out of disk space, some of the preloaded images are garbage collected by the `containerd` runtime. In this case, first free up some disk space, and then run the following command to pull the cached images again:

```powershell
    Invoke-AksEdgeNodeCommand -NodeType Linux -command "sudo /path/to/script/reimport-ci.sh
```

This script checks for the missing images and reimports them as needed.

### Azure Arc connectivity

1. Issue: `Disconnect-AksEdgeArc` doesn't remove the pods from the cluster.

   Workaround: If the pods aren't cleaned up, run the following commands to manually clean up the existing Azure Arc-related resources before trying to reconnect again:

   ```powershell
   kubectl delete ns azure-arc
   kubectl delete clusterrolebinding azure-arc-operator
   kubectl delete secret sh.helm.release.v1.azure-arc.v1
   ```

2. Issue: Azure Arc connectivity doesn't work in a proxy environment.

   Workaround: You can enable system-wide proxy settings by following **Internet options > Connections > LAN Settings**.

   :::image type="content" source="../media/aks-edge/aks-edge-azure-arc-proxy.png" alt-text="Screenshot showing internet options." lightbox="../media/aks-edge/aks-edge-azure-arc-proxy.png":::

## Can't fully delete AKS cluster with PodDisruptionBudget (PDB) resources

When you delete an AKS cluster that has [PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) (PDB) resources, the deletion might fail to remove the PDB resources. By default, PDB is installed in workload identity-enabled AKS clusters.

**For deleting a node pool** with a PodDisruptionBudget: By design, the node pool isn't deleted if a PodDisruptionBudget exists, to protect applications. Use the following workaround to delete the PDB resources and then retry deleting the node pool.

Before you delete the AKS cluster, access the AKS cluster's **kubeconfig** and delete all PDBs:

1. Access the AKS cluster according to its connectivity state:

   - When the AKS cluster is in a **Connected** state, run the [`az connectedk8s proxy`](/cli/azure/connectedk8s#az-connectedk8s-proxy) command

     ```azurecli
     az connectedk8s proxy -n $aks_cluster_name -g $resource_group_name 
     ```

   - When the AKS cluster is in a **disconnected** state, run the `az aksarc get-credentials` command with permission to perform the **Microsoft.HybridContainerService/provisionedClusterInstances/listAdminKubeconfig/action** action, which is included in the **Azure Kubernetes Service Arc Cluster Admin** role permission.

     ```azurecli
     az aksarc get-credentials -n $aks_cluster_name -g $resource_group_name --admin
     ```

1. Verify PDB:

   ```bash
   kubectl get pdb -A 
   ```

1. Delete all PDBs. The following command is an example of deleting a PDB generated from workload identity enablement:

   ```bash
   kubectl delete pdb azure-wi-webhook-controller-manager -n arc-workload-identity 
   ```

1. Delete the AKS cluster:

   ```azurecli
   az connectedk8s delete -n <cluster_name> -g <resource_group>
   ```

## Offline deployments

### Failed to get nodeagent certificate: Not Found

Check the network adapter configuration. During deployment, AKS Edge Essentials needs an adapter that's enabled and has the correct IP address, subnet, and default gateway. These values are automatically populated in a DHCP environment. If you're setting manually, ensure all three are set. In many cases, the default gateway isn't set, which results in this error.

## Kubernetes

### Kube-vip pod continuously restarts

In some scenarios, the **kube-vip** pod loops and restarts continuously.

#### Validation

To confirm that the scenario you're encountering is the same issue documented in this article, check that the kube-vip pod in the **kube-system** namespace has a high number of restarts by running the following command:

```bash
kubectl get pods –n kube-system
```

#### Cause

There are a few different reasons why the kube-vip pod might be constantly restarting. These causes include:

- Using an OS disk that is not backed with an SSD disk, or a premium SSD disk when using an Azure VM. You can [review the hardware requirements here](aks-edge-system-requirements.md#hardware-requirements).
- Disk latency is too high. If the disk latency is greater than 10 ms, it can result in request timeouts, leader loss, and potential cluster instability. You can [review the hardware requirements for etcd here](https://etcd.io/docs/v3.4/op-guide/hardware/).

#### Resolution

To mitigate this issue, review your underlying storage infrastructure to ensure that it meets the performance requirements for etcd and AKS Edge Essentials. Also, consider using premium SSD-backed storage or optimizing your storage configuration for performance.

## Next steps

[AKS Edge Essentials overview](aks-edge-overview.md)
