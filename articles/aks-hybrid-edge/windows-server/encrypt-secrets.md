---
title: Encrypt etcd secrets for Azure Kubernetes Service clusters
description: Learn how to encrypt etcd secrets in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: aathipsa
ms.custom: windows-server
# Intent: As an IT Pro, I want to learn about encrypted etcd secrets and how they are used in my AKS deployment. 
# Keyword: etcd secrets AKS Windows Server

---

# Encrypt etcd secrets for Azure Kubernetes Service clusters

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to monitor and troubleshoot the encryption of etcd secrets for Azure Kubernetes Service (AKS) management clusters and workload clusters in AKS on Windows Server.

A *secret* in Kubernetes is an object that contains a small amount of sensitive data, such as passwords and SSH keys. In the Kubernetes API server, secrets are stored in *etcd*, which is a highly available key values store used as the Kubernetes backing store for all cluster data. AKS comes with encryption of etcd secrets and automates the management and rotation of encryption keys.

## Monitor and troubleshoot

To simplify application deployment on Kubernetes clusters, review the [documentation and scripts](https://github.com/microsoft/AKS-Arc-Apps).

- To set up logging using Elasticsearch, Fluent Bit, and Kibana, follow the steps to [install the tools and set up logging](https://github.com/microsoft/AKS-Arc-Apps/tree/main/Logging).
- To use the monitoring tool Prometheus, follow the steps to [install Prometheus in a Kubernetes cluster](https://github.com/microsoft/AKS-Arc-Apps/tree/main/Monitoring#certs-and-keys-monitoring).

> [!NOTE]
> You can find the logs on the control plane node under **/var/log/pods**.

## Next steps

- [Deploy a Linux application on a Kubernetes cluster](./deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](./deploy-windows-application.md)
- [Encrypting secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data)
- [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)
