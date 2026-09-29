---
title: Deploy metrics server on an AKS Edge Essentials cluster
description: Learn about the steps to deploy a metrics server on an AKS Edge Essentials cluster.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Metrics server on an AKS Edge Essentials cluster

The [metrics server](https://github.com/kubernetes-sigs/metrics-server) is a tool that inspects your containers' resource consumption. You can find the [YAML file](https://github.com/Azure/AKS-Edge/blob/main/samples/others/metrics-server.yaml) for the metrics server deployment in the **/Samples/Other** folder [in the GitHub repo](https://github.com/Azure/AKS-Edge/).

## Deploy metrics server

> [!NOTE]
> AKS Edge Essentials K8s does not support [Kubernetes TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/). To deploy the metrics server using K8s, be sure to include `--kubelet-insecure-tls` in your deployment YAML.

### Step 1: deploy the metrics server manifest

```powershell
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/others/metrics-server.yaml
```

Wait for the metrics server pods to reach the **running** status. It might take a few minutes.

```powershell
kubectl get pods -A --watch
```

:::image type="content" source="../media/aks-edge/metrics-pod-running.png" alt-text="Screenshot of results showing metrics pod running." lightbox="../media/aks-edge/metrics-pod-running.png":::

#### Step 2: View your resource consumption

```powershell
kubectl top nodes
```

```powershell
kubectl top pods -A
```

:::image type="content" source="../media/aks-edge/metrics-server-installed.png" alt-text="Screenshot of results showing metrics server installed." lightbox="../media/aks-edge/metrics-server-installed.png":::

If your metrics server fails to display, this could be a known MTU issue in which the Linux VM's MTU doesn't match that of your network. This issue can happen on Azure VMs. Set your MTU parameter to 1300 in your **AksEdgeConfig** file, as follows:

```json
{
    "LinuxVm": {
        "CpuCount": 4,
        "MemoryInMB": 4096,
        "Mtu": 1300
    }
}
```

## Next steps

- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
