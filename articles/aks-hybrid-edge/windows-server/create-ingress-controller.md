---
title: Use an ingress controller in AKS on Windows Server
description: Learn how to deploy an ingress controller in Azure Kubernetes Service in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: EkeleAsonye
ms.custom: windows-server
---

# Deploy an ingress controller

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

An *ingress controller* is a Kubernetes resource that allows external access to services within the Kubernetes cluster. Ingress lets an operator expose a service to external network requests, usually HTTP or HTTPS. You configure access by creating a set of rules that define the inbound connections that reach specific services.

An ingress controller is software that provides configurable traffic routing for Kubernetes services. Kubernetes ingress resources are used to configure the ingress rules and routes for individual Kubernetes services. By using an ingress controller and ingress rules, you can use a single IP address to route traffic to multiple services in a Kubernetes cluster.

After you deploy the controller in your environment, you can then create and deploy the ingress manifest. Currently, you use ingress in AKS by using the NGINX ingress controller. For information about how to install, configure, and use the NGINX ingress controller, see [Installation with Manifests](https://kubernetes.github.io/ingress-nginx/deploy/#azure).

Ingress differs from the [NodePort and LoadBalancer](concepts-container-networking.md#kubernetes-services) in a unique way, and it improves traffic routing to your cluster in a less costly way. Defining NodePort services creates numerous random ports, and defining LoadBalancer services increases the cost for cloud resources more than you might want. When you define an ingress controller, you consolidate the traffic-routing rules into a single resource that runs as part of your cluster. The NodePort and LoadBalancer let you expose a service by specifying that value in the service's type, whereas ingress is an independent resource for the service. Ingress is defined, created, and destroyed separately from the service.

You can deploy ingress in various ways depending on the use case. Ingress resources are used to update the configuration within the ingress controller to determine how it functions.

## Use ingress to expose services through externally reachable URLs

An example of using ingress is shown in the following YAML manifest. The `ingress.class` appears within the metadata (in this example, `ingress-nginx`), and this setting lets the NGINX ingress controller know what it needs to monitor and update:

```yaml
apiVersion: networking.k8s.io/v1  
kind: Ingress  
metadata: 
      name: hello-world
      annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /
        kubernetes.io/ingress.class: "nginx"
  spec:  
      rules:
       - host: test.example.com
          http:
             paths: 
             - path: /hello-world
pathType: Prefix
backend:
    service: 
         name: hello-world 
                    port:  
                     number: 8080
```

The `spec` section provides information about what's configured. In this example, a rule (or set of rules) is defined and includes the following items:

- The host to which the rules are applied.
- Whether the traffic is HTTP or HTTPS.
- The monitored path.
- The internal service and port where the traffic is sent.

## Use ingress to load balance traffic

In the following example, another path is added to the manifest that permits load balancing between different backends of an application. In this example, the operator can split traffic and send it to different service endpoints and deployments based on the path described. Behind each path is a deployment and a service, which is helpful for endpoints that receive more traffic:

```yaml
apiVersion: networking.k8s.io/v1  
kind: Ingress  
metadata: 
      name: hello-world-and-earth
      annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /
  spec:  
      rules:
       - host: test.example.com
          http:
             paths: 
             - path: /hello-world
pathType: Prefix
backend:
    service: 
         name: hello-world 
                    port:  
                     number: 8080
               - path: /hello-earth
pathType: Prefix
backend:
    service: 
         name: hello-earth 
                    port:  
                     number: 8080
```

## Use ingress to route HTTP traffic to multiple host names on the same IP address

You can use a different ingress resource for each host, which lets you control the traffic with multiple host names. To use a different ingress resource, point multiple host names at the same public IP address that's used for the LoadBalancer service. In the following manifest file, a production version of `hello-world` was added. The hostname `prod.example.com` is used, and traffic is pointed to the new service `hello-world-prod`. Traffic comes in through the load balancer IP address and is routed based on the host name and the path that you provide:

```yaml
apiVersion: networking.k8s.io/v1  
kind: Ingress  
metadata: 
      name: hello-world-prod
      annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /
  spec:  
      rules:
       - host: test.example.com
          http:
             paths: 
             - path: /hello-world
pathType: Prefix
backend:
    service: 
         name: hello-world-test 
                    port:  
                     number: 8080
       - host: prod.example.com
          http:
              paths:
               - path: /hello-world
pathType: Prefix
backend:
    service: 
         name: hello-world-prod 
                    port:  
                     number: 8080
```

## Next steps

For more information, see the following links:

- [Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- [NGINX ingress controller](https://github.com/kubernetes/ingress-nginx)
