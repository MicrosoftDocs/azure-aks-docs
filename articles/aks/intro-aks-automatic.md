---
title: Introduction to Azure Kubernetes Service (AKS) Automatic (preview)
description: Simplify deployment and management of container-based applications in Azure by learning about the features and benefits of Azure Kubernetes Service Automatic.
ms.topic: overview
ms.custom: build-2024, biannual
ms.date: 06/13/2025
author: sabbour
ms.author: asabbour
#Customer intent: As a cluster administrator or developer, I want to simplify AKS cluster management and deployment by using preconfigured settings, built-in best practices, and automated features for production-ready applications.
---

# What is Azure Kubernetes Service (AKS) Automatic (preview)?

**Applies to:** :heavy_check_mark: AKS Automatic (preview)

Azure Kubernetes Service (AKS) Automatic offers an experience that makes the most common tasks on Kubernetes fast and frictionless, while preserving the flexibility, extensibility, and consistency of Kubernetes. Azure takes care of your cluster setup, including node management, scaling, security, and preconfigured settings that follow AKS well-architected recommendations. Automatic clusters dynamically allocate compute resources based on your specific workload requirements and are tuned for running production applications.

- **Production ready by default**: Clusters are preconfigured for optimal production use, suitable for most applications. They offer fully managed node pools that automatically allocate and scale resources based on your workload needs. Pods are bin packed efficiently, to maximize resource utilization.
  
- **Built-in best practices and safeguards**: AKS Automatic clusters have a hardened default configuration, with many cluster, application, and networking security settings enabled by default. AKS automatically patches your nodes and cluster components while adhering to any planned maintenance schedules.

- **Code to Kubernetes in minutes**: Go from a container image to a deployed application that adheres to best practices patterns within minutes, with access to the comprehensive capabilities of the Kubernetes API and its rich ecosystem.

## AKS Automatic and Standard feature comparison

The following table provides a comparison of options that are available, preconfigured, and default in both AKS Automatic and AKS Standard. For more information on whether specific features are available in Automatic, you can check the documentation for that feature.

**Pre-configured** features are always enabled and you can't disable or change their settings. **Default** features are configured for you but can be changed. **Optional** features are available for you to configure and aren't enabled by default.

When enabling optional features, you can follow the linked feature documentation. When you reach a step for cluster creation, follow steps to create an [AKS Automatic cluster][quickstart-aks-automatic] instead of creating an AKS Standard cluster.

### Application deployment, monitoring, and observability

Application deployment can be streamlined using [automated deployments][automated-deployments] from source control, which creates Kubernetes manifest and generates CI/CD workflows. Additionally, the cluster is configured with monitoring tools such as Managed Prometheus for metrics, Managed Grafana for visualization, and Container Insights for log collection.

| Option                    | AKS Automatic   	| AKS Standard  	|
|---	                    |---	            |---	            |
| Application deployment	        | **Optional:** <ul><li>Use [automated deployments][automated-deployments] to containerize applications from source control, create Kubernetes manifests, and continuous integration/continuous deployment (CI/CD) workflows.</li><li>Create deployment pipelines using [GitHub Actions for Kubernetes][kubernetes-action].</li><li>Bring your own CI/CD pipeline.</li></ul>  | **Optional:** <ul><li>Use [automated deployments][automated-deployments] to containerize applications from source control, create Kubernetes manifests, and continuous integration/continuous deployment (CI/CD) workflows.</li><li>Create deployment pipelines using [GitHub Actions for Kubernetes][kubernetes-action].</li><li>Bring your own CI/CD pipeline.</li></ul> |
| Monitoring, logging, and visualization       | **Default:** <ul><li>[Managed Prometheus][managed-prometheus] for metric collection when using Azure CLI or the Azure portal. </li><li>[Managed Grafana][managed-grafana] for visualization when using Azure CLI or the Azure portal.</li><li>[Container insights][container-insights] for log collection when using Azure CLI or the Azure portal.</li></ul>  | **Optional:** <ul><li>[Managed Prometheus][managed-prometheus] for metric collection.</li><li>[Managed Grafana][managed-grafana] for visualization.</li><li>[Container insights][container-insights] for log collection.</li></ul> |

### Node management, scaling, and cluster operations

