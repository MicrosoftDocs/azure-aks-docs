---
title: "Deploy OCI artifacts with Azure Kubernetes Fleet Manager and Flux"
description: "Learn how to use Fleet Manager and Flux OCIRepository resources to deploy an OCI artifact across member clusters and override the artifact tag on a selected cluster."
ms.date: 11/03/2026
ms.topic: how-to
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom: devx-track-azurecli, references-regions
ai-usage: ai-assisted
# Customer intent: "As a platform engineer, I want to use GitOps with Fleet Manager to deploy workloads consistently across multiple clusters and tenant namespaces, so that I can standardize delivery while keeping isolation and governance intact."
---

# Deploy OCI artifacts with Azure Kubernetes Fleet Manager and Flux (preview)

**Applies to**: :heavy_check_mark: Fleet Manager with hub cluster

In this article, you deploy the [AKS Store Demo](https://github.com/azure-samples/aks-store-demo) from an OCI artifact across all member clusters in your fleet. You create the application namespace and Flux `OCIRepository` and `Kustomization` resources on the Fleet Manager hub cluster, then distribute them across member clusters by using [Fleet Manager resource placement](./quickstart-resource-propagation.md). You configure the `OCIRepository` and `Kustomization` as suspended on the Fleet Manager hub cluster, and only enable them once distributed to member clusters. This approach demonstrates how to use Fleet Manager resource placement overrides.

:::image type="content" source="./media/howto-gitops-flux-open-container-artifacts/fleet-gitops-flux-artifacts-workflow.png" alt-text="Diagram showing how the Flux and Fleet Manager elements combined to deliver the end-to-end solution to distribute an application defined using an Open Container Artifact." lightbox="./media/howto-gitops-flux-open-container-artifacts/fleet-gitops-flux-artifacts-workflow.png":::

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Before you begin

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* You need a Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).

* You need access to the Kubernetes API of the hub cluster. If you don't have access, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

* Set environment variables for your subscription, Fleet Manager resource, and member cluster that should receive the older artifact tag.

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    ```

* You need Azure CLI installed to complete this article. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* Set the default Azure subscription by using the [`az account set`][az-account-set] command:

    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

[!INCLUDE [pre-configure flux](./includes/gitops-enable-flux-hub.md)]

## Stage resources on Fleet Manager hub cluster

Start by creating the application namespace and staging its resources on the Fleet Manager hub cluster.

* Get the kubeconfig file of the Fleet Manager hub cluster by using the [`az fleet get-credentials`][az-fleet-get-credentials] command.

    ```azurecli-interactive
    az fleet get-credentials \
        --resource-group ${GROUP} \
        --name ${FLEET}
    ```

* Create the application namespace.

    ```bash
    kubectl create namespace aks-store-demo
    ```

* Use Fleet Manager resource placement to distribute the staged namespace across member clusters. Save the following YAML as `crp-aks-store-demo.yaml`:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp-aks-store-demo
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1
          name: aks-store-demo
          selectionScope: NamespaceOnly
      policy:
        placementType: PickAll
      strategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
          maxSurge: 25%
    ```

* Apply the resource placement on the Fleet Manager hub cluster.

    ```bash
    kubectl apply -f crp-aks-store-demo.yaml
    ```

