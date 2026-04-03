---
title: Control cluster and node access using Conditional Access with AKS-managed Microsoft Entra integration
titleSuffix: Azure Kubernetes Service
description: Learn how to access clusters and nodes using Conditional Access when integrating Microsoft Entra ID in your Azure Kubernetes Service (AKS) clusters.
ms.topic: concept-article
ms.subservice: aks-integration
ms.date: 11/10/2025
author: shashankbarsin
ms.author: shasb
ms.custom: devx-track-azurecli
# Customer intent: "As a cloud security administrator, I want to configure Conditional Access for my AKS clusters, so that I can manage access securely and ensure compliance for users accessing the clusters and nodes."
---

# Control cluster and node access using Conditional Access with AKS-managed Microsoft Entra integration

When you integrate Microsoft Entra ID with your AKS cluster, you can use [Conditional Access][aad-conditional-access] to control access to your cluster control plane and cluster nodes. This article shows you how to enable Conditional Access on your AKS clusters for both control plane access and SSH access to nodes.

> [!NOTE]
> Microsoft Entra Conditional Access has Microsoft Entra ID P1, P2, or Governance capabilities requiring a Premium P2 SKU. For more on Microsoft Entra ID licenses and SKUs, see [Microsoft Entra ID Governance licensing fundamentals][licensing-fundamentals] and [pricing guide][aad-pricing].

## Before you begin

* See [AKS-managed Microsoft Entra integration](./managed-azure-ad.md) for an overview and setup instructions.
* For SSH access to nodes, see [Manage SSH for secure access to Azure Kubernetes Service (AKS) nodes](./manage-ssh-node-access.md) to configure Entra ID based SSH.

## Use Conditional Access with Microsoft Entra ID and AKS

You can use Conditional Access to control access to both the AKS cluster control plane and SSH access to cluster nodes.

### Configure Conditional Access for cluster control plane access

1. In the Azure portal, go to the **Microsoft Entra ID** page and select **Enterprise applications**.
1. Select **Conditional Access** > **Policies** > **New policy**.
1. Enter a name for the policy, such as *aks-policy*.
1. Under **Assignments**, select **Users and groups**. Choose the users and groups you want to apply the policy to. In this example, choose the same Microsoft Entra group that has administrator access to your cluster.
1. Under **Cloud apps or actions** > **Include**, select **Select apps**. Search for **Azure Kubernetes Service** and select **Azure Kubernetes Service Microsoft Entra Server**.
1. Under **Access controls** > **Grant**, select **Grant access**, **Require device to be marked as compliant**, and **Require all the selected controls**.
1. Confirm your settings, set **Enable policy** to **On**, and then select **Create**.

### Verify Conditional Access for cluster control plane access

After implementing your Conditional Access policy, verify that it works as expected by accessing the AKS cluster and checking the sign-in activity.

1. Get the user credentials to access the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    Assign values to the required environment variables. The AKS cluster and resource group must exist.

    ```azurecli-interactive
    export RANDOM_SUFFIX=$(head -c 3 /dev/urandom | xxd -p)
    export RESOURCE_GROUP="myResourceGroup$RANDOM_SUFFIX"
    export AKS_CLUSTER="myManagedCluster$RANDOM_SUFFIX"
    ```

    Download credentials required to access your AKS cluster.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing
    ```

1. Follow the instructions to sign in.

1. View the nodes in the cluster using the `kubectl get nodes` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

    Results:

    <!-- expected_similarity=0.3 -->

    ```output
    NAME                                         STATUS   ROLES   AGE     VERSION
    aks-nodepool1-xxxxx-vmss000000               Ready    agent   3d2h    v1.xx.x
    aks-nodepool1-xxxxx-vmss000001               Ready    agent   3d2h    v1.xx.x
    ```

1. In the Azure portal, navigate to **Microsoft Entra ID** and select **Enterprise applications** > **Activity** > **Sign-ins**.

1. Under the **Conditional Access** column you should see a status of *Success*. Select the event and then select the **Conditional Access** tab. Your Conditional Access policy will be listed.

## Configure Conditional Access for SSH access to cluster nodes

When you enable Entra ID based SSH access on your AKS cluster nodes, you can apply Conditional Access policies to control SSH access to the nodes. This provides additional security by enforcing device compliance, multifactor authentication, or other conditions before users can SSH into cluster nodes.

1. In the Azure portal, go to the **Microsoft Entra ID** page and select **Enterprise applications**.
1. Select **Conditional Access** > **Policies** > **New policy**.
1. Enter a name for the policy, such as *aks-node-ssh-policy*.
1. Under **Assignments**, select **Users and groups**. Choose the users and groups you want to apply the policy to.
1. Under **Cloud apps or actions** > **Include**, select **Select apps**. Search for **Azure Virtual Machine Sign-In** and select **Azure Linux Virtual Machine Sign-In**.
1. Under **Access controls** > **Grant**, select **Grant access**, **Require device to be marked as compliant**, **Require multi-factor authentication**, and **Require all the selected controls**.
1. Confirm your settings, set **Enable policy** to **On**, and then select **Create**.

> [!NOTE]
> For Entra ID based SSH to work with Conditional Access, ensure that your AKS cluster nodes are configured with `--ssh-access entraid`. For more information, see [Manage SSH for secure access to Azure Kubernetes Service (AKS) nodes](./manage-ssh-node-access.md).

### Verify Conditional Access for SSH access to nodes

After implementing your Conditional Access policy for SSH access to nodes, verify that it works as expected:

1. Ensure you have the appropriate Azure RBAC permissions:
   - **Virtual Machine Administrator Login** role for admin access
   - **Virtual Machine User Login** role for non-admin access

1. Install the SSH extension for Azure CLI:

    ```azurecli-interactive
    az extension add --name ssh
    ```

1. SSH into a node using Entra ID authentication:

    ```azurecli-interactive
    az ssh vm --resource-group $RESOURCE_GROUP --name <node-name>
    ```

1. During the authentication flow, you'll be prompted to satisfy the Conditional Access policies (e.g., device compliance, MFA).

1. After successful authentication that meets the Conditional Access requirements, you'll be connected to the node.

1. In the Azure portal, navigate to **Microsoft Entra ID** and select **Enterprise applications** > **Activity** > **Sign-ins**.

1. Find the sign-in event for **Azure Linux Virtual Machine Sign-In** and verify that under the **Conditional Access** column you see a status of *Success*.

## Next steps

For more information, see the following articles:

* Use [kubelogin](https://github.com/Azure/kubelogin) to access features for Azure authentication that aren't available in kubectl.
* [Use Privileged Identity Management (PIM) to control access to your Azure Kubernetes Service (AKS) clusters][pim-aks].

<!-- LINKS - External -->
[aad-pricing]: https://azure.microsoft.com/pricing/details/active-directory/

<!-- LINKS - Internal -->
[aad-conditional-access]: /azure/active-directory/conditional-access/overview
[licensing-fundamentals]: /entra/id-governance/licensing-fundamentals
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[pim-aks]: ./privileged-identity-management.md
