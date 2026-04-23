---
title: Introduction to Azure Kubernetes Service (AKS) Automatic
description: Simplify deployment and management of container-based applications in Azure by learning about the features and benefits of Azure Kubernetes Service Automatic.
ms.topic: overview
ms.custom: build-2024, biannual
ms.date: 04/13/2026
author: wangyira
ms.author: wangamanda
#Customer intent: As a cluster administrator or developer, I want to simplify AKS cluster management and deployment by using preconfigured settings, built-in best practices, and automated features for production-ready applications.
---

# What is Azure Kubernetes Service (AKS) Automatic?

**Applies to:** :heavy_check_mark: AKS Automatic

Azure Kubernetes Service (AKS) Automatic offers an experience that makes the most common tasks on Kubernetes fast and frictionless, while preserving the flexibility, extensibility, and consistency of Kubernetes. Azure takes care of your cluster setup, including node management, scaling, security, and preconfigured settings that follow AKS well-architected recommendations. Automatic clusters dynamically allocate compute resources based on your specific workload requirements and are tuned for running production applications.

- **Production ready by default**: Clusters are preconfigured for optimal production use, suitable for most applications. They offer fully managed node pools that automatically allocate and scale resources based on your workload needs. Pods are bin packed efficiently, to maximize resource utilization.

- **Guaranteed pod readiness**: AKS Automatic includes a [pod readiness SLA][azure-sla] that guarantees 99.9% of qualifying pod readiness operations complete within 5 minutes. This means your workloads start running promptly during scaling events and node provisioning, giving you confidence in your application's responsiveness without manual tuning.
  
- **Built-in best practices and safeguards**: AKS Automatic clusters have a hardened default configuration, with many cluster, application, and networking security settings enabled by default. AKS automatically patches your nodes and cluster components while adhering to any planned maintenance schedules.

- **Code to Kubernetes in minutes**: Go from a container image to a deployed application that adheres to best practices patterns within minutes, with access to the comprehensive capabilities of the Kubernetes API and its rich ecosystem.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## AKS Automatic and Standard feature comparison

The following table provides a comparison of options that are available, preconfigured, and default in both AKS Automatic and AKS Standard. For more information on whether specific features are available in Automatic, you can check the documentation for that feature.

**Preconfigured** features are always enabled and you can't disable or change their settings. **Default** features are configured for you but can be changed. **Optional** features are available for you to configure and aren't enabled by default.

When enabling optional features, you can follow the linked feature documentation. When you reach a step for cluster creation, follow steps to create an [AKS Automatic cluster][quickstart-aks-automatic] instead of creating an AKS Standard cluster.

### Application deployment, monitoring, and observability

Application deployment can be streamlined using [automated deployments][automated-deployments] from source control, which creates Kubernetes manifest and generates CI/CD workflows. Additionally, the cluster is configured with monitoring tools such as Managed Prometheus for metrics, Managed Grafana for visualization, and Container Insights for log collection.

| Option | AKS Automatic | AKS Standard |
|--------|---------------|--------------|
| Application deployment | **Optional**: <br> * Use [automated deployments][automated-deployments] to containerize applications from source control, create Kubernetes manifests, and continuous integration/continuous deployment (CI/CD) workflows. <br> * Create deployment pipelines using [GitHub Actions for Kubernetes][kubernetes-action]. <br> * Bring your own CI/CD pipeline. | **Optional**: <br> * Use [automated deployments][automated-deployments] to containerize applications from source control, create Kubernetes manifests, and continuous integration/continuous deployment (CI/CD) workflows. <br> * Create deployment pipelines using [GitHub Actions for Kubernetes][kubernetes-action]. <br> * Bring your own CI/CD pipeline. |
| Monitoring, logging, and visualization | **Default**: <br> * [Managed Prometheus][managed-prometheus] for metric collection when using Azure CLI or the Azure portal. <br> * [Container insights][container-insights] for log collection when using Azure CLI or the Azure portal. <br> * [Azure Monitor Dashboards with Grafana](/azure/azure-monitor/visualize/visualize-use-grafana-dashboards) for visualization is built in when using the Azure portal. <br> * [Advanced Container Networking Services](advanced-container-networking-services-overview.md) container network observability for pod metrics, DNS, L4 metrics, and network flow logs when using the Azure portal. <br> **Optional**: <br> * [Managed Grafana][managed-grafana] for visualization when using Azure CLI or the Azure portal. | **Default**: [Azure Monitor Dashboards with Grafana](/azure/azure-monitor/visualize/visualize-use-grafana-dashboards) for visualization is built in when using the Azure portal. <br> **Optional**: <br> * [Managed Prometheus][managed-prometheus] for metric collection. <br> * [Managed Grafana][managed-grafana] for visualization. <br> * [Container insights][container-insights] for log collection. <br> * [Advanced Container Networking Services](advanced-container-networking-services-overview.md) container network observability for pod metrics, DNS, L4 metrics, and network flow logs.

