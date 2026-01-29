---
title: Set up a Custom Domain Name and SSL Certificate with the Application Routing Add-on for Azure Kubernetes Service (AKS)
description: Understand the advanced configuration options that are supported with the application routing add-on for Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.author: davidsmatlak
author: davidsmatlak
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 01/29/2026
# Customer intent: As a Kubernetes administrator, I want to set up a custom domain and SSL certificate using the application routing add-on, so that I can securely manage external access to services in my Azure Kubernetes Service cluster.
---

# Set up a custom domain name and SSL certificate with the application routing add-on for Azure Kubernetes Service (AKS)

This article shows you how to configure custom domain names and SSL/TLS certificates for AKS ingress using [Azure Key Vault][azure-key-vault-overview] and [Azure DNS][azure-dns-overview] with the [application routing add-on for AKS](./app-routing.md).

## Prerequisites

- An AKS cluster with the [application routing add-on][app-routing-add-on-basic-configuration].
- Azure Key Vault if you want to configure SSL termination and store certificates in the vault hosted in Azure. If you don't have one, see [Create a key vault using the Azure CLI](/azure/key-vault/general/quick-create-cli).
- To enable support for HTTPS traffic, you need an SSL certificate. If you don't have one, see [create a certificate][create-and-export-a-self-signed-ssl-certificate].
- Azure DNS if you want to configure global and private zone management and host them in Azure. If you don't have an Azure DNS zone, you can [create one][create-an-azure-dns-zone]. To enable support for DNS zones:

  - All global Azure DNS zones need to be in the same resource group, which could be different from the cluster resource group.
  - All private Azure DNS zones need to be in the same resource group, which could be different from the cluster resource group.
  - The resource group doesn't need to be in the same subscription as the cluster.

### Required Azure permissions

**Your user account needs**: [Owner][rbac-owner], [Azure account administrator][rbac-classic], or [Azure co-administrator][rbac-classic] role on your Azure subscription.

**What the commands do**: When you run `az aks approuting update --attach-kv` or `az aks approuting zone add --attach-zones`, these commands use your role assignment permissions to automatically grant the application routing add-on's managed identity the following roles:

- **Key Vault Certificate User** role on your Azure Key Vault (for certificate access).
- **DNS Zone Contributor** role on your Azure DNS zones (for DNS record management).

For more information on AKS managed identities, see [Summary of managed identities][summary-msi].

## Connect to your AKS cluster

To connect to the Kubernetes cluster from your local computer, you use `kubectl`, the Kubernetes command-line client. You can install it locally using the [`az aks install-cli`][az-aks-install-cli] command. If you use the Azure Cloud Shell, `kubectl` is already installed.

- Configure kubectl to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    # Set environment variables for your resource group and cluster name
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER_NAME=<cluster-name>

    # Get the AKS cluster credentials
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

## Create and export a self-signed SSL certificate

For testing, you can use a self-signed public certificate instead of a Certificate Authority (CA)-signed certificate. If you already have a certificate, you can skip this step.

> [!CAUTION]
> Self-signed certificates are digital certificates that aren't signed by a trusted third-party CA. The company or developer responsible for the website or software creates, issues, and signs these certificates. This is why self-signed certificates are considered unsafe for public-facing websites and applications. Azure Key Vault has a [trusted partnership with the some Certificate Authorities](/azure/key-vault/certificates/how-to-integrate-certificate-authority).

1. Create a self-signed SSL certificate to use with the ingress using the `openssl req` command. Make sure you replace _`<host-name>`_ with the DNS name you're using.

    ```bash
    openssl req -new -x509 -nodes -out aks-ingress-tls.crt -keyout aks-ingress-tls.key -subj "/CN=<host-name>" -addext "subjectAltName=DNS:<host-name>"
    ```

1. Export the SSL certificate and skip the password prompt using the `openssl pkcs12 -export` command.

    ```bash
    openssl pkcs12 -export -in aks-ingress-tls.crt -inkey aks-ingress-tls.key -out aks-ingress-tls.pfx
    ```

