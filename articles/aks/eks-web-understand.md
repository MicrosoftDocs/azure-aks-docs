---
title: Understand Platform Differences for the Web Application Workload
description: Learn about the key differences between the AWS and Azure platforms related to the web application hosting.
author: paolosalvatori
ms.author: paolos
ms.date: 10/31/2024
ms.topic: how-to
---

# Understand Platform Differences for the Web Application Workload

Before you port the sample web application to Azure, make sure to obtain a solid understanding of the operational differences between the AWS and Azure platforms. This article walks through some of the key concepts for this workload and provides links to resources for more information. For a comprehensive comparison between Azure and AWS services, you can refer to the [AWS to Azure services comparison][aws-to-azure] article by Microsoft. It provides in-depth analysis and insights into the features and capabilities of both cloud platforms.

## Orchestration

In recent years, Kubernetes has become the de facto standard for container orchestration, enabling organizations to efficiently manage and scale their containerized applications. [Azure Kubernetes Service (AKS)][aks] and [Amazon Elastic Kubernetes Service (EKS)][aws-eks] are both fully managed Kubernetes services offered by Microsoft Azure and Amazon Web Services (AWS) respectively. Let's compare AKS and EKS along multiple dimensions.

For more information, see:

- [Migrate from Amazon EKS to Azure Kubernetes Service (AKS)](/azure/architecture/aws-professional/eks-to-aks/migrate-eks-to-aks)
- [AKS for Amazon EKS professionals](/azure/architecture/aws-professional/eks-to-aks/)
- [Identity and access management](/azure/architecture/aws-professional/eks-to-aks/workload-identity)
- [Cluster logging and monitoring](/azure/architecture/aws-professional/eks-to-aks/monitoring)
- [Secure network topologies](/azure/architecture/aws-professional/eks-to-aks/private-clusters)
- [Storage options](/azure/architecture/aws-professional/eks-to-aks/storage)
- [Cost optimization and management](/azure/architecture/aws-professional/eks-to-aks/cost-management)
- [Agent node and node pool management](/azure/architecture/aws-professional/eks-to-aks/node-pools)
- [Cluster governance](/azure/architecture/aws-professional/eks-to-aks/governance)
- [Workload Migration](/azure/architecture/aws-professional/eks-to-aks/migrate-eks-to-aks)

### Deployment

Both AKS and EKS provide multiple options for deploying a managed Kubernetes cluster on Azure and AWS. These options include native solutions as well as those based on third-party or open source technologies.