### Node management, scaling, and cluster operations

Node management is automatically handled without the need for manual user node pool creation, [system node pools and components are managed][managed-system-node-pool] by AKS. Scaling is seamless, with nodes created based on workload requests. Additionally, features for workload scaling like Horizontal Pod Autoscaler (HPA), [Kubernetes Event Driven Autoscaling (KEDA)][keda], and [Vertical Pod Autoscaler (VPA)][vpa] are enabled. The [pod readiness SLA][azure-sla] that guarantees 99.9% of pod readiness operations complete within 5 minutes. Clusters are configured for automatic node repair, automatic cluster upgrades, and detection of deprecated Kubernetes standard API usage. You can also set a planned maintenance schedule for upgrades if needed.

| Option | AKS Automatic | AKS Standard |
|--------|---------------|--------------|
| Node management | **Preconfigured**: AKS Automatic manages the node pools using [Node Autoprovisioning][node-autoprovisioning]. <br> **Optional**: [AKS Automatic with managed system node pools][managed-system-node-pool] creates, scales, upgrades the system nodes and system components on your behalf and host them in the AKS subscriptions. | **Default**: You create and manage system and user node pools <br> **Optional**: AKS Standard manages user node pools using [Node Autoprovisioning][node-autoprovisioning]. |
| Scaling | **Preconfigured**: AKS Automatic creates nodes based on workload requests using [Node Autoprovisioning][node-autoprovisioning]. <br> [Horizontal Pod Autoscaler (HPA)][aks-hpa], [Kubernetes Event Driven Autoscaling (KEDA)][keda], and [Vertical Pod Autoscaler (VPA)][vpa] are enabled on the cluster. | **Default:** Manual scaling of node pools. <br> **Optional**: <br> * [Cluster autoscaler][cluster-autoscaler] <br> * [Node Autoprovisioning][node-autoprovisioning] <br> * [Kubernetes Event Driven Autoscaling (KEDA)][keda] <br> * [Vertical Pod Autoscaler (VPA)][vpa] |
| Cluster tier and Service Level Agreement (SLA) | **Preconfigured**: Standard tier cluster with up to 5,000 nodes, a [cluster uptime SLA][uptime-sla], and a [pod readiness SLA][azure-sla] that guarantees 99.9% of qualifying pod readiness operations complete within 5 minutes. |  **Default**: Free tier cluster with 10 nodes but can support up to 1,000 nodes. <br/> **Optional**: <br> * Standard tier cluster with up to 5,000 nodes and a [cluster uptime SLA][uptime-sla]. <br> * Premium tier cluster with up to 5,000 nodes, [cluster uptime SLA][uptime-sla], and [long term support][long-term-support]. |
| Node operating system | **Preconfigured for system node pool**: [Azure Linux][azure-linux] <br> **Optional for user nodes**: <br> * [Azure Linux][azure-linux] <br> * Ubuntu | **Default**: Ubuntu <br> **Optional**: <br> * [Azure Linux][azure-linux] <br> * [Windows Server][windows-server] |
| Node resource group | **Preconfigured**: [Fully managed node resource group][nrg-lockdown] to prevent accidental or intentional changes to cluster resources. | **Default**: Unrestricted <br/> **Optional**: [Read only][nrg-lockdown]  with node resource group lockdown |
| Node auto-repair | **Preconfigured**: Continuously monitors the health state of worker nodes and performs [automatic node repair][node-auto-repair] if they become unhealthy. |  **Preconfigured**: Continuously monitors the health state of worker nodes and performs [automatic node repair][node-auto-repair] if they become unhealthy.  |
| Cluster upgrades | **Preconfigured**: Clusters are [automatically upgraded using the stable channel][cluster-upgrade-channels] to minor version N-1, where N is the latest supported minor version. |  **Default**: Manual upgrade. <br> **Optional**: Automatic upgrade using a selectable [upgrade channel][cluster-upgrade-channels].  |
| Node OS image upgrades | **Preconfigured**: Clusters are [automatically upgraded using the NodeImage channel][nodeos-updates] with security fixes and bug fixes. | **Default**: Manual upgrade. <br> **Optional**: Automatic upgrade using a selectable [node OS upgrade channel][nodeos-updates]|
| Kubernetes API breaking change detection | **Preconfigured**: Cluster upgrades are stopped on detection of [deprecated Kubernetes standard API usage][stop-cluster-upgrade-api-breaking-changes]. |  **Preconfigured**: Cluster upgrades are stopped on detection of [deprecated Kubernetes standard API usage][stop-cluster-upgrade-api-breaking-changes].  |
| Planned maintenance windows | **Default**: Set [planned maintenance schedule][planned-maintenance] configuration to control upgrades. |  **Optional**: Set [planned maintenance schedule][planned-maintenance] configuration to control upgrades.  |

