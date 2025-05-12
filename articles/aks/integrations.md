---
title: Add-ons, extensions, and other integrations with Azure Kubernetes Service (AKS)
description: Learn about the add-ons, extensions, and open-source integrations you can use with Azure Kubernetes Service (AKS).
ms.topic: overview
ms.subservice: aks-integration
ms.date: 05/22/2023
author: nickomang
ms.author: nickoman

---

# Add-ons, extensions, and other integrations with Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) provides extra functionality for your clusters using add-ons and extensions. Open-source projects and third parties provide by more integrations that are commonly used with AKS. The [AKS support policy][aks-support-policy] doesn't support the open-source and third-party integrations.

## Add-ons

Add-ons are a fully supported way to provide extra capabilities for your AKS cluster. The installation, configuration, and lifecycle of add-ons are managed on AKS. You can use the [`az aks enable-addons`][az-aks-enable-addons] command to install an add-on or manage the add-ons for your cluster.

AKS uses the following rules for applying updates to installed add-ons:

- Only an add-on's patch version can be upgraded within a Kubernetes minor version. The add-on's major/minor version isn't upgraded within the same Kubernetes minor version.
- The major/minor version of the add-on is only upgraded when moving to a later Kubernetes minor version.
- Any breaking or behavior changes to the add-on are announced well before, usually 60 days, for a GA minor version of Kubernetes on AKS.
- You can patch add-ons weekly with every new release of AKS, which is announced in the release notes. You can control AKS releases using the [maintenance windows][maintenance-windows] and [release tracker][release-tracker].

### Exceptions

- Add-ons are upgraded to a new major/minor version (or breaking change) within a Kubernetes minor version if either the cluster's Kubernetes version or the add-on version are in preview.
- There can be unavoidable circumstances, such as CVE security patches or critical bug fixes, when you need to update an add-on within a GA minor version.

### Available add-ons

| Name | Description | Articles | GitHub |
|---|---|---| --- |
| ingress-appgw | Use Application Gateway Ingress Controller with your AKS cluster. | [What is Application Gateway Ingress Controller?][agic] | [GitHub][agic-repo] |
| keda | Use event-driven autoscaling for the applications on your AKS cluster. | [Simplified application autoscaling with Kubernetes Event-driven Autoscaling (KEDA) add-on][keda] | [GitHub][keda-repo] |
| monitoring | Use Container Insights and Managed Prometheus monitoring with your AKS cluster. | [Container insights overview][container-insights]<br>[Managed Prometheus overview][managed-prometheus] | [GitHub][aks-repo]<br>[GitHub][managed-prometheus-repo] |
| azure-policy | Use Azure Policy for AKS, which enables at-scale enforcements and safeguards on your clusters in a centralized, consistent manner. | [Understand Azure Policy for Kubernetes clusters][azure-policy-aks] | [GitHub][azure-policy-repo] |
| azure-keyvault-secrets-provider | Use Azure Keyvault Secrets Provider addon.| [Use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster][keyvault-secret-provider] | [GitHub][keyvault-secret-provider-repo] |
| virtual-node | Use virtual nodes with your AKS cluster. | [Use virtual nodes][virtual-nodes] | [GitHub][virtual-nodes-oss-repo] |
| open-service-mesh | Use Open Service Mesh with your AKS cluster (retired). | [Open Service Mesh AKS add-on (retired)][osm] | [GitHub][osm-repo] |

## Extensions

Cluster extensions build on top of certain Helm charts and provide an Azure Resource Manager-driven experience for installation and lifecycle management of different Azure capabilities on top of your Kubernetes cluster.

- For more information on the specific cluster extensions for AKS, see [Deploy and manage cluster extensions for Azure Kubernetes Service (AKS)][cluster-extensions].
- For more information on available cluster extensions, see [Currently available extensions][cluster-extensions-current].

### Difference between extensions and add-ons

Extensions and add-ons are both supported ways to add functionality to your AKS cluster. When you install an add-on, the functionality is added as part of the AKS resource provider in the Azure API. When you install an extension, the functionality is added as part of a separate resource provider in the Azure API.

## GitHub Actions

GitHub Actions help you automate your software development workflows from within GitHub.

- For more information on using GitHub Actions with Azure, see [GitHub Actions for Azure][github-actions].
- For an example of using GitHub Actions with an AKS cluster, see [Build, test, and deploy containers to Azure Kubernetes Service using GitHub Actions][github-actions-aks].

## Open-source and third-party integrations

There are many open-source and third-party integrations you can install on your AKS cluster. The [AKS support policy][aks-support-policy] doesn't cover self-managed installations of the following projects. Some of these projects have managed experiences built on top of them (for example in the case of Prometheus, Grafana, and Istio). These managed experiences are noted in the 'More Details' column.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

