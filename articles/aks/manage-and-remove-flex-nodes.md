---
title: Manage and remove flex nodes in AKS (preview)
description: Learn how to inventory, update, upgrade, drain, detach, and remove flex nodes and their supporting access.
author: leslielin-5
ms.author: leslielin
ms.topic: how-to
ms.date: 09/08/2026
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform operator, I want to manage, upgrade, and safely remove flex nodes throughout their lifecycle."
---

# Manage and remove flex nodes in AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

After you attach flex nodes to an Azure Kubernetes Service (AKS) cluster, use AKS management commands to inspect their state, update pool or Machine settings, upgrade Kubernetes, and remove hosts that you no longer need.

In this article, you:

- Inventory flex node pools, Azure Machine resources, and Kubernetes Nodes.
- Update settings for hosts that join later or for an existing Machine.
- Upgrade one Machine or the complete flex node pool.
- Drain, reset, and remove a flex node.
- Delete an empty pool and remove supporting access.

Run the management commands in this article in a Linux-compatible Bash environment that has the required tools and network access. This article calls that environment your **Bash environment**. The separate machine that joins the cluster is the **flex node host**; run commands there only when a step explicitly directs you to.

## Before you begin

- Complete [Attach a flex node to an AKS cluster](./attach-flex-node-to-aks.md).
- Use the shared environment file and dedicated kubeconfig created by the deployment series.
- Use an Azure account that can update and delete the flex node pool and its Machine resources.
- Use a Kubernetes identity that can inspect, drain, and delete the target Node.
- Use a `kubectl` version within one minor version of `AKS_VERSION`.
- Ensure that your Bash environment can connect to the flex node host through SSH.
- Review your workloads' Pod Disruption Budgets and data-retention requirements before an upgrade or removal.

For a private AKS cluster, your Bash environment must resolve and reach both the private API server and the flex node host.

## Load the deployment environment

Start a new Bash session, identify the environment file, and load it. Replace `<deployment-name>` with the deployment label used in the preceding articles.

```bash
export FLEXNODE_DEPLOYMENT="<deployment-name>"
export FLEXNODE_ENV_FILE="${HOME}/.config/aks-flexnode/${FLEXNODE_DEPLOYMENT}.env"
test -s "${FLEXNODE_ENV_FILE}"
source "${FLEXNODE_ENV_FILE}"
export KUBECONFIG="${FLEXNODE_KUBECONFIG}"
export FLEX_NODE_NAME="$(printf '%s' "${FLEX_HOST_NAME}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
: "${FLEX_MACHINE_NAME:?Complete the Machine verification in the attachment article.}"
```

This article uses the Azure Machine name recorded during attachment. Don't assume that the Machine resource name is the same as the Linux host name or Kubernetes Node name.

Set the active subscription and display the Azure and Kubernetes targets:

```azurecli
az account set --subscription "${SUBSCRIPTION_ID}"

az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "{Cluster:name,ResourceId:id,ApiServer:(privateFqdn || fqdn)}" \
    --output table
```

```bash
kubectl \
    --kubeconfig "${FLEXNODE_KUBECONFIG}" \
    cluster-info
```

Confirm that **ResourceId** matches `AKS_RESOURCE_ID` and that the Kubernetes control-plane hostname matches **ApiServer**. If either value doesn't match, stop and reload the environment file and kubeconfig for the intended cluster.

## Inspect the current state

List the Machine resources in the flex node pool:

```azurecli
az aks machine list \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --query "[].{Machine:name,Node:properties.kubernetes.nodeName,Version:properties.kubernetes.currentOrchestratorVersion,State:properties.provisioningState}" \
    --output table
```

List the registered flex nodes:

```bash
kubectl get nodes \
    --selector kubernetes.azure.com/nodepool-type=FlexNodes \
    --output custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,KUBELET:.status.nodeInfo.kubeletVersion,UID:.metadata.uid
```

Display the pool version and provisioning state:

```azurecli
az aks nodepool show \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --query "{Version:orchestratorVersion,State:provisioningState}" \
    --output table
```

## Update flex node settings

Pool settings and Machine settings have different effects:

- A pool update changes defaults for hosts that join the pool later.
- A Machine update changes an existing flex node.

### Update settings for hosts that join later

The following example updates optional labels on the pool:

