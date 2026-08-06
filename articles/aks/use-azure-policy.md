---
title: Use Azure Policy to secure your Azure Kubernetes Service (AKS) clusters
description: Learn how to use Azure Policy to secure your Azure Kubernetes Service (AKS) clusters.
ms.topic: how-to
ms.subservice: aks-security
ms.date: 06/30/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.custom: template-how-to
zone_pivot_groups: portal-terraform

# Customer intent: "As a Kubernetes administrator, I want to apply security policies to my AKS clusters using Azure Policy, so that I can enforce organizational standards and ensure compliance across my container deployments."
---

# Secure your Azure Kubernetes Service (AKS) clusters with Azure Policy

You can apply and enforce built-in security policies on your Azure Kubernetes Service (AKS) clusters by using [Azure Policy][azure-policy]. Azure Policy helps you enforce organizational standards and assess compliance at scale. After you install the [Azure Policy add-on for AKS][kubernetes-policy-reference], you can apply individual policy definitions or groups of policy definitions called initiatives (sometimes called policysets) to your cluster. For a complete list of AKS policy and initiative definitions, see [Azure Policy built-in definitions for AKS][aks-policies].

This article shows you how to apply policy definitions to your cluster and verify that the assignments are enforced.

## Prerequisites

:::zone pivot="azure-portal"

- This article assumes you have an existing AKS cluster. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or [Azure portal][aks-quickstart-portal].
- You need the [Azure Policy add-on for AKS installed on your AKS cluster][azure-policy-addon].

:::zone-end

:::zone pivot="terraform"

You need the following resources installed and configured before you begin:

- This article assumes you have an existing AKS cluster. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or [Azure portal][aks-quickstart-portal].
- You need the [Azure Policy add-on for AKS installed on your AKS cluster][azure-policy-addon].
- Terraform version 1.6.0 or later.
- Azure CLI version 2.47.0 or later. To install or update the Azure CLI, see [Install Azure CLI][azure-cli-install].
- Kubectl installed and configured.

:::zone-end

## Assign a built-in policy definition or initiative

:::zone pivot="azure-portal"

You can apply a policy definition or initiative in the Azure portal by using the following steps:

1. Go to the Azure Policy service in the Azure portal called **Policy**.
1. In the left pane of the Azure Policy page, select **Definitions**.
1. Under **Categories**, select `Kubernetes`.
1. Choose the policy definition or initiative you want to apply. For this example, select the **Kubernetes cluster pod security baseline standards for Linux-based workloads** initiative.
1. Select **Assign**.
1. Set the **Scope** to the resource group of the AKS cluster with the Azure Policy add-on enabled.
1. Select the **Parameters** page and update the **Effect** from `audit` to `deny` to block new deployments that violate the baseline initiative. You can also add extra namespaces to exclude from evaluation. For this example, keep the default values.
1. Select **Review + create** > **Create** to submit the policy assignment.

:::zone-end


:::zone pivot="terraform"

Create a directory for the Terraform configuration.

```bash
mkdir aks-use-azure-policy
cd aks-use-azure-policy
```

### Create the Terraform configuration

Create a file named `main.tf`.

```bash
touch main.tf
```

Open the `main.tf` file and add the following configuration.

### Configure the Terraform provider

The following configuration:

- Defines the Terraform version.
- Configures the AzureRM provider.
- Enables Azure provider features required for resource management.

```terraform
terraform {
 required_version = ">= 1.6.0"
 required_providers {
   azurerm = {
     source  = "hashicorp/azurerm"
     version = "~> 4.0"
   }
 }
}
provider "azurerm" {
 features {}
}
```

### Define input variables

Use the following variables to provide the name of the existing resource group and AKS cluster during deployment.

```terraform
variable "resource_group_name" {
 description = "Name of the resource group that contains the existing AKS cluster."
 type        = string
}
variable "aks_cluster_name" {
 description = "Name of the existing AKS cluster."
 type        = string
}
```

### Reference the existing AKS cluster

The following data sources retrieve information about the existing resource group and AKS cluster. Terraform uses this data to reference infrastructure that already exists in Azure instead of creating new resources.

```terraform
data "azurerm_resource_group" "aks" {
 name = var.resource_group_name
}
data "azurerm_kubernetes_cluster" "aks" {
 name                = var.aks_cluster_name
 resource_group_name = data.azurerm_resource_group.aks.name
}
```

:::zone-end


:::zone pivot="azure-portal, terraform"

