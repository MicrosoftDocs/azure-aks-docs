---
title: Troubleshoot BGP with FRR in AKS environments
description: Learn how to troubleshoot BGP connectivity issues when using MetalLB with FRR in AKS deployments.
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.topic: troubleshooting
ms.reviewer: srikantsarwa
ms.lastreviewed: 06/19/2025
ms.custom: hyperconverged

---

# BGP with FRR not working in AKS environment

This article helps you identify and resolve Border Gateway Protocol (BGP) connectivity issues when using MetalLB with Free Range Routing (FRR) in Azure Kubernetes Service (AKS) Arc environments.

Use this guidance when BGP sessions fail to establish, external IP routing doesn't work correctly, or network connectivity to exposed services becomes unreliable in your AKS deployment.

## Symptoms

In environments using MetalLB with FRR for BGP peering, you might experience the following issues:

- BGP sessions are not established or keep flapping, a condition where the BGP session repeatedly goes up and down, causing route instability. This behavior can be due to network issues, misconfigurations, or hardware problems. It can result in degraded performance or loss of service availability.
- Services of type `LoadBalancer` don't receive properly routed external IPs.
- Advertised routes are missing or not propagated to upstream routers.
- Network connectivity to exposed services is inconsistent or unavailable.

These symptoms are often observed in specific hardware environments such as Hyper-Converged Infrastructure (HCI) or where strict network/security policies are enforced.

## Mitigation

If you encounter these issues with FRR, you can temporarily disable it using Azure CLI:

```azurecli
# Retrieve the object ID for the managed identity
$objID = az ad sp list --filter "appId eq '087fca6e-4606-4d41-b3f6-5ebdf75b8b4c'" --query "[].id" --output tsv

# Update the arcnetworking extension to disable FRR
az k8s-extension update \
  --cluster-name $clusterName \
  -g $rgName \
  --cluster-type connectedClusters \
  --extension-type microsoft.arcnetworking \
  --config "k8sRuntimeFpaObjectId=$objID" \
  --config "metallb.speaker.frr.enabled=false" \
  -n arcnetworking
```

## Troubleshooting steps

Use the following steps to diagnose and resolve BGP issues with MetalLB and FRR in your AKS environment.

### Check BGP configuration

```azurecli
kubectl get ipaddresspools -A -o yaml
kubectl get bgppeers.metallb.io -A -o yaml
kubectl get bgpadvertisements -A -o yaml
```

### Collect logs from MetalLB speaker (FRR)

```azurecli
# Get the list of MetalLB speaker pods
kubectl get pods -n kube-system

# Speaker container logs
kubectl logs -n kube-system arcnetworking-metallb-speaker-xxxxx -c speaker

# FRR container logs
kubectl logs -n kube-system arcnetworking-metallb-speaker-xxxxx -c frr
```

### Review TOR switch configuration

- Configuration and logs from the top-of-rack (TOR) switch or upstream router might be necessary.
- These logs are hardware/vendor-specific and not covered in this guide.

## Next steps

[Official MetalLB troubleshooting guide](https://metallb.universe.tf/troubleshooting/#with-frr)

