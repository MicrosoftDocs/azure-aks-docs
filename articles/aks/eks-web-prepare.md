---
title: Prepare to Deploy Web Application Workload to Azure
description: Learn the steps to deploy your web application workload to Azure Kubernetes Service (AKS).
author: paolosalvatori
ms.author: paolos
ms.topic: how-to
ms.date: 10/31/2024
ms.service: azure-kubernetes-service
ms.custom: 
    - migration
    - aws-to-azure
    - eks-to-aks
---

# Prepare to deploy web application workload to Azure

This article provides a comprehensive guide on how to deploy a robust and production-ready infrastructure to facilitate the hosting, protection, scaling, and monitoring of a web application on the Azure platform.

## Yelb deployment on AWS

The [Yelb][yelb] sample web application on AWS is deployed using Bash, [AWS CLI][aws-cli], [eksctl][eksctl], [kubectl][kubectl], and [Helm][helm]. The companion [sample][azure-sample] contains Bash scripts and YAML manifests that you can use to automate the deployment of the [Yelb][yelb] application on [AWS Elastic Kubernetes Service (EKS)][aws-eks]. This solution demonstrates how to implement a web application firewall using [AWS WAF][aws-waf] to protect a web application running on [Amazon Elastic Kubernetes Service (EKS)][aws-eks]. You can use the Bash scripts to create an EKS cluster and deploy the [Yelb][yelb] application. The [Yelb][yelb] web application is exposed to the public internet using an [Amazon Application Load Balancer (ALB)][aws-alb] and protected using [AWS WAF web access control list (web ACL)][aws-web-acl]. For detailed instructions, see [Porting a Web Application from AWS Elastic Kubernetes Service (EKS) to Azure Kubernetes Service (AKS)][azure-sample].

:::image type="content" source="media/eks-web-rearchitect/yelb-ui.png" alt-text="Screenshot of the Yelb service interface.":::

## Yelb deployment on Azure

In this tutorial, you learn how to deploy the Yelb sample web application on an [Azure Kubernetes Service (AKS)][aks] cluster and expose it through an ingress controller like the [NGINX ingress controller][nginx]. The ingress controller service is accessible via an [internal (or private) load balancer][azure-lb], which is used to balance traffic within the virtual network housing the AKS cluster. This load balancer frontend can also be accessed from an on-premises network in a hybrid scenario. To learn more about utilizing an internal load balancer to restrict the access to your applications in Azure Kubernetes Service (AKS), refer to the guide [Use an internal load balancer with Azure Kubernetes Service (AKS)](/azure/aks/internal-lb?tabs=set-service-annotations).

The companion [sample][azure-sample] supports installing a [managed NGINX ingress controller with the application routing add-on][aks-app-routing-addon] or an unmanaged [NGINX ingress controller][nginx] using the [Helm chart][nginx-helm-chart]. The application routing add-on with NGINX ingress controller provides the following features:

- Easy configuration of managed NGINX Ingress controllers based on [Kubernetes NGINX Ingress controller][nginx].
- Integration with [Azure DNS][azure-dns] for public and private zone management.
- SSL termination with certificates stored in [Azure Key Vault][azure-kv].

For other configurations, see:

- [DNS and SSL configuration](/azure/aks/app-routing-dns-ssl)
- [Application routing add-on configuration](/azure/aks/app-routing-nginx-configuration)
- [Configure internal NGIX ingress controller for Azure private DNS zone](/azure/aks/create-nginx-ingress-private-controller).

To enhance security, the [Yelb][yelb] application is protected by an [Azure Application Gateway][azure-ag] resource. This resource is deployed in a dedicated subnet within the same virtual network as the AKS cluster or in a peered virtual network. 
The [Azure Web Application Firewall (WAF)][azure-waf] secures access to the web application hosted on [Azure Kubernetes Service (AKS)][aks] and exposed via the [Azure Application Gateway][azure-ag] against common exploits and vulnerabilities.

## Prerequisites

