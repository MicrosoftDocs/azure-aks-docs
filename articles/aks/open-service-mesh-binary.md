---
title: Download the OSM client Library
description: Download and configure the Open Service Mesh (OSM) client library
ms.topic: concept-article
ms.custom: linux-related-content
ms.date: 05/27/2026
ms.author: schaffererin
author: schaffererin
zone_pivot_groups: client-operating-system
# Customer intent: As a cloud engineer, I want to download and configure the Open Service Mesh client library for AKS, so that I can effectively manage and operate my service mesh environment while ensuring compatibility with Kubernetes versions.
---

# Download and configure the Open Service Mesh (OSM) client library

This article shows how to download the OSM client library to operate and configure the OSM add-on for Azure Kubernetes Service (AKS) and how to configure the binary for your environment.

[!INCLUDE [open-service-mesh-retirement](./includes/open-service-mesh-retirement.md)]

> [!IMPORTANT]
> The Kubernetes version of your cluster determines which OSM add-on component version is installed on your AKS cluster. To see which OSM add-on version maps to each AKS version, see the **AKS managed add-ons** column of the [Kubernetes component version table](./supported-kubernetes-versions.md#aks-components-breaking-changes-by-version). To verify the version installed on your cluster, inspect the `osm-controller` image after installation.

::: zone pivot="client-operating-system-linux"

[!INCLUDE [Linux - download and install client binary](includes/servicemesh/osm/open-service-mesh-binary-install-linux.md)]

::: zone-end

::: zone pivot="client-operating-system-macos"

[!INCLUDE [macOS - download and install client binary](includes/servicemesh/osm/open-service-mesh-binary-install-macos.md)]

::: zone-end

::: zone pivot="client-operating-system-windows"

[!INCLUDE [Windows - download and install client binary](includes/servicemesh/osm/open-service-mesh-binary-install-windows.md)]

::: zone-end

> [!WARNING]
> Don't attempt to install OSM from the binary using `osm install`. This will result in an installation of OSM that isn't integrated as an add-on for AKS.

## Configure OSM CLI variables with an OSM_CONFIG file

Users can override the default OSM CLI configuration to enhance the add-on experience. This can be done by creating a config file, similar to `kubeconfig`. The config file can be either created at `$HOME/.osm/config.yaml`, or at a different path that is exported using the `OSM_CONFIG` environment variable.

The file must contain the following YAML formatted content:

```yaml
install:
  kind: managed
  distribution: AKS
  namespace: kube-system
```

If the file isn't created at `$HOME/.osm/config.yaml`, remember to set the `OSM_CONFIG` environment variable to point to the path where the config file is created.

After setting OSM_CONFIG, the output of the `osm env` command should be the following:

```console
$ osm env
---
install:
  kind: managed
  distribution: AKS
  namespace: kube-system
```
