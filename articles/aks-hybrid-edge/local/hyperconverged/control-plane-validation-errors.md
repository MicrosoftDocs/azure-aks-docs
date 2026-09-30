---
title: Control plane configuration validation errors
description: Learn details about each control plane configuration validation error.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: troubleshooting
ms.date: 09/01/2026
ms.custom: hyperconverged

---

# Control plane configuration validation errors

This article describes how to identify and resolve [ControlPlaneConfigurationValidation](configure-ssh-keys.md) error codes that can occur when you create and deploy an AKS cluster on Azure Local.

## Symptoms

When you try to create an AKS cluster, you receive an error message that appears as follows:

```json
admission webhook "vhybridakscluster.kb.io" denied the request: { 
   "result": "Failed", 
   "validationChecks": [ 
      { 
         "name": "ControlPlaneConfigurationValidation", 
         "message": "ControlPlane: Global LinuxProfile SSH public keys should be valid and non-empty. ssh: no key found", 
         "recommendation": "Please check https://aka.ms/AKSArcValidationErrors/ControlPlaneConfigurationValidation for recommendations" 
      } 
   ] 
}
```

The following section describes the error messages that you might see when you encounter the **ControlPlaneConfigurationValidation** error code.

## Global LinuxProfile SSH public keys must be valid and non-empty

If you don't provide valid SSH key information during Kubernetes cluster creation and no SSH key exists, you receive error messages similar to the following:

- An RSA key file or key value must be supplied to SSH Key Value.
- Control Plane: Missing Security Keys in Cluster Configuration.
- LinuxProfile SSH public keys should be valid and non-empty.
- Global LinuxProfile SSH public keys should be valid and non-empty.

To mitigate the issue, see [Generate and store SSH keys with the Azure CLI](/azure/virtual-machines/ssh-keys-azure-cli#generate-new-keys) to create the SSH keys. Then, see [Create Kubernetes clusters](../aks-create-clusters-cli.md) for the interface you're using. If you're using the REST API, see [provisioned cluster instances](/rest/api/hybridcontainer/provisioned-cluster-instances) to create the provisioned cluster instance.

## Control plane count and VM size

In Kubernetes, control plane nodes manage and orchestrate the cluster. They run key components such as API Server, etcd, scheduler, etc. Control plane nodes maintain cluster state, schedule workloads, and ensure high availability, often using multiple nodes for redundancy.

To successfully create an AKS cluster, you must specify at least one control plane node count. Also, to maintain etcd quorum, the control plane node count should be an odd number. For more information about supported count and VM SKU options, see [Scale requirements for AKS on Azure Local](scale-requirements.md#support-count-for-aks-on-azure-local).

## Next steps

[Troubleshoot issues in AKS Hybrid and Edge](aks-troubleshoot.md)
