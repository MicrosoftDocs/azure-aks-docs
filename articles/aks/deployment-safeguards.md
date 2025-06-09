---
title: Use deployment safeguards to enforce best practices in Azure Kubernetes Service (AKS)
description: Learn how to use deployment safeguards to enforce best practices on an Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.topic: how-to
ms.custom: build-2024, devx-track-azurecli
ms.date: 04/25/2024
ms.author: schaffererin
---

# Use deployment safeguards to enforce best practices in Azure Kubernetes Service (AKS)

This article shows you how to use deployment safeguards to enforce best practices on an Azure Kubernetes Service (AKS) cluster.

## Overview

Throughout the development lifecycle, it's common for bugs, issues, and other problems to arise if the initial deployment of your Kubernetes resources includes misconfigurations. To ease the burden of Kubernetes development, Azure Kubernetes Service (AKS) offers deployment safeguards. Deployment safeguards enforce Kubernetes best practices in your AKS cluster through Azure Policy controls.

Deployment safeguards offer two levels of configuration:

  * `Warning`: Displays warning messages in the code terminal to alert you of any noncompliant cluster configurations but still allows the request to go through.
  * `Enforcement`: Enforces compliant configurations by denying and mutating deployments if they don't follow best practices.

After you configure deployment safeguards for 'Warning' or 'Enforcement', Deployment safeguards programmatically assess your clusters at creation or update time for compliance. Deployment safeguards also display aggregated compliance information across your workloads at a per resource level via Azure Policy's compliance dashboard in the [Azure portal][Azure-Policy-compliance-portal] or in your CLI or terminal. Running a noncompliant workload indicates that your cluster isn't following best practices and that workloads on your cluster are at risk of experiencing issues caused by your cluster configuration.

## Prerequisites
> [!NOTE]
> Cluster admins do not need Azure Policy permissions to enable or disable Deployment Safeguards. However, it is required to have the Azure Policy add-on installed.

* You need to enable the Azure Policy add-on for AKS. For more information, see [Enable Azure Policy on your AKS cluster][policy-for-kubernetes].

## Deployment safeguards policies

The following table lists the policies that become active and the Kubernetes resources they target when you enable deployment safeguards. You can view the [currently available deployment safeguards][deployment-safeguards-list] in the Azure portal as an Azure Policy definition or at [Azure Policy built-in definitions for Azure Kubernetes Service][Azure-Policy-built-in-definition-docs]. The intention behind this collection is to create a common and generic list of best practices applicable to most users and use cases.

| Deployment safeguard policy | Mutation outcome if available |
|--------------|--------------|
| Cannot Edit Individual Nodes | N/A |
| Kubernetes cluster containers CPU and memory resource limits shouldn't exceed the specified limits | Sets CPU resource limits to 500m if not set and sets memory limits to 500Mi if no path is present |
| Must Have Anti Affinity Rules Set | N/A |
| No AKS Specific Labels | N/A |
| Kubernetes cluster containers should only use allowed images | N/A |
| Reserved System Pool Taints | Removes the `CriticalAddonsOnly` taint from a user node pool if not set. AKS uses the `CriticalAddonsOnly` taint to keep customer pods away from the system pool. This configuration ensures a clear separation between AKS components and customer pods and prevents eviction of customer pods that don't tolerate the `CriticalAddonsOnly` taint. |
| Ensure cluster containers have readiness or liveness probes configured | N/A |
| Kubernetes clusters should use Container Storage Interface (CSI) driver StorageClass | N/A|
| Kubernetes cluster services should use unique selectors | N/A| 
| Kubernetes cluster container images should not include latest image tag | N/A |

If you want to submit an idea or request for deployment safeguards, open an issue in the [AKS GitHub repository][aks-gh-repo] and add `[deployment safeguards request]` to the beginning of the title.

## Enable deployment safeguards

>[!NOTE]
> Using the deployment safeguards `Enforcement` level means you're opting in to deployments being blocked and mutated. Please consider how these policies might work with your AKS cluster before enabling `Enforcement`.

### Enable deployment safeguards on an existing cluster

Enable deployment safeguards on an existing cluster that has the Azure Policy add-on enabled using the `az aks safeguard update` command with the `--level` flag. If you want to receive noncompliance warnings, set the `--level` to `Warning`. If you want to deny or mutate all noncompliant deployments, set it to `Enforcement`.

```azurecli-interactive
az aks safeguard update -g <RGNAME> -n <CLUSTERNAME> --level Enforcement 
```

If you want to update the deployment safeguards level of an existing cluster, rereun the following command with the new value for `--level`.

```azurecli-interactive
az aks safeguard update -g <RGNAME> -n <CLUSTERNAME> --level Warning 
```

### Excluding namespaces

You can also exclude certain namespaces from deployment safeguards. When you exclude a namespace, activity in that namespace is unaffected by deployment safeguards warnings or enforcement.

For example, to exclude the namespaces `ns1` and `ns2`, use a comma-separated list of namespaces with the `--safeguards-excluded-ns` flag, as shown in the following example:

```azurecli-interactive
az aks safeguards update -g <RGNAME> -n <CLUSTERNAME> --level Warning --safeguards-excluded-ns ns1,ns2 
```

### Update your deployment safeguard version

Deployment safeguards adhere to the AKS addon versioning scheme. Each new version of a deployment safeguard will be released as a new minor version in AKS. These updates will be communicated through the AKS GitHub release notes and reflected in the "Deployment Safeguards Policies" table in our documentation.

