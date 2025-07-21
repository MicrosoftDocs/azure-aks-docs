---
title: Deploy and test highly available GitHub Actions on Azure Kubernetes Service (AKS)
description: Learn how to deploy and test highly available GitHub Actions with Azure Files on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/13/2025
author: schaffererin
ms.author: schaffererin
ms.custom: 'stateful-workloads'
---

# Deploy and test highly available GitHub Actions on Azure Kubernetes Service (AKS)

In this article, you learn how to deploy and test highly available GitHub Actions with Azure Files on Azure Kubernetes Service (AKS).

## GitHub Actions sample workflows

The repository has three sample workloads in the default GitHub workflow folder for you to test the self-hosted ARC runners:

* **`dotnet-using-container.yml`**: .NET Build using containers install .NET SDK and restore/build/publish application on the runner itself.
* **`dotnet-without-container.yml`**: .NET Build without containers use workflow container feature to run a .NET SDK container and build inside the application inside the container. NuGet caching is mounted by default on this container.
* **`container-service-test.yml`**: Container and Service Test testing workflows also using containers feature to create an Ubuntu container and a Redis service. Both containers run on the same AKS Pod. NuGet caching is also mounted by default on this container.

All three workflows have an input parameter for the ARC runner name to be used on the `runs-on:` field of your workflow. This is the `ARC_RUNNER_SCALESET_NAME="arc-runner-set"` variable we defined previously. To facilitate testing, we use the `workflow_dispatch:` option on the three workflows to only run those workflows when it's requested manually. On the GitHub Actions tab of your repository, select one of the workflows and run the workload.

Once the workflow is running, it requests a runner to ARC running on the AKS cluster. Once this runner, a pod on Kubernetes, is allocated for the job, the workflow runs in there to completion. We use the ephemeral runner approach, so the pod running the workflow is destroyed at the end and a new one is created for the next workflow run.

## Delete the resources

When you're ready, you can delete all the resources created in this guide using the following commands:

```bash
# Delete ARC runners scale sets 

helm delete "${ARC_RUNNER_SCALESET_NAME}" -n "${NAMESPACE_ARC_RUNNERS}" --wait 

# Delete ARC runners scale set controller 

helm delete "${ARC_CONTROLLER_NAME}" -n "${NAMESPACE_ARC_CONTROLLER}" --wait 

# Delete Azure File share configurations 

kubectl delete -f ./install/arc-runners-set-pv-pvc.yaml --wait 
kubectl delete -f ./install/arc-runners-storage-class-files.yaml --wait 

# Delete secrets 

kubectl delete secret azure-storage-secret -n arc-runners --wait 
kubectl delete secret ${ARC_RUNNER_GITHUB_SECRET_NAME} -n arc-runners --wait 

# Delete container runner configmap pod spec 

kubectl delete -f ./install/arc-runners-set-container-pod-spec.yaml --wait 

# Delete namespaces 

kubectl delete namespace ${NAMESPACE_ARC_RUNNERS} 
kubectl delete namespace ${NAMESPACE_ARC_CONTROLLER} 
```

## Next steps

To learn more about deploying open-source software on Azure Kubernetes Service (AKS), see the following article:

* [Deploy stateful workloads on Azure Kubernetes Service (AKS)](./stateful-workloads-overview.md)

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Jorge Arterio | Senior Cloud Advocate
* Jeff Patterson | Principal Product Manager
* Rena Shah | Senior Product Manager
* Shekhar Singh Sorot | Product Manager 2
* Erin Schaffer | Content Developer 2
