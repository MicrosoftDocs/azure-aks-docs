---
title: Troubleshoot issue in which the cluster is stuck in Upgrading state
description: Learn how to troubleshoot and mitigate the issue when an AKS Hybrid and Edge cluster is stuck in 'Upgrading' state.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
---

# Troubleshoot AKS cluster stuck in "Upgrading" state

This article describes how to fix an issue in which your Azure Kubernetes Service Hybrid and Edge cluster is stuck in the **Upgrading** state. This issue typically occurs after you update Azure Local to version 2503 or 2504, and you then try to upgrade the Kubernetes version on your cluster.

## Symptoms

When you try to upgrade an AKS cluster, you notice that the `currentState` property of the cluster remains in the **Upgrading** state.

```azurecli
az aksarc upgrade --name "cluster-name" --resource-group "rg-name"
```

```output
===> Kubernetes might be unavailable during cluster upgrades.
 Are you sure you want to perform this operation? (y/N): y
The cluster is on version 1.28.9 and is not in a failed state. 

===> This will upgrade the control plane AND all nodepools to version 1.30.4. Continue? (y/N): y
Upgrading the AKSArc cluster. This operation might take a while...
{
  "extendedLocation": {
    "name": "/subscriptions/resourceGroups/Bellevue/providers/Microsoft.ExtendedLocation/customLocations/bel-CL",
    "type": "CustomLocation"
  },
  "id": "/subscriptions/fbaf508b-cb61-4383-9cda-a42bfa0c7bc9/resourceGroups/Bellevue/providers/Microsoft.Kubernetes/ConnectedClusters/Bel-cluster/providers/Microsoft.HybridContainerService/ProvisionedClusterInstances/default",
"name": "default",
"properties": {
"kubernetesVersion": "1.30.4",
"provisioningState": "Succeeded",
"currentState": "Upgrading",
"errorMessage": null,
"operationStatus": null
"agentPoolProfiles": [
      {
        ...
```

## Cause

- The issue is caused by a recent change introduced in Azure Local version 2503. Under certain conditions, if there are transient or intermittent failures during the Kubernetes upgrade process, they're not correctly detected or recovered from. This can cause the cluster state to remain in the **Upgrading** state.
- You see this issue if the AKS custom location extension `hybridaksextension` version is 2.1.211 or 2.1.223. You can run the following command to check the extension version on your cluster:

  ```azurecli
  az login --use-device-code --tenant <Azure tenant ID> 
  az account set -s <subscription ID> 
  $res=get-archcimgmt
  az k8s-extension show -g $res.HybridaksExtension.resourceGroup -c $res.ResourceBridge.name --cluster-type appliances --name hybridaksextension
  ```

  ```output
  {
    "aksAssignedIdentity": null,
    "autoUpgradeMinorVersion": false,
    "configurationProtectedSettings": {},
    "currentVersion": "2.1.211",
    "customLocationSettings": null,
    "errorInfo": null,
    "extensionType": "microsoft.hybridaksoperator",
    ...
  }
  ```

## Mitigation

This issue was fixed in AKS on [Azure Local, version 2505](/azure/azure-local/whats-new?view=azloc-2505&preserve-view=true#features-and-improvements-in-2505). Upgrade your Azure Local deployment to the 2505 build. After you update, [verify that the Kubernetes version was upgraded](#verification) and the `currentState` property of the cluster shows as **Succeeded**.

### Workaround for Azure Local versions 2503 or 2504

This issue only affects clusters in Azure Local version 2503 or 2504, and on AKS extension versions 2.1.211 or 2.1.223. The mitigation described here is applicable only when you are unable to upgrade to 2505.

You can resolve the issue by running the AKS `update` command. The `update` command restarts the upgrade flow. You can run the `aksarc update` command with placeholder parameters, which do not impact the state of the cluster. So in this case, you can run the `update` command to enable NFS or SMB drivers if those features aren't already enabled. First, check if any of the storage drivers are already enabled:

```azurecli
az login --use-device-code --tenant <Azure tenant ID> 
az account set -s <subscription ID> 
az aksarc show -g <resource_group_name> -n <cluster_name>
```

Check the storage profile section:

```json
"storageProfile": {  
     "nfsCsiDriver": {  
       "enabled": false
     },  
     "smbCsiDriver": {  

       "enabled": true  
     }  
   }
```

If one of the drivers is disabled, you can enable it using one of the following commands:

```azurecli
az aksarc update --enable-smb-driver -g <resource_group_name> -n <cluster_name>
az aksarc update --enable-nfs-driver -g <resource_group_name> -n <cluster_name>
```

Running the `aksarc update` command should resolve the issue and the `currentState` property of the cluster should now show as **Succeeded**. Once the status is updated, if you don't want to keep the drivers enabled, you can reverse this action by running one of the following commands:

```azurecli
az aksarc update --disable-smb-driver -g <resource_group_name> -n <cluster_name>
az aksarc update --disable-nfs-driver -g <resource_group_name> -n <cluster_name>
```

If both drivers are already enabled on your cluster, you can disable the one that's not in use. If you require both drivers to remain enabled, contact Microsoft Support for further assistance.

## Verification

To confirm the K8s version upgrade is complete, run the following command and check that the `currentState` property in the JSON output is set to **Succeeded**.

```azurecli
az aksarc show -g <resource_group> -n <cluster_name>
```

```output
...
...
"provisioningState": "Succeeded",
"status": {
    "currentState": "Succeeded",
    "errorMessage": null,
    "operationStatus": null
    "controlPlaneStatus": { ...
...
```

## Contact Microsoft Support

If the problem persists, collect the [AKS cluster logs](get-on-demand-logs.md) before you [create a support request](aks-troubleshoot.md#open-a-support-request).

## Next steps

- [Use the diagnostic checker tool to identify common environment issues](aks-arc-diagnostic-checker.md)
- [Review AKS on Azure Local architecture](cluster-architecture.md)
