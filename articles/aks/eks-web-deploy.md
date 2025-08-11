---
title: Deploy an Amazon Web Services (AWS) web application to Azure
description: Learn how to deploy an AWS web application to Azure and validate your deployment.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.date: 10/31/2024
ms.service: azure-kubernetes-service
ms.custom: 
    - migration
    - aws-to-azure
    - eks-to-aks
# Customer intent: As a cloud engineer, I want to deploy an AWS web application to Azure Kubernetes Service so that I can leverage Azure's infrastructure and services for better scalability and management.
---

# Deploy an Amazon Web Services (AWS) web application to Azure

In this article, you deploy the [Yelb application][yelb] to the [Azure Kubernetes Service (AKS)][aks] cluster you created in the [previous article](./eks-web-prepare.md).

## Check the environment

Before you deploy the application, ensure that your AKS cluster is properly configured using the following commands:

1. List the namespaces in your cluster using the `kubectl get namespace` command.

    ```bash
    kubectl get namespace
    ```

    If you installed the NGINX ingress controller using the application routing add-on, you should see the `app-routing-system` namespace in the output:

    ```output
    NAME                 STATUS   AGE
    app-routing-system   Active   4h28m
    cert-manager         Active   109s
    dapr-system          Active   4h18m
    default              Active   4h29m
    gatekeeper-system    Active   4h28m
    kube-node-lease      Active   4h29m
    kube-public          Active   4h29m
    kube-system          Active   4h29m
    ```

    If you installed the NGINX ingress controller via Helm, you should see the `ingress-basic` namespace in the output:

    ```output
    NAME                STATUS   AGE
    cert-manager        Active   7m42s
    dapr-system         Active   11m
    default             Active   21m
    gatekeeper-system   Active   20m
    ingress-basic       Active   7m19s
    kube-node-lease     Active   21m
    kube-public         Active   21m
    kube-system         Active   21m
    prometheus          Active   8m9s
    ```

1. Get the service details of the `app-routing-system` or the `ingress-basic` namespace using the `kubectl get service command`.

    ```bash
    kubectl get service --namespace <namespace-name> -o wide
    ```

    If you used the application routing add-on, you should see the `EXTERNAL-IP` of the `nginx` service is a private IP address. This address is the private IP of a frontend IP configuration in the `kubernetes-internal` private load balancer of your AKS cluster:

    ```output
    NAME    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                      AGE     SELECTOR
    nginx   LoadBalancer   172.16.55.104   10.240.0.7    80:31447/TCP,443:31772/TCP,10254:30459/TCP   4h28m   app=nginx
    ```

    If you used Helm, you should see the `EXTERNAL-IP` of the `nginx-ingress-ingress-nginx-controller` service is a private IP address. This address is the private IP of a frontend IP configuration in the `kubernetes-internal` private load balancer of your AKS cluster.
  
    ```output
    NAME                                               TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
    nginx-ingress-ingress-nginx-controller             LoadBalancer   172.16.42.152    10.240.0.7    80:32117/TCP,443:32513/TCP   7m31s
    nginx-ingress-ingress-nginx-controller-admission   ClusterIP      172.16.78.85     <none>        443/TCP                      7m31s
    nginx-ingress-ingress-nginx-controller-metrics     ClusterIP      172.16.109.138   <none>        10254/TCP                    7m31s
    ```

## Prepare to deploy the Yelb application

