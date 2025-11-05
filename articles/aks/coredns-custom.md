---
title: Customize CoreDNS for Azure Kubernetes Service (AKS)
description: Learn how to customize CoreDNS to add subdomains, extend custom DNS endpoints, and change scaling logic using Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
author: schaffererin
ms.topic: how-to
ms.date: 09/08/2025
ms.author: schaffererin
# Customer intent: As a cluster operator or developer, I want to learn how to customize the CoreDNS configuration to add sub domains or extend to custom DNS endpoints within my network. I also want to learn how to customize the logic for CoreDNS pod scaling.
---

# Customize CoreDNS for Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) uses [CoreDNS][coredns] for cluster DNS management and resolution with all _1.12.x_ and higher clusters. AKS is a managed service, so you can't modify the main configuration for CoreDNS (a _CoreFile_). Instead, you use a Kubernetes _ConfigMap_ to override the default settings. To see the default AKS CoreDNS ConfigMaps, use the `kubectl get configmaps --namespace=kube-system coredns --output yaml` command.

This article shows you how to use ConfigMaps for basic CoreDNS customization options in Azure Kubernetes Service (AKS).

> [!NOTE]
> Previously, AKS used `kube-dns` for cluster DNS management and resolution, but it's now deprecated. `kube-dns` offered different [customization options][kubednsblog] via a Kubernetes config map. CoreDNS is **not** backwards compatible with `kube-dns`. You must update any previous customizations to work with CoreDNS.

## Prerequisites

- This article assumes that you have an existing AKS cluster. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- Verify the version of CoreDNS you're running. The configuration values might change between versions.

## Plugin support

All built-in CoreDNS plugins are supported. No add-on/third party plugins are supported.

> [!IMPORTANT]
> When you create configurations like the ones in this article, the names you specify in the `data` section must end in `.server` or `.override`. This naming convention is defined in the default AKS CoreDNS ConfigMap, which you can view using the `kubectl get configmaps --namespace=kube-system coredns --output yaml` command.

## Configure DNS name rewrites

1. Create a file named `corednsms.yaml` and paste in the following example configuration. Make sure to replace `<domain to be rewritten>` with your own fully qualified domain name (FQDN).

     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: coredns-custom
       namespace: kube-system
     data:
       test.server: |
         <domain to be rewritten>.com:53 {
         log
         errors
         rewrite stop {
           name regex (.*)\.<domain to be rewritten>\.com {1}.default.svc.cluster.local
           answer name (.*)\.default\.svc\.cluster\.local {1}.<domain to be rewritten>.com
         }
         forward . /etc/resolv.conf # You can redirect this to a specific DNS server such as 10.0.0.10, but that server must be able to resolve the rewritten domain name
         }
     ```

     > [!IMPORTANT]
     > If you redirect to a DNS server, such as the CoreDNS service IP, that DNS server must be able to resolve the rewritten domain name.

1. Create the ConfigMap using the [`kubectl apply configmap`][kubectl-apply] command and specify the name of your YAML manifest.

     ```bash
     kubectl apply -f corednsms.yaml
     ```

1. Verify the customizations were applied using the [`kubectl get configmaps`][kubectl-get] command.

     ```bash
     kubectl get configmaps --namespace=kube-system coredns-custom -o yaml
     ```

1. Perform a rolling restart to reload the ConfigMap and enable the Kubernetes Scheduler to restart CoreDNS without downtime using the [`kubectl rollout restart`][kubectl-rollout] command.

     ```bash
     kubectl --namespace kube-system rollout restart deployment coredns
     ```

## Specify a forward server for your network traffic

1. Create a file named `corednsms.yaml` and paste in the following example configuration. Make sure to replace the `forward` name and `<domain to be rewritten>` with your own values.

     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: coredns-custom
       namespace: kube-system
     data:
       test.server: | # You can select any name here, but it must end with the .server file extension
         <domain to be rewritten>.com:53 {
             forward foo.com 1.1.1.1
         }
     ```