* Authorize the `flux-applier` service account to manage resources in the `aks-store-demo` namespace. Save the following YAML as `apply-service-account.yaml`.

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: flux-applier
      namespace: aks-store-demo
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: flux-applier
      namespace: aks-store-demo
    rules:
      - apiGroups: ["*"]
        resources: ["*"]
        verbs: ["*"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: flux-applier
      namespace: aks-store-demo
    subjects:
      - kind: ServiceAccount
        name: flux-applier
        namespace: aks-store-demo
    roleRef:
      kind: Role
      name: flux-applier
      apiGroup: rbac.authorization.k8s.io
    ```

* Apply the authorization on the Fleet Manager hub cluster.

    ```bash
    kubectl apply -f apply-service-account.yaml
    ```

* So the Flux extension on member clusters can also manage resources in the distributed `aks-store-demo` namespace, use a Fleet Manager resource placement to roll out the service account to member clusters. Save the following YAML as `distribute-service-account.yaml`.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ResourcePlacement
    metadata:
      name: aks-store-demo-flux-roles-placement
      namespace: aks-store-demo
    spec:
      resourceSelectors:
        - group: ""
          version: v1
          kind: ServiceAccount
          name: flux-applier
    
        - group: rbac.authorization.k8s.io
          version: v1
          kind: Role
          name: flux-applier
    
        - group: rbac.authorization.k8s.io
          version: v1
          kind: RoleBinding
          name: flux-applier

      policy:
        placementType: PickAll
      strategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
          maxSurge: 25%
    ```

* Apply the placement on the Fleet Manager hub cluster.

    ```bash
    kubectl apply -f distribute-service-account.yaml
    ```

* Next, attach the hub cluster to the Git source and use Kustomize to hydrate the resources onto the hub cluster. Save the following YAML as `bootstrap-fleet-gitops-oci.yaml`.

    ```yaml
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
        name: git-repo-fleet-config
        namespace: aks-store-demo
    spec:
        interval: 1m
        url: https://github.com/azure-samples/aks-store-demo
        ref:
            branch: main
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
        name: kustonize-fleet-config
        namespace: aks-store-demo
    spec:
        interval: 1m
        path: ./fleet/aks-store-fleet-oci
        prune: true
        sourceRef:
          kind: GitRepository
          name: git-repo-fleet-config
    ```

* Stage the resources on the Fleet Manager hub cluster.

    ```bash
    kubectl apply -f bootstrap-fleet-gitops-oci.yaml
    ```

    > [!NOTE] 
    > The Fleet Manager hub cluster doesn't run synchronized resources locally by design. The hub cluster is intended to only store resource definitions for distribution to member clusters. 

## Understanding the source repository

When Flux synchronizes the GitRepo source, it applies the manifests in the [aks-store-fleet-oci](https://github.com/Azure-Samples/aks-store-demo/tree/main/fleet/aks-store-fleet-oci) folder and runs the Kustomization.

The file contents in the folder perform the following functions:

* **app-kustomization.yaml** - Flux Kustomization that runs on each member cluster, deploying the contents of the OCIRepository. 
* **app-source.yaml** - Flux OCIRepository source that points to the artifact to deploy.
* **fleet-resource-placement.yaml** - A Fleet Manager namespace-scoped [resource placement](./howto-understand-placement.md) that selects just the OCIRepository and Kustomization resources in the application namespace and distributes them to the same namespace on all member clusters.
* **fleet-resource-override.yaml** - A Fleet Manager [resource placement override](./howto-use-overrides-customize-resources-placement.md) that removes the `suspend` from the OCIRepository and Kustomization resources when it distributes them to member clusters.

> [!NOTE] 
> Both app components are bundled with `suspend` set to `true` so that the Fleet Manager hub cluster doesn't reconcile the resources. The hub cluster can't schedule workloads, so there's no impact other than an unnecessary use of scheduler time on the hub.

## Validating the deployment

1. Check the placement rollout:

    ```bash
    kubectl get resourceplacement aks-store-demo-flux-placement -n aks-store-demo
    ```

    Your output should look similar to the following example:

    ```output
    NAME                             GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
    aks-store-demo-flux-placement    1     True        1               True        1               2m45s
    ```

1. On member clusters, view the services that Flux deployed from the OCI artifact.

    ```bash
    kubectl get services --namespace aks-store-demo
    ```

1. Browse to the `store-front` or `store-admin` services to access the web experiences deployed and confirm the solution functions as expected.

## Deleting the deployment

Delete the Kustomization on the Fleet Manager hub cluster. This action removes the resource placement and override, which in turn removes the application deployment on member clusters.

```bash
kubectl delete Kustomization kustomize-fleet-config -n aks-store-demo
```

## Alternative use cases

To gradually roll out an OCI artifact update, change the tag in the `OCIRepository` and use a namespace-scoped `ResourcePlacement` with a staged update run. Configure stages to distribute the updated source to clusters in order, and validate each stage before proceeding. To roll back, restore the previous artifact tag and run another staged rollout. For details, see [Control cluster order for resource placement](./howto-staged-update-run.md) and [Understand resource placement](./howto-understand-placement.md).

## Summary

In this article, you deployed the AKS Store Demo from an OCI artifact across Fleet Manager member clusters by using Flux `OCIRepository` and `Kustomization` resources. You staged the resources on the Fleet Manager hub cluster, used resource placement to distribute the namespace and OCI resources, applied an artifact tag override for one selected member cluster, and validated the deployed services.

This approach adds Fleet Manager placement, rollout control, and per-cluster overrides to Flux reconciliation, which helps you manage multicluster deployments without maintaining separate Flux configuration for each target cluster. As you add or remove clusters from your environment, you can expand, move, or remove your OCI-managed applications through Fleet Manager.

## Next steps

To learn more about how to achieve additional control over resource distribution by using rollouts, see the following resources:

* [Deploy Helm charts with Azure Kubernetes Fleet Manager and Flux (preview)](./howto-gitops-fleet-flux-helm.md)
* [Control cluster order for resource placement](./howto-staged-update-run.md)
* [Understand status fields and conditions for Fleet Manager resource placement](./howto-understand-placement.md)
* [View agent logs in Azure Kubernetes Fleet Manager](./view-fleet-agent-logs.md)

<!-- Internal links -->
[az-account-set]: /cli/azure/account#az-account-set
[az-fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[azure-cli-install]: /cli/azure/install-azure-cli