### Optional: Create and assign a custom policy definition

The custom policy definition section is informational and is outside the scope of this article. Custom policies allow you to define rules for using Azure. For example, you can enforce the following types of rules:

- Security practices.
- Cost management.
- Organization-specific rules, like naming conventions or locations.

Before creating a custom policy, check the [list of common patterns and samples][azure-policy-samples] to see if your case is already covered.

Custom policy definitions are written in JSON. To learn more about creating a custom policy, see [Azure Policy definition structure][azure-policy-definition-structure] and [Create a custom policy definition][custom-policy-tutorial-create].

> [!NOTE]
> Azure Policy uses a property named _templateInfo_ that you can use to define the source type for the constraint template. When you define _templateInfo_ in policy definitions, you can't use _constraintTemplate_ or _constraint_ properties. You still need to define _apiGroups_ and _kinds_. For more information, see [Understanding Azure Policy effects][azure-policy-effects-audit].

After you create your custom policy definition, see [Assign a policy definition][custom-policy-tutorial-assign] for a step-by-step walkthrough to assign the policy to your cluster.

:::zone-end


## Validate an Azure Policy is running

:::zone pivot="azure-portal"

Confirm the policy assignments are applied to your cluster by using the following `kubectl get` command.

```azurecli-interactive
kubectl get constrainttemplates
```

> [!NOTE]
> Policy assignments can take [up to 20 minutes to sync][azure-policy-assign-policy] into each cluster.

Your output should be similar to the following example output:

```output
NAME                                     AGE
k8sazureallowedcapabilities              23m
k8sazureallowedusersgroups               23m
k8sazureblockhostnamespace               23m
k8sazurecontainerallowedimages           23m
k8sazurecontainerallowedports            23m
k8sazurecontainerlimits                  23m
k8sazurecontainernoprivilege             23m
k8sazurecontainernoprivilegeescalation   23m
k8sazureenforceapparmor                  23m
k8sazurehostfilesystem                   23m
k8sazurehostnetworkingports              23m
k8sazurereadonlyrootfilesystem           23m
k8sazureserviceallowedports              23m
```

### Validate rejection of a privileged pod

Test what happens when you schedule a pod with the security context of `privileged: true`. This security context escalates the pod's privileges. The initiative disallows privileged pods, so the request is denied, which results in the deployment being rejected.

1. Create a file named `nginx-privileged.yaml` and paste in the following YAML manifest.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx-privileged
    spec:
      containers:
        - name: nginx-privileged
          image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
          securityContext:
            privileged: true
    ```

1. Create the pod by using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```azurecli-interactive
    kubectl apply -f nginx-privileged.yaml
    ```

    As expected, the pod fails to be scheduled, as shown in the following example output:

    ```output
    Error from server ([denied by azurepolicy-container-no-privilege-00edd87bf80f443fa51d10910255adbc4013d590bec3d290b4f48725d4dfbdf9] Privileged container is not allowed: nginx-privileged, securityContext: {"privileged": true}): error when creating "privileged.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [denied by azurepolicy-container-no-privilege-00edd87bf80f443fa51d10910255adbc4013d590bec3d290b4f48725d4dfbdf9] Privileged container is not allowed: nginx-privileged, securityContext: {"privileged": true}
    ```

    The pod doesn't reach the scheduling stage, so there are no resources to delete before you move on.

### Test creation of an unprivileged pod

In the previous example, the container image automatically tried to use root to bind `NGINX` to port 80. The policy initiative denies this request, so the pod fails to start. Now, try running that same `NGINX` pod without privileged access.

1. Create a file named `nginx-unprivileged.yaml` and paste the following YAML manifest into it.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx-unprivileged
    spec:
      containers:
        - name: nginx-unprivileged
          image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
    ```

1. Create the pod by using the [`kubectl apply`][kubectl-apply] command and specify the name of your YAML manifest.

    ```azurecli-interactive
    kubectl apply -f nginx-unprivileged.yaml
    ```

1. Check the status of the pod by using the [`kubectl get pods`][kubectl-get] command.

    ```azurecli-interactive
    kubectl get pods
    ```

    Your output should be similar to the following example output, which shows the pod is successfully scheduled and has a status of _Running_:

    ```output
    NAME                 READY   STATUS    RESTARTS   AGE
    nginx-unprivileged   1/1     Running   0          18s
    ```

    This example shows the baseline initiative affecting only the deployments that violate policies in the collection. Allowed deployments continue to function.