## Import a self-signed SSL certificate into Azure Key Vault

- Import the SSL certificate into Azure Key Vault using the [`az keyvault certificate import`][az-keyvault-certificate-import] command. If your certificate is password protected, you can pass the password through the `--password` flag.

    ```azurecli-interactive
    # Set environment variables for your key vault name and certificate name
    export KEY_VAULT_NAME=<key-vault-name>
    export KEY_VAULT_CERT_NAME=<key-vault-certificate-name>

    # Import the SSL certificate into Azure Key Vault
    az keyvault certificate import --vault-name $KEY_VAULT_NAME --name $KEY_VAULT_CERT_NAME --file aks-ingress-tls.pfx [--password <certificate password if specified>]
    ```

> [!NOTE]
> To enable the application routing add-on to reload certificates from Azure Key Vault when they change, you should enable the [secret autorotation feature][csi-secrets-store-autorotation] of the Secrets Store CSI driver. When autorotation is enabled, the driver updates the pod mount and the Kubernetes secret by polling for changes periodically, based on the rotation poll interval you define. The default rotation poll interval is two minutes.

## Enable Azure Key Vault integration

Azure Key Vault offers [two authorization systems][authorization-systems]: **Azure role-based access control (Azure RBAC)**, which operates on the management plane, and the **access policy model**, which operates on both the management plane and the data plane. The `--attach-kv` operation selects the appropriate access model to use.

1. Get the resource ID for the key vault using the [`az keyvault show`][az-keyvault-create] command and set the output to an environment variable.

    ```azurecli-interactive
    KEY_VAULT_ID=$(az keyvault show --name <KeyVaultName> --query "id" --output tsv)
    ```

1. Update the application routing add-on to enable the Azure Key Vault provider for Secrets Store CSI Driver and apply the required role assignments using the [`az aks approuting update`][az-aks-approuting-update] command with the `--enable-kv` and `--attach-kv` arguments.

    ```azurecli-interactive
    az aks approuting update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-kv --attach-kv ${KEY_VAULT_ID}
    ```

## Create a global Azure DNS zone

If you already have an Azure DNS zone, you can skip this step.

- Create an Azure DNS zone using the [`az network dns zone create`][az-network-dns-zone-create] command.

    ```azurecli-interactive
    # Set environment variables for your resource group and DNS zone name
    export RESOURCE_GROUP=<resource-group-name>
    export ZONE_NAME=<zone-name>

    # Create the Azure DNS zone
    az network dns zone create --resource-group $RESOURCE_GROUP --name $ZONE_NAME
    ```

## Enable Azure DNS integration

1. Get the resource ID for the DNS zone using the [`az network dns zone show`][az-network-dns-zone-show] command and set the output to an environment variable.

    ```azurecli-interactive
    ZONE_ID=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $ZONE_NAME --query "id" --output tsv)
    ```

1. Update the application routing add-on to enable Azure DNS integration using the [`az aks approuting zone`][az-aks-approuting-zone] command. You can pass a comma-separated list of DNS zone resource IDs.

    ```azurecli-interactive
    az aks approuting zone add --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --ids=${ZONE_ID} --attach-zones
    ```

## Create an Ingress class that uses a host name and a certificate from Azure Key Vault

The application routing add-on creates an Ingress class on the cluster named _webapprouting.kubernetes.azure.com_. When you create an Ingress object with this class, it activates the add-on.

1. Get the certificate URI to use in the ingress from Azure Key Vault using the [`az keyvault certificate show`][az-keyvault-certificate-show] command.

    ```azurecli-interactive
    az keyvault certificate show --vault-name $KEY_VAULT_NAME --name $KEY_VAULT_CERT_NAME --query "id" --output tsv
    ```

   The following example output shows the certificate URI returned from the command:

    ```output
    https://KeyVaultName.vault.azure.net/certificates/KeyVaultCertificateName/ab12c34567d89e01f2345g6h78ijkl90
    ```

