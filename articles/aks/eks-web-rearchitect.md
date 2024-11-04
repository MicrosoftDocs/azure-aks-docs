---
title: Rearchitect AWS EKS web application for Azure Kubernetes Service (AKS)
description: Understand the architectural differences and steps to replicate the AWS EKS web application workload and AWS WAF protection in Azure.
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

# Rearchitect AWS EKS web application for Azure Kubernetes Service (AKS)

Now that you have a better understanding of the platform differences between AWS and Azure, let's examine the web application architecture and the modifications needed to make it compatible with [Azure Kubernetes Service (AKS)][aks].

## Yelb application architecture

The [Yelb][yelb] sample web application consists of a front-end component called `yelb-ui` and an application component called `yelb-appserver`.

:::image type="content" source="media/eks-web-rearchitect/yelb-architecture.png" alt-text="Architecture diagram of the Yel web application.":::

The `yelb-ui` is responsible for serving the JavaScript code to the browser. This code is compiled from an [Angular][angular] application. The `yelb-ui` component might also include an `nginx` proxy, depending on the deployment model. The `yelb-appserver` is a [Sinatra](https://sinatrarb.com/) application that interacts with a cache server (`redis-server`) and a Postgres backend database (`yelb-db`). [Redis Cache][redis-cache] stores the number of page views, while [PostgreSQL][postgresql] persists the votes. Both services are deployed on [Kubernetes][kubernetes] without using any managed service for storing data on AWS or Azure.

Since the original Yelb application is self-contained and doesn't rely on external services, you can migrate it from AWS to Azure without any code changes. On AWS, you can use [Amazon ElastiCache][aws-cache] and [DynamoDB][aws-dynamodb] as replacements for the Redis Cache and PostgreSQL instances deployed on [EKS][aws-eks]. On Azure, you can use [Azure Cache for Redis][azure-redis] and [Azure Database for PostgreSQL][azure-postgresql] as replacements for the Redis Cache and PostgreSQL services deployed on [AKS][aks].

The sample Yelb application allows users to vote on a set of alternatives (restaurants) and dynamically updates pie charts based on the number of votes received. The application also keeps track of the number of page views and displays the hostname of the `yelb-appserver` instance serving the API request upon a vote or a page refresh. This feature allows enables you to demo the application independently or collaboratively.

:::image type="content" source="media/eks-web-rearchitect/yelb-ui.png" alt-text="Screenshot of the Yelb service interface.":::

## Architecture on AWS

To help protect web applications and APIs from common web exploits, AWS offers [AWS Web Application Firewall (WAF)][aws-waf] and [AWS Firewall Manager][aws-firewall-manager]. These services allow you to monitor HTTP(S) requests and defend against DDoS attacks, bots, and common attack patterns such as SQL injection or cross-site scripting.

To test an implementation of a web application firewall using [AWS Web Application Firewall (WAF)][aws-waf] to safeguard applications running on [EKS][aws-eks], you can use the following solution:

1. Create an EKS cluster and deploy a sample workload.
1. Expose the sample application using an [Application Load Balancer (ALB)][aws-alb].
1. Create a [Kubernetes ingress][kubernetes-ingress] and associate an [AWS WAF web access control list (web ACL)][aws-web-acl] with the ALB in front of the ingress.

AWS WAF provides control over the type of traffic that reaches your web applications, ensuring protection against unauthorized access attempts and unwanted traffic. It integrates with [Amazon CloudFront][aws-cloudfront], [Application Load Balancer (ALB)][aws-alb], [Amazon API Gateway][aws-api-gateway], and [AWS AppSync][aws-appsync]. When using an existing ALB as an ingress for Kubernetes-hosted applications, you can quickly add a web application firewall to your apps.

For customers operating in multiple AWS accounts, [AWS Organizations][aws-organizations] and [AWS Firewall Manager][aws-firewall-manager] offer centralized control over AWS WAF rules. With Firewall Manager, you can enforce security policies across accounts to ensure compliance and adherence to best practices. It's recommended to run EKS clusters in dedicated Virtual Private Clouds (VPCs). [AWS Firewall Manager][aws-firewall-manager] ensures that WAF rules are correctly applied across accounts, regardless of where your applications run.

By implementing these measures, you can effectively deploy the sample web application on [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) and protect it using [AWS WAF][aws-waf].

:::image type="content" source="media/eks-web-rearchitect/architecture-on-aws.png" alt-text="Architecture diagram of the Yelb web application in AWS.":::

For more information, see [Protecting your Amazon EKS web apps with AWS WAF](https://aws.amazon.com/blogs/containers/protecting-your-amazon-eks-web-apps-with-aws-waf/).

## Map AWS services to Azure services

To recreate the AWS workload in Azure with minimal changes, use an Azure equivalent for each AWS service. The following table summarizes the service mapping:

| **Service mapping** | **AWS service** | **Azure service** |
|------------------------|-------------------|--------------------|
| Web access firewall | [AWS Web Application Firewall (WAF)][aws-waf] | [Azure Web Application Firewall (WAF)][azure-waf] |
| Application load balancing | [Application Load Balancer (ALB)][aws-alb] | [Azure Application Gateway][azure-ag]<br> [Application Gateway for Containers (AGC)][azure-agc] |
| Content delivery network | [Amazon CloudFront][aws-cloudfront] | [Azure Front Door (AFD)][azure-fd] |
| Orchestration | [Elastic Kubernetes Service (EKS)][aws-eks] | [Azure Kubernetes Service (AKS)][aks] |
| Secrets vault | [AWS Key Management Service (KMS)][aws-kms] | [Azure Key Vault][azure-kv] |
| Container registry | [Amazon Elastic Container Registry (ECR)][aws-ecr] | [Azure Container Registry (ACR)][azure-cr] |
| Domain Name System (DNS) | [Amazon Route 53][aws-route53] | [Azure DNS][azure-dns] |
| Caching | [Amazon ElastiCache][aws-cache] | [Azure Cache for Redis][azure-redis] |
| NoSQL | [Amazon DynamoDB][aws-dynamodb] | [Azure Database for PostgreSQL][azure-postgresql] |

For a comprehensive comparison between Azure and AWS services, see [AWS to Azure services comparison][aws-to-azure].

## Architecture on Azure

In this solution, the [Yelb][yelb] application is deployed to an AKS cluster and is exposed via an ingress controller like the [NGINX ingress controller][nginx]. The ingress controller service is exposed via an [internal (or private) load balancer][azure-lb]. For more information on how to use an internal load balancer to restrict access to your applications in AKS, see [Use an internal load balancer with Azure Kubernetes Service (AKS)](internal-lb.md).

This sample supports installing a [managed NGINX ingress controller with the application routing add-on][aks-app-routing-addon] or an unmanaged [NGINX ingress controller][nginx] using the [Helm chart][nginx-helm-chart]. The application routing add-on with NGINX ingress controller provides the following features:

- Easy configuration of managed NGINX Ingress controllers based on [Kubernetes NGINX Ingress controller][nginx].
- Integration with [Azure DNS](/azure/dns/dns-overview) for public and private zone management.
- SSL termination with certificates stored in [Azure Key Vault][azure-kv].

For other configurations, see the following articles:

- [DNS and SSL configuration](app-routing-dns-ssl.md)
- [Application routing add-on configuration](app-routing-nginx-configuration.md)
- [Configure internal NGINX ingress controller for Azure private DNS zone](create-nginx-ingress-private-controller.md).

The [Yelb][yelb] application is secured with an [Azure Application Gateway](/azure/application-gateway/overview) resource deployed in a dedicated subnet within the same virtual network as the AKS cluster or in a peered virtual network. You can secure access to the Yelb application using [Azure Web Application Firewall (WAF)](/azure/web-application-firewall/overview), which provides centralized protection of web applications from common exploits and vulnerabilities. 

The solution architecture is designed as follows:

- The AKS cluster is deployed with the following features:
  - Network Configuration: Azure CNI Overlay
  - Network Dataplane: Cilium
  - Network Policy: Cilium
- The Application Gateway handles TLS termination and communicates with the backend application over HTTPS.
- The Application Gateway Listener utilizes an SSL certificate obtained from [Azure Key Vault][azure-kv].
- The Azure WAF Policy associated to the Listener is used to run OWASP rules and custom rules against the incoming request and block malicous attacks.
- The Application Gateway Backend HTTP Settings are configured to invoke the Yelb application via HTTPS on port 443.
- The Application Gateway Backend Pool and Health Probe are set to call the NGINX ingress controller through the AKS internal load balancer using HTTPS.
- The NGINX ingress controller is deployed to use the AKS internal load balancer instead of the public one.
- The Azure Kubernetes Service (AKS) cluster is configured with the [Azure Key Vault provider for Secrets Store CSI Driver](/azure/aks/csi-secrets-store-driver) addonto retrieve secret, certificates, and keys from Azure Key Vault via a [CSI volume](https://kubernetes-csi.github.io/docs/).
- A [SecretProviderClass](/azure/aks/hybrid/secrets-store-csi-driver)  is used to retrieve the same certificate used by the Application Gateway from Key Vault.
- An [Kubernetes ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) object employs the NGINX ingress controller to expose the application via HTTPS through the AKS internal load balancer.
- The Yelb service is of type ClusterIP, as it is exposed via the NGINX ingress controller.

:::image type="content" source="media/eks-web-rearchitect/application-gateway-aks-https-detail.png" alt-text="Details of the solution based on Application Gateway WAFv2 and NGINX Ingress controller.":::

For comprehensive instructions and resources to successfully deploy the [Yelb application][yelb] on [Azure Kubernetes Service (AKS)][aks] using this architecture, please refer to the companion [sample][azure-sample].

## Alternative Solutions

Azure offers several options for deploying a web application such as the [Yelb application][yelb] on an [Azure Kubernetes Service (AKS)][aks] cluster and securing it with a web application firewall.

### Use Azure Application Gateway for Containers

This solution uses the cutting-edge [Application Gateway for Containers][azure-agc], a new Azure service that provides load balancing and dynamic traffic management for applications in a Kubernetes cluster.

:::image type="content" source="media/eks-web-rearchitect/application-gateway-for-containers-aks.png" alt-text="Architecture diagram of the solution based on Azure Application Gateway for Containers.":::

This innovative product enhances the experience for developers and administrators as part of Azure's Application Load Balancing portfolio. It builds upon the capabilities of the [Application Gateway Ingress Controller (AGIC)][agic] and allows Azure Kubernetes Service (AKS) customers to utilize Azure's native Application Gateway load balancer. This guide walks you through deploying an [Azure Kubernetes Service (AKS)][aks] cluster with an [Application Gateway for Containers][azure-agc] in a fully-automated manner, supporting both bring your own (BYO) and managed by ALB deployments. The [Application Gateway for Containers][azure-agc] offers several features:

- [Load Balancing](/azure/application-gateway/for-containers/overview#load-balancing-features): Efficiently distributes incoming traffic across multiple containers for optimal performance and scalability.
- [Gateway API Implementation](/azure/application-gateway/for-containers/overview#implementation-of-gateway-api): Supports the Gateway API, allowing you to define routing rules and policies in a Kubernetes-native way.
- [Custom Health Probe](/azure/application-gateway/for-containers/custom-health-probe): Define custom health probes to monitor container health and automatically route traffic away from unhealthy instances.
- [Session Affinity](/azure/application-gateway/for-containers/session-affinity?tabs=session-affinity-gateway-api): Provides session affinity, routing subsequent requests from the same client to the same container for a consistent user experience.
- [TLS Policy](/azure/application-gateway/for-containers/tls-policy?tabs=tls-policy-gateway-api): Supports TLS termination, allowing SSL/TLS encryption and decryption to be offloaded to the gateway.
- Header Rewrites: Rewrite HTTP headers of client requests and responses from backend targets using the `IngressExtension` custom resource definition. Learn more about [Ingress API](/azure/application-gateway/for-containers/how-to-header-rewrite-ingress-api) and [Gateway API](/azure/application-gateway/for-containers/how-to-header-rewrite-gateway-api).
- URL Rewrites: Modify the URL of client requests, including hostname and/or path, and include the newly rewritten URL when initiating requests to backend targets. Find more information on [Ingress API](/azure/application-gateway/for-containers/how-to-url-rewrite-ingress-api) and [Gateway API](/azure/application-gateway/for-containers/how-to-url-rewrite-gateway-api).

However, at this time, the Azure Application Gateway for Containers has some limitations. For example, the following features are not currently supported:

- [Azure Web Application Firewall](/azure/application-gateway/waf-overview)
- [Azure CNI Overlay](/azure/aks/azure-cni-overlay)
- [WebSockets](https://datatracker.ietf.org/doc/html/rfc6455)
- Private Frontends

For more information, see [Deploying an Azure Kubernetes Service (AKS) Cluster with Application Gateway for Containers](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/deploying-an-azure-kubernetes-service-aks-cluster-with/ba-p/3967434).

### Use Azure Front Door

The following solution uses [Azure Front Door][azure-fd] as a global layer 7 load balancer to securely expose and protect a workload that runs in [Azure Kubernetes Service (AKS)][aks] by using the [Azure Web Application Firewall][azure-waf], and an [Azure Private Link](/azure/private-link/private-link-service-overview) service.

:::image type="content" source="media/eks-web-rearchitect/front-door-aks.png" alt-text="Architecture diagram of the solution based on Azure Front Door.":::

This solution uses [Azure Front Door Premium][azure-fd], [end-to-end TLS encryption](/azure/frontdoor/end-to-end-tls), [Azure Web Application Firewall][azure-waf], and a [Private Link service](/azure/private-link/private-link-service-overview) to securely expose and protect a workload that runs in [AKS](/azure/aks/intro-kubernetes).

This architecture uses the Azure Front Door TLS and Secure Sockets Layer (SSL) offload capability to terminate the TLS connection and decrypt the incoming traffic at the front door. Azure Front Door reencrypts the incoming traffic before forwarding it to the AKS-hosted web application via. This practice enforces end-to-end TLS encryption for the entire request process, from the client to the origin. For more information, see [Secure your origin with Private Link in Azure Front Door Premium](/azure/frontdoor/private-link).

The [NGINX ingress controller][nginx] exposes the AKS-hosted web application. The NGINX ingress controller is configured to use a private IP address as a front-end IP configuration of the `kubernetes-internal` internal load balancer. The NGINX ingress controller uses HTTPS as the transport protocol to expose the web application. For more information, see [Create an ingress controller by using an internal IP address](/azure/aks/ingress-basic#create-an-ingress-controller-using-an-internal-ip-address).

This solution is recommended in those scenarios where customers deploy the same web application across multiple regional AKS clusters for business continuity and disaster recovery, or even across multiple cloud platforms or on-premises installations. In this case, Front Door can forward incoming calls to one of the backends also known as origins using one of the available routing methods.

- [Latency](/azure/frontdoor/routing-methods#latency): The latency-based routing ensures that requests are sent to the lowest latency origins acceptable within a sensitivity range. In other words, requests get sent to the nearest set of origins in respect to network latency.
- [Priority](/azure/frontdoor/routing-methods#priority): A priority can be set to your origins when you want to configure a primary origin to service all traffic. The secondary origin can be a backup in case the primary origin becomes unavailable.
- [Weighted](/azure/frontdoor/routing-methods#weighted): You can assign a weight to your origins when you want to distribute traffic across a set of origins evenly or according to the weight coefficients. Traffic gets distributed by the weight value if the latencies of the origins are within the acceptable latency sensitivity range in the origin group.
- [Session Affinity](/azure/frontdoor/routing-methods#affinity): You can configure session affinity for your frontend hosts or domains to ensure requests from the same end user gets sent to the same origin.

The following diagram shows the steps for the message flow during deployment time and runtime.

:::image type="content" source="media/eks-web-rearchitect/front-door-aks-flow.png" alt-text="Details of the solution based on Azure Front Door.":::

#### Deployment workflow

The following steps describe the deployment process. This workflow corresponds to the green numbers in the preceding diagram.

1. A security engineer generates a certificate for the custom domain that the workload uses, and saves it in an Azure Key Vault. You can obtain a valid certificate from a well-known [certification authority (CA)](https://en.wikipedia.org/wiki/Certificate_authority).
2. A platform engineer specifies the necessary information in the parameters and deploys the infrastructure using an Infrastructure as Code (IaC) technology such as Terraform or Bicep. The necessary information includes:
   - A prefix for the Azure resources.
   - The name and resource group of the existing Azure Key Vault that holds the TLS certificate for the workload hostname and the Azure Front Door custom domain.
   - The name of the certificate in the key vault.
   - The name and resource group of the DNS zone that's used to resolve the Azure Front Door custom domain.
3. You can use a [deployment script](/azure/azure-resource-manager/bicep/deployment-script-bicep) to install the following packages to your AKS cluster. For more information, check the parameters section of the Bicep module:
   - [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) using the [Prometheus Community Kubernetes Helm Charts](https://prometheus-community.github.io/helm-charts/). By default, this sample configuration does not install Prometheus and Grafana to the AKS cluster, and rather installs [Azure Managed Prometheus](/azure/azure-monitor/essentials/azure-monitor-workspace-overview) and [Azure Managed Grafana](/azure/managed-grafana/overview).
   - [cert-manager](https://cert-manager.io/docs/). Certificate Manager is not necessary in this sample as both the Application Gateway and NGINX Ingress Controller use a pre-uploaded TLS certificate from Azure Key Vault.
   - [NGINX Ingress Controller][nginx] via an Helm chart. If you use the [managed NGINX ingress controller with the application routing add-on](/azure/aks/app-routing), you don't need to install another instance of the NGINX Ingress Controller via Helm.
4. An Azure front door [secret resource](/azure/templates/microsoft.cdn/profiles/secrets) is used to manage and store the TLS certificate in the Azure key vault. This certificate is used by the [custom domain](/azure/templates/microsoft.cdn/profiles/customdomains) associated with the Azure Front Door endpoint.

> [!NOTE]
> At the end of the deployment, you need to approve the private endpoint connection before traffic can pass to the origin privately. For more information, see [Secure your origin with Private Link in Azure Front Door Premium](/azure/frontdoor/private-link). To approve private endpoint connections, use the Azure portal, the Azure CLI, or Azure PowerShell. For more information, see [Manage a private endpoint connection](/azure/private-link/manage-private-endpoint).

#### Runtime workflow

The following steps describe the message flow for a request that an external client application initiates during runtime. This workflow corresponds to the orange numbers in the preceding diagram.

1. The client application uses its custom domain to send a request to the web application. The DNS zone associated with the custom domain uses a [CNAME record](https://en.wikipedia.org/wiki/CNAME_record) to redirect the DNS query for the custom domain to the original hostname of the Azure Front Door endpoint.
2. Azure Front Door traffic routing occurs in several stages. Initially, the request is sent to one of the [Azure Front Door points of presence](/azure/frontdoor/edge-locations-by-region). Then Azure Front Door uses the configuration to determine the appropriate destination for the traffic. Various factors can influence the routing process, such as the Azure front door caching, web application firewall (WAF), routing rules, rules engine, and caching configuration. For more information, see [Routing architecture overview](/azure/frontdoor/front-door-routing-architecture).
3. Azure Front Door forwards the incoming request to the [Azure private endpoint](/azure/private-link/private-endpoint-overview) connected to the [Private Link service](/azure/private-link/private-link-service-overview) that exposes the AKS-hosted workload.
4. The request is sent to the Private Link service.
5. The request is forwarded to the *kubernetes-internal* AKS internal load balancer.
6. The request is sent to one of the agent nodes that hosts a pod of the NGINX ingress controller.
7. One of the NGINX ingress controller replicas handles the request.
8. The NGINX ingress controller forwards the request to one of the workload pods.

For more information, see [Use Azure Front Door to secure AKS workloads](/azure/architecture/example-scenario/aks-front-door/aks-front-door)

### Use NGINX Ingress Controller and ModSecurity

The following solution makes use of [NGINX ingress controller][nginx] to expose the Yelb application and ModSecurity to block any malicious or suspicious traffic based on predefined OWASP or custom rules. [ModSecurity][mod-security] is an open-source web application firewall (WAF) that is compatible with popular web servers such as Apache, NGINX, and ISS. It provides protection from a wide range of attacks by using a powerful rule-definition language.

:::image type="content" source="media/eks-web-rearchitect/nginx-modsecurity-aks.png" alt-text="Architecture diagram of the solution based on NGINX Ingress Controller and ModSecurity.":::

[ModSecurity][mod-security] can be used with the NGINX Ingress controller to provide an extra layer of security to web applications exposed via Kubernetes. The NGINX Ingress controller acts as a reverse proxy, forwarding traffic to the web application, while ModSecurity inspects the incoming requests and blocks any malicious or suspicious traffic based on the defined rules.

Using ModSecurity with NGINX Ingress controllers in Kubernetes provides a cloud-agnostic solution that can be deployed on any managed Kubernetes cluster on any cloud platform. This means the solution can be deployed "as is" on various cloud platforms, including:

- [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/)
- [Azure Kubernetes Service (AKS)][aks]
- [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)

The cloud-agnostic nature of this solution allows multi-cloud customers to deploy and configure their web applications, such as Yelb, consistently across different cloud platforms without significant modifications. It provides flexibility and portability, enabling you to switch between cloud providers or have a multi-cloud setup while maintaining consistent security measures.

## Conclusions

In conclusion, there are multiple architectures available on Azure to deploy and protect the [Yelb][yelb] application on [Azure Kubernetes Service (AKS)][aks]. These solutions include using [Azure Web Application Firewall (WAF)][azure-waf] with [Azure Application Gateway][azure-ag] or [Azure Front Door][azure-fd], or using the open-source web access firewall [ModSecurity][mod-security] with the [NGINX ingress controller][nginx], or using the cutting-edge [Application Gateway for Containers][azure-agc]. Each of these solutions offers its own set of features and benefits, allowing you to choose the one that best suits your requirements. Whether you need regional load balancing, integrated WAF protection, or a cloud-agnostic approach, Azure provides the necessary tools and services to securely deploy and protect your Yelb application.

## Next steps

> [!div class="nextstepaction"]
> [Migrate AWS Web Application Deployment to AKS][eks-web-refactor]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

<!-- LINKS -->
[postgresql]: https://www.postgresql.org/
[redis-cache]: https://redis.io/solutions/caching/
[angular]: https://angular.dev/
[yelb]: https://github.com/mreferre/yelb/
[nginx]: https://github.com/kubernetes/ingress-nginx
[nginx-helm-chart]: https://kubernetes.github.io/ingress-nginx
[mod-security]: https://github.com/SpiderLabs/ModSecurity
[aws-waf]: https://aws.amazon.com/waf/
[aws-firewall-manager]: https://aws.amazon.com/firewall-manager/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-alb]: https://aws.amazon.com/elasticloadbalancing/application-load-balancer
[aws-web-acl]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html
[aws-cloudfront]: https://aws.amazon.com/cloudfront
[aws-api-gateway]: https://aws.amazon.com/api-gateway
[aws-appsync]: https://aws.amazon.com/appsync
[aws-organizations]: https://aws.amazon.com/organizations
[aws-kms]: https://aws.amazon.com/kms/
[aws-ecr]: https://aws.amazon.com/ecr
[aws-route53]: https://aws.amazon.com/it/route53/
[aws-dynamodb]: https://aws.amazon.com/it/dynamodb/
[aws-cache]: https://aws.amazon.com/it/elasticache/
[kubernetes]: https://kubernetes.io/
[kubernetes-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[aks]: ./what-is-aks.md
[aks-app-routing-addon]: ./app-routing.md
[azure-waf]: /azure/web-application-firewall/overview
[azure-ag]: /azure/application-gateway/overview
[azure-agc]: /azure/application-gateway/for-containers/overview
[azure-fd]: /azure/frontdoor/front-door-overview
[azure-kv]: /azure/key-vault/general/overview
[azure-cr]: /azure/container-registry/container-registry-intro
[azure-lb]: /azure/load-balancer/load-balancer-overview
[azure-dns]: /azure/dns/dns-overview
[azure-redis]: /azure/azure-cache-for-redis/cache-overview
[azure-postgresql]: /azure/postgresql/flexible-server/service-overview
[agic]: /azure/application-gateway/ingress-controller-overview
[aws-to-azure]: /azure/architecture/aws-professional/services
[azure-sample]: https://github.com/Azure-Samples/aks-web-application-replicate-from-aws
[eks-web-refactor]: ./eks-web-refactor.md