```azurecli
az aks nodepool update \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --labels pool-generation=second \
    --node-taints "pool-generation=second:NoSchedule" \
    --output none
```

Verify the pool settings:

```azurecli
az aks nodepool show \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --query "{Labels:nodeLabels,Taints:nodeTaints,State:provisioningState}" \
    --output yaml
```

Existing Machines keep their current settings. Hosts you attach after this update receive the new pool settings.

### Update an existing machine

When you update a machine label or taint, you replace the values that this command manages. Include every value that you want the machine to keep.

```azurecli
az aks machine update \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --machine-name "${FLEX_MACHINE_NAME}" \
    --labels pool-generation=second \
    --node-taints "pool-generation=second:NoSchedule" \
    --output none
```

Verify the node:

```bash
kubectl get node "${FLEX_NODE_NAME}" \
    --label-columns pool-generation \
    --output wide
```

The node stays `Ready`. A label or taint update doesn't recreate the node.

To apply the same change to multiple machines, first list their names:

```azurecli
az aks machine list \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --query "[].name" \
    --output tsv
```

Run the `az aks machine update` command once for each returned machine name.

## Upgrade Kubernetes

A flex node can't run a Kubernetes version that's newer than the AKS control plane. Upgrade the control plane before you upgrade a machine or pool.

Set the supported target version:

```bash
export TARGET_KUBERNETES_VERSION="1.36.3"
```

Upgrade the AKS control plane:

```azurecli
az aks upgrade \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --kubernetes-version "${TARGET_KUBERNETES_VERSION}" \
    --control-plane-only \
    --yes \
    --output none
```

Verify the control-plane version:

```azurecli
az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "{RequestedVersion:kubernetesVersion,CurrentVersion:currentKubernetesVersion,State:provisioningState}" \
    --output table
```

Continue when both versions match `TARGET_KUBERNETES_VERSION` and **State** is `Succeeded`.

### Upgrade one machine first

Use this path to validate the target version on one flex node before upgrading the complete pool.

Record the current Node UID and version:

```bash
OLD_NODE_UID="$(kubectl get node "${FLEX_NODE_NAME}" \
    --output jsonpath='{.metadata.uid}')"
export OLD_NODE_UID

kubectl get node "${FLEX_NODE_NAME}" \
    --output custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,UID:.metadata.uid
```

Set the Machine target version:

```azurecli
az aks machine update \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --machine-name "${FLEX_MACHINE_NAME}" \
    --kubernetes-version "${TARGET_KUBERNETES_VERSION}" \
    --output none
```

Verify that the Machine accepted the target version:

```azurecli
az aks machine show \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --machine-name "${FLEX_MACHINE_NAME}" \
    --query "{RequestedVersion:properties.kubernetes.orchestratorVersion,CurrentVersion:properties.kubernetes.currentOrchestratorVersion,State:properties.provisioningState}" \
    --output table
```

The existing Kubernetes Node can continue to report the previous kubelet version until it is replaced. Deleting the Node in the following step triggers the installed flex node agent to register a replacement Node by using the Machine target version. It isn't a host-removal operation. Don't reset or bootstrap the host during this step.

Before deleting the Node, prevent new workloads from scheduling and evict workloads managed by controllers:

```bash
kubectl drain "${FLEX_NODE_NAME}" \
    --ignore-daemonsets
```

If the drain is blocked, review the reported unmanaged Pods, local storage, and Pod Disruption Budgets. Don't bypass those protections until you understand the workload impact. Directly created Pods aren't recreated automatically.

```bash
kubectl delete node "${FLEX_NODE_NAME}"
```

Wait for the replacement Node:

```bash
kubectl wait \
    --for=create \
    "node/${FLEX_NODE_NAME}" \
    --timeout=5m

kubectl wait \
    --for=condition=Ready \
    "node/${FLEX_NODE_NAME}" \
    --timeout=10m

kubectl get node "${FLEX_NODE_NAME}" \
    --output custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,UID:.metadata.uid

NEW_NODE_UID="$(kubectl get node "${FLEX_NODE_NAME}" \
    --output jsonpath='{.metadata.uid}')"
export NEW_NODE_UID
printf 'Previous Node UID: %s\nReplacement Node UID: %s\n' \
    "${OLD_NODE_UID}" \
    "${NEW_NODE_UID}"
```