Node management is automatically handled without the need for manual node pool creation. Scaling is seamless, with nodes created based on workload requests. Additionally, features for workload scaling like Horizontal Pod Autoscaler (HPA), [Kubernetes Event Driven Autoscaling (KEDA)][keda], and [Vertical Pod Autoscaler (VPA)][vpa] are enabled. Clusters are configured for automatic node repair, automatic cluster upgrades, and detection of deprecated Kubernetes standard API usage. You can also set a planned maintenance schedule for upgrades if needed.

| Option                    | AKS Automatic   	| AKS Standard  	|
|---	                    |---	            |---	            |
| Node management 	        | **Pre-configured:** AKS Automatic manages the node pools using [Node Autoprovisioning][node-autoprovisioning]. | **Default:** You create and manage system and user node pools <br/> **Optional:** AKS Standard manages user node pools using [Node Autoprovisioning][node-autoprovisioning]. |
| Scaling   	            | **Pre-configured:** AKS Automatic creates nodes based on workload requests using [Node Autoprovisioning][node-autoprovisioning]. <br/>[Horizontal Pod Autoscaler (HPA)][aks-hpa], [Kubernetes Event Driven Autoscaling (KEDA)][keda], and [Vertical Pod Autoscaler (VPA)][vpa] are enabled on the cluster. | **Default:** Manual scaling of node pools. <br/>  **Optional:** <ul><li>[Cluster autoscaler][cluster-autoscaler]</li><li>[Node Autoprovisioning][node-autoprovisioning]</li><li>[Kubernetes Event Driven Autoscaling (KEDA)][keda]</li><li>[Vertical Pod Autoscaler (VPA)][vpa]</li></ul>|
| Cluster tier	        | **Pre-configured:** Standard tier cluster with up to 5,000 nodes and a [cluster uptime Service Level Agreement (SLA)][uptime-sla]. |  **Default:** Free tier cluster with 10 nodes but can support up to 1,000 nodes. <br/> **Optional:** <ul><li>Standard tier cluster with up to 5,000 nodes and a [cluster uptime SLA][uptime-sla].</li><li>Premium tier cluster with up to 5,000 nodes, [cluster uptime Service Level Agreement (SLA)][uptime-sla], and [long term support][long-term-support].</li></ul> |
| Node operating system 	        | **Pre-configured:** [Azure Linux][azure-linux] | **Default:** Ubuntu <br/> **Optional:** <ul><li>[Azure Linux][azure-linux]</li><li>[Windows Server][windows-server]</li></ul> |
| Node resource group 	        | **Pre-configured:** Fully managed node resource group to prevent accidental or intentional changes to cluster resources. | **Default:** Unrestricted <br/> **Optional:** [Read only][nrg-lockdown]  with node resource group lockdown (preview) |
| Node auto-repair 	        | **Pre-configured:** Continuously monitors the health state of worker nodes and performs [automatic node repair][node-auto-repair] if they become unhealthy. |  **Pre-configured:** Continuously monitors the health state of worker nodes and performs [automatic node repair][node-auto-repair] if they become unhealthy.  |
| Cluster upgrades	        | **Pre-configured:** Clusters are [automatically upgraded][cluster-upgrades]. |  **Default:** Manual upgrade. <br/> **Optional:** Automatic upgrade using a selectable [upgrade channel][cluster-upgrade-channels].  |
| Kubernetes API breaking change detection 	        | **Pre-configured:** Cluster upgrades are stopped on detection of [deprecated Kubernetes standard API usage][stop-cluster-upgrade-api-breaking-changes]. |  **Pre-configured:** Cluster upgrades are stopped on detection of [deprecated Kubernetes standard API usage][stop-cluster-upgrade-api-breaking-changes].  |
| Planned maintenance windows	        | **Default:** Set [planned maintenance schedule][planned-maintenance] configuration to control upgrades. |  **Optional:** Set [planned maintenance schedule][planned-maintenance] configuration to control upgrades.  |

### Security and policies

