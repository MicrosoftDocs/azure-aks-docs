---
title: Control cluster access using Conditional Access with AKS-managed Microsoft Entra integration
description: Learn how to access clusters using Conditional Access when integrating Microsoft Entra ID in your Azure Kubernetes Service (AKS) clusters.
ms.topic: article
ms.subservice: aks-integration
ms.date: 04/20/2023
author: tamram
ms.author: tamram
ms.custom: devx-track-azurecli
---

# Control cluster access using Conditional Access with AKS-managed Microsoft Entra integration

When you integrate Microsoft Entra ID with your AKS cluster, you can use [Conditional Access][aad-conditional-access] for just-in-time requests to control access to your cluster. This article shows you how to enable Conditional Access on your AKS clusters.

> [!NOTE]
> Microsoft Entra Conditional Access has Microsoft Entra ID P1, P2, or Governance capabilities requiring a Premium P2 SKU. For more on Microsoft Entra ID licenses and SKUs, see [Microsoft Entra ID Governance licensing fundamentals][licensing-fundamentals] and [pricing guide][aad-pricing].

## Before you begin

* See [AKS-managed Microsoft Entra integration](./managed-azure-ad.md) for an overview and setup instructions.

## Use Conditional Access with Microsoft Entra ID and AKS

1. In the Azure portal, go to the **Microsoft Entra ID** page and select **Enterprise applications**.
2. Select **Conditional Access** > **Policies** > **New policy**.

    :::image type="content" source="./media/managed-aad/conditional-access-new-policy.png" alt-text="Screenshot of adding a Conditional Access policy." lightbox="./media/managed-aad/conditional-access-new-policy.png":::

3. Enter a name for the policy, such as *aks-policy*.

4. Under **Assignments**, select **Users and groups**. Choose the users and groups you want to apply the policy to. In this example, choose the same Microsoft Entra group that has administrator access to your cluster.

    :::image type="content" source="./media/managed-aad/conditional-access-users-groups.png" alt-text="Screenshot of selecting users or groups to apply the Conditional Access policy." lightbox="./media/managed-aad/conditional-access-users-groups.png":::

5. Under **Cloud apps or actions** > **Include**, select **Select apps**. Search for **Azure Kubernetes Service** and select **Azure Kubernetes Service Microsoft Entra Server**.

    :::image type="content" source="./media/managed-aad/conditional-access-apps.png" alt-text="Screenshot of selecting Azure Kubernetes Service AD Server for applying the Conditional Access policy." lightbox="./media/managed-aad/conditional-access-apps.png":::

6. Under **Access controls** > **Grant**, select **Grant access**, **Require device to be marked as compliant**, and **Require all the selected controls**.

    :::image type="content" source="./media/managed-aad/conditional-access-grant-compliant.png" alt-text="Screenshot of selecting to only allow compliant devices for the Conditional Access policy." lightbox="./media/managed-aad/conditional-access-grant-compliant.png" :::

7. Confirm your settings, set **Enable policy** to **On**, and then select **Create**.

    :::image type="content" source="./media/managed-aad/conditional-access-enable-policy.png" alt-text="Screenshot of enabling the Conditional Access policy." lightbox="./media/managed-aad/conditional-access-enable-policy.png":::

## Verify your Conditional Access policy has been successfully listed

1. Get the user credentials to access the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
     az aks get-credentials --resource-group myResourceGroup --name myManagedCluster
    ```

2. Follow the instructions to sign in.

3. View the nodes in the cluster using the `kubectl get nodes` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

4. In the Azure portal, navigate to **Microsoft Entra ID** and select **Enterprise applications** > **Activity** > **Sign-ins**.

5. Under the **Conditional Access** column you should see a status of *Success*. Select the event and then select the **Conditional Access** tab. Your Conditional Access policy will be listed.

    :::image type="content" source="./media/managed-aad/conditional-access-sign-in-activity.png" alt-text="Screenshot that shows failed sign-in entry due to Conditional Access policy." lightbox="./media/managed-aad/conditional-access-sign-in-activity.png":::

## Next steps

For more information, see the following articles:

* Use [kubelogin](https://github.com/Azure/kubelogin) to access features for Azure authentication that aren't available in kubectl.
* [Use Privileged Identity Management (PIM) to control access to your Azure Kubernetes Service (AKS) clusters][pim-aks].

<!-- LINKS - External -->
[aad-pricing]: https://azure.microsoft.com/pricing/details/active-directory/

<!-- LINKS - Internal -->
[aad-conditional-access]: /azure/active-directory/conditional-access/overview
[licensing-fundamentals]: /entra/id-governance/licensing-fundamentals
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[pim-aks]: ./privileged-identity-management.md