Continue when the Node returns with the same name, has a new UID, is `Ready`, and reports the target kubelet version with a `v` prefix. The Machine resource reports the same version without the `v` prefix.

Before making further pool-level changes, upgrade the complete pool so that the pool and all Machines run the same Kubernetes version.

### Upgrade the complete pool

Upgrade every machine in the pool:

```azurecli
az aks nodepool upgrade \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --kubernetes-version "${TARGET_KUBERNETES_VERSION}" \
    --yes \
    --output none
```

Verify every flex node:

```bash
kubectl get nodes \
    --selector kubernetes.azure.com/nodepool-type=FlexNodes \
    --output custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,KUBELET:.status.nodeInfo.kubeletVersion,UID:.metadata.uid
```

Verify the pool:

```azurecli
az aks nodepool show \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --query "{Version:orchestratorVersion,State:provisioningState}" \
    --output table
```

Continue when every node is `Ready` at the target version and the pool provisioning state is `Succeeded`. Nodes that are recreated receive new UIDs, and controller-managed Pods on those nodes are recreated or rescheduled. Repeat the workload and connectivity validation from the attachment article after either upgrade path, and remove the validation namespace when the checks finish.

## Remove a flex node

Remove a host only when it no longer runs required workloads.

Before you drain or change the host, confirm the recorded and actual host names:

```bash
printf 'Recorded flex host: %s\n' "${FLEX_HOST_NAME}"
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" hostname
```

Continue only when the SSH command returns `FLEX_HOST_NAME`. If it doesn't match, stop and correct the SSH target.

### Drain the Node

Prevent new workloads from scheduling and evict workloads managed by controllers:

```bash
kubectl drain "${FLEX_NODE_NAME}" \
    --ignore-daemonsets
```

If the drain is blocked, review the reported unmanaged Pods, local storage, and Pod Disruption Budgets. Don't bypass those protections until you understand the workload impact.

### Reset the host registration

Run reset on the host to deregister the flex node and remove the agent from the host:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    'sudo env \
        AZURE_CONFIG_DIR=/etc/aks-flex-node/azure \
        TERM=dumb \
        /usr/local/bin/aks-flex-node reset'
```

Don't continue if reset fails. The expected final combined cleanup task reports `status=ok`.

Reset stops and removes the agent service, removes the flex node worker machine, reverts the network configuration that the agent applied, and removes `/etc/aks-flex-node` and `/var/log/aks-flex-node`. The installed service-principal credential is removed with `/etc/aks-flex-node`. If secure delivery left another credential copy elsewhere on the host, remove that exact source file according to your credential-management process.

Verify that the agent and worker environment are gone:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    'sudo systemctl show aks-flex-node-agent \
        --property=ActiveState \
        --property=SubState
     sudo machinectl list
     if sudo test ! -e /etc/aks-flex-node/base-config.json; then
         printf "base-config.json removed\n"
     else
         printf "base-config.json still exists\n" >&2
         false
     fi'
```

The expected agent state is `inactive`, no flex node worker machine remains, and the bootstrap configuration file is absent.

Reset leaves the agent program files under `/usr/local/lib/aks-flex-node`, so you can attach the host again without downloading the release a second time. Reimage the host when you need it returned to a state that has never run a flex node.

### Remove residual cluster resources

Reset deregisters the flex node, but the Kubernetes Node object can remain. Remove it:

```bash
kubectl delete node "${FLEX_NODE_NAME}" --ignore-not-found
```

Check whether the Azure Machine remains:

```azurecli
az aks machine list \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --query "[?name=='${FLEX_MACHINE_NAME}'].name" \
    --output tsv
```

If the command returns the Machine name, remove it through the node-pool operation:

```azurecli
az aks nodepool delete-machines \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --machine-names "${FLEX_MACHINE_NAME}" \
    --output none
```

Run the list command again. Continue when it returns no Machine name.

## Delete an empty flex node pool

List the remaining machines:

```azurecli
az aks machine list \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodepool-name "${FLEX_POOL_NAME}" \
    --query "[].name" \
    --output tsv
```

Delete the pool only when the command returns no machine names:

```azurecli
az aks nodepool delete \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --output none
```

Verify that the pool no longer exists:

```azurecli
az aks nodepool list \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --query "[?name=='${FLEX_POOL_NAME}'].name" \
    --output tsv
```

