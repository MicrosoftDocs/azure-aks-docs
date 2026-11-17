---
title: "Use Azure Kubernetes Fleet Manager to configure and distribute identity bindings (preview)"
description: Learn how to create Fleet Identity Binding Profiles to define identity binding configuration and distribute it across multiple member clusters.
ms.topic: how-to
ms.date: 10/06/2026
author: nibooy
ms.author: yoobinshin
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a platform engineer, I want to create an identity binding and distribute it to my member clusters via Fleet Manager, so that I can centrally manage workload identity across multiple clusters."
---

# Use Azure Kubernetes Fleet Manager to configure and distribute identity bindings (preview)

**Applies to**: :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Fleet Manager identity binding profiles extend [Identity bindings for Azure Kubernetes Service (AKS)][aks-identity-bindings-concepts] and allow you to define an identity binding once and distribute it across multiple member clusters. If workloads on multiple clusters need to use the same user-assigned managed identity (UAMI), you can create an identity binding profile to manage it centrally. Creation and distribution of identity bindings from a single profile simplifies management and ensures consistency across clusters.

This article provides instructions on how to create an identity binding profile and use it to apply the same identity binding configuration to multiple clusters.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites and limitations

[!INCLUDE [identity-binding-prerequisites.md](./includes/identity-binding/identity-binding-prerequisites.md)]

## Before you begin

* Review the [identity binding profile overview](./concepts-fleet-identity-binding.md) to understand how identity binding profiles work.
* A Fleet Manager with at least one member cluster. If you don't have one, see [create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
* A user-assigned managed identity that you use for the identity binding.
* The following Azure permissions on the member clusters:
    * `Microsoft.ContainerService/managedClusters/identityBindings/write`
* The following Azure permissions on the managed identity:
    * `Microsoft.ManagedIdentity/userAssignedIdentities/read`
    * `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/read`
    * `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write`
    * `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/delete`
* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```

## Set up your environment

If you already have a Fleet Manager with labeled member clusters and a managed identity, set `GROUP`, `FLEET`, `PROFILE_NAME`, `MEMBER_CLUSTER_1`, `MEMBER_LABEL`, `IDENTITY_ID`, and `MI_CLIENT_ID` to match your environment, then skip to [Create an identity binding profile](#create-an-identity-binding-profile).

Set the following environment variables:

```bash
export GROUP=<resource-group-name>
export FLEET=<fleet-name>
export PROFILE_NAME=<identity-binding-profile-name>
export MEMBER_CLUSTER_1=aks-member-1
export MEMBER_CLUSTER_2=aks-member-2
export MI_NAME=<managed-identity-name>
export MEMBER_LABEL=env=production
```

### Enable workload identity on member clusters

Each member cluster that receives the identity binding needs workload identity and the OIDC issuer enabled. Enable them on an existing cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command.

```azurecli-interactive
az aks update \
    --resource-group $GROUP \
    --name $MEMBER_CLUSTER_1 \
    --enable-workload-identity \
    --enable-oidc-issuer

az aks update \
    --resource-group $GROUP \
    --name $MEMBER_CLUSTER_2 \
    --enable-workload-identity \
    --enable-oidc-issuer
```

### Create a managed identity

Create the UAMI your workloads use, and then capture its resource ID and client ID.

```azurecli-interactive
az identity create --resource-group $GROUP --name $MI_NAME

export IDENTITY_ID=$(az identity show \
    --resource-group $GROUP \
    --name $MI_NAME \
    --query id \
    --output tsv)

export MI_CLIENT_ID=$(az identity show \
    --resource-group $GROUP \
    --name $MI_NAME \
    --query clientId \
    --output tsv)
```

### Label the member clusters

An identity binding profile selects member clusters by label. Set a label on each cluster that should receive the identity binding using the [`az fleet member update`](/cli/azure/fleet/member#az-fleet-member-update) command.

```azurecli-interactive
az fleet member update \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name $MEMBER_CLUSTER_1 \
    --labels "$MEMBER_LABEL"

