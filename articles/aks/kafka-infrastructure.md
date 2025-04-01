---
title: Prepare the infrastructure for deploying Kafka on Azure Kubernetes Service (AKS)  
description: In this article, you prepare the infrastructure for deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.  
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
zone_pivot_groups: azure-cli-or-terraform
---

# Prepare the infrastructure for deploying Kafka on Azure Kubernetes Service (AKS)  

In this article, you prepare the infrastructure for deploying a Kafka cluster on Azure Kubernetes Service (AKS).  

## Architecture overview

The target AKS architecture for Kafka deployment prioritizes high availability through a comprehensive zone-redundant design. The design requires three node pools—one per availability zone—to maintain workload distribution and storage alignment. This zonal configuration is critical because persistent volumes in this architecture have zonal affinity. Any new nodes that are provisioned with cluster autoscaler must be created in the appropriate zone. Without this zonal specificity, pods with zone-bound persistent volumes would remain in a pending state. Multiple replicas of the Strimzi Cluster Operator and Kafka broker instances are defined and distributed across zones, providing resilience against both node and entire zone failures within the target region. To prevent resource contention and ensure predictable performance, dedicated node pools for Kafka workloads are strongly recommended. 

## Prerequisites  

* If you haven't already, review the [Overview for deploying Kafka on Azure Kubernetes Service (AKS) using Strimzi](./kafka-overview.md).  
* Terraform v1.3.0 or later installed.  
* Azure CLI installed and authenticated.  
* Sufficient permissions to create infrastructure resources and assign RBAC to managed identities: Network Contributor, Azure Kubernetes Service Contributor, and Role Based Access Control Administrator.  

## Deploy infrastructure  

The following steps guide you through deploying the AKS cluster and supporting infrastructure needed for your Kafka deployment.


