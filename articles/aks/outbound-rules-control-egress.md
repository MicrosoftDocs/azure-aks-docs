---
title: Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters
description: Learn what ports and addresses are required to control egress traffic in Azure Kubernetes Service (AKS)
ms.subservice: aks-networking
ms.custom:
  - build-2024
ms.topic: how-to
ms.author: allensu
ms.date: 12/11/2024
author: asudbring
#Customer intent: As an cluster operator, I want to learn the network and FQDNs rules to control egress traffic and improve security for my AKS clusters.
---

# Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters

This article provides the necessary details that allow you to secure outbound traffic from your Azure Kubernetes Service (AKS). It contains the cluster requirements for a base AKS deployment and additional requirements for optional addons and features. You can apply this information to any outbound restriction method or appliance.

To see an example configuration using Azure Firewall, visit [Control egress traffic using Azure Firewall in AKS](limit-egress-traffic.md).

## Background

AKS clusters are deployed on a virtual network. This network can either be customized and pre-configured by you or it can be created and managed by AKS. In either case, the cluster has **outbound**, or egress, dependencies on services outside of the virtual network.

For management and operational purposes, nodes in an AKS cluster need to access certain ports and fully qualified domain names (FQDNs). These endpoints are required for the nodes to communicate with the API server or to download and install core Kubernetes cluster components and node security updates. For example, the cluster needs to pull container images from Microsoft Artifact Registry (MAR).

The AKS outbound dependencies are almost entirely defined with FQDNs, which don't have static addresses behind them. The lack of static addresses means you can't use network security groups (NSGs) to lock down the outbound traffic from an AKS cluster.

By default, AKS clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. If you wish to restrict egress traffic, a limited number of ports and addresses must be accessible to maintain healthy cluster maintenance tasks. 

A [network isolated AKS cluster][network-isolated-cluster], provides the simplest and most secure solution for setting up outbound restrictions for a cluster out of the box. A network isolated cluster pulls the images for cluster components and add-ons from a private Azure Container Registry (ACR) instance connected to the cluster instead of pulling from MAR. If the images aren't present, the private ACR pulls them from MAR and serves them via its private endpoint, eliminating the need to enable egress from the cluster to the public MAR endpoint. The cluster operator can then incrementally set up allowed outbound traffic securely over a private network for each scenario they want to enable. This way the cluster operators have complete control over designing the allowed outbound traffic from their clusters right from the start, thus allowing them to reduce the risk of data exfiltration.

Another solution to securing outbound addresses is using a firewall device that can control outbound traffic based on domain names. Azure Firewall can restrict outbound HTTP and HTTPS traffic based on the FQDN of the destination. You can also configure your preferred firewall and security rules to allow these required ports and addresses.

> [!IMPORTANT]
>
> This document covers only how to lock down the traffic leaving the AKS subnet. AKS has no ingress requirements by default. Blocking **internal subnet traffic** using network security groups (NSGs) and firewalls isn't supported. To control and block the traffic within the cluster, see [Secure traffic between pods using network policies in AKS][use-network-policies].

## Required outbound network rules and FQDNs for AKS clusters

The following network and FQDN/application rules are required for an AKS cluster. You can use them if you wish to configure a solution other than Azure Firewall.