Cluster authentication and authorization use [Azure Role-based Access Control (RBAC) for Kubernetes authorization][azure-rbac-for-k8s-auth] and applications can use features like [workload identity with Microsoft Entra Workload ID][workload-identity] and [OpenID Connect (OIDC) cluster issuer][oidc-issuer] to have secure communication with Azure services. [Deployment safeguards][deployment-safeguards] enforce Kubernetes best practices through Azure Policy controls and the built-in [image cleaner][image-cleaner] removes unused images with vulnerabilities, enhancing image security.

| Option                    | AKS Automatic   	| AKS Standard  	|
|---	                    |---	            |---	            |
| Cluster authentication and authorization	        | **Pre-configured:** [Azure RBAC for Kubernetes authorization][azure-rbac-for-k8s-auth] for managing cluster authentication and authorization using Azure role-based access control.  | **Default:** Local accounts. <br/> **Optional:** <ul><li>[Azure RBAC for Kubernetes authorization][azure-rbac-for-k8s-auth]</li><li>[Kubernetes RBAC with Microsoft Entra integration][k8s-rbac-with-entra]</li></ul> |
| Cluster security	        | **Pre-configured:** [API server virtual network integration][api-server-vnet-integration] enables network communication between the API server and the cluster nodes over a private network without requiring a private link or tunnel. | **Optional:** [API server virtual network integration][api-server-vnet-integration] enables network communication between the API server and the cluster nodes over a private network without requiring a private link or tunnel.|
| Application security	        | **Pre-configured:** <ul><li>[Workload identity with Microsoft Entra Workload ID][workload-identity]</li><li>[OpenID Connect (OIDC) cluster issuer][oidc-issuer]</li></ul> | **Optional:** <ul><li>[Workload identity with Microsoft Entra Workload ID][workload-identity]</li><li>[OpenID Connect (OIDC) cluster issuer][oidc-issuer]</li></ul> |
| Image security	        | **Pre-configured:** [Image cleaner][image-cleaner] to remove unused images with vulnerabilities. | **Optional:** [Image cleaner][image-cleaner] to remove unused images with vulnerabilities. |
| Policy enforcement	        | **Pre-configured:** [Deployment safeguards][deployment-safeguards] that enforce Kubernetes best practices in your AKS cluster through Azure Policy controls. | **Optional:** [Deployment safeguards][deployment-safeguards] enforce Kubernetes best practices in your AKS cluster through Azure Policy controls. |

### Networking

AKS Automatic clusters use [managed Virtual Network powered by Azure CNI Overlay with Cilium][azure-cni-powered-by-cilium] for high-performance networking and robust security. Ingress is handled by [managed NGINX using the application routing add-on][app-routing], integrating seamlessly with Azure DNS and Azure Key Vault. Egress uses a [managed NAT gateway][managed-nat-gateway] for scalable outbound connections. Additionally, you have the flexibility to enable [Istio-based service mesh add-on for AKS][istio-mesh] or bring your own service mesh.

| Option                    | AKS Automatic   	| AKS Standard  	|
|---	                    |---	            |---	            |
| Virtual network	        | **Default:** [Managed Virtual Network using Azure CNI Overlay powered by Cilium][azure-cni-powered-by-cilium] combines the robust control plane of Azure CNI with the data plane of Cilium to provide high-performance networking and security. <br/> **Optional:** <ul><li>[Custom virtual network][automatic-custom-network]</li><li>[Custom virtual network][automatic-private-custom-network] with private cluster.</li></ul> | **Default:** [Managed Virtual Network with kubenet][kubenet] <br/> **Optional:** <ul><li>[Azure CNI][azure-cni]</li><li>[Azure CNI Overlay][azure-cni-overlay]</li><li>[Azure CNI Overlay powered by Cilium][azure-cni-powered-by-cilium]</li><li>[Bring your own CNI][use-byo-cni]</li></ul> |
| Ingress	        | **Pre-configured:** [Managed NGINX using the application routing add-on][app-routing] with integrations for Azure DNS  and Azure Key Vault. <br/> **Optional:** <ul><li>[Istio-based service mesh add-on for AKS][istio-deploy-ingress] ingress gateway</li><li>Bring your own ingress or gateway.</li></ul> | **Optional:** <ul><li>[Managed NGINX using the application routing add-on][app-routing] with integrations for Azure DNS  and Azure Key Vault.</li><li>[Istio-based service mesh add-on for AKS][istio-deploy-ingress] ingress gateway</li><li>Bring your own ingress or gateway.</li></ul> |
| Egress	        | **Pre-configured:** [AKS managed NAT gateway][managed-nat-gateway] for a scalable outbound connection flows when used with managed virtual network <br/> **Optional (with custom virtual network):** <ul><li> [Azure Load Balancer][egress-load-balancer]</li><li>[User-assigned NAT gateway][managed-nat-gateway]</li><li>[User-defined routing (UDR)][udr]</li> | **Default:** [Azure Load Balancer][egress-load-balancer] <br/> **Optional:** <ul><li>[User-assigned NAT gateway][managed-nat-gateway]</li><li>[AKS managed NAT gateway][userassigned-nat-gateway]</li><li>[User-defined routing (UDR)][udr]</li></ul> |
| Service mesh	        | **Optional:** <ul><li>[Azure Service Mesh (Istio)][istio-mesh]</li><li>Bring your own service mesh.</li></ul> | **Optional:** <ul><li>[Azure Service Mesh (Istio)][istio-mesh]</li><li>Bring your own service mesh.</li></ul> |

