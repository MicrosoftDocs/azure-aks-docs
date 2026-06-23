---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 06/23/2026
author: wangyira
ms.author: wangamanda
---

## Limitations

The following limitations apply to AKS Automatic clusters:

- AKS Automatic is generally available in the following regions: `australiaeast`, `austriaeast`, `belgiumcentral`, `brazilsouth`, `canadacentral`, `centralindia`, `centralus`, `chilecentral`, `denmarkeast`, `eastasia`, `eastus`, `eastus2`, `francecentral`, `germanywestcentral`, `indonesiacentral`, `israelcentral`, `italynorth`, `japaneast`, `japanwest`, `koreacentral`, `malaysiawest`, `mexicocentral`, `newzealandnorth`, `northeurope`, `norwayeast`, `polandcentral`, `southafricanorth`, `southcentralus`, `southeastasia`, `spaincentral`, `swedencentral`, `switzerlandnorth`, `uaenorth`, `uksouth`, `westeurope`, `westus2`, `westus3`.
  - New AKS Automatic clusters by default enable managed system node pools and [LocalDNS](../../dns-concepts.md#localdns-in-azure-kubernetes-service). You can't create AKS Automatic clusters without managed system node pools in any region.
- AKS Automatic cluster has [node resource group lockdown](../../node-resource-group-lockdown.md) preconfigured, which doesn't allow changes to the `MC_` resource group, preventing virtual network links on the default Private DNS zone. For cross‑VNet or custom DNS scenarios, use custom network and private DNS by following [Create a private Azure Kubernetes Service (AKS) Automatic cluster in a custom virtual network](../../automatic/quick-automatic-private-custom-network.md).
- Azure CLI version 2.86.0 or later is required. To find the version, run `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/get-started-with-azure-cli).
- The following extensions aren't supported:
  - [Dapr](../../dapr.md)
  - [Azure Machine Learning](/azure/machine-learning/how-to-attach-kubernetes-anywhere)
- Windows nodes aren't supported.
- Migration between AKS base SKU and Automatic SKU isn't supported.
- Migrations between AKS Automatic clusters without managed system node pools and AKS Automatic clusters with managed system node pools aren't supported.
