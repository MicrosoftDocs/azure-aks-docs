---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 04/13/2026
author: wangyira
ms.author: wangamanda
---
## Limitations

- AKS Automatic clusters' system nodepool require deployment in Azure regions that support at least three [availability zones](/azure/reliability/regions-list), ephemeral OS disk, and Azure Linux OS.
- AKS Automatic is available in the following regions: `australiaeast`, `austriaeast`, `belgiumcentral`, `brazilsouth`, `canadacentral`, `centralindia`, `centralus`, `chilecentral`, `denmarkeast`, `eastasia`, `eastus`, `eastus2`, `francecentral`, `germanywestcentral`, `indonesiacentral`, `israelcentral`, `italynorth`, `japaneast`, `japanwest`, `koreacentral`, `malaysiawest`, `mexicocentral`, `newzealandnorth`, `northcentralus`, `northeurope`, `norwayeast`, `polandcentral`, `southafricanorth`, `southcentralus`, `southeastasia`, `spaincentral`, `swedencentral`, `switzerlandnorth`, `uaenorth`, `uksouth`, `westeurope`, `westus`, `westus2`, `westus3`.
- AKS Automatic cluster has [node resource group lockdown](../../node-resource-group-lockdown.md) preconfigured, which does not allow changes to the MC_ resource group, preventing virtual network links on the default Private DNS zone. For cross‑VNet or custom DNS scenarios, use custom network and private DNS by following [Create a private Azure Kubernetes Service (AKS) Automatic cluster in a custom virtual network](../../automatic/quick-automatic-private-custom-network.md).



> [!IMPORTANT]
> AKS Automatic tries to dynamically select a virtual machine size for the `system` node pool based on the capacity available in the subscription. Make sure your subscription has quota for 16 vCPUs of any of the following sizes in the region you're deploying the cluster to: [Standard_D4lds_v5](/azure/virtual-machines/sizes/general-purpose/dldsv5-series), [Standard_D4ads_v5](/azure/virtual-machines/sizes/general-purpose/dadsv5-series), [Standard_D4ds_v5](/azure/virtual-machines/sizes/general-purpose/ddv5-series), [Standard_D4d_v5](/azure/virtual-machines/sizes/general-purpose/ddv5-series), [Standard_D4d_v4](/azure/virtual-machines/sizes/general-purpose/dv4-series), [Standard_DS3_v2](/azure/virtual-machines/sizes/general-purpose/dsv3-series), [Standard_DS12_v2](/azure/virtual-machines/sizes/memory-optimized/dv2-dsv2-series-memory), [Standard_D4alds_v6](/azure/virtual-machines/sizes/general-purpose/daldsv6-series), [Standard_D4lds_v6](/azure/virtual-machines/sizes/general-purpose/dldsv6-series), or [Standard_D4alds_v5](/azure/virtual-machines/sizes/general-purpose/dldsv5-series). You can [view quotas for specific VM-families and submit quota increase requests](/azure/quotas/per-vm-quota-requests) through the Azure portal.
> If you have additional questions, learn more through the [troubleshooting docs](/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/aks-automatic-troubleshoot/).
