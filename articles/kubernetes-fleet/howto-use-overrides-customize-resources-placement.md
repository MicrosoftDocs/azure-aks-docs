---
title: "Use Resource Overrides to customize resources deployed by Azure Kubernetes Fleet Manager resource placement"
description: This article provides an overview of how to use the resource override APIs to customize resource configurations when using Azure Kubernetes Fleet Manager resource placement.
ms.topic: how-to
ms.date: 02/11/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: As a Kubernetes administrator, I want to override resource configurations as they are deployed by Fleet Manager resource placement, so that I can deploy the same resource to multiple environments with minimal changes."
zone_pivot_groups: cluster-namespace-scope
---

# Use Resource Overrides to customize resources deployed by Azure Kubernetes Fleet Manager resource placement

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

Azure Kubernetes Fleet Manager intelligent resource placement can be used to deploy the same resource to multiple clusters across a fleet. Often there's a need to modify the resource configuration to enforce rules around behavior in different environments (dev, test, prod). For this purpose, Fleet Manager provides resource overrides, which are the Fleet Manager equivalent of Helm templates and Kustomize patches.

Examples of situations where modifying a resource configuration is useful include:

* I want to the same `ClusterRole` configuration to all clusters, but make it more restrictive for my production clusters.
* I want to use the same `Deployment` on all clusters, but use a different container image or port on my productions clusters.

This article shows you how to create overrides for resources deployed by Fleet Manager resource placement.

Azure Kubernetes Fleet Manager supports two scopes for overrides:

* **Cluster-scoped**: Use `ClusterResourceOverride` with `ClusterResourcePlacement` for fleet administrators managing infrastructure-level changes.
* **Namespace-scoped (preview)**: Use `ResourceOverride` with `ResourcePlacement` for application teams managing rollouts within their specific namespaces.

You can select the scope most applicable to you from the scope type choices at the top of the article.

> [!IMPORTANT]
> `ResourcePlacement` uses the `placement.kubernetes-fleet.io/v1beta1` API version and is currently in preview.

:::zone target="docs" pivot="cluster-scope"

## Cluster-scoped resource overrides

A `ClusterResourceOverride` has the following properties:

* `clusterResourceSelectors`: Specifies the set of cluster resources selected for overriding.
* `policy`: Specifies the set of rules to apply to the selected cluster resources.

> [!NOTE]
> `Policy` definitions are the same for both cluster and namespace-scoped resources.

Let's use the following example `ClusterRole` named `secret-reader` to demonstrate how `ClusterResourceOverride` works.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```

## Selecting cluster resources

A `ClusterResourceOverride` can include one or more `clusterResourceSelector` to choose which resources to override. Each `clusterResourceSelector` supports the following fields.

* `group`: The API group of the resource.
* `version`: The API version of the resource.
* `kind`: The kind of the resource.
* `name`: The name of the resource.

> [!NOTE]
> If you select a namespace in `ClusterResourceSelector`, the override applies to all resources in the namespace.

Using our example `ClusterRole`, let's see how we select it in a `ClusterResourceOverride`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ClusterResourceOverride
metadata:
  name: example-cro
spec:
  clusterResourceSelectors:
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
      version: v1
      name: secret-reader
```
:::zone-end

:::zone target="docs" pivot="namespace-scope"  

## Namespace-scoped resource overrides (preview)

A `ResourceOverride` has the following properties:

* `resourceSelectors`: Specifies the set of resources selected for overriding.
* `policy`: Specifies the set of rules to apply to the selected resources.

> [!NOTE]
> `Policy` definitions are the same for both cluster and namespace-scoped resources.

Let's use the following example `Deployment` named `nginx-sample` to demonstrate how `ResourceOverride` works.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-sample
  namespace: nginx-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

## Selecting namespace resources

A `ResourceOverride` can include one or more `resourceSelector` to choose which resources to override. Each `resourceSelector` supports the following fields.

* `group`: The API group of the resource.
* `version`: The API version of the resource.
* `kind`: The kind of the resource.
* `name`: The name of the resource.

The namespace of the resource to override is determined by specifying the `namespace` set in the `metadata` of the `ResourceOverride`.

Using our example `Deployment`, let's see how we select it in a `ResourceOverride`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ResourceOverride
metadata:
  name: example-resource-override
  namespace: nginx-demo
spec:
  resourceSelectors:
    -  group: apps
       kind: Deployment
       version: v1
       name: nginx-sample
```

> [!IMPORTANT]
> * If you select a namespace in `resourceSelector` (`kind: Namespace`), the override applies to all resources in the namespace.
> * The `ResourceOverride` needs to be in the same namespace as the resource to override.

