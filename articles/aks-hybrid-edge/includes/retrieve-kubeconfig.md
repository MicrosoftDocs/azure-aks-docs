---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.lastreviewed: 06/03/2024
ms.reviewer: leslielin

# Common content between AKS and AKS on VMware

---

## Get certificate-based admin kubeconfig

An AKS Hybrid and Edge cluster administrator can retrieve the certificate-based admin kubeconfig using the following command.

### Before you begin

Ensure you meet the following prerequisites:

- An AKS Hybrid and Edge cluster.
- You need the Azure CLI installed and configured. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- Install the latest version of the `aksarc` and `connectedk8s` Azure CLI extension:

  ```azurecli
  az extension add --name aksarc
  az extension add --name connectedk8s
  ```

  If you already installed the extensions, update the extension to the latest version:

  ```azurecli
  az extension update --name aksarc
  az extension update --name connectedk8s
  ```

- **Kubectl**. The Kubernetes command-line tool, kubectl, enables you to run commands targeting your Kubernetes clusters. To check whether you installed kubectl, open a command prompt and type `kubectl version --client`. Make sure your kubectl client version is at least `v1.24.0`. For installation instructions, see [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl).
- To run the Azure CLI command, you must have the `Azure Kubernetes Service Arc Cluster Admin` role, or **Microsoft.HybridContainerService/provisionedClusterInstances/listAdminKubeconfig/action** action on the Kubernetes cluster.
- In order to retrieve and use the certificate-based admin Kubeconfig, you need direct line of sight to your AKS cluster. Run the following commands on the physical machine, or a jumpbox that has access to the physical machines on which your AKS cluster is running.

### Retrieve the certificate-based admin kubeconfig using Az CLI

You can retrieve the kubeconfig of your AKS cluster using the [`az aksarc get-credentials`](/cli/azure/aksarc#az-aksarc-get-credentials) command.

> [!CAUTION]
> The admin kubeconfig contains secrets, so you should follow best security practices for the admin kubeconfig; such as securely handle it, rotate secrets periodically, and so on.

```azurecli
az aksarc get-credentials --resource-group myResourceGroup --name myAKSCluster --admin
```

Now, you can use `kubectl` to manage your Kubernetes cluster. For example, you can list the nodes in your cluster using `kubectl get nodes`:

```azurecli
kubectl get nodes
```

Expected output:

```output
NAME             STATUS ROLES                AGE VERSION
moc-l0ttdmaioew  Ready  control-plane,master 34m v1.24.11
moc-ls38tngowsl  Ready  <none>               32m v1.24.11
```