### Security and policies

Cluster authentication and authorization use [Azure Role-based Access Control (RBAC) for Kubernetes authorization][azure-rbac-for-k8s-auth] and applications can use features like [workload identity with Microsoft Entra Workload ID][workload-identity] and [OpenID Connect (OIDC) cluster issuer][oidc-issuer] to have secure communication with Azure services. [Deployment safeguards][deployment-safeguards] enforce Kubernetes best practices through Azure Policy controls and the built-in [image cleaner][image-cleaner] removes unused images with vulnerabilities, enhancing image security.

| Option | AKS Automatic | AKS Standard |
|--------|---------------|--------------|
| Cluster authentication and authorization | **Preconfigured**: [Azure RBAC for Kubernetes authorization][azure-rbac-for-k8s-auth] for managing cluster authentication and authorization using Azure role-based access control.  | **Default**: Local accounts. <br/> **Optional**: <br> * [Azure RBAC for Kubernetes authorization][azure-rbac-for-k8s-auth] <br> * [Kubernetes RBAC with Microsoft Entra integration][k8s-rbac-with-entra] |
| Cluster security | **Preconfigured**: [API server virtual network integration][api-server-vnet-integration] enables network communication between the API server and the cluster nodes over a private network without requiring a private link or tunnel. | **Optional**: [API server virtual network integration][api-server-vnet-integration] enables network communication between the API server and the cluster nodes over a private network without requiring a private link or tunnel.|
| Application security | **Preconfigured**: <br> * [Workload identity with Microsoft Entra Workload ID][workload-identity] <br> * [OpenID Connect (OIDC) cluster issuer][oidc-issuer] <br/> **Optional**:<br> * [Advanced Container Networking Services](container-network-security-wireguard-encryption-concepts.md) container network security for pod traffic with Wireguard node encryption| **Optional**: <br> * [Workload identity with Microsoft Entra Workload ID][workload-identity] <br> * [OpenID Connect (OIDC) cluster issuer][oidc-issuer] <br/> **Optional**:<br> * [Advanced Container Networking Services ](container-network-security-wireguard-encryption-concepts.md) container network security for pod traffic with Wireguard node encryption|
| Image security | **Preconfigured**: [Image cleaner][image-cleaner] to remove unused images with vulnerabilities. | **Optional**: [Image cleaner][image-cleaner] to remove unused images with vulnerabilities. |
| Policy enforcement | **Preconfigured**: [Deployment safeguards][deployment-safeguards] that enforce Kubernetes best practices in your AKS cluster through Azure Policy controls in enforcement mode, which cannot be turned off. <br/> **Optional**:<br> * [Advanced Container Networking Services](how-to-apply-l7-policies.md) container network security for Cilium DNS and L7 policies. | **Optional**: [Deployment safeguards][deployment-safeguards] enforce Kubernetes best practices in your AKS cluster through Azure Policy controls in enforcement mode or warning mode. <br/> **Optional**:<br> * [Advanced Container Networking Services ](how-to-apply-l7-policies.md) container network security for Cilium DNS and L7 policies |
| Managed namespaces | **Optional**: Use [Managed namespaces](./managed-namespaces.md) to create preconfigured namespaces where you can define network policies for ingress/egress, resource quotas for memory/CPU, and set-up labels/annotations. | **Optional**: Use [Managed namespaces](./managed-namespaces.md) to create preconfigured namespaces where you can define network policies for ingress/egress, resource quotas for memory/CPU, and set-up labels/annotations. |

### Networking

