---
title: AKS Edge Essentials scale (preview)
description: Learn how to scale out your AKS Edge Essentials applications to multiple nodes.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, linux-related-content, edge-essentials
---

# Scale out on multiple machines (preview)

Now that AKS Edge Essentials is installed on your primary machine, this article describes how you can scale out your cluster to other secondary machines to create a multi-machine deployment.

> [!CAUTION]
> Scaling to additional nodes is an experimental feature.

> [!IMPORTANT]
> AKS Edge Essentials multi-machine deployment is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.
> Azure Kubernetes Service Edge Essentials previews are partially covered by customer support on a best-effort basis.


## Prerequisites

- Set up your [scalable Kubernetes](aks-edge-howto-multi-node-deployment.md) cluster.
- Set up your secondary machines as described in the [Set up machine article](aks-edge-howto-setup-machine.md). You can't mix different Kubernetes distributions in your cluster. If the cluster on your primary machine is running **K8s**, you must install the **K8s** MSI on the secondary machines as well.

## Step 1: get cluster configuration from your primary machine

On your primary machine on which you created your scalable deployment, run the following steps in an elevated PowerShell window to create the appropriate configuration file based on your requirements.

- To scale by adding a Linux-only worker node, create the required configuration file using the following command and specify the `NodeType` as "Linux" and provide a unique and available IP address for this node:

    ```powershell
    New-AksEdgeScaleConfig -scaleType AddMachine -NodeType Linux -LinuxNodeIp x.x.x.x -outFile .\ScaleConfig.json | Out-Null
    ```

- To scale by adding more Linux control plane node, specify the `NodeType` as "Linux", set the `ControlPlane` flag as true, and provide a unique IP address for the Linux node:

    ```powershell
    New-AksEdgeScaleConfig -scaleType AddMachine -NodeType Linux -LinuxNodeIp x.x.x.x -ControlPlane -outFile .\ScaleConfig.json | Out-Null
    ```

- To scale by adding a Windows-only worker node, specify the `NodeType` as "Windows" and provide a unique IP address for the Windows node:

   ```powershell
    New-AksEdgeScaleConfig -scaleType AddMachine -NodeType Windows -WindowsNodeIp x.x.x.x -outFile .\ScaleConfig.json | Out-Null
    ```

- To add a Linux and Windows worker node, specify the `NodeType` as "LinuxAndWindows" and provide a unique IP address for both the Linux and Windows nodes:

    ```powershell
    New-AksEdgeScaleConfig -scaleType AddMachine -NodeType LinuxandWindows -LinuxNodeIp x.x.x.x -WindowsNodeIp x.x.x.x -outFile .\ScaleConfig.json | Out-Null
    ```

- To add a Linux control plane node and Windows worker node, specify the `NodeType` as "LinuxAndWindows", set the `ControlPlane` flag as `true`, and provide a unique IP address for both the Linux and Windows nodes:

    ```powershell
    New-AksEdgeScaleConfig -scaleType AddMachine -NodeType LinuxandWindows -LinuxNodeIp x.x.x.x -WindowsNodeIp x.x.x.x  -ControlPlane -outFile .\ScaleConfig.json | Out-Null
    ```

These commands export the necessary data to join a cluster in the JSON format, return it as a JSON string, and store it in the file specified via `outFile` parameter.

> [!CAUTION]
> Every time you run the `New-AksEdgeScaleConfig` command, the previously-created `ClusterJoinToken` becomes invalid, so you can't use a previously created **ScaleConfig.json** file. Additionally, `ClusterJoinToken` is only valid for 24 hours.

## Step 2: validate the configuration parameters

The **.\ScaleConfig.json** configuration file includes the configuration from the primary machine. Review and update necessary sections, and provide details relevant to the machine you're scaling to.

- Verify the `NetworkConnection.AdapterName` with reference to the secondary machine. If you've created an external switch on your Hyper-V on your secondary machine, you can choose to specify the vswitch details in your **ScaleConfig.json** file. If you don't create an external switch in Hyper-V manager and run the `New-AksEdgeDeployment` command, AKS Edge Essentials automatically creates an external switch named `aksedgesw-ext` and uses that for your deployment.

    > [!NOTE]
    > In this release, there is a known issue in automatic creation of external switches with the `New-AksEdgeDeployment` command if you are using a Wi-fi adapter for the switch. In this case, first create the external switch using the Hyper-V manager - Virtual Switch Manager and map the switch to the Wi-fi adapter. Then provide the switch details in your configuration JSON as described in this section.

- The `Network.NetworkPlugin` is `flannel` by default. Flannel is the default CNI for a K3S cluster. For a K8S cluster, change the `NetworkPlugin` to `calico`.
- Verify the resource configuration for the secondary nodes. You can modify these parameters as needed. Ensure that you [reserve enough memory for each node](./aks-edge-concept-clusters-nodes.md). If you specified `MacAddress` on your primary machine, verify and provide the right MAC address relevant to the secondary machine.

- An odd number of control plane nodes is the only supported setting. Therefore, if you want to scale up/down your control plane, make sure you have one, three, or five control plane nodes.

## Step 3: bring up a node on your secondary machine

Now you're ready to bring up nodes on your secondary machines and add them to the cluster.

To deploy the corresponding node on the secondary machine, you can now use the **ScaleConfig.json** file created in the previous step:

```powershell
New-AksEdgeDeployment -JsonConfigFilePath .\ScaleConfig.json
```

## Step 4: validate your cluster setup

On any node in the cluster, run the following cmdlet:

```powershell
kubectl get nodes -o wide
```

You should be able to see all the nodes of the cluster.

:::image type="content" source="../media/aks-edge/aks-edge-multi-nodes.png" alt-text="Screenshot showing multiple nodes." lightbox="../media/aks-edge/aks-edge-multi-nodes.png":::

## Step 5: add more nodes

You can generate a new **ScaleConfig** file based on the nodeType required by repeating steps 1-4. Ensure that you provide IP addresses that are available in your network each time you add a node.

## Step 6: add the second node (Linux/Windows) on a machine that already has a node (optional)

You can add another node to an existing machine that already has a node. For example, if your machine is running a Linux node, you can add a Windows node to it:

```powershell
New-AksEdgeScaleConfig -ScaleType AddNode -NodeType Windows -WindowsNodeIp "xxx" -outFile .\ScaleConfig.json | Out-Null
```

You can also specify parameters such as `CpuCount` and/or `MemoryInMB` for your Windows VM.

> [!NOTE]
> Run `New-AksEdgeScaleConfig` only on machines that have the **Linux node with ControlPlane** role.

You can use the generated configuration file and run the following command to add the Windows node:

```powershell
Add-AksEdgeNode -JsonConfigFilePath .\ScaleConfig.json
```

You can also specify parameters such as `CpuCount` and/or `MemoryInMB` for your Windows VM here.

## Next steps

- [Deploy your application](aks-edge-howto-deploy-app.md) or [connect to Arc](aks-edge-howto-connect-to-arc.md)
- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
