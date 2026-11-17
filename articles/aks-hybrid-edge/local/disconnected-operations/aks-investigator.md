---
title: Install and use the Investigator extension for AKS on Azure Local disconnected operations
description: Learn how to install the Investigator extension for AKS and use AI-assisted troubleshooting with AKS on Azure Local disconnected operations.
ms.topic: how-to
ms.date: 11/09/2026
ms.custom: disconnected-operations
author: olaseniadeniji
ms.author: oadeniji
ai-usage: ai-assisted
---

# Install and use the Investigator extension for AKS on Azure Local disconnected operations

The Investigator extension for AKS provides AI-assisted troubleshooting for Kubernetes clusters. By using [disconnected operations for Azure Local](/azure/azure-local/manage/disconnected-operations-overview), the investigator and its AI model run in your environment without using a public AI model endpoint.

This article shows you how to:

- Import the AKS Investigator platform expansion pack.
- Install the Investigator extension for AKS on an AKS on Azure Local cluster.
- Install the `kubectl investigate` plug-in.
- Run and review an investigation.

> [!IMPORTANT]
> The Investigator extension for AKS is in preview. Preview features are provided without a service-level agreement and might change before general availability. Review the evidence returned by an investigation before you make changes to a workload.

## Prerequisites

Before you begin, ensure you have:

