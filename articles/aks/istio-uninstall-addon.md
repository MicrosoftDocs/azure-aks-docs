---
title: Uninstall Istio-based service mesh add-on for Azure Kubernetes Service
description: Uninstall Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.service: azure-kubernetes-service
ms.date: 03/28/2024
ms.author: kochhars
author: sanyakochhar
---

# Uninstall Istio-based service mesh add-on for Azure Kubernetes Service

This article shows you how to uninstall the Istio-based service mesh add-on for Azure Kubernetes Service (AKS) cluster and delete sample resources created in the [Getting Started][istio-getting-started] guide.

## Uninstall the add-on
Disabling the service mesh add-on will completely remove the Istio control plane and ingress gateways from the cluster. It will also delete the corresponding managed namespaces such as `aks-istio-system` and `aks-istio-ingress` and resources created in them. Resources in user-managed namespaces will not be deleted. If you would like to uninstall the add-on, run the following command:

```azurecli-interactive
az aks mesh disable --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

Istio `CustomResourceDefintion`s (CRDs) aren't be deleted by default. To clean them up, use:

```bash
kubectl delete crd $(kubectl get crd -A | grep "istio.io" | awk '{print $1}')
```

## Clean up sample resources

Use `kubectl delete` to delete the sample application if it was installed:

```bash
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/bookinfo/platform/kube/bookinfo.yaml
```

<!--- Internal Links --->
[istio-getting-started]: istio-deploy-addon.md