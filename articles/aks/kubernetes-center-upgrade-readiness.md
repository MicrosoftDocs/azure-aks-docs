---
title: Review AKS upgrade readiness in Kubernetes Center using the Azure portal
description: Learn how to review AKS version support, upgrade failures, upcoming upgrades, recommendations, and Fleet update runs in Kubernetes Center.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 11/06/2026
ai-usage: ai-assisted
# Customer intent: As a cluster operator, I want to review upgrade insights across AKS clusters so that I can identify support risks, investigate failures, and plan upgrades.
---

# Review AKS upgrade readiness in Kubernetes Center using the Azure portal

Use **Multicluster update and insights** in Kubernetes Center (preview) to identify clusters that need upgrade attention without opening each Azure Kubernetes Service (AKS) resource individually. You can review Kubernetes version support, investigate recent upgrade failures, see upcoming upgrades, and choose a remediation path.

This article explains how to use the Azure portal experience. Reviewing insights doesn't initiate an upgrade or change a cluster's configuration.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An Azure subscription with one or more AKS clusters.
- Read access to the clusters you want to inspect. To inspect Fleet information, you also need access to the relevant Azure Kubernetes Fleet Manager resources.
- Appropriate write permissions if you choose to change upgrade settings, enroll a cluster in long-term support (LTS), or configure Fleet upgrades. Read access alone doesn't authorize these changes.

Fleet membership isn't required to review standalone clusters.

## Open upgrade insights and set the scope

