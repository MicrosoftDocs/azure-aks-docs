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

Now that you have a better understanding of the platform differences between AWS and Azure, let's examine the web application architecture on AWS and the modifications needed to make it compatible with [Azure Kubernetes Service (AKS)][aks].

## Yelb application architecture

The [Yelb][yelb] sample web application consists of a front-end component called `yelb-ui` and an application component called `yelb-appserver`.

:::image type="content" source="media/eks-web-rearchitect/yelb-architecture.png" alt-text="Architecture diagram of the Yelb web application.":::

The `yelb-ui` serves JavaScript code to the browser. This code is compiled from an [Angular][angular] application. The `yelb-ui` component might also include an `nginx` proxy depending on the deployment model. The `yelb-appserver` is a [Sinatra](https://sinatrarb.com/) application that interacts with a cache server (`redis-server`) and a Postgres back-end database (`yelb-db`). [Redis Cache][redis-cache] stores the number of page views, while [PostgreSQL][postgresql] persists the votes. Both services are deployed on [Kubernetes][kubernetes] without using any managed service for storing data on AWS or Azure.

The original Yelb application is self-contained and doesn't rely on external services, so you can migrate it from AWS to Azure without any code changes. On Azure, you can use [Azure Cache for Redis][azure-redis] and [Azure Database for PostgreSQL][azure-postgresql] as replacements for the Redis Cache and PostgreSQL services deployed on [AKS][aks].

The sample Yelb application allows users to vote on a set of alternatives (restaurants) and dynamically updates pie charts based on the number of votes received. The application also keeps track of the number of page views and displays the hostname of the `yelb-appserver` instance serving the API request upon a vote or a page refresh. This feature enables you to demo the application independently or collaboratively.

:::image type="content" source="media/eks-web-rearchitect/yelb-user-interface.png" alt-text="Screenshot of the Yelb service interface.":::

## Architecture on AWS

To help protect web applications and APIs from common web exploits, AWS offers [AWS Web Application Firewall (WAF)][aws-waf] and [AWS Firewall Manager][aws-firewall-manager]. 

## Map AWS services to Azure services

To recreate the AWS workload in Azure with minimal changes, use an Azure equivalent for each AWS service. The following table summarizes the service mappings:

| **Service mapping** | **AWS service** | **Azure service** |
|------------------------|-------------------|--------------------|
| Web access firewall | [AWS Web Application Firewall (WAF)][aws-waf] | [Azure Web Application Firewall (WAF)][azure-waf] |
| Application load balancing | [Application Load Balancer (ALB)][aws-alb] | [Azure Application Gateway][azure-ag] [Application Gateway for Containers (AGC)][azure-agc] |
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

- Easy configuration of managed NGINX ingress controllers based on [Kubernetes NGINX ingress controller][nginx].
- Integration with [Azure DNS](/azure/dns/dns-overview) for public and private zone management.
- SSL termination with certificates stored in [Azure Key Vault][azure-kv].

For other configurations, see the following articles:

- [DNS and SSL configuration](app-routing-dns-ssl.md)
- [Application routing add-on configuration](app-routing-nginx-configuration.md)
- [Configure internal NGINX ingress controller for Azure private DNS zone](create-nginx-ingress-private-controller.md)

The [Yelb][yelb] application is secured with an [Azure Application Gateway](/azure/application-gateway/overview) resource deployed in a dedicated subnet within the same virtual network as the AKS cluster or in a peered virtual network. You can secure access to the Yelb application using [Azure Web Application Firewall (WAF)](/azure/web-application-firewall/overview), which provides centralized protection of web applications from common exploits and vulnerabilities. 

### Solution architecture design

The following diagram shows the recommended architecture on Azure:

:::image type="content" source="media/eks-web-rearchitect/application-gateway-azure-kubernetes-service-https.png" alt-text="Diagram of the solution based on Application Gateway WAFv2 and NGINX ingress controller." lightbox="media/eks-web-rearchitect/application-gateway-azure-kubernetes-service-https.png":::

The solution architecture consists of the following:

1. The Application Gateway handles TLS termination and communicates with the backend application over HTTPS.
2. The Application Gateway Listener uses an SSL certificate obtained from [Azure Key Vault][azure-kv].
3. The Azure WAF Policy associated to the Listener runs OWASP rules and custom rules against the incoming requests and blocks malicious attacks.
4. The Application Gateway Backend HTTP Settings invoke the Yelb application via HTTPS on port 443.
5. The Application Gateway Backend Pool and Health Probe call the NGINX ingress controller through the AKS internal load balancer using HTTPS.
6. The NGINX ingress controller uses the AKS internal load balancer.
7. The AKS cluster is configured with the [Azure Key Vault provider for Secrets Store CSI Driver add-on](/azure/aks/csi-secrets-store-driver) to retrieve secrets, certificates, and keys from Azure Key Vault via a [CSI volume](https://kubernetes-csi.github.io/docs/).
8. A [SecretProviderClass](/azure/aks/hybrid/secrets-store-csi-driver) retrieves the same certificate used by the Application Gateway from Azure Key Vault.
9. An [Kubernetes ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) object employs the NGINX ingress controller to expose the application via HTTPS through the AKS internal load balancer.
10. The Yelb service is of type `ClusterIP` and is exposed via the NGINX ingress controller.

For comprehensive instructions on deploying the [Yelb application][yelb] on AKS using this architecture, see the [companion sample][azure-sample].

## Alternative solutions
Azure offers several options for deploying a web application on an AKS cluster and securing it with a web application firewall:

### [Application Gateway Ingress Controller](#tab/agic)

The [Application Gateway Ingress Controller (AGIC)](/azure/application-gateway/ingress-controller-overview) is a Kubernetes application, so you can leverage Azure's native [Application Gateway](https://azure.microsoft.com/services/application-gateway/) L7 load-balancer to expose cloud software to the Internet for your [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/services/kubernetes-service/) workloads. AGIC monitors the Kubernetes cluster it's hosted on and continuously updates an Application Gateway so that selected services are exposed to the Internet.

:::image type="content" source="media/eks-web-rearchitect/application-gateway-ingress-controller-azure-kubernetes-service-http.png" alt-text="Diagram of the solution based on Azure Application Gateway Ingress Controller." lightbox="media/eks-web-rearchitect/application-gateway-ingress-controller-azure-kubernetes-service-http.png":::

The Ingress Controller runs in its own pod on the AKS cluster. AGIC monitors a subset of Kubernetes Resources for changes, translates the state of the cluster to an Application Gateway specific configuration, and applies it to [Azure Resource Manager (ARM)](/azure/azure-resource-manager/management/overview). For more information, see [What is Application Gateway Ingress Controller?](/azure/application-gateway/ingress-controller-overview).

The following table outlines advantages and disadvantages of the Application Gateway Ingress Controller (AGIC):

| Advantages | Disadvantages |
|---------------|-----------------|
| • **Native integration**: AGIC provides native integration with Azure services, specifically Azure Application Gateway, which allows for seamless and efficient routing of traffic to services running on AKS. <br> • **Simplified deployments**: Deploying AGIC as an AKS add-on is straightforward and simpler compared to other methods. It enables a quick and easy setup of an Application Gateway and an AKS cluster with AGIC enabled. <br> • **Fully managed service**: AGIC as an add-on is a fully managed service, providing benefits such as automatic updates and increased support from Microsoft. It ensures the Ingress Controller remains up-to-date and adds an extra layer of support. | • **Single cloud approach**: AGIC is primarily adopted by customers who adopt a single-cloud approach. It might not be the best choice if you require a multi cloud architecture where deployment across different cloud platforms is a requirement. In this case, you might want to use a cloud-agnostic ingress controller such as NGINX, Traefik, or HAProxy to avoid vendo-lockin issues.|

For more information, see the following resources:

- [What is Application Gateway Ingress Controller?](/azure/application-gateway/ingress-controller-overview)
- [Documentation for Application Gateway Ingress Controller](https://azure.github.io/application-gateway-kubernetes-ingress/)

### [Azure Application Gateway for Containers](#tab/agc)

[Azure Application Gateway for Containers][azure-agc] provides load balancing and dynamic traffic management for applications in Kubernetes clusters.

:::image type="content" source="media/eks-web-rearchitect/application-gateway-for-containers-azure-kubernetes-service.png" alt-text="Diagram of the solution based on Azure Application Gateway for Containers." lightbox="media/eks-web-rearchitect/application-gateway-for-containers-azure-kubernetes-service.png":::

#### Key features

Azure Application Gateway for Containers builds upon the capabilities of [Application Gateway Ingress Controller (AGIC)][agic] and allows you to use Azure's native Application Gateway load balancer. Key features include:

- [**Load balancing**](/azure/application-gateway/for-containers/overview#load-balancing-features): Efficiently distributes incoming traffic across multiple containers for optimal performance and scalability.
- [**Gateway API implementation**](/azure/application-gateway/for-containers/overview#implementation-of-gateway-api): Supports the Gateway API, allowing you to define routing rules and policies in a Kubernetes-native way.
- [**Custom health probes**](/azure/application-gateway/for-containers/custom-health-probe): Define custom health probes to monitor container health and automatically route traffic away from unhealthy instances.
- [**Session affinity**](/azure/application-gateway/for-containers/session-affinity?tabs=session-affinity-gateway-api): Provides session affinity, routing subsequent requests from the same client to the same container for a consistent user experience.
- [**TLS policy**](/azure/application-gateway/for-containers/tls-policy?tabs=tls-policy-gateway-api): Supports TLS termination, allowing SSL/TLS encryption and decryption to be offloaded to the gateway.
- **Header rewrites**: Rewrite HTTP headers of client requests and responses from backend targets using the `IngressExtension` custom resource definition. For more information, see [Ingress API](/azure/application-gateway/for-containers/how-to-header-rewrite-ingress-api) and [Gateway API](/azure/application-gateway/for-containers/how-to-header-rewrite-gateway-api).
- **URL rewrites**: Modify the URL of client requests, including hostname and/or path, and include the newly rewritten URL when initiating requests to backend targets. For more information, see [Ingress API](/azure/application-gateway/for-containers/how-to-url-rewrite-ingress-api) and [Gateway API](/azure/application-gateway/for-containers/how-to-url-rewrite-gateway-api).

#### Limitations

Currently, Azure Application Gateway for Containers doesn't support the following features:

- [Azure Web Application Firewall](/azure/application-gateway/waf-overview)
- [Azure CNI Overlay](/azure/aks/azure-cni-overlay)
- [WebSockets](https://datatracker.ietf.org/doc/html/rfc6455)
- Private front ends

For more information, see [Deploying an Azure Kubernetes Service (AKS) Cluster with Application Gateway for Containers](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/deploying-an-azure-kubernetes-service-aks-cluster-with/ba-p/3967434).

### [Azure Front Door](#tab/afd)

[Azure Front Door][azure-fd] is global layer 7 load balancer that securely exposes and protects workloads running in AKS using the [Azure Web Application Firewall][azure-waf] and an [Azure Private Link](/azure/private-link/private-link-service-overview) service.

:::image type="content" source="media/eks-web-rearchitect/front-door-azure-kubernetes-service.png" alt-text="Diagram of the solution based on Azure Front Door." lightbox="media/eks-web-rearchitect/front-door-azure-kubernetes-service.png":::

This solution uses [Azure Front Door Premium][azure-fd], [end-to-end TLS encryption](/azure/frontdoor/end-to-end-tls), [Azure Web Application Firewall][azure-waf], and a [Private Link service](/azure/private-link/private-link-service-overview) to securely expose and protect a workload that runs in [AKS](/azure/aks/intro-kubernetes).

Azure Front Door TLS and Secure Sockets Layer (SSL) offload capability to terminate TLS connections and decrypt incoming traffic at the front door. Azure Front Door reencrypts the incoming traffic before forwarding it to the AKS-hosted web application. This practice enforces end-to-end TLS encryption for the entire request process, from the client to the origin. For more information, see [Secure your origin with Private Link in Azure Front Door Premium](/azure/frontdoor/private-link).

The [NGINX ingress controller][nginx] exposes the AKS-hosted web application. It's configured to use a private IP address as a front-end IP configuration of the `kubernetes-internal` internal load balancer, and it uses HTTPS as the transport protocol to expose the web application. For more information, see [Create an ingress controller by using an internal IP address](/azure/aks/ingress-basic#create-an-ingress-controller-using-an-internal-ip-address).

We recommend this solution for scenarios where you're deploying the same web application across multiple regional AKS clusters for business continuity and disaster recovery, or even across multiple cloud platforms or on-premises installations. In this case, Front Door can forward incoming calls to one of the backends (also known as *origins*) using one of the following routing methods:

- [**Latency**](/azure/frontdoor/routing-methods#latency): Latency-based routing ensures that requests are sent to the lowest latency origins acceptable within a sensitivity range. In other words, requests get sent to the nearest set of origins in respect to network latency.
- [**Priority**](/azure/frontdoor/routing-methods#priority): You can set priorities to origins when you want to configure a primary origin to service all traffic. The secondary origin can be a backup in case the primary origin becomes unavailable.
- [**Weighted**](/azure/frontdoor/routing-methods#weighted): You can assign a weight to your origins when you want to distribute traffic across a set of origins evenly or according to the weight coefficients. Traffic gets distributed by the weight value if the latencies of the origins are within the acceptable latency sensitivity range in the origin group.
- [**Session affinity**](/azure/frontdoor/routing-methods#affinity): You can configure session affinity for your frontend hosts or domains to ensure requests from the same end user gets sent to the same origin.

For more information, see [Use Azure Front Door to secure AKS workloads](/azure/architecture/example-scenario/aks-front-door/aks-front-door).

### [NGINX ingress controller](#tab/nginx)

The following solution uses the [NGINX ingress controller][nginx] to expose the Yelb application and ModSecurity to block any malicious or suspicious traffic based on predefined OWASP or custom rules. [ModSecurity][mod-security] is an open-source web application firewall (WAF) that's compatible with popular web servers such as Apache, NGINX, and ISS. It provides protection from a wide range of attacks by using a powerful rule-definition language.

:::image type="content" source="media/eks-web-rearchitect/nginx-modsecurity-azure-kubernetes-service.png" alt-text="Diagram of the solution based on NGINX ingress controller and ModSecurity." lightbox="media/eks-web-rearchitect/nginx-modsecurity-azure-kubernetes-service.png":::

You can use [ModSecurity][mod-security] with the NGINX ingress controller to provide an extra layer of security to web applications exposed via Kubernetes. The NGINX ingress controller acts as a reverse proxy, forwarding traffic to the web application, while ModSecurity inspects the incoming requests and blocks any malicious or suspicious traffic based on the defined rules.

Using ModSecurity with NGINX Ingress controllers in Kubernetes provides a cloud-agnostic solution that you can deploy to any managed Kubernetes cluster on any cloud platform. This solution enables you to switch between cloud providers or have a multi cloud setup while maintaining consistent security measures.


## Next step

> [!div class="nextstepaction"]
> [Migrate AWS web application deployment to AKS][eks-web-refactor]

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

Principal author:
- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

Other contributors:
- [Ken Kilty](https://www.linkedin.com/in/kennethkilty/) | Principal TPM
- [Russell de Pina](https://www.linkedin.com/in/rdepina/) | Principal TPM
- [Erin Schaffer](https://www.linkedin.com/in/erin-schaffer-65800215b/) | Content Developer 2

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
[aws-cloudfront]: https://aws.amazon.com/cloudfront
[aws-kms]: https://aws.amazon.com/kms/
[aws-ecr]: https://aws.amazon.com/ecr
[aws-route53]: https://aws.amazon.com/it/route53/
[aws-dynamodb]: https://aws.amazon.com/it/dynamodb/
[aws-cache]: https://aws.amazon.com/it/elasticache/
[kubernetes]: https://kubernetes.io/
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