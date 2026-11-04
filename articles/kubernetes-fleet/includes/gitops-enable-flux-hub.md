---
ms.topic: include
ms.service: azure-kubernetes-fleet-manager
ms.date: 10/28/2026
author: sjwaight
ms.author: simonwaight
---

* For the subscription where Fleet Manager is deployed, register the following Azure resource providers.

    ```azurecli-interactive
    az provider register --namespace Microsoft.Kubernetes
    az provider register --namespace Microsoft.ContainerService
    az provider register --namespace Microsoft.KubernetesConfiguration
    ```
 
* The user who installs and configures the extension must have both the [Azure Kubernetes Fleet Manager Contributor][azure-rbac-fleet-manager-contributor-role] and [Kubernetes Extension Contributor][azure-rbac-kubernetes-extension-contributor-role] roles.

* You need the `k8s-extension` and `fleet` Azure CLI extensions. You can install them by running the following commands.

  ```azurecli-interactive
  az extension add --name k8s-extension
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extensions.

  ```azurecli-interactive
  az extension update --name k8s-extension
  az extension update --name fleet
  ```

* Enable the Flux extension on the Fleet Manager hub cluster.

    ```azurecli-interactive
    az k8s-extension create \
        --name flux \
        --extension-type microsoft.flux \
        --cluster-name ${FLEET} \
        --resource-group ${GROUP} \
        --cluster-type fleets \
        --scope cluster
    ```
    
  If you want to limit Flux to managing resources in a namespace other than the default `flux-system`, provide the namespace by using the `--release-namespace` parameter. To use the Flux extension in a [multi-tenancy configuration][azure-arc-flux-multitenancy] update the `--scope` argument to `namespace`.

  > [!NOTE]
  > You can only install one instance of the Flux extension on a Fleet Manager.

<!-- INTERNAL LINKS -->
[az-extension-update]: /cli/azure/extension#az-extension-update
[azure-arc-flux-multitenancy]: /azure/azure-arc/kubernetes/conceptual-gitops-flux2#multi-tenancy
[azure-rbac-fleet-manager-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-fleet-manager-contributor-role
[azure-rbac-kubernetes-extension-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#kubernetes-extension-contributor
