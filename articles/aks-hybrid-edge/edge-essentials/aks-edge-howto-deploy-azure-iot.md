---
title: Azure IoT Operations with AKS Edge Essentials
description: Learn how to run the quickstart script that creates an Arc-enabled AKS Edge Essentials Kubernetes cluster that can run Azure IoT Operations.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Create and configure an AKS Edge Essentials cluster that can run Azure IoT Operations

Azure Kubernetes Service (AKS) Edge Essentials is one of the supported cluster platforms for [Azure IoT Operations](/azure/iot-operations/overview-iot-operations). You can use AKS Edge Essentials to create a Microsoft-managed Kubernetes cluster and deploy Azure IoT Operations on it as a workload. This article describes the steps to run a script that creates an AKS Edge Essentials Kubernetes cluster with the required configuration for Azure IoT Operations, and then connects that cluster to Azure Arc.

> [!NOTE]
> Azure IoT Operations supports AKS Edge Essentials when deployed on K3s single machine clusters only. K8s clusters are not supported for AIO and deploying clusters on multiple machines is an experimental feature.

## Prerequisites for running the script

To run the script, you need the following prerequisites:

- An Azure subscription with either the **Owner** role or a combination of **Contributor** and **User Access Administrator** roles. You can check your access level by navigating to your subscription, selecting **Access control (IAM)** on the left-hand side of the Azure portal, and then selecting **View my access**. If you don't have an Azure subscription, [create one for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
- Azure CLI version 2.64.0 or newer installed on your development machine. Use `az --version` to check your version and `az upgrade` to update if necessary. For more information, see [How to install the Azure CLI](/cli/azure/install-azure-cli).
- Install the latest version of the **connectedk8s** extensions for Azure CLI:

  ```azurecli
  az extension add --upgrade --name connectedk8s 
  ```

- Hardware requirements: ensure that your machine has a minimum of 16 GB available RAM, 4 available vCPUs, and 52 GB free disk space reserved for Azure IoT Operations.

## Create an Arc-enabled cluster

