---
title: "How to migrate Azure Kubernetes Fleet Manager preview instances to a supported state"
description: Quickly identify if an instance of Kubernetes Fleet Manager was created using preview custom resource APIs.
ms.date: 12/12/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: how-to

---

# How to migrate Azure Kubernetes Fleet Manager preview instances to a supported state 

During the preview stage of Azure Kubernetes Fleet Manager (Kubernetes Fleet), an internal custom resource definition (CRD) API change was made that impacts a small number Kubernetes Fleet instances created during the service public preview. 

Microsoft notified affected Kubernetes Fleet users who can use this article to help identify specific Kubernetes Fleet instances affected by the change and this article covers how to move to a supported instance.

The Kubernetes Fleet Custom Resource Definitions (CRDs) API change is shown in the table.

| Old API definition (unsupported) | New API definition (supported) |
|--------------------|--------------------|
| memberclusters.fleet.azure.com/v1alpha1 | memberclusters.cluster.kubernetes-fleet.io/v1 |
| internalmemberclusters.fleet.azure.com/v1alpha1 | internalmemberclusters.cluster.kubernetes-fleet.io/v1 |

As of March 2025 the old API definitions no longer receive support or updates and will be removed from platform deployments.

Administrators with affected Kubernetes Fleet instances need to create a new Kubernetes Fleet instance and manually transfer member clusters. This is a one-time activity.

## Prerequisites

* The user undertaking this activity must be assigned the `Azure Kubernetes Fleet Manager RBAC Cluster Admin` Entra ID role.

* You need Azure CLI version 2.61.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.3.0 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the following command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

## Identify affected instances

1. Set the correct Azure Subscription. If you received a notification, it contains one or more Subscription ID you can use.

    ```azurecli-interactive
    az account set \
        --subscription <subscription-id>
    ```

2. Find all the Kubernetes Fleet instances you have in the Subscription.

    ```azurecli-interactive
    az resource list \
        --resource-type 'Microsoft.ContainerService/fleets'
    ```

    If you have multiple Kubernetes Fleet instances deployed, you can filter to instances created in 2022 or 2023 which may be affected. Instances from 2024 aren't affected.

    ```azurecli-interactive
    az resource list \
        --resource-type 'Microsoft.ContainerService/fleets' \
        --query "[?contains(createdTime, '2023') || contains(createdTime, '2022')]"
    ```

    If the above query returns any matching instances, you can double-check if the instances are using the retired Kubernetes CRD API as follows.

3. Download Kubernetes credentials for the Kubernetes Fleet hub cluster.

    ```azurecli-interactive
    az fleet get-credentials \
        --resource-group <resource-group> \
        --name <fleet-name>
    ```

4. Query the Kubernetes Fleet hub cluster Kubernetes API to determine if the old CRD versions are deployed.

    ```azurecli-interactive
    kubectl get crd memberclusters.fleet.azure.com
    kubectl get crd internalmemberclusters.fleet.azure.com
    ```

    If both queries return `Error from server (NotFound) customresourcedefinitions.apiextensions.k8s.io` then the selected Kubernetes Fleet instance isn't affected and no further action is required.
    
    If any instances are affected see the next section for remediation steps.

## Remediating affected instances 

If you identify any affected Kubernetes Fleet instances, you'll need to undertake the following steps.

1. Document any update runs and cluster resource placement rules defined on the affected Kubernetes Fleet instance.
2. Remove all member clusters from the affected Kubernetes Fleet instance.
3. Create a new Kubernetes Fleet Manager instance and associate member clusters as required.
4. Reapply and validate any configurations you noted from the old Kubernetes Fleet instance.
5. Delete the old Kubernetes Fleet instance.

<!-- INTERNAL LINKS -->
[azure-cli-install]: /cli/azure/install-azure-cli