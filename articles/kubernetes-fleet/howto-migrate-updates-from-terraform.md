---
title: "Migrate Kubernetes updates to Azure Kubernetes Fleet Manager from Terragrunt and Terraform"
description: "Learn how to migrate Kubernetes updates from Terragrunt and Terraform to Azure Kubernetes Fleet Manager Update Runs."  
ms.topic: how-to
ms.date: 07/14/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a fleet administrator, I want to migrate my Kubernetes update process from Terragrunt and Terraform to Azure Kubernetes Fleet Manager Update Runs, so that I can manage updates more efficiently."
---

# Migrate Kubernetes updates to Azure Kubernetes Fleet Manager from Terragrunt and Terraform

Operators of multi-cluster environments often use Terragrunt and Terraform to manage Kubernetes updates across their clusters. Cluster update order is defined using a folder structure in a Git repository or in configuration files or scripts, using Terragrunt as the orchestration tool.

In smaller environments this approach can be manageable, but as the number and size of clusters grows, so does the complexity of cluster updates. Long-running update processes place a burden on operations teams as they're required to monitor progress of updates across multiple clusters in multiple environments, using disconnected tools and processes. 

Over time, the overhead of managing updates results in less frequent updates resulting in clusters out of support or facing complicated multi-version Kubernetes updates.

Azure Kubernetes Fleet Manager [Update Runs][learn-update-run] provide operators with a safe way to reduce the complexity of multi-cluster updates. Update Runs allow operators to define update strategies to ensure safe ordering of updates across clusters in a single operation. Update Runs support large environments that have hundreds of clusters which can take multiple days or weeks to complete.

This article explains how to migrate to Azure Kubernetes Fleet Manager Update Runs from an existing Kubernetes update process based on Terragrunt and Terraform.

## Benefits of using Fleet Manager Update Runs

Using Fleet Manager Update Runs to manage Kubernetes updates across your clusters provides the following benefits:

- **Automated or manual updates**: update runs can be used to manually update clusters at any time, or you can automate the update process using auto-upgrade. Auto-upgrade creates and executes update runs automatically when AKS releases new Kubernetes versions.
- **Define the order of updates**: build reusable strategies that define the order for cluster updates. Update strategies provide confidence that lower environments are updated first, limiting the blast radius of unexpected issues.
- **Add new clusters easily**: new clusters can be included in update runs by populating the update group for a cluster. If the group is already defined in the update strategy, the cluster is automatically included in the next update run. You can move (or remove) clusters from update runs by modifying the update group at any time.
- **Durable across days and weeks**: update runs are designed to handle long-running updates, allowing you to update hundreds of clusters that can take multiple days or even weeks to complete.
- **Update more than just Kubernetes**: update runs can be used to update more than just Kubernetes, allowing you to also update the node image version of your clusters.
- **Honor maintenance windows**: update runs automatically respect the maintenance windows defined for each cluster, ensuring updates are only applied when it's safe to.
- **Monitoring and alerting**: [built-in monitoring and alerting capabilities][update-run-alerts] allow you to track the progress of update runs and receive notifications when updates fail or complete.

> [!NOTE]
> If you aren't already familiar with Fleet Manager Update Runs, read the [Update Run documentation][learn-update-run] before reading this article.

## Example multi-cluster environment using Terragrunt and Terraform

To help illustrate how to migrate to Fleet Manager we have an example multi-cluster environment using Terragrunt and Terraform to manage Azure Kubernetes Service (AKS) clusters. The following folder structure is used to hold the Terraform and Terragrunt configuration files.

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
    source = "../../../modules/aks"
}

inputs = {
    cluster_name        = "aks-dev-cluster-01"
    location            = "australiaeast"
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
    source = "../../../modules/aks"
}