1. Create the ConfigMap using the [`kubectl apply configmap`][kubectl-apply] command.

     ```bash
     kubectl apply -f corednsms.yaml
     ```

1. Perform a rolling restart to reload the ConfigMap and enable the Kubernetes Scheduler to restart CoreDNS without downtime using the [`kubectl rollout restart`][kubectl-rollout] command.

     ```bash
     kubectl --namespace kube-system rollout restart deployment coredns
     ```

## Use custom domains

You might want to configure custom domains that can only be resolved internally. For example, you might want to resolve the custom domain _puglife.local_, which isn't a valid top-level domain. Without a custom domain ConfigMap, the AKS cluster can't resolve the address.

1. Create a new file named `corednsms.yaml` and paste in the following example configuration. Make sure to update the custom domain and IP address with your own values.

     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: coredns-custom
       namespace: kube-system
     data:
       puglife.server: | # You can select any name here, but it must end with the .server file extension
         puglife.local:53 {
             errors
             cache 30
             forward . 192.11.0.1  # This is my test/dev DNS server
         }
     ```

1. Create the ConfigMap using the [`kubectl apply configmap`][kubectl-apply] command.

     ```bash
     kubectl apply -f corednsms.yaml
     ```

1. Perform a rolling restart to reload the ConfigMap and enable the Kubernetes Scheduler to restart CoreDNS without downtime using the [`kubectl rollout restart`][kubectl-rollout] command.

     ```bash
     kubectl --namespace kube-system rollout restart deployment coredns 
     ```

## Configure stub domains

1. Create a file named `corednsms.yaml` and paste the following example configuration. Make sure to update the custom domains and IP addresses with your own values.

     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: coredns-custom
       namespace: kube-system
     data:
       test.server: | # You can select any name here, but it must end with the .server file extension
         abc.com:53 {
          errors
          cache 30
          forward . 1.2.3.4
         }
         my.cluster.local:53 {
             errors
             cache 30
             forward . 2.3.4.5
         }

     ```

1. Create the ConfigMap using the [`kubectl apply configmap`][kubectl-apply] command and specify.

     ```bash
     kubectl apply -f corednsms.yaml
     ```

1. Perform a rolling restart to reload the ConfigMap and enable the Kubernetes Scheduler to restart CoreDNS without downtime using the [`kubectl rollout restart`][kubectl-rollout] command.

     ```bash
     kubectl --namespace kube-system rollout restart deployment coredns
     ```

## Add custom host-to-IP mappings

1. Create a file named `corednsms.yaml` and paste the following example configuration. Make sure to update the IP addresses and hostnames with your own values.

     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: coredns-custom # This is the name of the ConfigMap you can overwrite with your changes
       namespace: kube-system
     data:
         test.override: | # You can select any name here, but it must end with the .override file extension
               hosts { 
                   10.0.0.1 example1.org
                   10.0.0.2 example2.org
                   10.0.0.3 example3.org
                   fallthrough
               }
     ```

1. Create the ConfigMap using the [`kubectl apply configmap`][kubectl-apply] command.

     ```bash
     kubectl apply -f corednsms.yaml
     ```

1. Perform a rolling restart to reload the ConfigMap and enable the Kubernetes Scheduler to restart CoreDNS without downtime using the [`kubectl rollout restart`][kubectl-rollout] command.

     ```bash
     kubectl --namespace kube-system rollout restart deployment coredns
     ```

## Next steps

- To troubleshoot CoreDNS issues, see [Troubleshoot issues with CoreDNS on Azure Kubernetes Service (AKS)](./coredns-troubleshoot.md).
- To learn about CoreDNS autoscaling behavior, see [Autoscaling CoreDNS in Azure Kubernetes Service (AKS)](./coredns-autoscale.md).

<!-- LINKS - external -->
[kubednsblog]: https://www.danielstechblog.io/using-custom-dns-server-for-domain-specific-name-resolution-with-azure-kubernetes-service/
[coredns]: https://coredns.io/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-rollout]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout

<!-- LINKS - internal -->
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
