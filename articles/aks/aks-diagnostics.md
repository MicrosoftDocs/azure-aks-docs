---
title: Azure Kubernetes Service (AKS) Diagnose and Solve Problems overview
description: Learn about self-diagnosing clusters in Azure Kubernetes Service.
services: azure-kubernetes-service
author: rzhang628
ms.topic: how-to
ms.subservice: aks-monitoring
ms.date: 03/10/2023
ms.author: rongzhang
---

# Azure Kubernetes Service Diagnose and Solve Problems overview

Troubleshooting Azure Kubernetes Service (AKS) cluster issues plays an important role in maintaining your cluster, especially if your cluster is running mission-critical workloads. AKS Diagnose and Solve Problems is an intelligent, self-diagnostic experience that:

* Helps you identify and resolve problems in your cluster.
* Requires no extra configuration or billing cost.

## Open AKS Diagnose and Solve Problems

You can access AKS Diagnose and Solve Problems using the following steps:

1. In the [Azure portal](https://portal.azure.com), navigate to your AKS cluster resource.
1. From the service menu, select **Diagnose and solve problems**.
1. Select a troubleshooting category tile that best describes the issue of your cluster by referring the keywords in each tile description on the homepage or typing a keyword that best describes your issue in the search bar.

    :::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-home-page.png" alt-text="Screenshot of the AKS Diagnose and Solve Problems home page in the Azure portal." lightbox="./media/concepts-diagnostics/aks-diagnostics-home-page.png":::

## View a diagnostic report

After selecting a category, you can view various diagnostic reports that provide detailed information about the issue. The *Overview* option from the navigation menu runs all the diagnostics in that particular category and displays any issues that are found with the cluster. Select **View details** under each tile to view a detailed description of the issue, including:

* An issue summary
* Error details
* Recommended actions
* Links to helpful docs
* Related-metrics
* Logging data

### Example scenario: Diagnose connectivity issues

I observed that my application is getting disconnected or experiencing intermittent connection issues. In response, I navigate to the AKS Diagnose and Solve Problems home page and select the **Connectivity Issues** tile to investigate the potential causes.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-connectivity-issues.png" alt-text="Screenshot of the connectivity issues troubleshooting category tile in the Azure portal." lightbox="./media/concepts-diagnostics/aks-diagnostics-connectivity-issues.png":::

I received a diagnostic alert indicating that the disconnection might be related to my *Cluster DNS*. To gather more information, I select **View details**.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-results.png" alt-text="Screenshot of cluster DNS connectivity issues in the Azure portal." lightbox="./media/concepts-diagnostics/aks-diagnostics-results.png":::

Based on the diagnostic result, it appears that the issue might be related to known DNS issues or the VNet configuration. I can use the documentation links provided to address the issue and resolve the problem.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-network.png" alt-text="Screenshot of the troubleshooting links for cluster DNS connectivity issues in the Azure portal." lightbox="./media/concepts-diagnostics/aks-diagnostics-network.png":::

If the recommended documentation based on the diagnostic results doesn't resolve the issue, I can return to the previous step in Diagnostics and refer to additional documentation.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-doc.png" alt-text="Screenshot of the additional troubleshooting links for cluster DNS connectivity issues in the Azure portal." lightbox="./media/concepts-diagnostics/aks-diagnostics-doc.png":::

## Use AKS Diagnose and Solve Problems for best practices

Deploying applications on AKS requires adherence to best practices to guarantee optimal performance, availability, and security. The AKS Diagnose and Solve Problems **Best Practices** tile provides an array of best practices that can assist in managing various aspects, such as VM resource provisioning, cluster upgrades, scaling operations, subnet configuration, and other essential aspects of a cluster's configuration.

Leveraging the AKS Diagnose and Solve Problems can be vital in ensuring that your cluster adheres to best practices and that any potential issues are identified and resolved in a timely and effective manner. By incorporating AKS Diagnose and Solve Problems into your operational practices, you can be confident in the reliability and security of your application in production.

### Example scenario: View best practices

I'm curious about the best practices I can follow to prevent potential problems. In response, I navigate to the AKS Diagnose and Solve Problems home page and select the **Best Practices** tile.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-best.png" alt-text="Screenshot of the AKS Diagnose and Solve Problems best practices." lightbox="./media/concepts-diagnostics/aks-diagnostics-best.png":::

From here, I can view the best practices that are recommended for my cluster and select **View details** to see the results.

:::image type="content" source="./media/concepts-diagnostics/aks-diagnostics-practice.png" alt-text="Screenshot of the details of AKS Diagnose and Solve Problems best practices." lightbox="./media/concepts-diagnostics/aks-diagnostics-practice.png":::

## Next steps

* Collect logs to help you further troubleshoot your cluster issues using [AKS Periscope](https://aka.ms/aksperiscope).
* Read the [triage practices section](/azure/architecture/operator-guides/aks/aks-triage-practices) of the AKS day-2 operations guide.
* Post your questions or feedback at [UserVoice](https://feedback.azure.com/d365community/forum/aabe212a-f724-ec11-b6e6-000d3a4f0da0). Make sure to add "[Diag]" in the title.