1. Delete the `NGINX` unprivileged pod by using the [`kubectl delete`][kubectl-delete] command and specify the name of your YAML manifest.

    ```azurecli-interactive
    kubectl delete -f nginx-unprivileged.yaml
    ```

:::zone-end


:::zone pivot="terraform"

Use the following steps to assign a built-in Azure Policy initiative to your AKS cluster by using Terraform.

### Retrieve the built-in Azure Policy initiative

The following data source retrieves the built-in Azure Policy initiative for Kubernetes pod security baseline standards.

```terraform
data "azurerm_policy_set_definition" "aks_pod_security_baseline" {
 display_name = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
}
```

### Assign the Azure Policy initiative

The following resource assigns the built-in Azure Policy initiative to the resource group that contains the AKS cluster.

Set the policy effect to `Deny` to block workloads that violate the defined policy rules.

```terraform
resource "azurerm_resource_group_policy_assignment" "aks_pod_security_baseline" {
 name                 = "aks-pod-security-baseline"
 display_name         = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
 resource_group_id    = data.azurerm_resource_group.aks.id
 policy_definition_id = data.azurerm_policy_set_definition.aks_pod_security_baseline.id
 parameters = jsonencode({
   effect = {
     value = "Deny"
   }
 })
}
```

### Initialize the Terraform configuration

Run `terraform init` to initialize the Terraform working directory and download the required provider plugins.

```bash
terraform init
```

### Format and validate the configuration

Run `terraform fmt` to format the Terraform configuration.

```bash
terraform fmt
```

Run `terraform validate` to validate the Terraform configuration syntax.

```bash
terraform validate
```

### Apply the Terraform configuration

Before deploying the configuration, provide values for the following variables:

- `resource_group_name`
- `aks_cluster_name`

Run `terraform apply` to deploy the Azure Policy assignment.

```bash
terraform apply
```

When prompted, enter `yes` to confirm the deployment.

### Verify the Azure Policy installation

After deployment completes, verify that the Azure Policy components are running in the AKS cluster.

```bash
kubectl get pods -n kube-system
```

Verify that the Gatekeeper constraint templates were installed successfully.

```bash
kubectl get constrainttemplates
```

### Test the Azure Policy assignment

Create a file named `privileged-pod.yaml`.

```yaml
apiVersion: v1
kind: Pod
metadata:
 name: privileged-pod
spec:
 containers:
 - name: nginx
   image: nginx
   securityContext:
     privileged: true
```

Apply the manifest to the cluster.

```bash
kubectl apply -f privileged-pod.yaml
```

The deployment fails because the Azure Policy assignment denies privileged containers that violate the configured pod security baseline standards.

:::zone-end


:::zone pivot="azure-portal, terraform"

## Disable a policy or initiative

Remove the baseline initiative in the Azure portal by using the following steps:

1. Go to the **Policy** pane in the Azure portal.
1. Select **Assignments**.
1. Select the ellipsis (`...`) at the end of the line for **Kubernetes cluster pod security baseline standards for Linux-based workload** initiative.
1. Select **Delete assignment**.

To remove the Azure Policy add-on from your AKS cluster, see [Remove the add-on][azure-policy-addon-remove].

## Next steps

For more information about how Azure Policy works, see the following articles:

- [Azure Policy overview][azure-policy]
- [Azure Policy initiatives and policies for AKS][aks-policies]
- [Remove the add-on][azure-policy-addon-remove]

:::zone-end


<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[aks-policies]: policy-reference.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[azure-policy]: /azure/governance/policy/overview
[azure-policy-addon]: /azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks
[azure-policy-addon-remove]: /azure/governance/policy/concepts/policy-for-kubernetes#remove-the-add-on-from-aks
[azure-policy-assign-policy]: /azure/governance/policy/concepts/policy-for-kubernetes#assign-a-policy-definition
[kubernetes-policy-reference]: /azure/governance/policy/concepts/policy-for-kubernetes
[azure-policy-effects-audit]: /azure/governance/policy/concepts/effect-audit#audit-properties
[custom-policy-tutorial-create]: /azure/governance/policy/tutorials/create-custom-policy-definition
[custom-policy-tutorial-assign]: /azure/governance/policy/concepts/policy-for-kubernetes#assign-a-policy-definition
[azure-policy-samples]: /azure/governance/policy/samples/
[azure-policy-definition-structure]: /azure/governance/policy/concepts/definition-structure