## Remove supporting access

Use your identity inventory to confirm that no other host, flex node pool, or automation uses `HOST_PRINCIPAL_OBJECT_ID`. If you can't confirm that the identity is unused, keep the assignment. Otherwise, remove its AKS-scoped role assignment:

```bash
: "${HOST_PRINCIPAL_OBJECT_ID:?Record the host identity in the host-and-identity article.}"
```

```azurecli
az role assignment list \
    --assignee-object-id "${HOST_PRINCIPAL_OBJECT_ID}" \
    --scope "${AKS_RESOURCE_ID}" \
    --fill-principal-name false \
    --query "[?roleDefinitionName=='Azure Kubernetes Service Contributor Role'].{Id:id,PrincipalId:principalId,Role:roleDefinitionName,Scope:scope}" \
    --output table
```

Continue only when the output identifies the exact principal, role, and AKS cluster scope that you intend to remove.

```azurecli
az role assignment delete \
    --assignee-object-id "${HOST_PRINCIPAL_OBJECT_ID}" \
    --role "Azure Kubernetes Service Contributor Role" \
    --scope "${AKS_RESOURCE_ID}"
```

Verify that the assignment is gone:

```azurecli
az role assignment list \
    --assignee-object-id "${HOST_PRINCIPAL_OBJECT_ID}" \
    --scope "${AKS_RESOURCE_ID}" \
    --fill-principal-name false \
    --query "[?roleDefinitionName=='Azure Kubernetes Service Contributor Role'].id" \
    --output tsv
```

If no flex node pools remain and you manually applied the exact temporary preview RBAC objects in the networking article, remove them:

```bash
kubectl delete clusterrolebinding aks-flex-node-daemon --ignore-not-found
kubectl delete clusterrole aks-flex-node-daemon --ignore-not-found
```

Keep Unbounded-Net installed while the AKS-managed nodes depend on it for cluster networking. Remove dedicated clusters, networks, hosts, or Azure Arc connections only according to your organization's resource-retention and platform-management processes.

### Delete a dedicated service principal application

Complete this section only if you created a dedicated application for this deployment, the host is detached, and no other host or automation uses the application or its credentials. Skip it for managed identities or shared applications. Use your operator account with permission to delete the application in Microsoft Entra ID.

Deleting the application also deletes its associated service principal and registered credentials. Remove its Azure role assignments as described earlier before deleting it. For a credential-only test that never attached a host or assigned a role, you can perform this cleanup without the host-removal steps.

1. Display the application and service principal. Confirm that the client ID and service principal object ID match the dedicated identity recorded during host preparation.

    ```bash
    : "${SP_CLIENT_ID:?Set the application client ID of the dedicated service principal.}"
    : "${SP_OBJECT_ID:?Set the service principal object ID.}"
    ```

    ```azurecli
    az ad app show \
        --id "${SP_CLIENT_ID}" \
        --query "{Name:displayName,ClientId:appId,ApplicationObjectId:id}" \
        --output table

    az ad sp show \
        --id "${SP_CLIENT_ID}" \
        --query "{ClientId:appId,ServicePrincipalObjectId:id}" \
        --output table
    ```

1. Delete only the confirmed dedicated application.

    ```azurecli
    az ad app delete --id "${SP_CLIENT_ID}"
    ```

1. Verify that neither active directory object remains.

    ```azurecli
    az ad app list \
        --filter "appId eq '${SP_CLIENT_ID}'" \
        --query "[].appId" \
        --output tsv

    az ad sp list \
        --filter "appId eq '${SP_CLIENT_ID}'" \
        --query "[].appId" \
        --output tsv
    ```

    Continue when both commands succeed and return no application IDs. If directory replication delays deletion, wait briefly and repeat the checks.

1. Remove the exact local PEM file used for the test. Replace the placeholder with its protected path in your Bash environment, not the installed host path.

    ```bash
    export SP_CLIENT_CERTIFICATE_FILE="<protected-path-to-sp-client.pem>"
    rm -f -- "${SP_CLIENT_CERTIFICATE_FILE}"
    unset SP_CLIENT_CERTIFICATE_FILE
    ```

    Remove any other credential copies through your approved credential-management process. Reset removes the installed copy under `/etc/aks-flex-node`.

## Next step

Review the [support policy for flex nodes](./flex-nodes-support-policy.md).
