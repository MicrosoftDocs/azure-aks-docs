---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 09/18/2026
author: davidsmatlak
ms.author: davidsmatlak
---

Install the aks-preview CLI extension by using the [`az extension add`][az-extension-add] command.

```azurecli-interactive
az extension add --name aks-preview
```

Update the extension to ensure you have the latest version installed by using the [`az extension update`][az-extension-update] command.

```azurecli-interactive
az extension update --name aks-preview
```


<!--- LINKS --->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
