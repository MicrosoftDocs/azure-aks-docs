---
title: "Annotation-based placement in Azure Kubernetes Fleet Manager"
description: "Learn how to use a Kubernetes annotation to place a resource on selected Fleet Manager member clusters."
ms.date: 10/27/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
ai-usage: ai-assisted
---

# Annotation-based placement in Azure Kubernetes Fleet Manager

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

With annotation-based placement, you can specify where a Kubernetes resource should run by adding an annotation to the resource on the Fleet Manager hub cluster. Fleet Manager translates the annotation into a placement policy, so you don't need to create and maintain a placement object for a straightforward placement scenario.

This capability is part of the KubeFleet placement policy API design. It's described as an alpha-level feature in the [KubeFleet placement policy enhancement](https://github.com/kubefleet-dev/enhancements/blob/main/enhancements/0001-placement-policy/README.md). Check that your Fleet Manager distribution supports and enables the feature before using it.

## How annotation-based placement works

Add the reserved `kubefleet.dev/cluster-selectors` annotation to a resource on the hub cluster. The annotation contains one or more cluster selection requirements. Fleet Manager creates a placement policy for the resource and records the policy reference on the resource for tracking.

When you change or remove the annotation, Fleet Manager updates or deletes the corresponding policy. Deleting the annotated resource also deletes its policy. For supported workload resources, Fleet Manager adds dependencies referenced by the workload's pod template to the policy.

## Annotation format

The value is a semicolon-separated list of requirements. Each requirement contains one or more comma-separated label matchers and an optional cluster count:

```text
LABEL_KEY=LABEL_VALUE[,LABEL_KEY=LABEL_VALUE...][,count=N|All]
```

Each label matcher in a requirement must match the cluster. The `count` value specifies how many matching clusters to select. It accepts a positive integer or `All`, which selects every matching cluster. If you omit `count`, the default is `1`.

For convenience, use `region` instead of `fleet.azure.com/location`, and `alias` instead of `kubefleet.dev/cluster-alias`. The `alias` matcher selects a member cluster by its KubeFleet alias. If you don't explicitly define an `alias` label, Fleet Manager falls back to matching against the member cluster name.

This example requests one cluster in each of three regions:

```bash
kubectl annotate deployment app \\
	kubefleet.dev/cluster-selectors='region=eastus;region=westus;region=centralus'
```

This example requests all staging clusters and one canary cluster in the East US region:

```bash
kubectl annotate deployment app \\
	kubefleet.dev/cluster-selectors='env=staging,count=All;env=canary,region=eastus,count=1'
```

To select named clusters, use their aliases:

```bash
kubectl annotate namespace work \\
	kubefleet.dev/cluster-selectors='alias=bravelion;alias=smartfish'
```

## Choosing an approach

Use annotation-based placement for a resource with a small, direct set of cluster requirements. Each semicolon-separated requirement becomes a scheduling requirement in the generated policy. Requirements can overlap, so the same cluster might satisfy more than one requirement; don't assume the requested counts always add up to a number of distinct clusters.

For more complex scenarios, create a placement policy directly. Direct policies provide finer control over resource selectors, cluster selectors, minimum cluster counts, and other placement options. For an overview of the existing placement APIs, see [Intelligent resource placement](./concepts-resource-placement.md).

Annotation-based placement is a separate workflow from `ResourcePlacement` and `ClusterResourcePlacement`. Don't use both workflows to place the same resource on the same target cluster.

## Security considerations

An annotation can cause a resource to be distributed to other clusters. Restrict who can add or change the placement annotation, and limit which resource kinds can use it. The enhancement specifies that annotation-based placement is restricted to administrators by default. Administrators can configure authorization for their environment. Review these controls before enabling the feature, especially for sensitive resources such as Secrets.


> [!NOTE] 
> Annotation-based placement works only when the user making the request has permissions to both read the resource being distributed and to create a PlacementPolicy resource.

## Next steps

- [Learn how member cluster labels support placement](./concepts-member-cluster-labels.md).
- [Learn about intelligent resource placement](./concepts-resource-placement.md).
