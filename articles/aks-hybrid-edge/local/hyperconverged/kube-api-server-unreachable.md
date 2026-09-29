---
title: Troubleshoot the "Failed to either reach kube-apiserver or control plane IP of Kubernetes cluster from Arc Resource Bridge IP" error
description: Learn how to troubleshoot the "failed to either reach kube-apiserver or control plane IP of Kubernetes cluster from Arc Resource Bridge IP error" when you try to create and deploy an AKS Hybrid and Edge cluster.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
# Customer intent: As an Azure Kubernetes user, I want to troubleshoot the "failed to either reach kube-apiserver or control plane IP of Kubernetes cluster from Arc Resource Bridge IP error" error code so that I can successfully start or create and deploy an Azure Kubernetes Service Arc cluster.

---

# Troubleshoot the failed to either reach kube-apiserver or control plane IP of Kubernetes cluster from Arc Resource Bridge IP error

This article describes how to identify and resolve the "failed to either reach kube-apiserver or control plane IP of Kubernetes cluster from Arc Resource Bridge IP" error that occurs when you try to create and deploy a Microsoft Azure Kubernetes Service Arc cluster.

## Symptoms

When you try to create an AKS cluster, you receive the following error message:

```output
Failed to either reach kube-apiserver or control plane IP %s:%d of Kubernetes cluster %s from Arc Resource Bridge IP %v. Read aka.ms/aks-arc-kubeapiserver-unreachable for more information.
```

## Possible causes and follow-ups

- Check whether the logical network into which you deployed the AKS cluster is reachable from the [management IP pool](/azure/azure-local/plan/cloud-deployment-network-considerations#management-ip-pool). 
- Check whether the `control plane IP` address of the AKS cluster is reachable from the [management IP pool](/azure/azure-local/plan/cloud-deployment-network-considerations#management-ip-pool). You can find the control plane IP address by running the [`az aksarc show`](/cli/azure/aksarc#az-aksarc-show) command.
- One possible reason for connectivity issues here is if the Arc Resource Bridge is in a different vlan than the logical network in which you created the AKS cluster. If the Arc Resource Bridge is in a different vlan, ensure that cross-vlan communication is enabled.
- Another frequent issue occurs if you have a firewall that isolates the management network from logical networks. Ensure that you opened the required ports so the management network can reach AKS VMs. Review [the network requirements](network-system-requirements.md#network-port-and-cross-vlan-requirements) for more information about required ports.
- Duplicate IPs and IP address collisions are other reasons why the API server might be unreachable. Ensure that you didn't use the IP addresses provided in the management network anywhere else. Likewise, ensure that the control plane IP provided during the AKS cluster creation operation isn't used anywhere else.

## Use the diagnostic checker tool

The diagnostic checker is a PowerShell-based tool that can help identify AKS cluster creation failures due to potential issues in the environment. [Use the diagnostic checker tool](aks-arc-diagnostic-checker.md) to identify some of the common networking issues that can lead to an AKS cluster creation failure due to the API server being unreachable.

## Contact Microsoft Support

If the problem persists, collect the following information before [creating a support request](aks-troubleshoot.md#open-a-support-request). Collect [AKS cluster logs](get-on-demand-logs.md) before creating the support request.

## Next steps

- [Use the diagnostic checker tool to identify common environment issues](aks-arc-diagnostic-checker.md)
- [Review AKS on Azure Local architecture](cluster-architecture.md)
- [Review Azure Local network considerations](/azure/azure-local/plan/cloud-deployment-network-considerations)
- [Review networking prerequisities for AKS on Azure Local](network-system-requirements.md)