- An active [Azure subscription](/azure/guides/developer/azure-developer-guide#understanding-accounts-subscriptions-and-billing). If you don't have one, create a [free Azure account][azure-free] before you begin.
- The **Owner** [Azure built-in role][azure-built-in-roles], or the **User Access Administrator** and **Contributor** built-in roles, on a subscription in your Azure account.
- [Azure CLI][azure-cli] version 2.61.0 or later. For more information, see [Install Azure CLI][azure-cli].
- [Azure Kubernetes Service (AKS) preview extension][aks-preview].
- [jq][install-jq] version 1.5 or later.
- [Python 3][install-python] or later.
- [kubectl][install-kubectl] version 1.21.0 or later
- [Helm][install-helm] version 3.0.0 or later
- [Visual Studio Code][download-vscode] installed on one of the [supported platforms](https://code.visualstudio.com/docs/supporting/requirements#_platforms) along with the [Bicep extension][bicep-extension].
- An existing [Azure Key Vault][azure-kv] resource with a valid TLS certificate for the Yelb web application.
- An existing [Azure DNS Zone][azure-dns] or equivalent DNS server for the name resolution of the [Yelb][yelb] application.

## Architecture

This sample provides a collection of [Bicep][bicep] templates, Bash scripts, and YAML manifests for building an AKS cluster, deploying the [Yelb][yelb] application, exposing the UI service using the [NGINX ingress controller][nginx] and protecting it with the [Azure Application Gateway][azure-ag] and [Azure Web Application Firewall (WAF)][azure-waf].

This sample also includes two separate Bicep parameter files and two sets of Bash scripts and YAML manifests, each geared towards deploying two different solution options. For more information on Bicep, see [What is Bicep?](/azure/azure-resource-manager/bicep/overview)

## TLS Termination at Application Gateway and Yelb Invocation via HTTP

In this solution, the [Azure Web Application Firewall (WAF)][azure-waf] ensures the security of the system by blocking malicious attacks. The [Azure Application Gateway][azure-ag] plays a crucial role in the architecture by receiving incoming calls from client applications, performing TLS termination, and forwarding the requests to the AKS-hosted `yelb-ui` service. This communication is achieved through the internal load balancer and NGINX Ingress controller, using the HTTP transport protocol. The following diagram illustrates the architecture:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-http.png" alt-text="Architecture diagram of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTP.":::

The message flow can be described as follows:

- The [Azure Application Gateway][azure-ag] takes care of TLS termination and sends incoming calls to the AKS-hosted `yelb-ui` service over HTTP.
- To ensure secure communication, the Application Gateway Listener makes use of an SSL certificate obtained from [Azure Key Vault][azure-kv].
- The Azure WAF Policy associated with the Listener applies OWASP rules and custom rules to incoming requests, effectively preventing malicious attacks.
- The Application Gateway Backend HTTP Settings are configured to invoke the Yelb application via HTTP, utilizing port 80.
- To manage traffic, the Application Gateway Backend Pool and Health Probe are set to call the [NGINX ingress controller][nginx] through the AKS internal load balancer using the HTTP protocol.
- The [NGINX ingress controller][nginx] is deployed to utilize the AKS internal load balancer instead of the public one, ensuring secure communication within the cluster.
- To expose the application via HTTP through the AKS internal load balancer, a [Kubernetes ingress][kubernetes-ingress] object makes use of the [NGINX ingress controller][nginx].
- The `yelb-ui` service has a ClusterIP type, which restricts its invocation to within the cluster or through the [NGINX ingress controller][nginx].

The following diagram illustrates the message flow in further detail:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-http-detail.png" alt-text="Details of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTP.":::

## Implementing End-to-End TLS Using Azure Application Gateway

Before diving into the solution, let's quickly go over [TLS termination and end-to-end TLS with Application Gateway](/azure/application-gateway/ssl-overview).

### TLS termination with Application Gateway

[Azure Application Gateway][azure-ag] supports the termination of Transport Layer Security (TLS) at the gateway level, which means that traffic is decrypted at the gateway before being sent to the backend servers. This approach offers several benefits:

- **Improved performance**: The initial handshake for TLS decryption can be resource-intensive. By caching TLS session IDs and managing TLS session tickets at the application gateway, multiple requests from the same client can utilize cached values, improving performance. If TLS decryption is performed on the backend servers, the client needs to reauthenticate with each server change.
- **Better utilization of backend servers**: SSL/TLS processing requires significant CPU resources, especially with increasing key sizes. If you offload this work from the backend servers to the Application Gateway, the servers can focus more efficiently on delivering content.
- **Intelligent routing**: Decrypting traffic at the application gateway allows access to request content such as headers and URIs. This data can be utilized to intelligently route requests.
- **Certificate management**: By adding TLS termination at the application gateway, certificates only need to be purchased and installed on the gateway rather than on every backend server.

To configure TLS termination, you need to add a TLS/SSL certificate to the listener. The certificate should be in Personal Information Exchange (PFX) format, which contains both the private and public keys. You can import the certificate from Azure Key Vault to the Application Gateway. For more information on TLS termination with Key Vault certificates, refer to the [TLS termination with Key Vault certificates](/azure/application-gateway/key-vault-certs) documentation.

### Zero Trust Security Model

If you adopt a [Zero Trust](https://www.microsoft.com/en-us/security/business/zero-trust) security model, you should prevent unencrypted communication between a service proxy like Azure Application Gateway and the backend servers. The zero trust security model is a concept wherein trust is not automatically granted to any user or device trying to access resources within a network. Instead, it requires continuous verification of identity and authorization for each request, regardless of the user's location or network.

In our scenario, implementing the zero trust security model involves utilizing the Azure Application Gateway as a service proxy, which acts as a front-end for incoming requests. These requests then travel down to the NGINX Ingress controller on Azure Kubernetes Service (AKS) in an encrypted format.

Zero trust security model provides several advantages to improve the privacy and security of communications:

1. **Enhanced Access Control:** With zero trust, access control is based on continuous verification. This approach ensures that only authorized users or devices are granted access to specific resources, thus reducing the risk of unauthorized access and potential data breaches.
2. **Stronger Data Protection:** The encryption of requests ensures that sensitive information is transmitted securely and mitigates the risk of unauthorized interception and protects the privacy of communications.
3. **Reduction in Lateral Movement:** Zero trust restricts the movement of threats within the network by enforcing strict access controls. Even if one part of the network is compromised, the attacker's ability to move laterally and access other resources is limited.
4. **Improved Visibility and Monitoring:** The zero trust security model typically employs advanced monitoring and analytics tools. These tools offer better insight into the network's behavior, allowing for quick detection and response to any potential security incidents.

Zero trust security model enhances privacy and security by enforcing continuous verification, encrypting communications, and limiting lateral movement of threats within the network. 

### End-to-End TLS with Application Gateway

You can implement a zero trust approach by configuring Azure Application Gateway for end-to-end TLS encryption with the backend servers. [End-to-end TLS encryption](/azure/application-gateway/ssl-overview#end-to-end-tls-encryption) allows you to securely transmit sensitive data to the backend while also utilizing Application Gateway's Layer-7 load-balancing features. These features include cookie-based session affinity, URL-based routing, routing based on sites, and the ability to rewrite or inject X-Forwarded-* headers.

When Application Gateway is configured with end-to-end TLS communication mode, it terminates the TLS sessions at the gateway and decrypts user traffic. It then applies the configured rules to select the appropriate backend pool instance to route the traffic to. Next, Application Gateway initiates a new TLS connection to the backend server and re-encrypts the data using the backend server's public key certificate before transmitting the request to the backend. The response from the web server follows the same process before reaching the end user. To enable end-to-end TLS, you need to set the protocol setting in the Backend HTTP Setting to HTTPS and apply it to a backend pool. This approach ensures that your communication with the backend servers is secured and compliant with your requirements. For more information, you can refer to the documentation on [Application Gateway end-to-end TLS encryption](/azure/application-gateway/end-to-end-ssl-portal). Additionally, you may find it useful to review [best practices for securing your Application Gateway](/security/benchmark/azure/baselines/application-gateway-security-baseline).

### Solution

In this solution, the [Azure Web Application Firewall (WAF)][azure-waf] ensures the security of the system by blocking malicious attacks. The [Azure Application Gateway][azure-ag] handles incoming calls from client applications and performs TLS termination. It also implements [end-to-end TLS](/azure/application-gateway/ssl-overview#end-to-end-tls-encryption) by invoking the underlying AKS-hosted `yelb-ui` service using the HTTPS transport protocol via the internal load balancer and NGINX Ingress controller. The following diagram illustrates the architecture:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-https.png" alt-text="Architecture diagram of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTPS.":::

The message flow can be described as follows:

- The [Azure Application Gateway][azure-ag] handles TLS termination and communicates with the backend application over HTTPS.
- The Application Gateway Listener utilizes an SSL certificate obtained from [Azure Key Vault][azure-kv].
- The Azure WAF Policy associated with the Listener runs OWASP rules and custom rules against incoming requests to block malicious attacks.
- The Application Gateway Backend HTTP Settings are configured to invoke the AKS-hosted `yelb-ui` service via HTTPS on port 443.
- The Application Gateway Backend Pool and Health Probe call the [NGINX ingress controller][nginx] through the AKS internal load balancer using HTTPS.
- The [NGINX ingress controller][nginx] is deployed to use the AKS internal load balancer.
- The Azure Kubernetes Service (AKS) cluster is configured with the [Azure Key Vault provider for Secrets Store CSI Driver][azure-kv-csi-driver] addon to retrieve secrets, certificates, and keys from Azure Key Vault via a [CSI volume](https://kubernetes-csi.github.io/docs/).
- A [SecretProviderClass][secret-provider-class] is used to retrieve the certificate used by the Application Gateway from Key Vault.
- A [Kubernetes ingress][kubernetes-ingress] object utilizes the [NGINX ingress controller][nginx] to expose the application via HTTPS through the AKS internal load balancer.
- The `yelb-ui` service has a ClusterIP type, which restricts its invocation to within the cluster or through the [NGINX ingress controller][nginx].

In order to ensure the security and stability of the system, it is important to consider the following recommendations:

- It is crucial to regularly update the Azure WAF Policy with the latest rules to ensure optimal security.
- Monitoring and logging mechanisms should be implemented to track and analyze incoming requests and potential attacks.
- Regular maintenance and updates of the AKS cluster, NGINX ingress controller, and Application Gateway are necessary to address any security vulnerabilities and maintain a secure infrastructure.

### Hostname

The Application Gateway Listener and the [Kubernetes ingress][kubernetes-ingress] are configured to use the same hostname. Here are the reasons why it is important to use the same hostname for a service proxy and a backend web application:

- **Preservation of Session State**: When a different hostname is used between the proxy and the backend application, session state can get lost. This means that user sessions may not persist properly, resulting in a poor user experience and potential loss of data.
- **Authentication Failure**: If the hostname differs between the proxy and the backend application, authentication mechanisms may fail. This approach can lead to users being unable to log in or access secure resources within the application.
- **Inadvertent Exposure of URLs**: If the hostname is not preserved, there is a risk that backend URLs may be exposed to end users. This can lead to potential security vulnerabilities and unauthorized access to sensitive information.
- **Cookie Issues**: Cookies play a crucial role in maintaining user sessions and passing information between the client and the server. When the hostname differs, cookies may not work as expected, leading to issues such as failed authentication, improper session handling, and incorrect redirection.
- **End-to-End TLS/SSL Requirements**: If end-to-end TLS/SSL is required for secure communication between the proxy and the backend service, a matching TLS certificate for the original hostname is necessary. Using the same hostname simplifies the certificate management process and ensures that secure communication is established seamlessly.

You can avoid these problems if you adopt the same hostname for the service proxy and the backend web application. The backend application sees the same domain as the web browser, ensuring that session state, authentication, and URL handling are all functioning correctly. This technique is especially important in platform as a service (PaaS) offerings, where the complexity of certificate management can be reduced by utilizing the managed TLS certificates provided by the PaaS service. 

### Message Flow

The following diagram shows the steps for the message flow during deployment and runtime.

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-https-detail.png" alt-text="Details of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTPS.":::

#### Deployment workflow

The following steps describe the deployment process. This workflow corresponds to the green numbers in the preceding diagram.

1. A security engineer generates a certificate for the custom domain that the workload uses, and saves it in an Azure key vault. You can obtain a valid certificate from a well-known [certification authority (CA)](https://en.wikipedia.org/wiki/Certificate_authority).
2. A platform engineer specifies the necessary information in the *main.bicepparams* Bicep parameters file and deploys the Bicep templates to create the Azure resources. The necessary information includes:
   - A prefix for the Azure resources.
   - The name and resource group of the existing Azure Key Vault that holds the TLS certificate for the workload hostname and the Azure Front Door custom domain.
   - The name of the certificate in the key vault.
   - The name and resource group of the DNS zone that's used to resolve the Azure Front Door custom domain.
3. You can configure the [deployment script][azure-deployment-script] to install the following packages to your AKS cluster. For more information, check the parameters section of the Bicep module:
   - [Prometheus][prometheus] and [Grafana][grafana] using the [Prometheus Community Kubernetes Helm Charts](https://prometheus-community.github.io/helm-charts/). By default, this sample configuration does not install Prometheus and Grafana to the AKS cluster, and rather installs [Azure Managed Prometheus][azure-prometheus] and [Azure Managed Grafana][azure-grafana].
   - [cert-manager](https://cert-manager.io/docs/). Certificate Manager is not necessary in this sample as both the Application Gateway and NGINX Ingress Controller use a pre-uploaded TLS certificate from Azure Key Vault.
   - [NGINX Ingress Controller][nginx] via a Helm chart. If you use the [managed NGINX ingress controller with the application routing add-on][aks-app-routing-addon], you don't need to install another instance of the NGINX Ingress Controller via Helm.
4. The Application Gateway Listener retrieves the TLS certificate from Azure key Vault.
5. The [Kubernetes ingress][kubernetes-ingress] object utilizes the certificate obtained from the [Azure Key Vault provider for Secrets Store CSI Driver][azure-kv-csi-driver] to expose the Yelb UI service via HTTPS.

#### Runtime workflow

The following steps describe the message flow for a request that an external client application initiates during runtime. This workflow corresponds to the orange numbers in the preceding diagram.

1. The client application calls the sample web application using its hostname. The DNS zone associated with the custom domain of the Application Gateway Listener uses an A record to resolve the DNS query with the addres of the Azure Public IP used by the Frontend IP Configuration of the Application Gateway.
2. The request is sent to the Azure Public IP used by the Frontend IP Configuration of the Application Gateway.
3. The Application Gateway performs thw following actions.
   - The Application Gateway handles TLS termination and communicates with the backend application over HTTPS.
   - The Application Gateway Listener utilizes an SSL certificate obtained from [Azure Key Vault][azure-kv].
   - The Azure WAF Policy associated to the Listener is used to run OWASP rules and custom rules against the incoming request and block malicious attacks.
   - The Application Gateway Backend HTTP Settings are configured to invoke the sample web application via HTTPS on port 443.
4. The Application Gateway Backend Pool calls the NGINX ingress controller through the AKS internal load balancer using HTTPS.
5. The request is sent to one of the agent nodes that hosts a pod of the NGINX ingress controller.
6. One of the NGINX ingress controller replicas handles the request and sends the request to one of the service endpoints of the `yelb-ui` service.
7. The `yelb-ui` calls the `yelb-appserver` service.
8. The `yelb-appserver` calls the `yelb-db` and `yelb-cache` services.

## Deployment

By default, Bicep templates install the AKS cluster with the [Azure CNI Overlay](/azure/aks/azure-cni-overlay) network plugin and the [Cilium](/azure/aks/azure-cni-powered-by-cilium) data plane. However, Bicep templates are parametric, so you can choose any network plugin.

- [Azure CNI with static IP allocation](/azure/aks/configure-azure-cni)
- [Azure CNI with dynamic IP allocation](/azure/aks/configure-azure-cni-dynamic-ip-allocation)
- [Azure CNI Powered by Cilium](/azure/aks/azure-cni-powered-by-cilium)
- [Azure CNI Overlay](/azure/aks/azure-cni-overlay)
- [BYO CNI](/azure/aks/use-byo-cni?tabs=azure-cli)
- [Kubenet](/azure/aks/configure-kubenet)

In addition, the project shows how to deploy an [Azure Kubernetes Service][aks] cluster with the following extensions and features:

- [Microsoft Entra Workload ID][aks-workload-id] uses [Service Account Token Volume Projection][token-projection], specifically a service account, to enable pods to use a Kubernetes identity. A Kubernetes token is issued and [OIDC federation][oidc-federation] enables Kubernetes applications to access Azure resources securely with Microsoft Entra ID, based on annotated service accounts.
- [Istio-based service mesh add-on for Azure Kubernetes Service](/azure/aks/istio-about) provides an officially supported and tested [Istio](https://istio.io/v1.1/docs/concepts/what-is-istio/) integration for Azure Kubernetes Service (AKS).
- [API Server VNET Integration](/azure/aks/api-server-vnet-integration) allows you to enable network communication between the API server and the cluster nodes without requiring a private link or tunnel. AKS clusters with API Server VNET integration provide a series of advantages, for example, they can have public network access or private cluster mode enabled or disabled without redeploying the cluster. For more information, see [Create an Azure Kubernetes Service cluster with API Server VNet Integration](/azure/aks/api-server-vnet-integration).
- [Azure NAT Gateway](/azure/virtual-network/nat-gateway/nat-overview) to manage outbound connections initiated by AKS-hosted workloads.
- [Event-driven Autoscaling (KEDA) add-on](/azure/aks/keda-about) is a single-purpose and lightweight component that strives to make application autoscaling simple and is a CNCF Incubation project.
- [Dapr extension for Azure Kubernetes Service (AKS)](/azure/aks/dapr) allows you to install [Dapr](https://dapr.io/), a portable, event-driven runtime that simplifies building resilient, stateless, and stateful applications that run on the cloud and edge and embrace the diversity of languages and developer frameworks. With its sidecar architecture, Dapr helps you tackle the challenges that come with building microservices and keeps your code platform agnostic.
- [Flux V2 extension](/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2?tabs=azure-cli) allows to deploy workloads to an Azure Kubernetes Service (AKS) cluster via [GitOps](https://www.weave.works/technologies/gitops/). For more information, see [GitOps Flux v2 configurations with AKS and Azure Arc-enabled Kubernetes](/azure/azure-arc/kubernetes/conceptual-gitops-flux2)
- [Vertical Pod Autoscaling](/azure/aks/vertical-pod-autoscaler) allows you to automatically sets resource requests and limits on containers per workload based on past usage. VPA makes certain pods are scheduled onto nodes that have the required CPU and memory resources. For more information, see [Kubernetes Vertical Pod Autoscaling](https://itnext.io/k8s-vertical-pod-autoscaling-fd9e602cbf81).
- [Azure Key Vault Provider for Secrets Store CSI Driver](/azure/aks/csi-secrets-store-identity-access) provides a variety of methods of identity-based access to your [Azure Key Vault][azure-kv]. The `keyVault.bicep` module [Key Vault Administrator](/azure/key-vault/general/rbac-guide?tabs=azure-cli#azure-built-in-roles-for-key-vault-data-plane-operations) role to the user-assigned managed identity of the addon to let it retrieve the certificate used by [Kubernetes Ingress][kubernetes-ingress] used to expose the `yelb-ui` service via the [NGINX ingress controller][nginx].
- [Image Cleaner](/azure/aks/image-cleaner?tabs=azure-cli) to clean up stale images on your Azure Kubernetes Service cluster.
- [Azure Kubernetes Service (AKS) Network Observability](/azure/aks/network-observability-overview) is an important part of maintaining a healthy and performant Kubernetes cluster. By collecting and analyzing data about network traffic, you can gain insights into how your cluster is operating and identify potential problems before they cause outages or performance degradation.
- [Managed NGINX ingress with the application routing add-on][aks-app-routing-addon].

In a production environment, we strongly recommend deploying a [private AKS cluster](/azure/aks/private-clusters) with [Uptime SLA](/azure/aks/uptime-sla). For more information, see [private AKS cluster with a Public DNS address](/azure/aks/private-clusters#create-a-private-aks-cluster-with-a-public-dns-address). Alternatively, you can deploy a public AKS cluster and secure access to the API server using [authorized IP address ranges](/azure/aks/api-server-authorized-ip-ranges).

### Azure Resources

The Bicep templates deploy or use the following Azure resources:

| Resource | Type | Description |
|----------|------|-------------|
| [Azure Kubernetes Service(AKS)][aks] | [Microsoft.ContainerService/managedClusters](/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep) | A public or private AKS cluster composed of a `system` node pool in a dedicated subnet that hosts only critical system pods and services, and a `user` node pool hosting user workloads and artifacts in a dedicated subnet. |
| [Azure Application Gateway][azure-ag] | [Microsoft.Network/applicationGateways](/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep) | A fully managed regional layer 7 load balancer and service proxy used to expose AKS-hosted workloads such as the Yelb application. |
|[Azure Web Application Firewall (WAF)](/azure/web-application-firewall/ag/ag-overview)|[Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies](/azure/templates/microsoft.network/applicationgatewaywebapplicationfirewallpolicies?pivots=deployment-language-bicep)| A fully managed web access firewall used to provide centralized protection for AKS-hosted web applications exposed via the Azure Application Gateway. |
| [Grafana Admin Role Assignment](/azure/managed-grafana/how-to-share-grafana-workspace?tabs=azure-portal) | [Microsoft.Authorization/roleDefinitions](/azure/templates/microsoft.authorization/roleassignments?pivots=deployment-language-bicep) | A `Grafana Admin` role assignment on the Azure Managed Grafana for the Microsoft Entra ID user whose objectID is defined in the `userId` parameter. |
| [Key Vault Administrator Role Assignment][azure-kv-csi-driver] | [Microsoft.Authorization/roleDefinitions](/azure/templates/microsoft.authorization/roleassignments?pivots=deployment-language-bicep) | A `Key Vault Administrator` role assignment on the existing Azure Key Vault resource which contains the TLS certificate for the user-defined managed identity used by the Azure Key Vault provider for Secrets Store CSI Driver. |
| [Azure DNS Zone](/azure/dns/private-dns-overview) | [Microsoft.Network/dnsZones](/azure/templates/microsoft.network/dnszones?pivots=deployment-language-bicep) | An existing Azure DNS zone used for the name resolution of AKS-hosted workloads. This resource is optional. |
| [Virtual Network](/azure/virtual-network/virtual-networks-overview) | [Microsoft.Network/virtualNetworks](/azure/templates/microsoft.network/virtualnetworks) | A new virtual network with multiple subnets for different purposes: `SystemSubnet`is used for the agent nodes of the `system` node pool, `UserSubnet` is used for the agent nodes of the `user` node pool, `ApiServerSubnet` is used by API Server VNET Integration, `AzureBastionSubnet` is used by Azure Bastion Host, `VmSubnet` is used for a jump-box virtual machine used to connect to the (private) AKS cluster and for Azure Private Endpoints, `AppGatewaySubnet` hosts the Application Gateway. |
| [User-Assigned Managed Identity](/azure/active-directory/managed-identities-azure-resources/overview) | [Microsoft.ManagedIdentity/userAssignedIdentities](/azure/templates/microsoft.managedidentity/2018-11-30/userassignedidentities?pivots=deployment-language-bicep) | A user-defined managed identity used by the AKS cluster to create more resources in Azure. |
| [Virtual Machine](/azure/virtual-machines/windows/) | [Microsoft.Compute/virtualMachines](/azure/templates/microsoft.compute/virtualmachines) | A jump-box virtual machine used to manage the private AKS cluster. |
| [Azure Bastion][azure-bastion] | [Microsoft.Network/bastionHosts](/azure/templates/microsoft.network/bastionhosts) | An Azure Bastion deployed in the AKS cluster virtual network to provide SSH connectivity to agent nodes and virtual machines. |
| [Storage Account](/azure/storage/common/storage-account-overview) | [Microsoft.Storage/storageAccounts](/azure/templates/microsoft.storage/storageaccounts) | A storage account used to store the boot diagnostics logs of the jumpbox virtual machine. |
| [Azure Container Registry][azure-cr] | [Microsoft.ContainerRegistry/registries](/azure/templates/microsoft.containerregistry/registries?pivots=deployment-language-bicep) | An Azure Container Registry to build, store, and manage container images and artifacts in a private registry. This resource is not required to deploy the `Yelb` application as the sample uses public container images. |
| [Azure Key Vault](/azure/key-vault/general/basic-concepts) | [Microsoft.KeyVault/vaults](/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-bicep) | An existing Azure Key Vault used to store secrets, certificates, and keys. |
| [Azure Private Endpoint](/azure/private-link/private-endpoint-overview)| [Microsoft.Network/privateEndpoints](/azure/templates/microsoft.network/privateendpoints) | Azure Private Endpoints for Azure Container Registry, Azure Key Vault, and Azure Storage Account. |
| [Azure Private DNS Zone](/azure/dns/private-dns-overview) | [Microsoft.Network/privateDnsZones](/azure/templates/microsoft.network/privatednszones) |  Azure Private DNS Zones are used for the DNS resolution of the Azure Private Endpoints for Azure Container Registry, Azure Key Vault, Azure Storage Account, API Server when deploying a private AKS cluster. |
| [Azure Network Security Group](/azure/virtual-network/network-security-groups-overview) | [Microsoft.Network/networkSecurityGroups](/azure/templates/microsoft.network/networksecuritygroups?tabs=bicep) | Azure Network Security Groups used to filter inbound and outbound traffic for subnets hosting virtual machines. |
| [Azure Monitor Workspace][azure-prometheus] | [Microsoft.Monitor/accounts][azure-prometheus] | This is an [Azure Monitor workspace][azure-prometheus] to store Prometheus metrics generated by the AKS cluster and workloads. You can [Prometheus query language (PromQL)](https://aka.ms/azureprometheus-promio-promql) to analyze and alert on the performance of monitored infrastructure and workloads without having to operate the underlying infrastructure. The primary method for visualizing Prometheus metrics is [Azure Managed Grafana][azure-grafana]. |
| [Azure Managed Grafana][azure-grafana] | [Microsoft.Dashboard/grafana](/azure/templates/microsoft.dashboard/grafana?pivots=deployment-language-bicep) | an [Azure Managed Grafana][azure-grafana] instance used to visualize the [Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-enable?tabs=azure-portal) generated by the [Azure Kubernetes Service(AKS)][aks] cluster. [Azure Managed Grafana][azure-grafana] provides a set of built-in dashboards to visualize Prometheus metrics generated by your AKS cluster and workloads. |
| [Azure Log Analytics Workspace][azure-la] | [Microsoft.OperationalInsights/workspaces](/azure/templates/microsoft.operationalinsights/workspaces) | A centralized Azure Log Analytics workspace used to collect diagnostics logs and metrics from various Azure resources. |
| [Deployment Script][azure-deployment-script] | [Microsoft.Resources/deploymentScripts](/azure/templates/microsoft.resources/deploymentscripts?pivots=deployment-language-bicep) | A deployment script is utilized to run the `install-packages.sh` Bash script, which can optionally install the [NGINX Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/), [Cert-Manager](https://cert-manager.io/docs/), [Prometheus][prometheus], and [Grafana](https://grafana.com) to the AKS cluster using [Helm](https://helm.sh/). However, the in-cluster Prometheus and Grafana instances are not necessary as the Bicep templates install [Azure Managed Prometheus][azure-prometheus] and [Azure Managed Grafana][azure-grafana] to collect and monitor AKS Prometheus metrics. For more details on deployment scripts, refer to the [Use deployment scripts in Bicep][azure-deployment-script] documentation.|

## Deploy the Bicep templates

You can deploy the [Bicep templates][bicep-dir] in the companion [sample][azure-sample] using the `deploy.sh` Bash script. Specify a value for the following parameters in the `deploy.sh` script and `main.https.nginxviaaddon.bicepparam` parameters file before deploying the Bicep templates.

- `prefix`: specifies a prefix for all the Azure resources.
- `authenticationType`: specifies the type of authentication when accessing the Virtual Machine. `sshPublicKey` is the recommended value. Allowed values: `sshPublicKey` and `password`.
- `vmAdminUsername`: specifies the name of the administrator account of the virtual machine.
- `vmAdminPasswordOrKey`: specifies the SSH Key or password for the virtual machine.
- `aksClusterSshPublicKey`:  specifies the SSH Key or password for AKS cluster agent nodes.
- `aadProfileAdminGroupObjectIDs`: when creating an an AKS cluster with [Microsoft Entra ID](/en-us/azure/aks/azure-ad-integration-cli) and [Azure RBAC](/azure/aks/azure-ad-rbac) integration, this array parameter contains the list of Microsoft Entra ID group object IDs that have the admin role of the cluster.

This is the full list of the parameters.

| Name                                      | Type                   | Description      |
|-------------------------------------------|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `prefix`                                  | `string`                 | Specifies the name prefix for all the Azure resources.                 |
| `location`                                | `string`                 | Specifies the location for all the Azure resources.                    |
| `userId`                                  | `string`                 | Specifies the object id of an Azure Active Directory user.             |
| `letterCaseType`                          | `string`                 | Specifies whether name resources are in CamelCase, UpperCamelCase, or KebabCase.            |
| `createMetricAlerts`                      | `bool`                   | Specifies whether creating metric alerts or not.                       |
| `metricAlertsEnabled`                     | `bool`                   | Specifies whether metric alerts as either enabled or disabled.         |
| `metricAlertsEvalFrequency`               | `string`                 | Specifies metric alerts eval frequency.                               |
| `metricAlertsWindowsSize`                 | `string`                 | Specifies metric alerts window size.                                  |
| `aksClusterDnsPrefix`                     | `string`                 | Specifies the DNS prefix specified when creating the managed cluster. |
| `aksClusterNetworkPlugin`                 | `string`                 | Specifies the network plugin used for building Kubernetes network. - azure or kubenet.      |
| `aksClusterNetworkPluginMode`             | `string`                 | Specifies the Network plugin mode used for building the Kubernetes network.                 |
| `aksClusterNetworkPolicy`                 | `string`                 | Specifies the network policy used for building Kubernetes network. - calico or azure       |
| `aksClusterNetworkDataplane`              | `string`                 | Specifies the network dataplane used in the Kubernetes cluster..      |
| `aksClusterNetworkMode`                   | `string`                 | Specifies the network mode. This cannot be specified if networkPlugin is anything other than azure.|
| `aksClusterPodCidr`                       | `string`                 | Specifies the CIDR notation IP range from which to assign pod IPs when kubenet is used.     |
| `aksClusterServiceCidr`                   | `string`                 | A CIDR notation IP range from which to assign service cluster IPs. It must not overlap with any Subnet IP ranges.                                       |
| `aksClusterDnsServiceIP`                  | `string`                 | Specifies the IP address assigned to the Kubernetes DNS service. It must be within the Kubernetes service address range specified in serviceCidr.       |
| `aksClusterLoadBalancerSku`               | `string`                 | Specifies the sku of the load balancer used by the virtual machine scale sets used by nodepools.   |
| `loadBalancerBackendPoolType`             | `string`                 | Specifies the type of the managed inbound Load Balancer BackendPool.  |
| `advancedNetworking`                      | `object`                 | Specifies Advanced Networking profile for enabling observability on a cluster. Enabling advanced networking features may incur extra costs. |
| `aksClusterIpFamilies`                    | `array`                  | Specifies the IP families are used to determine single-stack or dual-stack clusters. For single-stack, the expected value is IPv4. For dual-stack, the expected values are IPv4 and IPv6. |
| `aksClusterOutboundType`                  | `string`                 | Specifies outbound (egress) routing method. - loadBalancer or userDefinedRouting.           |
| `aksClusterSkuTier`                       | `string`                 | Specifies the tier of a managed cluster SKU: Paid or Free              |
| `aksClusterKubernetesVersion`             | `string`                 | Specifies the version of Kubernetes specified when creating the managed cluster.           |
| `aksClusterAdminUsername`                 | `string`                 | Specifies the administrator username of Linux virtual machines.        |
| `aksClusterSshPublicKey`                  | `string`                 | Specifies the SSH RSA public key string for the Linux nodes.           |
| `aadProfileTenantId`                      | `string`                 | Specifies the tenant id of the Azure Active Directory used by the AKS cluster for authentication.  |
| `aadProfileAdminGroupObjectIDs`           | `array`                  | Specifies the Microsoft Entra ID group object IDs that have admin role of the cluster.                |
| `aksClusterNodeOSUpgradeChannel`          | `string`                 | Specifies the node OS upgrade channel. The default is Unmanaged, but may change to either NodeImage or SecurityPatch at GA. .                             |
| `aksClusterUpgradeChannel`                | `string`                 | Specifies the upgrade channel for auto upgrade. Allowed values include rapid, stable, patch, node-image, none.                                          |
| `aksClusterEnablePrivateCluster`          | `bool`                   | Specifies whether to create the cluster as a private cluster or not.  |
| `aksClusterWebAppRoutingEnabled`          | `bool`                   | Specifies whether the managed NGINX Ingress Controller application routing addon is enabled.|
| `aksClusterNginxDefaultIngressControllerType` | `string`             | Specifies the ingress type for the default NginxIngressController custom resource for the managed NGINX ingress controller. |
| `aksPrivateDNSZone`                       | `string`                 | Specifies the Private DNS Zone mode for private cluster. When the value is equal to None, a Public DNS Zone is used in place of a Private DNS Zone       |
| `aksEnablePrivateClusterPublicFQDN`       | `bool`                   | Specifies whether to create public FQDN for private cluster or not.            |
| `aadProfileManaged`                       | `bool`                   | Specifies whether to enable managed AAD integration.                  |
| `aadProfileEnableAzureRBAC`               | `bool`                   | Specifies whether to enable Azure RBAC for Kubernetes authorization.  |
| `systemAgentPoolName`                     | `string`                 | Specifies the unique name of of the system node pool profile in the context of the subscription and resource group.                                     |
| `systemAgentPoolVmSize`                   | `string`                 | Specifies the vm size of nodes in the system node pool.               |
| `systemAgentPoolOsDiskSizeGB`             | `int`                    | Specifies the OS Disk Size in GB to be used to specify the disk size for every machine in the system agent pool. |
| `systemAgentPoolOsDiskType`               | `string`                 | Specifies the OS disk type to be used for machines in a given agent pool. |
| `systemAgentPoolAgentCount`               | `int`                    | Specifies the number of agents (VMs) to host docker containers in the system node pool. Allowed values must be in the range of 1 to 100 (inclusive). The default value is 1.  |
| `systemAgentPoolOsType`                   | `string`                 | Specifies the OS type for the vms in the system node pool. Choose from Linux and Windows. Default to Linux.                                             |
| `systemAgentPoolOsSKU`                    | `string`                 | Specifies the OS SKU used by the system agent pool. If not specified, the default is Ubuntu if OSType=Linux or Windows2019 if OSType=Windows. |
| `systemAgentPoolMaxPods`                  | `int`                    | Specifies the maximum number of pods that can run on a node in the system node pool. The maximum number of pods per node in an AKS cluster is 250. |
| `systemAgentPoolMaxCount`                 | `int`                    | Specifies the maximum number of nodes for autoscaling for the system node pool.            |
| `systemAgentPoolMinCount`                 | `int`                    | Specifies the minimum number of nodes for autoscaling for the system node pool.            |
| `systemAgentPoolEnableAutoScaling`        | `bool`                   | Specifies whether to enable autoscaling for the system node pool.    |
| `systemAgentPoolScaleSetPriority`         | `string`                 | Specifies the virtual machine scale set priority in the system node pool: Spot or Regular. |
| `systemAgentPoolScaleSetEvictionPolicy`   | `string`                 | Specifies the ScaleSetEvictionPolicy to be used to specify eviction policy for spot virtual machine scale set. Default to Delete. Allowed values are Delete or Deallocate.      |
| `systemAgentPoolNodeLabels`               | `object`                 | Specifies the Agent pool node labels to be persisted across all nodes in the system node pool.     |
| `systemAgentPoolNodeTaints`               | `array`                  | Specifies the taints added to new nodes during node pool create and scale. For example, key=value:NoSchedule.                                           |
| `systemAgentPoolKubeletDiskType`          | `string`                 | Determines the placement of emptyDir volumes, container runtime data root, and Kubelet ephemeral storage.                                              |
| `systemAgentPoolType`                     | `string`                 | Specifies the type for the system node pool: VirtualMachineScaleSets or AvailabilitySet    |
| `systemAgentPoolAvailabilityZones`        | `array`                  | Specifies the availability zones for the agent nodes in the system node pool. Requirese the use of VirtualMachineScaleSets as node pool type.           |
| `userAgentPoolName`                       | `string`                 | Specifies the unique name of of the user node pool profile in the context of the subscription and resource group.                                       |
| `userAgentPoolVmSize`                     | `string`                 | Specifies the vm size of nodes in the user node pool.                 |
| `userAgentPoolOsDiskSizeGB`               | `int`                    | Specifies the OS Disk Size in GB to be used to specify the disk size for every machine in the system agent pool.                                |
| `userAgentPoolOsDiskType`                 | `string`                 | Specifies the OS disk type to be used for machines in a given agent pool. |
| `userAgentPoolAgentCount`                 | `int`                    | Specifies the number of agents (VMs) to host docker containers in the user node pool. Allowed values must be in the range of 1 to 100 (inclusive). The default value is 1.     |
| `userAgentPoolOsType`                     | `string`                 | Specifies the OS type for the vms in the user node pool. Choose from Linux and Windows. Default to Linux.                                                |
| `userAgentPoolOsSKU`                      | `string`                 | Specifies the OS SKU used by the system agent pool. If not specified, the default is Ubuntu if OSType=Linux or Windows2019 if OSType=Windows. |
| `userAgentPoolMaxPods`                    | `int`                    | Specifies the maximum number of pods that can run on a node in the user node pool. |
| `userAgentPoolMaxCount`                   | `int`                    | Specifies the maximum number of nodes for autoscaling for the user node pool.              |
| `userAgentPoolMinCount`                   | `int`                    | Specifies the minimum number of nodes for autoscaling for the user node pool.              |
| `userAgentPoolEnableAutoScaling`          | `bool`                   | Specifies whether to enable autoscaling for the user node pool.      |
| `userAgentPoolScaleSetPriority`           | `string`                 | Specifies the virtual machine scale set priority in the user node pool: Spot or Regular.   |
| `userAgentPoolScaleSetEvictionPolicy`     | `string`                 | Specifies the ScaleSetEvictionPolicy to be used to specify eviction policy for spot virtual machine scale set. Default to Delete. Allowed values are Delete or Deallocate.      |
| `userAgentPoolNodeLabels`                 | `object`                 | Specifies the Agent pool node labels to be persisted across all nodes in the user node pool.|
| `userAgentPoolNodeTaints`                 | `array`                  | Specifies the taints added to new nodes during node pool create and scale. For example, key=value:NoSchedule.                                           |
| `userAgentPoolKubeletDiskType`            | `string`                 | Determines the placement of emptyDir volumes, container runtime data root, and Kubelet ephemeral storage.                                              |
| `userAgentPoolType`                       | `string`                 | Specifies the type for the user node pool: VirtualMachineScaleSets or AvailabilitySet      |
| `userAgentPoolAvailabilityZones`          | `array`                  | Specifies the availability zones for the agent nodes in the user node pool. Requirese the use of VirtualMachineScaleSets as node pool type.             |
| `httpApplicationRoutingEnabled`           | `bool`                   | Specifies whether the httpApplicationRouting add-on is enabled or not.                     |
| `istioServiceMeshEnabled`                 | `bool`                   | Specifies whether the Istio Service Mesh add-on is enabled or not.   |
| `istioIngressGatewayEnabled`              | `bool`                   | Specifies whether the Istio Ingress Gateway is enabled or not.        |
| `istioIngressGatewayType`                 | `string`                 | Specifies the type of the Istio Ingress Gateway.                      |
| `kedaEnabled`                             | `bool`                   | Specifies whether the Kubernetes Event-Driven Autoscaler (KEDA) add-on is enabled or not.  |
| `daprEnabled`                             | `bool`                   | Specifies whether the Dapr extension is enabled or not.              |
| `daprHaEnabled`                           | `bool`                   | Enable high availability (HA) mode for the Dapr control plane         |
| `fluxGitOpsEnabled`                       | `bool`                   | Specifies whether the Flux V2 extension is enabled or not.            |
| `verticalPodAutoscalerEnabled`            | `bool`                   | Specifies whether the Vertical Pod Autoscaler is enabled or not.     |
| `aciConnectorLinuxEnabled`                | `bool`                   | Specifies whether the aciConnectorLinux add-on is enabled or not.     |
| `azurePolicyEnabled`                      | `bool`                   | Specifies whether the azurepolicy add-on is enabled or not.           |
| `azureKeyvaultSecretsProviderEnabled`     | `bool`                   | Specifies whether the Azure Key Vault Provider for Secrets Store CSI Driver addon is enabled or not.                                                    |
| `kubeDashboardEnabled`                    | `bool`                   | Specifies whether the kubeDashboard add-on is enabled or not.         |
| `podIdentityProfileEnabled`               | `bool`                   | Specifies whether the pod identity addon is enabled..                 |
| `autoScalerProfileScanInterval`           | `string`                 | Specifies the scan interval of the autoscaler of the AKS cluster.   |
| `autoScalerProfileScaleDownDelayAfterAdd` | `string`                 | Specifies the scale down delay after add of the autoscaler of the AKS cluster.            |
| `autoScalerProfileScaleDownDelayAfterDelete` | `string`               | Specifies the scale down delay after delete of the autoscaler of the AKS cluster.         |
| `autoScalerProfileScaleDownDelayAfterFailure` | `string`               | Specifies scale down delay after failure of the autoscaler of the AKS cluster.           |
| `autoScalerProfileScaleDownUnneededTime`  | `string`                 | Specifies the scale down unneeded time of the autoscaler of the AKS cluster.              |
| `autoScalerProfileScaleDownUnreadyTime`   | `string`                 | Specifies the scale down unready time of the autoscaler of the AKS cluster.               |
| `autoScalerProfileUtilizationThreshold`   | `string`                 | Specifies the utilization threshold of the autoscaler of the AKS cluster.                 |
| `autoScalerProfileMaxGracefulTerminationSec` | `string` | Specifies the max graceful termination time interval in seconds for the autoscaler of the AKS cluster.       |
| `enableVnetIntegration`                    | `bool`    | Specifies whether to enable API server VNET integration for the cluster or not.                                |
| `virtualNetworkName`                       | `string` | Specifies the name of the virtual network.            |
| `virtualNetworkAddressPrefixes`            | `string` | Specifies the address prefixes of the virtual network.                                                         |
| `systemAgentPoolSubnetName`                | `string` | Specifies the name of the subnet hosting the worker nodes of the default system agent pool of the AKS cluster. |
| `systemAgentPoolSubnetAddressPrefix`       | `string` | Specifies the address prefix of the subnet hosting the worker nodes of the default system agent pool of the AKS cluster. |
| `userAgentPoolSubnetName`                  | `string` | Specifies the name of the subnet hosting the worker nodes of the user agent pool of the AKS cluster.           |
| `userAgentPoolSubnetAddressPrefix`         | `string` | Specifies the address prefix of the subnet hosting the worker nodes of the user agent pool of the AKS cluster.  |
| `applicationGatewaySubnetName`             | `string` | Specifies the name of the subnet which contains the Application Gateway.                                       |
| `applicationGatewaySubnetAddressPrefix`    | `string` | Specifies the address prefix of the subnet which contains the Application Gateway.                              |
| `blobCSIDriverEnabled`                     | `bool`    | Specifies whether to enable the Azure Blob CSI Driver. The default value is false.                              |
| `diskCSIDriverEnabled`                     | `bool`    | Specifies whether to enable the Azure Disk CSI Driver. The default value is true.                               |
| `fileCSIDriverEnabled`                     | `bool`    | Specifies whether to enable the Azure File CSI Driver. The default value is true.                               |
| `snapshotControllerEnabled`                | `bool`    | Specifies whether to enable the Snapshot Controller. The default value is true.                                 |
| `defenderSecurityMonitoringEnabled`        | `bool`    | Specifies whether to enable Defender threat detection. The default value is false.                              |
| `imageCleanerEnabled`                      | `bool`    | Specifies whether to enable ImageCleaner on AKS cluster. The default value is false.                           |
| `imageCleanerIntervalHours`                | `int`     | Specifies whether ImageCleaner scanning interval in hours.                                                     |
| `nodeRestrictionEnabled`                   | `bool`    | Specifies whether to enable Node Restriction. The default value is false.                                       |
| `workloadIdentityEnabled`                  | `bool`    | Specifies whether to enable Workload Identity. The default value is false.                                      |
| `oidcIssuerProfileEnabled`                 | `bool`    | Specifies whether the OIDC issuer is enabled.        |
| `podSubnetName`                            | `string` | Specifies the name of the subnet hosting the pods running in the AKS cluster.                                  |
| `podSubnetAddressPrefix`                   | `string` | Specifies the address prefix of the subnet hosting the pods running in the AKS cluster.                         |
| `apiServerSubnetName`                      | `string` | Specifies the name of the subnet delegated to the API server when configuring the AKS cluster to use API server VNET integration. |
| `apiServerSubnetAddressPrefix`             | `string` | Specifies the address prefix of the subnet delegated to the API server when configuring the AKS cluster to use API server VNET integration. |
| `vmSubnetName`                             | `string` | Specifies the name of the subnet which contains the virtual machine.                                            |
| `vmSubnetAddressPrefix`                    | `string` | Specifies the address prefix of the subnet which contains the virtual machine.                                   |
| `bastionSubnetAddressPrefix`               | `string` | Specifies the Bastion subnet IP prefix. This prefix must be within vnet IP prefix address space.                |
| `logAnalyticsWorkspaceName`                | `string` | Specifies the name of the Log Analytics Workspace.   |
| `logAnalyticsSku`                          | `string` | Specifies the service tier of the workspace: Free, Standalone, PerNode, Per-GB.                                |
| `logAnalyticsRetentionInDays`              | `int`     | Specifies the workspace data retention in days. -1 means Unlimited retention for the Unlimited Sku. 730 days is the maximum allowed for all other Skus. |
| `vmEnabled`                                | `bool`    | Specifies whether creating or not a jumpbox virtual machine in the AKS cluster virtual network.                |
| `vmName`                                   | `string` | Specifies the name of the virtual machine.           |
| `vmSize`                                   | `string` | Specifies the size of the virtual machine.           |
| `imagePublisher`                           | `string` | Specifies the image publisher of the disk image used to create the virtual machine.                             |
| `imageOffer`                               | `string` | Specifies the offer of the platform image or marketplace image used to create the virtual machine.              |
| `imageSku`                                 | `string` | Specifies the Ubuntu version for the VM. This picks a fully patched image of this given Ubuntu version.    |
| `authenticationType`                       | `string` | Specifies the type of authentication when accessing the Virtual Machine. SSH key is recommended.               |
| `vmAdminUsername`                          | `string` | Specifies the name of the administrator account of the virtual machine.                                         |
| `vmAdminPasswordOrKey`                     | `string` | Specifies the SSH Key or password for the virtual machine. SSH key is recommended.                              |
| `diskStorageAccountType`                   | `string` | Specifies the storage account type for OS and data disk.                                                       |
| `numDataDisks`                             | `int`     | Specifies the number of data disks of the virtual machine.                                                     |
| `osDiskSize`                               | `int`     | Specifies the size in GB of the OS disk of the VM.   |
| `dataDiskSize`                             | `int`     | Specifies the size in GB of the OS disk of the virtual machine.                                                |
| `dataDiskCaching`                          | `string` | Specifies the caching requirements for the data disks.                                                         |
| `blobStorageAccountName`                   | `string` | Specifies the globally unique name for the storage account used to store the boot diagnostics logs of the virtual machine. |
| `blobStorageAccountPrivateEndpointName`     | `string` | Specifies the name of the private link to the boot diagnostics storage account.                                |
| `acrPrivateEndpointName`                   | `string` | Specifies the name of the private link to the Azure Container Registry.                                        |
| `acrName`                                  | `string` | Name of your Azure Container Registry                 |
| `acrAdminUserEnabled`                      | `bool`    | Enable admin user that have push / pull permission to the registry.                                             |
| `acrSku`                                   | `string` | Tier of your Azure Container Registry.               |
| `acrPublicNetworkAccess`                   | `string` | Whether to allow public network access. Defaults to Enabled.                                                   |
| `acrAnonymousPullEnabled`                  | `bool`    | Specifies whether or not registry-wide pull is enabled from unauthenticated clients.                           |
| `acrDataEndpointEnabled`                   | `bool`    | Specifies whether or not a single data endpoint is enabled per region for serving data.                         |
| `acrNetworkRuleSet`                        | `object`  | Specifies the network rule set for the container registry.                                                     |
| `acrNetworkRuleBypassOptions`              | `string` | Specifies ehether to allow trusted Azure services to access a network restricted registry.                     |
| `acrZoneRedundancy`                        | `string` | Specifies whether or not zone redundancy is enabled for this container registry.                               |
| `bastionHostEnabled`                       | `bool`    | Specifies whether Azure Bastion should be created.   |
| `bastionHostName`                          | `string` | Specifies the name of the Azure Bastion resource.    |
| `applicationGatewayName`                   | `string` | Specifies the name of the Application Gateway.       |
| `applicationGatewaySkuName`                | `string` | Specifies the sku of the Application Gateway.        |
| `applicationGatewayPrivateIpAddress`        | `string` | Specifies the private IP address of the Application Gateway.                                                   |
| `applicationGatewayFrontendIpConfigurationType` | `string` | Specifies the frontend IP configuration type.        |
| `applicationGatewayPublicIpAddressName`     | `string` | Specifies the name of the public IP adddress used by the Application Gateway.                                  |
| `applicationGatewayAvailabilityZones`      | `array`   | Specifies the availability zones of the Application Gateway.                                                   |
| `applicationGatewayMinCapacity`            | `int`     | Specifies the lower bound on number of Application Gateway capacity.                                           |
| `applicationGatewayMaxCapacity`            | `int`     | Specifies the upper bound on number of Application Gateway capacity.                                           |
| `backendAddressPoolName`                   | `string` | Specifies the backend address pool name of the Application Gateway                                             |
| `trustedRootCertificates`                  | `array`   | Specifies an array containing trusted root certificates.                                                       |
| `probes`                                  | `array`   | Specifies an array containing custom probes.         |
| `requestRoutingRules`                       | `array`   | Specifies an array containing request routing rules.                                                           |
| `redirectConfigurations`                    | `array`   | Specifies an array containing redirect configurations.                                                         |
| `httpListeners`                            | `array`   | Specifies an array containing http listeners.        |
| `backendHttpSettings`                      | `array`   | `array` containing backend http settings               |
| `frontendPorts`                            | `array`   | Specifies an array containing frontend ports.        |
| `wafPolicyName`                            | `string` | Specifies the name of the WAF policy                 |
| `wafPolicyMode`                            | `string` | Specifies the mode of the WAF policy.                |
| `wafPolicyState`                           | `string` | Specifies the state of the WAF policy.               |
| `wafPolicyFileUploadLimitInMb`             | `int`     | Specifies the maximum file upload size in Mb for the WAF policy.                                               |
| `wafPolicyMaxRequestBodySizeInKb`          | `int`     | Specifies the maximum request body size in Kb for the WAF policy.                                              |
| `wafPolicyRequestBodyCheck`                | `bool`    | Specifies the whether to allow WAF to check request Body.                                                      |
| `wafPolicyRuleSetType`                     | `string` | Specifies the rule set type.                          |
| `wafPolicyRuleSetVersion`                  | `string` | Specifies the rule set version.                       |
| `natGatewayName`                            | `string` | Specifies the name of the Azure NAT Gateway.         |
| `natGatewayZones`                           | `array`   | Specifies a list of availability zones denoting the zone in which Nat Gateway should be deployed.              |
| `natGatewayPublicIps`                       | `int`     | Specifies the number of Public IPs to create for the Azure NAT Gateway.                                        |
| `natGatewayIdleTimeoutMins`                 | `int`     | Specifies the idle timeout in minutes for the Azure NAT Gateway.                                               |
| `keyVaultPrivateEndpointName`               | `string` | Specifies the name of the private link to the Key Vault.                                                       |
| `keyVaultName`                             | `string` | Specifies the name of an existing Key Vault resource holding the TLS certificate.                              |
| `keyVaultResourceGroupName`                 | `string` | Specifies the name of the resource group that contains the existing Key Vault resource.                        |
| `tags`                                     | `object`  | Specifies the resource tags.                          |
| `clusterTags`                              | `object`  | Specifies the resource tags.                          |
| `actionGroupName`                          | `string` | Specifies the name of the Action Group.               |
| `actionGroupShortName`                     | `string` | Specifies the short name of the action group.        |
| `actionGroupEnabled`                        | `bool`    | Specifies whether this action group is enabled. |
| `actionGroupEmailAddress`                    | `string` | Specifies the email address of the receiver.         |
| `actionGroupUseCommonAlertSchema`            | `bool`    | Specifies whether to use common alert schema.        |
| `actionGroupCountryCode`                   | `string` | Specifies the country code of the SMS receiver.      |
| `actionGroupPhoneNumber`                   | `string` | Specifies the phone number of the SMS receiver.      |
| `metricAnnotationsAllowList`               | `string` | Specifies a comma-separated list of additional Kubernetes label keys used in the resource labels metric. |
| `metricLabelsAllowlist`                     | `string` | Specifies a comma-separated list of Kubernetes annotations keys used in the resource labels metric. |
| `prometheusName`                           | `string` | Specifies the name of the Azure Monitor managed service for Prometheus resource.                                |
| `prometheusPublicNetworkAccess`            | `string` | Specifies whether or not public endpoint access is allowed for the Azure Monitor managed service for Prometheus resource.  |
| `grafanaName`                              | `string` | Specifies the name of the Azure Managed Grafana resource.                                                      |
| `grafanaSkuName`                           | `string` | Specifies the sku of the Azure Managed Grafana resource.                                                       |
| `grafanaApiKey`                            | `string` | Specifies the api key setting of the Azure Managed Grafana resource.                                           |
| `grafanaAutoGeneratedDomainNameLabelScope` | `string` | Specifies the scope for dns deterministic name hash calculation.                                               |
| `grafanaDeterministicOutboundIP`           | `string` | Specifies whether the Azure Managed Grafana resource uses deterministic outbound IPs.                          |
| `grafanaPublicNetworkAccess`               | `string` | The state for enable or disable traffic over the public interface for the Azure Managed Grafana resource.      |
| `grafanaZoneRedundancy`                    | `string` | The zone redundancy setting of the Azure Managed Grafana resource.                                            |
| `email`                                    | `string` | Specifies the email address for the cert-manager cluster issuer.                                               |
| `deploymentScripName`                      | `string` | Specifies the name of the deployment script uri.     |
| `deploymentScriptUri`                      | `string` | Specifies the uri of the deployment script.          |
| `deployPrometheusAndGrafanaViaHelm`        | `bool` | Specifies whether to deploy Prometheus and Grafana to the AKS cluster using a Helm chart. |
| `deployCertificateManagerViaHelm`          | `bool` | Specifies whether to whether to deploy the Certificate Manager to the AKS cluster using a Helm chart. |
| `ingressClassNames`                        | `array` | Specifies the list of ingress classes for which a cert-manager cluster issuer should be created. |
| `clusterIssuerNames`                       | `array` | Specifies the list of the names for the cert-manager cluster issuers. |
| `deployNginxIngressControllerViaHelm`      | `string` | Specifies whether and how to deploy the NGINX Ingress Controller to the AKS cluster using a Helm chart. Possible values are None, Internal, and External. |
| `azCliVersion`                             | `string` | Specifies the Azure CLI module version. |
| `timeout`                                  | `string` | Specifies the maximum allowed script execution time specified in ISO 8601 format. Default value is P1D. |
| `cleanupPreference`                        | `string` | Specifies the clean up preference when the script execution gets in a terminal state. Default setting is Always. |
| `retentionInterval`                        | `string` | Specifies the interval for which the service retains the script resource after it reaches a terminal state. |
| `dnsZoneName`                              | `string` | Specifies the name of an existing public DNS zone.   |
| `dnsZoneResourceGroupName`                 | `string` | Specifies the name of the resource group which contains the public DNS zone.  |
| `keyVaultCertificateName`                  | `string` | Specifies the name of the Key Vault certificate.     |

We suggest reading sensitive configuration data such as passwords or SSH keys from a preexisting  Azure Key Vault resource. For more information, see [Create parameters files for Bicep deployment](/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep).

The sample includes four distinct Bicep parameter files that allow you to deploy four different variations of the solution:

- `main.http.nginxviaaddon.bicepparam`: the Application Gateway communicates via HTTP with a managed NGINX Ingress Controller instance installed via the application routing add-on.
- `main.http.nginxviahelm.bicepparam`: the Application Gateway communicates via HTTP an unmanaged NGINX Ingress Controller instance installed via Helm.
- `main.https.nginxviaaddon.bicepparam`: the Application Gateway communicates via HTTPS with the managed NGINX Ingress Controller installed via the application routing add-on.
- `main.https.nginxviahelm.bicepparam`: the Application Gateway communicates via HTTPS an unmanaged NGINX Ingress Controller instance installed via Helm.

The `deploy.sh` Bash script provides the flexibility to select from multiple solutions. Simply choose solution option `3`.

```bash
#!/bin/bash

# Template
template="main.bicep"

# Print the menu
echo "==============================================================================================="
echo "Choose an Option to expose the Yelb UI via managed or unmanaged NGINX Ingress Controller (1-5): "
echo "==============================================================================================="
options=(
  "HTTP with NGINX Ingress Controller deployed via application routing add-on"
  "HTTP with NGINX Ingress Controller deployed via Helm chart"
  "HTTPS with NGINX Ingress Controller deployed via application routing add-on"
  "HTTPS with NGINX Ingress Controller deployed via Helm chart"
  "Quit"
)

# Select an option
COLUMNS=1
select option in "${options[@]}"; do
  case $option in
    "HTTP with NGINX Ingress Controller deployed via application routing add-on")
      parameters="main.http.nginxviaaddon.bicepparam"
      break
    ;;
    "HTTP with NGINX Ingress Controller deployed via Helm chart")
      parameters="main.http.nginxviahelm.bicepparam"
      break
    ;;
    "HTTPS with NGINX Ingress Controller deployed via application routing add-on")
      parameters="main.https.nginxviaaddon.bicepparam"
      break
    ;;
    "HTTPS with NGINX Ingress Controller deployed via Helm chart")
      parameters="main.https.nginxviahelm.bicepparam"
      break
    ;;
    "Quit")
      exit
    ;;
    *) echo "Invalid option $REPLY" ;;
  esac
done

# AKS cluster name
prefix="<your-azure-resource-prefix>"
aksName="${prefix}Aks"
userPrincipalName="<your-azure-account>"
validateTemplate=0
useWhatIf=0
update=1
deploy=1
installExtensions=0

# Name and location of the resource group for the Azure Kubernetes Service (AKS) cluster
resourceGroupName="${prefix}RG"
location="EastUS2"
deploymentName="main"

# Subscription id, subscription name, and tenant id of the current subscription
subscriptionId=$(az account show --query id --output tsv)
subscriptionName=$(az account show --query name --output tsv)
tenantId=$(az account show --query tenantId --output tsv)

# Install aks-preview Azure extension
if [[ $installExtensions == 1 ]]; then
  echo "Checking if [aks-preview] extension is already installed..."
  az extension show --name aks-preview &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[aks-preview] extension is already installed"

    # Update the extension to make sure you have the latest version installed
    echo "Updating [aks-preview] extension..."
    az extension update --name aks-preview &>/dev/null
  else
    echo "[aks-preview] extension is not installed. Installing..."

    # Install aks-preview extension
    az extension add --name aks-preview 1>/dev/null

    if [[ $? == 0 ]]; then
      echo "[aks-preview] extension successfully installed"
    else
      echo "Failed to install [aks-preview] extension"
      exit
    fi
  fi

  # Registering AKS feature extensions
  aksExtensions=(
    "AdvancedNetworkingPreview"
    "AKS-KedaPreview"
    "RunCommandPreview"
    "EnableAPIServerVnetIntegrationPreview"
    "EnableImageCleanerPreview"
    "AKS-VPAPreview"
  )
  ok=0
  registeringExtensions=()
  for aksExtension in ${aksExtensions[@]}; do
    echo "Checking if [$aksExtension] extension is already registered..."
    extension=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/$aksExtension') && @.properties.state == 'Registered'].{Name:name}" --output tsv)
    if [[ -z $extension ]]; then
      echo "[$aksExtension] extension is not registered."
      echo "Registering [$aksExtension] extension..."
      az feature register \
        --name $aksExtension \
        --namespace Microsoft.ContainerService \
        --only-show-errors
      registeringExtensions+=("$aksExtension")
      ok=1
    else
      echo "[$aksExtension] extension is already registered."
    fi
  done
  echo $registeringExtensions
  delay=1
  for aksExtension in ${registeringExtensions[@]}; do
    echo -n "Checking if [$aksExtension] extension is already registered..."
    while true; do
      extension=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/$aksExtension') && @.properties.state == 'Registered'].{Name:name}" --output tsv)
      if [[ -z $extension ]]; then
        echo -n "."
        sleep $delay
      else
        echo "."
        break
      fi
    done
  done

  if [[ $ok == 1 ]]; then
    echo "Refreshing the registration of the Microsoft.ContainerService resource provider..."
    az provider register \
      --namespace Microsoft.ContainerService \
      --only-show-errors
    echo "Microsoft.ContainerService resource provider registration successfully refreshed"
  fi
fi

# Get the last Kubernetes version available in the region
kubernetesVersion=$(az aks get-versions \
  --location $location \
  --query "values[?isPreview==null].version | sort(@) | [-1]" \
  --output tsv \
  --only-show-errors)

if [[ -n $kubernetesVersion ]]; then
  echo "Successfully retrieved the last Kubernetes version [$kubernetesVersion] supported by AKS in [$location] Azure region"
else
  echo "Failed to retrieve the last Kubernetes version supported by AKS in [$location] Azure region"
  exit
fi

# Check if the resource group already exists
echo "Checking if [$resourceGroupName] resource group actually exists in the [$subscriptionName] subscription..."

az group show \
  --name $resourceGroupName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "No [$resourceGroupName] resource group actually exists in the [$subscriptionName] subscription"
  echo "Creating [$resourceGroupName] resource group in the [$subscriptionName] subscription..."

  # Create the resource group
  az group create \
    --name $resourceGroupName \
    --location $location \
    --only-show-errors 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$resourceGroupName] resource group successfully created in the [$subscriptionName] subscription"
  else
    echo "Failed to create [$resourceGroupName] resource group in the [$subscriptionName] subscription"
    exit
  fi
else
  echo "[$resourceGroupName] resource group already exists in the [$subscriptionName] subscription"
fi

# Get the user principal name of the current user
if [ -z $userPrincipalName ]; then
  echo "Retrieving the user principal name of the current user from the [$tenantId] Microsoft Entra ID tenant..."
  userPrincipalName=$(az account show \
    --query user.name \
    --output tsv \
    --only-show-errors)
  if [[ -n $userPrincipalName ]]; then
    echo "[$userPrincipalName] user principal name successfully retrieved from the [$tenantId] Microsoft Entra ID tenant"
  else
    echo "Failed to retrieve the user principal name of the current user from the [$tenantId] Microsoft Entra ID tenant"
    exit
  fi
fi

# Retrieve the objectId of the user in the Microsoft Entra ID tenant used by AKS for user authentication
echo "Retrieving the objectId of the [$userPrincipalName] user principal name from the [$tenantId] Microsoft Entra ID tenant..."
userObjectId=$(az ad user show \
  --id $userPrincipalName \
  --query id \
  --output tsv \
  --only-show-errors 2>/dev/null)

if [[ -n $userObjectId ]]; then
  echo "[$userObjectId] objectId successfully retrieved for the [$userPrincipalName] user principal name"
else
  echo "Failed to retrieve the objectId of the [$userPrincipalName] user principal name"
  exit
fi

# Create AKS cluster if does not exist
echo "Checking if [$aksName] aks cluster actually exists in the [$resourceGroupName] resource group..."

az aks show \
  --name $aksName \
  --resource-group $resourceGroupName \
  --only-show-errors &>/dev/null

notExists=$?

if [[ $notExists != 0 || $update == 1 ]]; then

  if [[ $notExists != 0 ]]; then
    echo "No [$aksName] aks cluster actually exists in the [$resourceGroupName] resource group"
  else
    echo "[$aksName] aks cluster already exists in the [$resourceGroupName] resource group. Updating the cluster..."
  fi

  # Validate the Bicep template
  if [[ $validateTemplate == 1 ]]; then
    if [[ $useWhatIf == 1 ]]; then
      # Execute a deployment What-If operation at resource group scope.
      echo "Previewing changes deployed by [$template] Bicep template..."
      az deployment group what-if \
        --only-show-errors \
        --resource-group $resourceGroupName \
        --template-file $template \
        --parameters $parameters \
        --parameters prefix=$prefix \
        location=$location \
        userId=$userObjectId \
        aksClusterKubernetesVersion=$kubernetesVersion

      if [[ $? == 0 ]]; then
        echo "[$template] Bicep template validation succeeded"
      else
        echo "Failed to validate [$template] Bicep template"
        exit
      fi
    else
      # Validate the Bicep template
      echo "Validating [$template] Bicep template..."
      output=$(az deployment group validate \
        --only-show-errors \
        --resource-group $resourceGroupName \
        --template-file $template \
        --parameters $parameters \
        --parameters prefix=$prefix \
        location=$location \
        userId=$userObjectId \
        aksClusterKubernetesVersion=$kubernetesVersion)

      if [[ $? == 0 ]]; then
        echo "[$template] Bicep template validation succeeded"
      else
        echo "Failed to validate [$template] Bicep template"
        echo $output
        exit
      fi
    fi
  fi

  if [[ $deploy == 1 ]]; then
    # Deploy the Bicep template
    echo "Deploying [$template] Bicep template..."
    az deployment group create \
      --only-show-errors \
      --resource-group $resourceGroupName \
      --only-show-errors \
      --template-file $template \
      --parameters $parameters \
      --parameters prefix=$prefix \
      location=$location \
      userId=$userObjectId \
      aksClusterKubernetesVersion=$kubernetesVersion 1>/dev/null

    if [[ $? == 0 ]]; then
      echo "[$template] Bicep template successfully provisioned"
    else
      echo "Failed to provision the [$template] Bicep template"
      exit
    fi
  else
    echo "Skipping the deployment of the [$template] Bicep template"
    exit
  fi
else
  echo "[$aksName] aks cluster already exists in the [$resourceGroupName] resource group"
fi
```

## Deployment Script

The sample makes use of a [Deployment Script][azure-deployment-script] to run the `install-packages.sh` Bash script, which can optionally install the following packages:

- [Prometheus][prometheus] and [Grafana][grafana] using the [Prometheus Community Kubernetes Helm Charts](https://prometheus-community.github.io/helm-charts/). By default, this sample configuration does not install Prometheus and Grafana to the AKS cluster, and rather installs [Azure Managed Prometheus][azure-prometheus] and [Azure Managed Grafana][azure-grafana].
- [cert-manager](https://cert-manager.io/docs/). Certificate Manager is not necessary in this sample as both the Application Gateway and NGINX Ingress Controller use a pre-uploaded TLS certificate from Azure Key Vault.
- [NGINX Ingress Controller][nginx] via a Helm chart. By default, this sample configuration installs the [managed NGINX ingress controller with the application routing add-on][aks-app-routing-addon] and does not install the NGINX Ingress Controller via Helm.

For more details on deployment scripts, see the [Use deployment scripts in Bicep][azure-deployment-script] documentation.

```bash
# Install kubectl
az aks install-cli --only-show-errors

# Get AKS credentials
az aks get-credentials \
  --admin \
  --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --only-show-errors

# Check if the cluster is private or not
private=$(az aks show --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --query apiServerAccessProfile.enablePrivateCluster \
  --output tsv)

# Install openssl
apk add --no-cache --quiet openssl

# Install Helm
wget -O get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add Helm repos
if [[ $deployPrometheusAndGrafanaViaHelm == 'true' ]]; then
  echo "Adding Prometheus Helm repository..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
fi

if [[ $deployCertificateManagerViaHelm == 'true' ]]; then
  echo "Adding cert-manager Helm repository..."
  helm repo add jetstack https://charts.jetstack.io
fi

if [[ $deployNginxIngressControllerViaHelm != 'None' ]]; then
  echo "Adding NGINX ingress controller Helm repository..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
fi

# Update Helm repos
echo "Updating Helm repositories..."
helm repo update

# Install Prometheus
if [[ $deployPrometheusAndGrafanaViaHelm == 'true' ]]; then
  echo "Installing Prometheus and Grafana..."
  helm install prometheus prometheus-community/kube-prometheus-stack \
    --create-namespace \
    --namespace prometheus \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
fi

# Install certificate manager
if [[ $deployCertificateManagerViaHelm == 'true' ]]; then
  echo "Installing cert-manager..."
  helm install cert-manager jetstack/cert-manager \
    --create-namespace \
    --namespace cert-manager \
    --set crds.enabled=true \
    --set prometheus.enabled=true \
    --set nodeSelector."kubernetes\.io/os"=linux

# Create arrays from the comma-separated strings
  IFS=',' read -ra ingressClassArray <<<"$ingressClassNames"   # Split the string into an array
  IFS=',' read -ra clusterIssuerArray <<<"$clusterIssuerNames" # Split the string into an array

  # Check if the two arrays have the same length and are not empty
  # Check if the two arrays have the same length and are not empty
  if [[ ${#ingressClassArray[@]} > 0 && ${#ingressClassArray[@]} == ${#clusterIssuerArray[@]} ]]; then
    for i in ${!ingressClassArray[@]}; do
      echo "Creating cluster issuer ${clusterIssuerArray[$i]} for the ${ingressClassArray[$i]} ingress class..."
      # Create cluster issuer
      cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${clusterIssuerArray[$i]}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: ${ingressClassArray[$i]}
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF
    done
  fi
fi

if [[ $deployNginxIngressControllerViaHelm == 'External' ]]; then
  # Install NGINX ingress controller using the internal load balancer
  echo "Installing NGINX ingress controller using the public load balancer..."
  helm install nginx-ingress ingress-nginx/ingress-nginx \
    --create-namespace \
    --namespace ingress-basic \
    --set controller.replicaCount=3 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.metrics.enabled=true \
    --set controller.metrics.serviceMonitor.enabled=true \
    --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
fi

if [[ $deployNginxIngressControllerViaHelm == 'Internal' ]]; then
  # Install NGINX ingress controller using the internal load balancer
  echo "Installing NGINX ingress controller using the internal load balancer..."
  helm install nginx-ingress ingress-nginx/ingress-nginx \
    --create-namespace \
    --namespace ingress-basic \
    --set controller.replicaCount=3 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.metrics.enabled=true \
    --set controller.metrics.serviceMonitor.enabled=true \
    --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true
fi

# Create output as JSON file
echo '{}' |
  jq --arg x 'prometheus' '.prometheus=$x' |
  jq --arg x 'cert-manager' '.certManager=$x' |
  jq --arg x 'ingress-basic' '.nginxIngressController=$x' >$AZ_SCRIPTS_OUTPUT_PATH
```

As you can note, when `$deployNginxIngressControllerViaHelm == 'Internal'`, the script deploys the [NGINX Ingress Controller][nginx] via Helm and sets the [service.beta.kubernetes.io/azure-load-balancer-internal](/azure/aks/internal-lb#create-an-internal-load-balancer) annotation to `true`. This creates the `kubernetes-internal` internal load balancer in the node resource group of the AKS cluster and exposes the ingress controller service via a private IP address.

The script creates a [ClusterIssuer](https://cert-manager.io/docs/concepts/issuer/) for the `Let's Encrypt` ACME certificate authority for each cluster issuer and ingress class specified, respectively, in the `ingressClassNames` and `clusterIssuerNames` environment variables. However, in this sample, the [Kubernetes Ingress][kubernetes-ingress] object uses the same certificate as the one used by the Application Gateway from Key Vault.

## Next steps

> [!div class="nextstepaction"]
> [Deploy an AWS Web Application Workload to Azure][eks-web-deploy]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

<!-- LINKS -->
[aws-cli]: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
[eksctl]: https://eksctl.io/installation/
[kubectl]: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
[helm]: https://helm.sh/docs/intro/install/
[yelb]: https://github.com/mreferre/yelb/
[nginx]: https://github.com/kubernetes/ingress-nginx
[nginx-helm-chart]: https://kubernetes.github.io/ingress-nginx
[prometheus]: https://prometheus.io/ 
[grafana]: https://grafana.com/
[aws-waf]: https://aws.amazon.com/waf/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-alb]: https://aws.amazon.com/elasticloadbalancing/application-load-balancer
[aws-web-acl]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html
[aws-cloudformation]: https://aws.amazon.com/it/cloudformation/
[kubernetes-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[aks]: ./what-is-aks.md
[aks-app-routing-addon]: ./app-routing.md
[azure-waf]: /azure/web-application-firewall/overview
[azure-ag]: /azure/application-gateway/overview
[azure-kv]: /azure/key-vault/general/overview
[azure-bastion]: /azure/bastion/bastion-overview
[azure-cr]: /azure/container-registry/container-registry-intro
[azure-lb]: /azure/load-balancer/load-balancer-overview
[azure-dns]: /azure/dns/dns-overview
[azure-la]: /azure/azure-monitor/logs/log-analytics-workspace-overview
[azure-grafana]: /azure/managed-grafana/overview
[azure-prometheus]: /azure/azure-monitor/essentials/azure-monitor-workspace-overview
[azure-deployment-script]: /azure/azure-resource-manager/bicep/deployment-script-bicep
[token-projection]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection
[oidc-federation]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens
[bicep-dir]: https://github.com/Azure-Samples/aks-web-application-replicate-from-aws/tree/main/azure/nginx-with-azure-waf/bicep
[aks-workload-id]:/azure/aks/workload-identity-overview?tabs=dotnet
[azure-kv-csi-driver]: /azure/aks/csi-secrets-store-driver
[secret-provider-class]: /azure/aks/hybrid/secrets-store-csi-driver
[azure-sample]: https://github.com/Azure-Samples/aks-web-application-replicate-from-aws
[eks-web-deploy]: ./eks-web-deploy.md
[azure-free]: https://azure.microsoft.com/free/
[azure-built-in-roles]: /azure/role-based-access-control/built-in-roles
[azure-cli]: /cli/azure/install-azure-cli
[aks-preview]: /azure/aks/draft#install-the-aks-preview-azure-cli-extension
[install-jq]: https://jqlang.github.io/jq/
[install-python]: https://www.python.org/downloads/
[install-kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[install-helm]: https://helm.sh/docs/intro/install/
[download-vscode]: https://code.visualstudio.com/Download
[bicep]: /azure/azure-resource-manager/bicep/overview
[bicep-extension]: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep