---
title: Use Virtual Nodes v2 in Azure Kubernetes Service (AKS) (preview)
description: Learn how to burst AKS workloads to Azure Container Instances with Virtual Nodes v2.
ms.topic: how-to
ms.date: 08/24/2026
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
author: kevinkrp93
ms.author: kevinthomas
ai-usage: ai-assisted
---

# Use Virtual Nodes v2 in Azure Kubernetes Service (AKS) (preview)

Virtual Nodes v2 is an improved Virtual Nodes stack that extends AKS beyond VM-based nodes by running pods on serverless compute in [Azure
Container Instances](/azure/container-instances/container-instances-overview) (ACI). Workloads burst to ACI in seconds without waiting for new nodes to be provisioned, and you pay only for the compute you use while the pods are running. Virtual Nodes v2
is delivered as an [AKS cluster extension](cluster-extensions.md).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Supported

- Init containers
- Host aliases
- Container lifecycle hooks (`postStart` and `preStop`)
- `kubectl exec` with arguments
- Persistent volumes and PVCs (Azure Files only)
- VNet peering
- NSG-controlled egress
- NAT Gateway for egress
- Confidential containers
- Up to 200 pods per virtual node

## Limitations

The following features aren't supported:

- Windows containers
- DaemonSets
- Port forwarding
- IPv6
- API server authorized IP ranges
- Azure CNI Overlay
- Cilium or NPM as the network policy
- Bring your own (BYO) virtual network
- Multiple extension instances per cluster
- Standby pools

## Resource availability and quota limits

Virtual Nodes v2 is available in all Azure public cloud regions where Azure Container Instances supports VNet SKUs. For more information, see [Resource availability & quota limits for ACI](/azure/container-instances/container-instances-region-availability).

## Prerequisites

- Azure CNI in node-subnet mode
- Calico or none as the network policy
- Workload identity enabled
- At least one node pool with a VM size of 4+ vCPUs and 16+ GiB of memory. Each virtual node reserves about 3 vCPUs and 12 GiB of memory on an AKS node in your cluster, so ensure your nodes have enough resources.
- [k8s-extension](cluster-extensions.md) version 1.8 or higher
- `kubectl` 1.30 or later

Register the ACI resource provider:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerInstance
```
> [!NOTE]
> Run the following command if you encounter an error at any stage of the extension enablement process.
>
> ```azurecli-interactive
> az provider register --namespace Microsoft.KubernetesConfig
> ```

## Enable Virtual Nodes v2

Install the extension:

```azurecli-interactive
az k8s-extension create \
    --name <extension-name> \
    --extension-type Microsoft.virtualnodes \
    --cluster-name <cluster-name> \
    --resource-group <resource-group> \
    --cluster-type managedClusters \
    --configuration-settings replicaCount=1   # specifies number of virtual nodes - optional
```

### Configure extension settings

Create and update operations support the following configuration settings.

| Configuration setting | Description |
| --- | --- |
| `replicaCount` | Number of virtual nodes. |
| `admissionControllerReplicaCount` | Number of admission controller pods. |
| `podAnnotations` | Annotations added to infrastructure pods as a key-value map. |
| `nodeSelector` | Labels that select the AKS nodes that host infrastructure and admission controller pods. |
| `tolerations` | Tolerations applied to infrastructure and admission controller pods. |
| `affinity` | Additional affinity settings merged with the required AKS affinity rules. |
| `zones` | Semicolon-delimited availability zones where pods are deployed. |
| `nodeLabels` | Labels added to virtual nodes as comma-separated `key=value` pairs. |

The allowed `kubernetes.io` labels are:

- `beta.kubernetes.io/arch`
- `beta.kubernetes.io/instance-type`
- `beta.kubernetes.io/os`
- `failure-domain.beta.kubernetes.io/region`
- `failure-domain.beta.kubernetes.io/zone`
- `kubernetes.io/arch`
- `kubernetes.io/hostname`
- `kubernetes.io/os`
- `node.kubernetes.io/instance-type`
- `topology.kubernetes.io/region`
- `topology.kubernetes.io/zone`

Verify the extension:

```azurecli-interactive
az k8s-extension show \
    --name <extension-name> \
    --cluster-type managedClusters \
    --cluster-name <cluster-name> \
    --resource-group <resource-group>
```

Confirm `provisioningState` is `Succeeded`. It can stay `Pending` for a few
minutes.

Verify the extension pods are running in the `vn-system` namespace :

```bash
kubectl get pods --namespace vn-system
```
## Update an extension

```azurecli
az k8s-extension update --name <extension-name> --cluster-name <aks-cluster-name> --resource-group <aks-resource-group> --cluster-type managedClusters
```

> [!NOTE]
> The `--auto-upgrade-mode` parameter supports `none`, `patch`, or `compatible`. To pin a specific extension version by using `--version`, set 
> `--auto-upgrade-mode` to `none`.

## Azure Container Registry access

To pull images from a private Azure Container Registry (ACR), use the extension managed identity or a Kubernetes image pull secret.

### Use the extension managed identity

Grant the `AcrPull` role to the managed identity generated for the extension. This role grants all pods running on the extension's virtual nodes access to pull images from the registry without extra pod configuration. You must have permission to create role assignments on the registry.

Get the principal ID of the extension managed identity:
```azurepowershell
$extensionPrincipalId = az k8s-extension show --name <extension-name> --cluster-name <aks-cluster-name> --resource-group <aks-resource-group> --cluster-type managedClusters --query aksAssignedIdentity.principalId --output tsv
```

Get the resource ID of the container registry:

```azurepowershell
$acrId = az acr show --name <acr-name> --resource-group <acr-resource-group> --query id --output tsv
```

Assign the `AcrPull` role to the extension managed identity at the registry scope:

```azurepowershell
az role assignment create --assignee-object-id $extensionPrincipalId --assignee-principal-type ServicePrincipal --role AcrPull --scope $acrId
```

Wait several minutes for the role assignment to propagate before deploying workloads that pull images from the registry.

### Use an image pull secret

For instructions, see [Kubernetes Pull Secret for ACR Authentication](/azure/container-registry/container-registry-auth-kubernetes).

## Deploy a workload to Virtual Nodes v2

Schedule pods on virtual nodes using the `virtualization: virtualnode2` node
selector and the `virtual-kubelet.io/provider` toleration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
        - name: hello
          image: mcr.microsoft.com/azuredocs/aci-helloworld
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 1Gi
      nodeSelector:
        virtualization: virtualnode2
        kubernetes.io/os: linux
      tolerations:
        - key: virtual-kubelet.io/provider
          operator: Exists
          effect: NoSchedule
```

Save the manifest as `demo.yaml`, and then apply it.
```bash
kubectl apply -f demo.yaml
```

Verify the pods are running.
```bash
kubectl get pods -l app=demo -o wide
```

## Disable Virtual Nodes v2
> [!WARNING]
> When you disable the virtual node extension, the AKS cluster disconnects from the backing Azure Container Instances container groups. To avoid orphaned instances that continue running and incurring charges, delete any workloads running on the virtual node before you disable the extension.

Delete the extension and clean up virtual node resources.
```azurecli-interactive
az k8s-extension delete \
    --name <extension-name> \
    --cluster-name <cluster-name> \
    --resource-group <resource-group> \
    --cluster-type managedClusters
```
```azurecli-interactive
kubectl delete node <virtual-node-name>
```

## Next steps

- [Troubleshoot Virtual Nodes v2 extension](/troubleshoot/azure/azure-container-instances/management/troubleshoot-microsoft-virtualnodes-extension)
- [Azure Container Instances pricing](https://azure.microsoft.com/pricing/details/container-instances/)
