---
title: Prepare to deploy web application workload to Azure
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

## TLS termination at the Application Gateway and Yelb invocation via HTTP

In this solution, the [Azure Web Application Firewall (WAF)][azure-waf] ensures the security of the system by blocking malicious attacks. The [Azure Application Gateway][azure-ag] receives incoming calls from client applications, performs TLS termination, and forwards the requests to the AKS-hosted `yelb-ui` service. This communication is achieved through the internal load balancer and NGINX Ingress controller using the HTTP transport protocol. The following diagram illustrates the architecture:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-http.png" alt-text="Architecture diagram of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTP.":::

The message flow is as follows:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-http-detail.png" alt-text="Details of the solution based on Application Gateway WAFv2 and NGINX Ingress controller via HTTP.":::

- The [Azure Application Gateway][azure-ag] handles TLS termination and sends incoming calls to the AKS-hosted `yelb-ui` service over HTTP.
- The Application Gateway Listener uses an SSL certificate obtained from [Azure Key Vault][azure-kv] to ensure secure communication.
- The Azure WAF Policy associated with the Listener applies OWASP rules and custom rules to incoming requests, effectively preventing malicious attacks.
- The Application Gateway Backend HTTP Settings invoke the Yelb application via HTTP using port 80.
- The Application Gateway Backend Pool and Health Probe call the [NGINX ingress controller][nginx] through the AKS internal load balancer using the HTTP protocol for traffic management.
- The [NGINX ingress controller][nginx] uses the AKS internal load balancer to ensure secure communication within the cluster.
- A [Kubernetes ingress][kubernetes-ingress] object uses the [NGINX ingress controller][nginx] to expose the application via HTTP through the internal load balancer.
- The `yelb-ui` service with the `ClusterIP` type restricts its invocation to within the cluster or through the [NGINX ingress controller][nginx].

## Implementing end-to-end TLS using Azure Application Gateway

### TLS termination

[Azure Application Gateway][azure-ag] supports TLS termination at the gateway level, which means that traffic is decrypted at the gateway before being sent to the backend servers. To configure TLS termination, you need to add a TLS/SSL certificate to the listener. The certificate should be in Personal Information Exchange (PFX) format, which contains both the private and public keys. You can import the certificate from Azure Key Vault to the Application Gateway. For more information on TLS termination with Key Vault certificates, see [TLS termination with Key Vault certificates](/azure/application-gateway/key-vault-certs).

### Zero Trust Security Model

