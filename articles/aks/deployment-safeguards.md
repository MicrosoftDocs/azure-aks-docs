---
title: Use Deployment Safeguards to enforce best practices in Azure Kubernetes Service (AKS)
description: Learn how to use Deployment Safeguards to enforce best practices on an Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.topic: how-to
ms.custom: build-2024, devx-track-azurecli
ms.date: 01/29/2026
ms.author: schaffererin
# Customer intent: As a Kubernetes developer, I want to implement Deployment Safeguards in my AKS cluster, so that I can enforce best practices and prevent configuration issues that may compromise the stability of my applications.
---

# Use Deployment Safeguards to enforce best practices in Azure Kubernetes Service (AKS)

This article shows you how to use Deployment Safeguards to enforce best practices on an Azure Kubernetes Service (AKS) cluster.

## Overview
> [!NOTE]
> Deployment Safeguards is turned on by default in AKS Automatic.

Throughout the development lifecycle, it is common for bugs, issues, and other problems to arise if the initial deployment of your Kubernetes resources includes misconfigurations. To ease the burden of Kubernetes development, Azure Kubernetes Service (AKS) offers Deployment Safeguards. Deployment Safeguards enforce Kubernetes best practices in your AKS cluster through Azure Policy controls.

Deployment Safeguards offer two levels of configuration:

  * `Warn`: Displays warning messages in the code terminal to alert you of any noncompliant cluster configurations but still allows the request to go through.
  * `Enforce`: Enforces compliant configurations by denying and mutating deployments if they don't follow best practices.

After you configure Deployment Safeguards for 'Warn' or 'Enforce', Deployment Safeguards programmatically assess your Kubernetes resources at creation or update time for compliance. Deployment Safeguards also display aggregated compliance information across your workloads at a per resource level via Azure Policy's compliance dashboard in the [Azure portal][Azure-Policy-compliance-portal] or in your CLI or terminal. Running a noncompliant workload indicates that your cluster is not following best practices and that workloads on your cluster are at risk of experiencing issues caused by your cluster configuration.

## Prerequisites
> [!NOTE]
> Cluster admins don't need Azure Policy permissions to enable or disable Deployment Safeguards. However, it's required to have the Azure Policy add-on installed.

* You need to enable the Azure Policy add-on for AKS. For more information, see [Enable Azure Policy on your AKS cluster][policy-for-kubernetes]. This includes registering the `Microsoft.PolicyInsights` resource provider in your subscription.

## Deployment Safeguards policies

The following table lists the policies that become active and the Kubernetes resources they target when you enable Deployment Safeguards. You can view the [currently available Deployment Safeguards][deployment-safeguards-list] in the Azure portal as an Azure Policy definition or at [Azure Policy built-in definitions for Azure Kubernetes Service][Azure-Policy-built-in-definition-docs]. The intention behind this collection is to create a common and generic list of best practices applicable to most users and use cases.