- AKS: To create an [Azure Kubernetes Service (AKS)][aks] cluster, you can use options such as [Azure Resource Manager (ARM)][arm], [Bicep][bicep], [Azure CLI][azure-cli], [Terraform][terraform], [Pulumi](https://www.pulumi.com/registry/packages/azure-native/how-to-guides/azure-cs-aks/), [Crossplane](https://docs.crossplane.io/latest/getting-started/provider-azure/), or [Kubernetes Cluster API](https://capz.sigs.k8s.io/).
- EKS: Similarly, for EKS deployment, you have options like [AWS CloudFormation][aws-cloudformation], [eksctl][eksctl], [Terraform][terraform], [Pulumi](https://www.pulumi.com/docs/iac/clouds/aws/guides/eks/), [Crossplane](https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws/v0.37.1/resources/eks.aws.crossplane.io/Cluster/v1beta1), or [Kubernetes Cluster API](https://cluster-api-aws.sigs.k8s.io/topics/eks/).

### Monitoring
Effective monitoring is essential for identifying and resolving issues in Kubernetes clusters. Let's see how AKS and EKS handle monitoring:

- AKS: [Azure Monitor](/azure/aks/monitor-aks) provides built-in monitoring capabilities for AKS clusters. It offers metrics, logs, and alerts, giving you visibility into the performance and health of your AKS environment. AKS integrates well with commonly used monitoring tools like Prometheus and Grafana, allowing you to build custom monitoring solutions. [Azure Monitor managed service for Prometheus][azure-prometheus] is a component of [Azure Monitor Metrics](/azure/azure-monitor/essentials/data-platform-metrics), providing more flexibility in the types of metric data that you can collect and analyze with Azure Monitor. Prometheus metrics are supported by analysis tools like [Azure Monitor Metrics Explorer with PromQL][azure-metrics-explorer] and open source tools such as [PromQL](https://aka.ms/azureprometheus-promio-promql) and [Azure Managed Grafana][azure-grafana].
- EKS: EKS integrates with [Amazon CloudWatch][aws-cloudwatch], a comprehensive monitoring service provided by AWS. CloudWatch collects and provides insights into logs, metrics, and resource utilization for EKS clusters. Additionally, EKS supports integration with popular monitoring tools like [Amazon Managed Service for Prometheus][aws-prometheus] and [Amazon Managed Grafana][aws-grafana], empowering you to build robust monitoring solutions.

### Support for Open Source Projects
Both AKS and EKS provide support for open-source projects, enabling you to leverage additional capabilities and features:

- AKS: AKS supports projects like [Kubernetes Event-driven Autoscaling (KEDA)][keda] and [Karpenter][karpenter]. KEDA enables event-driven autoscaling in AKS, allowing you to scale your workloads based on event-driven metrics. Karpenter provides a framework for automated cluster autoscaling and intelligent pod bin packing within AKS. AKS supports a managed version of Karpenter called [Node Autoprovisioning][node-autoprovisioning].
- EKS: EKS also supports open-source projects like KEDA and Karpenter. These projects enable similar functionalities in EKS clusters, allowing you to dynamically scale your applications and optimize resource utilization.

### Deployment Tools
Both AKS and EKS offer command-line tools to simplify the creation and management of Kubernetes clusters:

- AKS: [Azure CLI][azure-cli] is the primary command-line tool for managing AKS clusters. It provides a comprehensive set of commands to create, configure, and manage AKS resources. Azure CLI's intuitive interface and extensive documentation make it easy to work with AKS.
- EKS: Amazon provides [eksctl][eksctl], a dedicated command-line tool for managing EKS clusters. eksctl automates many of the cluster creation and management tasks, making it simpler for developers and operators to work with EKS. eksctl is designed for ease of use and provides a streamlined experience for managing EKS environments.

## Application Gateway

[Azure Application Gateway][azure-ag]and [[AWS Application Load Balancer][aws-alb]] are two popular load balancing solutions offered by Microsoft Azure and Amazon Web Services, respectively. These services play a crucial role in distributing incoming network traffic across multiple servers to ensure high availability and improved performance for applications.

[Azure Application Gateway][azure-ag]is a powerful application delivery controller that provides layer 7 load balancing, SSL/TLS termination, URL-based routing, and other advanced features. It is designed to optimize the delivery of web applications and provide enhanced security through features like [Azure Web Application Firewall][azure-waf] and [Application Gateway Ingress Controller][agic] for [Azure Kubernetes Service (AKS)][aks].

On the other hand, [AWS Application Load Balancer][aws-alb] is a highly scalable and efficient load balancer that operates at the application layer, allowing it to intelligently distribute traffic based on application-level information. It supports features like SSL/TLS termination, URL-based routing, and session affinity.

Here is an exhaustive comparison between [Azure Application Gateway][azure-ag] and [AWS Application Load Balancer][aws-alb] based on the provided features:

| Feature                                  | Azure Application Gateway                                                                                          | AWS Application Load Balancer                                                                                                   |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Secure Sockets Layer (SSL/TLS) Termination | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#secure-sockets-layer-ssltls-termination) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listeners-ssl)  |
| Autoscaling                              | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#autoscaling)                          | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-target-group.html) |
| Zone Redundancy                          | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#zone-redundancy)                      | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-components.html#zone-configuration) |
| Static VIP                               | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#static-vip)                            | Not Supported                                                                                                                   |
| Web Application Firewall                 | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#web-application-firewall)              | Not Supported                                                                                                                   |
| Ingress Controller for AKS                | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#ingress-controller-for-aks)           | Not Supported                                                                                                                   |
| URL-based Routing                        | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#url-based-routing)                    | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#url-based-routing) |
| Multiple-site Hosting                    | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#multiple-site-hosting)                | Not Supported                                                                                                                   |
| Redirection                              | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#redirection)                          | Not Supported                                                                                                                   |
| Session Affinity                         | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#session-affinity)                     | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-group.html#sticky-sessions) |
| WebSocket and HTTP/2 Traffic             | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#websocket-and-http2-traffic)          | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#websocket-protocol) |
| Mutual TLS Authentication             | [Supported](https://learn.microsoft.com/en-us/azure/application-gateway/mutual-authentication-overview)          | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html) |
| Connection Draining                      | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#connection-draining)                   | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-group.html#connection-draining) |
| Custom Error Pages                       | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#custom-error-pages)                    | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update.html#change-default-reqs)     |
| Rewrite HTTP Headers                     | [Supported](https://docs.microsoft.com/en-us/azure/application-gateway/features#rewrite-http-headers)                  | Not Supported                                                                                                                   |
| Sizing                                   | [Multiple Sizes Available](https://docs.microsoft.com/en-us/azure/application-gateway/features#sizing)                 | [Multiple Sizes Available](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-limits.html) |

Both [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) and [[AWS Application Load Balancer][aws-alb]](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) offer multiple common features like SSL/TLS termination, autoscaling, zone redundancy, URL-based routing, session affinity, WebSocket and HTTP/2 traffic support, connection draining, and custom error pages.

However, [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) provides additional features such as a Web Application Firewall, Ingress Controller for AKS, multiple-site hosting, and rewriting HTTP headers. These features are not available in [[AWS Application Load Balancer][aws-alb]](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html).

It's also worth mentioning that both [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) and [[AWS Application Load Balancer][aws-alb]](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) support secure SSL/TLS termination. However, [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) offers more flexible and advanced options for SSL/TLS termination.

In terms of sizing, both [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) and [[AWS Application Load Balancer][aws-alb]](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) offer multiple sizes to cater to different application needs.

In summary, while [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) provides some unique features like Web Application Firewall and Ingress Controller for AKS, [[AWS Application Load Balancer][aws-alb]](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) has a simpler feature set with a focus on core load balancing capabilities. The choice between the two would depend on the specific requirements and preferences of your application deployment.


## Next steps

> [!div class="nextstepaction"]
> [Prepare to Deploy Web Application Workload to Azure][eks-web-rearchitect]

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer

<!-- LINKS -->
[eksctl]: https://eksctl.io/installation/
[aws-waf]: https://aws.amazon.com/waf/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-alb]: https://aws.amazon.com/elasticloadbalancing/application-load-balancer
[aws-web-acl]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html
[aws-cloudformation]: https://aws.amazon.com/cloudformation/
[aws-cloudwatch]: https://aws.amazon.com/cloudwatch/
[aws-prometheus]: https://aws.amazon.com/prometheus/
[aws-grafana]: https://aws.amazon.com/grafana/
[aks]: ./what-is-aks.md
[eks-web-rearchitect]: ./eks-web-rearchitect.md
[azure-ag]: /azure/application-gateway/overview
[azure-waf]: /azure/web-application-firewall/overview
[azure-metrics-explorer]: /azure/azure-monitor/essentials/metrics-explorer
[azure-prometheus]: /azure/azure-monitor/essentials/prometheus-metrics-overview
[azure-grafana]: /azure/managed-grafana/overview
[agic]: /azure/application-gateway/ingress-controller-overview
[arm]: /azure/azure-resource-manager/management/overview
[bicep]: /azure/azure-resource-manager/bicep/overview
[azure-cli]: /cli/azure/install-azure-cli
[terraform]: https://www.terraform.io/
[keda]: https://keda.sh/
[karpenter]: https://karpenter.sh/
[node-autoprovisioning]: /azure/aks/node-autoprovision
[aws-to-azure]: /azure/architecture/aws-professional/services