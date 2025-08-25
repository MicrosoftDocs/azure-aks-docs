---
title: AKS release tracker
description: Learn how to determine which Azure regions have the weekly AKS release deployments rolled out in real time. 
ms.topic: overview
ms.date: 05/09/2024
ms.author: davidsmatlak
author: davidsmatlak
ms.custom: mvc, build-2023
# Customer intent: "As a cloud administrator, I want to track the deployment status of AKS releases in real time by region, so that I can ensure my clusters are updated with the latest fixes and features promptly."
---

# AKS release tracker

AKS releases weekly rounds of fixes and feature and component updates that affect all clusters and customers. It's important for you to know when a particular AKS release is hitting your region, and the AKS release tracker provides these details in real time by versions and regions.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Overview

With AKS release tracker, you can follow specific component updates present in an AKS version release, such as fixes shipped to a core add-on, and node image updates for Azure Linux, Ubuntu, and Windows. The tracker provides links to the specific version of the AKS [release notes][aks-release] to help you identify relevant release instances. Real time data updates allow you to track the release order and status of each region.

## Use the release tracker

To view the release tracker, visit the [AKS release status webpage][release-tracker-webpage].

### AKS releases

The top half of the tracker shows the current latest version and three previously available release versions for each region and links to the corresponding release notes entries. This view is helpful when you want to track the available versions by region.

:::image type="content" source="./media/release-tracker/regional-status.png" alt-text="Screenshot of the AKS release tracker's regional status table displayed in a web browser.":::

The bottom half of the tracker shows the release order. The table has two views: *By Region* and *By Version*.

:::image type="content" source="./media/release-tracker/release-order.png" alt-text="Screenshot of the AKS release tracker's release order table displayed in a web browser.":::

### AKS node image updates

The top half of the tracker shows the current latest node image version and three previously available node image versions for each region. This view is helpful when you want to track the available node image versions by region.

:::image type="content" source="./media/release-tracker/node-image-status.png" alt-text="Screenshot of the AKS release tracker's node image status table displayed in a web browser.":::

The bottom half of the tracker shows the node image update order. The table has two views: *By Region* and *By Version*.

:::image type="content" source="./media/release-tracker/node-image-order.png" alt-text="Screenshot of the AKS release tracker's node image order table displayed in a web browser.":::

<!-- LINKS - external -->
[aks-release]: https://github.com/Azure/AKS/releases
[release-tracker-webpage]: https://releases.aks.azure.com/webpage/index.html