> [!TIP]  
> **If you have an existing AKS cluster or existing supporting infrastructure**: You can skip the full deployment steps or make code adjustments, but ensure your infrastructure and AKS cluster meets the following requirements:  
>  
> * Virtual network with subnet for nodes
> * [Azure Container Storage installed](/azure/storage/container-storage/container-storage-aks-quickstart#install-azure-container-storage-and-create-a-storage-pool) on the AKS cluster.  
> * Node pool per availability zone (1, 2, and 3).  
> * Dedicated node pools for Kafka with [appropriate VM sizes](./kafka-overview.md#node-pools) based on your workload's requirements.  
> * Azure Managed Prometheus and Azure Managed Grafana configured.

::: zone pivot="azure-cli"  

### Set environment variables

Before running any CLI commands, set the environment variables that will be used throughout this guide with values that meet your requirements.

    ```bash 
    export RESOURCE_GROUP_NAME="rg-kafka"  
    export LOCATION="eastus"  
    export VNET_NAME="vnet-aks-kafka"  
    export SUBNET_NAME="node-subnet"  
    export AKS_CLUSTER_NAME="aks-kafka-cluster"  
    export AKS_TIER=standard
    export NAT_GATEWAY_NAME="nat-kafka"  
    export ADDRESS_SPACE="10.31.0.0/20"  
    export SUBNET_PREFIX="10.31.0.0/21"  
    export SYSTEM_NODE_COUNT_MIN=3
    export SYSTEM_NODE_COUNT_MAX=6
    export SYSTEM_NODE_VM_SIZE="Standard_D4ds_v5"   
    export KAFKA_NODE_COUNT_MIN=1  
    export KAFKA_NODE_COUNT_MAX=3 
    export KAFKA_NODE_COUNT=1
    export KAFKA_NODE_VM_SIZE="Standard_D16ds_v5"  
    export LOG_ANALYTICS_WORKSPACE_NAME="law-monitoring"  
    export DIAGNOSTIC_SETTINGS_NAME="aks-diagnostic-settings"  
    export ACR_NAME="myACR"  
    export ACR_SKU="Premium"  
    export USER_ASSIGNED_IDENTITY_NAME="uami-aks"  
    export KUBERNETES_VERSION="1.30.0"  
    export AAD_ADMIN_GROUP_OBJECT_IDS="<your-admin-group-object-id>"    
    export AAD_TENANT_ID="<your-tenant-id>"  
    export GRAFANA_NAME="grafana-kafka-aks"  
    export PROMETHEUS_WORKSPACE_NAME="prometheus-aks"
    ```  
 
### Pre-cluster deployments 

Before deploying the AKS cluster for Kakfa, deploy the prerequisite resources that support the AKS cluster deployment:  

* Create a resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```azurecli-interactive    
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
    ```

* Create a virtual network using the [`az network vnet create`](/cli/azure/network/vnet#az-network-vnet-create) command. 

    ```azurecli-interactive 
    az network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VNET_NAME \
    --address-prefix $ADDRESS_SPACE \
    --location $LOCATION
    ```

* Create a subnet using the [`az network vnet subnet create`](/cli/azure/network/vnet/subnet#az-network-vnet-subnet-create) command.
    
    ```azurecli-interactive
    az network vnet subnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --address-prefix $SUBNET_PREFIX
    ```

* Create a public IP for the NAT Gateway using the [`az network public-ip create`](/cli/azure/network/public-ip#az-network-public-ip-create) command. 

    ```azurecli-interactive
    az network public-ip create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name ${NAT_GATEWAY_NAME}-public-ip \
    --sku Standard \
    --location $LOCATION
    ```

* Create a NAT Gateway using the [`az network nat gateway create`](/cli/azure/network/nat/gateway#az-network-nat-gateway-create) command. 

    ```azurecli-interactive
    az network nat gateway create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $NAT_GATEWAY_NAME \
    --public-ip-addresses ${NAT_GATEWAY_NAME}-public-ip \
    --location $LOCATION
    ```

* Associate the NAT Gateway to the node subnet using [`az network vnet subnet update`](/cli/azure/network/vnet/subnet#az-network-vnet-subnet-update) command.

    ```azurecli-interactive
    az network vnet subnet update \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --nat-gateway $NAT_GATEWAY_NAME
    ```

* Create a log analytics workspace using the [`az monitor log-analytics workspace create`](/cli/azure/monitor/log-analytics/workspace#az-monitor-log-analytics-workspace-create) command.

    ```azurecli-interactive
    az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP_NAME \
    --workspace-name $LOG_ANALYTICS_WORKSPACE_NAME \
    --location $LOCATION  
    ```

* Create an Azure container registry using the [`az acr create`](/cli/azure/acr#az-acr-create) command.

    ```azurecli-interactive
    az acr create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $ACR_NAME \
    --sku $ACR_SKU \
    --location $LOCATION \
    --admin-enabled false
    --zone-redundancy Enabled
    ```

* Create a user-assigned managed identity using the [`az identity create`](/cli/azure/identity#az-identity-create) command. 

    ```azurecli-interactive
    az identity create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $USER_ASSIGNED_IDENTITY_NAME \
    --location $LOCATION
    ```
* Create an Azure monitor workspace for Prometheus using the [`az monitor account create`](/cli/azure/monitor/account#az-monitor-account-create) command.

    ```azurecli-interactive
    az monitor account create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $PROMETHEUS_WORKSPACE_NAME \
    --location $LOCATION
    ```

* Create an Azure managed Grafana instance using the [`az grafana create`](/cli/azure/grafana#az-grafana-create) command. 

    ```azurecli-interactive
    az grafana create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $GRAFANA_NAME \
    --location $LOCATION \
    --api-key Enabled \
    --deterministic-outbound-ip Enabled \
    --public-network-access Enabled \
    --grafana-major-version 10 
    ```
    >[!NOTE]
    > Azure Managed Grafana has zone redundancy available in [select regions](/azure/managed-grafana/high-availability#supported-regions). If your target region has zone redundancy, use the `--zone-redundancy Enabled` argument. 


* Assign RBAC permissions to the managed identity of the Grafana instance using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. 
    
    ```azurecli-interactive
    az role assignment create \
    --assignee $(az grafana show --resource-group $RESOURCE_GROUP_NAME --name $GRAFANA_NAME --query identity.principalId -o tsv) \
    --role "Monitoring Reader" --scope $(az group show --name $RESOURCE_GROUP_NAME --query id -o tsv)
    ```

### AKS cluster deployment

Deploy the AKS cluster with dedicated node pools for Kafka per availability zone and Azure Container Storage enabled using Azure CLI:  

* First, assign the network contributor role to the user-assigned managed identity for AKS using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command.

    ```azurecli-interactive  
    az role assignment create \
    --assignee $(az identity show --resource-group $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_IDENTITY_NAME --query principalId -o tsv) \
    --role "Network Contributor" \
    --scope $(az group show --name $RESOURCE_GROUP_NAME --query id -o tsv)
    ```

* Create an AKS cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command.

    ```azurecli-interactive
    az aks create \
    --name $AKS_CLUSTER_NAME \
    --aad-admin-group-object-ids $AAD_ADMIN_GROUP_OBJECT_IDS \
    --aad-tenant-id $AAD_TENANT_ID \
    --assign-identity $(az identity show --resource-group $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_IDENTITY_NAME --query id -o tsv) \
    --attach-acr $(az acr show --resource-group $RESOURCE_GROUP_NAME --name $ACR_NAME --query id -o tsv) \
    --auto-upgrade-channel patch \
    --enable-aad \
    --enable-addons monitoring \
    --enable-azure-monitor-metrics \
    --enable-cluster-autoscaler \
    --enable-managed-identity \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --kubernetes-version $KUBERNETES_VERSION \
    --load-balancer-sku standard \
    --location $LOCATION \
    --max-count $SYSTEM_NODE_COUNT_MAX \
    --max-pods 110 \
    --min-count $SYSTEM_NODE_COUNT_MIN \
    --network-dataplane cilium \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-policy cilium \
    --node-osdisk-type Ephemeral \
    --node-os-upgrade-channel NodeImage \
    --node-vm-size $SYSTEM_NODE_VM_SIZE \
    --nodepool-labels "role=system" \
    --nodepool-name systempool \
    --nodepool-tags "env=production" \
    --os-sku AzureLinux \
    --outbound-type userAssignedNATGateway \
    --pod-cidr 10.244.0.0/16 \
    --resource-group $RESOURCE_GROUP_NAME \
    --tags "env=production" \
    --tier $AKS_TIER
    --vnet-subnet-id $(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --name $SUBNET_NAME --query id -o tsv) \
    --workspace-resource-id $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP_NAME --workspace-name $LOG_ANALYTICS_WORKSPACE_NAME --query id -o tsv) \
    --zones 1 2 3 
    ```

* Create an additional node pool per availability zone using a for loop and the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command. 

    ```azurecli-interactive
    for zone in 1 2 3; do
      az aks nodepool add \
      --cluster-name $AKS_CLUSTER_NAME \
      --enable-cluster-autoscaler \
      --labels app=kafka acstor.azure.com/io-engine=acstor \
      --max-count $KAFKA_NODE_COUNT_MAX \
      --max-surge 10% \
      --min-count $KAFKA_NODE_COUNT_MIN \
      --node-count $KAFKA_NODE_COUNT \
      --mode User \
      --name "kafka$zone" \
      --node-osdisk-type Ephemeral \
      --node-vm-size $KAFKA_NODE_VM_SIZE \
      --os-sku AzureLinux \
      --resource-group $RESOURCE_GROUP_NAME \
      --vnet-subnet-id $(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --name $SUBNET_NAME --query id -o tsv) \
      --zones $zone
    done
    ```

* Enable [Azure Container Storage](/azure/storage/container-storage/container-storage-aks-quickstart) with azureDisk on the AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command.
  
    ```azurecli-interactive
    az aks update \
    --name $AKS_CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --enable-azure-container-storage azureDisk
    ```

* Enable Azure Managed Prometheus and Grafana integration using the [`az aks update`](/cli/azure/aks#az-aks-update) command.

    ```azurecli-interactive
    az aks update \
    --name $AKS_CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --enable-azure-monitor-metrics \
    --azure-monitor-workspace-resource-id $(az monitor account show --resource-group $RESOURCE_GROUP_NAME --name $PROMETHEUS_WORKSPACE_NAME --query id -o tsv) \
    --grafana-resource-id $(az grafana show --resource-group $RESOURCE_GROUP_NAME --name $GRAFANA_NAME --query id -o tsv)
    ```

* (Optional) Configure diagnostic setting for the AKS cluster using the [`az monitor diagnostic-settings create`](/cli/azure/monitor/diagnostic-settings#az-monitor-diagnostic-settings-create) command.
    
    ```azurecli-interactive
    az monitor diagnostic-settings create \
    --resource $(az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --query id -o tsv) \
    --name $DIAGNOSTIC_SETTINGS_NAME \
    --workspace $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP_NAME --workspace-name $LOG_ANALYTICS_WORKSPACE_NAME --query id -o tsv) \
    --logs '[{"category": "kube-apiserver", "enabled": true}, {"category": "kube-audit", "enabled": true}, {"category": "kube-audit-admin", "enabled": true}, {"category": "kube-controller-manager", "enabled": true}, {"category": "kube-scheduler", "enabled": true}, {"category": "cluster-autoscaler", "enabled": true}, {"category": "cloud-controller-manager", "enabled": true}, {"category": "guard", "enabled": true}, {"category": "csi-azuredisk-controller", "enabled": true}, {"category": "csi-azurefile-controller", "enabled": true}, {"category": "csi-snapshot-controller", "enabled": true}]' \
    --metrics '[{"category": "AllMetrics", "enabled": true}]' 
    ```

### Validate deployment and connect to cluster  

After deploying your AKS cluster, use the following steps to validate the deployment and gain access to the AKS API Server:  


1. Verify the deployment of the AKS cluster using the [`az aks show`](/cli/azure/aks#az-aks-show) command.  

    ```azurecli-interactive  
    az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --output table  
    ```  

1. After verifying the deployment, connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.  

    ```azurecli-interactive  
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME  
    ```  
        
1. Verify connectivity by listing nodes using the `kubectl get` command.  

    ```bash  
    kubectl get nodes  
    ```  
::: zone-end

::: zone pivot="terraform"

In this section, you deploy an AKS cluster and supporting infrastructure resources using Terraform:  

* A private AKS cluster with a node pool per availability zone using the Azure Verified Module (AVM).  
* Virtual network and subnet configurations.  
* NAT gateway for outbound connectivity.  
* Azure Container Registry with private endpoint.  
* User-assigned managed identity for AKS.  
* Azure Monitor workspace for Prometheus metrics.  
* Azure Managed Grafana dashboard with Prometheus integration.  
* Dedicated node pools for Kafka workloads with appropriate labels.  
* Azure Container Storage extension for persistent volumes. 

> [!NOTE]  
> This Terraform deployment uses the [Azure Verified Module](https://github.com/Azure/terraform-azurerm-avm-ptn-aks-production) for a production AKS cluster. As a result, the cluster is deployed as a private cluster. Appropriate connectivity must be in place to run the subsequent kubectl commands.  


1. Copy the `variables.tf` to your Terraform directory.

    ```tf
    variable "azure_subscription_id" {
    type        = string
    description = "The Azure subscription ID to use for the resources."
    
    }
    variable "enable_telemetry" {
    type        = bool
    default     = true
    description = "This variable controls whether or not telemetry is enabled for the module."
    }

    variable "kubernetes_cluster_name" {
    type        = string
    default     = "kafka-cluster"
    description = "The name of the Kubernetes cluster."
    }

    variable "kubernetes_version" {
    type        = string
    default     = "1.30"
    description = "The version of Kubernetes to use for the cluster."
    }

    variable "resource_group_name" {
    type        = string
    description = "The name of the resource group in which to create the resources."
    }

    variable "rbac_aad_admin_group_object_ids" {
    type        = list(string)
    description = "The object IDs of the Azure AD groups that should be granted admin access to the Kubernetes cluster."    
    }

    variable "location" {
    type        = string
    description = "The location in which to create the resources."
    }
    ```

1. Review the variables and create a `kafka.tfvars` as needed. Update with values that meet your requirements:  

    ```tf  
    # Replace placeholder values with your actual configuration

    azure_subscription_id = "00000000-0000-0000-0000-000000000000" # Replace with your actual subscription ID
    location              = "Canada Central"
    enable_telemetry      = true
    kubernetes_cluster_name = "kafka-aks-cluster"
    kubernetes_version    = "1.30"
    resource_group_name   = "rg-kafka-prod"
    rbac_aad_admin_group_object_ids = [
    "0000-0000-0000-0000", 
    # Add additional admin group object IDs as needed
    ]
    ```  

1. Copy the `main.tf` to your Terraform directory.
    
    ```tf 
    terraform {
      required_version = ">= 1.3.0"
      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = ">= 4, <5"
        }
      }
    }
    provider "azurerm" {
      features {
        resource_group {
          prevent_deletion_if_contains_resources = false
        }
      }
      subscription_id = var.azure_subscription_id
    }
    module "naming" {
      source  = "Azure/naming/azurerm"
      version = ">= 0.3.0"
    }
    
    resource "azurerm_user_assigned_identity" "this" {
      location            = var.location
      name                = "uami-${var.kubernetes_cluster_name}"
      resource_group_name = var.resource_group_name
    }
    
    data "azurerm_client_config" "current" {}
    
    module "avm-ptn-aks-production" {
      source  = "Azure/avm-ptn-aks-production/azurerm"
      kubernetes_version  = "1.30"
      enable_telemetry    = var.enable_telemetry 
      name                = var.kubernetes_cluster_name
      resource_group_name = var.resource_group_name
      location = var.location 
      network = {
        name                = module.avm_res_network_virtualnetwork.name
        resource_group_name = var.resource_group_name
        node_subnet_id      = module.avm_res_network_virtualnetwork.subnets["subnet"].resource_id
        pod_cidr            = "192.168.0.0/16"
      }
      acr = {
        name                          = module.naming.container_registry.name_unique
        subnet_resource_id            = module.avm_res_network_virtualnetwork.subnets["private_link_subnet"].resource_id
        private_dns_zone_resource_ids = [azurerm_private_dns_zone.this.id]
      }
      managed_identities = {
        user_assigned_resource_ids = [
          azurerm_user_assigned_identity.this.id
        ]
      }
      rbac_aad_tenant_id = data.azurerm_client_config.current.tenant_id
      rbac_aad_admin_group_object_ids =  var.rbac_aad_admin_group_object_ids
      rbac_aad_azure_rbac_enabled = true
      
      node_pools = {
        kafka = {
          name                 = "kafka"
          vm_size              = "Standard_D8ds_v5"
          orchestrator_version = "1.30"
          max_count            = 3
          min_count            = 1
          os_sku               = "AzureLinux"
          mode                 = "User"
          os_disk_size_gb      = 128
          labels = {
            "app" = "kafka"
            "acstor.azure.com/io-engine" = "acstor"
          }
        }
      }
    }
    
    resource "azurerm_private_dns_zone" "this" {
      name                = "privatelink.azurecr.io"
      resource_group_name = var.resource_group_name
    }
    
    resource "azurerm_nat_gateway" "this" {
      location            = var.location
      name                = module.naming.nat_gateway.name_unique
      resource_group_name = var.resource_group_name
    }
    
    resource "azurerm_public_ip" "this" {
      name                = module.naming.public_ip.name_unique
      location            = var.location
      resource_group_name = var.resource_group_name
      allocation_method   = "Static"
      sku                 = "Standard"
    }
    
    # Associate NAT Gateway with Public IP
    resource "azurerm_nat_gateway_public_ip_association" "this" {
      nat_gateway_id       = azurerm_nat_gateway.this.id
      public_ip_address_id = azurerm_public_ip.this.id  
    }
    
    module "avm_res_network_virtualnetwork" {
      source  = "Azure/avm-res-network-virtualnetwork/azurerm"
      version = "0.7.1"
    
      address_space       = ["10.31.0.0/16"]
      location            = var.location
      name                = "vnet-aks-lab"
      resource_group_name = var.resource_group_name
      subnets = {
        "subnet" = {
          name             = "nodecidr"
          address_prefixes = ["10.31.0.0/17"]
          nat_gateway = {
            id = azurerm_nat_gateway.this.id
          }
          private_link_service_network_policies_enabled = false
        }
        "private_link_subnet" = {
          name             = "private_link_subnet"
          address_prefixes = ["10.31.129.0/24"]
        }
      }
    }
    
    resource "azurerm_monitor_workspace" "this" {
      name                = "prometheus-aks"
      location            = var.location
      resource_group_name = var.resource_group_name
    }
    
    resource "azurerm_monitor_data_collection_endpoint" "dataCollectionEndpoint" {
      name                = "prom-aks-endpoint"
      location            = var.location
      resource_group_name = var.resource_group_name
      kind                = "Linux"
    }
    
    resource "azurerm_monitor_data_collection_rule" "dataCollectionRule" {
      name      = "prom-aks-dcr"
      location            = var.location
      resource_group_name = var.resource_group_name
      data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dataCollectionEndpoint.id
      kind                        = "Linux"
      description = "DCR for Azure Monitor Metrics Profile (Managed Prometheus)"
      destinations {
        monitor_account {
          monitor_account_id = azurerm_monitor_workspace.this.id
          name               = "PrometheusAzMonitorAccount"
        }
      }
      data_flow {
        streams      = ["Microsoft-PrometheusMetrics"]
        destinations = ["PrometheusAzMonitorAccount"]
      }
      data_sources {
        prometheus_forwarder {
          streams = ["Microsoft-PrometheusMetrics"]
          name    = "PrometheusDataSource"
        }
      }
      
    }
    
    resource "azurerm_monitor_data_collection_rule_association" "dataCollectionRuleAssociation" {
      name                    = "prom-aks-dcra"
      target_resource_id      = module.avm-ptn-aks-production.resource_id
      data_collection_rule_id = azurerm_monitor_data_collection_rule.dataCollectionRule.id
      description             = "Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster."
    }
    
    resource "azurerm_dashboard_grafana" "this" {
      name                              = "grafana-kafka-aks"
      location                          = var.location
      resource_group_name               = var.resource_group_name
      api_key_enabled                   = true
      deterministic_outbound_ip_enabled = true
      public_network_access_enabled     = true
      grafana_major_version             = 10
    
      azure_monitor_workspace_integrations {
        resource_id = azurerm_monitor_workspace.this.id
      }
    
      identity {
        type = "SystemAssigned"
      }
    }
    
    data "azurerm_resource_group" "current" {
      name       = var.resource_group_name
      depends_on = [azurerm_dashboard_grafana.this]
    }
    
    resource "azurerm_role_assignment" "grafana_monitoring_reader" {
      scope                            = data.azurerm_resource_group.current.id
      role_definition_name             = "Monitoring Reader"
      principal_id                     = azurerm_dashboard_grafana.this.identity[0].principal_id
      skip_service_principal_aad_check = true
    }
    
    resource "azurerm_kubernetes_cluster_extension" "container_storage" {
      name           = "microsoft-azurecontainerstorage"
      cluster_id     = module.avm-ptn-aks-production.resource_id
      extension_type = "microsoft.azurecontainerstorage"
      configuration_settings = {
        "enable-azure-container-storage" : "azureDisk",
      }
    }
    ```

1. Initialize Terraform using the `terraform init` command.  

    ```bash  
    terraform init  
    ```  

1. Create a deployment plan using the `terraform plan` command.  

    ```bash  
    terraform plan -var-file="kafka.tfvars"
    ```  

1. Apply the configuration using the `terraform apply` command.  

    ```bash  
    terraform apply -var-file="kafka.tfvars" 
    ```  

 1. Verify the deployment using the [`az aks show`](/cli/azure/aks#az-aks-show) command.  

    ```azurecli-interactive  
    az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --output table  
    ```  

1. After verifying the deployment, connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.  

    ```azurecli-interactive  
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME  
    ```  
        
1. Verify connectivity by listing nodes using the `kubectl get` command.  

    ```bash  
    kubectl get nodes  
    ```  

::: zone-end

## Create Azure Container Storage storage pool

* Verify that Azure Container Storage is running on you AKS cluster using the `kubectl get` command.

    ```bash
    kubectl get deploy,ds -n acstor
    ```

Currently, you can't configure Azure Container Storage with a toleration to handle nodes with taints. Adding taints to nodes will block the deployment of Azure Container Storage.


* After deploying the cluster and validating that Azure Container Storage is running, apply the multi-zone `StoragePool` configuration using the `kubectl apply` command.  

    ```bash  
    kubectl apply -f - <<EOF  
    ---  
    apiVersion: containerstorage.azure.com/v1  
    kind: StoragePool  
    metadata:  
      name: azuredisk-zr  
      namespace: acstor  
    spec:  
      zones: ["1","2","3"]  
      poolType:  
        azureDisk:  
          skuName: PremiumV2_LRS  
          iopsReadWrite: 5000  
          mbpsReadWrite: 200  
      resources:  
        requests:  
          storage: 100Gi      
    EOF  
    ```  

> [!IMPORTANT]  
> The storage configuration above represents a starting point. For production deployments, adjust the `iopsReadWrite`, `mbpsReadWrite`, and `storage` values based on your expected Kafka cluster size and workload as discussed in the [Azure Container Storage section](./kafka-overview.md#azure-container-storage).  

## Next step  

> [!div class="nextstepaction"]  
> [Deploy Strimzi and Kafka on Azure Kubernetes Service (AKS)](./kafka-deploy.md)  

## Contributors  

*Microsoft maintains this article. The following contributors originally wrote it:*  

* Sergio Navar | Senior Customer Engineer  
* Erin Schaffer | Content Developer 2  