The [AksEdgeQuickStartForAio.ps1](https://github.com/Azure/AKS-Edge/blob/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1) script automates the process of creating and connecting a cluster, and is the recommended path for deploying Azure IoT Operations on AKS Edge Essentials. The script performs the following tasks:

- Downloads the latest k3s [AKS Edge Essentials MSI from this repo](https://github.com/Azure/aks-edge).
- Installs AKS Edge Essentials, and deploys and creates a single machine k3s cluster on your Windows machine.
- Connects to the Azure subscription, creates a resource group if it doesn't already exist, and connects the cluster to Arc to create an Arc-enabled Kubernetes cluster.
- Enables the custom location feature on the Arc-enabled Kubernetes cluster.
- Enables the workload identity federation feature on the Arc-enabled Kubernetes cluster.
- Deploys the local path provisioning.
- Configures firewall rules on the host Windows machine for the MQTT broker.
- On the Linux VM, which serves as the Kubernetes control plane node:
  - Configures the port proxy for the Kubernetes service default IP range of 10.96.0.0/28.
  - Configures the IP table rules:
    - `sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 9110 -j ACCEPT`
    - `sudo iptables -A INPUT -p tcp --dport (10124, 8420, 2379, 50051) -j ACCEPT`

To run the quickstart script, perform the following steps:

1. Open an elevated PowerShell window and change the directory to a working folder.
1. Get the `objectId` of the Microsoft Entra ID application that the Azure Arc service uses in your tenant. Run the following command exactly as written, without changing the GUID value.

   ```azurecli
   az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv
   ```

1. Run the following commands:

   ```powershell
   $giturl = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools"
   $url = "$giturl/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1"
   Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStartForAio.ps1 -UseBasicParsing
   Invoke-WebRequest -Uri "$giturl/aio-aide-userconfig.json" -OutFile .\aio-aide-userconfig.json -UseBasicParsing
   Invoke-WebRequest -Uri "$giturl/aio-aksedge-config.json" -OutFile .\aio-aksedge-config.json -UseBasicParsing
   Unblock-File .\AksEdgeQuickStartForAio.ps1
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```

1. Add the required parameter values in the **aio-aide-userconfig.json** and **aio-aksedge-config.json** files:

   In **aio-aide-userconfig.json**, fill in the following values:

   |Flag|Value  |
   |---------|---------|
   |SubscriptionId    |      The ID of your Azure subscription. If you don't know your subscription ID, see [Find your Azure subscription](/azure/azure-portal/get-subscription-tenant-id#find-your-azure-subscription). |
   |TenantId  |    The ID of your Microsoft Entra tenant. If you don't know your tenant ID, see [Find your Microsoft Entra tenant](/azure/azure-portal/get-subscription-tenant-id#find-your-microsoft-entra-tenant).     |
   |ResourceGroupName     |   The name of an existing resource group or a name for a new resource group to be created. Only one Azure IoT Operations instance is supported per resource group.     |
   |Location     |      An Azure region close to you. For a list of the Azure IoT Operations supported Azure regions, see [Supported regions](/azure/iot-operations/overview-support#supported-regions).   |
   |CustomLocationOID     |     The object ID value that you retrieved in step 2.     |
   |EnableWorkloadIdentity (preview) | Enabled by default. While you can opt out before deploying the cluster, you can't enable it after cluster creation. Workload identity federation lets you configure a user-assigned managed identity or app registration in Microsoft Entra ID to trust tokens from external identity providers (IdPs) such as Kubernetes. To configure workload identity federation, [see this article](aks-edge-workload-identity.md). |

   In **aio-aksedge-config.json**, add the required **ClusterName** field and other optional fields, as follows:

   |Flag | Value  |
   |---------|---------|
   | ClusterName  |    A name for the new cluster to be created.     |
   | `Proxy-Https` | Provide the proxy value: `https://<proxy-server-ip-address>:<port>`. |
   | `Proxy-Http` | Provide the proxy value: `http://<proxy-server-ip-address>:<port>`. |
   | `Proxy-No` | Provide the proxy skip range: `<excludedIP>`,`<excludedCIDR>`. If the `http(s)_proxy` is provided, then `No` should also be updated to `localhost,127.0.0.0/8,192.168.0.0/16,172.17.0.0/16,10.42.0.0/16,10.43.0.0/16,10.96.0.0/12,10.244.0.0/16,.svc,169.254.169.254`. |

   > [!IMPORTANT]
   > Preview features are available on a self-service, opt-in basis. Previews are provided "as is" and "as available," and they're excluded from the service-level agreements and limited warranty. AKS Edge Essentials previews are partially covered by customer support on a best-effort basis.

1. [Optional] [Azure Arc gateway (preview)](/azure/azure-arc/servers/arc-gateway?tabs=portal) lets you onboard infrastructure to Azure Arc using only 7 endpoints. To use Azure Arc Gateway with Azure IoT Operations on AKS Edge Essentials:

   - [Follow step 1 to create an Arc gateway resource](/azure/azure-arc/servers/arc-gateway?tabs=portal#step-1-create-an-arc-gateway-resource).
   - Note [the URLs listed in step 2](/azure/azure-arc/servers/arc-gateway?tabs=portal#step-2-ensure-the-required-urls-are-allowed-in-your-environment) to add to the `proxy-no` in **aio-aksedge-config.json**.
   - Follow [step 3a in the Arc gateway documentation](/azure/azure-arc/servers/arc-gateway?tabs=portal#step-3a-onboard-azure-arc-resources-with-your-arc-gateway-resource) and save the gateway ID.
   - In **aio-aide-userconfig.json**, set the value of `GatewayResourceId` to the gateway ID saved from the previous step.

1. Run the following command:

   ```powershell
   .\AksEdgeQuickStartForAio.ps1 -aideUserConfigfile .\aio-aide-userconfig.json -aksedgeConfigFile .\aio-aksedge-config.json
   ```

   If there are issues during deployment; for example, if your machine reboots as part of this process, run the set of commands again.
  
   Run the following commands to check that the deployment was successful:
  
   ```powershell
   Import-Module AksEdge
   Get-AksEdgeDeploymentInfo
   ```
  
   In the output of the `Get-AksEdgeDeploymentInfo` command, you should see that the cluster's Arc status is **Connected**.

## Verify your cluster

To verify that your Kubernetes cluster is Azure Arc-enabled, run the following command:

```bash
kubectl get deployments,pods -n azure-arc
```

The output looks similar to the following example:

```output
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/clusterconnect-agent         1/1     1            1           10m
deployment.apps/extension-manager            1/1     1            1           10m
deployment.apps/clusteridentityoperator      1/1     1            1           10m
deployment.apps/controller-manager           1/1     1            1           10m
deployment.apps/flux-logs-agent              1/1     1            1           10m
deployment.apps/cluster-metadata-operator    1/1     1            1           10m
deployment.apps/extension-events-collector   1/1     1            1           10m
deployment.apps/config-agent                 1/1     1            1           10m
deployment.apps/kube-aad-proxy               1/1     1            1           10m
deployment.apps/resource-sync-agent          1/1     1            1           10m
deployment.apps/metrics-agent                1/1     1            1           10m

NAME                                              READY   STATUS    RESTARTS        AGE
pod/clusterconnect-agent-5948cdfb4c-vzfst         3/3     Running   0               10m
pod/extension-manager-65b8f7f4cb-tp7pp            3/3     Running   0               10m
pod/clusteridentityoperator-6d64fdb886-p5m25      2/2     Running   0               10m
pod/controller-manager-567c9647db-qkprs           2/2     Running   0               10m
pod/flux-logs-agent-7bf6f4bf8c-mr5df              1/1     Running   0               10m
pod/cluster-metadata-operator-7cc4c554d4-nck9z    2/2     Running   0               10m
pod/extension-events-collector-58dfb78cb5-vxbzq   2/2     Running   0               10m
pod/config-agent-7579f558d9-5jnwq                 2/2     Running   0               10m
pod/kube-aad-proxy-56d9f754d8-9gthm               2/2     Running   0               10m
pod/resource-sync-agent-769bb66b79-z9n46          2/2     Running   0               10m
pod/metrics-agent-6588f97dc-455j8                 2/2     Running   0               10m
```

## Next steps

- [Deploy Azure IoT Operations](/azure/iot-operations/deploy-iot-ops/howto-deploy-iot-operations)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