* IP address dependencies are for non-HTTP/S traffic (both TCP and UDP traffic).
* FQDN HTTP/HTTPS endpoints can be placed in your firewall device.
* Wildcard HTTP/HTTPS endpoints are dependencies that can vary with your AKS cluster based on a number of qualifiers.
* AKS uses an admission controller to inject the FQDN as an environment variable to all deployments under kube-system and gatekeeper-system. This ensures all system communication between nodes and API server uses the API server FQDN and not the API server IP.  You can get the same behavior on your own pods, in any namespace, by annotating the pod spec with an annotation named `kubernetes.azure.com/set-kube-service-host-fqdn`. If that annotation is present, AKS will set the KUBERNETES_SERVICE_HOST variable to the domain name of the API server instead of the in-cluster service IP. This is useful in cases where the cluster egress is via a layer 7 firewall.
* If you have an app or solution that needs to talk to the API server, you must either add an **additional** network rule to allow **TCP communication to port 443 of your API server's IP** **OR** , if you have a layer 7 firewall configured to allow traffic to the API Server's domain name, set `kubernetes.azure.com/set-kube-service-host-fqdn` in your pod specs.
* On rare occasions, if there's a maintenance operation, your API server IP might change. Planned maintenance operations that can change the API server IP are always communicated in advance.
* You might notice traffic towards "md-*.blob.storage.azure.net" endpoint. This endpoint is used for internal components of Azure Managed Disks. Blocking access to this endpoint from your firewall should not cause any issues.
* You might notice traffic towards "umsa*.blob.core.windows.net" endpoint. This endpoint is used to store manifests for Azure Linux VM Agent & Extensions and is regularly checked to download new versions. You can find more details on [VM Extensions](/azure/virtual-machines/extensions/features-linux?tabs=azure-cli#network-access).


### Azure Global required network rules

| Destination Endpoint                                                             | Protocol | Port    | Use  |
|----------------------------------------------------------------------------------|----------|---------|------|
| **`*:1194`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:1194`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:1194`** <br/> *Or* <br/> **`APIServerPublicIP:1194`** `(only known after cluster creation)`  | UDP           | 1194      | For tunneled secure communication between the nodes and the control plane. This isn't required for [private clusters][private-clusters], or for clusters with the *konnectivity-agent* enabled. |
| **`*:9000`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:9000`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:9000`** <br/> *Or* <br/> **`APIServerPublicIP:9000`** `(only known after cluster creation)`  | TCP           | 9000      | For tunneled secure communication between the nodes and the control plane. This isn't required for [private clusters][private-clusters], or for clusters with the *konnectivity-agent* enabled. |
| **`*:123`** or **`ntp.ubuntu.com:123`** (if using Azure Firewall network rules)  | UDP      | 123     | Required for Network Time Protocol (NTP) time synchronization on Linux nodes. This isn't required for nodes provisioned after March 2021.                 |
| **`CustomDNSIP:53`** `(if using custom DNS servers)`                             | UDP      | 53      | If you're using custom DNS servers, you must ensure they're accessible by the cluster nodes. |
| **`APIServerPublicIP:443`** `(if running pods/deployments that access the API Server)` | TCP      | 443     | Required if running pods/deployments that access the API Server, those pods/deployments would use the API IP. This port isn't required for [private clusters][private-clusters]. |

### Azure Global required FQDN / application rules

| Destination FQDN                 | Port            | Use      |
|----------------------------------|-----------------|----------|
| **`*.hcp.<location>.azmk8s.io`** | **`HTTPS:443`** | Required for Node <-> API server communication. Replace *\<location\>* with the region where your AKS cluster is deployed. This is required for clusters with *konnectivity-agent* enabled. Konnectivity also uses Application-Layer Protocol Negotiation (ALPN) to communicate between agent and server. Blocking or rewriting the ALPN extension will cause a failure. This isn't required for [private clusters][private-clusters]. |
| **`mcr.microsoft.com`**          | **`HTTPS:443`** | Required to access images in Microsoft Container Registry (MCR). This registry contains first-party images/charts (for example, coreDNS, etc.). These images are required for the correct creation and functioning of the cluster, including scale and upgrade operations.  |
| **`*.data.mcr.microsoft.com`**, **`mcr-0001.mcr-msedge.net`**   | **`HTTPS:443`** | Required for MCR storage backed by the Azure content delivery network (CDN). |
| **`management.azure.com`**       | **`HTTPS:443`** | Required for Kubernetes operations against the Azure API. |
| **`login.microsoftonline.com`**  | **`HTTPS:443`** | Required for Microsoft Entra authentication. |
| **`packages.microsoft.com`**     | **`HTTPS:443`** | This address is the Microsoft packages repository used for cached *apt-get* operations.  Example packages include Moby, PowerShell, and Azure CLI. |
| **`acs-mirror.azureedge.net`**   | **`HTTPS:443`** | This address is for the repository required to download and install required binaries like kubenet and Azure CNI. |
| **`packages.aks.azure.com`**     | **`HTTPS:443`** | This address will be replacing `acs-mirror.azureedge.net` in the future and will be used to download and install required Kubernetes and Azure CNI binaries. |

### Microsoft Azure operated by 21Vianet required network rules


| Destination Endpoint                                                             | Protocol | Port    | Use  |
|----------------------------------------------------------------------------------|----------|---------|------|
| **`*:1194`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.Region:1194`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:1194`** <br/> *Or* <br/> **`APIServerPublicIP:1194`** `(only known after cluster creation)`  | UDP           | 1194      | For tunneled secure communication between the nodes and the control plane. |
| **`*:9000`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:9000`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:9000`** <br/> *Or* <br/> **`APIServerPublicIP:9000`** `(only known after cluster creation)`  | TCP           | 9000      | For tunneled secure communication between the nodes and the control plane. |
| **`*:22`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:22`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:22`** <br/> *Or* <br/> **`APIServerPublicIP:22`** `(only known after cluster creation)`  | TCP           | 22      | For tunneled secure communication between the nodes and the control plane. |
| **`*:123`** or **`ntp.ubuntu.com:123`** (if using Azure Firewall network rules)  | UDP      | 123     | Required for Network Time Protocol (NTP) time synchronization on Linux nodes.                 |
| **`CustomDNSIP:53`** `(if using custom DNS servers)`                             | UDP      | 53      | If you're using custom DNS servers, you must ensure they're accessible by the cluster nodes. |
| **`APIServerPublicIP:443`** `(if running pods/deployments that access the API Server)` | TCP      | 443     | Required if running pods/deployments that access the API Server, those pod/deployments would use the API IP.  |

### Microsoft Azure operated by 21Vianet required FQDN / application rules

| Destination FQDN                               | Port            | Use      |
|------------------------------------------------|-----------------|----------|
| **`*.hcp.<location>.cx.prod.service.azk8s.cn`**| **`HTTPS:443`** | Required for Node <-> API server communication. Replace *\<location\>* with the region where your AKS cluster is deployed. |
| **`*.tun.<location>.cx.prod.service.azk8s.cn`**| **`HTTPS:443`** | Required for Node <-> API server communication. Replace *\<location\>* with the region where your AKS cluster is deployed. |
| **`mcr.microsoft.com`**                        | **`HTTPS:443`** | Required to access images in Microsoft Container Registry (MCR). This registry contains first-party images/charts (for example, coreDNS, etc.). These images are required for the correct creation and functioning of the cluster, including scale and upgrade operations. |
| **`.data.mcr.microsoft.com`**                  | **`HTTPS:443`** | Required for MCR storage backed by the Azure Content Delivery Network (CDN). |
| **`management.chinacloudapi.cn`**              | **`HTTPS:443`** | Required for Kubernetes operations against the Azure API. |
| **`login.chinacloudapi.cn`**                   | **`HTTPS:443`** | Required for Microsoft Entra authentication. |
| **`packages.microsoft.com`**                   | **`HTTPS:443`** | This address is the Microsoft packages repository used for cached *apt-get* operations.  Example packages include Moby, PowerShell, and Azure CLI. |
| **`*.azk8s.cn`**                               | **`HTTPS:443`** | This address is for the repository required to download and install required binaries like kubenet and Azure CNI. |

### Azure US Government required network rules

| Destination Endpoint                                                             | Protocol | Port    | Use  |
|----------------------------------------------------------------------------------|----------|---------|------|
| **`*:1194`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:1194`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:1194`** <br/> *Or* <br/> **`APIServerPublicIP:1194`** `(only known after cluster creation)`  | UDP           | 1194      | For tunneled secure communication between the nodes and the control plane. |
| **`*:9000`** <br/> *Or* <br/> [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureCloud.<Region>:9000`** <br/> *Or* <br/> [Regional CIDRs](/azure/virtual-network/service-tags-overview#discover-service-tags-by-using-downloadable-json-files) - **`RegionCIDRs:9000`** <br/> *Or* <br/> **`APIServerPublicIP:9000`** `(only known after cluster creation)`  | TCP           | 9000      | For tunneled secure communication between the nodes and the control plane. |
| **`*:123`** or **`ntp.ubuntu.com:123`** (if using Azure Firewall network rules)  | UDP      | 123     | Required for Network Time Protocol (NTP) time synchronization on Linux nodes.                 |
| **`CustomDNSIP:53`** `(if using custom DNS servers)`                             | UDP      | 53      | If you're using custom DNS servers, you must ensure they're accessible by the cluster nodes. |
| **`APIServerPublicIP:443`** `(if running pods/deployments that access the API Server)` | TCP      | 443     | Required if running pods/deployments that access the API Server, those pods/deployments would use the API IP.  |

### Azure US Government required FQDN / application rules

| Destination FQDN                                        | Port            | Use      |
|---------------------------------------------------------|-----------------|----------|
| **`*.hcp.<location>.cx.aks.containerservice.azure.us`** | **`HTTPS:443`** | Required for Node <-> API server communication. Replace *\<location\>* with the region where your AKS cluster is deployed.|
| **`mcr.microsoft.com`**                                 | **`HTTPS:443`** | Required to access images in Microsoft Container Registry (MCR). This registry contains first-party images/charts (for example, coreDNS, etc.). These images are required for the correct creation and functioning of the cluster, including scale and upgrade operations. |
| **`*.data.mcr.microsoft.com`**                          | **`HTTPS:443`** | Required for MCR storage backed by the Azure content delivery network (CDN). |
| **`management.usgovcloudapi.net`**                      | **`HTTPS:443`** | Required for Kubernetes operations against the Azure API. |
| **`login.microsoftonline.us`**                          | **`HTTPS:443`** | Required for Microsoft Entra authentication. |
| **`packages.microsoft.com`**                            | **`HTTPS:443`** | This address is the Microsoft packages repository used for cached *apt-get* operations.  Example packages include Moby, PowerShell, and Azure CLI. |
| **`acs-mirror.azureedge.net`**                          | **`HTTPS:443`** | This address is for the repository required to install required binaries like kubenet and Azure CNI. |
| **`packages.aks.azure.com`**                            | **`HTTPS:443`** | This address will be replacing `acs-mirror.azureedge.net` in the future and will be used to download and install required Kubernetes and Azure CNI binaries. |

## Optional recommended FQDN / application rules for AKS clusters

The following FQDN / application rules aren't required, but are recommended for AKS clusters:

| Destination FQDN                                                               | Port          | Use      |
|--------------------------------------------------------------------------------|---------------|----------|
| **`security.ubuntu.com`, `azure.archive.ubuntu.com`, `changelogs.ubuntu.com`** | **`HTTP:80`** | This address lets the Linux cluster nodes download the required security patches and updates. |
| **`snapshot.ubuntu.com`** | **`HTTPS:443`** | This address lets the Linux cluster nodes download the required security patches and updates from ubuntu snapshot service. |

If you choose to block/not allow these FQDNs, the nodes will only receive OS updates when you do a [node image upgrade](node-image-upgrade.md) or [cluster upgrade](upgrade-cluster.md). Keep in mind that node image upgrades also come with updated packages including security fixes.

## GPU enabled AKS clusters required FQDN / application rules

| Destination FQDN                        | Port      | Use      |
|-----------------------------------------|-----------|----------|
| **`nvidia.github.io`**                  | **`HTTPS:443`** | This address is used for correct driver installation and operation on GPU-based nodes. |
| **`us.download.nvidia.com`**            | **`HTTPS:443`** | This address is used for correct driver installation and operation on GPU-based nodes. |
| **`download.docker.com`**             | **`HTTPS:443`** | This address is used for correct driver installation and operation on GPU-based nodes. |

## Windows Server based node pools required FQDN / application rules

| Destination FQDN                                                           | Port      | Use      |
|----------------------------------------------------------------------------|-----------|----------|
| **`onegetcdn.azureedge.net, go.microsoft.com`**                            | **`HTTPS:443`** | To install windows-related binaries |
| **`*.mp.microsoft.com, www.msftconnecttest.com, ctldl.windowsupdate.com`** | **`HTTP:80`**   | To install windows-related binaries |

If you choose to block/not allow these FQDNs, the nodes will only receive OS updates when you do a [node image upgrade](node-image-upgrade.md) or [cluster upgrade](upgrade-cluster.md). Keep in mind that Node Image Upgrades also come with updated packages including security fixes.

## AKS features, addons, and integrations

### Workload identity

#### Required FQDN / application rules

| Destination FQDN                                                           | Port      | Use      |
|----------------------------------------------------------------------------|-----------|----------|
| **`login.microsoftonline.com`** or **`login.chinacloudapi.cn`** or **`login.microsoftonline.us`** | **`HTTPS:443`** | Required for Microsoft Entra authentication. |

### Microsoft Defender for Containers

#### Required FQDN / application rules

| FQDN                                                       | Port      | Use      |
|------------------------------------------------------------|-----------|----------|
| **`login.microsoftonline.com`** <br/> **`login.microsoftonline.us`** (Azure Government) <br/> **`login.microsoftonline.cn`** (Azure operated by 21Vianet) | **`HTTPS:443`** | Required for Microsoft Entra Authentication. |
| **`*.ods.opinsights.azure.com`** <br/> **`*.ods.opinsights.azure.us`** (Azure Government) <br/> **`*.ods.opinsights.azure.cn`** (Azure operated by 21Vianet)| **`HTTPS:443`** | Required for Microsoft Defender to upload security events to the cloud.|
| **`*.oms.opinsights.azure.com`** <br/> **`*.oms.opinsights.azure.us`** (Azure Government) <br/> **`*.oms.opinsights.azure.cn`** (Azure operated by 21Vianet)| **`HTTPS:443`** | Required to authenticate with Log Analytics workspaces.|

### Azure Key Vault provider for Secrets Store CSI Driver

If using network isolated clusters, it's recommended to set up [private endpoint to access Azure Key Vault][akv-privatelink].

If your cluster has outbound type user-defined routing and Azure Firewall, the following network rules and application rules are applicable:

#### Required FQDN / application rules

| FQDN                                          | Port      | Use      |
|-----------------------------------------------|-----------|----------|
| **`vault.azure.net`** | **`HTTPS:443`** | Required for CSI Secret Store addon pods to talk to Azure KeyVault server.|
| **`*.vault.usgovcloudapi.net`** | **`HTTPS:443`** | Required for CSI Secret Store addon pods to talk to Azure KeyVault server in Azure Government.|

### Azure Monitor - Managed Prometheus and Container Insights

If using network isolated clusters, it's recommended to set up [private endpoint based ingestion][azure-monitor-ingestion-private-link], which is supported for both Managed Prometheus (Azure Monitor workspace) and Container insights (Log Analytics workspace).

If your cluster has outbound type user-defined routing and Azure Firewall, the following network rules and application rules are applicable:

#### Required network rules

| Destination Endpoint                                                             | Protocol | Port    | Use  |
|----------------------------------------------------------------------------------|----------|---------|------|
| [ServiceTag](/azure/virtual-network/service-tags-overview#available-service-tags) - **`AzureMonitor:443`**  | TCP           | 443      | This endpoint is used to send metrics data and logs to Azure Monitor and Log Analytics. |

#### Azure public cloud required FQDN / application rules

| Endpoint| Purpose | Port |
|:---|:---|:---|
| **`*.ods.opinsights.azure.com`** | | 443 |
| **`*.oms.opinsights.azure.com`** | | 443 |
| **`dc.services.visualstudio.com`** | | 443 |
| **`*.monitoring.azure.com`** | | 443 |
| **`login.microsoftonline.com`** | | 443 |
| **`global.handler.control.monitor.azure.com`** | Access control service | 443 |
| **`*.ingest.monitor.azure.com`** | Container Insights - logs ingestion endpoint (DCE) | 443 |
| **`*.metrics.ingest.monitor.azure.com`** | Azure monitor managed service for Prometheus - metrics ingestion endpoint (DCE) | 443 |
| **`<cluster-region-name>.handler.control.monitor.azure.com`** | Fetch data collection rules for specific cluster | 443 |

#### Microsoft Azure operated by 21Vianet cloud required FQDN / application rules

| Endpoint| Purpose | Port |
|:---|:---|:---|
| **`*.ods.opinsights.azure.cn`** | Data ingestion | 443 |
| **`*.oms.opinsights.azure.cn`** | Azure Monitor agent (AMA) onboarding | 443 |
| **`dc.services.visualstudio.com`** | For agent telemetry that uses Azure Public Cloud Application Insights | 443 |
| **`global.handler.control.monitor.azure.cn`** | Access control service | 443 |
| **`<cluster-region-name>.handler.control.monitor.azure.cn`** | Fetch data collection rules for specific cluster | 443 |
| **`*.ingest.monitor.azure.cn`** | Container Insights - logs ingestion endpoint (DCE) | 443 |
| **`*.metrics.ingest.monitor.azure.cn`** | Azure monitor managed service for Prometheus - metrics ingestion endpoint (DCE) | 443 |

#### Azure Government cloud required FQDN / application rules

| Endpoint| Purpose | Port |
|:---|:---|:---|
| **`*.ods.opinsights.azure.us`** | Data ingestion | 443 |
| **`*.oms.opinsights.azure.us`** | Azure Monitor agent (AMA) onboarding | 443 |
| **`dc.services.visualstudio.com`** | For agent telemetry that uses Azure Public Cloud Application Insights | 443 |
| **`global.handler.control.monitor.azure.us`** | Access control service | 443 |
| **`<cluster-region-name>.handler.control.monitor.azure.us`** | Fetch data collection rules for specific cluster | 443 |
| **`*.ingest.monitor.azure.us`** | Container Insights - logs ingestion endpoint (DCE) | 443 |
| **`*.metrics.ingest.monitor.azure.us`** | Azure monitor managed service for Prometheus - metrics ingestion endpoint (DCE) | 443 |

### Azure Policy

#### Required FQDN / application rules

| FQDN                                          | Port      | Use      |
|-----------------------------------------------|-----------|----------|
| **`data.policy.core.windows.net`** | **`HTTPS:443`** | This address is used to pull the Kubernetes policies and to report cluster compliance status to policy service. |
| **`store.policy.core.windows.net`** | **`HTTPS:443`** | This address is used to pull the Gatekeeper artifacts of built-in policies. |
| **`dc.services.visualstudio.com`** | **`HTTPS:443`** | Azure Policy add-on that sends telemetry data to applications insights endpoint. |

#### Microsoft Azure operated by 21Vianet required FQDN / application rules

| FQDN                                          | Port      | Use      |
|-----------------------------------------------|-----------|----------|
| **`data.policy.azure.cn`** | **`HTTPS:443`** | This address is used to pull the Kubernetes policies and to report cluster compliance status to policy service. |
| **`store.policy.azure.cn`** | **`HTTPS:443`** | This address is used to pull the Gatekeeper artifacts of built-in policies. |

#### Azure US Government required FQDN / application rules

| FQDN                                          | Port      | Use      |
|-----------------------------------------------|-----------|----------|
| **`data.policy.azure.us`** | **`HTTPS:443`** | This address is used to pull the Kubernetes policies and to report cluster compliance status to policy service. |
| **`store.policy.azure.us`** | **`HTTPS:443`** | This address is used to pull the Gatekeeper artifacts of built-in policies. |

### AKS cost analysis add-on

#### Required FQDN / application rules

| FQDN                                                       | Port      | Use      |
|------------------------------------------------------------|-----------|----------|
| **`management.azure.com`** <br/> **`management.usgovcloudapi.net`** (Azure Government) <br/> **`management.chinacloudapi.cn`** (Azure operated by 21Vianet)| **`HTTPS:443`** | Required for Kubernetes operations against the Azure API. |
| **`login.microsoftonline.com`** <br/> **`login.microsoftonline.us`** (Azure Government) <br/> **`login.microsoftonline.cn`** (Azure operated by 21Vianet) | **`HTTPS:443`** | Required for Microsoft Entra ID authentication. |

## Cluster extensions

### Required FQDN / application rules

| FQDN | Port               | Use |
|-----------------------------------------------|-----------|----------|
| **`<region>.dp.kubernetesconfiguration.azure.com`** | **`HTTPS:443`** | This address is used to fetch configuration information from the Cluster Extensions service and report extension status to the service.|
| **`mcr.microsoft.com, *.data.mcr.microsoft.com`** | **`HTTPS:443`** | This address is required to pull container images for installing cluster extension agents on AKS cluster.|
|**`arcmktplaceprod.azurecr.io`**|**`HTTPS:443`**|This address is required to pull container images for installing marketplace extensions on AKS cluster.|
| **`arcmktplaceprod.centralindia.data.azurecr.io`** | **`HTTPS:443`** | This address is for the Central India regional data endpoint and is required to pull container images for installing marketplace extensions on AKS cluster.|
| **`arcmktplaceprod.japaneast.data.azurecr.io`** | **`HTTPS:443`** | This address is for the East Japan regional data endpoint and is required to pull container images for installing marketplace extensions on AKS cluster.|
| **`arcmktplaceprod.westus2.data.azurecr.io`** | **`HTTPS:443`** | This address is for the West US2 regional data endpoint and is required to pull container images for installing marketplace extensions on AKS cluster.|
| **`arcmktplaceprod.westeurope.data.azurecr.io`** | **`HTTPS:443`** | This address is for the West Europe regional data endpoint and is required to pull container images for installing marketplace extensions on AKS cluster.|
| **`arcmktplaceprod.eastus.data.azurecr.io`** | **`HTTPS:443`** | This address is for the East US regional data endpoint and is required to pull container images for installing marketplace extensions on AKS cluster.|
|**`*.ingestion.msftcloudes.com, *.microsoftmetrics.com`**|**`HTTPS:443`**|This address is used to send agents metrics data to Azure.|
|**`marketplaceapi.microsoft.com`**|**`HTTPS: 443`**|This address is used to send custom meter-based usage to the commerce metering API.|


#### Azure US Government required FQDN / application rules

| FQDN | Port | Use |
|-----------------------------------------------|-----------|----------|
| **`<region>.dp.kubernetesconfiguration.azure.us`** | **`HTTPS:443`** | This address is used to fetch configuration information from the Cluster Extensions service and report extension status to the service. |
| **`mcr.microsoft.com, *.data.mcr.microsoft.com`** | **`HTTPS:443`** | This address is required to pull container images for installing cluster extension agents on AKS cluster.|

> [!NOTE]
>
> For any addons that aren't explicitly stated here, the core requirements cover it.


### Istio-based service mesh add-on

In Istio=based service mesh add-on, if you are setting up istiod with a Plugin Certificate Authority (CA) or if you are setting up secure ingress gateway, Azure Key Vault provider for Secrets Store CSI Driver is required for these features. Outbound network requirements for Azure Key Vault provider for Secrets Store CSI Driver can be found [here][akv-outbound].

### Application routing add-on

Application routing add-on supports SSL termination at the ingress with certificates stored in Azure Key Vault. Outbound network requirements for Azure Key Vault provider for Secrets Store CSI Driver can be found [here][akv-outbound].

## Next steps

In this article, you learned what ports and addresses to allow if you want to restrict egress traffic for the cluster.

If you want to restrict how pods communicate between themselves and East-West traffic restrictions within cluster see [Secure traffic between pods using network policies in AKS][use-network-policies].

<!-- LINKS - internal -->

[private-clusters]: ./private-clusters.md
[use-network-policies]: ./use-network-policies.md
[network-isolated-cluster]: ./concepts-network-isolated.md
[akv-outbound]: #azure-key-vault-provider-for-secrets-store-csi-driver

<!-- LINKS - external -->

[azure-monitor-ingestion-private-link]: /azure/azure-monitor/containers/kubernetes-monitoring-private-link#container-insights-log-analytics-workspace
[akv-privatelink]: /azure/key-vault/general/private-link-service?tabs=portal
