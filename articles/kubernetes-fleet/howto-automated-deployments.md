---
title: Use Azure Kubernetes Fleet Manager Automated Deployments to drive multi-cluster resource placement
description: Learn how to use Azure Kubernetes Fleet Manager Automated Deployments to build and deploy an application across multiple clusters.
author: sjwaight
ms.author: simonwaight
ms.topic: how-to
ms.custom: build-2025
ms.date: 06/12/2025
ms.service: azure-kubernetes-fleet-manager
---

# Use Azure Kubernetes Fleet Manager Automated Deployments to drive multi-cluster resource placement (Preview)

Azure Kubernetes Fleet Manager Automated Deployments can be used to build and deploy an application from a code repository to one or more AKS cluster in a fleet. Automated deployments simplify the process of setting up a GitHub Action workflow to build and deploy your code. Once connected, every new commit you make runs the pipeline. 

Automated Deployments build on [draft.sh](https://draft.sh). When you create a new deployment workflow, you can use an existing Dockerfile, generate a Dockerfile, use existing Kubernetes manifests, or generate Kubernetes manifests. The generated manifests are created with security and resiliency best practices in mind.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites

* A GitHub account with the application to deploy.
* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the conceptual overviews of [Automated Deployments](./concepts-automated-deployments.md) and [resource propagation](./concepts-resource-propagation.md) to understand the concepts and terminology used in this article.
* A Kubernetes Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* The user completing the configuration has permissions to the Fleet Manager hub cluster Kubernetes API. For more information, see [Access the Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md) for more details.
* A Kubernetes namespace already deployed on the Fleet Manager hub cluster.
* An Azure Container Registry (ACR) with [AcrPull rights granted to member AKS clusters][acr-create].

## Bring your application source code

Find your Azure Kubernetes Fleet Manager and start Automated Deployments configuration.

1. In the [Azure portal][azure-portal], search for **Kubernetes Fleet Manager** in the top search bar.
1. Select [**Kubernetes fleet manager**][portal-fleets] in the search results.
1. Select your Azure Kubernetes Fleet Manager from the resource list. 
1. From the Fleet Manager service menu, under **Fleet resources**, select **Automated deployments**.
1. Select **+ Create** in the top menu. If this deployment is your first, you can also select **Create** in the deployment list area.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-create.png" alt-text="Screenshot showing create options for Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-create.png" :::

### Connect to source code repository

Create a workflow and authorize it to connect to the desired source code repository and branch. Complete the following details on the **Repository** tab.

1. Enter a meaningful name for the workflow in the  **Workflow name** field.
1. Next, select **Authorize access** to authorize a user against GitHub to obtain a list of repositories. 
1. For **Repository source** select either:
    1. **My repositories** for repositories the currently authorized GitHub user owns, or;
    1. **All repositories** for repositories the currently authorized GitHub user can access. You need to select the **Organization** which owns the repository.
1. Choose the **Repository** and **Branch**.
1. Select the **Next** button.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-repository.png" alt-text="Screenshot showing selection of source control repository when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-repository.png" :::

### Specify application image and deployment configuration

To prepare an application to run on Kubernetes, you need to build it into a container image which you store in a container registry. A [Dockerfile](https://docs.docker.com/build/concepts/dockerfile/) provides instructions on how to build the container image. If your source code repository doesn't already have a Dockerfile, Automated Deployments can generate one for you.

#### [Use existing Dockerfile](#tab/use-existing-dockerfile)

If your code repository already has a Dockerfile, you can use it to build the application image.

1. Select **Existing Dockerfile** for the **Container configuration**.
1. Select the **Dockerfile** from your repository.
1. Enter the **Dockerfile build context** to pass the set of files and directories to the build process (typically the same folder as the Dockerfile). These files are used to build the image, and they're included in the final image, unless they're ignored through inclusion in a `.dockerignore` file.
1. Select an existing **Azure Container Registry**. This registry is used to store the built application image. Any AKS cluster that can receive the application must be given `AcrPull` permissions on the Registry.
1. Set the **Azure Container Registry image** name. You must use this image name in your Kubernetes deployment manifests.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-existing-dockerfile.png" alt-text="Screenshot showing selection of an existing Dockerfile when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-existing-dockerfile.png" :::

#### [Generate a Dockerfile](#tab/generate-dockerfile)

Use Fleet Manager Automated Deployments to generate a Dockerfile for many languages and frameworks such as Go, C#, Node.js, Python, Java, Gradle, Clojure, PHP, Ruby, Erlang, Swift, and Rust. The language support is built on what's available in [draft.sh](https://draft.sh).

1. Select **Auto-containerize (generate Dockerfile)** for the container configuration.
1. Set the **Save files in repository** location to a folder in the source repository.
1. Choose the **Application environment** from the list of supported languages and frameworks.
1. Enter the **Application port**.
1. Select an existing **Azure Container Registry**. This registry is used to store the built application image. Any AKS cluster that can receive the application must be given `AcrPull` permissions on the Registry.
1. Set the **Azure Container Registry image** name. You must use this image name in your Kubernetes deployment manifests.
1. Review the generated `Dockerfile` and `.dockerignore` files.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-create-dockerfile.png" alt-text="Screenshot showing creating a Dockerfile when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-create-dockerfile.png" :::

---

### Choose the Kubernetes manifest configuration

An application running on Kubernetes consists of many Kubernetes primitive components. These components describe what container image to use, how many replicas to run, if there's a public IP required to expose the application, etc. For more information, see the official [Kubernetes documentation][kubernetes-documentation]. If your source code repository doesn't already have Kubernetes manifests, Automated Deployments can generate them for you. You can also choose an existing Helm chart.

> [!WARNING]
> Don't choose the `fleet-system` or any of the `fleet-member` namespaces as these are internal namespaces used by Fleet Manager and can't be used to place your application. 

#### [Use existing Kubernetes manifests](#tab/existing-kubernetes-manifests)

If your code repository already has a Kubernetes manifest, you can select it to control what workload is deployed and configured by a cluster resource placement.

1. Select **Use existing Kubernetes manifest deployment files** for the deployment options.
1. Select the **Kubernetes manifest file or folder** from your repository.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Select the **Next** button.


:::image type="content" source="media/automated-deployments/fleet-auto-deploy-existing-manifest.png" alt-text="Screenshot showing selection of an existing Kubernetes manifest when setting up Fleet Manager Automated Deployments." lightbox="media/automated-deployments/fleet-auto-deploy-existing-manifest.png" :::

#### [Generate Kubernetes manifests](#tab/generate-kubernetes-manifests)

Use Fleet Manager Automated Deployments to generate a set of basic Kubernetes manifest files to get your application up and running. Currently, Automated Deployments creates a `Deployment`, a `Service`, and a `ConfigMap`.

The generated manifests are designed to apply recommendations of [deployment safeguards][deployment-safeguards], such as:

- Automatically generating [liveness, readiness, and startup probes][kubernetes-probes].
- Preferring [pod anti-affinity][pod-anti-affinity] and [topology spread constraints][topology-spread-constraints] that spread replicas onto different nodes for improved resiliency.
- Enforcing the `RuntimeDefault` [secure computing profile][seccomp-profile] which establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors.
- Dropping all Linux capabilities and only allowing a limited set following the baseline [Kubernetes Pod Security Standards][kubernetes-pod-security-standards].

To generate Kubernetes manifests:

1. Select **Generate application deployment files** for the deployment options.
1. Enter the **Application port**. This port is used on the generated `Service`.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Set the **Save files in repository** location to a folder in the source repository.
1. Select the **Next** button.

#### [Use existing Helm chart](#tab/existing-helm-chart)

If your code repository already has a Helm chart, you can select it to build the application image.

1. Select **Use existing Helm chart** for the deployment options.
1. Select the **Charts path** folder from your repository.
1. Select the **Values.yaml** file path from your repository.
1. Optionally, provide **Helm chart overrides**.
1. Select the existing Fleet Manager **Namespace** to stage the workload in. 
1. Select the **Next** button.

---

## Review configuration

Review the configuration for the repository, image, and deployment configuration. 

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-review.png" alt-text="Screenshot showing the configuration of an Automated Deployment so it can be reviewed before being submitted." lightbox="media/automated-deployments/fleet-auto-deploy-review.png" :::

Select **Next** to start the process which performs these actions:

1. Create federated credentials to allow the GitHub Action to:
    1. Push the built container image to the Azure Container Registry.
    1. Stage the Kubernetes manifests into the selected namespace on the Fleet Manager hub cluster.
1. Create a pull request on the code repository with any generated files and the workflow.

Setup takes a few minutes, so don't navigate away from the Deploy page.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-run.png" alt-text="Screenshot showing Automated Deployment configuration completed with a button to approve the pull request." lightbox="media/automated-deployments/fleet-auto-deploy-run.png" :::

### Review and merge pull request

When the Deploy stage finishes, select the **Approve pull request** button to open the generated pull request on your code repository.

> [!NOTE]
> There's a known issue with the naming of the generated pull request where it says it's deploying to AKS. Despite this incorrect name, the resulting workflow does stage your workload on the Fleet Manager hub cluster in the namespace you selected. 

 :::image type="content" source="media/automated-deployments/fleet-auto-deploy-merge-pr.png" alt-text="Screenshot of pull request on GitHub." lightbox="media/automated-deployments/fleet-auto-deploy-merge-pr.png" :::

1. Review the changes under **Files changed** and make any desired edits.
1. Select **Merge pull request** to merge the changes into your code repository.

Merging the change runs the GitHub Actions workflow that builds your application into a container image and stores it in the selected Azure Container Registry.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-github-action.png" alt-text="Screenshot showing GitHub Actions workflow in progress." lightbox="media/automated-deployments/fleet-auto-deploy-github-action.png" :::

### Check the generated resources

After the pipeline is completed, you can review the created container image on the Azure portal by locating the Azure Container Registry instance you configured and opening the image repository.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-check-registry-image.png" alt-text="Screenshot of the built container image hosted in an Azure Container Registry repository." lightbox="media/automated-deployments/fleet-auto-deploy-check-registry-image.png" :::

You can also view the Fleet Manager Automated Deployment configuration. Selecting the `workflow` name opens GitHub on the GitHub Action.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-check-deployments.png" alt-text="Screenshot of the configured Fleet Manager Automated Deployment, including a link to the GitHub Action." lightbox="media/automated-deployments/fleet-auto-deploy-check-deployments.png" :::

Finally, you can confirm the expected Kubernetes resources are staged on the Fleet Manager hub cluster.

```azurecli-interactive
az fleet get-credentials \
    --resource-group ${GROUP} \
    --name ${FLEET}
```

```bash
kubectl describe deployments virtual-worker --namespace=contoso-store
```

Output looks similar to the below. The replicas of 0 is expected as workloads aren't scheduled on the Fleet Manager hub cluster. Make sure that the `Image` property points at the built image in your Azure Container Registry.

```output
Name:                   virtual-worker
Namespace:              contoso-store
CreationTimestamp:      Thu, 24 Apr 2025 01:56:49 +0000
Labels:                 workflow=actions.github.com-k8s-deploy
                        workflowFriendlyName=contoso-store-deploy
Annotations:            <none>
Selector:               app=virtual-worker
Replicas:               1 desired | 0 updated | 0 total | 0 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=virtual-worker
  Containers:
   virtual-worker:
    Image:      contoso03.azurecr.io/virtual-worker:latest
    Port:       <none>
    Host Port:  <none>
    Limits:
      cpu:     2m
      memory:  20Mi
    Requests:
      cpu:     1m
      memory:  1Mi
    Environment:
      MAKELINE_SERVICE_URL:  http://makeline-service:3001
      ORDERS_PER_HOUR:       100
    Mounts:                  <none>
  Volumes:                   <none>
  Node-Selectors:            kubernetes.io/os=linux
  Tolerations:               <none>
Events:                      <none>
```

## Define cluster resource placement

During preview, to configure placement of your staged workload on to member clusters you can follow these steps.

1. In the source code repository for your application, create a folder in the repository root called **fleet**.

1. Create a new file `deploy-contoso-ns-two-regions.yaml` in the **fleet** folder and add the contents shown. This sample deploys the `contoso-store` namespace across two clusters that must be in two different Azure regions. 

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: distribute-virtual-worker-two-regions
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1          
          name: contoso-store
      policy:
        placementType: PickN
        numberOfClusters: 2
        topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: region
          whenUnsatisfiable: DoNotSchedule
    ```

1. Modify the GitHub Action workflow file, adding a reference to the CRP file.

    ```yml
    DEPLOYMENT_MANIFEST_PATH: |
      ./virtual-worker.yaml
      ./fleet/deploy-contoso-ns-two-regions.yaml
    ```

1. Commit the new CRP manifest and updated GitHub Action workflow file.

1. Check the workload is placed according to the policy defined in the CRP definition. You check either using the Azure portal or `kubectl` at the command line.

:::image type="content" source="media/automated-deployments/fleet-auto-deploy-check-placement.png" alt-text="Screenshot of the Fleet Manager Resource Placements showing a successfully completed placement." lightbox="media/automated-deployments/fleet-auto-deploy-check-placement.png" :::


## Next steps

 * [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
 * [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

[azure-portal]: https://portal.azure.com
[portal-fleets]: https://portal.azure.com/#browse/Microsoft.ContainerService%2Ffleets
[kubernetes-documentation]: https://kubernetes.io/docs/concepts/workloads/
[deployment-safeguards]: /azure/aks/deployment-safeguards
[seccomp-profile]: /azure/aks/secure-container-access#secure-computing-seccomp
[kubernetes-probes]: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
[kubernetes-pod-security-standards]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[pod-anti-affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
[topology-spread-constraints]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
[acr-create]: /azure/aks/cluster-container-registry-integration