1. Copy the following YAML manifest into a new file named **ingress.yaml** and save the file to your local computer.

   Update _`<host-name>`_ with the name of your DNS host and _`<key-vault-certificate-uri>`_ with the URI returned from the previous command. The string value for _`<key-vault-certificate-uri>`_ should only include `https://yourkeyvault.vault.azure.net/certificates/certname`. Remove the _Certificate Version_ at the end of the URI string to get the current version.

   The _`secretName`_ key in the `tls` section defines the name of the secret that contains the certificate for this Ingress resource. This certificate is presented in the browser when a client browses to the URL specified in the `<host-name>` key. Make sure that the value of `secretName` is equal to `keyvault-` followed by the value of the Ingress resource name (from `metadata.name`). In the example YAML, `secretName` needs to be equal to `keyvault-<your-ingress-name>`.

    ```yml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      annotations:
        kubernetes.azure.com/tls-cert-keyvault-uri: <key-vault-certificate-uri>
      name: aks-helloworld
      namespace: hello-web-app-routing
    spec:
      ingressClassName: webapprouting.kubernetes.azure.com
      rules:
      - host: <host-name>
        http:
          paths:
          - backend:
              service:
                name: aks-helloworld
                port:
                  number: 80
            path: /
            pathType: Prefix
      tls:
      - hosts:
        - <host-name>
        secretName: keyvault-<your-ingress-name>
    ```

1. Create the cluster resources using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f ingress.yaml -n hello-web-app-routing
    ```

    The following example output shows the created resource:

    ```output
    Ingress.networking.k8s.io/aks-helloworld created
    ```

## Verify the managed ingress was created

- Verify the managed ingress was created using the [`kubectl get ingress`][kubectl-get] command.

    ```bash
    kubectl get ingress -n hello-web-app-routing
    ```

    The following example output shows the created managed ingress:

    ```output
    NAME             CLASS                                HOSTS               ADDRESS       PORTS     AGE
    aks-helloworld   webapprouting.kubernetes.azure.com   myapp.contoso.com   20.51.92.19   80, 443   4m
    ```

## Related content

Learn about monitoring the Ingress NGINX controller metrics included with the application routing add-on with [with Prometheus in Grafana][prometheus-in-grafana] as part of analyzing the performance and usage of your application.

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[summary-msi]: managed-identity-overview.md#summary-of-managed-identities-used-by-aks
[rbac-owner]: /azure/role-based-access-control/built-in-roles#owner
[rbac-classic]: /azure/role-based-access-control/rbac-and-directory-admin-roles#classic-subscription-administrator-roles
[app-routing-add-on-basic-configuration]: app-routing.md
[csi-secrets-store-autorotation]: csi-secrets-store-configuration-options.md#manage-auto-rotation
[azure-key-vault-overview]: /azure/key-vault/general/overview
[az-aks-approuting-update]: /cli/azure/aks/approuting#az-aks-approuting-update
[az-aks-approuting-zone]: /cli/azure/aks/approuting/zone
[az-network-dns-zone-show]: /cli/azure/network/dns/zone#az-network-dns-zone-show
[az-network-dns-zone-create]: /cli/azure/network/dns/zone#az-network-dns-zone-create
[az-keyvault-certificate-import]: /cli/azure/keyvault/certificate#az-keyvault-certificate-import
[az-keyvault-create]: /cli/azure/keyvault#az-keyvault-create
[authorization-systems]: /azure/key-vault/general/rbac-access-policy
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[create-and-export-a-self-signed-ssl-certificate]: #create-and-export-a-self-signed-ssl-certificate
[create-an-azure-dns-zone]: #create-a-global-azure-dns-zone
[azure-dns-overview]: /azure/dns/dns-overview
[az-keyvault-certificate-show]: /cli/azure/keyvault/certificate#az-keyvault-certificate-show
[prometheus-in-grafana]: app-routing-nginx-prometheus.md