| Name | Description | More details |
|---|---|---|
| [Helm][helm] | An open-source packaging tool that helps you install and manage the lifecycle of Kubernetes applications. | [Quickstart: Develop on Azure Kubernetes Service (AKS) with Helm][helm-qs] |
| [Prometheus][prometheus] | Monitoring and alerting toolkit. | Managed experience - [Azure Monitor managed service for Prometheus][prometheus-az-monitor]; Self-managed experience - [Prometheus operator][prometheus-helm-chart] |
| [Grafana][grafana] | Dashboards for observability.  | Managed experience - [Azure Managed Grafana][managed-grafana]; Self-managed experience - [Deploy Grafana on Kubernetes][grafana-install].
| [Couchbase][couchdb] | A distributed NoSQL cloud database. | [Install Couchbase and the Operator on AKS][couchdb-install] |
| [OpenFaaS][open-faas]| An open-source framework for building serverless functions by using containers. | [Use OpenFaaS with AKS][open-faas-aks] |
| [Apache Spark][apache-spark] | An open-source, fast engine for large-scale data processing. | Running Apache Spark jobs requires a minimum node size of *Standard_D3_v2*. For more information on running Spark jobs on Kubernetes, see the [running Spark on Kubernetes][spark-kubernetes] guide. |
| [Istio][istio] | Service mesh | Managed experience - [Istio add-on for AKS](./istio-about.md); Self-managed experience - [Istio open-source installation][istio-install]
| [Linkerd][linkerd] | An open-source service mesh. | [Linkerd Getting Started][linkerd-install] |
| [Consul][consul] | An open-source, identity-based networking solution. | [Getting Started with Consul Service Mesh for Kubernetes][consul-install] |

### Third-party integrations for Windows containers

Microsoft collaborates with partners to ensure the build, test, deployment, configuration, and monitoring of your applications perform optimally with Windows containers on AKS.

For more information, see [Windows AKS partner solutions][windows-aks-partner-solutions].

<!-- LINKS -->
[aks-repo]: https://github.com/Azure/AKS
[app-routing-repo]: https://github.com/Azure/aks-app-routing-operator
[container-insights]: /azure/azure-monitor/containers/container-insights-overview
[virtual-nodes]: virtual-nodes.md
[virtual-nodes-oss-repo]: https://github.com/virtual-kubelet/virtual-kubelet
[azure-policy-aks]: /azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks
[azure-policy-repo]: https://github.com/Azure/azure-policy
[agic]: /azure/application-gateway/ingress-controller-overview
[agic-repo]: https://github.com/Azure/application-gateway-kubernetes-ingress
[osm]: open-service-mesh-about.md
[osm-repo]: https://github.com/Azure/osm-azure
[keyvault-secret-provider]: csi-secrets-store-driver.md
[keyvault-secret-provider-repo]: https://github.com/Azure/secrets-store-csi-driver-provider-azure
[cluster-extensions]: cluster-extensions.md?tabs=azure-cli
[cluster-extensions-current]: cluster-extensions.md?tabs=azure-cli#currently-available-extensions
[aks-support-policy]: support-policies.md
[helm]: https://helm.sh
[helm-qs]: quickstart-helm.md
[prometheus]: https://prometheus.io/
[prometheus-helm-chart]: https://github.com/prometheus-operator/kube-prometheus
[prometheus-az-monitor]: /azure/azure-monitor/essentials/prometheus-metrics-overview
[istio]: https://istio.io/
[istio-install]: https://istio.io/latest/docs/setup/install/
[linkerd]: https://linkerd.io/
[linkerd-install]: https://linkerd.io/2.16/getting-started/
[consul]: https://www.consul.io/
[consul-install]: https://learn.hashicorp.com/tutorials/consul/service-mesh-deploy
[grafana]: https://grafana.com/
[grafana-install]: https://grafana.com/docs/grafana/latest/installation/kubernetes/
[couchdb]: https://www.couchbase.com/
[couchdb-install]: https://docs.couchbase.com/operator/2.4/tutorial-aks.html
[open-faas]: https://www.openfaas.com/
[open-faas-aks]: openfaas.md
[apache-spark]: https://spark.apache.org/
[spark-kubernetes]: https://spark.apache.org/docs/latest/running-on-kubernetes.html
[managed-grafana]: /azure/managed-grafana/overview
[keda]: keda-about.md
[keda-repo]: https://github.com/Azure-Samples/aks-keda-addon-workload-identity
[app-routing]: app-routing.md
[maintenance-windows]: planned-maintenance.md
[release-tracker]: release-tracker.md
[github-actions]: /azure/developer/github/github-actions
[github-actions-aks]: kubernetes-action.md
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[windows-aks-partner-solutions]: windows-aks-partner-solutions.md
[managed-prometheus]: /azure/azure-monitor/containers/container-insights-overview
[managed-prometheus-repo]: https://github.com/Azure/prometheus-collector

