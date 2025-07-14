---
title: "Migrate Kubernetes upgrades from Terragrunt and Terraform to Azure Kubernetes Fleet Manager Update Runs"
description: "Learn how to migrate Kubernetes upgrades from Terragrunt and Terraform to Azure Kubernetes Fleet Manager Update Runs."  
ms.topic: how-to
ms.date: 07/14/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a fleet administrator, I want to migrate my Kubernetes upgrades from Terragrunt and Terraform to Azure Kubernetes Fleet Manager Update Runs, so that I can manage updates more efficiently."
---

# Migrate to Fleet Manager update runs from Terragrunt and Terraform for Kubernetes upgrades

Operators of multi-cluster Kubernetes environments often use Terragrunt and Terraform to manage upgrades across their clusters, ensuring ordering of updates of clusters through use of a folder structure held in a Git repository. In smaller scale environments this can be manageable, but as the number and size of clusters grows, so does the complexity of managing updates, especially in highly regulated environments requiring frequent updates. Long-running update processes place an overhead on the operations team as they are required to monitor the progress of updates across multiple clusters, using multiple tools and processes.

Azure Kubernetes Fleet Manager provides a more efficient way to manage updates across multiple clusters, allowing you to define update strategies and safely run updates across your fleet of clusters in a single operation. Update Runs allow large environment updates with confidence, handling hundreds of clusters that can take multiple hours, days or even weeks to complete updating.

This article explains how to migrate from a process based on Terragrunt and Terraform to one use Azure Kubernetes Fleet Manager Update Runs with auto-upgrade.

## Benefits of using Fleet Manager Update Runs

Using Fleet Manager Update Runs to manage updates across your clusters provides the following benefits:

- **Manual and automated updates**: update runs can be used to manually update clusters at any time, or you can automate the update process using auto-upgrade. Auto-upgrade creates and executes update runs automatically when new Kubernetes versions are released by AKS.
- **Define the order of updates**: build reusable strategies that define the order in which clusters are updated. Update strategies provide confidence that lower order environments will be updated first, limiting the blast radius of unexpected issues.
- **Add new clusters easily**: new clusters can be included in update runs by populating the upgrade group for a cluster when it is added. If the group is already defined in the update run strategy, the cluster is automatically included in the next update run. You can move (or remove) clusters from update runs by updating the upgrade group at any time.
- **Durable across days and weeks**: update runs are designed to handle long-running updates, allowing you to update hundreds of clusters that can take multiple days or even weeks to complete.
- **Update more than just Kubernetes**: update runs can be used to update more than just Kubernetes, allowing you to also update the node image version your clusters.
- **Honor maintenance windows**: update runs automatically respect the maintenance windows defined for each cluster, ensuring updates are only applied when it is safe to.
- **Monitoring and alerting**: built-in monitoring and alerting capabilities allow operators to track the progress of update runs and receive notifications when updates fail or complete.

> [!NOTE]
> If you aren't already familiar with Fleet Manager Update Runs, read the [Update Run documentation][learn-update-run] before reading this article.

## Example multi-cluster environment using Terragrunt and Terraform

We will use a simple example of a multi-cluster environment using Terragrunt and Terraform to manage an Azure Kubernetes Service (AKS) cluster. The following folder structure is used to hold the Terraform and Terragrunt configuration files.

```
├── environments/
│   ├── dev/
│   │   └── aks/
│   │       └── terragrunt.hcl
│   └── prod/
│       └── aks/
│           └── terragrunt.hcl
|
└── modules/
    └── aks/
        └── main.tf
```

Fist, we have our Terraform definition for our Azure Kubernetes Service (AKS) cluster. This is a simplified example of how you might define an AKS cluster using Terraform.

```terraform
# main.tf
variable "kubernetes_version" {
    type    = string
    default = "1.30.2"
}

resource "azurerm_kubernetes_cluster" "aks" {
    name                = var.cluster_name
    location            = var.location
    resource_group_name = var.resource_group_name
    dns_prefix          = var.cluster_name
    
    default_node_pool {
        name       = "default"
        node_count = 3
        vm_size    = "Standard_DS2_v2"
    }
    
    kubernetes_version = var.kubernetes_version
    
    identity {
        type = "SystemAssigned"
    }
    
    tags = var.tags
}
```

Next, we have our Terragrunt configuration that uses the above Terraform module to create an AKS cluster.

```terraform
# dev/aks/terragrunt.hcl
terraform {
    source = "../../modules/aks"
}

inputs = {
    cluster_name        = "aks-dev-cluster-01"
    location            = "Australia East"
    resource_group_name = "rg-dev-aks"
    tags = {
        environment = "dev"
    }
}
```

Our production definition is similar, but with different values for the cluster name, resource group, and tags.

```terraform
# prod/aks/terragrunt.hcl
terraform {
    source = "../../modules/aks"
}

inputs = {
    cluster_name        = "aks-prod-cluster-01"
    location            = "Australia East"
    resource_group_name = "rg-prod-aks"
    tags = {
        environment = "prod"
    }
}
```

Let's go ahead and deploy all the clusters using Terragrunt.

```bash
terragrunt apply-all
```

We now have two AKS clusters deployed, one named and tagged as `dev` and one as `prod`, with each having the Kubernetes version set to `1.30.2` (the default value).

### Update the Kubernetes version using Terragrunt

Let's upgrade the Kubernetes version of both clusters to `1.31.0` using Terragrunt.

We want to make sure we apply the update to our development cluster before production. Additionally, we want to track the state of our cluster configurations, so we add a `kubernetes_version` variable to our Terragrunt configuration files rather than supplying it as a command line argument.

```terraform
# dev/aks/terragrunt.hcl
terraform {
    source = "../../modules/aks"
}

inputs = {
    cluster_name        = "aks-dev-cluster-01"
    location            = "Australia East"
    resource_group_name = "rg-dev-aks"
    kubernetes_version  = "1.31.0"
    tags = {
        environment = "dev"
    }
}
```

Let's go ahead and apply the update to our development cluster.

```bash
# Navigate to the dev/aks directory
cd environments/dev/aks
# Apply the update to the development cluster
terragrunt apply
```

Once the development cluster has been tested, I can then apply the same update to the production cluster by using the same process.


## Related content

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- LINKS -->
[learn-update-run]: ./update-orchestration.md
[rest-api-statuses]: /rest/api/fleet/update-runs/get#updatestate
[kusto-query-docs]: /kusto/query
[kusto-mv-expand]: /kusto/query/mv-expand-operator
[kusto-json-parse]: /kusto/query/parse-json-function
[monitor-log-search]: /azure/azure-monitor/alerts/alerts-create-log-alert-rule
[monitor-set-up-action-group]: /azure/azure-monitor/alerts/action-groups#create-an-action-group-in-the-azure-portal