1. Sign in to the [Azure portal](https://portal.azure.com/).
1. In the portal search box, search for and select **Kubernetes center**.
1. In the **Kubernetes center** menu, expand **Multicluster management**, and select **Multicluster update and insights**.
1. Review **View by**, **Subscription**, **Resource group**, and **Location** at the top of the page. Select the scope you want to investigate.
1. Select **Refresh** when you need to reload the displayed information.

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/upgrade-insights-menu.png" alt-text="Screenshot of the Kubernetes center menu showing Multicluster update and insights under Multicluster management." lightbox="./media/kubernetes-center-upgrade-readiness/upgrade-insights-menu.png":::

The page contains summary cards and a cluster table. Start with the cards to identify a concern, then inspect the affected clusters. Counts and resource names in the screenshots are examples, not expected values for your environment.

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/upgrade-insights-overview.png" alt-text="Screenshot of upgrade insights cards showing version support, upgrade issues, upcoming upgrades, recommendations, and Fleet update runs." lightbox="./media/kubernetes-center-upgrade-readiness/upgrade-insights-overview.png":::

## Find clusters that need a supported Kubernetes version

1. Locate **Cluster Version Support Status by Tier**.
1. Select **All**, **Premium**, **Standard**, or **Free** to examine the corresponding cluster tier.
1. Review the support categories:

    | Category | What to investigate |
    | --- | --- |
    | **Out of support** | Prioritize reviewing the cluster's Kubernetes version and available upgrade options. |
    | **Out of support (LTS eligible)** | The version is outside its current support coverage, but the cluster is a candidate for LTS. Eligibility doesn't mean LTS is already enabled. |
    | **Expiring soon** | Plan the next upgrade before the current support coverage ends. |
    | **In support** | The cluster is currently within the support coverage shown by the experience. Continue to review its upgrade policy. |

1. Select a category's linked count to open the corresponding cluster list.
1. Open a cluster to review its version and configuration before choosing an upgrade or support-plan change.

For version-specific support dates, use the [AKS Kubernetes version support policy](./supported-kubernetes-versions.md), rather than dates or version numbers in a screenshot.

The card also provides **Enable LTS for Eligible Clusters**. Treat LTS enrollment as a configuration and billing decision, not a way to clear a warning without review. LTS requires the Premium tier and an explicit LTS support plan. For more information, see [Long-term support for AKS versions](./long-term-support.md).

## Investigate a failed upgrade

1. Locate **Cluster upgrade issues**, and read the time window and checked-cluster count. The card shows recent upgrade issues over the last 14 days.
1. Select **View all Upgrade issues**.
1. In **Upgrade Failure Clusters**, search by cluster name or filter by **Subscription**, **Resource group**, **Location**, or **Error code**.
1. For an affected cluster, compare **Current Kubernetes version** and **Target Kubernetes version**, then read **Error details**.
1. Select **View cluster** to continue investigating the affected resource.

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/upgrade-failure-details.png" alt-text="Screenshot of an upgrade failure showing current and target Kubernetes versions and an error caused by a restrictive pod disruption budget." lightbox="./media/kubernetes-center-upgrade-readiness/upgrade-failure-details.png":::

For example, the screenshot shows a node-drain failure because evicting a pod would violate its pod disruption budget (PDB). Use the error to identify the workload and review its availability requirements before retrying. Don't remove disruption protections solely to make an upgrade succeed.

> [!NOTE]
> A failed cluster provisioning state isn't necessarily an upgrade failure. **Recommendations** can identify clusters whose state blocks upgrades even when **Cluster upgrade issues** has no matching recent upgrade failure. If the upgrade-issues action is disabled, read the card's status and coverage before drawing conclusions.

## Review upgrades planned for the next 14 days

1. Locate **Upcoming Upgrades** to review active upgrades and the upcoming schedule.
1. Select **View all Upcoming upgrades**.
1. Use the calendar to identify a date with planned upgrades. Select that date to narrow the results.
1. Use **Upgrade type**, **Date**, or the resource filters to focus the list.
1. Review each entry's upgrade type, planned start time, and any target-version or estimated-duration information shown.
1. Select **View cluster** to inspect the cluster before the planned operation.

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/upcoming-upgrades-calendar.png" alt-text="Screenshot of a 14-day upcoming-upgrades calendar showing separate counts for clusters and upgrade operations." lightbox="./media/kubernetes-center-upgrade-readiness/upcoming-upgrades-calendar.png":::

A cluster can have more than one upgrade operation, such as a Kubernetes version upgrade and a node OS upgrade. For that reason, a day's upgrade count can exceed its cluster count. Check the time-zone label on planned start times when coordinating a maintenance window, and treat duration estimates as estimates.

In the main table, **Next upgrade** only describes the next 14 days. A blank value doesn't establish that automatic upgrades are disabled.

## Choose a remediation path

1. In **Recommendations**, identify the issue you want to address. Examples include standalone clusters without auto-upgrade, clusters still at risk despite auto-upgrade, blocked cluster states, and fleets without auto-upgrade.
1. Read the affected-resource count and support-status breakdown.
1. Select **Review** or **Remediate** for that recommendation.
1. Where the **Set up multicluster upgrades** chooser is offered, select a path:

    | Path | When to use it |
    | --- | --- |
    | **Staged Fleet runs** | Coordinate upgrades across clusters using staged rollout and Fleet management. |
    | **Individual cluster auto-upgrades** | Configure upgrade policies on selected clusters without requiring Fleet membership. |

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/remediation-paths.png" alt-text="Screenshot of the remediation chooser offering Staged Fleet runs and Individual cluster auto-upgrades." lightbox="./media/kubernetes-center-upgrade-readiness/remediation-paths.png":::

For individual cluster auto-upgrades, the workflow provides **Cluster selection**, **Schedule & upgrade options**, and **Review** steps. Review the eligible clusters, intended upgrade channels, and maintenance settings before submitting a configuration change.

> [!IMPORTANT]
> The individual-cluster path can create or overwrite existing auto-upgrade profiles across multiple clusters. Review existing settings and the selected resources before submitting. Opening the chooser doesn't apply changes.

A `patch` policy alone doesn't move a cluster to a newer Kubernetes minor version. When a cluster remains at risk, review whether its upgrade policy meets your version-support requirements. For policy details, see [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md). For staged updates, see [Update clusters using Fleet Manager](../kubernetes-fleet/update-orchestration.md).

## Review Fleet update runs

1. Locate **Fleet Update runs status**.
1. Review the displayed run states, including **Failed**, **Running**, **Stopped**, **Completed**, **Not started**, and **Pending**.
1. Select **View runs** to continue into the run details.
1. Investigate failed or pending work before starting additional updates.

Fleet update runs describe orchestrated operations. They aren't a substitute for checking each cluster's support status.

## Find a specific cluster and verify the outcome

In the cluster table, use **Search by cluster name** and the **Kubernetes version**, **Next upgrade**, **Support status**, **Auto Upgrade**, and **Node OS AutoUpgrade** filters.

:::image type="content" source="./media/kubernetes-center-upgrade-readiness/cluster-filters.png" alt-text="Screenshot of the upgrade-insights cluster search and version, schedule, support, and automatic-upgrade filters." lightbox="./media/kubernetes-center-upgrade-readiness/cluster-filters.png":::

After an approved configuration change or completed upgrade:

1. Return to **Multicluster update and insights**, and select **Refresh**.
1. Find the affected cluster.
1. Verify its displayed Kubernetes version, support status, and upgrade policies against the intended outcome.
1. For an upgrade operation, also verify completion in the cluster or Fleet run details. A configured policy or planned date isn't proof that an upgrade completed.

## Next steps

- [Create and manage AKS resources with Kubernetes Center](./kubernetes-center-azure-portal.md).
- [Upgrade the AKS cluster control plane](./upgrade-aks-control-plane.md).
- [Use planned maintenance to schedule and control upgrades](./planned-maintenance.md).
