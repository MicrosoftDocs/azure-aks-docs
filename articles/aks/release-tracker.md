---
title: AKS release tracker
description: Learn how to determine which Azure regions have AKS release deployments rolled out in real time. 
ms.topic: overview
ms.date: 02/05/2026
ms.author: yudian
author: yudian
ms.custom: mvc, build-2023
# Customer intent: "As a cloud administrator, I want to track the deployment status of AKS releases in real time by region, so that I can ensure my clusters are updated with the latest fixes and features promptly."
---

# AKS release tracker

AKS regularly releases security patches, bug fixes, component updates, and feature updates for all AKS clusters. AKS release tracker provides real-time information on when these AKS releases are landing in the region your AKS cluster is located in.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Overview

With AKS release tracker, you can follow specific component updates present in an AKS version release, such as fixes shipped to a core add-on, and node image updates for Azure Linux, Ubuntu, and Windows. The tracker provides links to the specific version of the AKS [release notes][aks-release] to help you identify relevant release instances. Real time data updates allow you to track the release order and status of each region.

AKS release tracker provides a regional breakdown of the following three independent release trains:

- **AKS releases** ships updates, bug fixes, and security patches for features and add-ons. Some of the feature/add-on updates require upgrading the AKS cluster to a minimum required Kubernetes version. For more information, see the [AKS release notes][aks-release]. These releases are automatically applied to the clusters when the release reaches the region where the cluster is located.
- **AKS Kubernetes versions** updates the [AKS supported Kubernetes minor and patch versions][supported-kubernetes-versions] and [long-term support (LTS) versions][long-term-support] available in each region. You can upgrade to new Kubernetes versions either manually or automatically using [cluster autoupgrade][auto-upgrade-cluster].
- **AKS node images** updates the latest node image available for Azure Linux, Ubuntu, and Windows in each region. You can upgrade to the latest node image version either manually or automatically using [autoupgrade for node images][auto-upgrade-node-images].

> [!NOTE]
> You can use [planned maintenance][planned-maintenance] to control the schedule of AKS-initiated maintenance (AKS release train) and user-initiated maintenance (cluster autoupgrades and node image autoupgrades).

## Use the release tracker

To view the release tracker, visit the [AKS release status webpage][release-tracker-webpage].

### AKS releases

The top half of the tracker shows the current latest version and three previously available release versions for each region and links to the corresponding release notes entries. This view is helpful when you want to track the available versions by region.

:::image type="content" source="./media/release-tracker/regional-status.png" alt-text="Screenshot of the AKS release tracker's regional status table displayed in a web browser.":::

The bottom half of the tracker shows the release order. The table has two views: *By Region* and *By Version*.

:::image type="content" source="./media/release-tracker/release-order.png" alt-text="Screenshot of the AKS release tracker's release order table displayed in a web browser.":::

### AKS supported Kubernetes versions release

AKS supports [three GA minor versions of Kubernetes][supported-kubernetes-versions] and might support any number of patches based on upstream community release availability for a given minor version. AKS also provides an [LTS option][long-term-support], which extends the support window for a Kubernetes version to give you more time to plan and test upgrades to newer Kubernetes versions. You can track all the real-time in-operation patch releases of AKS supported community versions and LTS versions by region with the **AKS Kubernetes Versions Release** tab in AKS Release Tracker. You can also reference the [AKS release calendar for minor versions][aks-release-calendar]. 

The top half of the tracker shows the regional status on the following:

- Supported [community versions of Kubernetes in AKS][supported-kubernetes-versions] and [LTS Kubernetes versions in AKS][long-term-support] that are **currently in operation** for each region. 
- The **Recent Deprecated Version** column shows the latest out-of-support Kubernetes minor version for that region. 

:::image type="content" source="./media/release-tracker/kubernetes-version-status.png" alt-text="Screenshot of the AKS release tracker's supported Kubernetes version regional status table displayed in a web browser.":::

The bottom half of the tracker shows the regional release order of all [supported Kubernetes community versions in AKS][supported-kubernetes-versions] and [LTS Kubernetes versions in AKS][long-term-support]. The table has two views: **By Region** and **By Version**.

:::image type="content" source="./media/release-tracker/kubernetes-version-order.png" alt-text="Screenshot of the AKS release tracker's supported Kubernetes version release order table displayed in a web browser.":::

### AKS node image updates

The top half of **AKS Node Image** tab shows the latest node image version and three previously available node image versions for each region. This view is helpful when you want to track the available node image versions by region.

:::image type="content" source="./media/release-tracker/node-image-status.png" alt-text="Screenshot of the AKS release tracker's node image status table displayed in a web browser.":::

The bottom half of **AKS Node Image** tab shows the node image update order. The table has two views: **By Region** and **By Version**.

:::image type="content" source="./media/release-tracker/node-image-order.png" alt-text="Screenshot of the AKS release tracker's node image order table displayed in a web browser.":::

The **AKS Security Patch** tab shows the [last node image security patch version][auto-upgrade-node-images] for each region and update order.

:::image type="content" source="./media/release-tracker/security-patch.png" alt-text="Screenshot of the AKS release tracker's security patch release status table displayed in a web browser.":::

<!-- LINKS - external -->
[aks-release]: https://github.com/Azure/AKS/releases
[release-tracker-webpage]: https://releases.aks.azure.com/webpage/index.html

<!-- LINKS - internal -->
[supported-kubernetes-versions]: supported-kubernetes-versions.md
[long-term-support]: long-term-support.md
[auto-upgrade-cluster]: auto-upgrade-cluster.md
[auto-upgrade-node-images]: auto-upgrade-node-os-image.md
[planned-maintenance]: planned-maintenance.md
[aks-release-calendar]: supported-kubernetes-versions.md#aks-kubernetes-release-calendar