---
author: houk-ms
ms.author: honc
ms.reviewer: schaffererin
ms.service: service-connector
ms.topic: include
ms.date: 09/01/2024
---

Learn how to connect to Azure Key Vault with the Secrets Store CSI Driver in an Azure Kubernetes Service (AKS) cluster using Service Connector. In this article, you complete the following tasks:

> [!div class="checklist"]
>
> * Create an AKS cluster and an Azure Key Vault.
> * Create a connection between the AKS cluster and the Azure Key Vault with Service Connector.
> * Create a `SecretProviderClass` CRD and a `Pod` that consumes the CSI provider to test the connection.
> * Clean up resources.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/).
* The [Azure CLI](/cli/azure/install-azure-cli). Sign in using the [`az login`][az-login] command.
* [Docker](https://docs.docker.com/get-docker/) and [kubectl](https://kubernetes.io/docs/tasks/tools/). To install kubectl locally, use the [`az aks install-cli`][az-aks-install-cli] command.
* A basic understanding of containers and AKS. Get started by [preparing an application for AKS](/azure/aks/tutorial-kubernetes-prepare-app).
* Before you begin, make sure you finish the steps in [Use the Azure Key Vault provider for Secrets Store CSI Driver in an Azure Kubernetes Service (AKS) cluster](../../csi-secrets-store-driver.md) to enable the Azure Key Vault Secrets Store CSI Driver in your AKS cluster.

## Initial set-up

1. If you're using Service Connector for the first time, start by running the command [az provider register](/cli/azure/provider#az-provider-register) to register the Service Connector and Kubernetes Configuration resource providers.

   ```azurecli
   az provider register -n Microsoft.ServiceLinker
   ```
   ```azurecli
   az provider register -n Microsoft.KubernetesConfiguration
   ```

   > [!TIP]
   > You can check if these resource providers have already been registered by running the commands `az provider show -n "Microsoft.ServiceLinker" --query registrationState` and `az provider show -n "Microsoft.KubernetesConfiguration" --query registrationState`.

1. Optionally, use the Azure CLI command to get a list of supported target services for AKS cluster.

   ```azurecli
   az aks connection list-support-types --output table
   ```

## Create Azure resources

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create \
        --name <resource-group-name> \
        --location <location>
    ```

1. Create an AKS cluster using the [`az aks create`][az-aks-create] command. The following example creates a single-node AKS cluster with managed identity enabled.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --enable-managed-identity \
        --node-count 1
    ```

1. Connect to the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group <resource-group-name> \
        --name <cluster-name>
    ```

1. Create an Azure key vault using the [`az keyvault create`][az-keyvault-create] command.

    ```azurecli-interactive
    az keyvault create \
        --resource-group <resource-group-name> \  
        --name <key-vault-name> \
        --location <location>
    ```

1. Create a secret in the key vault using the [`az keyvault secret set`][az-keyvault-secret-set] command.

    ```azurecli-interactive
    az keyvault secret set \
        --vault-name <key-vault-name> \
        --name <secret-name> \
        --value <secret-value>
    ```

## Create a service connection in AKS with Service Connector (preview)

You can create a service connection to Azure Key Vault using the Azure portal or Azure CLI.

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Service Connector (Preview)** > **Create**.
1. On the **Create connection** page, configure the following settings in the **Basics** tab:

    * **Kubernetes namespace**: Select **default**.
    * **Service type**: Select **Key Vault** and select the checkbox to enable the Azure Key Vault CSI Provider.
    * **Connection name**: Enter a name for the connection.
    * **Subscription**: Select the subscription that contains the key vault.
    * **Key vault**: Select the key vault you created.
    * **Client type**: Select **None**.

1. Select **Review + create**, and then select **Create** to create the connection.

### [Azure CLI](#tab/azure-cli)

* Create a connection to your key vault using the [`az aks connection create keyvault`][az-aks-connection-create-keyvault] command.

    ```azurecli-interactive
    az aks connection create keyvault \
        --connection <connection-name> \
        --resource-group <resource-group-of-cluster> \
        --name <cluster-name> \
        --target-resource-group <resource-group-of-key-vault> \
        --vault <key-vault-name> \
        --enable-csi \
        --client-type none

---

## Test the connection

### Clone the sample repo and deploy manifest files

1. Clone the sample repository using the `git clone` command.

   ```bash
   git clone https://github.com/Azure-Samples/serviceconnector-aks-samples.git
   ```

1. Change directories to the Azure Key Vault CSI provider sample.

   ```bash
   cd serviceconnector-aks-samples/azure-keyvault-csi-provider
   ```

1. In the `secret_provider_class.yaml` file, replace the following placeholders with your Azure Key Vault information:

   * Replace `<AZURE_KEYVAULT_NAME>` with the name of the key vault you created and connected.
   * Replace `<AZURE_KEYVAULT_TENANTID>` with the tenant ID of the key vault.
   * Replace `<AZURE_KEYVAULT_CLIENTID>` with identity client ID of the `azureKeyvaultSecretsProvider` addon.
   * Replace `<KEYVAULT_SECRET_NAME>` with the key vault secret you created. For example, `ExampleSecret`.

1. Deploy the `SecretProviderClass` CRD using the `kubectl apply` command.

   ```bash
   kubectl apply -f secret_provider_class.yaml
   ```

1. Deploy the `Pod` manifest file using the `kubectl apply` command.

    The command creates a pod named `sc-demo-keyvault-csi` in the default namespace of your AKS cluster.

   ```bash
   kubectl apply -f pod.yaml
   ```

### Verify the connection

1. Verify the pod was created successfully using the `kubectl get` command.

   ```bash
   kubectl get pod/sc-demo-keyvault-csi
   ```

    After the pod starts, the mounted content at the volume path specified in your deployment YAML is available.

1. Show the secrets held in the secrets store using the `kubectl exec` command.

   ```bash
   kubectl exec sc-demo-keyvault-csi -- ls /mnt/secrets-store/
   ```

1. Display a secret using the `kubectl exec` command.

    This example command shows a test secret named `ExampleSecret`.

   ```bash
   kubectl exec sc-demo-keyvault-csi -- cat /mnt/secrets-store/ExampleSecret
   ```

<!-- LINKS -->
[az-group-create]: /cli/azure/group#az_group_create
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-keyvault-create]: /cli/azure/keyvault#az_keyvault_create
[az-keyvault-secret-set]: /cli/azure/keyvault/secret#az_keyvault_secret_set
[az-aks-connection-create-keyvault]: /cli/azure/aks/connection/create#az_aks_connection_create_keyvault
[az-login]: /cli/azure/reference-index#az_login
[az-aks-install-cli]: /cli/azure/aks#az_aks_install_cli
