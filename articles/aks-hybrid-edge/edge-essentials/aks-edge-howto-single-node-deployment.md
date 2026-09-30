---
title: Single machine Kubernetes
description: Learn how to deploy AKS Edge Essentials on a single machine.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Single machine deployment

You can deploy AKS Edge Essentials on either a single machine or on multiple machines. In a single machine Kubernetes deployment, both the Kubernetes control node and worker node run on the same machine. This article describes how to create the Kubernetes control node on your machine on a private network.

## Prerequisites

Set up your primary machine as described in [Set up machine](aks-edge-howto-setup-machine.md).

## Step 1: single machine configuration parameters

Generate the parameters you need to create a single machine cluster by running the following command:

```powershell
New-AksEdgeConfig -DeploymentType SingleMachineCluster -outFile .\aksedge-config.json | Out-Null
```

This command creates a configuration file called **aksedge-config.json** that includes the configuration needed to create a single-machine cluster with a Linux node. The file is created in your current working directory. See the following examples for more options for creating the configuration file.

See [Deployment JSON configuration](aks-edge-deployment-config-json.md) for a detailed description of the configuration parameters.

The key parameters for single machine deployment are:

- `DeploymentType`: This parameter defines the deployment type. Specify `SingleMachineCluster`.
- `Arc`: This section is required. During the AKS Edge Essentials deployment, the Arc parameters are used to connect the AKS Edge Essentials cluster to Azure Arc. For more information about the required Arc parameters, see the [connect to Arc documentation](aks-edge-howto-connect-to-arc.md).
  
- The `Network.NetworkPlugin` by default is `flannel`. This plugin is the default for a K3S cluster. If you're using a K8S cluster, change the CNI to `calico`.
- Set the following parameters according to your deployment configuration [as described here](aks-edge-deployment-config-json.md): `LinuxNode.CpuCount`, `LinuxNode.MemoryInMB`, `LinuxNode.DataSizeInGB`, `WindowsNode.CpuCount`, `WindowsNode.MemoryInMB`, `Init.ServiceIPRangeSize`, and `Network.InternetDisabled`.
- To encrypt the Kubernetes secret store, enable the Key Management Service (KMS) plugin (preview) by setting the `Init.KmsPlugin enable` to **true**. For more information, see [Enable secret encryption on a cluster](aks-edge-howto-secret-encryption.md).

> [!IMPORTANT]
> Starting with the AKS Edge Essentials 1.10.868.0 release, the `Arc` section of the config file is required. The Azure Arc connection occurs automatically during the AKS Edge Essentials deployment.

## Step 2: Create a single machine cluster

Run the `New-AksEdgeDeployment` cmdlet to deploy a single-machine AKS Edge cluster with a single Linux control-plane node:

```powershell
New-AksEdgeDeployment -JsonConfigFilePath .\aksedge-config.json
```

> [!IMPORTANT]
> The Kubernetes `pod cidr` is `10.42.0.0/16` for K3s and `10.244.0.0/24` for K8s. The Kubernetes `service cidr` is `10.43.0.0/16` for K3s and `10.96.0.0/12` for K8s.

## Step 3: Validate your cluster

Confirm that the deployment was successful by running:

```powershell
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

The following image shows pods on a K3S cluster:

:::image type="content" source="../media/aks-edge/all-pods-running.png" alt-text="Screenshot showing all pods running." lightbox="../media/aks-edge/all-pods-running.png":::

## Step 4: Add a Windows worker node (optional)

> [!CAUTION]
> Windows worker nodes is an experimental feature in this release. We are actively working on this feature.

If you want to add a Windows node to an existing Linux-only single machine cluster, first create the configuration file using the following command:

```powershell
New-AksEdgeScaleConfig -ScaleType AddNode -NodeType Windows -outFile .\ScaleConfig.json | Out-Null
```

This command creates the configuration file **ScaleConfig.json** in the current working directory. You can also modify the Windows node parameters in the configuration file to specify the resources that you need to allocate to the Windows node. With the configuration file, run the following command to add the node to the single machine cluster:

```powershell
Add-AksEdgeNode -JsonConfigFilePath .\ScaleConfig.json
```

## Example deployment options

### Create a JSON object with the configuration parameters

You can programmatically edit the JSON object and pass it as a string:

```powershell
$jsonObj = New-AksEdgeConfig -DeploymentType SingleMachineCluster
$jsonObj.User.AcceptEula = $true
$jsonObj.User.AcceptOptionalTelemetry = $true
$jsonObj.Init.ServiceIpRangeSize = 10
$machine = $jsonObj.Machines[0]
$machine.LinuxNode.CpuCount = 4
$machine.LinuxNode.MemoryInMB = 4096

New-AksEdgeDeployment -JsonConfigString ($jsonObj | ConvertTo-Json -Depth 4)
```

> [!TIP]
> See [Deployment JSON configuration](aks-edge-deployment-config-json.md) for all available options, including network settings such as proxy settings.

### Create a simple cluster with NodePort service

You can create a simple cluster with no service IPs by setting `ServiceIPRangeSize` to 0:

```powershell
New-AksEdgeDeployment -JsonConfigString (New-AksEdgeConfig | ConvertTo-Json -Depth 4)
```

### Allocate resources to your nodes

To connect to Arc and deploy your apps with GitOps, allocate four CPUs or more for the `LinuxNode.CpuCount` (processing power), 4 GB or more for `LinuxNode.MemoryinMB` (RAM), and assign a number greater than 0 to the `ServiceIpRangeSize`. In the following example, you allocate 10 IP addresses for your Kubernetes services:

```json
{
  "SchemaVersion": "1.5",
  "Version": "1.0",
  "DeploymentType": "SingleMachineCluster",
  "Init": {
    "ServiceIPRangeSize": 10
  },
  "Network": {
      "NetworkPlugin": "flannel"
  },
  "User": {
      "AcceptEula": true,
      "AcceptOptionalTelemetry": true
  },
  "Machines": [
       {
         "LinuxNode": {
              "CpuCount": 4,
              "MemoryInMB": 4096
          }
       }
   ]
}
```

> [!NOTE]
> AKS Edge Essentials allocates IP addresses from your internal switch to run your Kubernetes services if you specify a `ServiceIPRangeSize`.

You can also choose to pass the parameters as a JSON string, as previously described:

   ```powershell
   $jsonObj = New-AksEdgeConfig -DeploymentType SingleMachineCluster
   $jsonObj.User.AcceptEula = $true
   $jsonObj.User.AcceptOptionalTelemetry = $true
   $jsonObj.Init.ServiceIpRangeSize = 10
   $machine = $jsonObj.Machines[0]
   $machine.LinuxNode.CpuCount = 4
   $machine.LinuxNode.MemoryInMB = 4096

   New-AksEdgeDeployment -JsonConfigString ($jsonObj | ConvertTo-Json -Depth 4)
   ```

### Create a mixed workload cluster

You can create a cluster with both Linux and Windows nodes. Use the following command to create the configuration file:

```powershell
New-AksEdgeConfig -DeploymentType SingleMachineCluster -NodeType LinuxAndWindows -outFile .\aksedge-config.json | Out-Null
```

After you create the configuration file, use the following command to deploy your cluster:

```powershell
New-AksEdgeDeployment -JsonConfigFilePath .\aksedge-config.json
```

## Next steps

- [Deploy your application](aks-edge-howto-deploy-app.md).
- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
