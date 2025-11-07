---
title: Deploy a fully managed resource group with node resource group lockdown in Azure Kubernetes Service (AKS)
description: Learn how to deploy a fully managed resource group using node resource group lockdown in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: azure-kubernetes-service, devx-track-azurecli
ms.date: 11/04/2025
ms.author: schaffererin
author: schaffererin
# Customer intent: As a Kubernetes administrator, I want to deploy a fully managed resource group with node resource group lockdown, so that I can prevent unauthorized changes to cluster resources and ensure stable operations within my AKS environment.
---

# Deploy a fully managed resource group using node resource group lockdown in Azure Kubernetes Service (AKS)

AKS deploys infrastructure into your subscription for connecting to and running your applications. Changes made directly to resources in the [node resource group][whatis-nrg] can affect cluster operations or cause future issues. For example, scaling, storage, or network configurations should be made through the Kubernetes API and not directly on these resources.

To prevent changes from being made to the node resource group, you can apply a deny assignment and block users from modifying resources created as part of the AKS cluster.

## Before you begin

Before you begin, you need the following resources installed and configured:

* The Azure CLI version 2.44.0 or later. Run `az --version` to find the current version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].

## Create an AKS cluster with node resource group lockdown

Create a cluster with node resource group lockdown using the [`az aks create`][az-aks-create] command with the `--nrg-lockdown-restriction-level` flag set to `ReadOnly`. This configuration allows you to view the resources but not modify them.

```azurecli-interactive
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --nrg-lockdown-restriction-level ReadOnly \
    --generate-ssh-keys
```

## Update an existing cluster with node resource group lockdown

Update an existing cluster with node resource group lockdown using the [`az aks update`][az-aks-update] command with the `--nrg-lockdown-restriction-level` flag set to `ReadOnly`. This configuration allows you to view the resources but not modify them.

```azurecli-interactive
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --nrg-lockdown-restriction-level ReadOnly
```

## Remove node resource group lockdown from a cluster

Remove node resource group lockdown from an existing cluster using the [`az aks update`][az-aks-update] command with the `--nrg-restriction-level` flag set to `Unrestricted`. This configuration allows you to view and modify the resources.

```azurecli-interactive
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --nrg-lockdown-restriction-level Unrestricted
```

## Next steps

To learn more about the node resource group in AKS, see [Node resource group][whatis-nrg].

<!-- LINKS -->
[whatis-nrg]: ./concepts-clusters-workloads.md#node-resource-group
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