inputs = {
    cluster_name        = "aks-prod-cluster-01"
    location            = "australiaeast"
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

Let's update the Kubernetes version of both clusters to `1.31.1` using Terragrunt.

We want to make sure we apply the update to our development cluster before production. Additionally, we want to track the state of our cluster configurations, so we add a `kubernetes_version` variable to our Terragrunt configuration files rather than supplying it as a command line argument.

```terraform
# dev/aks/terragrunt.hcl
terraform {
    source = "../../../modules/aks"
}

inputs = {
    cluster_name        = "aks-dev-cluster-01"
    location            = "australiaeast"
    resource_group_name = "rg-dev-aks"
    kubernetes_version  = "1.31.1"  # <-- Updated version
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

Once the development cluster is updated and tested as working, we can update our production cluster using the same process.

We can also update all individual hcl files (or the main.tf file) and then `apply-all`, using Terragrunt `dependencies` or `dependency` blocks to control the ordering of clusters.

However, more than a few clusters or environments means the folder structure, configuration files and process can become unwieldy and prone to human error. It also becomes hard to visualize the actual state of your clusters compared to the desired state held in your config files and Git repository.

## Migrating to Fleet Manager Update Runs

Let's look at how we can move our existing approach to use Fleet Manager update runs, then enable automated upgrades. For this article, let's perform the same update we just did, but using Fleet Manager Update Runs instead of Terragrunt and Terraform.

If you prefer to use the Azure portal, you can follow the [update clusters using groups and stages][update-run-portal-cli] documentation.

> [!NOTE]
> Once you start using Fleet Manager Update Runs, you should remove Kubernetes version update support from your Terragrunt and Terraform configurations.

### Create a Fleet Manager resource and add clusters as members

Define a Fleet Manager resource using Terraform. The Fleet Manager resource can be in any resource group or Azure subscription as long as the Entra ID tenant is the same as the clusters you want to manage.

```terraform
provider "azurerm" {
  features {}
}

resource "azurerm_kubernetes_fleet_manager" "fleet" {
    location            = "australiaeast"
    name                = "flt-demo-01"
    resource_group_name = "rg-fleet-01"
}
```

Next, we need to add our clusters as members of the Fleet Manager, creating a `azurerm_kubernetes_fleet_member` resource for each cluster. We also assign an update group when creating the member. The update group is optional, but allows the cluster to be included in update runs that use strategies.

```terraform

# We're assuming all resources are in the same Azure subscription

# Reference existing AKS clusters
resource "azurerm_kubernetes_cluster" "dev_cluster" {
    name                = "aks-dev-cluster-01"
    resource_group_name = "rg-dev-aks"
}

resource "azurerm_kubernetes_cluster" "prod_cluster" {
    name                = "aks-prod-cluster-01"
    resource_group_name = "rg-prod-aks"
}

# Create member clusters and assign update groups
resource "azurerm_kubernetes_fleet_member" "dev_cluster_member" {
    kubernetes_cluster_id = dev_cluster.id
    kubernetes_fleet_id   = fleet_demo_01.id
    name                  = "mbr-dev-cluster-01"
    group                 = "dev"
}

resource "azurerm_kubernetes_fleet_member" "prod_cluster_member" {
    kubernetes_cluster_id = prod_cluster.id
    kubernetes_fleet_id   = fleet_demo_01.id
    name                  = "mbr-prod-cluster-01"
    group                 = "prod"
}
```    

### Create an update strategy

Next, we need to create an update strategy that defines the ordering of clusters to update. Update strategies can be reused across multiple update runs. As an example, you can do Kubernetes and node image updates separately, but using the same strategy.

The strategy can be defined using a `azurerm_kubernetes_fleet_update_strategy` resource. Stages are executed sequentially and groups within a stage are executed in parallel. The `after_stage_wait_in_seconds` property allows you to define a wait time on stage completion before the next stage starts, which is useful for testing or validation before proceeding to the next stage.

```terraform
resource "azurerm_kubernetes_fleet_update_strategy" "tg_migration_strategy" {
    name                        = "tg-migration-strategy"
    kubernetes_fleet_manager_id = azurerm_kubernetes_fleet_manager.fleet.id
    stage {
        name = "stg-pre-prod"
        group {
            name = "dev"
        }
        after_stage_wait_in_seconds = 3600
    }
    stage {
        name = "stg-prod"
        group {
          name = "prod"
        }
    }
}
```

### Create an update run

Now we can create an update run that uses the strategy we defined. The `azurerm_kubernetes_fleet_update_run` resource allows us to specify the strategy and the clusters to be updated.

```terraform
resource "azurerm_kubernetes_fleet_update_run" "update_run_tg_migration_131" {
    name                        = "update_run_tg_migration_131"
    kubernetes_fleet_manager_id = azurerm_kubernetes_fleet_manager.fleet.id
    managed_cluster_update {
        upgrade {
            type               = "Full"
            kubernetes_version = "1.31.1"
        }
        node_image_selection {
            type = "Consistent"
        }
    }
    fleet_update_strategy_id = azurerm_kubernetes_fleet_update_strategy.tg_migration_strategy.id
}
```

### Execute the update run

You can use Terraform execute the update run via a `null_resource` with a `local-exec` provisioner as shown. Depending on your configuration, the arguments being passed will change.

```terraform
resource "null_resource" "trigger_update_run" {
  provisioner "local-exec" {
    command = "az fleet updaterun start --resource-group ${azurerm_kubernetes_fleet_manager.fleet.resource_group_name} --fleet-name ${azurerm_kubernetes_fleet_manager.fleet.name} --name ${azurerm_kubernetes_fleet_update_run.update_run_tg_migration_131.name}"
  }

  depends_on = [azurerm_kubernetes_fleet_update_run.update_run_tg_migration_131]
}

```

You can also use the Azure portal or Azure CLI to start the update run. For more information, see [Manage an update run][manage-update-run].

### Enable auto-upgrade

Once you're familiar with update runs, you can [enable auto-upgrade][fleet-auto-upgrade] for your clusters. Auto-upgrade automatically creates and executes update runs when AKS releases new Kubernetes versions. This means you no longer need to monitor for new Kubernetes versions and manually create update runs.

> [!NOTE]
> Auto-upgrade supports Stable and Rapid Kubernetes release channels today, and automatically increments the Kubernetes minor when a new minor is released. If you want to remain on a specific Kubernetes minor, you shouldn't currently use auto-upgrade. Support for target Kubernetes version for auto-upgrade is under development. Track target minor version support on the [Fleet Manager roadmap](https://github.com/Azure/AKS/issues/4603).

## Related content

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).
* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).
* [Multi-cluster updates FAQs](./faq.md#multi-cluster-updates---automated-or-manual-faqs).

<!-- LINKS -->
[learn-update-run]: ./update-orchestration.md
[update-run-portal-cli]: ./update-orchestration.md#update-clusters-using-groups-and-stages
[manage-update-run]: ./update-orchestration.md#manage-an-update-run
[fleet-auto-upgrade]: ./update-automation.md
[update-run-alerts]: ./howto-monitor-update-runs.md