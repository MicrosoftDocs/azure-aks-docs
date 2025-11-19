---
title: Download the OSM client Library
description: Download and configure the Open Service Mesh (OSM) client library
ms.topic: concept-article
ms.custom: linux-related-content
ms.date: 09/25/2024
ms.author: pgibson
author: schaffererin
zone_pivot_groups: client-operating-system
# Customer intent: As a cloud engineer, I want to download and configure the Open Service Mesh client library for AKS, so that I can effectively manage and operate my service mesh environment while ensuring compatibility with Kubernetes versions.
---

# Download and configure the Open Service Mesh (OSM) client library

This article shows how to download the OSM client library to operate and configure the OSM add-on for Azure Kubernetes Service (AKS) and how to configure the binary for your environment.

> [!IMPORTANT]
> Microsoft has announced the retirement of the [Open Service Mesh (OSM) add-on for AKS](https://azure.microsoft.com/en-us/updates?id=open-service-mesh-add-on-for-aks-will-be-retired-on-september-30-2027). The upstream OSM project has also been retired by the [Cloud Native Computing Foundation (CNCF)](https://docs.openservicemesh.io/). Identify any existing OSM configurations and migrate them to equivalent Istio configurations. For migration steps, see [Migration guidance for Open Service Mesh (OSM) configurations to Istio](open-service-mesh-istio-migration-guidance.md).

> [!IMPORTANT]
> Based on the version of Kubernetes your cluster is running, the OSM add-on installs a different version of OSM.
>
> |Kubernetes version         | OSM version installed |
> |---------------------------|-----------------------|
> | 1.24.0 or greater         | 1.2.5                 |
> | Between 1.23.5 and 1.24.0 | 1.1.3                 |
> | Below 1.23.5              | 1.0.0                 |
>
> Older versions of OSM may not be available for install or be actively supported if the corresponding AKS version has reached end of life. You can check the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar) for information on AKS version support windows.

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
