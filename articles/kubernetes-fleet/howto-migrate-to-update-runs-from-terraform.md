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

Operators of multi-cluster Kubernetes environments often use Terragrunt and Terraform to manage upgrades across their clusters. Ordering of updates of clusters is maintained through use of a folder structure held in a Git repository and ordering in any script-based orchestration.

In smaller scale environments this approach can be manageable, but as the number and size of clusters grows, so does the complexity of this process. Long-running update processes place an overhead on the operations team as they are required to monitor the progress of updates across multiple clusters, using multiple tools and processes. 

Over time, these challenges result in less frequent updates, leading to clusters running out of support, or facing impactful updates due to breaking changes or urgent timelines that could have been avoided with a more regular update cadence.

Azure Kubernetes Fleet Manager provides a more efficient way to manage updates across multiple clusters, allowing you to define update strategies and safely run updates across your fleet of clusters in a single operation. Update Runs support large environment updates with confidence, handling hundreds of clusters that can take multiple days or even weeks to update.

This article explains how to migrate to Azure Kubernetes Fleet Manager Update Runs with auto-upgrade from an existing process based on Terragrunt and Terraform.

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

Fist, we have our Terraform definition for creation of an Azure Kubernetes Service (AKS) cluster.

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

Next, we have our development cluster Terragrunt configuration.

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

Our production Terragrunt definition is similar, but with different values for the cluster name, resource group, and tags.

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

Let's go ahead and deploy the clusters using Terragrunt.

```bash
terragrunt apply-all
```

Two AKS clusters are deployed, one named and tagged as `dev` and one as `prod`, with each having the Kubernetes version set to `1.30.2` (the default value).

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
    kubernetes_version  = "1.31.0"  # <-- Updated version
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

Once the development cluster has been tested, we can update our production cluster using the same process.

There are other ways to achieve this upgrade that allows a global `apply-all` by using Terragrunt `dependencies` or `dependency` blocks to control the order. However, once there are more that a small number of clusters or environments, the complexity of the folder structure and configuration files can become unwieldy and prone to human error. It also becomes hard to visualize the state of your clusters compared to the configuration held in your Git repository.

## Migrating to Fleet Manager Update Runs

Let's look at how we can move our existing approach to use Fleet Manager update runs, then enable automated upgrades. 

### Create a Fleet Manager resource

Define a Fleet Manager resource using Terraform. The Fleet Manager resource an be in any resource group or Azure subscription as long as the Entra ID tenant is the same as the clusters you want to manage.

```terraform
# main.tf
provider "azurerm" {
  features {}
}

resource "azurerm_kubernetes_fleet_manager" "fleet_demo_01" {
  location            = azurerm_resource_group.fleet_rg.location
  name                = coalesce(var.fleet_name, random_string.fleet_name.result)
  resource_group_name = azurerm_resource_group.fleet_rg.name
}
```

Next, we need to add our clusters as members of the Fleet Manager resource. We can do this by creating a `azurerm_kubernetes_fleet_member` resource for each cluster. Note that we also assign an update group when creating the member. The update group is optional, but allows the cluster to be included in update runs that use strategies.

```terraform

# We're assuming all resources are in the same Azure subscription

data "azurerm_kubernetes_cluster" "dev_cluster" {
  name                = "aks-dev-cluster-01"
  resource_group_name = "rg-dev-aks"
}

data "azurerm_kubernetes_cluster" "prod_cluster" {
    name                = "aks-prod-cluster-01"
    resource_group_name = "rg-prod-aks"
}

# Add dev cluster as member, assign 'dev' update group
resource "azurerm_kubernetes_fleet_member" "dev_cluster_member" {
    kubernetes_cluster_id = dev_cluster.id
    kubernetes_fleet_id   = fleet_demo_01.id
    name                  = "member-dev-cluster-01"
    group                 = "dev"
}

# Add prod cluster as member, assign 'dev' update group
resource "azurerm_kubernetes_fleet_member" "prod_cluster_member" {
    kubernetes_cluster_id = prod_cluster.id
    kubernetes_fleet_id   = fleet_demo_01.id
    name                  = "member-prod-cluster-01"
    group                 = "prod"
}
```    



## Related content

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- LINKS -->
[learn-update-run]: ./update-orchestration.md
