---
title: Deploy CanIPull to an Azure Kubernetes Service (AKS) cluster
description: Learn how to deploy CanIPull to an AKS cluster and verify whether a node can authenticate to Azure Container Registry.
ms.topic: how-to
ms.date: 08/26/2026
ms.service: azure-kubernetes-service
ms.custom: aeo-round-2
author: schaffererin
ms.author: schaffererin
---

# Deploy CanIPull to an Azure Kubernetes Service (AKS) cluster

[CanIPull][canipull-github] is a diagnostic tool for Azure Kubernetes Service (AKS). It checks whether a cluster node can resolve and authenticate to Azure Container Registry (ACR). To perform the check, CanIPull reads the cluster identity configuration from the selected node and validates that the identity can exchange a token with ACR. It doesn't pull an image or validate access to a specific repository.

This article shows you how to run CanIPull by using Azure Copilot or a Kubernetes manifest. CanIPull `v0.1.0` runs on one AMD64 Linux node at a time. Repeat the check on other supported nodes to compare their connectivity or configuration.

## Prerequisites

Before you begin, you need:

- An existing AKS cluster with at least one AMD64 Linux node.
- An existing ACR instance that you want to test.

To deploy CanIPull with Azure Copilot, you also need access to [Azure Copilot in the Azure portal][azure-copilot-overview].

To deploy CanIPull manually, you also need:

- [Azure CLI][install-azure-cli] installed.
- An authenticated Azure CLI session with permissions to get user credentials for the AKS cluster and read the ACR instance.
- [`kubectl` configured to connect to your AKS cluster][aks-get-credentials].
- Kubernetes permissions to list nodes at cluster scope; create, get, list, watch, and delete pods in the `default` namespace; and get pod logs in the `default` namespace.

## Deploy CanIPull with Azure Copilot

Azure Copilot can select the AKS cluster, AMD64 Linux node, and ACR login server and then deploy CanIPull for you. The diagnostic checks DNS resolution and ACR token exchange from the selected node. It doesn't select or access a repository or image.

1. In the Azure portal, open **Copilot**.
1. Enter one of the following prompts:

   - `Help me deploy CanIPull to my AKS cluster.`
  - `Can an AMD64 Linux node in my AKS cluster resolve and authenticate to a specific Azure Container Registry?`
  - `Help me test ACR token exchange from an AMD64 Linux node in my AKS cluster.`

1. Select the AKS cluster and the AMD64 Linux node where you want CanIPull to run.
1. Select the ACR instance whose login server you want to use for the DNS and token exchange checks.
1. Review the selections, and then confirm the deployment.
1. After the deployment completes, follow the prompt to open the **Run command** pane.
1. Review the CanIPull logs for DNS, cluster identity, and ACR token exchange results.

For more information about this experience, see [Use CanIPull with Azure Copilot][copilot-canipull].

## Deploy CanIPull manually

Use a one-shot Kubernetes pod when you want to choose the target node and inspect the CanIPull logs directly with `kubectl`.

> [!IMPORTANT]
> The manifest mounts `/etc/kubernetes/azure.json` from the selected node. This file contains sensitive cluster identity configuration. Deploy the pod only if you're a trusted cluster administrator. Don't increase the CanIPull verbosity because higher levels can print access tokens. Delete the pod as soon as you finish the test.

### Connect to the cluster and select a node

1. Set variables for the AKS cluster and ACR instance.

   ```azurecli-interactive
   RESOURCE_GROUP=<resource-group>
   CLUSTER_NAME=<aks-cluster-name>
   ACR_NAME=<acr-name>
   ```

1. Get the cluster credentials.

   ```azurecli-interactive
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $CLUSTER_NAME
   ```

1. Get the ACR login server. CanIPull expects the fully qualified login server, such as `myregistry.azurecr.io`, rather than the ACR resource name.

   ```azurecli-interactive
   ACR_LOGIN_SERVER=$(az acr show \
     --name $ACR_NAME \
     --query loginServer \
     --output tsv)

   echo $ACR_LOGIN_SERVER
   ```

1. List the AMD64 Linux nodes and choose the node where you want to run the diagnostic check. CanIPull `v0.1.0` supports only AMD64 nodes.

   ```bash
   kubectl get nodes \
     --selector kubernetes.io/os=linux,kubernetes.io/arch=amd64 \
     --output wide
   ```

### Create the CanIPull pod

1. Create a file named `canipull.yaml` with the following manifest. Replace `<target-linux-node>` and `<acr-login-server>` with the node name and ACR login server from the previous section.

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: canipull
     namespace: default
     labels:
       app: canipull
   spec:
     automountServiceAccountToken: false
     nodeName: <target-linux-node>
     restartPolicy: Never
     containers:
       - name: canipull
         image: mcr.microsoft.com/aks/canipull:v0.1.0
         imagePullPolicy: IfNotPresent
         args:
           - <acr-login-server>
         securityContext:
           allowPrivilegeEscalation: false
           capabilities:
             drop:
               - ALL
           readOnlyRootFilesystem: true
         volumeMounts:
           - name: azure-config
             mountPath: /etc/kubernetes/azure.json
             readOnly: true
     volumes:
       - name: azure-config
         hostPath:
           path: /etc/kubernetes/azure.json
           type: File
   ```

1. Create the pod.

   ```bash
   kubectl apply --filename canipull.yaml
   ```

1. Wait for the pod to finish.

   ```bash
   kubectl get pod canipull --watch
   ```

   Press <kbd>Ctrl</kbd>+<kbd>C</kbd> when the pod status changes to `Completed` or `Error`.

## Review the CanIPull results

View the diagnostic output.

```bash
kubectl logs canipull
```

A successful test includes the following results:

- The ACR authentication server resolves through DNS.
- CanIPull reads the Azure configuration from the node.
- The cluster's kubelet identity or service principal can authenticate.
- ACR accepts the initial token exchange.

These results confirm only that the selected node can resolve the ACR authentication server and that the cluster identity can complete the initial token exchange. CanIPull doesn't pull an image or validate access to a repository, image manifest, or image layer.

The tool's final success message uses broader wording than the scope of the test and resembles the following output:

```output
Your cluster can pull images from <acr-login-server>!
```

To verify an end-to-end image pull, deploy a workload that references an image in the target repository.

If the test fails, review the log line marked `FAILED`. Common causes include:

- The ACR authentication server doesn't resolve from the selected node.
- The selected node doesn't contain `/etc/kubernetes/azure.json`.
- The cluster identity credentials aren't valid.
- ACR rejects the token exchange for the kubelet identity or service principal.

If the token exchange fails because the identity isn't authorized to access ACR, see [Authenticate with ACR from AKS][cluster-container-registry-integration].

## Clean up resources

Delete the CanIPull pod and remove its access to the node configuration.

```bash
kubectl delete pod canipull
```

## Related content

- [AKS CanIPull GitHub repository][canipull-github]
- [Work with AKS clusters efficiently using Azure Copilot][copilot-aks]
- [Authenticate with ACR from AKS][cluster-container-registry-integration]

<!-- LINKS -->
[aks-get-credentials]: learn/quick-kubernetes-deploy-cli.md#connect-to-the-cluster
[azure-copilot-overview]: /azure/copilot/overview
[canipull-github]: https://github.com/Azure/aks-canipull
[cluster-container-registry-integration]: cluster-container-registry-integration.md
[copilot-aks]: /azure/copilot/work-aks-clusters
[copilot-canipull]: /azure/copilot/work-aks-clusters#deploy-aks-canipull-and-troubleshoot-image-pull-issues
[install-azure-cli]: /cli/azure/install-azure-cli