:::zone-end

Now we have the resource selected. Let's look at how we configure the override using a `policy`.

## Policy

A `policy` consists of a set of `overrideRules` that specify the changes to apply to the selected resources. Each `overrideRules` supports the following fields:

* `clusterSelector`: Specifies the set of clusters to which the override rule applies.
* `jsonPatchOverrides`: Specifies the changes to apply to the selected resources.

### Cluster selector

You can use the `clusterSelector` field in the `overrideRules` to specify the clusters to which the rule applies. The `clusterSelector` supports the following field:

* `clusterSelectorTerms`: A list of terms that specify the criteria for selecting clusters. Each term includes a `labelSelector` field that defines a set of labels to match.

> [!IMPORTANT]
> Only `labelSelector` is supported in the `clusterSelectorTerms` field.

### JSON patch overrides

You can use `jsonPatchOverrides` in `overrideRules` to specify the changes to apply to the selected resources. The `JsonPatch` property supports the following fields:

* `op`: The operation to perform. Supported operations include:
  * `add`: Adds a new value to the specified path.
  * `remove`: Removes the value at the specified path.
  * `replace`: Replaces the value at the specified path.

* `path`: The path to the field to modify. Guidance on specifying paths includes:
  * Must start with a slash (`/`) character.
  * Can't be empty or contain an empty string.
  * Can't be a `TypeMeta` field (`/kind` or `/apiVersion`).
  * Can't be a `Metadata` field (`/metadata/name` or `/metadata/namespace`), except the fields `/metadata/labels` and `/metadata/annotations`.
  * Can't be any field in the status of the resource.

  Examples of valid paths include:  
  * `/metadata/labels/new-label`
  * `/metadata/annotations/new-annotation`
  * `/spec/template/spec/containers/0/resources/limits/cpu`
  * `/spec/template/spec/containers/0/resources/requests/memory`

* `value`: The value to add, remove, or replace. If `op` is `remove`, you can't specify `value`.

The `jsonPatchOverrides` fields apply a JSON patch on the selected resources by following [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902).

:::zone target="docs" pivot="cluster-scope" 

Extending our example, we configure a `policy` to remove the `list` verb from the `ClusterRole` named `secret-reader` on clusters labeled with `env:prod`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ClusterResourceOverride
metadata:
  name: example-cro
spec:
  clusterResourceSelectors:
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
      version: v1
      name: secret-reader
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: prod
        jsonPatchOverrides:
          - op: remove
            path: /rules/0/verbs/2
```

:::zone-end

:::zone target="docs" pivot="namespace-scope" 

Extending our example, we configure a `policy` to replace the container image in the `Deployment` with the `nginx:1.30.0` image for clusters with the `env: prod` label.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ResourceOverride
metadata:
  name: example-resource-override
  namespace: test-namespace
spec:
  resourceSelectors:
    -  group: apps
       kind: Deployment
       version: v1
       name: test-nginx
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: prod
        jsonPatchOverrides:
          - op: replace
            path: /spec/template/spec/containers/0/image
            value: "nginx:1.30.0"
```

:::zone-end

### Define multiple overrides

You can add multiple `jsonPatchOverrides` fields to `overrideRules` to apply multiple changes to a selected cluster resources. Here's an example:

:::zone target="docs" pivot="cluster-scope" 

This example removes the verbs "list" and "watch" in our sample `ClusterRole` named `secret-reader` on clusters with the label `env: prod`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ClusterResourceOverride
metadata:
  name: cro-1
spec:
  clusterResourceSelectors:
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
      version: v1
      name: secret-reader
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: prod
        jsonPatchOverrides:
          - op: remove
            path: /rules/0/verbs/2
          - op: remove
            path: /rules/0/verbs/1
```

:::zone-end

:::zone target="docs" pivot="namespace-scope" 

This example replaces both the container image and port in the `Deployment` with `443` for clusters with the `env: prod` label.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ResourceOverride
metadata:
  name: example-resource-override
  namespace: test-namespace
spec:
  resourceSelectors:
    -  group: apps
       kind: Deployment
       version: v1
       name: test-nginx
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: prod
        jsonPatchOverrides:
          - op: replace
            path: /spec/template/spec/containers/0/image
            value: "nginx:1.30.0"
          - op: replace
            path: /spec/template/spec/containers/0/ports/0/containerPort
            value: "443"
```

:::zone-end

### Reserved Variables in the JSON Patch Override Value

Reserved variables are replaced at placement by the `value` of the JSON patch override rule. Currently supported reserved variables:

* `${MEMBER-CLUSTER-NAME}`: replaced by the name of the `memberCluster`.

