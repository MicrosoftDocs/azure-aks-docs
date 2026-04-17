---
title: Set up a cluster for AKS desktop and configure projects
description: Learn how to set up a compatible AKS cluster and configure projects for AKS desktop in Azure Kubernetes Service (AKS).
ms.subservice: aks-developer
ms.service: azure-kubernetes-service
ms.editor: schaffererin
author: danielsollondon
ms.topic: how-to
ms.date: 04/16/2026
ms.author: danis
# Customer intent: As a devops engineer or cluster operator or platform engineer, I want to set up a compatible AKS cluster and configure projects for AKS desktop, so that I can delegate to developers who can deploy and/or manage applications without needing deep Kubernetes expertise.
---

# Set up a cluster and projects for AKS desktop

Setting up a cluster for AKS desktop requires configuring specific AKS features the tool depends on for project management, Azure RBAC-based access control, and application monitoring. Without these requirements, AKS desktop features such as metrics, network policies, and RBAC-based access will be unavailable or degraded. This article covers the minimum cluster requirements for AKS desktop, recommended optional addons, and how to create and import projects.


The minimum and fastest way to deploy apps with AKS desktop is with:
  1. AKS Automatic cluster
  2. Azure Container Registry (ACR)
  3. Existing image in the ACR
  4. [Install the latest build of AKS desktop](https://github.com/Azure/aks-desktop/releases).



## Prerequisites

- An Azure subscription. If you don't have one, create a [free Azure account](https://azure.microsoft.com/free).
- Azure CLI version 2.64.0 or later. Check your version with [`az --version`](/cli/azure/reference-index#az-version) and [install or upgrade](/cli/azure/install-azure-cli) as needed.
- The `aks-preview` Azure CLI extension: `az extension add --name aks-preview`.
- Permissions to create resources in Azure (Contributor role or Owner role on the target resource group).
- **Azure Kubernetes Service RBAC Cluster Admin** role on the target AKS cluster to grant users access to projects.

## AKS desktop cluster support

AKS desktop builds on top of several AKS features — including AKS Deployment Safeguards, Managed Prometheus for metrics, and Entra ID-based permission management — all of which must be configured on your cluster to ensure applications are deployed to best practices.

### AKS Automatic clusters
[AKS Automatic clusters](intro-aks-automatic.md) come with all of the above features preconfigured and require no additional setup. If you want less management and get started quickly, AKS Automatic is the easiest path to a fully compatible cluster.

See the [official feature comparison](intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison) for a complete breakdown of differences between AKS Automatic and AKS Standard.

If you have an existing AKS Automatic cluster, you can [deploy an application](aks-desktop-app.md) or [import an existing namespace](#use-existing-namespace--importing-existing-namespaces-into-aks-desktop-projects) that includes your application.


#### Quickstart: Create an AKS Automatic Cluster with an ACR

```bash
# set vars
RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"
myResourceGroup=bbash$RAND
myLocation=westus3
myClusterName=clu-$RAND
registryName=bbashreg$RAND


# create rg
az group create --name $myResourceGroup --location $myLocation

# create acr
az acr create --resource-group $myResourceGroup --name $registryName --sku Basic

# create cluster & attach acr
az aks create --resource-group $myResourceGroup --name $myClusterName --sku automatic --attach-acr $registryName

# get cluster resource ID
AKS_ID=$(az aks show --resource-group $myResourceGroup --name $myClusterName --query id --output tsv)

# grant yourself admin permission to the cluster
az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --assignee <your-entra-id> \
    --scope $AKS_ID

# [optional] upload test image to acr for testing
mkdir myapp
cd myapp
git clone https://github.com/Azure-Samples/contoso-air
cd contoso-air/src/web
az acr build --resource-group $myResourceGroup --registry $registryName --image contosoair:v1 .

# note the application port is 3000, you need this for deployment!
```

### New and Existing AKS Standard clusters
You can use an existing AKS Standard cluster but that will need have AKS features enabled for AKS desktop.

These are hard requirements. AKS desktop will not function with AKS clusters that lack them.

| Requirement | Why it is needed | How to check | How to enable |
| --- | --- | --- | --- |
| **Microsoft Entra ID (AAD) authentication** | Required for Azure RBAC and managed namespace role assignments. Clusters without Entra ID authentication enabled do not appear in the AKS desktop cluster picker. | `az aks show -g <rg> -n <cluster> --query aadProfile` -- must not be `null` | Must be set at cluster creation: `--enable-aad --enable-azure-rbac` |
| **Azure RBAC for Kubernetes authorization** | Required for assigning users to projects with Admin, Writer, or Reader roles. | `az aks show -g <rg> -n <cluster> --query aadProfile.enableAzureRbac` -- must be `true` | Must be set at cluster creation: `--enable-azure-rbac` |

### Recommended configuration for Standard AKS clusters

These addons and settings are optional but strongly recommended. Without them, specific AKS desktop features will be unavailable or degraded.

| Feature | What it enables in AKS desktop | Can be enabled after cluster creation? | How to enable |
| --- | --- | --- | --- |
| **Network policy engine** (Cilium recommended) | Ingress and egress network policies on managed namespaces. Without a network policy engine, policies are silently ignored. | **No** -- must be set at cluster creation. | `--network-plugin azure --network-policy cilium` |
| **Azure Monitor Metrics** (Managed Prometheus) | Metrics tab (CPU, memory, and request-rate charts) and the Scaling chart (CPU %). | Yes | `az aks update -g <rg> -n <cluster> --enable-azure-monitor-metrics` |
| **Managed Grafana** | Visualization for metrics dashboards. | Yes | Enabled alongside Azure Monitor Metrics when using the Azure Portal. Via CLI, link a Grafana workspace with `--enable-azure-monitor-metrics --azure-monitor-workspace-resource-id <id>`. |
| **KEDA** | Kubernetes Event-Driven Autoscaling in the Scaling tab. | Yes | `az aks update -g <rg> -n <cluster> --enable-keda` |
| **VPA** (Vertical Pod Autoscaler) | Vertical pod autoscaling recommendations in the Scaling tab. | Yes | `az aks update -g <rg> -n <cluster> --enable-vpa` |

### Feature availability matrix

The table below is a quick reference showing which AKS desktop features work when specific cluster addons are missing.

| AKS desktop feature | Works without addon? | Required addon | Can be enabled after cluster creation? |
| --- | --- | --- | --- |
| Project creation | Yes | Azure RBAC + Entra ID | No (creation-time only) |
| Network policies | No (silently ignored) | Cilium, Calico, or Azure network policy | No (creation-time only) |
| Metrics tab | No (shows error) | Managed Prometheus | Yes |
| Scaling chart (CPU %) | No (shows error) | Managed Prometheus | Yes |
| HPA (horizontal scaling) | Yes | metrics-server (included by default) | Yes |
| KEDA scaling | No | KEDA addon | Yes |
| VPA scaling | No | VPA addon | Yes |

### Creating a fully compatible AKS Standard cluster

The following command creates a Standard-tier AKS cluster with all recommended features enabled:

```bash
az aks create \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --location <location> \
  --tier standard \
  --enable-aad \
  --enable-azure-rbac \
  --network-plugin azure \
  --network-policy cilium \
  --enable-azure-monitor-metrics \
  --enable-keda \
  --enable-vpa \
  --enable-hpa \
  --generate-ssh-keys
```

Replace `<resource-group>`, `<cluster-name>`, and `<location>` with your own values. A cluster created with these flags will support every AKS desktop feature without additional configuration.

To attach an existing ACR to the cluster after creation, run:
```bash
az aks update \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --attach-acr <acr-name>
```

### Enabling features on an existing cluster

Some features can be added to an existing cluster after creation. However, the **network policy engine cannot be changed after cluster creation**.

> [!IMPORTANT]
> If your cluster was created without a network policy engine, you must create a new cluster with the `--network-policy cilium` flag for full network policy support. This cannot be enabled on an existing cluster.

#### Enable Azure Monitor Metrics (Managed Prometheus)

```bash
az aks update -g <rg> -n <cluster> --enable-azure-monitor-metrics
```

This enables the Metrics tab and the Scaling chart (CPU %) in AKS desktop.

#### Enable KEDA addon

[Kubernetes Event-Driven Autoscaling (KEDA)](keda-about.md) is a lightweight component that makes application autoscaling simple.

```bash
az aks update -g <rg> -n <cluster> --enable-keda
```

This enables KEDA-based autoscaling in the Scaling tab.

#### Enable VPA addon

The [Vertical Pod Autoscaler (VPA)](vertical-pod-autoscaler.md) automatically adjusts pod resource requests based on observed usage.

```bash
az aks update -g <rg> -n <cluster> --enable-vpa
```

This enables VPA recommendations in the Scaling tab.

> [!NOTE]
> These commands may take several minutes to complete. Each addon may incur additional Azure costs. See [AKS pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/) for details.

## About Projects in AKS desktop
![AKS desktop project creation options showing New Namespace, AKS Managed Namespace, and Use Existing Namespace](./media/aks-desktop-app/image.png)
The **Projects** feature simplifies Kubernetes management by grouping related resources, such as workloads, services, configurations and Azure Resources into logical units. This approach streamlines navigation, improves visibility, and supports teamwork by providing an application-focused view across namespaces and clusters. It also provides ownership attribution and the basis for cost management.

There are 3 options when you create a Project:
* Use Existing namespace
* Create a New Namespace
* Create a New AKS Managed Namespace

### New Namespace
This creates a standard Kubernetes namespace and can be used across any types of Kubernetes cluster supported by [Headlamp](https://headlamp.dev/docs/latest/learn/projects), this provides basic functionality of seeing application resources, their properties and map.

### AKS Managed Namespace
In AKS desktop, this enhanced project type is directly linked by default to an [AKS managed namespace](concepts-managed-namespaces.md), which is a way to logically isolate workloads and teams within a cluster. This feature enables administrators to enforce resource quotas, apply network policies, and manage access control at the namespace level. Therefore a Managed Namespace attributes Azure Resources and Kubernetes resources together, this is useful for ownership attribution, cost management and a way of identifying everything that is part of your application. A Project can consist of one or more applications, note in most examples we only show one app to keep it simple.

## Use Existing namespace / Importing existing namespaces into AKS desktop projects
When you open this, AKS desktop will scan:
* AKS Managed Namespaces (MNS) that you have permissions to. You don't need to have registered the cluster they're deployed to — you only need MNS permissions to access them.
* Regular Kubernetes namespaces across the clusters you have registered, note, you will only be shown namespaces you have access to.

It will indicate for both if they are part of an AKS Project already, this means there is metadata on the namespace (labels) with project information. If you import the namespace it will add labels to the namespace, you will then see the namespace represented as a project and observe the overview.


## Project Overview in AKS desktop

Once you deploy an application to a Project through AKS desktop, you gain access to the **Project Overview** screen. The Project Overview screen is your centralized control hub, giving you visibility, insights, and direct actions to manage, monitor, and optimize your application.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-app-project-overview.png" alt-text="Screenshot of the Project Overview screen in AKS desktop." lightbox="./media/aks-desktop-app/aks-desktop-app-project-overview.png":::

The following table describes the key features available in the Project Overview screen:

| Feature | Description |
| ------- | ----------- |
| **Resources** | View all Kubernetes resources deployed in your Project, including workloads and network configuration. |
| **Access** | Grant or remove access to your Project. |
| **Map** | Visualize how Kubernetes resources in your Project interact, showing data flow between deployments and services. |
| **Info** | View and edit project resource quota, network policies. |
| **Deploy** | See pipelines created by GitHub Pipelines preview. |
| **Logs** | Access streaming logs for your application. |
| **Metrics** | View detailed metrics such as CPU, memory, and resource usage for your application. |
| **Scaling** | Configure application scaling using Horizontal Pod Autoscaler (HPA) or manual settings. |
| **Insights** | Run eBPF-based diagnostics (Processes, Trace TCP, Trace DNS) to troubleshoot application issues without code changes or pod restarts. See [Troubleshoot an application using Insights](aks-desktop-deploy-troubleshooting.md). |


## Next steps

- [Deploy an application with AKS desktop](aks-desktop-app.md)
- [Set up permissions for AKS desktop](aks-desktop-permissions.md)
- [AKS desktop quick start](aks-desktop-quickstart-auto.md)
- [Troubleshoot an application using Insights (preview)](aks-desktop-deploy-troubleshooting.md)
- [Use the AI troubleshooting assistant (preview)](aks-desktop-deploy-ai-assistant.md)


