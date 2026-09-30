---
title: Create logical networks for Kubernetes clusters on Azure Local
description: Learn how to create Arc-enabled logical networks for AKS Hybrid and Edge.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 04/01/2024
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
---

# Create logical networks for Kubernetes clusters on Azure Local

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

After you install and configure Azure Local, you must create Arc VM logical networks. AKS on Azure Local uses static logical networks to provide IP addresses to the underlying VMs of the AKS clusters.

## Before you begin

Before you begin, make sure you have the following prerequisites:

- Install and configure Azure Local. Make sure you have the custom location Azure Resource Manager ID, as this ID is a required parameter for creating a logical network.
- Make sure that the logical network you create contains enough usable IP addresses to avoid IP address exhaustion. IP address exhaustion can lead to Kubernetes cluster deployment failures. For more information, see [Networking concepts in AKS on Azure Local](network-system-requirements.md).
- Make sure you have an external VM switch that all the machines in your Azure Local cluster can access. By default, an external switch is created during the deployment of your Azure Local cluster that you can use to associate with the logical network you create.

Run the following command to get the name of the external VM switch on your Azure Local cluster:

```powershell
Get-VmSwitch -SwitchType External
```

Make a note of the name of the switch. You use this information when you create a logical network. For example:

```powershell
Get-VmSwitch -SwitchType External
```

```output
Name                                           SwitchType      NetAdapterInterfaceDescription
----                                           ----------      ----------------------------
ConvergedSwitch(management_compute_storage)    External        Teamed-Interface
```

## Create the logical network

You can create a logical network by using either the Azure CLI or the Azure portal.

# [Azure CLI](#tab/azurecli)

To create a logical network on the VM switch in a static IP configuration, use the [`az stack-hci-vm network lnet create`](/cli/azure/stack-hci-vm/network/lnet#az-stack-hci-vm-network-lnet-create) command:

```azurecli
az stack-hci-vm network lnet create \
  --subscription $subscription \
  --resource-group $resource_group \
  --custom-location $customLocationID \
  --name $lnetName \
  --vm-switch-name $vmSwitchName \
  --ip-allocation-method "Static" \
  --address-prefixes $addressPrefixes \
  --gateway $gateway \
  --dns-servers $dnsServers \
  --ip-pool-start $ipPoolStart \
  --ip-pool-end $ipPoolEnd \
  --vlan 10
```

For static IP, provide the following required parameters:

| Required parameters | Description |
|------------|-------------|
| `--name`  | Name for the logical network that you create for your Azure Local cluster. Make sure to provide a name that follows the [rules for Azure resources](/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming#example-names-networking). You can't rename a logical network after it's created. |
| `--resource-group` | Name of the resource group where you create the logical network. |
| `--subscription` | Name or ID of the subscription where your Azure Local is deployed. |
| `--custom-location` | Provide the custom location associated with your Azure Local cluster where you're creating the logical network. |
| `--vm-switch-name`     | The name of the VM switch. Usage: `--vm-switch-name "vm-switch-01"`. |
| `--address-prefixes` | AddressPrefix for the network. Currently only one address prefix is supported. Usage: `--address-prefixes "10.220.32.16/24"`. |
| `--dns-servers`      | Space-separated list of DNS server IP addresses. Usage: `--dns-servers 10.220.32.16 10.220.32.17`. |
| `--gateway`         | Gateway. The gateway IP address must be within the scope of the address prefix. Usage: `--gateway 10.220.32.16`. |
| `--ip-allocation-method`   | The IP address allocation method. Supported value is `Static`. Usage: `--ip-allocation-method "Static"`. |
| `--ip-pool-start`     | The start IP address of your IP pool. The address must be in range of the address prefix. Usage: `--ip-pool-start "10.220.32.18"`.  |
| `--ip-pool-end`       | The end IP address of your IP pool. The address must be in range of the address prefix. Usage: `--ip-pool-end "10.220.32.38"`.  |
| `--vlan`              | The VLAN ID. Usage: `--vlan 10`. This parameter is optional. Specifies the VLAN ID (an int32 value) to use when creating the logical network.  |

# [Azure portal](#tab/azureportal)

Complete the following steps to create a logical network using the Azure portal:

1. In the left pane, under **Resources**, select **Logical networks**.

   :::image type="content" source="../../media/aks-networks/select-logical-network.png" alt-text="Screenshot showing Resources pane in Azure portal." lightbox="../../media/aks-networks/select-logical-network.png":::

1. In the right pane, select **Create logical network**.

   :::image type="content" source="../../media/aks-networks/create-logical-network.png" alt-text="Screenshot showing logical network creation link." lightbox="../../media/aks-networks/create-logical-network.png":::

1. On **Create logical network**, on the **Basics** tab:

    - Select the Azure subscription name.
    - Select the associated resource group name.
    - Enter a logical network name. Make sure to provide a name that follows the [Rules for Azure resources.](/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming#example-names-networking) You can't rename a logical network after it's created.
    - Enter the virtual switch name that you saved earlier.
    - The geographic region is automatically set to the region where you registered your cluster.
    - The custom location is automatically populated from the cluster.

    When complete, select **Next: Network Configuration**.

   :::image type="content" source="../../media/aks-networks/enter-network-name.png" alt-text="Screenshot showing Basics tab." lightbox="../../media/aks-networks/enter-network-name.png":::

1. On the **Network configuration** tab, select **Static** and then enter the following values:
    - IPv4 address space (previously reserved).
    - IP pools.
    - Default gateway address.
    - DNS server address.
    - VLAN ID (if used).

    When complete, select **Review + Create**.

   :::image type="content" source="../../media/aks-networks/enter-ip-addresses.png" alt-text="Screenshot showing Network configuration tab." lightbox="../../media/aks-networks/enter-ip-addresses.png":::

1. On the **Review + Create** tab, review network settings and then select **Create**:

   :::image type="content" source="../../media/aks-networks/review-and-create-static.png" alt-text="Screenshot showing static network properties page." lightbox="../../media/aks-networks/review-and-create-static.png":::

---

## Next steps

[Create and manage Kubernetes clusters on-premises using Azure CLI](../aks-create-clusters-cli.md)