For example, to create an Azure DNS hostname that contains the name of the cluster the  example `ResourceOverride` adds a value of `fleet-clustername-eastus` on clusters in the `eastus` Azure region.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ResourceOverride
metadata:
  name: ro-kuard-demo-eastus
  namespace: kuard-demo
spec:
  placement:
    name: crp-kuard-demo
  resourceSelectors:
    -  group: ""
        kind: Service
        version: v1
        name: kuard-svc
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  fleet.azure.com/location: eastus
        jsonPatchOverrides:
          - op: add
            path: /metadata/annotations
            value:
              {"service.beta.kubernetes.io/azure-dns-label-name":"fleet-${MEMBER-CLUSTER-NAME}-eastus"}
```

### Multiple override rules

You can add multiple `overrideRules` to a `policy` field to apply multiple changes to the selected resources. Here's an example for `ResourceOverride`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1alpha1
kind: ResourceOverride
metadata:
  name: ro-1
  namespace: test
spec:
  resourceSelectors:
    -  group: apps
       kind: Deployment
       version: v1
       name: test-nginx
  policy:
    overrideRules:
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: prod
        jsonPatchOverrides:
          - op: replace
            path: /spec/template/spec/containers/0/image
            value: "nginx:1.20.0"
      - clusterSelector:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  env: test
        jsonPatchOverrides:
          - op: replace
            path: /spec/template/spec/containers/0/image
            value: "nginx:latest"
```

This example replaces the container image in the `Deployment` with:

* The `nginx:1.20.0` image for clusters with the `env: prod` label.
* The `nginx:latest` image for clusters with the `env: test` label.

:::zone target="docs" pivot="cluster-scope" 

## Use with cluster resource placement

### [Azure CLI](#tab/azure-cli)

1. Create a `ClusterResourcePlacement` to specify the placement rules for distributing the cluster resource overrides across the cluster infrastructure. The following code is an example. Be sure to select the appropriate resource.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp
    spec:
      resourceSelectors:
        - group: rbac.authorization.k8s.io
          kind: ClusterRole
          version: v1
          name: secret-reader
      policy:
        placementType: PickAll
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      env: prod
    ```

    This example distributes resources across all clusters labeled with `env: prod`. As the changes are implemented, the corresponding `ClusterResourceOverride` configurations are applied to the designated clusters. The selection of a matching cluster role resource, `secret-reader`, triggers the application of the configurations to the clusters.

2. Apply the `ClusterResourcePlacement` by using the `kubectl apply` command:

    ```bash
    kubectl apply -f cluster-resource-placement.yaml
    ```

3. Verify that the `ClusterResourceOverride` was applied to the selected resources by checking the status of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe clusterresourceplacement crp
    ```

    Your output should resemble the following example:

    ```output
    Status:
      Conditions:
        ...
        Last Transition Time:   2024-04-27T04:18:00Z
        Message:                The selected resources are successfully overridden in the 10 clusters
        Observed Generation:    1
        Reason:                 OverriddenSucceeded
        Status:                 True
        Type:                   ClusterResourcePlacementOverridden
        ...
      Observed Resource Index:  0
      Placement Statuses:
        Applicable Cluster Resource Overrides:
          example-cro-0
        Cluster Name:  member-50
        Conditions:
          ...
          Message:               Successfully applied the override rules on the resources
          Observed Generation:   1
          Reason:                OverriddenSucceeded
          Status:                True
          Type:                  Overridden
         ...
    ```

    The `ClusterResourcePlacementOverridden` condition indicates whether the resource override was successfully applied to the selected resources in the clusters. Each cluster maintains its own `Applicable Cluster Resource Overrides` list. This list contains the snapshot of the cluster resource override, if relevant. Individual status messages for each cluster indicate whether the override rules were successfully applied.

### [Portal](#tab/azure-portal)

1. On the Azure portal overview page for your Fleet Manager, in the **Fleet Resources** section, select **Resource placements**.

1. Select **Create**.

