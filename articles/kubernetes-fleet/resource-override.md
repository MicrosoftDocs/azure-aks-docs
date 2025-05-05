---
title: "Customize Namespace-Scoped Resources in Azure Kubernetes Fleet Manager with Resource Overrides"
description: This article provides an overview of how to use the ResourceOverride API to override namespace-scoped resources in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 05/10/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - build-2024
---

# Customize namespace-scoped resources in Azure Kubernetes Fleet Manager with resource overrides

This article provides an overview of how to use the `ResourceOverride` API to override namespace-scoped resources in Azure Kubernetes Fleet Manager (Kubernetes Fleet).

You can modify or override specific attributes of existing resources within a namespace. With `ResourceOverride`, you can define rules based on cluster labels and specify changes to be applied to resources such as Deployments, StatefulSets, ConfigMaps, or Secrets.

These changes can include updates to container images, environment variables, resource limits, or any other configurable parameters. Such updates help ensure consistent management and enforcement of configurations across your Kubernetes clusters managed through Kubernetes Fleet.

## API components

The `ResourceOverride` API consists of the following components:

* `resourceSelectors`: Specifies the set of resources selected for overriding.
* `policy`: Specifies the set of rules to apply to the selected resources.

### Resource selectors

A `ResourceOverride` object can include one or more resource selectors to specify which resources to override. The `ResourceSelector` object includes the following fields.

> [!NOTE]
> If you select a namespace in `ResourceSelector`, the override will apply to all resources in the namespace.

* `group`: The API group of the resource.
* `version`: The API version of the resource.
* `kind`: The kind of the resource.
* `namespace`: The namespace of the resource.

To add a resource selector to a `ResourceOverride` object, use the `resourceSelectors` field with the following YAML format.

> [!IMPORTANT]
> The `ResourceOverride` object needs to be in the same namespace as the resource that you want to override.

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
```

This example selects a `Deployment` object named `test-nginx` from the `test-namespace` namespace for overriding.

## Policy

A `Policy` object consists of a set of rules, `overrideRules`, that specify the changes to apply to the selected resources. Each `overrideRules` object supports the following fields:

* `clusterSelector`: Specifies the set of clusters to which the override rule applies.
* `jsonPatchOverrides`: Specifies the changes to apply to the selected resources.

To add an override rule to a `ResourceOverride` object, use the `policy` field with the following YAML format:

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
            value: "nginx:1.20.0"
```

This example replaces the container image in the `Deployment` object with the `nginx:1.20.0` image for clusters with the `env: prod` label.

### Cluster selector

You can use the `clusterSelector` field in the `overrideRules` object to specify the resources to which the override rule applies. The `ClusterSelector` object supports the following field:

* `clusterSelectorTerms`: A list of terms that specify the criteria for selecting clusters. Each term includes a `labelSelector` field that defines a set of labels to match.

### JSON patch overrides

You can use `jsonPatchOverrides` in the `overrideRules` object to specify the changes to apply to the selected resources. The `JsonPatch` object supports the following fields:

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

### Multiple override rules

You can add multiple `overrideRules` objects to a `policy` field to apply multiple changes to the selected resources. Here's an example:

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

This example replaces the container image in the `Deployment` object with:

* The `nginx:1.20.0` image for clusters with the `env: prod` label.
* The `nginx:latest` image for clusters with the `env: test` label.

## Apply the cluster resource placement

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

3. Verify that the `ResourceOverride` object was applied to the selected resources by checking the status of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

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

1. On the Azure portal overview page for your Kubernetes Fleet resource, in the **Fleet Resources** section, select **Resource placements**.

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

1. Verify that the cluster resource placement was applied to the selected resources by selecting the resource from the list and checking the status.

---

## Related content

* [Open-source Kubernetes Fleet documentation](https://github.com/Azure/fleet/tree/main/docs)
* [Azure Kubernetes Fleet Manager overview](./overview.md)
