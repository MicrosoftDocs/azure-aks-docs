---
title: Connect to an AKS on bare metal Cluster (preview)
description: Learn how to connect to your Azure Kubernetes Service on bare metal cluster using the Azure Arc proxy and kubectl.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Connect to an AKS on bare metal Cluster (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article shows you how to connect to your AKS on bare metal cluster to run `kubectl` commands. After you deploy your cluster, use the Azure Arc proxy to route `kubectl` commands from your local machine to the Kubernetes cluster running on your device.

## Prerequisites

- An AKS on bare metal cluster in a **Succeeded** state.
- Azure CLI installed on your local machine and signed in.
- The `connectedk8s` extension installed.

  ```azurecli
  az extension add --name connectedk8s
  ```

- `kubectl` installed. Open a terminal and run the following command, then close and reopen your terminal:

  ```azurecli
  az aks install-cli
  ```

- Your user account must be a member of the Microsoft Entra ID admin group you specified during cluster deployment. This membership is required to view and manage workloads on the cluster.

## Connect by using Azure Arc proxy

The Azure Arc proxy lets you connect to your cluster from anywhere without direct network access to the bare metal host.

### Step 1: Sign in to Azure

Open a terminal window and sign in to Azure, and then select the subscription that contains your deployed cluster:

```azurecli
az login
```

### Step 2: Start the proxy

Run the following command and keep this terminal window open:

```azurecli
az connectedk8s proxy --name <cluster-name> --resource-group <resource-group>
```

You see output similar to:

```output
Proxy is listening on port 47011
Merged "<cluster-name>" as current context in C:\Users\<you>\.kube\config
Start sending kubectl requests on '<cluster-name>' context using kubeconfig at C:\Users\<you>\.kube\config
Press Ctrl+C to close proxy.
```

> [!IMPORTANT]
> Keep this terminal window open. The proxy must stay running while you use kubectl.

### Step 3: Run kubectl in a new terminal

Open a **second terminal window** and run:

```bash
kubectl get nodes
```

Expected output:

```output
NAME               STATUS   ROLES           AGE   VERSION
<cluster-name>     Ready    control-plane   1d    v1.34.2
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `context deadline exceeded` | The proxy isn't running. Restart `az connectedk8s proxy` in the first terminal. |
| `kubectl: command not found` | Run `az aks install-cli`, then close and reopen your terminal. |
| MSI token audience error | Don't use Azure Cloud Shell. Run `az connectedk8s proxy` from your local machine. |
| `unrecognized arguments` | Use double dashes: `--name` and `--resource-group` (not single dash). |

## Next steps

- [Deploy an application](aks-bare-metal-deploy-application.md)