1. Create a `ClusterResourcePlacement` to specify the placement rules for distributing the cluster resource overrides across the cluster infrastructure, as shown in the following example. Be sure to select the appropriate resource. Replace the default template with the YAML example, and then select **Add**.

    :::image type="content" source="./media/cluster-resource-override/crp-create-inline.png" lightbox="./media/cluster-resource-override/crp-create.png" alt-text="Screenshot of the Azure portal page for creating a resource placement, showing the YAML template with placeholder values.":::

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp
    spec:
      resourceSelectors:
        - group: rbac.authorization.k8s.io
          kind: ClusterRole
          version: v1
          name: secret-reader
      policy:
        placementType: PickAll
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      env: prod
    ```

    This example distributes resources across all clusters labeled with `env: prod`. As the changes are implemented, the corresponding `ClusterResourceOverride` configurations are applied to the designated clusters. The selection of a matching cluster role resource, `secret-reader`, triggers the application of the configurations to the clusters.

1. Verify that the cluster resource placement was created successfully.

    :::image type="content" source="./media/cluster-resource-override/crp-success-inline.png" lightbox="./media/cluster-resource-override/crp-success.png" alt-text="Screenshot of the Azure portal page for cluster resource placements, showing a successfully created placement.":::

1. Verify that the cluster resource placement was applied to the selected resources by selecting the resource from the list and checking the status.

:::zone-end

:::zone target="docs" pivot="namespace-scope" 

## Use with resource placement

### [Azure CLI](#tab/azure-cli)

1. Create a `ClusterResourcePlacement` resource to specify the placement rules for distributing the resource overrides across the cluster infrastructure. The following code is an example. Be sure to select the appropriate namespaces.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp-example
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: test-namespace
          version: v1
      policy:
        placementType: PickAll
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      env: prod
                - labelSelector:
                    matchLabels:
                      env: test
    ```

    This example distributes resources within `test-namespace` across all clusters labeled with `env:prod` and `env:test`. As the changes are implemented, the corresponding `ResourceOverride` configurations are applied to the designated resources. The selection of a matching deployment resource, `my-deployment`, triggers the application of the configurations to the designated resources.

2. Apply the `ClusterResourcePlacement` resource by using the `kubectl apply` command:

    ```bash
    kubectl apply -f cluster-resource-placement.yaml
    ```

3. Verify that the `ResourceOverride` was applied to the selected resources by checking the status of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe clusterresourceplacement crp-example
    ```

    Your output should resemble the following example:

    ```output
    Status:
      Conditions:
        ...
        Message:                The selected resources are successfully overridden in the 10 clusters
        Observed Generation:    1
        Reason:                 OverriddenSucceeded
        Status:                 True
        Type:                   ClusterResourcePlacementOverridden
        ...
      Observed Resource Index:  0
      Placement Statuses:
        Applicable Resource Overrides:
          Name:        ro-1-0
          Namespace:   test-namespace
        Cluster Name:  member-50
        Conditions:
          ...
          Last Transition Time:  2024-04-26T22:57:14Z
          Message:               Successfully applied the override rules on the resources
          Observed Generation:   1
          Reason:                OverriddenSucceeded
          Status:                True
          Type:                  Overridden
         ...
    ```

    The `ClusterResourcePlacementOverridden` condition indicates whether the resource override was successfully applied to the selected resources. Each cluster maintains its own `Applicable Resource Overrides` list. This list contains the resource override snapshot, if relevant. Individual status messages for each cluster indicate whether the override rules were successfully applied.

### [Portal](#tab/azure-portal)

1. On the Azure portal overview page for your Fleet Manager resource, in the **Fleet Resources** section, select **Resource placements**.

1. Select **Create**.

1. Create a `ClusterResourcePlacement` resource to specify the placement rules for distributing the resource overrides across the cluster infrastructure, as shown in the following example. Be sure to select the appropriate namespaces. When you're ready, select **Add**.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp-example
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: test-namespace
          version: v1
      policy:
        placementType: PickAll
        affinity:
          clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      env: prod
                - labelSelector:
                    matchLabels:
                      env: test
    ```

    This example distributes resources within `test-namespace` across all clusters labeled with `env:prod` and `env:test`. As the changes are implemented, the corresponding `ResourceOverride` configurations are applied to the designated resources. The selection of a matching deployment resource, `my-deployment`, triggers the application of the configurations to the designated resources.

    :::image type="content" source="./media/quickstart-resource-propagation/create-resource-propagation-inline.png" lightbox="./media/quickstart-resource-propagation/create-resource-propagation.png" alt-text="Screenshot of the Azure portal page for creating a resource placement, showing the YAML template with placeholder values.":::

1. Verify that the cluster resource placement was created successfully.

    :::image type="content" source="./media/quickstart-resource-propagation/overview-cluster-resource-inline.png" lightbox="./media/quickstart-resource-propagation/overview-cluster-resource.png" alt-text="Screenshot of the Azure portal page for cluster resource placements, showing a successfully created placement.":::

1. Verify that the cluster resource placement is applied by selecting the CRP from the list and checking the placement status.

:::zone-end

---

## Related content

* [Open-source KubeFleet documentation](https://kubefleet.dev/docs/concepts/override/)
* [Azure Kubernetes Fleet Manager overview](./overview.md)