| Deployment safeguard policy | Mutation outcome if available |
|--------------|--------------|
| Cannot Edit Individual Nodes | N/A |
| Kubernetes cluster containers CPU and memory resource limits shouldn't exceed the specified limits | Sets default CPU and memory requests and limits, and enforces minimums. For more information, see [Resource requests mutator](#resource-requests-mutator). |
| Must Have Anti Affinity Rules or topologySpreadConstraintsSet | Adds pod anti-affinity rules and topology spread constraints to improve workload distribution. For more information, see [Anti-affinity and topology spread mutator](#anti-affinity-and-topology-spread-mutator). |
| No AKS Specific Labels | N/A |
| Kubernetes cluster containers should only use allowed images | N/A |
| Reserved System Pool Taints | Removes the `CriticalAddonsOnly` taint from a user node pool if not set. AKS uses the `CriticalAddonsOnly` taint to keep customer pods away from the system pool. This configuration ensures a clear separation between AKS components and customer pods and prevents eviction of customer pods that don't tolerate the `CriticalAddonsOnly` taint. |
| Ensure cluster containers have readiness or liveness probes configured | N/A |
| Kubernetes clusters should use Container Storage Interface (CSI) driver StorageClass | N/A|
| Kubernetes cluster services should use unique selectors | N/A| 
| Kubernetes cluster container images should not include latest image tag | N/A |

If you want to submit an idea or request for Deployment Safeguards, open an issue in the [AKS GitHub repository][aks-gh-repo] and add `[Deployment Safeguards request]` to the beginning of the title.

## Resource requests mutator

When Deployment Safeguards is set to `Enforce` level, the resource requests mutator automatically sets CPU and memory requests and limits for containers that don't have them defined or have values below minimum thresholds.

### Default values

When no resources are specified, the mutator sets the following default values:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 500m |
| Memory | 2048Mi (2Gi) | 2048Mi (2Gi) |

### Minimum enforcement

When resources are specified but below thresholds, the mutator enforces the following minimums:

| Resource | Minimum value |
|----------|---------------|
| CPU | 100m |
| Memory | 100Mi |

### Understanding resource units

**CPU units:**

- `m` = millicores (1/1000th of a CPU core)
- `1000m` = `1` = 1 full CPU core
- `500m` = 0.5 CPU cores (half a core)
- `100m` = 0.1 CPU cores (10% of a core)

**Memory units:**

- `Mi` = Mebibytes (binary: 1 Mi = 1,024 × 1,024 bytes)
- `Gi` = Gibibytes (binary: 1 Gi = 1,024 Mi)
- `2048Mi` = `2Gi` = 2 gibibytes
- `100Mi` ≈ 105 MB (decimal)

### CPU mutation rules

The mutator applies the following logic for CPU resources:

| Scenario | Action |
|----------|--------|
| Both CPU request and limit are missing | Set both to 500m (default) |
| CPU request exists but is less than 100m | Set request to 100m (minimum) |
| CPU limit exists but is less than 100m | Set limit to 100m (minimum) |
| Only CPU request exists | Leave as-is (no limit added) |
| Only CPU limit exists | Leave as-is (no request added) |

### Memory mutation rules

The mutator applies the following logic for memory resources:

| Scenario | Action |
|----------|--------|
| Both memory request and limit are missing | Set both to 2048Mi (default) |
| Memory request exists but is less than 100Mi | Set request to 100Mi (minimum) |
| Memory limit exists but is less than 100Mi | Set limit to 100Mi (minimum) |
| Only memory request exists | Leave as-is (no limit added) |
| Only memory limit exists | Leave as-is (no request added) |

### QoS class fix

After CPU and memory mutations are applied, if the request value exceeds the limit for the same resource type, the mutator caps the request to match the limit. This fix maintains valid Kubernetes Quality of Service (QoS) class configurations.

### Cases that are mutated

The resource requests mutator applies changes in the following scenarios:

- **Empty resources**: Containers with no CPU or memory requests or limits receive default values (500m CPU, 2048Mi memory).
- **Below minimum thresholds**: CPU requests or limits below 100m are increased to 100m. Memory requests or limits below 100Mi are increased to 100Mi.
- **Invalid QoS scenarios**: When requests exceed limits, requests are lowered to match limits.
- **Partial resource specifications**: Containers with only requests or only limits (but not both) have minimums enforced where specified.
- **Multiple containers**: All containers in a pod are processed and mutated appropriately.
- **Enabled namespaces**: Only workloads in namespaces where the safeguard is enabled are mutated.

### Cases that aren't mutated

The resource requests mutator doesn't apply changes in the following scenarios:

- **Excluded namespaces**: Workloads in namespaces where the safeguard is excluded remain unchanged.
- **Already compliant resources**: Containers that already have requests and limits above minimum thresholds remain unchanged.
- **Valid QoS configurations**: When requests are less than or equal to limits and both values are above minimums, no changes occur.

## Anti-affinity and topology spread mutator

When Deployment Safeguards is set to `Enforce` level, the anti-affinity and topology spread mutator automatically adds pod anti-affinity rules and topology spread constraints to improve workload distribution across nodes.

### When the mutator runs

The mutator runs only when all of the following conditions are met:

- Both pod anti-affinity and topology spread constraints don't already exist on the workload.
- The namespace isn't excluded from Deployment Safeguards.
- Deployment Safeguards is in `Enforce` mode.
- The workload doesn't have the `kubernetes.azure.com/managedby=aks` label.

### What the mutator adds

**Label identification**: The mutator identifies pods using the following label priority:

1. `app` label (first priority)
1. `app.kubernetes.io/name` label (second priority)
1. Fallback: Creates a `default-antiaffinity-applabel=<workload-name>` label

**Pod anti-affinity**: Adds a preferred pod anti-affinity rule with weight 100 that prefers to schedule pods with matching labels on different nodes. Uses topology key `kubernetes.io/hostname`.

**Topology spread constraints**: Adds a constraint with the following settings:

| Setting | Value |
|---------|-------|
| MaxSkew | 1 (allows maximum difference of 1 pod per node) |
| WhenUnsatisfiable | ScheduleAnyway (best-effort, doesn't block scheduling) |
| Topology key | `kubernetes.io/hostname` |

### Cases that are mutated

The anti-affinity and topology spread mutator applies changes in the following scenarios:

- **Workloads with `app` label**: Uses the `app` label value for anti-affinity and topology spread selectors.
- **Workloads with `app.kubernetes.io/name` label**: When no `app` label exists, uses this label for selectors.
- **Workloads with no app labels**: Creates a default label using the workload name and adds anti-affinity and topology spread rules.
- **Clean workloads**: Workloads with no existing affinity or topology spread constraints receive both configurations.
- **Partial affinity**: Workloads with existing node affinity (but no pod anti-affinity) receive pod anti-affinity and topology spread rules.
- **Enabled namespaces**: Mutations only occur in namespaces where the safeguard is enabled.

### Cases that aren't mutated

The anti-affinity and topology spread mutator doesn't apply changes in the following scenarios:

- **Existing topology spread constraints**: Workloads that already have any topology spread constraints are skipped entirely.
- **Existing pod anti-affinity**: Workloads with existing required or preferred pod anti-affinity rules are skipped entirely.
- **Excluded namespaces**: Workloads in namespaces where the safeguard is excluded remain unchanged.
- **Workloads without identifiable names or labels**: Edge cases where no app name can be determined are skipped gracefully.

## Deployment Safeguards error messages

This section describes the error messages you might encounter when Deployment Safeguards detects noncompliant configurations, along with recommended fixes.

### General safeguard error messages

The following table lists error messages for general Deployment Safeguards policies:

| Policy | Error message | Fix |
|--------|---------------|-----|
| Enforce Probes | `Container <container_name> in your Pod <pod_name> has no livenessProbe. Required probes: readinessProbe, livenessProbe` | Add liveness and readiness probes to each container. |
| No "Latest" Image | `Please specify an explicit version such as '1.0'. Using the latest tag for container %v in Kubernetes is a best practice to ensure reproducibility, prevent unintended updates, and facilitate easier debugging and rollbacks by using explicit and versioned container images.` | Use an explicit image tag other than `latest` or blank. For example, `nginx` isn't allowed, but `nginx:v1.0.0` is allowed. |
| Enforce CSI Driver | `Storage class <class_name> use intree provisioner kubernetes.io/azure-file is not allowed` or `Storage class <class_name> use intree provisioner kubernetes.io/azure-disk is not allowed` | Use `disk.csi.azure.com` or `file.csi.azure.com` instead. For more information, see [CSI drivers on AKS][csi-drivers-aks]. |
| Resource Requests | `container <container_name> has no resource requests` | Add CPU and memory requests to your container. |
| AntiAffinity Rules | `Deployment with 2 replicas should have either podAntiAffinity or topologySpreadConstraints set to avoid disruptions due to nodes crashing` | Define `podAntiAffinity` or `topologySpreadConstraints` on the workload. |
| Restricted Labels | `Label kubernetes.azure.com is reserved for AKS use only` | Remove the label from your workload. |
| Restricted Node Edits | `Tainting or labelling individual nodes is not recommended. Please use AZ cli to taint/label nodepools instead` | Use the Azure CLI to taint or label node pools instead of individual nodes. |
| Restricted Taints | `Taint with key CriticalAddonsOnly is reserved for the system pool only` | Don't taint the user node pool with `CriticalAddonsOnly`. |

### Pod Security Standards error messages

> [!NOTE]
> Baseline Pod Security Standards are now turned on by default in AKS Automatic. The baseline Pod Security Standards in AKS Automatic can't be turned off.

Deployment Safeguards also supports the ability to turn on [Baseline, Restricted and Privileged Pod Security Standards][pod-security-standards]. To ensure your workloads deploy successfully, make sure each manifest complies with the Baseline or Restricted Pod Security requirements. By default, Azure Kubernetes Service uses Privileged Pod Security Standards.

| Policy | Error message | Fix |
|--------|---------------|-----|
| AppArmor | `AppArmor annotation values must be undefined/nil, runtime/default, or localhost/*` or `AppArmor profile type must be one of: undefined/nil, RuntimeDefault, or Localhost` | Remove any specification of AppArmor. Kubernetes by default applies AppArmor settings. On supported hosts, the RuntimeDefault AppArmor profile is applied by default. |
| Host Namespaces | `Host network namespaces are disallowed: spec.hostNetwork is set to true` or `Host PID namespaces are disallowed: spec.hostPID is set to true` or `Host IPC namespaces are disallowed: spec.hostIPC is set to true` | Set those values to `false`, or remove specifying the fields. |
| Privileged Containers | `Privileged [ephemeral\|init\|N/A] containers are disallowed: spec.containers[*].securityContext.privileged is set to true` | Set the appropriate `securityContext.privileged` field to `false`, or remove the field. |
| Capabilities | Message starts with `Disallowed capabilities detected` | Remove the capability shown from the container's manifest. |
| HostPath Volumes | `HostPath volumes are forbidden under restricted security policy unless containers mounting them are from allowed images` | Remove the HostPath volume and volume mount. |
| Host Ports | `HostPorts are forbidden under baseline security policy` | Remove the host port specification from the offending container. |
| SELinux | `SELinux type must be one of: undefined/empty, container_t, container_init_t, container_kvm_t, or container_engine_t` | Set the container's `securityContext.seLinuxOptions.type` field to one of the allowed values. |
| /proc Mount Type | `ProcMount must be undefined/nil or 'Default' in spec.containers[*].securityContext.procMount` | Set `spec.containers[*].securityContext.procMount` to `Default` or leave it undefined. |
| Seccomp | `Seccomp profile must not be explicitly set to Unconfined. Allowed values are: undefined/nil, RuntimeDefault, or Localhost` | Set `securityContext.seccompProfile.type` on the pod or containers to one of the allowed values. |
| Sysctls | `Disallowed sysctl detected. Only baseline Kubernetes pod security standard sysctls are permitted` | Remove the disallowed sysctls. For the specific list, see the [Kubernetes pod security standards specification][pod-security-standards]. |
| Volume Types (PSS Restricted Only) | `Only the following volume types are allowed under restricted policy: configMap, csi, downwardAPI, emptyDir, ephemeral, persistentVolumeClaim, projected, secret` | Remove any volumes that aren't one of the allowed types. |
| Privilege Escalation (PSS Restricted Only) | `Privilege escalation must be set to false under restricted policy` | Set `spec.containers[*].securityContext.allowPrivilegeEscalation` to `false` for each container, initContainer, and ephemeralContainer. |
| Running as Non-Root (PSS Restricted Only) | `Containers must not run as root user in spec.containers[*].securityContext.runAsNonRoot` | Set `spec.containers[*].securityContext.runAsNonRoot` to `true` for each container, initContainer, and ephemeralContainer. |
| Run as Non-Root User (PSS Restricted Only) | `Containers must not run as root user: spec.securityContext.runAsUser is set to 0` | Set `securityContext.runAsUser` to a nonzero value, or leave it undefined for the pod level and each container, initContainer, and ephemeralContainer. |
| Seccomp (PSS Restricted Only) | `Seccomp profile must be "RuntimeDefault" or "Localhost" under restricted policy` | Set `securityContext.seccompProfile.type` on the pod or containers to one of the allowed values. This differs from the baseline because the restricted policy doesn't allow an undefined value. |
| Capabilities (PSS Restricted Only) | `All containers must drop ALL capabilities under restricted policy` or `Only NET_BIND_SERVICE may be added to capabilities under restricted policy` | All containers must drop `ALL` capabilities and are only permitted to add `NET_BIND_SERVICE`. |

## Enable Deployment Safeguards

>[!NOTE]
> Using the Deployment Safeguards `Enforce` level means you're opting in to deployments being blocked and mutated. Consider how these policies might work with your AKS cluster before enabling `Enforce`.

### Enable Deployment Safeguards on an existing cluster

Enable Deployment Safeguards on an existing cluster that has the Azure Policy add-on enabled using the `az aks safeguard create` command with the `--level` flag. If you want to receive noncompliance warnings, set the `--level` to `Warn`. If you want to deny or mutate all noncompliant deployments, set it to `Enforce`.

```azurecli-interactive
az aks safeguards create --resource-group <resource-group-name> --name <cluster-name> --level Enforce 
```

You can also enable Deployment Safeguards by using the `--cluster` flag and specifying the cluster resource ID.

```azurecli-interactive
az aks safeguards create --cluster <ID> --level Enforce
```

If you want to update the Deployment Safeguards level of an existing cluster, run the following command with the new value for `--level`.

```azurecli-interactive
az aks safeguards update --resource-group <resource-group-name> --name <cluster-name> --level Warn 
```

### Excluding namespaces

You can also exclude certain namespaces from Deployment Safeguards. When you exclude a namespace, activity in that namespace is unaffected by Deployment Safeguards warnings or enforcement.

For example, to exclude the namespaces `ns1` and `ns2`, use a space separated list of namespaces with the `--excluded-ns` flag, as shown in the following example:

```azurecli-interactive
az aks safeguards update --resource-group <resource-group-name> --name <cluster-name> --level Warn --excluded-ns ns1 ns2 
```

### Turn on Pod Security Standards

>[!NOTE]
> Azure Kubernetes Service (AKS) uses `Privileged` Pod Security Standards by default. If you want to revert to the default configuration, set the `--pss-level` flag to `Privileged`.

To enable Pod Security Standards in Deployment Safeguards, use the `--pss-level` flag to select one of the following levels: `Baseline`, `Restricted`, or `Privileged`.

```azurecli-interactive
az aks safeguards update --resource-group <resource-group-name> --name <cluster-name> --level Warn --pss-level <Baseline|Restricted|Privileged>
```

### Update your Deployment Safeguard version

Deployment Safeguards adhere to the [AKS addon versioning scheme][aks-component-versions]. Each new version of a Deployment Safeguard will be released as a new minor version in AKS. These updates will be communicated through the [AKS GitHub release notes][aks-release-notes] and reflected in the "Deployment Safeguards Policies" table in our documentation.

To learn more about AKS versioning and addons, refer to the following documentation: [aks-component-versions] and [aks-versioning-for-addons].

## Verify compliance across clusters

After deploying your Kubernetes manifest, you see warnings or a potential denial message in your CLI or terminal if the cluster isn't compliant with Deployment Safeguards, as shown in the following examples:

**Warn**

```
$ kubectl apply -f deployment.yaml
Warning: [azurepolicy-k8sazurev1antiaffinityrules-ceffa082711831ebffd1] Deployment with 2 replicas should have either podAntiAffinity or topologySpreadConstraints set to avoid disruptions due to nodes crashing
deployment.apps/simple-web created
```

**Enforce**

With Deployment Safeguard mutations, the `Enforce` level mutates your Kubernetes resources when applicable. However, your Kubernetes resources still need to pass all safeguards to deploy successfully. If any safeguard policies fail, your resource is denied and won't be deployed.

```
$ kubectl apply -f deployment.yaml 
Error from server (Forbidden): error when creating "deployment.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8sazurev1antiaffinityrules-ceffa082711831ebffd1] Deployment with 2 replicas should have either podAntiAffinity or topologySpreadConstraints set to avoid disruptions due to nodes crashing
```

If your Kubernetes resources comply with the applicable mutation safeguards and meet all other safeguard requirements, they'll be successfully deployed, as shown in the following example:

```
$ kubectl apply -f deployment.yaml
deployment.apps/simple-web created
```

## Verify compliance across clusters using the Azure Policy dashboard

To verify Deployment Safeguards have been applied and to check on your cluster's compliance, navigate to the Azure portal page for your cluster and select **Policies**, then select **go to Azure Policy**.

From the list of policies and initiatives, select the initiative associated with Deployment Safeguards. You see a dashboard showing compliance state across your AKS cluster.

> [!NOTE]
> To properly assess compliance across your AKS cluster, the Azure Policy initiative must be scoped to your cluster's resource group.

## Disable Deployment Safeguards
 
To disable Deployment Safeguards on your cluster, use the `delete` command.
 
```azurecli-interactive
az aks safeguards delete --resource-group <resource-group-name> --name <cluster-name>
```


## FAQ

#### Can I create my own mutations?

No. If you have an idea for a safeguard, open an issue in the [AKS GitHub repository][aks-gh-repo] and add `[Deployment Safeguards request]` to the beginning of the title.

#### Can I pick and choose which mutations I want in Enforcement?

No. Deployment Safeguards is all or nothing. Once you turn on Warn or Enforce, all safeguards are active.

#### Why did my deployment resource get admitted even though it wasn't following best practices?

Deployment Safeguards enforce best practice standards through Azure Policy controls and has policies that validate against Kubernetes resources. To evaluate and enforce cluster components, Azure Policy extends [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/). Gatekeeper enforcement also currently operates in a [`fail-open` model](https://open-policy-agent.github.io/gatekeeper/website/docs/failing-closed/#considerations). As there's no guarantee that Gatekeeper responds to our networking call, we make sure that in that case, the validation is skipped so that the deny doesn't block your deployments.

To learn more, see [workload validation in Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/workload-resources/).

## Next steps

* Learn more about [best practices][best-practices] for operating an AKS cluster.

<!-- EXTERNAL LINKS -->
[pod-security-standards]: https://kubernetes.io/docs/concepts/security/pod-security-standards/

<!-- LINKS -->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[best-practices]: ./best-practices.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[aks-gh-repo]: https://github.com/Azure/AKS
[aks-release-notes]: https://github.com/Azure/AKS/releases
[policy-for-kubernetes]: /azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks
[deployment-safeguards-list]: https://portal.azure.com/#view/Microsoft_Azure_Policy/InitiativeDetail.ReactView/id/%2Fproviders%2FMicrosoft.Authorization%2FpolicySetDefinitions%2Fc047ea8e-9c78-49b2-958b-37e56d291a44/scopes/
[Azure-Policy-built-in-definition-docs]: /azure/aks/policy-reference#policy-definitions
[Azure-Policy-compliance-portal]: https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance
[Azure-Policy-RBAC-permissions]: /azure/governance/policy/overview#azure-rbac-permissions-in-azure-policy
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[aks-component-versions]: ./supported-kubernetes-versions.md
[aks-versioning-for-addons]: ./integrations.md#add-ons
[csi-drivers-aks]: ./csi-storage-drivers.md
