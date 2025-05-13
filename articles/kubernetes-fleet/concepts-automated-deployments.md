---
title: Azure Kubernetes Fleet Manager Automated Deployments conceptual overview
description: Learn about the concepts behind Fleet Manager Automated Deployments which simplify the process of building and deploying your application from Git.
author: sjwaight
ms.author: simonwaight
ms.topic: conceptual
ms.custom: build-2025
ms.date: 04/22/2025
ms.service: azure-kubernetes-fleet-manager
---

# Azure Kubernetes Fleet Manager Automated Deployments (Preview)

This article provides a conceptual overview of Fleet Manager's Automated Deployments capability. Fleet Manager Automated Deployments simplify the process of taking your application source code from a GitHub repository and deploying it across one or more AKS cluster in your fleet. Once configured, every new commit you make runs the pipeline, resulting in updates to your application wherever it's deployed in your fleet.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites

To use Fleet Manager Automated Deployments the following prerequisites must be in place.

* A GitHub account.
* An application to deploy. The application can already be containerized, or Automated Deployments can containerize it based on the contents of the repository.
* An Azure Kubernetes Fleet Manager [with a hub cluster][fleet-deploy-hub] and one or more member AKS cluster.
* A Kubernetes namespace on the Fleet Manager hub cluster.
* An Azure Container Registry (ACR) with [AcrPull rights granted to member AKS clusters][acr-create].

## Core concepts

Fleet Manager Automated Deployments help with the following activities:

* Securely connecting a source GitHub repository to a Fleet hub cluster without the need for an operator to handle credentials. You can connect multiple repositories or branches to a single Fleet Manager.
* Building container images and publishing to an existing Azure Container Registry (ACR) ensuring images are located in a known registry which fleet members can access.
* Staging resource manifests into an existing namespace on the Fleet Manager hub cluster so they're ready for [cluster resource placement (CRP)][concept-crp]. 

The generated GitHub Actions workflow can be modified to meet your needs by using an editor like Visual Studio Code.

### Existing resource requirements

These resources must already exist and be configured when using Fleet Manager Automated Deployments.

* **Container Registry** - in order to facilitate image pulls from Azure Container Registry, member AKS clusters must be granted `AcrPull` rights on the Registry. On initial configuration, Automated Deployments is unable to determine which member clusters might receive a placement, so it's not possible to automate permission setup for an unknown set of clusters. Granting all member clusters `AcrPull` rights on a Registry is likely undesirable, so the decision to configure this permission on clusters is delegated to an authorized user outside the scope of Automated Deployments.

* **Kubernetes Namespace** - while Fleet Manager's cluster resource placements can be used to deploy cluster-scoped resources we have limited Automated Deployments to deploying only namespace-scoped resources. This limitation simplifies the setup of deployments by focusing on application workloads in a namespace instead of broader Kubernetes constructs.

> [!NOTE]
> We welcome feedback as we continue to work on Fleet Manager Automated Deployments. 
> 
> As an example: We're considering adding further steps to generate a CRP on initial setup, along with automated execution of the CRP. Today you can add a CRP to your source repository and manually modify the generated GitHub Action to add a stage that applies the placement. 
>
> If you would like to provide feedback and suggestions on any aspect of Fleet Manager Automated Deployments add them to the [roadmap item for this feature](https://github.com/Azure/AKS/issues/4685). 

## GitHub OAuth application

Once you grant Automated Deployments access to your GitHub repository you will find a new application in your GitHub `Authorized OAuth Apps` list named `AKS Developer Hub`. This is the same application as used by the AKS Automated Deployments capability.

## Single cluster support

To deploy to a single AKS cluster, you can use [Automated Deployments for AKS][aks-automated-deployments] which doesn't require Fleet Manager.

## Next steps

Now that you understand the Fleet Manager Automated Deployments concepts, see an end-to-end example showing how you can [use Fleet Manager Automated Deployments to drive multi-cluster resource placement][fleet-autodeploy-howto].

<!-- LINKS -->
[fleet-deploy-hub]: ./concepts-choosing-fleet.md#kubernetes-fleet-resource-with-hub-clusters
[fleet-autodeploy-howto]: ./howto-automated-deployments.md
[concept-crp]: ./concepts-resource-propagation.md
[acr-create]: /azure/aks/cluster-container-registry-integration
[aks-automated-deployments]: /azure/aks/automated-deployments