az fleet member update \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name $MEMBER_CLUSTER_2 \
    --labels "$MEMBER_LABEL"
```

## Create an identity binding profile

Create the identity binding profile using the [`az fleet identitybindingprofile create`](/cli/azure/fleet/identitybindingprofile#az-fleet-identitybindingprofile-create) command. If you plan to authorize workloads with `allowedSubjects`, add `--allowed-subjects-from-file` here as described in the next section.

```azurecli-interactive
az fleet identitybindingprofile create \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name $PROFILE_NAME \
    --managed-identity-resource-id $IDENTITY_ID \
    --selector "$MEMBER_LABEL"
```

The profile defines the labels that select the member clusters, but it doesn't create any identity bindings until you apply it.

## Authorize workloads to use the identity

Creating the profile doesn't permit any workload to use the managed identity. Authorize them in one of two ways: set `allowedSubjects` on the profile, or create `ClusterRole` and `ClusterRoleBinding` objects on each member cluster. A token exchange succeeds when the member cluster's RBAC permits it or when an `allowedSubjects` entry matches. If you don't configure one of these authorization options, workloads can't acquire a token.

### Set allowedSubjects on the profile

The `allowedSubjects` property lists the namespaces and service accounts that can use the identity. It's part of the profile, so every selected member cluster receives it when you apply the profile.

> [!NOTE]
> The `allowedSubjects` field of AKS Identity Binding is in preview.

1. Create a JSON file containing an array of allowed subjects, with up to 100 entries. Each entry needs a `namespaceSelector` and can include an optional `serviceAccountSelector`. If you omit `serviceAccountSelector`, every service account in the matching namespaces is authorized. Use the built-in `kubernetes.io/metadata.name` label to target a namespace by name.

    ```json
    [
      {
        "namespaceSelector": {
          "matchLabels": ["kubernetes.io/metadata.name=demo"]
        },
        "serviceAccountSelector": {
          "matchLabels": ["app=payments"]
        }
      }
    ]
    ```

    This entry authorizes the service accounts labeled `app=payments` in the `demo` namespace. Service accounts don't have labels by default, so add a label to them to match the selector.

1. Set the field on the profile with the [`az fleet identitybindingprofile create`](/cli/azure/fleet/identitybindingprofile#az-fleet-identitybindingprofile-create) command, which creates the profile or updates it if it already exists.

    ```azurecli-interactive
    az fleet identitybindingprofile create \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --managed-identity-resource-id $IDENTITY_ID \
        --selector "$MEMBER_LABEL" \
        --allowed-subjects-from-file allowed-subjects.json
    ```

### Create RBAC objects on the member clusters

Grant the permission with Kubernetes RBAC instead, by creating a `ClusterRole` for the managed identity and a `ClusterRoleBinding` naming the service accounts that can use it. For the manifest, see [authorize namespaces and service accounts][aks-identity-bindings-authorize].

You can create these objects on a member cluster before or after you apply the profile. On a fleet with a hub cluster, you can distribute them across the member clusters with fleet workload placement using a [ClusterResourceEnvelope][fleet-envelope-objects] instead of creating them on each cluster.

## Apply the profile to member clusters

1. Review which member clusters are affected using the [`az fleet identitybindingprofile apply`](/cli/azure/fleet/identitybindingprofile#az-fleet-identitybindingprofile-apply) command with the `what-if` parameter.

    ```azurecli-interactive
    az fleet identitybindingprofile apply \
        --what-if \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --output table
    ```

    As you're applying a new profile, both clusters have an `Add` action.

    ```output
    Action    ClusterResourceId                   ETag        Name
    --------  ----------------------------------  ----------  ----------------
    Add       /subscriptions/…/…/aks-member-1     "fd009cd9"  aks-member-1
    Add       /subscriptions/…/…/aks-member-2     "a400f86e"  aks-member-2
    ```

1. Create the identity bindings by running the same command without the `what-if` parameter.

    ```azurecli-interactive
    az fleet identitybindingprofile apply \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME
    ```

    The identity binding creation process is asynchronous. The overall duration depends on the number of clusters you select.

## Confirm the profile is applied

1. Monitor the status of the apply operation.

    ```azurecli-interactive
    az fleet identitybindingprofile show \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --query "properties.provisioningState" \
        -o tsv
    ```

    The output should look similar to the following.

    ```output
    Succeeded
    ```

1. Confirm which member clusters the profile is applied to using the [`az fleet identitybindingprofile list-members`](/cli/azure/fleet/identitybindingprofile#az-fleet-identitybindingprofile-list-members) command.

    ```azurecli-interactive
    az fleet identitybindingprofile list-members \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --query "[].name" \
        -o table
    ```

## Update which clusters a profile applies to

1. Modify the labels on the member clusters to add or remove. The following example removes the labels from `$MEMBER_CLUSTER_1` by passing an empty `--labels` value.

    > [!WARNING]
    > `--labels` replaces all custom labels on the member cluster. If the cluster has other labels, such as ones that resource placements or other identity binding profiles select on, include them in `--labels` so only the profile's label is removed.

    ```azurecli-interactive
    az fleet member update \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $MEMBER_CLUSTER_1 \
        --labels ""
    ```

1. Review the changes using the `what-if` parameter.

    ```azurecli-interactive
    az fleet identitybindingprofile apply \
        --what-if \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --output table
    ```

    The `aks-member-1` cluster shows a `Remove` action when you remove it.

    ```output
    Action    ClusterResourceId                   ETag        Name
    --------  ----------------------------------  ----------  ----------------
    Remove    /subscriptions/…/…/aks-member-1     "fd009cd9"  aks-member-1
    -         /subscriptions/…/…/aks-member-2     "a400f86e"  aks-member-2
    ```

1. When you're satisfied with the changes, apply them to the profile by running the same command and omitting the `what-if` parameter.

    ```azurecli-interactive
    az fleet identitybindingprofile apply \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME
    ```

## Delete an identity binding profile

To delete an identity binding profile, first remove it from the member clusters it's applied to.

> [!IMPORTANT]
> To prevent unexpected loss of access for running workloads, you can't delete an identity binding profile while it's still applied to member clusters. Also, you can't remove those member clusters from a Fleet Manager, or delete the Fleet Manager itself.

1. Change the profile's member selector to a value that no member cluster has, then apply the change so the identity binding is removed from all member clusters.

    ```azurecli-interactive
    az fleet identitybindingprofile create \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --managed-identity-resource-id $IDENTITY_ID \
        --selector "env=none"

    az fleet identitybindingprofile apply \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME
    ```

1. Confirm the profile reports no members before continuing.

    ```azurecli-interactive
    az fleet identitybindingprofile list-members \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME
    ```

    ```output
    []
    ```

1. Delete the identity binding profile using the [`az fleet identitybindingprofile delete`](/cli/azure/fleet/identitybindingprofile#az-fleet-identitybindingprofile-delete) command.

    ```azurecli-interactive
    az fleet identitybindingprofile delete \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name $PROFILE_NAME \
        --yes
    ```

## Next steps

* Read the [multi-cluster identity binding management overview](./concepts-fleet-identity-binding.md) to understand the key concepts.
* See how to use identity bindings to [authorize namespaces and service accounts][aks-identity-bindings-authorize].

<!-- INTERNAL LINKS -->
[aks-identity-bindings-concepts]: ../aks/identity-bindings-concepts.md
[aks-identity-bindings-howto]: ../aks/identity-bindings.md
[aks-identity-bindings-authorize]: ../aks/identity-bindings.md#authorize-namespaces-and-service-accounts
[az-extension-update]: /cli/azure/extension#az-extension-update
[fleet-envelope-objects]: ./quickstart-envelope-reserved-resources.md
