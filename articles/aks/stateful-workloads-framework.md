---
title: Kubernetes stateful workloads on Azure overview
description: Learn about running stateful workloads on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 08/05/2024
author: schaffererin
ms.author: schaffererin
---

# Kubernetes stateful workloads on Azure overview

This article provides an overview of running stateful workloads on Azure using the Kubernetes stateful framework.

## What are stateful workloads?

A *stateful workload* is an application that uses persistent data storage to preserve state across multiple instances. In a stateful application, the server monitors each client session and maintains data, such as user preferences or session history, between requests. This configuration allows you to return to the application and continue where you left off. Using a stateful approach can provide considerable efficiency, particularly in scenarios that require high performance, near real-time processing, or stream-based systems.

While stateful workloads offer many benefits, they also present certain challenges. For example, stateful workloads might introduce complex processing patterns that can lead to increased overhead and performance costs. It's important that you understand and consider the specific needs of your application to help determine the right balance between statefulness and statelessness.

## Kubernetes stateful framework foundation stack

The Kubernetes stateful framework begins with a common foundation stack. In this case, we use the *KATE* (Kubernetes, ArgoCD, Terraform, and External Secrets Operator) stack, a popular, standardized stack used for many infrastructure projects. The *KATE* stack uses the following open-source tools:

* [Kubernetes][kubernetes]
* [ArgoCD][argo-cd]
* [Terraform][terraform]
* [External Secrets Operator][external-secrets-operator]

:::image type="content" source="./media/valkey-stateful-workload/kate-stack.png" alt-text="Screenshot of the KATE stack.":::

## Kubernetes stateful framework for Azure

With the foundation stack established, we now need to enhance the framework to support stateful workloads on Azure, specifically by integrating the essential resources for running data infrastructure on [Azure Kubernetes Service (AKS)][what-is-aks].

Supporting complex stateful workloads, such as databases or message queues, requires storage capabilities that exceed ephemeral options. Specifically, we need systems that offer increased resilience and availability to address various events, such as application failures or workload reassignments to different hosts. We can achieve this using the [*PersistentVolume subsystem*][persistent-volumes], which comprises three interconnected Kubernetes resources: *PersistentVolumes*, *PersistentVolumeClaims*, and *StorageClasses*. This subsystem provides an API for users and administrators to abstract the details of how storage is provided from how the storage is consumed.

Most stateful workloads need data from secrets, such as connection strings, usernames, passwords, and certificates. [Azure Key Vault][azure-key-vault] provides a secure store for secrets that we use to hold the necessary stateful frameworks secrets.

We also need a Kubernetes Controller or Kubernetes Operator, like the [Secrets Store CSI Driver][secrets-store-csi-driver] and the [External Secrets Operator][external-secrets-operator], to synchronize secret store secrets as Kubernetes Secrets.

:::image type="content" source="./media/valkey-stateful-workload/stateful-foundation-stack.png" alt-text="Screenshot of the Kubernetes stateful foundation stack for Azure.":::

## Next steps

The following article provides an overview of how to deploy a stateful workload on Azure using the Kubernetes stateful framework and Valkey:

> [!div class="nextstepaction"]
> [Valkey stateful workload overview][valkey-overview]

<!-- External links -->
[kubernetes]: https://kubernetes.io/
[argo-cd]: https://argoproj.github.io/cd
[terraform]: https://www.terraform.io/
[external-secrets-operator]: https://external-secrets.io/latest/
[persistent-volumes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
[secrets-store-csi-driver]: https://github.com/kubernetes-sigs/secrets-store-csi-driver

<!-- Internal links -->
[what-is-aks]: ./what-is-aks.md
[azure-key-vault]: /azure/key-vault/general/overview
[valkey-overview]: ./valkey-overview.md
