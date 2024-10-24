---
title: Rearchitect AWS EKS Web Application for Azure Kubernetes Service (AKS)
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

# Rearchitect AWS EKS Web Application for Azure Kubernetes Service (AKS)

Now that you have gained an understanding of the platform differences between AWS and Azure that are relevant to this workload, let's examine the web application architecture and explore the necessary modifications to make it compatible with AKS.

## Yelb Application

The current architecture layout of the [Yelb][yelb] sample web application consists of a front-end component called `yelb-ui` and an application component called `yelb-appserver`.

:::image type="content" source="media/eks-web-rearchitect/yelb-architecture.png" alt-text="Architecture diagram of the Yel web application.":::

The `yelb-ui` is responsible for serving the JavaScript code to the browser. This code is compiled from an Angular 2 application. Depending on the deployment model, the code can be served from an EC2 instance, a container (Docker, Kubernetes, ECS), or an S3 bucket (serverless). The `yelb-ui` component may also include an `nginx` proxy, depending on the deployment model. The `yelb-appserver` is a [Sinatra](https://sinatrarb.com/) application that interacts with a cache server (`redis-server`) and a Postgres backend database (`yelb-db`). Redis is used to store the number of page views, while Postgres is used to persist the votes. In the serverless deployment model, DynamoDB is used as a replacement for both redis and postgres.

Yelb allows users to vote on a set of alternatives (restaurants) and dynamically updates pie charts based on the number of votes received. 

:::image type="content" source="media/eks-web-rearchitect/yelb-ui.png" alt-text="Screenshot of the Yelb service interface.":::

The Yelb application also keeps track of the number of page views and displays the hostname of the `yelb-appserver` instance serving the API request upon a vote or a page refresh. This allows individuals to demo the application solo or involve others in interacting with the application.

## Architecture on AWS

In order to easily protect web applications and APIs from common web exploits, AWS offers [AWS Web Application Firewall (WAF)][aws-waf] and [AWS Firewall Manager][aws-firewall-manager]. These services allow you to monitor HTTP(S) requests and defend against DDoS attacks, bots, and common attack patterns such as SQL injection or cross-site scripting.

To demonstrate the implementation of a web application firewall using [AWS Web Application Firewall (WAF)][aws-waf] to safeguard applications running on [Amazon Elastic Kubernetes Service (EKS)][aws-eks], the following solution can be followed:

1. Create an EKS cluster and deploy a sample workload.
2. Expose the sample application using an [Application Load Balancer (ALB)][aws-alb].
3. Create a [Kubernetes ingress][kubernetes-ingress] and associate an [AWS WAF web access control list (web ACL)][aws-web-acl] with the ALB in front of the ingress.

AWS WAF provides control over the type of traffic that reaches your web applications, ensuring protection against unauthorized access attempts and unwanted traffic. It integrates seamlessly with [Amazon CloudFront][aws-cloudfront], [Application Load Balancer (ALB)][aws-alb], [Amazon API Gateway][aws-api-gateway], and [AWS AppSync][aws-appsync]. By leveraging an existing ALB as an ingress for Kubernetes-hosted applications, adding a web application firewall to your apps can be accomplished quickly.

For customers operating in multiple AWS accounts, [AWS Organizations][aws-organizations] and [AWS Firewall Manager][aws-firewall-manager] offer centralized control over AWS WAF rules. With Firewall Manager, security policies can be enforced across accounts to ensure compliance and adherence to best practices. It is recommended to run EKS clusters in dedicated Virtual Private Clouds (VPCs), and Firewall Manager can ensure that WAF rules are correctly applied across accounts, regardless of where your applications run.

By implementing these measures, the [Yelb][yelb] can be effectively deployed on [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) and protected by [AWS WAF][aws-waf] safeguarding web-based workloads and ensuring a secure and reliable user experience.

:::image type="content" source="media/eks-web-rearchitect/architecture-on-aws.png" alt-text="Architecture diagram of the Yelb web application in AWS.":::

For more information, see [Protecting your Amazon EKS web apps with AWS WAF](https://aws.amazon.com/blogs/containers/protecting-your-amazon-eks-web-apps-with-aws-waf/).


## Map AWS services to Azure services

To recreate the AWS workload in Azure with minimal changes, use an Azure equivalent for each AWS service. The following table summarizes the service mapping:

| **Service mapping** |       **AWS service**                         |     **Azure service**    |
|:--------------------|:----------------------------------------------|:-------------------------|
| Queuing             | [AWS Web Application Firewall (WAF)][aws-waf] | [Azure Queue Storage][azure-queue-storage]      |
| Persistence         | DynamoDB (No SQL)                             | [Azure Table storage][azure-table-storage]      |
| Orchestration       | [Elastic Kubernetes Service (EKS)][aws-eks]   | [Azure Kubernetes Service (AKS)][aks] |
| Identity | AWS IAM | [Microsoft Entra][microsoft-entra] |


<!-- LINKS -->
[yelb]: https://github.com/mreferre/yelb/
[aws-waf]: https://aws.amazon.com/waf/
[aws-firewall-manager]: https://aws.amazon.com/firewall-manager/
[aws-eks]: https://docs.aws.amazon.com/en_us/eks/latest/userguide/what-is-eks.html
[aws-alb]: https://aws.amazon.com/elasticloadbalancing/application-load-balancer
[aws-web-acl]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html
[aws-cloudfront]: https://aws.amazon.com/cloudfront
[aws-api-gateway]: https://aws.amazon.com/api-gateway
[aws-appsync]: https://aws.amazon.com/appsync
[aws-organizations]: https://aws.amazon.com/organizations
[kubernetes-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[aks]: ./what-is-aks.md