---
title: Deploy a sample application on AKS on bare metal (preview)
description: Learn how to deploy a containerized application to your Azure Kubernetes Service on bare metal cluster.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Deploy a sample application on AKS on bare metal (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal preview is partially covered by customer support on a best-effort basis.

This article walks you through deploying a sample application to your AKS on bare metal cluster and accessing it.

## Prerequisites

- An AKS on bare metal cluster in a **Succeeded** state
- Connected to the cluster via `az connectedk8s proxy` (see [Connect to your cluster](aks-bare-metal-connect-to-cluster.md))
- `kubectl` installed and configured

## Deploy a sample nginx application
Follow the steps below to deploy a nginx deployment on your AKS on bare metal cluster.

### Step 1: Create the deployment

```bash
kubectl create deployment nginx --image=mcr.microsoft.com/cbl-mariner/base/nginx:1.22
```

### Step 2: Verify the pod is running

```bash
kubectl get pods
```

Wait until the STATUS shows **Running**:

```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-1ab234c5d6-xyz12   1/1     Running   0          30s
```

### Step 3: Expose the deployment as a service

```bash
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Step 4: Find the NodePort

```bash
kubectl get svc nginx
```

Output:

```
NAME    TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.96.45.123   <none>        80:31234/TCP   5s
```

The NodePort in this example is `31234`.

### Step 5: Access the application

From a machine that can reach the bare metal host's network:

```
http://<bare-metal-host-ip>:<nodeport>
```

For example: `http://10.0.0.10:31234`

## Deploy using a YAML manifest

For more complex applications, use a YAML manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
      - name: hello-app
        image: mcr.microsoft.com/cbl-mariner/base/nginx:1.22
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hello-app
spec:
  type: NodePort
  selector:
    app: hello-app
  ports:
  - port: 80
    targetPort: 80
```

Apply the manifest:

```bash
kubectl apply -f hello-app.yaml
```

## Best practices for single-node clusters

Since AKS on bare metal runs a single-node cluster during public preview:

- **Set resource requests and limits**: Prevents workloads from consuming all host resources and starving the control plane
- **Reserve capacity for the control plane**: The Kubernetes control plane requires approximately 2-GB RAM and 1 CPU core
- **Use NodePort for external access**: LoadBalancer type isn't supported during preview
- **Pull images from MCR**: Microsoft Container Registry (`mcr.microsoft.com`) images are guaranteed to be accessible

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Pod stuck in `ErrImagePull` | Verify the host can reach `mcr.microsoft.com`. Check DNS and firewall rules |
| Pod stuck in `Pending` | Check node resources: `kubectl describe node`. Look for CPU or memory pressure |
| Service not accessible | Verify you're using the correct NodePort and host IP. Check firewall allows the port |
| `context deadline exceeded` on kubectl | The `az connectedk8s proxy` isn't running. Restart it in another terminal |

## Clean up

To remove the sample application:

```bash
kubectl delete deployment nginx
kubectl delete svc nginx
```

## Next steps

- [Upgrade your cluster](aks-bare-metal-upgrade-cluster.md)