## Next steps

To learn more about AKS Automatic, follow the quickstart to create a cluster.

> [!div class="nextstepaction"]
> [Quickstart: Deploy an Azure Kubernetes Service (AKS) Automatic cluster (preview)][quickstart-aks-automatic]

<!-- LINKS - internal -->
[aks-hpa]: tutorial-kubernetes-scale.md#autoscale-pods
[node-autoprovisioning]: node-autoprovision.md
[cluster-autoscaler]: cluster-autoscaler-overview.md
[vpa]: vertical-pod-autoscaler.md
[keda]: keda-about.md
[azure-linux]: use-azure-linux.md
[windows-server]: windows-vs-linux-containers.md
[nrg-lockdown]: node-resource-group-lockdown.md
[node-auto-repair]: node-auto-repair.md
[cluster-upgrades]: auto-upgrade-cluster.md
[cluster-upgrade-channels]: auto-upgrade-cluster.md?tabs=azure-cli#cluster-auto-upgrade-channels
[stop-cluster-upgrade-api-breaking-changes]: stop-cluster-upgrade-api-breaking-changes.md
[planned-maintenance]: planned-maintenance.md
[azure-rbac-for-k8s-auth]: manage-azure-rbac.md
[k8s-rbac-with-entra]: azure-ad-rbac.md
[workload-identity]: workload-identity-overview.md
[oidc-issuer]: use-oidc-issuer.md
[image-cleaner]: image-cleaner.md
[deployment-safeguards]: deployment-safeguards.md
[api-server-vnet-integration]: api-server-vnet-integration.md
[azure-cni-powered-by-cilium]: azure-cni-powered-by-cilium.md
[kubenet]: configure-kubenet.md
[azure-cni]: configure-azure-cni.md
[azure-cni-overlay]: azure-cni-overlay.md
[use-byo-cni]: use-byo-cni.md
[app-routing]: app-routing.md
[istio-deploy-ingress]: istio-deploy-ingress.md
[managed-nat-gateway]: nat-gateway.md#create-an-aks-cluster-with-a-managed-nat-gateway
[userassigned-nat-gateway]: nat-gateway.md#create-an-aks-cluster-with-a-user-assigned-nat-gateway
[udr]: egress-outboundtype.md#outbound-type-of-userdefinedrouting
[egress-load-balancer]: egress-outboundtype.md#outbound-type-of-loadbalancer
[istio-mesh]: istio-about.md
[automated-deployments]: automated-deployments.md
[kubernetes-action]: kubernetes-action.md
[managed-prometheus]: /azure/azure-monitor/essentials/prometheus-metrics-overview
[managed-grafana]: /azure/managed-grafana/overview
[container-insights]: /azure/azure-monitor/containers/container-insights-overview
[uptime-sla]: free-standard-pricing-tiers.md#uptime-sla-terms-and-conditions
[long-term-support]: long-term-support.md
[quickstart-aks-automatic]: ./learn/quick-kubernetes-automatic-deploy.md
[automatic-custom-network]: ./automatic/quick-automatic-custom-network.md
[automatic-private-custom-network]: ./automatic/quick-automatic-private-custom-network.md
