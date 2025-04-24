---
title: Azure Kubernetes Fleet Manager Automated Deployments 
description: Learn about the concepts behind Fleet Manager Automated Deployments which simplify the process of building and deploying your application from Git.
author: sjwaight
ms.author: simonwaight
ms.topic: conceptual
ms.custom: build-2025
ms.date: 04/22/2025
ms.service: azure-kubernetes-fleet-manager
---

# Azure Kubernetes Fleet Manager Automated Deployments (Preview)

This article provides a conceptual overview of Fleet Manager's Automated Deployments capability. Fleet Manager Automated Deployments simplify the process of taking your application source code from GitHub repository and deploying it across one or more AKS cluster in your fleet. Once configured, every new commit you make runs the pipeline, resulting in updates to your application wherever it is deployed in your fleet.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites

In order to use Fleet Manager's Automated Deployments the following prerequisites must be in place.

* A GitHub account.
* An application to deploy. The application can already be containerized, or Automated Deployments can containerize it based on the contents of the repository.
* An Azure Kubernetes Fleet Manager [with a hub cluster][fleet-deploy-hub] and one or more member AKS cluster.
* A Kubernetes namespace on the Fleet Manager hub cluster.
* An Azure Container Registry (ACR) with [AcrPull rights granted to member AKS cluster][acr-create].

## Core concepts

Fleet Manager Automated Deployments help with the following activities:

* Securely connecting a source GitHub repository to a Fleet hub cluster without the need for an operator to handle credentials. You can connect multiple repositories or branches to a single Fleet Manager.
* Building container images and publishing to an existing Azure Container Registry (ACR) ensuring images are located in a known registry which fleet members can access.
* Staging existing [cluster resource placement (CRP)][concept-crp] manifests into an existing namespace on the Fleet Manager hub cluster so they are ready for placement. Using an existing namespace allows 

You can modify the generated GitHub Action workflow to meet your needs by opening it up in an editor like Visual Studio Code and changing as you see fit.

### Existing resource requirements

In this section we cover why you are required to use an existing Azure Container Registry and Kubernetes Namespace when using Fleet Manager Automated Deployments.

* **Container Registry** - in order to facilitate image pulls from Azure Container Registry, member AKS clusters must be granted `AcrPull` rights on the Registry. On initial configuration, Automated Deployments is unable to determine which member clusters will receive a placement, so it is not possible to automate permission setup for an unknown set of clusters. Additionally, automatically granting all member clusters `AcrPull` rights on a Registry is likely undesirable, so the decision to configure this permission is delegated to the fleet administrative user outside the scope of Automated Deployments.

* **Kubernetes Namespace** - while Fleet Manager's cluster resource placements can be used to deploy cluster-scoped resources we have initially limited Automated Deployments to deploying only namespace-scoped resources. This limit provides fleet administrators with control over where in their fleet a deployment can potentially be placed by ensuring the namespace resides only on clusters they define. This limitation also simplifies the setup of deployments by allowing those configuring Automated Deployments to focus on their application workload instead of Kubernetes constructs.

> [!NOTE]
> During preview we welcome feedback as we continue to work on Fleet Manager Automated Deployments. 
> 
> As an example: We are considering adding the generation of CRP manifests on initial setup, along with automated execution of resource placement. During preview, you can add CRP manifests to your source repository and manually modify the generated GitHub Action to add a stage that invokes the Fleet Manager placement scheduler. 
>
> If you would like to provide feedback and suggestions on any aspect of Fleet Manager Automated Deployments please add them to the [roadmap item for this feature](https://github.com/Azure/AKS/issues/4685). 

## Single cluster support

To deploy to a single AKS cluster you can use [Automated Deployments for AKS][aks-automated-deployments] which does not require Fleet Manager.

## Next steps

Now that you understand the concepts behind, see an end-to-end example showing how you can [use Fleet Manager Automated Deployments to drive multi-cluster resource placement][fleet-autodeploy-howto].

<!-- LINKS -->
[fleet-deploy-hub]: ./concepts-choosing-fleet.md#kubernetes-fleet-resource-with-hub-clusters
[fleet-autodeploy-howto]: ./howto-automated-deployments.md
[concept-crp]: ./concepts-resource-propagation.md
[acr-create]: /azure/aks/cluster-container-registry-integration
[aks-automated-deployments]: /azure/aks/automated-deployments