If you want to deploy the sample using the [TLS termination at Application Gateway and Yelb invocation via HTTP](eks-web-prepare.md#tls-termination-at-the-application-gateway-and-yelb-invocation-via-http) approach, you can find the Bash scripts and YAML templates to deploy the [Yelb][yelb] application in the `http` folder.

If you want to deploy the sample using the [Implementing end-to-end TLS using Azure Application Gateway](./eks-web-prepare.md#implementing-end-to-end-tls-using-azure-application-gateway) architecture, you can find the Bash scripts and YAML templates to deploy the web application in the `https` folder.

In the remaining sections of this article, we guide you through the deployment process of the sample application using the end-to-end TLS approach.


### Customize variables

1. Before running any scripts, you need to customize the values of the variables in the `00-variables.sh` file. This file is included in all scripts and contains the following variables:

    ```bash
    # Azure subscription and tenant
    RESOURCE_GROUP_NAME="<aks-resource-group>"
    SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
    SUBSCRIPTION_NAME="$(az account show --query name --output tsv)"
    TENANT_ID="$(az account show --query tenantId --output tsv)"
    AKS_CLUSTER_NAME="<aks-name>"
    AGW_NAME="<application-gateway-name>"
    AGW_PUBLIC_IP_NAME="<application-gateway-public-ip-name>"
    DNS_ZONE_NAME="<your-azure-dns-zone-name-eg-contoso.com>"
    DNS_ZONE_RESOURCE_GROUP_NAME="<your-azure-dns-zone-resource-group-name>"
    DNS_ZONE_SUBSCRIPTION_ID="<your-azure-dns-zone-subscription-id>"

    # NGINX ingress controller installed via Helm
    NGINX_NAMESPACE="ingress-basic"
    NGINX_REPO_NAME="ingress-nginx"
    NGINX_REPO_URL="https://kubernetes.github.io/ingress-nginx"
    NGINX_CHART_NAME="ingress-nginx"
    NGINX_RELEASE_NAME="ingress-nginx"
    NGINX_REPLICA_COUNT=3

    # Specify the ingress class name for the ingress controller
    # - nginx: Unmanaged NGINX ingress controller installed via Helm
    # - webapprouting.kubernetes.azure.com: Managed NGINX ingress controller installed via AKS application routing add-on
    INGRESS_CLASS_NAME="webapprouting.kubernetes.azure.com"

    # Subdomain of the Yelb UI service
    SUBDOMAIN="<yelb-application-subdomain>"

    # URL of the Yelb UI service
    URL="https://$SUBDOMAIN.$DNS_ZONE_NAME"

    # Secret provider class
    KEY_VAULT_NAME="<key-vault-name>"
    KEY_VAULT_CERTIFICATE_NAME="<key-vault-resource-group-name>"
    KEY_VAULT_SECRET_PROVIDER_IDENTITY_CLIENT_ID="<key-vault-secret-provider-identity-client-id>"
    TLS_SECRET_NAME="yelb-tls-secret"
    NAMESPACE="yelb"
    ```

1. You can run the following [az aks show](/cli/azure/aks#az-aks-show) command to retrieve the `clientId` of the [user-assigned managed identity](/entra/identity/managed-identities-azure-resources/how-manage-user-assigned-managed-identities) used by the [Azure Key Vault Provider for Secrets Store CSI Driver](/azure/aks/csi-secrets-store-identity-access). The `keyVault.bicep` module [Key Vault Administrator](/azure/key-vault/general/rbac-guide?tabs=azure-cli#azure-built-in-roles-for-key-vault-data-plane-operations) role to the user-assigned managed identity of the addon to let it retrieve the certificate used by [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) used to expose the `yelb-ui` service via the [NGINX ingress controller](https://docs.nginx.com/nginx-ingress-controller/overview/about/).

    ```azurecli-interactive
    az aks show \
      --name <aks-name> \
      --resource-group <aks-resource-group-name> \
      --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId \
      --output tsv \
      --only-show-errors
    ```

1. If you deployed the Azure infrastructure using the Bicep modules provided with this sample, you can proceed to [deploy the Yelb application](#deploy-the-application). If you want to deploy the application in your AKS cluster, you can use the following scripts to configure your environment. You can use the `02-create-nginx-ingress-controller.sh` to install the [NGINX ingress controller][nginx] with the [ModSecurity](https://github.com/SpiderLabs/ModSecurity) open-source web application firewall (WAF) enabled.

    ```bash
    #!/bin/bash

    # Variables
    source ./00-variables.sh

    # Check if the NGINX ingress controller Helm chart is already installed
    result=$(helm list -n $NGINX_NAMESPACE | grep $NGINX_RELEASE_NAME | awk '{print $1}')

    if [[ -n $result ]]; then
      echo "[$NGINX_RELEASE_NAME] NGINX ingress controller release already exists in the [$NGINX_NAMESPACE] namespace"
    else
      # Check if the NGINX ingress controller repository is not already added
      result=$(helm repo list | grep $NGINX_REPO_NAME | awk '{print $1}')

      if [[ -n $result ]]; then
        echo "[$NGINX_REPO_NAME] Helm repo already exists"
      else
        # Add the NGINX ingress controller repository
        echo "Adding [$NGINX_REPO_NAME] Helm repo..."
        helm repo add $NGINX_REPO_NAME $NGINX_REPO_URL
      fi

      # Update your local Helm chart repository cache
      echo 'Updating Helm repos...'
      helm repo update

      # Deploy NGINX ingress controller
      echo "Deploying [$NGINX_RELEASE_NAME] NGINX ingress controller to the [$NGINX_NAMESPACE] namespace..."
      helm install $NGINX_RELEASE_NAME $NGINX_REPO_NAME/$nginxChartName \
        --create-namespace \
        --namespace $NGINX_NAMESPACE \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.replicaCount=$NGINX_REPLICA_COUNT \
        --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    fi

    # Get values
    helm get values $NGINX_RELEASE_NAME --namespace $NGINX_NAMESPACE
    ```

### Deploy the application

1. Run the following `03-deploy-yelb.sh` script to deploy the Yelb application and a [Kubernetes Ingress][kubernetes-ingress] object to make the `yelb-ui` service accessible to the public internet.

    ```bash
    #!/bin/bash

    # Variables
    source ./00-variables.sh

    # Check if namespace exists in the cluster
    result=$(kubectl get namespace -o jsonpath="{.items[?(@.metadata.name=='$NAMESPACE')].metadata.name}")

    if [[ -n $result ]]; then
      echo "$NAMESPACE namespace already exists in the cluster"
    else
      echo "$NAMESPACE namespace does not exist in the cluster"
      echo "creating $NAMESPACE namespace in the cluster..."
      kubectl create namespace $NAMESPACE
    fi

    # Create the Secret Provider Class object
    echo "Creating the secret provider class object..."
    cat <<EOF | kubectl apply -f -
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      namespace: $NAMESPACE
      name: yelb
    spec:
      provider: azure
      secretObjects:
        - secretName: $TLS_SECRET_NAME
          type: kubernetes.io/tls
          data: 
            - objectName: $KEY_VAULT_CERTIFICATE_NAME
              key: tls.key
            - objectName: $KEY_VAULT_CERTIFICATE_NAME
              key: tls.crt
      parameters:
        usePodIdentity: "false"
        useVMManagedIdentity: "true"
        userAssignedIdentityID: $KEY_VAULT_SECRET_PROVIDER_IDENTITY_CLIENT_ID
        keyvaultName: $KEY_VAULT_NAME
        objects: |
          array:
            - |
              objectName: $KEY_VAULT_CERTIFICATE_NAME
              objectType: secret
        tenantId: $TENANT_ID
    EOF

    # Apply the YAML configuration
    kubectl apply -f yelb.yml

    echo "waiting for secret $TLS_SECRET_NAME in namespace $namespace..."

    while true; do
      if kubectl get secret -n $NAMESPACE $TLS_SECRET_NAME >/dev/null 2>&1; then
        echo "secret $TLS_SECRET_NAME found!"
        break
      else
        printf "."
        sleep 3
      fi
    done

    # Create chat-ingress
    cat ingress.yml |
      yq "(.spec.ingressClassName)|="\""$INGRESS_CLASS_NAME"\" |
      yq "(.spec.tls[0].hosts[0])|="\""$SUBDOMAIN.$DNS_ZONE_NAME"\" |
      yq "(.spec.tls[0].secretName)|="\""$TLS_SECRET_NAME"\" |
      yq "(.spec.rules[0].host)|="\""$SUBDOMAIN.$DNS_ZONE_NAME"\" |
      kubectl apply -f -

    # Check the deployed resources within the yelb namespace:
    kubectl get all -n yelb
    ```

2. Update the `yelb-ui` YAML manifest to include the `csi volume` definition and `volume mount` to read the certificate as a secret from Azure Key Vault.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-ui
      tier: frontend
  template:
    metadata:
      labels:
        app: yelb-ui
        tier: frontend
    spec:
      containers:
        - name: yelb-ui
          image: mreferre/yelb-ui:0.7
          ports:
            - containerPort: 80
          volumeMounts:
            - name: secrets-store-inline
              mountPath: "/mnt/secrets-store"
              readOnly: true
      volumes:
        - name: secrets-store-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: yelb
```

3. You can now deploy the application. The script uses the `yelb.yml` YAML manifest to deploy the application and the `ingress.yml` to create the ingress object. If you use an [Azure Public DNS Zone](/azure/dns/public-dns-overview) for domain name resolution, you can employ the `04-configure-dns.sh` script. This script associates the public IP address of the NGINX ingress controller with the domain used by the ingress object, which exposes the `yelb-ui` service. The script performs the following steps:

   1. Retrieves the public address of the Azure public IP used by the front-end IP configuration of the Application Gateway.
   2. Checks if an `A` record exists for the subdomain used by the `yelb-ui` service.
   3. If the `A` record doesn't exist, the script creates it.

  ```bash
  source ./00-variables.sh

  # Get the address of the Application Gateway Public IP
  echo "Retrieving the address of the [$AGW_PUBLIC_IP_NAME] public IP address of the [$AGW_NAME] Application Gateway..."
  PUBLIC_IP_ADDRESS=$(az network public-ip show \
      --resource-group $RESOURCE_GROUP_NAME \
      --name $AGW_PUBLIC_IP_NAME \
      --query ipAddress \
      --output tsv \
      --only-show-errors)
  if [[ -n $PUBLIC_IP_ADDRESS ]]; then
      echo "[$PUBLIC_IP_ADDRESS] public IP address successfully retrieved for the [$AGW_NAME] Application Gateway"
  else
      echo "Failed to retrieve the public IP address of the [$AGW_NAME] Application Gateway"
      exit
  fi
  # Check if an A record for todolist subdomain exists in the DNS Zone
  echo "Retrieving the A record for the [$SUBDOMAIN] subdomain from the [$DNS_ZONE_NAME] DNS zone..."
  IPV4_ADDRESS=$(az network dns record-set a list \
      --zone-name $DNS_ZONE_NAME \
      --resource-group $DNS_ZONE_RESOURCE_GROUP_NAME \
      --subscription $DNS_ZONE_SUBSCRIPTION_ID \
      --query "[?name=='$SUBDOMAIN'].ARecords[].IPV4_ADDRESS" \
      --output tsv \
      --only-show-errors)
  if [[ -n $IPV4_ADDRESS ]]; then
      echo "An A record already exists in [$DNS_ZONE_NAME] DNS zone for the [$SUBDOMAIN] subdomain with [$IPV4_ADDRESS] IP address"
      if [[ $IPV4_ADDRESS == $PUBLIC_IP_ADDRESS ]]; then
          echo "The [$IPV4_ADDRESS] ip address of the existing A record is equal to the ip address of the ingress"
          echo "No additional step is required"
          continue
      else
          echo "The [$IPV4_ADDRESS] ip address of the existing A record is different than the ip address of the ingress"
      fi
      # Retrieving name of the record set relative to the zone
      echo "Retrieving the name of the record set relative to the [$DNS_ZONE_NAME] zone..."
      RECORDSET_NAME=$(az network dns record-set a list \
          --zone-name $DNS_ZONE_NAME \
          --resource-group $DNS_ZONE_RESOURCE_GROUP_NAME \
          --subscription $DNS_ZONE_SUBSCRIPTION_ID \
          --query "[?name=='$SUBDOMAIN'].name" \
          --output tsv \
          --only-show-errors 2>/dev/null)
      if [[ -n $RECORDSET_NAME ]]; then
          echo "[$RECORDSET_NAME] record set name successfully retrieved"
      else
          echo "Failed to retrieve the name of the record set relative to the [$DNS_ZONE_NAME] zone"
          exit
      fi
      # Remove the A record
      echo "Removing the A record from the record set relative to the [$DNS_ZONE_NAME] zone..."
      az network dns record-set a remove-record \
          --ipv4-address $IPV4_ADDRESS \
          --record-set-name $RECORDSET_NAME \
          --zone-name $DNS_ZONE_NAME \
          --resource-group $DNS_ZONE_RESOURCE_GROUP_NAME \
          --subscription $DNS_ZONE_SUBSCRIPTION_ID \
          --only-show-errors 1>/dev/null
      if [[ $? == 0 ]]; then
          echo "[$IPV4_ADDRESS] ip address successfully removed from the [$RECORDSET_NAME] record set"
      else
          echo "Failed to remove the [$IPV4_ADDRESS] ip address from the [$RECORDSET_NAME] record set"
          exit
      fi
  fi
  # Create the A record
  echo "Creating an A record in [$DNS_ZONE_NAME] DNS zone for the [$SUBDOMAIN] subdomain with [$PUBLIC_IP_ADDRESS] IP address..."
  az network dns record-set a add-record \
      --zone-name $DNS_ZONE_NAME \
      --resource-group $DNS_ZONE_RESOURCE_GROUP_NAME \
      --subscription $DNS_ZONE_SUBSCRIPTION_ID \
      --record-set-name $SUBDOMAIN \
      --ipv4-address $PUBLIC_IP_ADDRESS \
      --only-show-errors 1>/dev/null
  if [[ $? == 0 ]]; then
      echo "A record for the [$SUBDOMAIN] subdomain with [$PUBLIC_IP_ADDRESS] IP address successfully created in [$DNS_ZONE_NAME] DNS zone"
  else
      echo "Failed to create an A record for the $SUBDOMAIN subdomain with [$PUBLIC_IP_ADDRESS] IP address in [$DNS_ZONE_NAME] DNS zone"
  fi
  ```

> [!NOTE]
> Before deploying the Yelb application and creating the `ingress` object, the script generates a `SecretProviderClass` to retrieve the TLS certificate from Azure Key Vault and generate the Kubernetes secret for the `ingress` object. It's important to note that the [Secrets Store CSI Driver for Key Vault](/azure/aks/csi-secrets-store-identity-access) creates the Kubernetes secret containing the TLS certificate only when the `SecretProviderClass` and volume definition is included in the `deployment`. To ensure the TLS certificate is properly retrieved from Azure Key Vault and stored in the Kubernetes secret used by the `ingress` object, we need to make the following modifications to the YAML manifest of the `yelb-ui` deployment:
>
> - Add `csi volume` definition using the `secrets-store.csi.k8s.io` driver, which references the `SecretProviderClass` object responsible for retrieving the TLS certificate from Azure Key Vault.
> - Include `volume mount` to read the certificate as a secret from Azure Key Vault.
>
> For more information, see [Set up Secrets Store CSI Driver to enable NGINX ingress controller with TLS](/azure/aks/csi-secrets-store-nginx-tls#deploy-a-secretproviderclass).

## Test the application

Use the `05-call-yelb-ui.sh` script to invoke the `yelb-ui` service, simulate SQL injection, XSS attacks, and observe how the managed rule set of ModSecurity blocks malicious requests.

```bash
#!/bin/bash
# Variables
source ./00-variables.sh
# Call REST API
echo "Calling Yelb UI service at $URL..."
curl -w 'HTTP Status: %{http_code}\n' -s -o /dev/null $URL
# Simulate SQL injection
echo "Simulating SQL injection when calling $URL..."
curl -w 'HTTP Status: %{http_code}\n' -s -o /dev/null $URL/?users=ExampleSQLInjection%27%20--
# Simulate XSS
echo "Simulating XSS when calling $URL..."
curl -w 'HTTP Status: %{http_code}\n' -s -o /dev/null $URL/?users=ExampleXSS%3Cscript%3Ealert%28%27XSS%27%29%3C%2Fscript%3E
# A custom rule blocks any request with the word blockme in the querystring.
echo "Simulating query string manipulation with the 'blockme' word in the query string..."
curl -w 'HTTP Status: %{http_code}\n' -s -o /dev/null $URL/?users?task=blockme
```

The Bash script should produce the following output, where the first call succeeds, while ModSecurity rules block the following two calls:

```output
Calling Yelb UI service at https://yelb.contoso.com...
HTTP Status: 200
Simulating SQL injection when calling https://yelb.contoso.com...
HTTP Status: 403
Simulating XSS when calling https://yelb.contoso.com...
HTTP Status: 403
Simulating query string manipulation with the 'blockme' word in the query string...
HTTP Status: 403
```

## Monitor the application

In the proposed solution, the deployment process automatically configures the [Azure Application Gateway][azure-ag] resource to collect diagnostic logs and metrics to an [Azure Log Analytics Workspace][azure-la] workspace. By enabling logs, you can gain valuable insights into the evaluations, matches, and blocks performed by the [Azure Web Application Firewall (WAF)][azure-waf] within the Application Gateway. For more information, see [Diagnostic logs for Application Gateway](/azure/application-gateway/application-gateway-diagnostics#firewall-log). You can also use Log Analytics to examine the data within the firewall logs. When you have the firewall logs in your Log Analytics workspace, you can view data, write queries, create visualizations, and add them to your portal dashboard. For detailed information on log queries, see [Overview of log queries in Azure Monitor](/azure/azure-monitor/logs/log-query-overview).

### Explore data with Kusto queries

In the proposed solution, the deployment process automatically configures the [Azure Application Gateway][azure-ag] resource to collect diagnostic logs and metrics to an [Azure Log Analytics workspace][azure-la]. By enabling logs, you can gain insights into the evaluations, matches, and blocks performed by the [Azure Web Application Firewall (WAF)][azure-waf] within the Application Gateway. For more information, see [Diagnostic logs for Application Gateway](/azure/application-gateway/application-gateway-diagnostics#firewall-log).

You can also use Log Analytics to examine the data within the firewall logs. When you have the firewall logs in your Log Analytics workspace, you can view data, write queries, create visualizations, and add them to your portal dashboard. For more information on log queries, see [Overview of log queries in Azure Monitor](/azure/azure-monitor/logs/log-query-overview).

```kusto
AzureDiagnostics 
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| limit 10
```

Alternatively, when working with the **Resource-specific** table, the raw firewall log data can be accessed using the following query. To learn more about resource-specific tables, refer to the [Monitoring data reference](/azure/application-gateway/monitor-application-gateway-reference#supported-resource-log-categories-for-microsoftnetworkapplicationgateways) documentation.

```kusto
AGWFirewallLogs
| limit 10
```

Once you have the data, you can delve deeper and create graphs or visualizations. Here are some additional examples of [KQL](/kusto/query/) queries that can be utilized:

#### Matched/Blocked requests by IP

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by clientIp_s, bin(TimeGenerated, 1m)
| render timechart
```

#### Matched/Blocked requests by URI

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by requestUri_s, bin(TimeGenerated, 1m)
| render timechart
```

#### Top matched rules

```kusto
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by ruleId_s, bin(TimeGenerated, 1m)
| where count_ > 10
| render timechart
```

#### Top five matched rule groups

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize Count=count() by details_file_s, action_s
| top 5 by Count desc
| render piechart
```

## Review deployed resources

You can use Azure CLI or Azure PowerShell to list the deployed resources in the resource group.

### [Azure CLI](#tab/azure-cli)

List the deployed resources in the resource group using the [`az resource list`][az-resource-list] command.

```azurecli-interactive
az resource list --resource-group <resource-group-name>
```

### [Azure PowerShell](#tab/azure-powershell)

List the deployed resources in the resource group using the [`Get-AzResource`][get-azresource] cmdlet.

```azurepowershell-interactive
Get-AzResource -ResourceGroupName <resource-group-name>
```
---

You can use Azure CLI or Azure PowerShell to delete the resource group when you no longer need the resources you created in this tutorial.

### [Azure CLI](#tab/azure-cli)

Delete the resource group and its associated resources using the [`az group delete`][az-group-delete] command.

```azurecli-interactive
az group delete --name <resource-group-name>
```
### [Azure PowerShell](#tab/azure-powershell)

Delete the resource group and its associated resources using the [`Remove-AzResourceGroup`][remove-azresourcegroup] cmdlet.

```azurepowershell-interactive
Remove-AzResourceGroup -Name <resource-group-name>
```
---

## Next steps

You can increase security and threat protection of the solution using [Azure DDoS Protection][azure-ddos] and [Azure Firewall][azure-fw]. For more information, see the following articles:

- [Tutorial: Protect your application gateway with Azure DDoS Network Protection][azure-ddos-ag]
- [Firewall and Application Gateway for virtual networks][azure-fw-ag-1] 
- [Zero Trust network for web applications with Azure Firewall and Application Gateway][azure-fw-ag-2]

If you use the NGINX ingress controller or any other AKS hosted ingress controller in place of the Azure Application Gateway, you can use the [Azure Firewall][azure-fw] to inspect traffic to and from the AKS cluster and protect the cluster from data exfiltration and other undesired network traffic. For more information, see the following articles:

- [Use Azure Firewall to protect Azure Kubernetes Service (AKS) clusters][azure-fw-aks-1]
- [Use Azure Firewall to help protect an Azure Kubernetes Service (AKS) cluster][azure-fw-aks-2]
 
## Contributors

*Microsoft maintains this article. The following contributors originally wrote it*:

Principal author:
- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

Other contributors:
- [Ken Kilty](https://www.linkedin.com/in/kennethkilty/) | Principal TPM
- [Russell de Pina](https://www.linkedin.com/in/rdepina/) | Principal TPM
- [Erin Schaffer](https://www.linkedin.com/in/erin-schaffer-65800215b/) | Content Developer 2

<!-- LINKS -->
[yelb]: https://github.com/mreferre/yelb/
[nginx]: https://github.com/kubernetes/ingress-nginx
[kubernetes-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[aks]: ./what-is-aks.md
[azure-ddos]: /azure/ddos-protection/ddos-protection-overview
[azure-fw]: /en-us/azure/firewall/overview
[azure-ddos-ag]: /azure/application-gateway/tutorial-protect-application-gateway-ddos
[azure-fw-ag-1]: /azure/architecture/example-scenario/gateway/application-gateway-before-azure-firewall
[azure-fw-ag-2]: /azure/architecture/example-scenario/gateway/firewall-application-gateway
[azure-fw-aks-1]: /azure/firewall/protect-azure-kubernetes-service
[azure-fw-aks-2]: /azure/architecture/guide/aks/aks-firewall
[az-group-delete]: /cli/azure/group#az-group-delete
[remove-azresourcegroup]: /powershell/module/az.resources/remove-azresourcegroup
[azure-waf]: /azure/web-application-firewall/overview
[azure-ag]: /azure/application-gateway/overview
[azure-la]: /azure/azure-monitor/logs/log-analytics-overview