To learn more about AKS versioning and addons, refer to the following documentation: [aks-component-versions] and [aks-versioning-for-addons].

## Verify compliance across clusters

After deploying your Kubernetes manifest, you see warnings or a potential denial message in your CLI or terminal if the cluster isn't compliant with deployment safeguards, as shown in the following examples:

**Warning**

```
$ kubectl apply -f pod.yml
Warning: [azurepolicy-k8sazurev2containerenforceprob-0e8a839bcd103e7b96a8] Container <my-container> in your Pod <my-pod> has no <livenessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
Warning: [azurepolicy-k8sazurev2containerenforceprob-0e8a839bcd103e7b96a8] Container <my-container> in your Pod <my-pod> has no <readinessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
Warning: [azurepolicy-k8sazurev1restrictedlabels-67c4210cc58f28acdfdb] Label <{"kubernetes.azure.com"}> is reserved for AKS use only
Warning: [azurepolicy-k8sazurev3containerlimits-a8754961dbd4c1d8b49d] container <my-container> has no resource limits
Warning: [azurepolicy-k8sazurev1containerrestrictedi-bde07e1776cbcc9aa8b8] my-pod in default does not have imagePullSecrets. Unauthenticated image pulls are not recommended.
pod/my-pod created
```

**Enforcement**

With deployment safeguard mutations, the `Enforcement` level mutates your Kubernetes resources when applicable. However, your Kubernetes resources still need to pass all safeguards to deploy successfully. If any safeguard policies fail, your resource is denied and won't be deployed.

```
$ kubectl apply -f pod.yml
Error from server (Forbidden): error when creating ".\pod.yml": admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8sazurev2containerenforceprob-0e8a839bcd103e7b96a8] Container <my-container> in your Pod <my-pod> has no <livenessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
[azurepolicy-k8sazurev2containerenforceprob-0e8a839bcd103e7b96a8] Container <my-container> in your Pod <my-pod> has no <readinessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
[azurepolicy-k8sazurev2containerallowedimag-1ff6d14b2f8da22019d7] Container image my-image for container my-container has not been allowed.
[azurepolicy-k8sazurev1restrictedlabels-67c4210cc58f28acdfdb] Label <{"kubernetes.azure.com"}> is reserved for AKS use only
[azurepolicy-k8sazurev1containerrestrictedi-bde07e1776cbcc9aa8b8] my-pod in default does not have imagePullSecrets. Unauthenticated image pulls are not recommended.
```

If your Kubernetes resources comply with the applicable mutation safeguards and meet all other safeguard requirements, they will be successfully deployed, as shown in the following example:

```
$ kubectl apply -f pod.yml
pod/my-pod created
```

## Verify compliance across clusters using the Azure Policy dashboard

To verify deployment safeguards have been applied and to check on your cluster's compliance, navigate to the Azure portal page for your cluster and select **Policies**, then select **go to Azure Policy**.

From the list of policies and initiatives, select the initiative associated with deployment safeguards. You see a dashboard showing compliance state across your AKS cluster.

> [!NOTE]
> To properly assess compliance across your AKS cluster, the Azure Policy initiative must be scoped to your cluster's resource group.

## Disable deployment safeguards

Disable deployment safeguards on your cluster by setting the safeguards `--level` to `off`.

```azurecli-interactive
az aks safeguards update -g <RGNAME> -n <CLUSTERNAME> --level off
```

--

## FAQ

#### Can I create my own mutations?

No. If you have an idea for a safeguard, open an issue in the [AKS GitHub repository][aks-gh-repo] and add `[deployment safeguards request]` to the beginning of the title.

#### Can I pick and choose which mutations I want in Enforcement?

No. Deployment safeguards is all or nothing. Once you turn on Warning or Enforcement, all safeguards will be active.

#### Why did my deployment resource get admitted even though it wasn't following best practices?

Deployment safeguards enforce best practice standards through Azure Policy controls and has policies that validate against Kubernetes resources. To evaluate and enforce cluster components, Azure Policy extends [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/). Gatekeeper enforcement also currently operates in a [`fail-open` model](https://open-policy-agent.github.io/gatekeeper/website/docs/failing-closed/#considerations). As there's no guarantee that Gatekeeper will respond to our networking call, we make sure that in that case, the validation is skipped so that the deny doesn't block your deployments.

To learn more, see [workload validation in Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/workload-resources/).

## Next steps

* Learn more about [best practices][best-practices] for operating an AKS cluster.

<!-- LINKS -->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[best-practices]: ./best-practices.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[aks-gh-repo]: https://github.com/Azure/AKS
[policy-for-kubernetes]: /azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks
[deployment-safeguards-list]: https://portal.azure.com/#view/Microsoft_Azure_Policy/InitiativeDetail.ReactView/id/%2Fproviders%2FMicrosoft.Authorization%2FpolicySetDefinitions%2Fc047ea8e-9c78-49b2-958b-37e56d291a44/scopes/
[Azure-Policy-built-in-definition-docs]: /azure/aks/policy-reference#policy-definitions
[Azure-Policy-compliance-portal]: https://ms.portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance
[Azure-Policy-RBAC-permissions]: /azure/governance/policy/overview#azure-rbac-permissions-in-azure-policy
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[aks-component-versions]: https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-components-breaking-changes-by-version
[aks-versioning-for-addons]: https://learn.microsoft.com/azure/aks/integrations#add-ons
