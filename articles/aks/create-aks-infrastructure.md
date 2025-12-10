---
title: Create Azure AKS Infrastructure
description: Learn how to build the foundational Azure infrastructure for a generic AKS cluster that can host any containerized workload.
ms.topic: how-to
ms.author: carols
author: fossygirl
ms.reviewer: rogardle
ms.date: 11/20/2025
---

# Create Azure AKS infrastructure

In this article, you provision the core Azure resources required for a production-ready AKS deployment. This article validates Azure access, creates a resource group, establishes an Azure Container Registry (ACR), deploys a baseline AKS cluster, optionally adds an additional node pool for user workloads, and grants the cluster permission to pull from ACR. All commands rely on parameterized environment variables so the workflow remains repeatable across regions and subscriptions.

<!--- Summary: Builds the foundational Azure infrastructure for a generic AKS cluster that can host any containerized workload. --->

## Prerequisites

You need the following tooling and account access before running the guide. Ensure you're authenticated to Azure using `az login` and have sufficient permissions to create resource groups, container registries, and AKS clusters.

- Azure subscription with quota for the selected region
- Azure CLI (`az`) with Owner or Contributor rights
- kubectl configured locally for cluster access
- jq (optional) for parsing JSON output during verification

Run the following commands to confirm you have all the necessary CLI tooling and Azure access:

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

<!--- Summary: Confirms the necessary CLI tooling and Azure access are in place. --->

## Set up the environment

Here, you define all the environment variables used throughout the provisioning steps. The `HASH` timestamp keeps resource names unique during repeated executions. Cluster and registry defaults target a minimal proof-of-concept footprint, but you can adjust them as needed.

The following commands establish Azure scope, AKS sizing, and ACR naming conventions for the provisioning sequence regardless of downstream workloads.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp

# Azure scope and regional placement
export LOCATION="${LOCATION:-eastus2}"
export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg_aks_${HASH}}"

# AKS cluster naming and version control
# Hyphen required because AKS cluster names cannot include underscores
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-openwebsearch-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"  # Optional Kubernetes version override

# Node pool sizing
export AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
export AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-1}"
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"
export AKS_SYSTEM_NODEPOOL_NAME="${AKS_SYSTEM_NODEPOOL_NAME:-system}"
export AKS_USER_NODEPOOL_NAME="${AKS_USER_NODEPOOL_NAME:-user}"

# ACR configuration
export ACR_NAME="${ACR_NAME:-acrwebsearch${HASH}}"
export ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"
```

<!--- Summary: Establishes Azure scope, AKS sizing, and ACR naming conventions for the provisioning sequence regardless of downstream workloads. --->

### Verify environment variable values

Review the effective configuration before creating resources. Re-run the block after any adjustments to ensure the active values are correct for the target subscription and region.

Use the following commands to pint the active parameters to validate naming, sizing, and regional choices.

```bash
: "${HASH:=$(date -u +"%y%m%d%H%M")}"  # Ensure HASH exists

VARS=(
  HASH
  LOCATION
  SUBSCRIPTION_ID
  RESOURCE_GROUP
  AKS_CLUSTER_NAME
  AKS_VERSION
  AKS_SYSTEM_NODE_COUNT
  AKS_USER_NODE_COUNT
  AKS_NODE_VM_SIZE
  AKS_SYSTEM_NODEPOOL_NAME
  AKS_USER_NODEPOOL_NAME
  ACR_NAME
  ACR_LOGIN_SERVER
)
for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

<!--- Summary: Prints the active parameters to validate naming, sizing, and regional choices. --->

## Steps

Execute each step sequentially. Every subsection includes purpose, commands, and a summary to confirm expected outcomes.

### Check the Azure subscription context

Verify the active Azure subscription and ensure the resource providers required for AKS and ACR operations are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

<!--- Summary: Azure subscription context confirmed and required providers registered. --->

### Create a resource group

Provision a dedicated resource group to isolate the AKS cluster, registry, and supporting infrastructure for your workloads.

```bash
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table
```

<!--- Summary: Resource group created in the target region for subsequent resources. --->

### Provision the Azure Container Registry

Create an Azure Container Registry for storing container images and authenticate the local Docker daemon to push images.

```bash
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Basic \
  --output table
az acr login --name "${ACR_NAME}"
```