AKS Automatic clusters use [managed Virtual Network powered by Azure CNI Overlay with Cilium][azure-cni-powered-by-cilium] for high-performance networking and robust security. Ingress is handled by [managed NGINX using the application routing add-on][app-routing], integrating seamlessly with Azure DNS and Azure Key Vault. Egress uses a [managed NAT gateway][managed-nat-gateway] for scalable outbound connections. Additionally, you have the flexibility to enable [Istio-based service mesh add-on for AKS][istio-mesh] or bring your own service mesh.

| Option | AKS Automatic | AKS Standard |
|--------|---------------|--------------|
| Virtual network | **Default**: [Managed Virtual Network using Azure CNI Overlay powered by Cilium][azure-cni-powered-by-cilium] combines the robust control plane of Azure CNI with the data plane of Cilium to provide high-performance networking and security. <br/> **Optional**: <br> * [Custom virtual network][automatic-custom-network] <br> * [Custom virtual network][automatic-private-custom-network] with private cluster. | **Default**: [Managed Virtual Network with kubenet][kubenet] <br/> **Optional**: <br> * [Azure CNI][azure-cni] <br> * [Azure CNI Overlay][azure-cni-overlay] <br> * [Azure CNI Overlay powered by Cilium][azure-cni-powered-by-cilium] <br> * [Bring your own CNI][use-byo-cni] |
| Ingress | **Preconfigured**: [Managed NGINX using the application routing add-on][app-routing] with integrations for Azure DNS and Azure Key Vault. <br/> **Optional**: <br> * [Istio-based service mesh add-on for AKS][istio-deploy-ingress] ingress gateway <br> * Bring your own ingress or gateway. | **Optional**: <br> * [Managed NGINX using the application routing add-on][app-routing] with integrations for Azure DNS and Azure Key Vault. <br> * [Istio-based service mesh add-on for AKS][istio-deploy-ingress] ingress gateway <br> * Bring your own ingress or gateway. |
| Egress | **Preconfigured**: [AKS managed NAT gateway][managed-nat-gateway] for a scalable outbound connection flows when used with managed virtual network <br> **Optional (with custom virtual network)**: <br> * [Azure Load Balancer][egress-load-balancer] <br> * [User-assigned NAT gateway][managed-nat-gateway] <br> * [User-defined routing (UDR)][udr] | **Default**: [Azure Load Balancer][egress-load-balancer] <br> **Optional**: <br> * [User-assigned NAT gateway][managed-nat-gateway] <br> * [AKS managed NAT gateway][userassigned-nat-gateway] <br> * [User-defined routing (UDR)][udr] |
| Service mesh | **Optional**: <br> * [Azure Service Mesh (Istio)][istio-mesh] <br> * Bring your own service mesh. | **Optional**: <br> * [Azure Service Mesh (Istio)][istio-mesh] <br> * Bring your own service mesh. |

### Pod Readiness SLA

AKS Automatic includes a [pod readiness SLA][azure-sla], a financially backed guarantee that 99.9% of qualifying pod readiness operations complete within 5 minutes. This SLA covers pod scheduling and node provisioning when needed.

The pod readiness SLA benefits workloads that depend on predictable scaling behavior, such as:

- **Web and API workloads** that need to scale out quickly during traffic spikes without degrading response times.
- **Event-driven processing** where new consumer pods must be ready promptly to avoid message backlog.
- **CI/CD and batch jobs** that require consistent pod startup times for reliable pipeline execution.

This guarantee is exclusive to AKS Automatic and is backed by the [Microsoft Online Services SLA][azure-sla]. You don't need to configure anything to enable it and it comes included with every AKS Automatic cluster.

## Next steps

To learn more about AKS Automatic, follow the quickstart to create a cluster.

> [!div class="nextstepaction"]
> [Quickstart: Deploy an Azure Kubernetes Service (AKS) Automatic cluster][quickstart-aks-automatic]

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
[cluster-upgrade-channels]: auto-upgrade-cluster.md#cluster-autoupgrade-channels
[nodeos-updates]: auto-upgrade-node-os-image.md#available-node-os-upgrade-channels
[stop-cluster-upgrade-api-breaking-changes]: stop-cluster-upgrade-api-breaking-changes.md
[planned-maintenance]: planned-maintenance.md
[azure-rbac-for-k8s-auth]: entra-id-authorization.md
[k8s-rbac-with-entra]: kubernetes-rbac-entra-id.md
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
[azure-sla]: https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services
[managed-system-node-pool]: ./automatic/aks-automatic-managed-system-node-pools-about.md#key-features-and-benefits
[nrg-lockdown]: node-resource-group-lockdown.md