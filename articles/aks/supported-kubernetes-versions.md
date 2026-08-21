---
title: Supported Kubernetes Versions in Azure Kubernetes Service (AKS)
description: Learn the Kubernetes version support policy and lifecycle of clusters in Azure Kubernetes Service (AKS).
author: schaffererin
ms.author: schaffererin
ms.date: 08/05/2026
ms.topic: overview
ms.service: azure-kubernetes-service
ms.custom:
  - build-2025
ai-usage: ai-assisted
# Customer intent: "As a Kubernetes administrator, I want to understand the supported Kubernetes version lifecycle in Azure Kubernetes Service, so that I can ensure my clusters remain compliant and up-to-date with security patches and feature releases."
---

# Supported Kubernetes versions in Azure Kubernetes Service (AKS)

The Kubernetes community releases [minor versions](https://kubernetes.io/releases/) roughly every four months.

Minor version releases include new features and improvements. Patch releases are more frequent (sometimes weekly) and are intended for critical bug fixes within a minor version. Patch releases include fixes for security vulnerabilities or major bugs.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Kubernetes versions

Kubernetes uses the standard [Semantic Versioning](https://semver.org/) versioning scheme for each version:

```
[major].[minor].[patch]
```

Each number in the version reflects compatibility with previous versions:

- **Major versions**: Introduce incompatible API changes or break backward compatibility.
- **Minor versions**: Add new features. Stable APIs generally remain compatible, but deprecated APIs and features can be removed according to the [Kubernetes Deprecation Policy](https://kubernetes.io/docs/reference/using-api/deprecation-policy/).
- **Patch versions**: Include backward-compatible bug fixes.

Always use the latest patch release for your current minor version. When a later patch becomes available for your minor version, upgrade as soon as possible to ensure your cluster is fully patched and supported.

## AKS Kubernetes release calendar and upcoming versions

Check the AKS Kubernetes release calendar for upcoming version releases. To see real-time updates of region release status and version release notes, visit the [AKS release status webpage][aks-release]. To learn more about the release status webpage, see [AKS release tracker][aks-tracker].

> [!NOTE]
> AKS follows a 12-month support policy for generally available (GA) Kubernetes versions. To learn more about our Kubernetes version support policy, see the [FAQ](./supported-kubernetes-versions.md#frequently-asked-questions-faq). Unless an explicit date is provided, the End of Life (EOL) date is the last day of the specified month. For example, "Mar 2026" indicates March 31, 2026.

For the past release history, see [Kubernetes history](https://github.com/kubernetes/kubernetes/releases).

| Kubernetes version | Upstream release | AKS preview | AKS GA | End of life | Platform support |
| ------------------ | ---------------- | ----------- | ------ | ----------- | ---------------- |
| 1.32 | Dec 2024 | Feb 2025 | Apr 2025 | Mar 2026 | Until 1.36 GA |
| 1.33 | Apr 2025 | May 2025 | Jun 2025 | Jul 2026 | Until 1.37 GA |
| 1.34 | Aug 2025 | Oct 2025 | Nov 2025 | Nov 2026 | Until 1.38 GA |
| 1.35 | Dec 2025 | Feb 2026 | Mar 2026 | Mar 2027 | Until 1.39 GA |
| 1.36 | Apr 2026 | May 2026 | Jun 2026 | Jun 2027 | Until 1.40 GA |
| 1.37 | Aug 2026 | Sep 2026 | Oct 2026 | Oct 2027 | Until 1.41 GA |

### LTS versions

You need to enable long-term support (LTS) to get extended support. For more information, see [Enable long-term support](/azure/aks/long-term-support#enable-long-term-support).

> [!NOTE]
> Azure Linux 2.0 goes end of life during the LTS period of AKS v1.28–v1.31. For more information on upgrading to Azure Linux 3.0 on AKS v1.28–v1.31, see the [Azure Linux AKS LTS releases](/azure/azure-linux/aks-support-cycle#aks-long-term-support-lts-releases) section.

| Kubernetes version | Upstream release | AKS preview | AKS GA | End of life | LTS End of life |
| ------------------ | ---------------- | ----------- | ------ | ----------- | --------------- |
| 1.29 | Dec 2023 | Feb 2024 | Mar 2024 | Mar 2025 | Apr 2026 |
| 1.30 | Apr 2024 | Jun 2024 | Jul 2024 | Aug 22, 2025 | Jul 2026 |
| 1.31 | Aug 2024 | Oct 2024 | Nov 2024 | Nov 1, 2025 | Nov 2026 |
| 1.32 | Dec 2024 | Feb 2025 | Apr 2025 | Mar 2026 | Mar 2027 |
| 1.33 | Apr 2025 | May 2025 | Jun 2025 | Jul 2026 | Jul 2027 |
| 1.34 | Aug 2025 | Oct 2025 | Nov 2025 | Nov 2026 | Nov 2027 |
| 1.35 | Dec 2025 | Feb 2026 | Mar 2026 | Mar 2027 | Mar 2028 |
| 1.36 | Apr 2026 | May 2026 | Jun 2026 | Jun 2027 | Jun 2028 |
| 1.37 | Aug 2026 | Sep 2026 | Oct 2026 | Oct 2027 | Oct 2028 |

### AKS Kubernetes release schedule Gantt chart

The following Gantt chart displays the current releases:

:::image type="content" source="media/supported-kubernetes-versions/kubernetes-versions-gantt.png" alt-text="Gantt chart showing the lifecycle of all Kubernetes versions currently active in AKS, including long term support." lightbox="media/supported-kubernetes-versions/kubernetes-versions-gantt.png":::

## AKS components breaking changes by version

Note the following important changes before you upgrade to any of the available minor versions:

### Kubernetes 1.36

| AKS managed add-ons | OS components | Breaking changes from Kubernetes 1.35.0 |
|---|---|---|
| aad-pod-identity-nmi v1.8.22-4<br>aci-connector-linux v1.6.4-9<br>addon-resizer v1.8.23-29<br>addon-token-adapter-linux master.260809.2<br>addon-token-adapter-windows master.260809.2<br>addon-token-reconciler master.260720.3<br>ai-toolchain-operator 0.6.0<br>aks-windows-gpu-device-plugin 0.0.19<br>alb-controller 1.11.3<br>ama-logs-linux 3.6.0<br>ama-logs-win win-3.6.0<br>apiserver-network-proxy-agent v0.32.1-13<br>app-routing-operator 0.2.27<br>appmonitoring-webhook 1.1.4<br>azure-cni-installer v1.8.12<br>azure-cni-networkmonitor v1.1.8post2<br>azure-cns-linux v1.8.12<br>azure-cns-windows v1.8.12<br>azure-ipam-installer v0.4.0-0<br>azure-monitor-metrics-cfg-reader 7.2.1-main-07-31-2026-4a713766-cfg<br>azure-monitor-metrics-ksm v2.19.1-2<br>azure-monitor-metrics-linux 7.2.1-main-07-31-2026-4a713766<br>azure-monitor-metrics-target-allocator 7.2.1-main-07-31-2026-4a713766-targetallocator<br>azure-monitor-metrics-windows 7.2.1-main-07-31-2026-4a713766-win<br>azure-npm-image v1.6.48-0<br>azure-npm-image-windows v1.5.5<br>azure-policy v1.17.0-1<br>azure-policy-audit v1.17.0-1<br>azure-policy-webhook v1.17.0-1<br>azuredisk-csi-linux v1.34.5-2<br>azuredisk-csi-windows v1.34.5<br>azurefile-csi-linux v1.35.7-7<br>azurefile-csi-windows v1.35.7<br>blob-csi v1.27.9-9<br>calico-cni-image v3.8.9.3<br>calico-node-image v3.8.9.5<br>calico-pod2daemon-flexvol-image v3.8.9.1<br>calico-typha-image v3.8.9<br>certgen v0.3.2<br>cilium-agent v1.19.6-260811<br>cilium-envoy v1.31.5-250218<br>cilium-operator v1.19.6-260811<br>cloud-provider-node-manager-linux v1.36.4-1<br>cloud-provider-node-manager-windows v1.36.4-windows-hpc-1<br>cluster-health-monitor v0.0.11<br>cluster-proportional-autoscaler v1.9.0-22<br>coredns v1.14.3-13<br>cost-analysis-agent v0.0.27<br>cost-analysis-opencost v1.111.0-16<br>cost-analysis-prometheus v2.54.1<br>cost-analysis-scraper v0.0.28<br>cost-analysis-victoria-metrics v1.103.0<br>csi-livenessprobe v2.19.0-3<br>csi-node-driver-registrar v2.17.0-3<br>fqdn-policy v1.16.6-250129<br>gitops-manager-config-agent 1.7.18<br>gitops-manager-config-operator 1.7.18<br>gpu-provisioner 0.3.5<br>health-probe-proxy v1.36.4-1<br>http-application-routing-defaultbackend 1.4<br>http-application-routing-external-dns v0.10.2-8<br>http-application-routing-nginx-ingress-controller v1.2.1-11<br>hubble-relay v1.19.6-260811<br>identity-binding-workload-identity-webhook v1.6.0-alpha.1<br>image-cleaner v1.4.1-3<br>ingress-appgw 1.9.12<br>keda 2.19.0-13<br>keda-admission-webhooks 2.19.0-10<br>keda-metrics-apiserver 2.19.0-13<br>kube-egress-gateway-cni v0.1.4<br>kube-egress-gateway-cni-ipam v0.1.4<br>kube-egress-gateway-cnimanager v0.1.5<br>kube-egress-gateway-daemon v0.1.4<br>kube-egress-gateway-daemon-init v0.1.4<br>kube-proxy v1.36.0-1<br>kube-state-metrics v2.15.0-19<br>kubectl v1.36.0-15<br>local-csi-driver v0.2.4<br>local-csi-driver-csi-provisioner v5.2.0<br>local-csi-driver-csi-resizer v1.13.2<br>local-csi-driver-registrar v2.13.0<br>metrics-server v0.8.0-20<br>microsoft-defender-admission-controller 0.11.20<br>microsoft-defender-antimalware-collector 1.0.21<br>microsoft-defender-low-level-collector 2.2.31<br>microsoft-defender-low-level-init 1.3.81<br>microsoft-defender-old-file-cleaner 1.1.64<br>microsoft-defender-pod-collector 1.0.264<br>microsoft-defender-security-publisher 1.1.70<br>microsoft-defender-sensor-release-version 0.10.38<br>open-policy-agent-gatekeeper v3.23.0-4<br>osm-bootstrap v1.2.15-7<br>osm-controller v1.2.15-7<br>osm-crds v1.2.15-8<br>osm-healthcheck v1.2.15-6<br>osm-init v1.2.15-5<br>osm-injector v1.2.15-7<br>osm-sidecar v1.38.3-2<br>overlay-vpa-admission-controller v1.6.0-11<br>overlay-vpa-recommender v1.6.0-7<br>overlay-vpa-updater v1.6.0-8<br>ratify v1.4.5-1<br>resourcesync-operator 1.7.18<br>retina-agent v1.2.4<br>retina-agent-enterprise v0.3.0<br>retina-agent-init-enterprise v0.3.0<br>retina-agent-win v1.2.4<br>retina-init v1.2.4<br>retina-operator v0.3.0<br>secrets-store-csi-driver v1.6.0-6<br>secrets-store-csi-driver-windows v1.6.0-6<br>secrets-store-driver-registrar-linux v2.17.0-3<br>secrets-store-driver-registrar-windows v2.17.0-3<br>secrets-store-livenessprobe-linux v2.19.0-3<br>secrets-store-livenessprobe-windows v2.19.0-3<br>secrets-store-provider-azure v1.8.2-5<br>secrets-store-provider-azure-windows v1.8.2-5<br>sgx-attestation 3.3.5<br>sgx-plugin 1.0.5<br>sgx-webhook 1.2.7<br>tigera-operator v1.40.2<br>tunnel-front master.260519.2<br>tunnel-openvpn-front master.260519.2<br>windows-gmsa-webhook-image v0.12.1-17<br>workload-identity-webhook v1.5.1-17 | **Linux - Ubuntu 24.04**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-ubuntu24.04u2<br>azure-acr-credential-provider-pmc 1.36.5-ubuntu24.04u1<br>blobfuse2 2.5.5<br>containerd 2.3.3-ubuntu24.04u2<br>containernetworking-plugins 1.9.0-ubuntu24.04u1<br>datacenter-gpu-manager-4-core 1:4.5.3-1<br>datacenter-gpu-manager-4-proprietary 1:4.5.3-1<br>dcgm-exporter 4.8.2-ubuntu24.04u10<br>dra-driver-nvidia-gpu 0.4.1-ubuntu24.04u5<br>inspektor-gadget 0.55.0-ubuntu24.04u2<br>kubectl 1.36.x<br>kubelet 1.36.x<br>kubernetes-cri-tools 1.34.0-ubuntu24.04u17<br>node-exporter 1.9.1-ubuntu24.04u24<br>nvidia-device-plugin 0.19.3-ubuntu24.04u6<br>runc 1.4.3-ubuntu24.04u2<br>**Linux - AzureLinux 3.0**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-2.azl3<br>aznfs 3.0.15-1<br>azure-acr-credential-provider-pmc 1.36.5-1.azl3<br>containerd 2.2.4-6.azl3<br>containernetworking-plugins 1.9.0-1.azl3<br>dra-driver-nvidia-gpu 0.4.1-5.azl3<br>inspektor-gadget 0.55.0-2.azl3<br>kubectl 1.36.x<br>kubelet 1.36.x<br>kubernetes-cri-tools 1.34.0-16.azl3<br>node-exporter 1.9.1-23.azl3<br>nvidia-container-toolkit 1.17.8<br>nvidia-device-plugin 0.19.3-6.azl3<br>**Windows - Windows2022**<br>containerd v2.0.4-azure.1 | alb-controller 1.10.32 -> 1.11.3<br>cilium-agent v1.18.12-260811 -> v1.19.6-260811<br>cilium-operator v1.18.12-260811 -> v1.19.6-260811<br>cloud-provider-node-manager-linux v1.35.8-1 -> v1.36.4-1<br>cloud-provider-node-manager-windows v1.35.8-windows-hpc-1 -> v1.36.4-windows-hpc-1<br>coredns v1.13.1-22 -> v1.14.3-13<br>csi-livenessprobe v2.18.0-8 -> v2.19.0-3<br>csi-node-driver-registrar v2.16.0-8 -> v2.17.0-3<br>hubble-relay v1.18.12-260811 -> v1.19.6-260811<br>keda 2.17.3-15 -> 2.19.0-13<br>keda-admission-webhooks 2.17.3-13 -> 2.19.0-10<br>keda-metrics-apiserver 2.17.3-14 -> 2.19.0-13<br>kube-proxy v1.35.0-1 -> v1.36.0-1<br>kubectl v1.35.0-19 -> v1.36.0-15<br>microsoft-defender-low-level-collector 2.1.127 -> 2.2.31<br>microsoft-defender-sensor-release-version 0.9.62 -> 0.10.38<br>overlay-vpa-admission-controller v1.5.1-15 -> v1.6.0-11<br>overlay-vpa-recommender v1.5.1-12 -> v1.6.0-7<br>overlay-vpa-updater v1.5.1-12 -> v1.6.0-8 |

### Kubernetes 1.35

| AKS managed add-ons | OS components | Breaking changes from Kubernetes 1.34.0 |
|---|---|---|
| aad-pod-identity-nmi v1.8.22-4<br>aci-connector-linux v1.6.4-9<br>addon-resizer v1.8.23-29<br>addon-token-adapter-linux master.260809.2<br>addon-token-adapter-windows master.260809.2<br>addon-token-reconciler master.260720.3<br>ai-toolchain-operator 0.6.0<br>aks-windows-gpu-device-plugin 0.0.19<br>alb-controller 1.10.32<br>ama-logs-linux 3.6.0<br>ama-logs-win win-3.6.0<br>apiserver-network-proxy-agent v0.32.1-13<br>app-routing-operator 0.2.27<br>appmonitoring-webhook 1.1.4<br>azure-cni-installer v1.8.12<br>azure-cni-networkmonitor v1.1.8post2<br>azure-cns-linux v1.8.12<br>azure-cns-windows v1.8.12<br>azure-ipam-installer v0.4.0-0<br>azure-monitor-metrics-cfg-reader 7.2.1-main-07-31-2026-4a713766-cfg<br>azure-monitor-metrics-ksm v2.19.1-2<br>azure-monitor-metrics-linux 7.2.1-main-07-31-2026-4a713766<br>azure-monitor-metrics-target-allocator 7.2.1-main-07-31-2026-4a713766-targetallocator<br>azure-monitor-metrics-windows 7.2.1-main-07-31-2026-4a713766-win<br>azure-npm-image v1.6.48-0<br>azure-npm-image-windows v1.5.5<br>azure-policy v1.17.0-1<br>azure-policy-audit v1.17.0-1<br>azure-policy-webhook v1.17.0-1<br>azuredisk-csi-linux v1.34.5-2<br>azuredisk-csi-windows v1.34.5<br>azurefile-csi-linux v1.35.7-7<br>azurefile-csi-windows v1.35.7<br>blob-csi v1.27.9-9<br>calico-cni-image v3.8.9.3<br>calico-node-image v3.8.9.5<br>calico-pod2daemon-flexvol-image v3.8.9.1<br>calico-typha-image v3.8.9<br>certgen v0.3.2<br>cilium-agent v1.18.12-260811<br>cilium-envoy v1.31.5-250218<br>cilium-operator v1.18.12-260811<br>cloud-provider-node-manager-linux v1.35.8-1<br>cloud-provider-node-manager-windows v1.35.8-windows-hpc-1<br>cluster-health-monitor v0.0.11<br>cluster-proportional-autoscaler v1.9.0-22<br>coredns v1.13.1-22<br>cost-analysis-agent v0.0.27<br>cost-analysis-opencost v1.111.0-16<br>cost-analysis-prometheus v2.54.1<br>cost-analysis-scraper v0.0.28<br>cost-analysis-victoria-metrics v1.103.0<br>csi-livenessprobe v2.18.0-8<br>csi-node-driver-registrar v2.16.0-8<br>fqdn-policy v1.16.6-250129<br>gitops-manager-config-agent 1.7.18<br>gitops-manager-config-operator 1.7.18<br>gpu-provisioner 0.3.5<br>health-probe-proxy v1.36.4-1<br>http-application-routing-defaultbackend 1.4<br>http-application-routing-external-dns v0.10.2-8<br>http-application-routing-nginx-ingress-controller v1.2.1-11<br>hubble-relay v1.18.12-260811<br>identity-binding-workload-identity-webhook v1.6.0-alpha.1<br>image-cleaner v1.4.1-3<br>ingress-appgw 1.9.12<br>keda 2.17.3-15<br>keda-admission-webhooks 2.17.3-13<br>keda-metrics-apiserver 2.17.3-14<br>kube-egress-gateway-cni v0.1.4<br>kube-egress-gateway-cni-ipam v0.1.4<br>kube-egress-gateway-cnimanager v0.1.5<br>kube-egress-gateway-daemon v0.1.4<br>kube-egress-gateway-daemon-init v0.1.4<br>kube-proxy v1.35.0-1<br>kube-state-metrics v2.15.0-19<br>kubectl v1.35.0-19<br>local-csi-driver v0.2.4<br>local-csi-driver-csi-provisioner v5.2.0<br>local-csi-driver-csi-resizer v1.13.2<br>local-csi-driver-registrar v2.13.0<br>metrics-server v0.8.0-20<br>microsoft-defender-admission-controller 0.11.20<br>microsoft-defender-antimalware-collector 1.0.21<br>microsoft-defender-low-level-collector 2.1.127<br>microsoft-defender-low-level-init 1.3.81<br>microsoft-defender-old-file-cleaner 1.1.64<br>microsoft-defender-pod-collector 1.0.264<br>microsoft-defender-security-publisher 1.1.70<br>microsoft-defender-sensor-release-version 0.9.62<br>open-policy-agent-gatekeeper v3.23.0-4<br>osm-bootstrap v1.2.15-7<br>osm-controller v1.2.15-7<br>osm-crds v1.2.15-8<br>osm-healthcheck v1.2.15-6<br>osm-init v1.2.15-5<br>osm-injector v1.2.15-7<br>osm-sidecar v1.38.3-2<br>overlay-vpa-admission-controller v1.5.1-15<br>overlay-vpa-recommender v1.5.1-12<br>overlay-vpa-updater v1.5.1-12<br>ratify v1.4.5-1<br>resourcesync-operator 1.7.18<br>retina-agent v1.2.4<br>retina-agent-enterprise v0.3.0<br>retina-agent-init-enterprise v0.3.0<br>retina-agent-win v1.2.4<br>retina-init v1.2.4<br>retina-operator v0.3.0<br>secrets-store-csi-driver v1.6.0-6<br>secrets-store-csi-driver-windows v1.6.0-6<br>secrets-store-driver-registrar-linux v2.17.0-3<br>secrets-store-driver-registrar-windows v2.17.0-3<br>secrets-store-livenessprobe-linux v2.19.0-3<br>secrets-store-livenessprobe-windows v2.19.0-3<br>secrets-store-provider-azure v1.8.2-5<br>secrets-store-provider-azure-windows v1.8.2-5<br>sgx-attestation 3.3.5<br>sgx-plugin 1.0.5<br>sgx-webhook 1.2.7<br>tigera-operator v1.40.2<br>tunnel-front master.260519.2<br>tunnel-openvpn-front master.260519.2<br>windows-gmsa-webhook-image v0.12.1-17<br>workload-identity-webhook v1.5.1-17 | **Linux - Ubuntu 24.04**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-ubuntu24.04u2<br>azure-acr-credential-provider-pmc 1.35.8-ubuntu24.04u1<br>blobfuse2 2.5.5<br>containerd 2.3.3-ubuntu24.04u2<br>containernetworking-plugins 1.9.0-ubuntu24.04u1<br>datacenter-gpu-manager-4-core 1:4.5.3-1<br>datacenter-gpu-manager-4-proprietary 1:4.5.3-1<br>dcgm-exporter 4.8.2-ubuntu24.04u10<br>dra-driver-nvidia-gpu 0.4.1-ubuntu24.04u5<br>inspektor-gadget 0.55.0-ubuntu24.04u2<br>kubectl 1.35.x<br>kubelet 1.35.x<br>kubernetes-cri-tools 1.34.0-ubuntu24.04u17<br>node-exporter 1.9.1-ubuntu24.04u24<br>nvidia-device-plugin 0.19.3-ubuntu24.04u6<br>runc 1.4.3-ubuntu24.04u2<br>**Linux - AzureLinux 3.0**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-2.azl3<br>aznfs 3.0.15-1<br>azure-acr-credential-provider-pmc 1.35.8-1.azl3<br>containerd 2.2.4-6.azl3<br>containernetworking-plugins 1.9.0-1.azl3<br>dra-driver-nvidia-gpu 0.4.1-5.azl3<br>inspektor-gadget 0.55.0-2.azl3<br>kubectl 1.35.x<br>kubelet 1.35.x<br>kubernetes-cri-tools 1.34.0-16.azl3<br>node-exporter 1.9.1-23.azl3<br>nvidia-container-toolkit 1.17.8<br>nvidia-device-plugin 0.19.3-6.azl3<br>**Windows - Windows2022**<br>containerd v2.0.4-azure.1 | azure-cni-installer v1.7.16-0 -> v1.8.12<br>azure-cns-linux v1.7.16-0 -> v1.8.12<br>azure-cns-windows v1.7.16-0 -> v1.8.12<br>azuredisk-csi-linux v1.33.11-2 -> v1.34.5-2<br>azuredisk-csi-windows v1.33.11 -> v1.34.5<br>azurefile-csi-linux v1.34.8-7 -> v1.35.7-7<br>azurefile-csi-windows v1.34.8 -> v1.35.7<br>cloud-provider-node-manager-linux v1.34.13-1 -> v1.35.8-1<br>cloud-provider-node-manager-windows v1.34.13-windows-hpc-1 -> v1.35.8-windows-hpc-1<br>csi-livenessprobe v2.17.0-13 -> v2.18.0-8<br>csi-node-driver-registrar v2.15.0-13 -> v2.16.0-8<br>kube-proxy v1.34.0-1 -> v1.35.0-1<br>kubectl v1.34.0-22 -> v1.35.0-19<br>microsoft-defender-low-level-collector 2.0.259 -> 2.1.127<br>microsoft-defender-sensor-release-version 0.8.55 -> 0.9.62<br>tigera-operator v1.38.8 -> v1.40.2 |

### Kubernetes 1.34

| AKS managed add-ons | OS components | Breaking changes from Kubernetes 1.33.0 |
|---|---|---|
| aad-pod-identity-nmi v1.8.22-4<br>aci-connector-linux v1.6.4-9<br>addon-resizer v1.8.23-29<br>addon-token-adapter-linux master.260809.2<br>addon-token-adapter-windows master.260809.2<br>addon-token-reconciler master.260720.3<br>ai-toolchain-operator 0.6.0<br>aks-windows-gpu-device-plugin 0.0.19<br>alb-controller 1.10.32<br>ama-logs-linux 3.6.0<br>ama-logs-win win-3.6.0<br>apiserver-network-proxy-agent v0.32.1-13<br>app-routing-operator 0.2.27<br>appmonitoring-webhook 1.1.4<br>azure-cni-installer v1.7.16-0<br>azure-cni-networkmonitor v1.1.8post2<br>azure-cns-linux v1.7.16-0<br>azure-cns-windows v1.7.16-0<br>azure-ipam-installer v0.4.0-0<br>azure-monitor-metrics-cfg-reader 7.2.1-main-07-31-2026-4a713766-cfg<br>azure-monitor-metrics-ksm v2.19.1-2<br>azure-monitor-metrics-linux 7.2.1-main-07-31-2026-4a713766<br>azure-monitor-metrics-target-allocator 7.2.1-main-07-31-2026-4a713766-targetallocator<br>azure-monitor-metrics-windows 7.2.1-main-07-31-2026-4a713766-win<br>azure-npm-image v1.6.48-0<br>azure-npm-image-windows v1.5.5<br>azure-policy v1.17.0-1<br>azure-policy-audit v1.17.0-1<br>azure-policy-webhook v1.17.0-1<br>azuredisk-csi-linux v1.33.11-2<br>azuredisk-csi-windows v1.33.11<br>azurefile-csi-linux v1.34.8-7<br>azurefile-csi-windows v1.34.8<br>blob-csi v1.27.9-9<br>calico-cni-image v3.8.9.3<br>calico-node-image v3.8.9.5<br>calico-pod2daemon-flexvol-image v3.8.9.1<br>calico-typha-image v3.8.9<br>certgen v0.3.2<br>cilium-agent v1.18.12-260811<br>cilium-envoy v1.31.5-250218<br>cilium-operator v1.18.12-260811<br>cloud-provider-node-manager-linux v1.34.13-1<br>cloud-provider-node-manager-windows v1.34.13-windows-hpc-1<br>cluster-health-monitor v0.0.11<br>cluster-proportional-autoscaler v1.9.0-22<br>coredns v1.13.1-22<br>cost-analysis-agent v0.0.27<br>cost-analysis-opencost v1.111.0-16<br>cost-analysis-prometheus v2.54.1<br>cost-analysis-scraper v0.0.28<br>cost-analysis-victoria-metrics v1.103.0<br>csi-livenessprobe v2.17.0-13<br>csi-node-driver-registrar v2.15.0-13<br>fqdn-policy v1.16.6-250129<br>gitops-manager-config-agent 1.7.18<br>gitops-manager-config-operator 1.7.18<br>gpu-provisioner 0.3.5<br>health-probe-proxy v1.36.4-1<br>http-application-routing-defaultbackend 1.4<br>http-application-routing-external-dns v0.10.2-8<br>http-application-routing-nginx-ingress-controller v1.2.1-11<br>hubble-relay v1.18.12-260811<br>identity-binding-workload-identity-webhook v1.6.0-alpha.1<br>image-cleaner v1.4.1-3<br>ingress-appgw 1.9.12<br>keda 2.17.3-15<br>keda-admission-webhooks 2.17.3-13<br>keda-metrics-apiserver 2.17.3-14<br>kube-egress-gateway-cni v0.1.4<br>kube-egress-gateway-cni-ipam v0.1.4<br>kube-egress-gateway-cnimanager v0.1.5<br>kube-egress-gateway-daemon v0.1.4<br>kube-egress-gateway-daemon-init v0.1.4<br>kube-proxy v1.34.0-1<br>kube-state-metrics v2.15.0-19<br>kubectl v1.34.0-22<br>local-csi-driver v0.2.4<br>local-csi-driver-csi-provisioner v5.2.0<br>local-csi-driver-csi-resizer v1.13.2<br>local-csi-driver-registrar v2.13.0<br>metrics-server v0.8.0-20<br>microsoft-defender-admission-controller 0.11.20<br>microsoft-defender-antimalware-collector 1.0.21<br>microsoft-defender-low-level-collector 2.0.259<br>microsoft-defender-low-level-init 1.3.81<br>microsoft-defender-old-file-cleaner 1.1.64<br>microsoft-defender-pod-collector 1.0.264<br>microsoft-defender-security-publisher 1.1.70<br>microsoft-defender-sensor-release-version 0.8.55<br>open-policy-agent-gatekeeper v3.23.0-4<br>osm-bootstrap v1.2.15-7<br>osm-controller v1.2.15-7<br>osm-crds v1.2.15-8<br>osm-healthcheck v1.2.15-6<br>osm-init v1.2.15-5<br>osm-injector v1.2.15-7<br>osm-sidecar v1.38.3-2<br>overlay-vpa-admission-controller v1.5.1-15<br>overlay-vpa-recommender v1.5.1-12<br>overlay-vpa-updater v1.5.1-12<br>ratify v1.4.5-1<br>resourcesync-operator 1.7.18<br>retina-agent v1.2.4<br>retina-agent-enterprise v0.3.0<br>retina-agent-init-enterprise v0.3.0<br>retina-agent-win v1.2.4<br>retina-init v1.2.4<br>retina-operator v0.3.0<br>secrets-store-csi-driver v1.6.0-6<br>secrets-store-csi-driver-windows v1.6.0-6<br>secrets-store-driver-registrar-linux v2.17.0-3<br>secrets-store-driver-registrar-windows v2.17.0-3<br>secrets-store-livenessprobe-linux v2.19.0-3<br>secrets-store-livenessprobe-windows v2.19.0-3<br>secrets-store-provider-azure v1.8.2-5<br>secrets-store-provider-azure-windows v1.8.2-5<br>sgx-attestation 3.3.5<br>sgx-plugin 1.0.5<br>sgx-webhook 1.2.7<br>tigera-operator v1.38.8<br>tunnel-front master.260519.2<br>tunnel-openvpn-front master.260519.2<br>windows-gmsa-webhook-image v0.12.1-17<br>workload-identity-webhook v1.5.1-17 | **Linux - Ubuntu 22.04**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-ubuntu22.04u2<br>azure-acr-credential-provider-pmc 1.34.13-ubuntu22.04u1<br>blobfuse2 2.5.5<br>containerd 1.7.34-ubuntu22.04u2<br>containernetworking-plugins 1.9.0-ubuntu22.04u1<br>datacenter-gpu-manager-4-core 1:4.5.3-1<br>datacenter-gpu-manager-4-proprietary 1:4.5.3-1<br>dcgm-exporter 4.8.2-ubuntu22.04u10<br>dra-driver-nvidia-gpu 0.4.1-ubuntu22.04u5<br>inspektor-gadget 0.55.0-ubuntu22.04u2<br>kubectl 1.34.x<br>kubelet 1.34.x<br>kubernetes-cri-tools 1.34.0-ubuntu22.04u17<br>node-exporter 1.9.1-ubuntu22.04u24<br>nvidia-device-plugin 0.19.3-ubuntu22.04u6<br>runc 1.4.3-ubuntu22.04u2<br>**Linux - AzureLinux 3.0**<br>acr-mirror 1.0.0<br>aks-secure-tls-bootstrap-client 1.1.4-2.azl3<br>aznfs 3.0.15-1<br>azure-acr-credential-provider-pmc 1.34.13-1.azl3<br>containerd 2.2.4-6.azl3<br>containernetworking-plugins 1.9.0-1.azl3<br>dra-driver-nvidia-gpu 0.4.1-5.azl3<br>inspektor-gadget 0.55.0-2.azl3<br>kubectl 1.34.x<br>kubelet 1.34.x<br>kubernetes-cri-tools 1.34.0-16.azl3<br>node-exporter 1.9.1-23.azl3<br>nvidia-container-toolkit 1.17.8<br>nvidia-device-plugin 0.19.3-6.azl3<br>**Windows - Windows2022**<br>containerd v2.0.4-azure.1 | azurefile-csi-linux v1.33.10-41 -> v1.34.8-7<br>azurefile-csi-windows v1.33.10 -> v1.34.8<br>blob-csi v1.26.16-1 -> v1.27.9-9<br>cilium-agent v1.17.18-260811 -> v1.18.12-260811<br>cilium-operator v1.17.18-260811 -> v1.18.12-260811<br>cloud-provider-node-manager-linux v1.33.16-1 -> v1.34.13-1<br>cloud-provider-node-manager-windows v1.33.16-windows-hpc-1 -> v1.34.13-windows-hpc-1<br>coredns v1.12.1-26 -> v1.13.1-22<br>hubble-relay v1.17.18-260811 -> v1.18.12-260811<br>ingress-appgw 1.8.1 -> 1.9.12<br>kube-proxy v1.33.0-1 -> v1.34.0-1<br>kubectl v1.33.0 -> v1.34.0-22<br>metrics-server v0.7.2-26 -> v0.8.0-20<br>overlay-vpa-admission-controller v1.2.2-3 -> v1.5.1-15<br>overlay-vpa-recommender v1.2.2-3 -> v1.5.1-12<br>overlay-vpa-updater v1.2.2-3 -> v1.5.1-12 |

### Kubernetes 1.33

| **AKS managed add-ons (add-on)** | **AKS components (ccp)** | **OS components** | **Breaking changes from Kubernetes 1.32.0** |
| ------------------------------- | ------------------------ | ----------------- | ------------------------------------------- |
| - aci-connector-linux 1.6.2 <br> - addon-resizer v1.8.23-2 <br> - ai-toolchain-operator 0.4.5 <br> - aks-windows-gpu-device-plugin 0.0.19 <br> - ama-logs-linux 3.1.26 <br> - ama-logs-win 3.1.26 <br> - app-routing-operator 0.0.3 <br> - azure-monitor-metrics-cfg-reader 6.16.0-main-04-15-2025-d78050c6-cfg <br> - azure-monitor-metrics-ksm v2.15.0-4 <br> - azure-monitor-metrics-linux 6.16.0-main-04-15-2025-d78050c6 <br> - azure-monitor-metrics-target-allocator 6.16.0-main-04-15-2025-d78050c6-targetallocator <br> - azure-monitor-metrics-windows 6.16.0-main-04-15-2025-d78050c6-win <br> - azure-npm-image v1.5.45 <br> - azure-npm-image-windows v1.5.5 <br> - azure-policy 1.10.1 <br> - azure-policy-webhook 1.10.0 <br> - certgen v0.1.9 <br> - cilium-agent v1.17.9 <br> - cilium-envoy v1.34.10-251105 <br> - cilium-operator-generic v1.17.9-260304 <br> - cloud-provider-node-manager-linux v1.33.0 <br> - cloud-provider-node-manager-windows v1.33.0 <br> - cluster-proportional-autoscaler v1.9.0-1 <br> - container-networking-cilium-agent v1.17.9-260304 <br> - container-networking-cilium-operator-generic v1.17.9-260304 <br> - coredns v1.12.1-1 <br> - cost-analysis-agent v0.0.23 <br> - cost-analysis-opencost v1.111.0 <br> - cost-analysis-prometheus v2.54.1 <br> - cost-analysis-victoria-metrics v1.103.0 <br> - extension-config-agent 1.23.3 <br> - extension-manager 1.23.3 <br> - fqdn-policy v1.16.6-250129 <br> - gpu-provisioner 0.3.3 <br> - health-probe-proxy v1.29.1 <br> - hubble-relay v1.15.0 <br> - image-cleaner v1.3.1 <br> - ingress-appgw 1.8.1 <br> - ip-masq-agent-v2 v0.1.15-2 <br> - ipv6-hp-bpf v0.0.1 <br> - keda v2.16.1 <br> - keda-admission-webhooks v2.16.1 <br> - keda-metrics-apiserver v2.16.1 <br> - kube-egress-gateway-cni v0.0.20 <br> - kube-egress-gateway-cni-ipam v0.0.20 <br> - kube-egress-gateway-cnimanager v0.0.20 <br> - kube-egress-gateway-daemon v0.0.20 <br> - kube-egress-gateway-daemon-init v0.0.20 <br> - metrics-server v0.7.2-6 <br> - microsoft-defender-admission-controller 20250325.2 <br> - microsoft-defender-low-level-collector 2.0.205 <br> - microsoft-defender-low-level-init 1.3.81 <br> - microsoft-defender-old-file-cleaner 1.0.214 <br> - microsoft-defender-pod-collector 1.0.177 <br> - microsoft-defender-security-publisher 1.0.211 <br> - open-policy-agent-gatekeeper v3.18.2-1 <br> - osm-bootstrap v1.2.9 <br> - osm-controller v1.2.9 <br> - osm-crds v1.2.9 <br> - osm-healthcheck v1.2.9 <br> - osm-init v1.2.9 <br> - osm-injector v1.2.9 <br> - osm-sidecar v1.32.2-hotfix.20241216 <br> - overlay-vpa 1.2.1 <br> - overlay-vpa-webhook-generation master.250430.1 <br> - ratify-base v1.2.3 <br> - retina-agent v0.0.31 <br> - retina-agent-enterprise v0.1.9 <br> - retina-agent-win v0.0.31 <br> - retina-operator v0.1.9 <br> - secrets-store-csi-driver v1.4.8 <br> - secrets-store-csi-driver-windows v1.4.8 <br> - secrets-store-driver-registrar-linux v2.11.1 <br> - secrets-store-driver-registrar-windows v2.11.1 <br> - secrets-store-livenessprobe-linux v2.13.1 <br> - secrets-store-livenessprobe-windows v2.13.1 <br> - secrets-store-provider-azure v1.6.2 <br> - secrets-store-provider-azure-windows v1.6.2 <br> - sgx-attestation 3.3.1 <br> - sgx-plugin 1.0.0 <br> - sgx-webhook 1.2.2 <br> - tigera-operator v1.36.7 <br> - windows-gmsa-webhook-image v0.12.1-2 <br> - workload-identity-webhook v1.5.0 | - addon-override-manager master.250116.1 <br> - apiserver-network-proxy-server v0.30.3-hotfix.20240819 <br> - app-routing-operator 0.2.5 <br> - ccp-webhook master.250509.3 <br> - cluster-autoscaler v1.32.1-aks <br> - cost-analysis-scraper v0.0.23 <br> - customer-net-probe master.250430.1 <br> - envoy v1.31.5-master.241218.3 <br> - ingress-dispatcher v1.31.5-master.250126.7 <br> - kube-state-metrics v2.15.0-4 <br> - gpu-provisioner 0.3.3 <br> - karpenter 0.7.3-aks <br> - kube-egress-gateway-controller v0.0.20 <br> - kubelet-serving-csr-approver v0.0.7 <br> - live-patching-controller v0.0.8 | - **Linux - Ubuntu 22.04** <br>   - containerd 1.7.27-ubuntu22.04u1 <br>   - kubernetes-cri-tools 1.32.0-ubuntu22.04u3 <br> - runc 1.2.6-ubuntu22.04u1 <br> - **Linux - AzureLinux 3.0** <br> - containerd 2.0.0-4.azl3 <br> - nvidia-container-toolkit 1.17.3 <br> - **Windows - Windows2022** <br> - containerd v1.7.20-azure.1 | - coredns v1.11.3-7 → v1.12.1-1 <br> - cloud-provider-node-manager-windows v1.32.5 → v1.33.0 <br> - cloud-provider-node-manager-linux v1.32.5 → v1.33.0 |

### Kubernetes 1.32

| **AKS managed add-ons (add-on)** | **AKS components (ccp)** | **OS components** | **Breaking changes** |
| ------------------------------- | ------------------------ | ----------------- | -------------------- |
| - Azure Policy 1.8.0 <br> - Metrics-Server 0.6.3 <br> - App routing operator v0.2.3 <br> - KEDA 2.14.1 <br> - Open Service Mesh v1.2.9 <br> - Core DNS V1.9.4 <br> - Overlay VPA 1.0.0 <br> - Azure-Keyvault-SecretsProvider v1.4.5 <br> - Application Gateway Ingress Controller (AGIC) 1.7.2 <br> - Image Cleaner v1.3.1 <br> - Azure Workload identity v1.3.0 <br> - Microsoft Defender Low Level Collector 2.0.186 <br> - open-policy-agent-gatekeeper v3.17.1 <br> - Retina v0.0.17 | - Cilium v1.17.9 <br> - Cluster Autoscaler v1.30.6-aks <br> - Tigera-Operator v1.34.7 | - OS Image Ubuntu 22.04 Cgroups V2 <br> - ContainerD 1.7.23-ubuntu22.04u1 for Linux and v1.6.35+azure for Windows <br> - Azure Linux 3.0 <br> - Cgroups V2 <br> - ContainerD 1.7.13-3.azl | - [Calico v1.34.7](https://github.com/tigera/operator/releases/tag/v1.34.7) |

### Kubernetes 1.31

| **AKS managed add-ons (add-on)** | **AKS components (ccp)** | **OS components** | **Breaking changes** |
| ------------------------------- | ------------------------ | ----------------- | -------------------- |
| - Azure Policy 1.8.0 <br> - Metrics-Server 0.6.3 <br> - App routing operator v0.2.3 <br> - KEDA 2.14.1 <br> - Open Service Mesh v1.2.9 <br> - Core DNS V1.9.4 <br> - Overlay VPA 1.0.0 <br> - Azure-Keyvault-SecretsProvider v1.4.5 <br> - Application Gateway Ingress Controller (AGIC) 1.7.2 <br> - Image Cleaner v1.3.1 <br> - Azure Workload identity v1.3.0 <br> - Microsoft Defender Low Level Collector 2.0.186 <br> - open-policy-agent-gatekeeper v3.17.1 <br> - Retina v0.0.17 | - Cilium v1.16.6 <br> - Cluster Autoscaler v1.30.6-aks <br> - Tigera-Operator v1.30.11 | - OS Image Ubuntu 22.04 Cgroups V2 <br> - ContainerD 1.7.23-ubuntu22.04u1 for Linux and v1.6.35+azure for Windows <br> - Azure Linux 3.0 <br> - Cgroups V2 <br> - ContainerD 1.7.13-3.azl | - [Calico v1.30.11](https://github.com/tigera/operator/releases/tag/v1.30.11) |

### Kubernetes 1.30

| **AKS managed add-ons (add-on)** | **AKS components (ccp)** | **OS components** | **Breaking changes** |
| ------------------------------- | ------------------------ | ----------------- | -------------------- |
| - Azure Policy 1.3.0 <br> - App routing operator v0.2.3 <br> - Metrics-Server 0.6.3 <br> - KEDA 2.11.2 <br> - Open Service Mesh 1.2.7 <br> - Core DNS V1.9.4 <br> - Overlay VPA 0.13.0 <br> - Azure-Keyvault-SecretsProvider 1.4.1 <br> - Application Gateway Ingress Controller (AGIC) 1.7.2 <br> - Image Cleaner v1.2.3 <br> - Azure Workload identity v1.2.0 <br> - Microsoft Defender Security Publisher 1.0.68 <br> - Microsoft Defender Old File Cleaner 1.3.68 <br> - Microsoft Defender Pod Collector 1.0.78 <br> - Microsoft Defender Low Level Collector 2.0.186 <br> - Microsoft Entra pod-managed identity 1.8.13.6 <br> - GitOps 1.8.1 <br> - CSI Secrets Store Driver 1.3.4-1 <br> - [azurefile-csi-driver 1.29.3](https://github.com/kubernetes-sigs/azurefile-csi-driver/releases/tag/v1.29.3) | - Cilium v1.14.20 <br> - CNI v1.4.43.1 (Default)/v1.5.11 (Azure CNI Overlay) <br> - Cluster Autoscaler 1.27.3 <br> - Tigera-Operator 1.30.7 | - OS Image Ubuntu 22.04 Cgroups V2 <br> - ContainerD 1.7.5 for Linux and 1.7.1 for Windows <br> - Azure Linux 2.0 <br> - Cgroups V2 <br> - ContainerD 1.6 | - Tigera-Operator 1.30.7 |

## Alias minor version in AKS

> [!NOTE]
> Alias minor version requires Azure CLI version 2.37 or above and API version 20220401 or above. Use `az upgrade` to install the latest version of the CLI.

You can create an AKS cluster without specifying a patch version. When you create a cluster without designating a patch, the cluster runs the minor version's latest GA patch. If you want to upgrade your patch version in the same minor version, use [autoupgrade](./auto-upgrade-cluster.md).

To see what patch you're on, run the `az aks show --resource-group myResourceGroup --name myAKSCluster` command. In the output, the `currentKubernetesVersion` property shows the whole Kubernetes version. For example:

```output
{
 "apiServerAccessProfile": null,
  "autoScalerProfile": null,
  "autoUpgradeProfile": null,
  "azurePortalFqdn": "myaksclust-myresourcegroup.portal.hcp.eastus.azmk8s.io",
  "currentKubernetesVersion": "<major>.<minor>.<patch>",
}
```

## Kubernetes version support policy

AKS defines a generally available (GA) version as a version available in all regions and enabled in all SLO or SLA measurements. AKS supports three GA minor versions of Kubernetes:

- The latest GA version (_N_).
- The two previous minor versions (_N-1_ and _N-2_).
  - Each supported minor version can support any number of patches at a given time. AKS reserves the right to deprecate patches if a critical CVE or security vulnerability is detected. For awareness on patch availability and any ad-hoc deprecation, refer to version release notes and visit the [AKS release status webpage][aks-tracker].

AKS might also support preview versions, which are explicitly labeled and subject to [preview terms and conditions][preview-terms].

AKS provides platform support only for one GA minor version of Kubernetes after the regular supported versions. The platform support window of Kubernetes versions on AKS is known as _N-3_. For more information, see [platform support policy](#platform-support-policy).

> [!NOTE]
> AKS uses safe deployment practices that involve gradual region deployment. This means it might take up to 10 business days for a new release or a new version to be available in all regions.

The supported window of Kubernetes minor versions on AKS is known as _N-2_, where _N_ refers to the latest release, meaning that two previous minor releases are also supported.

For example, on the day that AKS introduces version 1.29, support is provided for the following versions:

| New minor version | Supported minor versions |
| ----------------- | ------------------------ |
| 1.29 | 1.29, 1.28, 1.27 |

When a new minor version is introduced, the oldest minor version is deprecated and removed. For example, let's say the current supported minor version list is _1.29_, _1.28_, and _1.27_. When AKS releases 1.30, all the 1.27 versions go out of support 30 days later.

AKS might support any number of **patches** based on upstream community release availability for a given minor version. AKS reserves the right to deprecate any of these patches at any given time due to a CVE or potential bug concern. We encourage you to use the latest patch for a minor version.

## Platform support policy

Platform support policy is a reduced support plan for certain unsupported Kubernetes versions. During platform support, customers only receive support from Microsoft for AKS/Azure platform related issues. Any issues related to Kubernetes functionality and components aren't supported.

Platform support policy applies to clusters in an _N-3_ version (where _N_ is the latest supported AKS GA minor version), before the cluster drops to _N-4_. For example, Kubernetes v1.26 is considered platform support when v1.29 is the latest GA version. Let's say you're running an _N-2_ version. The moment that version becomes _N-3_, it also ends its official support, and you enter into the platform support policy.

AKS relies on the releases and patches from [Kubernetes](https://kubernetes.io/releases/), which is an open-source project that only supports a sliding window of three minor versions. AKS can only guarantee [full support](#kubernetes-version-support-policy) while those versions are being serviced upstream. Since there's no more patches being produced upstream, AKS can either leave those versions unpatched or fork. Due to this limitation, platform support doesn't support anything from relying on Kubernetes upstream.

The following table outlines support guidelines for community support compared to platform support:

| Support category | Community support (_N-2_) | Platform support (_N-3_) |
| ---------------- | ------------------------- | ------------------------ |
| Upgrades from N-3 to a supported version | Supported | Supported |
| Platform (Azure) availability | Supported | Supported |
| Node pool scaling | Supported | Supported |
| VM availability | Supported | Supported |
| Storage, Networking related issues | Supported | Supported except for bug fixes and retired components |
| Start/stop | Supported | Supported |
| Rotate certificates | Supported | Supported |
| Infrastructure SLA | Supported | Supported |
| Control Plane SLA | Supported | Supported |
| Platform (AKS) SLA | Supported | Not supported |
| Kubernetes components (including add-ons) | Supported | Not supported |
| Component updates | Supported | Not supported |
| Component hotfixes | Supported | Not supported |
| Applying bug fixes | Supported | Not supported |
| Applying security patches | Supported | Not supported |
| Kubernetes API support | Supported | Not supported |
| Node pool creation | Supported | Supported |
| Cluster creation | Supported | Not supported |
| Node pool snapshot | Supported | Not supported |
| Node image upgrade | Supported | Supported |

> [!NOTE]
> The table is subject to change and outlines common support scenarios. Any scenarios related to Kubernetes functionality and components aren't supported for _N-3_. For further support, see [Support and troubleshooting for AKS](./aks-support-help.md).

### Supported `kubectl` versions

You can use a `kubectl` version that is one minor version older or newer than your kube-apiserver version. For more information, see the [Kubernetes support policy for kubectl](https://kubernetes.io/docs/setup/release/version-skew-policy/#kubectl).

For example, if your _kube-apiserver_ is at _1.28_, then you can use versions _1.27_ to _1.29_ of `kubectl`.

To install or update `kubectl` to the latest version, use the command based on your preferred tool:

#### [Azure CLI](#tab/azure-cli)

```azurecli-interactive
az aks install-cli
```

#### [Azure PowerShell](#tab/azure-powershell)

```azurepowershell-interactive
Install-AzAksKubectl -Version latest
```

---

## Long Term Support (LTS)

AKS offers one year of Community Support and one year of Long Term Support (LTS), including backported security fixes from the upstream community. Our upstream LTS working group contributes efforts back to the community to provide our customers with a longer support window.

For more information on LTS, see [Long term support for Azure Kubernetes Service (AKS)](./long-term-support.md).

## Release and deprecation process

For upcoming version releases and deprecations, see the [AKS Kubernetes release calendar](#aks-kubernetes-release-calendar-and-upcoming-versions).

For new **minor** versions of Kubernetes:

- AKS announces new version release dates and old version deprecation in the [AKS Release notes](https://aka.ms/aks/releasenotes) at least 30 days before removal.
- AKS uses [Azure Advisor](/azure/advisor/advisor-overview) to alert you if a new version could cause issues in your cluster because of deprecated APIs. Azure Advisor also alerts you if you're out of support.
- AKS publishes a [service health notification](/azure/service-health/service-health-overview) available to all users with AKS and portal access and sends an email to the subscription administrators with the planned version removal dates.

  > [!NOTE]
  > To view or change your subscription administrators, see [manage Azure subscriptions](/azure/cost-management-billing/manage/add-change-subscription-administrator#assign-a-subscription-administrator).

- You have **30 days** from version removal to upgrade to a supported minor version release to continue receiving support.

For new **patch** versions of Kubernetes:

- Because of the urgent nature of patch versions, they can be introduced into the service as they become available. Once available, patches have a two month minimum lifecycle.
- In general, AKS doesn't broadly communicate the release of new patch versions. However, AKS constantly monitors and validates available CVE patches to support them in AKS in a timely manner. If a critical patch is found or user action is required, AKS notifies you to upgrade to the newly available patch.
- You have **30 days** from a patch release's removal from AKS to upgrade into a supported patch and continue receiving support. However, you'll **no longer be able to create clusters or node pools once the version is deprecated/removed**.

### Supported versions policy exceptions

AKS reserves the right to add or remove new/existing versions with one or more critical production-impacting bugs or security issues without advance notice.

Specific patch releases might be skipped or rollout accelerated, depending on the severity of the bug or security issue.

## Azure portal and CLI versions

If you deploy an AKS cluster by using Azure portal, Azure CLI, or Azure PowerShell, the cluster defaults to the _N-1_ minor version and latest patch.

To find out what versions are currently available for your subscription and region, use the command based on your preferred tool:

### [Azure CLI](#tab/azure-cli)

```azurecli-interactive
# The following example lists the available Kubernetes versions for the EastUS region:

az aks get-versions --location eastus --output table
```

### [Azure PowerShell](#tab/azure-powershell)

```azurepowershell-interactive
# The following example lists the available Kubernetes versions for the EastUS region:

Get-AzAksVersion -Location eastus
```

---

## Frequently asked questions (FAQ)

### How does Microsoft notify me of new Kubernetes versions?

The AKS team announces new Kubernetes version release dates in our documentation, on [GitHub](https://github.com/Azure/AKS/releases), and via email to subscription administrators with clusters nearing end of support. AKS also uses [Azure Advisor](/azure/advisor/advisor-overview) to alert you inside the Azure portal if you're out of support and inform you of deprecated APIs that can affect your application or development process.

### How often should I expect to upgrade Kubernetes versions to stay in support?

Starting with Kubernetes 1.19, the [open source community expanded support to one year](https://kubernetes.io/blog/2020/08/31/kubernetes-1-19-feature-one-year-support/). AKS commits to enabling patches and support matching the upstream commitments. For AKS clusters on 1.19 and greater, you can upgrade at a minimum of once a year to stay on a supported version.

### What happens when you upgrade a Kubernetes cluster with a minor version that isn't supported?

If your version falls out of support per the [supported Kubernetes versions list](#aks-kubernetes-release-calendar-and-upcoming-versions), you need to upgrade. You can upgrade from unsupported versions to supported versions. For example:

- If the lowest supported AKS minor version is _1.33_ and you're on _1.32_ or older, you're outside of support.
- If you successfully upgrade from _1.32_ to _1.33_ or higher, you're back within the support policies.

Downgrades or rollback to an unsupported version aren't supported. Additionally, the further the cluster version is from the lowest supported version, the higher the likelihood of upgrade problems. In that case, creation of a new cluster and workload migration would be a better approach.

### What does it mean to be "outside of support"?

"Outside of support" means:

- The version you're running is outside of the supported versions list.
- You'll be asked to upgrade the cluster to a supported version when requesting support, unless you're within the 30-day grace period after version deprecation.

Additionally, AKS doesn't make any runtime or other guarantees for clusters outside of the supported versions list.

### Can you stay on a Kubernetes version forever?

If a cluster is out of support for more than three minor versions and carries security risks, Azure  proactively contacts you. They advise you to upgrade your cluster. If you don't take further action, Azure reserves the right to automatically upgrade your cluster on your behalf.

### What happens if you scale a Kubernetes cluster with a minor version that isn't supported?

For minor versions not supported by AKS, scaling in or out should continue to work. Since there are no guarantees with quality of service, we recommend upgrading to bring your cluster back into support.

### What version does the control plane support if the node pool isn't in one of the supported AKS versions?

The control plane and all node pools must remain within the supported version skew window. Starting with Kubernetes 1.28, the control plane can be up to three minor versions ahead of node pools. For details, see the [Kubernetes version upgrade rules](./upgrade-aks-control-plane.md#kubernetes-version-upgrade-rules).

### What is the allowed difference in versions between the control plane and node pools?

The [version skew policy](https://kubernetes.io/releases/version-skew-policy/) now allows a difference of up to three versions between control plane and agent pools. AKS follows this skew version policy change starting from version 1.28 onwards.

### Can I skip multiple AKS versions during a cluster upgrade?

Yes, you can skip minor versions in some cases. However, if you upgrade the control plane independently from the node pools, you must satisfy Kubernetes [version skew policies](https://kubernetes.io/releases/version-skew-policy/). The Kubernetes version skew policy currently supports only N-3, so the control plane and agent pools must be within N-3 of each other.

- **LTS**: A version with the AKS Long-Term Support plan enabled. See [LTS versions](#lts-versions).
- **Unsupported LTS**: An LTS-enabled version that is past its LTS end-of-life date in the [LTS versions](#lts-versions) table.
- **Supported non-LTS**: A version that isn't LTS but is still listed as supported in the [AKS Kubernetes release calendar](#aks-kubernetes-release-calendar-and-upcoming-versions).
- **Unsupported non-LTS**: A version that isn't LTS and is no longer listed as supported in the [AKS Kubernetes release calendar](#aks-kubernetes-release-calendar-and-upcoming-versions).

| Starting version | Target version | Can skip multiple minors? | Constraint | Support statement |
| --- | --- | --- | --- | --- |
| LTS | Higher LTS | Yes | Target must be listed by AKS and satisfy version skew and validation checks. | Supported |
| Unsupported LTS | Supported LTS | Conditional | Target must be listed by AKS and satisfy validation checks. | Unsupported recovery path |
| Unsupported non-LTS | LTS | Conditional | LTS target must be listed by AKS and satisfy validation checks. Control-plane-only upgrades aren't supported; a full cluster upgrade is required. | Unsupported recovery path |
| Unsupported non-LTS | Lowest supported community version | Yes | Use the oldest supported GA target offered by AKS. Control-plane-only upgrades aren't supported; a full cluster upgrade is required. | Unsupported recovery path |
| Supported non-LTS | Higher community version | No | Upgrade one minor version at a time. | Supported |

Examples:

- If your cluster is on **1.29 LTS** and you want to move to **1.32 LTS**, you can skip multiple minor versions as long as **1.32 LTS** is still offered by AKS and the upgrade satisfies version skew and validation checks.
- If your cluster is on **1.28 non-LTS**, you can move to AKS LTS **1.30 LTS** by using the unsupported recovery path, as long as the target version is listed by AKS, satisfies validation checks, and you run a full cluster upgrade rather than `control-plane-only`.
- If your cluster is on supported non-LTS **1.33** and you want to move to supported non-LTS **1.35**, you can't skip directly from **1.33** to **1.35**. You must upgrade one minor version at a time, such as **1.33** to **1.34**, and then **1.34** to **1.35**.

In the preceding table, `Unsupported recovery path` indicates that the upgrade path is executed in a manner that can't be guaranteed safe and is therefore considered outside of support. AKS allows the upgrade to proceed, but it isn't supported and might carry risks.

To choose the correct path, check available targets by running `az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name>`. Review the preceding table, and then consider the risk of upgrading versus recreating the cluster and migrating workloads.

### Can I create a new 1.xx.x cluster during the platform support window?

No, the creation of new clusters isn't possible during the platform support period.

### I'm on a freshly deprecated version that is out of platform support. Can I still add new node pools, or should I upgrade?

Yes, you can add agent pools as long as they're compatible with the control plane version.

## Related content

For information on AKS cluster upgrades, see:

- [Upgrade an Azure Kubernetes Service (AKS) cluster][aks-upgrade]
- [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager][fleet-multi-cluster-upgrade]

<!-- LINKS - External -->
[aks-release]: https://releases.aks.azure.com/

<!-- LINKS - Internal -->
[aks-upgrade]: upgrade-cluster.md
[preview-terms]: https://azure.microsoft.com/support/legal/preview-supplemental-terms/
[aks-tracker]: release-tracker.md
[fleet-multi-cluster-upgrade]: /azure/kubernetes-fleet/update-orchestration