- Azure Local disconnected operations version 2607 or later.
- An AKS on Azure Local cluster deployed in the disconnected operations environment.
- A `linux/amd64` worker node that meets the resource requirements in the following table.
- The AKS Investigator expansion pack from the [disconnected operations catalog](https://github.com/Azure/AKSInvestigator/blob/main/DISCONNECTED_CATALOG.md).
- The `kubectl investigate` client for your operating system from [AKS Investigator releases](https://github.com/Azure/AKSInvestigator/releases).
- Operator access to the disconnected operations management endpoint.
- The Azure Local OperationsModule on the management computer.
- The [Azure CLI for disconnected operations](/azure/azure-local/manage/disconnected-operations-cli).
- The `k8s-extension` Azure CLI extension.
- `kubectl` configured to access the target cluster.

The Investigator extension for AKS supports CPU and GPU inference. CPU inference is the default and has the following requirements:

| Resource | Requirement |
| --- | --- |
| Architecture | `linux/amd64` |
| Processor | Intel processor with AVX-512 support |
| CPU | 12 vCPUs |
| Memory | 38 GiB requested and 48 GiB limit |
| Shared memory | 2 GiB |

The CPU image doesn't run on a processor that doesn't support AVX-512.

Update the required Azure CLI extensions:

```azurecli
az extension add --upgrade --name k8s-extension
```

Verify that your Kubernetes identity can access the Investigator deployment:

```powershell
kubectl auth can-i get deployments -n aks-investigator
kubectl auth can-i list deployments -n aks-investigator
kubectl auth can-i list pods -n aks-investigator
kubectl auth can-i create pods --subresource=exec -n aks-investigator
```

Each command must return `yes`.

## Import the AKS Investigator expansion pack

AKS Investigator is delivered to a disconnected environment as a [platform expansion pack](/azure/azure-local/manage/disconnected-operations-platform-expansion-packs). Azure Local doesn't include AKS Investigator by default.

On an internet-connected computer, download the required expansion pack from the [AKS Investigator disconnected operations catalog](https://github.com/Azure/AKSInvestigator/blob/main/DISCONNECTED_CATALOG.md). Transfer the expansion pack to the disconnected environment and copy it to the management computer. The expansion pack adds the extension chart, container images, AI model, and client artifacts to the local environment.

### Load the OperationsModule

On a Windows management computer, import the OperationsModule:

```powershell
$applianceConfigBasePath = "C:\AzureLocalDisconnectedOperations"

Import-Module `
    "$applianceConfigBasePath\OperationsModule\Azure.Local.DisconnectedOperations.psd1" `
    -Force
```

Set the management client context for your disconnected operations environment. For more information, see [Manage platform expansion packs for disconnected operations](/azure/azure-local/manage/disconnected-operations-platform-expansion-packs).

### Upload and install the expansion pack

Set the path to the AKS Investigator expansion pack:

```powershell
$expansionPackPath = "C:\AzureLocalDisconnectedOperations\packs\<aks-investigator-package>.zip"
```

Upload the expansion pack:

```powershell
$expansionPackId = Start-AldoExpansionPackUpload `
    -ExpansionPackPath $expansionPackPath
```

Check the upload status:

```powershell
Get-AldoExpansionPackUploadStatus
```

After the upload finishes, install the expansion pack:

```powershell
Start-AldoExpansionPackInstallation `
    -ExpansionPackId $expansionPackId `
    -Wait
```

Verify the installation:

```powershell
Get-AldoExpansionPackDetails `
    -ExpansionPackId $expansionPackId
```

Confirm that the expansion pack reports an installed state before you install the Investigator extension for AKS.

## Install the Investigator extension for AKS

Set the values for your Arc-enabled Kubernetes resource:

```powershell
$subscriptionId = "<subscription-id>"
$resourceGroup = "<resource-group>"
$clusterName = "<cluster-name>"

az account set --subscription $subscriptionId
```

Install the Investigator extension for AKS:

Azure Arc enables AKS on Azure Local. The extension API uses the `connectedClusters` resource type for the target cluster.

```powershell
az k8s-extension create `
    --name aks-investigator `
    --extension-type microsoft.aks.investigator `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --release-train Stable `
    --release-namespace aks-investigator `
    --auto-upgrade-minor-version false
```

The extension uses the artifacts imported into the local `edgeartifacts` registry.

## Verify the extension installation

Check the extension provisioning state:

```powershell
az k8s-extension show `
    --name aks-investigator `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --query "{Name:name,State:provisioningState,Version:version}" `
    --output table
```

Confirm that the provisioning state is `Succeeded`.

Check the Investigator workloads:

```powershell
kubectl get deployments,pods -n aks-investigator
```

The installation is ready when the following deployments and their pods are ready:

- `aks-investigator-holmes`
- `saturn-vllm`

## Install the kubectl investigate plug-in

Download the client for your operating system from [AKS Investigator releases](https://github.com/Azure/AKSInvestigator/releases) on an internet-connected computer. Transfer the client to a computer that can access the disconnected AKS cluster.

### Windows

Download `kubectl-investigate-<version>-windows-amd64.exe`, rename it to `kubectl-investigate.exe`, and copy it to a directory in your `PATH`. Verify the installation:

```powershell
kubectl investigate --help
```

If the directory isn't in `PATH`, run the executable directly:

```powershell
.\kubectl-investigate.exe --help
```

### Linux

Download `kubectl-investigate-<version>-linux-amd64`, rename it to `kubectl-investigate`, and copy it to a directory in your `PATH`:

```bash
chmod +x kubectl-investigate
sudo install kubectl-investigate /usr/local/bin/kubectl-investigate
kubectl investigate --help
```

## Run an investigation

Confirm that your current Kubernetes context points to the intended cluster:

```powershell
kubectl config current-context
kubectl cluster-info
```

Start an interactive investigation:

```powershell
kubectl investigate -i --model saturn-vllm
```

At the prompt, describe the resource and the evidence you want the Investigator extension for AKS to examine. For example:

```text
Why is pod checkout-api-7d9f6b8f5c-abcde in namespace checkout restarting?
Review its status, events, and current container logs.
```

For more reliable results:

- Identify the resource type, name, and namespace.
- Describe the symptom and time range, when known.
- Specify the evidence to review, such as status, events, logs, or configuration.
- Ask one investigation question at a time.

A successful investigation displays `Model: saturn-vllm`, runs one or more Kubernetes queries, and returns a response based on the query results.

To view the complete output of a tool call, enter `/show <number>`, where `<number>` is the tool number displayed by the client. Enter `/exit` to end the interactive session.

## Review investigation results

The Investigator extension for AKS uses Kubernetes resources, events, logs, metrics, and RBAC metadata that its diagnostic tools can access. The model processes this context locally.

Before you act on a response:

1. Review the output from each tool call.
1. Confirm that the tool calls completed successfully.
1. Compare the response with the Kubernetes data returned by the tools.
1. Apply any remediation through your organization's standard change process.

The Kubernetes service account that the Investigator extension for AKS uses can get, list, and watch diagnostic resources. It doesn't have create, update, patch, or delete access to customer workloads.

## Remove the Investigator extension for AKS

Delete the extension before you remove its expansion pack:

```powershell
az k8s-extension delete `
    --name aks-investigator `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --yes
```

When no cluster uses the expansion pack, remove it:

```powershell
Remove-AldoExpansionPack `
    -ExpansionPackId $expansionPackId
```

Use `Get-AldoExpansionPackDetails` to check the removal status.

## Troubleshoot

### The extension installation fails

Display the extension details:

```powershell
az k8s-extension show `
    --name aks-investigator `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --output jsonc
```

Confirm that:

- The AKS Investigator expansion pack is installed.
- The cluster can reach the local `edgeartifacts` registry.
- The Arc-enabled Kubernetes resource is available from the local control plane.

### An Investigator pod isn't ready

Check the pods and recent events:

```powershell
kubectl get pods -n aks-investigator -o wide
kubectl get events -n aks-investigator --sort-by=.lastTimestamp
```

For a pod in the `Pending` state, confirm that a compatible worker node has enough available CPU and memory. For `ImagePullBackOff`, confirm that the expansion pack installation completed and the cluster can reach `edgeartifacts`.

### kubectl doesn't recognize investigate

Confirm that the client is named `kubectl-investigate.exe` on Windows or `kubectl-investigate` on Linux and that its directory is in `PATH`.

### Optional toolsets are unavailable

The client checks multiple diagnostic toolsets when it starts. An optional toolset might be unavailable when its command, credential, service, or API isn't present. This status doesn't indicate a failure if the toolsets required for your investigation are available.

### An investigation is slow or a query fails

Response time depends on cluster size, prompt scope, available compute capacity, and the number of diagnostic queries. CPU inference can take several minutes.

If a query fails, use `/show <number>` to review its output. Retry with a narrower question that identifies the resource, namespace, symptom, and evidence to examine. Don't rely on a conclusion when its supporting queries failed.

## Next steps

- [AKS on Azure Local with disconnected operations overview](/azure/aks-hybrid-edge/local/disconnected-operations/overview)
- [Manage platform expansion packs for disconnected operations](/azure/azure-local/manage/disconnected-operations-platform-expansion-packs)
- [Deploy and manage Azure Arc-enabled Kubernetes cluster extensions](/azure/azure-arc/kubernetes/extensions)
