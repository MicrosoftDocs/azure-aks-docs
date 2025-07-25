---
title: Supported Kubernetes versions in Azure Kubernetes Service (AKS).
description: Learn the Kubernetes version support policy and lifecycle of clusters in Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 10/30/2024
ms.topic: concept-article
ms.custom:
  - build-2025
# Customer intent: "As a Kubernetes administrator, I want to understand the supported Kubernetes version lifecycle in Azure Kubernetes Service, so that I can ensure my clusters remain compliant and up-to-date with security patches and feature releases."
---

# Supported Kubernetes versions in Azure Kubernetes Service (AKS)

The Kubernetes community [releases minor versions](https://kubernetes.io/releases/) roughly every four months. 

Minor version releases include new features and improvements. Patch releases are more frequent (sometimes weekly) and are intended for critical bug fixes within a minor version. Patch releases include fixes for security vulnerabilities or major bugs.

## Kubernetes versions

Kubernetes uses the standard [Semantic Versioning](https://semver.org/) versioning scheme for each version:

```
[major].[minor].[patch]

Examples:
  1.29.2
  1.29.1
```

Each number in the version reflects compatibility with previous versions:

* **Major versions**: Introduce incompatible API changes or break backward compatibility.
* **Minor versions**: Add new features while maintaining backward compatibility.
* **Patch versions**: Include backward-compatible bug fixes.

Always use the latest patch release for your current minor version. For example, if your production cluster is on **`1.29.1`** and **`1.29.2`** is the latest available patch version available for the *1.29* minor version, you should upgrade to **`1.29.2`** as soon as possible to ensure your cluster is fully patched and supported.

## AKS Kubernetes release calendar

Check the AKS Kubernetes release calendar for upcoming version releases. To see real-time updates of region release status and version release notes, visit the [AKS release status webpage][aks-release]. To learn more about the release status webpage, see [AKS release tracker][aks-tracker].

> [!NOTE]
> AKS follows 12 months of support for a generally available (GA) Kubernetes version. To read more about our support policy for Kubernetes versioning, read our [FAQ](./supported-kubernetes-versions.md#faq).

For the past release history, see [Kubernetes history](https://github.com/kubernetes/kubernetes/releases).

|  K8s version | Upstream release  | AKS preview  | AKS GA  | End of life | Platform support |
|--------------|-------------------|--------------|---------|-------------|-----------------------|
| 1.29 | Dec 2023 | Feb 2024 | Mar 2024 | Mar 2025 | Until 1.33 GA |
| 1.30 | Apr 2024 | Jun 2024 | Jul 2024 | Jul 2025 | Until 1.34 GA |
| 1.31 | Aug 2024 | Oct 2024 | Nov 2024 | Nov 2025 | Until 1.35 GA |
| 1.32 | Dec 2024 | Feb 2025 | Apr 2025 | Mar 2026 | Until 1.36 GA |
| 1.33 | Apr 2025 | May 2025 | Jun 2025 | Jun 2026 | Until 1.37 GA |


### LTS Versions

> [!NOTE]
> Azure Linux 2.0 goes End of Life during the LTS period of AKS v1.28–v1.31. For more information on upgrading to Azure Linux 3.0 on AKS v1.28–v1.31, read the [Azure Linux AKS LTS Releases](/azure/azure-linux/support-cycle#aks-lts-releases) section.

|  K8s version | Upstream release  | AKS preview  | AKS GA  | End of life | LTS End of life |
|--------------|-------------------|--------------|---------|-------------|-----------------------|
| 1.27 | Apr 2023 | Jun 2023 | Jul 2023 | Jul 2024 | Jul 2025|
| 1.28 | Aug 2023 | Sep 2023 | Nov 2023 | Jan 2025 | Feb 2026|
| 1.29 | Dec 2023 | Feb 2024 | Mar 2024 | Mar 2025 | Apr 2026|
| 1.30 | Apr 2024 | Jun 2024 | Jul 2024 | Jul 2025 | Jul 2026|
| 1.31 | Aug 2024 | Oct 2024 | Nov 2024 | Nov 2025 | Nov 2026|
| 1.32 | Dec 2024 | Feb 2025 | Apr 2025 | Mar 2026 | Mar 2027|
| 1.33 | Apr 2025 | May 2025 | Jun 2025 | Jun 2026 | Jun 2027|

### AKS Kubernetes release schedule Gantt chart

If you prefer to see this information visually, here's a Gantt chart with all the current releases displayed:

:::image type="content" source="media/supported-kubernetes-versions/kubernetes-versions-gantt.png" alt-text="Gantt chart showing the lifecycle of all Kubernetes versions currently active in AKS, including long term support." lightbox="media/supported-kubernetes-versions/kubernetes-versions-gantt.png":::

## AKS components breaking changes by version

Note the following important changes before you upgrade to any of the available minor versions:

### Kubernetes 1.33.0

| AKS managed add-ons | AKS components | OS components | Breaking changes | Notes |
|---------------------|----------------|---------------|------------------|-------|
| • aci-connector-linux 1.6.2<br> • addon-resizer v1.8.23-2<br> • ai-toolchain-operator 0.4.5<br> • aks-windows-gpu-device-plugin 0.0.19<br> • ama-logs-linux 3.1.26<br> • ama-logs-win win-3.1.26<br> • app-routing-operator 0.0.3<br> • azure-monitor-metrics-cfg-reader 6.16.0-main-04-15-2025-d78050c6-cfg<br> • azure-monitor-metrics-ksm v2.15.0-4<br> • azure-monitor-metrics-linux 6.16.0-main-04-15-2025-d78050c6<br> • azure-monitor-metrics-target-allocator 6.16.0-main-04-15-2025-d78050c6-targetallocator<br> • azure-monitor-metrics-windows 6.16.0-main-04-15-2025-d78050c6-win<br> • azure-npm-image v1.5.45<br> • azure-npm-image-windows v1.5.5<br> • azure-policy 1.10.1<br> • azure-policy-webhook 1.10.0<br> • certgen v0.1.9<br> • cilium-agent 1.14.10-1<br> • cilium-envoy v1.31.5-250218<br> • cilium-operator-generic 1.14.10<br> • cloud-provider-node-manager-linux v1.33.0<br> • cloud-provider-node-manager-windows v1.33.0<br> • cluster-proportional-autoscaler v1.9.0-1<br> • container-networking-cilium-agent v1.16.6-250129<br> • container-networking-cilium-operator-generic v1.16.6-250129<br> • coredns v1.12.1-1<br> • cost-analysis-agent v0.0.23<br> • cost-analysis-opencost v1.111.0<br> • cost-analysis-prometheus v2.54.1<br> • cost-analysis-victoria-metrics v1.103.0<br> • extension-config-agent 1.23.3<br> • extension-manager 1.23.3<br> • fqdn-policy v1.16.6-250129<br> • gpu-provisioner 0.3.3<br> • health-probe-proxy v1.29.1<br> • hubble-relay v1.15.0<br> • image-cleaner v1.3.1<br> • ingress-appgw 1.8.1<br> • ip-masq-agent-v2 v0.1.15-2<br> • ipv6-hp-bpf v0.0.1<br> • keda v2.16.1<br> • keda-admission-webhooks v2.16.1<br> • keda-metrics-apiserver v2.16.1<br> • kube-egress-gateway-cni v0.0.20<br> • kube-egress-gateway-cni-ipam v0.0.20<br> • kube-egress-gateway-cnimanager v0.0.20<br> • kube-egress-gateway-daemon v0.0.20<br> • kube-egress-gateway-daemon-init v0.0.20<br> • metrics-server v0.7.2-6<br> • microsoft-defender-admission-controller 20250325.2<br> • microsoft-defender-low-level-collector 2.0.205<br> • microsoft-defender-low-level-init 1.3.81<br> • microsoft-defender-old-file-cleaner 1.0.214<br> • microsoft-defender-pod-collector 1.0.177<br> • microsoft-defender-security-publisher 1.0.211<br> • open-policy-agent-gatekeeper v3.18.2-1<br> • osm-bootstrap v1.2.9<br> • osm-controller v1.2.9<br> • osm-crds v1.2.9<br> • osm-healthcheck v1.2.9<br> • osm-init v1.2.9<br> • osm-injector v1.2.9<br> • osm-sidecar v1.32.2-hotfix.20241216<br> • overlay-vpa 1.2.1<br> • overlay-vpa-webhook-generation master.250430.1<br> • ratify-base v1.2.3<br> • retina-agent v0.0.31<br> • retina-agent-enterprise v0.1.9<br> • retina-agent-win v0.0.31<br> • retina-operator v0.1.9<br> • secrets-store-csi-driver v1.4.8<br> • secrets-store-csi-driver-windows v1.4.8<br> • secrets-store-driver-registrar-linux v2.11.1<br> • secrets-store-driver-registrar-windows v2.11.1<br> • secrets-store-livenessprobe-linux v2.13.1<br> • secrets-store-livenessprobe-windows v2.13.1<br> • secrets-store-provider-azure v1.6.2<br> • secrets-store-provider-azure-windows v1.6.2<br> • sgx-attestation 3.3.1<br> • sgx-plugin 1.0.0<br> • sgx-webhook 1.2.2<br> • tigera-operator v1.36.7<br> • windows-gmsa-webhook-image v0.12.1-2<br> • workload-identity-webhook v1.5.0 | • addon-override-manager master.250116.1<br> • apiserver-network-proxy-server v0.30.3-hotfix.20240819<br> • app-routing-operator 0.2.5<br> • ccp-webhook master.250509.3<br> • cluster-autoscaler v1.32.1-aks<br> • cost-analysis-scraper v0.0.23<br> • customer-net-probe master.250430.1<br> • envoy v1.31.5-master.241218.3<br> • ingress-dispatcher v1.31.5-master.250126.7<br> • kube-state-metrics v2.15.0-4<br> • gpu-provisioner 0.3.3<br> • karpenter 0.7.3-aks<br> • kube-egress-gateway-controller v0.0.20<br> • kubelet-serving-csr-approver v0.0.7<br> • live-patching-controller v0.0.8 | • Linux - Ubuntu 22.04<br>  • containerd 1.7.27-ubuntu22.04u1<br>  • kubernetes-cri-tools 1.32.0-ubuntu22.04u3<br>  • runc 1.2.6-ubuntu22.04u1<br> • Linux - AzureLinux 3.0<br>  • containerd 2.0.0-4.azl3<br>  • nvidia-container-toolkit 1.17.3<br> • Windows - Windows2022<br>  • containerd v1.7.20-azure.1 | • coredns v1.11.3-7 -> v1.12.1-1<br> • cloud-provider-node-manager-windows v1.32.5 -> v1.33.0<br> • cloud-provider-node-manager-linux v1.32.5 -> v1.33.0 | N/A |

### Kubernetes 1.32


| AKS managed add-ons | AKS components | OS components | Breaking changes | Notes |
|---------------------|----------------|---------------|------------------|-------|
| • Azure Policy 1.8.0<br> •  Metrics-Server 0.6.3<br> • App routing operator v0.2.3<br>  • KEDA 2.14.1<br> • Open Service Mesh v1.2.9<br> • Core DNS V1.9.4<br> • Overlay VPA 1.0.0 <br> • Azure-Keyvault-SecretsProvider v1.4.5<br> • Application Gateway Ingress Controller (AGIC) 1.7.2<br> • Image Cleaner v1.3.1<br> • Azure Workload identity v1.3.0<br> • MDC Defender Low Level Collector 2.0.186<br> • open-policy-agent-gatekeeper v3.17.1<br> • Retina v0.0.17<br> | • Cilium v1.17.0<br> • Cluster Autoscaler v1.30.6-aks<br> • Tigera-Operator v1.34.7<br>| • OS Image Ubuntu 22.04 Cgroups V2 <br> • ContainerD 1.7.23-ubuntu22.04u1 for Linux and v1.6.35+azure for Windows<br> • Azure Linux 3.0<br> • Cgroups V2<br> • ContainerD 1.7.13-3.azl<br>| • [Calico v1.34.7](https://github.com/tigera/operator/releases/tag/v1.34.7) | N/A |

### Kubernetes 1.31

| AKS managed add-ons | AKS components | OS components | Breaking changes | Notes |
|---------------------|----------------|---------------|------------------|-------|
| • Azure Policy 1.8.0<br> • Metrics-Server 0.6.3<br> • App routing operator v0.2.3<br> • KEDA 2.14.1<br> • Open Service Mesh v1.2.9<br> • Core DNS V1.9.4<br> • Overlay VPA 1.0.0 <br> • Azure-Keyvault-SecretsProvider v1.4.5<br> • Application Gateway Ingress Controller (AGIC) 1.7.2<br> • Image Cleaner v1.3.1<br> • Azure Workload identity v1.3.0<br> • MDC Defender Low Level Collector 2.0.186<br> • open-policy-agent-gatekeeper v3.17.1<br> • Retina v0.0.17<br> | • Cilium v1.16.6<br> • Cluster Autoscaler v1.30.6-aks<br> • Tigera-Operator v1.30.11<br>| • OS Image Ubuntu 22.04 Cgroups V2 <br> • ContainerD 1.7.23-ubuntu22.04u1 for Linux and v1.6.35+azure for Windows<br> • Azure Linux 3.0<br> • Cgroups V2<br> • ContainerD 1.7.13-3.azl<br>| • [Calico 1.30.11](https://github.com/tigera/operator/releases/tag/v1.30.11) | N/A |

### Kubernetes 1.30

| AKS managed add-ons | AKS components | OS components | Breaking changes | Notes |
|---------------------|----------------|---------------|------------------|-------|
| • Azure Policy 1.3.0<br> • App routing operator v0.2.3<br> • Metrics-Server 0.6.3<br> • KEDA 2.11.2<br> • Open Service Mesh 1.2.7<br> • Core DNS V1.9.4<br> • Overlay VPA 0.13.0<br> • Azure-Keyvault-SecretsProvider 1.4.1<br> • Application Gateway Ingress Controller (AGIC) 1.7.2<br> • Image Cleaner v1.2.3<br> • Azure Workload identity v1.2.0<br> • MDC Defender Security Publisher 1.0.68<br> • MDC Defender Old File Cleaner 1.3.68<br> • MDC Defender Pod Collector 1.0.78<br> • MDC Defender Low Level Collector 2.0.186<br> • Azure Active Directory Pod Identity 1.8.13.6<br> • GitOps 1.8.1<br> • CSI Secrets Store Driver 1.3.4-1<br> • [azurefile-csi-driver 1.29.3](azure-files-csi.md#prerequisites)<br>| • Cilium v1.14.9<br> • CNI v1.4.43.1 (Default)/v1.5.11 (Azure CNI Overlay)<br> • Cluster Autoscaler 1.27.3<br> • Tigera-Operator 1.30.7<br>| • OS Image Ubuntu 22.04 Cgroups V2 <br> • ContainerD 1.7.5 for Linux and 1.7.1 for Windows<br> • Azure Linux 2.0<br> • Cgroups V2<br> • ContainerD 1.6<br>| • Tigera-Operator 1.30.7 | N/A |


### Kubernetes 1.29

| AKS managed add-ons | AKS components | OS components | Breaking changes | Notes |
|---------------------|----------------|---------------|------------------|-------|
| • Azure Policy 1.3.0<br> • csi-provisioner v4.0.0<br>  • App routing operator v0.2.1<br> • csi-attacher v4.5.0<br> • csi-snapshotter v6.3.3<br> • snapshot-controller v6.3.3<br> • Metrics-Server 0.6.3<br> • KEDA 2.11.2<br> • Open Service Mesh 1.2.7<br> • Core DNS V1.9.4<br> • Overlay VPA 0.13.0<br> • Azure-Keyvault-SecretsProvider 1.4.1<br> • Application Gateway Ingress Controller (AGIC) 1.7.2<br> • Image Cleaner v1.2.3<br> • Azure Workload identity v1.2.0<br> • MDC Defender Security Publisher 1.0.68<br> • MDC Defender Old File Cleaner 1.3.68<br> • MDC Defender Pod Collector 1.0.78<br> • MDC Defender Low Level Collector 2.0.186<br> • Azure Active Directory Pod Identity 1.8.13.6<br> • GitOps 1.8.1<br> • CSI Secrets Store Driver 1.3.4-1<br> • azurefile-csi-driver 1.29.3<br>| • Cilium v1.14.9<br> • CNI v1.4.43.1 (Default)/v1.5.11 (Azure CNI Overlay)<br> • Cluster Autoscaler 1.27.3<br> • Tigera-Operator 1.30.7<br>| • OS Image Ubuntu 22.04 Cgroups V2 <br> • ContainerD 1.7.5 for Linux and 1.7.1 for Windows<br> • Azure Linux 2.0<br> • Cgroups V2<br> • ContainerD 1.6<br>| • Tigera-Operator 1.30.7<br> • csi-provisioner v4.0.0<br> • csi-attacher v4.5.0<br> • csi-snapshotter v6.3.3<br> • snapshot-controller v6.3.3 | N/A |


## Alias minor version

> [!NOTE]
> Alias minor version requires Azure CLI version 2.37 or above and API version 20220401 or above. Use `az upgrade` to install the latest version of the CLI.


You can create an AKS cluster without specifying a patch version. When you create a cluster without designating a patch, the cluster runs the minor version's latest GA patch. For example, if you create a cluster with **`1.29`** and **`1.29.2`** is the latest GA would patch available, your cluster is created with **`1.29.2`**. If you want to upgrade your patch version in the same minor version, use [autoupgrade](./auto-upgrade-cluster.md).


To see what patch you're on, run the `az aks show --resource-group myResourceGroup --name myAKSCluster` command. The `currentKubernetesVersion` property shows the whole Kubernetes version.

```
{
 "apiServerAccessProfile": null,
  "autoScalerProfile": null,
  "autoUpgradeProfile": null,
  "azurePortalFqdn": "myaksclust-myresourcegroup.portal.hcp.eastus.azmk8s.io",
  "currentKubernetesVersion": "1.29.2",
}
```

## Kubernetes version support policy

AKS defines a generally available (GA) version as a version available in all regions and enabled in all SLO or SLA measurements. AKS supports three GA minor versions of Kubernetes:

AKS supports three GA minor versions:
* The latest GA version (N).
* The two previous minor versions (N-1 and N-2).
  * Each supported minor version can support any number of patches at a given time. AKS reserves the right to deprecate patches if a critical CVE or security vulnerability is detected. For awareness on patch availability and any ad-hoc deprecation, refer to version release notes and visit the [AKS release status webpage][aks-tracker].

AKS might also support preview versions, which are explicitly labeled and subject to [preview terms and conditions][preview-terms].

AKS provides platform support only for one GA minor version of Kubernetes after the regular supported versions. The platform support window of Kubernetes versions on AKS is known as "N-3". For more information, see [platform support policy](#platform-support-policy).

> [!NOTE]
> AKS uses safe deployment practices which involve gradual region deployment. This means it might take up to 10 business days for a new release or a new version to be available in all regions.

The supported window of Kubernetes minor versions on AKS is known as "N-2", where N refers to the latest release, meaning that two previous minor releases are also supported.

For example, on the day that AKS introduces version 1.29, support is provided for the following versions:

New minor version    |    Supported Minor Version List
-----------------    |    ----------------------
1.29                 |    1.29, 1.28, 1.27

When a new minor version is introduced, the oldest minor version is deprecated and removed. For example, let's say the current supported minor version list is:

```
1.29
1.28
1.27
```

When AKS releases 1.30, all the 1.27 versions go out of support 30 days later.

AKS may support any number of **patches** based on upstream community release availability for a given minor version. AKS reserves the right to deprecate any of these patches at any given time due to a CVE or potential bug concern. You're always encouraged to use the latest patch for a minor version.  
## Platform support policy

Platform support policy is a reduced support plan for certain unsupported Kubernetes versions. During platform support, customers only receive support from Microsoft for AKS/Azure platform related issues. Any issues related to Kubernetes functionality and components aren't supported.

Platform support policy applies to clusters in an n-3 version (where n is the latest supported AKS GA minor version), before the cluster drops to n-4. For example, Kubernetes v1.26 is considered platform support when v1.29 is the latest GA version. However, during the v1.30-GA release, v1.26 shall autoupgrade to v1.27. If you're a running an n-2 version, the moment it becomes n-3 it also becomes deprecated, and you enter into the platform support policy. 

AKS relies on the releases and patches from [Kubernetes](https://kubernetes.io/releases/), which is an Open Source project that only supports a sliding window of three minor versions. AKS can only guarantee [full support](#kubernetes-version-support-policy) while those versions are being serviced upstream. Since there's no more patches being produced upstream, AKS can either leave those versions unpatched or fork. Due to this limitation, platform support doesn't support anything from relying on Kubernetes upstream.

This table outlines support guidelines for Community Support compared to Platform support.

| Support category | Community Support (N-2) | Platform Support (N-3) | 
|---|---|---|
| Upgrades from N-3 to a supported version| Supported | Supported|
| Platform (Azure) availability | Supported | Supported|
| Node pool scaling| Supported | Supported|
| VM availability| Supported | Supported|
| Storage, Networking related issues| Supported | Supported except for bug fixes and retired components |
| Start/stop | Supported | Supported|
| Rotate certificates | Supported | Supported|
| Infrastructure SLA| Supported | Supported|
| Control Plane SLA| Supported | Supported|
| Platform (AKS) SLA| Supported | Not supported|
| Kubernetes components (including Add-ons) | Supported | Not supported|
| Component updates | Supported | Not supported|
| Component hotfixes | Supported | Not supported|
| Applying bug fixes | Supported | Not supported|
| Applying security patches | Supported | Not supported|
| Kubernetes API support | Supported | Not supported|
| Node pool creation| Supported | Supported|
| Cluster creation| Supported | Not Supported|
| Node pool snapshot| Supported | Not supported|
| Node image upgrade| Supported | Supported|

 > [!NOTE]
  > The table is subject to change and outlines common support scenarios. Any scenarios related to Kubernetes functionality and components aren't supported for N-3. For further support, see [Support and troubleshooting for AKS](./aks-support-help.md).

### Supported `kubectl` versions

You can use a `kubectl` version that is one minor version older or newer than your kube-apiserver version, [Kubernetes support policy for kubectl](https://kubernetes.io/docs/setup/release/version-skew-policy/#kubectl).

For example, if your *kube-apiserver* is at *1.28*, then you can use versions *1.27* to *1.29* of `kubectl` with that *kube-apiserver*.

To install or update `kubectl` to the latest version, run:

### [Azure CLI](#tab/azure-cli)

```azurecli
az aks install-cli
```

### [Azure PowerShell](#tab/azure-powershell)

```powershell
Install-AzAksKubectl -Version latest
```

---

## Long Term Support (LTS)

AKS offers one year of Community Support and one year of Long Term Support (LTS), including backported security fixes from the upstream community. Our upstream LTS working group contributes efforts back to the community to provide our customers with a longer support window.

For more information on LTS, see [Long term support for Azure Kubernetes Service (AKS)](./long-term-support.md).

## Release and deprecation process

You can reference upcoming version releases and deprecations on the [AKS Kubernetes release calendar](#aks-kubernetes-release-calendar).

For new **minor** versions of Kubernetes:

* AKS announces new version release dates and old version deprecation in the [AKS Release notes](https://aka.ms/aks/releasenotes) at least 30 days before removal.
* AKS uses [Azure Advisor](/azure/advisor/advisor-overview) to alert you if a new version could cause issues in your cluster because of deprecated APIs. Azure Advisor also alerts you if you're out of support
* AKS publishes a [service health notification](/azure/service-health/service-health-overview) available to all users with AKS and portal access and sends an email to the subscription administrators with the planned version removal dates.
  > [!NOTE]
  > To find out who is your subscription administrators or to change it, please refer to [manage Azure subscriptions](/azure/cost-management-billing/manage/add-change-subscription-administrator#assign-a-subscription-administrator).
* You have **30 days** from version removal to upgrade to a supported minor version release to continue receiving support.

For new **patch** versions of Kubernetes:

* Because of the urgent nature of patch versions, they can be introduced into the service as they become available. Once available, patches have a two month minimum lifecycle.
* In general, AKS doesn't broadly communicate the release of new patch versions. However, AKS constantly monitors and validates available CVE patches to support them in AKS in a timely manner. If a critical patch is found or user action is required, AKS notifies you to upgrade to the newly available patch.
* You have **30 days** from a patch release's removal from AKS to upgrade into a supported patch and continue receiving support. However, you'll **no longer be able to create clusters or node pools once the version is deprecated/removed.**

### Supported versions policy exceptions

AKS reserves the right to add or remove new/existing versions with one or more critical production-impacting bugs or security issues without advance notice.

Specific patch releases might be skipped or rollout accelerated, depending on the severity of the bug or security issue.

## Azure portal and CLI versions

If you deploy an AKS cluster with Azure portal, Azure CLI, Azure PowerShell, the cluster defaults to the N-1 minor version and latest patch. For example, if AKS supports *1.29.2*, *1.29.1*, *1.28.7*, *1.28.6*, *1.27.11*, and *1.27.10*, the default version selected is *1.28.7*.

### [Azure CLI](#tab/azure-cli)

To find out what versions are currently available for your subscription and region, use the
[`az aks get-versions`][az-aks-get-versions] command. The following example lists the available Kubernetes versions for the *EastUS* region:

```azurecli-interactive
az aks get-versions --location eastus --output table
```

### [Azure PowerShell](#tab/azure-powershell)

To find out what versions are currently available for your subscription and region, use the
[Get-AzAksVersion][get-azaksversion] cmdlet. The following example lists available Kubernetes versions for the *EastUS* region:

```azurepowershell-interactive
Get-AzAksVersion -Location eastus
```

---

## FAQ

### How does Microsoft notify me of new Kubernetes versions?

The AKS team announces new Kubernetes version release dates in our documentation, on [GitHub](https://github.com/Azure/AKS/releases), and via email to subscription administrators with clusters nearing end of support. AKS also uses [Azure Advisor](/azure/advisor/advisor-overview) to alert you inside the Azure portal if you're out of support and inform you of deprecated APIs that can affect your application or development process.

### How often should I expect to upgrade Kubernetes versions to stay in support?

Starting with Kubernetes 1.19, the [open source community expanded support to one year](https://kubernetes.io/blog/2020/08/31/kubernetes-1-19-feature-one-year-support/). AKS commits to enabling patches and support matching the upstream commitments. For AKS clusters on 1.19 and greater, you can upgrade at a minimum of once a year to stay on a supported version.

**What happens when you upgrade a Kubernetes cluster with a minor version that isn't supported?**

If you're on the *n-3* version or older, it means you're outside of support and need to upgrade. If your upgrade from version n-3 to n-2 succeeds, you're back within our support policies. For example:

* If the oldest supported AKS minor version is *1.27* and you're on *1.26* or older, you're outside of support.
* If you successfully upgrade from *1.26* to *1.27* or higher, you're back within our support policies.

Downgrades aren't supported.

### What does 'Outside of Support' mean?

'Outside of Support' means that:

* The version you're running is outside of the supported versions list.
* You'll be asked to upgrade the cluster to a supported version when requesting support, unless you're within the 30-day grace period after version deprecation.

Additionally, AKS doesn't make any runtime or other guarantees for clusters outside of the supported versions list.

### What happens when you scale a Kubernetes cluster with a minor version that isn't supported?

For minor versions not supported by AKS, scaling in or out should continue to work. Since there are no guarantees with quality of service, we recommend upgrading to bring your cluster back into support.

### Can you stay on a Kubernetes version forever?

If a cluster is out of support for more than three minor versions and carries security risks, Azure  proactively contacts you. They advise you to upgrade your cluster. If you don't take further action, Azure reserves the right to automatically upgrade your cluster on your behalf.

### What happens if you scale a Kubernetes cluster with a minor version that isn't supported?

For minor versions not supported by AKS, scaling in or out should continue to work. Since there are no guarantees with quality of service, we recommend upgrading to bring your cluster back into support.

### What version does the control plane support if the node pool isn't in one of the supported AKS versions?

The control plane must be within a window of versions from all node pools. For details on upgrading the control plane or node pools, visit documentation on [upgrading node pools](manage-node-pools.md#upgrade-a-cluster-control-plane-with-multiple-node-pools).

### What is the allowed difference in versions between control plane and node pool?
The [version skew policy](https://kubernetes.io/releases/version-skew-policy/) now allows a difference of upto 3 versions between control plane and agent pools. AKS follows this skew version policy change starting from version 1.28 onwards. 

### Can I skip multiple AKS versions during cluster upgrade?

If you upgrade a supported AKS cluster, Kubernetes minor versions can't be skipped. Kubernetes control planes [version skew policy](https://kubernetes.io/releases/version-skew-policy/) doesn't support minor version skipping. For example, upgrades between:

* *1.28.x* -> *1.29.x*: allowed.
* *1.27.x* -> *1.28.x*: allowed.
* *1.27.x* -> *1.29.x*: not allowed.


For control plane version upgrades, you can go upto 3 minor versions for community supported versions in sequential fashion. 


To upgrade from *1.27.x* -> *1.29.x*:

1. Upgrade from *1.27.x* -> *1.28.x*.
2. Upgrade from *1.28.x* -> *1.29.x*.

Note starting from 1.28 version onwards, agentpool versions can be upto 3 versions older to control plane versions per [version skew policy](https://kubernetes.io/releases/version-skew-policy/). If your version is much behind the minimum supported version, you may have to do more than one control plane upgrade operation to get to the minimum supported version. For example, if your current control plane version is *1.23.x* and you intend to upgrade to a minimum supported version of *1.27.x* as an example. You may have to upgrade sequentially 4 times from *1.23.x* in order to get to *1.27.x*. Also note that Agent pool versions can be upgraded to the control plane minor version. In the above example you can upgrade agentpool version twice i.e once from *1.23.x* to *1.25.x*, when the control plane version is at *1.25.x*. And subsequently from *1.25.x* to *1.27.x* , when control plane version is at *1.27.x*. When upgrading in-place, i.e, control plane and agent pool together the same rules applicable to control plane upgrade applies. 


If, performing an upgrade from an _unsupported version_ - the upgrade is performed without any guarantee of functionality and is excluded from the service-level agreements and limited warranty. Clusters running _unsupported version_ has the flexibility of decoupling control plane upgrades with node pool upgrades. However if your version is out of date, we recommend that you re-create the cluster.

### Can I create a new 1.xx.x cluster during the platform support window?

No, Creation of new clusters is not possible during Platform Support period.

### I'm on a freshly deprecated version that is out of platform support, can I still add new node pools? Or should I upgrade?

Yes, you can add agent pools as long as they're compatible with the control plane version. 

## Next steps

For information on how to upgrade your cluster, see:
- [Upgrade an Azure Kubernetes Service (AKS) cluster][aks-upgrade]
- [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager][fleet-multi-cluster-upgrade]

<!-- LINKS - External -->
[azure-update-channel]: https://azure.microsoft.com/updates/?product=kubernetes-service
[aks-release]: https://releases.aks.azure.com/
[skew-policy]: https://kubernetes.io/releases/version-skew-policy/

<!-- LINKS - Internal -->
[aks-upgrade]: upgrade-cluster.md
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-extension-add]: /cli/azure/extension#az_extension_add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-get-versions]: /cli/azure/aks#az_aks_get_versions
[preview-terms]: https://azure.microsoft.com/support/legal/preview-supplemental-terms/
[get-azaksversion]: /powershell/module/az.aks/get-azaksversion
[aks-tracker]: release-tracker.md
[fleet-multi-cluster-upgrade]: /azure/kubernetes-fleet/update-orchestration
