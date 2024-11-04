---
title: Understand platform differences for the web application workload
description: Learn about the key differences between the AWS and Azure platforms related to the web application hosting.
author: paolosalvatori
ms.author: paolos
ms.date: 10/31/2024
ms.topic: how-to
ms.service: azure-kubernetes-service
---

# Understand platform differences for the web application workload

Before you migrate the sample web application to Azure, make sure you have a solid understanding of the operational differences between the AWS and Azure platforms.

This article walks through some of the key concepts for this workload and provides links to resources for more information. For a comprehensive comparison between Azure and AWS services, see [AWS to Azure services comparison][aws-to-azure].

### Deployment

Both AKS and EKS provide multiple options for deploying a managed Kubernetes cluster on Azure and AWS. These options include native solutions and provisioning solutions based on third-party systems or open-source technologies.

- **AKS**: To create an [AKS cluster][aks], you can use options like [Azure Resource Manager (ARM)][arm], [Bicep][bicep], [Azure CLI][azure-cli], [Terraform][terraform], [Pulumi](https://www.pulumi.com/registry/packages/azure-native/how-to-guides/azure-cs-aks/), [Crossplane](https://docs.crossplane.io/latest/getting-started/provider-azure/), and [Kubernetes Cluster API](https://capz.sigs.k8s.io/).
- **EKS**: Similarly, for EKS deployments, you have options like [AWS CloudFormation][aws-cloudformation], [eksctl][eksctl], [Terraform][terraform], [Pulumi](https://www.pulumi.com/docs/iac/clouds/aws/guides/eks/), [Crossplane](https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws/v0.37.1/resources/eks.aws.crossplane.io/Cluster/v1beta1), and [Kubernetes Cluster API](https://cluster-api-aws.sigs.k8s.io/topics/eks/).

### Monitoring

Effective monitoring is essential for identifying and resolving issues in Kubernetes clusters. The following information outlines how AKS and EKS handle monitoring:

- **AKS**: [Azure Monitor](/azure/aks/monitor-aks) provides built-in monitoring capabilities for AKS clusters. It offers metrics, logs, and alerts, giving you visibility into the performance and health of your AKS environment. AKS integrates well with commonly used monitoring tools like Prometheus and Grafana, allowing you to build custom monitoring solutions. [Azure Monitor managed service for Prometheus][azure-prometheus] is a component of [Azure Monitor Metrics](/azure/azure-monitor/essentials/data-platform-metrics) that provides more flexibility in the types of metric data that you can collect and analyze. You can use analysis tools like [Azure Monitor Metrics Explorer with PromQL][azure-metrics-explorer] and open-source tools such as [PromQL][promql] and [Azure Managed Grafana][azure-grafana] to effectively observe, analyze, and visualize Prometheus metrics.
- **EKS**: EKS integrates with [Amazon CloudWatch][aws-cloudwatch], a comprehensive monitoring service provided by AWS. CloudWatch collects and provides insights into logs, metrics, and resource utilization for EKS clusters. EKS also supports integration with popular monitoring tools like [Amazon Managed Service for Prometheus][aws-prometheus] and [Amazon Managed Grafana][aws-grafana], empowering you to build robust monitoring solutions.

### Support for open-Source projects

Both AKS and EKS provide support for open-source projects, enabling you to utilize more capabilities and features:

- **AKS**: AKS supports projects like [Kubernetes Event-driven Autoscaling (KEDA)][keda] and [Karpenter][karpenter]. KEDA enables event-driven autoscaling in AKS, allowing you to scale your workloads based on event-driven metrics. Karpenter provides a framework for automated cluster autoscaling and intelligent pod bin packing within AKS. AKS supports a managed version of Karpenter called [Node Autoprovisioning][node-autoprovisioning].
- **EKS**: EKS also supports open-source projects like KEDA and Karpenter. These projects enable similar functionalities in EKS clusters, allowing you to dynamically scale your applications and optimize resource utilization.

### Deployment tools

Both AKS and EKS offer command-line tools to simplify the creation and management of Kubernetes clusters:

- **AKS**: [Azure CLI][azure-cli] is the primary command-line tool for managing AKS clusters. It provides a comprehensive set of commands to create, configure, and manage AKS resources.
- **EKS**: Amazon provides [eksctl][eksctl], a command-line tool for managing EKS clusters. eksctl automates many of the cluster creation and management tasks, making it simpler for developers and operators to work with EKS.

## Load balancing

[Azure Application Gateway][azure-ag] and [AWS Application Load Balancer][aws-alb] are two popular load balancing solutions offered by Microsoft Azure and Amazon Web Services, respectively. These services play a crucial role in distributing incoming network traffic across multiple servers to ensure high availability and improved performance for applications.

[Azure Application Gateway][azure-ag] provides layer 7 load balancing, SSL/TLS termination, URL-based routing, and other advanced features. It's designed to optimize the delivery of web applications and provide enhanced security through features like [Azure Web Application Firewall][azure-waf] and [Application Gateway Ingress Controller][agic] for [Azure Kubernetes Service (AKS)][aks].

[AWS Application Load Balancer][aws-alb] operates at the application layer, allowing it to intelligently distribute traffic based on application-level information. It supports features like SSL/TLS termination, URL-based routing, and session affinity.

[Azure Application Gateway][azure-ag] and [AWS Application Load Balancer][aws-alb] provide a comparable feature set.  The following table provides a comparison of the solutions:
| Feature | Azure Application Gateway | AWS Application Load Balancer |
| -------- | ------------------------------ | ----------------------------------- |
| Secure Sockets Layer (SSL/TLS) Termination | [Supported](/azure/application-gateway/features#secure-sockets-layer-ssltls-termination) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listeners-ssl) |
| Autoscaling | [Supported](/azure/application-gateway/features#autoscaling)  | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-target-group.html) |
| Zone redundancy | [Supported](/azure/application-gateway/features#zone-redundancy) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-components.html#zone-configuration) |
| Static VIP | [Supported](/azure/application-gateway/features#static-vip) | Supported with [AWS Global Accelerator](https://aws.amazon.com/global-accelerator/) |
| Web Application Firewall | [Supported](/azure/application-gateway/features#web-application-firewall) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#load-balancer-waf) |
| Ingress controller | [Supported](/azure/application-gateway/features#ingress-controller-for-aks) | [Supported](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) |
| URL-based routing | [Supported](/azure/application-gateway/features#url-based-routing) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#url-based-routing) |
| Multiple-site hosting | [Supported](/azure/application-gateway/features#multiple-site-hosting) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-target-group.html) |
| Redirection | [Supported](/azure/application-gateway/features#redirection) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#add-https-listener) |
| Session affinity | [Supported](/azure/application-gateway/features#session-affinity) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-group.html#sticky-sessions) |
| WebSocket and HTTP/2 traffic | [Supported](/azure/application-gateway/features#websocket-and-http2-traffic) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#websocket-protocol) |
| Mutual TLS authentication | [Supported](/azure/application-gateway/mutual-authentication-overview) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html) |
| Connection draining | [Supported](/azure/application-gateway/features#connection-draining) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-group.html#connection-draining) |
| Custom error pages | [Supported](/azure/application-gateway/features#custom-error-pages) | [Supported](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update.html#change-default-reqs) |
| Rewrite HTTP headers and URL | [Supported](/azure/application-gateway/features?branch=main#rewrite-http-headers-and-url) | [Supported with AWS WAF](https://docs.aws.amazon.com/waf/latest/developerguide/customizing-the-incoming-request.html) |
| Sizing | [Multiple sizes available](/azure/application-gateway/features#sizing) | [Multiple sizes available](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-limits.html) |

## Web Access Firewall

Ensuring web application security is of paramount importance to protect against evolving cyber threats. [Azure Web Application Firewall (WAF)][azure-waf] and [AWS WAF][aws-waf] are fully managed web access firewall services that provide robust protection for web applications against threats and malicious attacks. 

[AWS WAF][aws-waf] is a web application firewall that lets you monitor the HTTP and HTTPS requests that are forwarded to your protected web application resources. You can protect multiple AWS resources, and in particular web applications exposed via the [AWS Application Load Balancer][aws-alb]. With AWS WAF, you have the ability to manage the access to your web applications. By defining specific conditions, such as the origin IP addresses or query string values, you can determine how your protected resource should respond to requests. This can include providing the requested content, returning an HTTP 403 status code (indicating Forbidden access), or even providing a customized response.

AWS WAF provides the AWS Managed Rules for AWS WAF, which consists of a set of managed rulesets maintained by AWS. These rulesets include the AWS Core Rule Set (CRS) and the AWS Managed Rules for Common Vulnerabilities and Exposures (CVEs). Users can easily enable these rulesets to enhance the security of their web applications. [Learn more about AWS WAF managed OWASP rulesets](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html). 

AWS WAF also supports custom rules, which enable users to define their own rule sets using the AWS WAF Rule Language. This allows for precise customization and protection against application-specific vulnerabilities and attack patterns. [Learn more about AWS WAF custom rules](https://docs.aws.amazon.com/waf/latest/developerguide/waf-user-created-rule-groups.html). 

AWS WAF offers advanced bot control features that allow users to set rules to block or rate-limit automated bot traffic. It provides options to differentiate between good and bad bots using string matching or machine learning algorithms. [Learn more about AWS WAF bot control](https://aws.amazon.com/waf/features/bot-control/).

In AWS WAF, you can create an [web access control list (web ACL)][aws-web-acl] to monitor HTTP(S) requests for one or more AWS resources. These resources can be  an [Amazon API Gateway](https://aws.amazon.com/it/api-gateway/), [AWS AppSync](https://aws.amazon.com/it/appsync/), [Amazon CloudFront](https://aws.amazon.com/it/cloudfront/), or an [Application Load Balancer](https://aws.amazon.com/it/elasticloadbalancing/application-load-balancer/).

AWS WAF integrates with [Amazon CloudWatch][aws-cloudwatch], enabling users to monitor and visualize key metrics and log data related to their web applications and WAF rules. CloudWatch offers customizable dashboards, alerts, and automated actions, providing enhanced visibility into application security. [Learn more about AWS WAF monitoring](https://docs.aws.amazon.com/waf/latest/developerguide/logging.html)

[Azure Web Application Firewall (WAF)][azure-waf] that provides centralized protection of web applications from common exploits and vulnerabilities. WAF can be deployed with [Azure Application Gateway](/azure/web-application-firewall/ag/ag-overview), [Azure Front Door](/azure/web-application-firewall/afds/afds-overview), and [Azure Content Delivery Network (CDN)](/azure/web-application-firewall/cdn/cdn-overview) service from Microsoft. 

The Azure WAF comes with a preconfigured, platform-managed [OWASP (Open Web Application Security Project) ruleset](https://owasp.org/www-project-modsecurity-core-rule-set/) that provides protection against various types of attacks, including cross-site scripting and SQL injection. 

As a WAF administrator, you have the option to write your own [custom rules](/azure/web-application-firewall/ag/custom-waf-rules-overview) to enhance the core rule set (CRS) rules. Azure WAF also supports a [Bot Protection ruleset](/azure/web-application-firewall/ag/bot-protection-overview) that you can use to prevent bad bots from scraping, scanning, and looking for vulnerabilities in your web application. The Azure WAF can be configured to run in the following two modes:

- Detection mode: Monitors and logs all threat alerts. You turn on logging diagnostics for Application Gateway in the Diagnostics section. You must also make sure that the WAF log is selected and turned on. Web application firewall doesn't block incoming requests when it's operating in Detection mode.
- Prevention mode: Blocks intrusions and attacks that the rules detect. The attacker receives a "403 unauthorized access" exception, and the connection is closed. Prevention mode records such attacks in the WAF logs.

Azure Web Application Firewall (WAF) monitoring and logging are provided through logging and integration with Azure Monitor and Azure Monitor logs. You can configure your [Azure Application Gateway](/azure/web-application-firewall/ag/ag-overview), [Azure Front Door](/azure/web-application-firewall/afds/afds-overview), and [Azure Content Delivery Network (CDN)](/azure/web-application-firewall/cdn/cdn-overview) to use [Azure Web Application Firewall (WAF)][azure-waf] and store diagnostic logs and metrics to a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-overview). You can use the [Azure Monitor Metrics Explorer][azure-metrics-explorer]  to analyze the Azure WAF metrics and the [Kusto Query Language](/kusto/query) to create and run queries against the diagnostics logs collected in the Log Analytics workspace.

## Next steps

> [!div class="nextstepaction"]
> [Prepare to deploy web application workload to Azure][eks-web-rearchitect]

For more information about the differences between AKS and EKS, see the following articles:

- [Migrate from Amazon EKS to Azure Kubernetes Service (AKS)](/azure/architecture/aws-professional/eks-to-aks/migrate-eks-to-aks)
- [AKS for Amazon EKS professionals](/azure/architecture/aws-professional/eks-to-aks/)
- [Identity and access management](/azure/architecture/aws-professional/eks-to-aks/workload-identity)
- [Cluster logging and monitoring](/azure/architecture/aws-professional/eks-to-aks/monitoring)
- [Secure network topologies](/azure/architecture/aws-professional/eks-to-aks/private-clusters)
- [Storage options](/azure/architecture/aws-professional/eks-to-aks/storage)
- [Cost optimization and management](/azure/architecture/aws-professional/eks-to-aks/cost-management)
- [Agent node and node pool management](/azure/architecture/aws-professional/eks-to-aks/node-pools)
- [Cluster governance](/azure/architecture/aws-professional/eks-to-aks/governance)
- [Workload migration](/azure/architecture/aws-professional/eks-to-aks/migrate-eks-to-aks)
## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

- [Paolo Salvatori](https://www.linkedin.com/in/paolo-salvatori) | Principal Customer Engineer
- Dixit Arora | Senior Customer Engineer
- Ken Kilty | Principal TPM
- Russell de Pina | Principal TPM
- Erin Schaffer | Content Developer 2
- Carol Smith | Senior Content Developer

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
[promql]: https://prometheus.io/docs/prometheus/latest/querying/basics/