<!--- Summary: ACR provisioned and local Docker client authenticated for pushes. --->

### Create the AKS cluster

Deploy the AKS cluster to host your workloads. Guard against reusing an existing cluster name by checking before creation.

```bash
if az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "AKS cluster ${AKS_CLUSTER_NAME} already exists in ${RESOURCE_GROUP}";
  echo "Skip creation or provide a new AKS_CLUSTER_NAME.";
else
  az aks create \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --generate-ssh-keys \
    --node-count "${AKS_SYSTEM_NODE_COUNT}" \
    --nodepool-name "${AKS_SYSTEM_NODEPOOL_NAME}" \
    --node-vm-size "${AKS_NODE_VM_SIZE}" \
    ${AKS_VERSION:+--kubernetes-version "${AKS_VERSION}"} \
    --output table
fi
```

<!--- Summary: AKS cluster created (or an existing one detected) in the specified resource group. --->

### Add optional user node pool

Provision an additional node pool when requested. The add command runs asynchronously to avoid CLI timeouts; the wait command tracks Azure's progress. The script first checks whether the pool already exists to prevent duplicate name errors.

```bash
if [ "${AKS_USER_NODE_COUNT}" -gt 0 ]; then
  if az aks nodepool show \
    --cluster-name "${AKS_CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_USER_NODEPOOL_NAME}" >/dev/null 2>&1; then
    echo "Node pool ${AKS_USER_NODEPOOL_NAME} already exists; skipping add.";
  else
    az aks nodepool add \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --node-count "${AKS_USER_NODE_COUNT}" \
      --node-vm-size "${AKS_NODE_VM_SIZE}" \
      --no-wait
    az aks nodepool wait \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --created
  fi
fi
```

<!--- Summary: Optional user node pool provisioned (or detected) with Azure confirming creation before continuing. --->

### Retrieve cluster credentials

Merge the AKS kubeconfig into the local context and verify all nodes are reachable.

```bash
az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --overwrite-existing
kubectl get nodes -o wide
```

<!--- Summary: kubectl context updated and node connectivity verified. --->

### Attach ACR to AKS cluster

Grant the AKS cluster permission to pull images from the provisioned ACR so future deployments can access your container images.

```bash
az aks update \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --attach-acr "${ACR_NAME}" \
  --output table
```

<!--- Summary: AKS cluster now has pull rights to the Azure Container Registry. --->

## Verification

Confirm the AKS cluster exists and responds to basic `kubectl` queries before continuing to downstream deployment steps. Start by ensuring the AKS cluster exists.

```bash
if ! az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "{name:name,provisioningState:provisioningState,location:location}" \
  --output table; then
  echo "AKS cluster '${AKS_CLUSTER_NAME}' not found in resource group '${RESOURCE_GROUP}'."
else
  echo "AKS cluster '${AKS_CLUSTER_NAME}' exists in resource group '${RESOURCE_GROUP}'."
fi
```

If the AKS cluster has been created, you'll see something like:

<!-- expected_similarity=".*exists.*" -->

```text
AKS cluster ${AKS_CLUSTER_NAME} exists in resource group ${RESOURCE_GROUP}.
```

Next, check that `kubectl` is correctly configured:

```bash
kubectl cluster-info
```

This command will output status of the current cluster, something like:

<!-- expected_similarity="(?s).*control plane is running.*" -->

```text
Kubernetes control plane is running at ...
CoreDNS is running at https://...
Metrics-server is running at https://...
```

Finally, ensure that there are both system and user nodes available:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.agentpool}{"\n"}{end}' |
  sort |
  uniq -c
```

This will output a count of nodes, something like:

<!-- expected_similarity=".*[0-9]+.*system\n.*[0-9]+.*user" -->

```text
      1 system
      1 user
```

Summary: Validated that the AKS cluster is present, healthy, and reachable via kubectl in the current context.

## Summary

The resource group, container registry, AKS cluster, optional node pool, and registry attachment are validated, leaving the cluster ready for any containerized workloads.

## Next Steps

- Proceed with `docs/OpenWebSearch_On_AKS.md` to deploy KMCP and the MCP server
- Configure role assignments or network policies specific to your security posture
- Integrate Azure Monitor or Log Analytics for operational visibility
- Run infrastructure cleanup commands after experimentation to manage costs