If you adopt a [Zero Trust](https://www.microsoft.com/en-us/security/business/zero-trust) security model, you should prevent unencrypted communication between a service proxy like Azure Application Gateway and the backend servers. The zero trust security model is a concept wherein trust is not automatically granted to any user or device trying to access resources within a network. Instead, it requires continuous verification of identity and authorization for each request, regardless of the user's location or network. In our scenario, implementing the zero trust security model involves utilizing the Azure Application Gateway as a service proxy, which acts as a front-end for incoming requests. These requests then travel down to the NGINX Ingress controller on Azure Kubernetes Service (AKS) in an encrypted format.

### End-to-End TLS with Application Gateway

You can implement a zero trust approach by configuring Azure Application Gateway for end-to-end TLS encryption with the backend servers. [End-to-end TLS encryption](/azure/application-gateway/ssl-overview#end-to-end-tls-encryption) allows you to securely transmit sensitive data to the backend while also utilizing Application Gateway's Layer-7 load-balancing features. These features include cookie-based session affinity, URL-based routing, routing based on sites, and the ability to rewrite or inject X-Forwarded-* headers.

When Application Gateway is configured with end-to-end TLS communication mode, it terminates the TLS sessions at the gateway and decrypts user traffic. It then applies the configured rules to select the appropriate backend pool instance to route the traffic to. Next, Application Gateway initiates a new TLS connection to the backend server and re-encrypts the data using the backend server's public key certificate before transmitting the request to the backend. The response from the web server follows the same process before reaching the end user. To enable end-to-end TLS, you need to set the protocol setting in the Backend HTTP Setting to HTTPS and apply it to a backend pool. This approach ensures that your communication with the backend servers is secured and compliant with your requirements. For more information, you can refer to the documentation on [Application Gateway end-to-end TLS encryption](/azure/application-gateway/end-to-end-ssl-portal). Additionally, you may find it useful to review [best practices for securing your Application Gateway](/security/benchmark/azure/baselines/application-gateway-security-baseline).

### Architecture

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

To help ensure the security and stability of the system, consider the following recommendations:

- Regularly update the Azure WAF Policy with the latest rules to ensure optimal security.
- Implement monitoring and logging mechanisms to track and analyze incoming requests and potential attacks.
- Regularly perform maintenance and updates of the AKS cluster, NGINX ingress controller, and Application Gateway to address any security vulnerabilities and maintain a secure infrastructure.

### Hostname

The Application Gateway Listener and the [Kubernetes ingress][kubernetes-ingress] are configured to use the same hostname. It's important to use the same hostname for a service proxy and a backend web application for the following reasons:

- **Preservation of session state**: When you use a different hostname for the proxy and the backend application, session state can get lost. This means that user sessions might not persist properly, resulting in a poor user experience and potential loss of data.
- **Authentication failure**: If the hostname differs between the proxy and the backend application, authentication mechanisms might fail. This approach can lead to users being unable to log in or access secure resources within the application.
- **Inadvertent exposure of URLs**: If the hostname isn't preserved, there's a risk that backend URLs might be exposed to end users. This can lead to potential security vulnerabilities and unauthorized access to sensitive information.
- **Cookie issues**: Cookies play a crucial role in maintaining user sessions and passing information between the client and the server. When the hostname differs, cookies might not work as expected, leading to issues such as failed authentication, improper session handling, and incorrect redirection.
- **End-to-end TLS/SSL requirements**: If end-to-end TLS/SSL is required for secure communication between the proxy and the backend service, a matching TLS certificate for the original hostname is necessary. Using the same hostname simplifies the certificate management process and ensures that secure communication is established seamlessly.

You can avoid these problems by using the same hostname for the service proxy and the backend web application. The backend application sees the same domain as the web browser, ensuring that session state, authentication, and URL handling function correctly. This technique is especially important in platform as a service (PaaS) offerings, where you can reduce the complexity of certificate management by using the managed TLS certificates provided by the PaaS service. 

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

By default, Bicep templates install the AKS cluster with the [Azure CNI Overlay](azure-cni-overlay.md) network plugin and the [Cilium](azure-cni-powered-by-cilium.md) data plane. You can also use any one of the following network plugins:

- [Azure CNI with static IP allocation](configure-azure-cni.md)
- [Azure CNI with dynamic IP allocation](configure-azure-cni-dynamic-ip-allocation.md)
- [Azure CNI Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](azure-cni-overlay.md)

In addition, the project shows how to deploy an [Azure Kubernetes Service][aks] cluster with the following extensions and features:

- [Microsoft Entra Workload ID][aks-workload-id]
- [Istio-based service mesh add-on for Azure Kubernetes Service](/azure/aks/istio-about)
- [API Server VNET Integration](/azure/aks/api-server-vnet-integration)
- [Azure NAT Gateway](/azure/virtual-network/nat-gateway/nat-overview)
- [Event-driven Autoscaling (KEDA) add-on](/azure/aks/keda-about)
- [Dapr extension for Azure Kubernetes Service (AKS)](/azure/aks/dapr)
- [Flux V2 extension](/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2?tabs=azure-cli)
- [Vertical Pod Autoscaling](/azure/aks/vertical-pod-autoscaler)
- [Azure Key Vault Provider for Secrets Store CSI Driver](/azure/aks/csi-secrets-store-identity-access)
- [Image Cleaner](/azure/aks/image-cleaner?tabs=azure-cli)
- [Azure Kubernetes Service (AKS) Network Observability](/azure/aks/network-observability-overview)
- [Managed NGINX ingress with the application routing add-on][aks-app-routing-addon].

In a production environment, we strongly recommend deploying a [private AKS cluster](/azure/aks/private-clusters) with [Uptime SLA](/azure/aks/uptime-sla). For more information, see [private AKS cluster with a Public DNS address](/azure/aks/private-clusters#create-a-private-aks-cluster-with-a-public-dns-address). Alternatively, you can deploy a public AKS cluster and secure access to the API server using [authorized IP address ranges](/azure/aks/api-server-authorized-ip-ranges). For detailed information and instructions on how to deploy the infrastructure on Azure using Bicep templates, refer to the [companion Azure code sample][azure-sample].

## Next step

> [!div class="nextstepaction"]
> [Deploy an AWS web application workload to Azure][eks-web-deploy]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

Principal author:
- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

Other contributors:
- [Ken Kilty](https://www.linkedin.com/in/kennethkilty/) | Principal TPM
- Russell de Pina | Principal TPM
- [Erin Schaffer](https://www.linkedin.com/in/erin-schaffer-65800215b/) | Content Developer 2

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
[kubernetes-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[aks]: ./what-is-aks.md
[aks-app-routing-addon]: ./app-routing.md
[azure-waf]: /azure/web-application-firewall/overview
[azure-ag]: /azure/application-gateway/overview
[azure-kv]: /azure/key-vault/general/overview
[azure-lb]: /azure/load-balancer/load-balancer-overview
[azure-dns]: /azure/dns/dns-overview
[azure-grafana]: /azure/managed-grafana/overview
[azure-prometheus]: /azure/azure-monitor/essentials/azure-monitor-workspace-overview
[azure-deployment-script]: /azure/azure-resource-manager/bicep/deployment-script-bicep
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