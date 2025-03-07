---
title: Prepare the AKS infrastructure for a Kafka deployment
description: In this article, we provide an overview of deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
zone_pivot_groups: azure-cli-or-terraform
---

## Infrastructure Overview

The target AKS architecture for Kafka deployment prioritizes high availability through a comprehensive zone-redundant design. This architecture utilizes a zone-redundant AKS cluster where control plane components are automatically distributed across availability zones. To prevent resource contention and ensure predictable performance, dedicated node pools for Kafka workloads are strongly recommended. The design requires three node pools—one per availability zone—to maintain workload distribution and storage alignment. This zonal configuration is critical because persistent volumes in this architecture have zonal affinity, ensuring that when cluster autoscaler activates during node failures, new nodes are provisioned in the appropriate zones. Without this zonal specificity, pods with zone-bound persistent volumes would remain in a pending state. This architecture enables multiple replicas of the Strimzi Cluster Operator and Kafka broker instances to be distributed across zones, providing resilience against both node and entire zone failures within the target region.

## Azure Container Storage

[Azure Container Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction) is a managed Kubernetes storage solution that dynamically provisions persistent volumes for stateful applications like Kafka. Based on the OpenEBS open-source project, it provides enterprise-grade storage capabilities specifically optimized for containerized workloads.

For Kafka deployments, Strimzi leverages [JBOD (Just a Bunch of Disks)](https://strimzi.io/docs/operators/latest/deploying#considerations-for-data-storage-str) configuration to manage data persistence. This approach allows Kafka brokers to utilize multiple storage volumes—either ephemeral or persistent—with each volume dedicated to specific data types. When using persistent storage, Strimzi integrates with Kubernetes Persistent Volumes (PVs) through Persistent Volume Claims (PVCs). Azure Container Storage enhances this integration by providing dynamic provisioning, simplified management, and the ability to resize volumes as your workloads grow.

To ensure high availability across infrastructure failures, a [zone-redundant storage pool](https://learn.microsoft.com/en-us/azure/storage/container-storage/enable-multi-zone-redundancy) should be configured to distribute underlying disks across all availability zones. Each zone will use Locally Redundant Storage (LRS) with Premium SSD v2 storage. Zone-Redundant Storage (ZRS) is unnecessary since Kafka provides built-in data replication at the application level. Premium SSD v2 can deliver the latency, high IOPS, and consistent throughput required by IO-intensive Kafka workloads at an optimized cost structure.

>[!NOTE]
>Ephemeral storage is not recommended for production Kafka clusters. When using ephemeral storage, broker restarts trigger full data replication across the cluster, which can significantly impact performance and recovery times.
>

The following table provides starting points for Premium SSD v2 disk configurations across different Kafka cluster sizes:

| Kafka Cluster Size | Disk Size | IOPS | Bandwidth |
|--------------------|-----------|------|-----------|
| **Small**<br>(3-9 brokers) | 1 TB | 5,000 | 250 MB/s |
| **Medium**<br>(10-19 brokers) | 2 TB | 10,000 | 500 MB/s |
| **Large**<br>(20+ brokers) | 4 TB | 20,000 | 1,000 MB/s |

The required IOPS, bandwidth, and disk size will vary based on your specific Kafka workload characteristics. These properties can be independently adjusted over time as your application's throughput and retention requirements evolve.

## AKS Node Pool Considerations for Strimzi/Kafka Deployment

Selecting the appropriate node pools for your Kafka deployment on AKS is a critical architectural decision that directly impacts performance, availability, and cost efficiency. Kafka workloads have unique resource utilization patterns—characterized by high throughput demands, storage I/O intensity, and the need for consistent performance under varying loads.

Kafka is typically more memory-intensive than CPU-intensive. This is primarily due to Kafka's heavy reliance on the operating system's page cache for optimizing read operations. With sufficient memory, frequently accessed messages can be served directly from RAM rather than requiring disk I/O. However, CPU requirements can increase significantly with message compression/decompression, SSL/TLS encryption, or high-throughput scenarios with many small messages.

Considering Strimzi's Kubernetes-native architecture where each Kafka broker runs as an individual pod, your VM selection strategy should optimize for horizontal scaling rather than single-node vertical scaling. Proper node pool configuration ensures efficient resource utilization while maintaining the performance isolation that Kafka components require to operate reliably.

Kafka runs using a Java Virtual Machines (JVM). Tuning the JVM is critical for optimal Kafka performance, especially in production environments. LinkedIn, the creators of Kafka, shared the typical arguments for running Kafka on Java for one of LinkedIn's busiest clusters: [Apache Kafka Java Configuration](https://kafka.apache.org/documentation/#java). A memory heap of 6GB will be used as a baseline, with an additional 2GB allocated to accommodate off-heap memory usage.

When sizing VMs for your Kafka deployment, consider these workload-specific factors:

| Workload Factor | Impact on Sizing | Considerations |
|-----------------|------------------|----------------|
| **Message Throughput** | Higher throughput requires more CPU, memory, and network capacity | - Monitor bytes in/out per second<br>- Consider peak vs. average throughput<br>- Account for future growth projections |
| **Message Size** | Larger messages consume more network bandwidth and disk I/O | - Small messages (≤1KB) are CPU-bound<br>- Large messages (>1MB) are network-bound<br>- Very large messages may require specialized tuning |
| **Retention Period** | Longer retention increases storage requirements | - Calculate total storage needs based on throughput × retention<br> |
| **Consumer Count** | More consumers increase CPU and network load | - Each consumer group adds overhead<br>- High fan-out patterns require additional resources |
| **Topic Partitioning** | Higher partition counts increase memory utilization | - Each partition consumes memory resources<br>- Over-partitioning can degrade performance |
| **Infrastructure Overhead** | Additional system components impact available resources for Kafka | - Azure Container Storage requires 1 vCPU per node minimum<br>- Monitoring agents, Logging components,  Network policies and security tools add further overhead<br>- Reserve an overhead for system components |

Before finalizing your production environment:

1. Perform load testing with representative data volumes and patterns
2. Monitor CPU, memory, disk, and network utilization during peak loads
3. Adjust VM SKUs based on observed bottlenecks
4. Test failure scenarios to validate high-availability behavior

Remember that Kafka performance scales horizontally—adding more broker nodes often provides better results than using larger VM SKUs. Start with the recommended baseline VMs and scale based on your application's specific requirements and performance metrics.

> [!IMPORTANT]
> The following recommendations serve as baseline guidance only. Your optimal VM SKU selection should be tailored to your specific Kafka workload characteristics, data patterns, and performance requirements. Each broker pod is estimated to have ~8GB of reserved memory. Your JVM and off-heap memory requirements may be larger and smaller.

### Small-Medium Sized Kafka Clusters

| VM SKU | vCPUs | RAM | Network | Broker Density (Estimates) | Key Benefits |
|--------|-------|-----|---------|----------------|-------------|
| **Standard_D8ds**  | 8 | 32 GB | 12,500 Mbps | 1-3 per node | - Aligns with Kubernetes fault isolation<br>- Adequate resources for high-performing brokers<br>- Proper zone distribution with anti-affinity<br>- Cost-effective for horizontal scaling |
| **Standard_D16ds**  | 16 | 64 GB | 12,500 Mbps | 3-6 per node | - Better consolidation for medium clusters (6-12 brokers)<br>- More efficient resource utilization<br>- Reduced node count for easier management |

### Large Sized Kafka Clusters (20+ Brokers)

| VM SKU | vCPUs | RAM | Network | Broker Density (Estimates) | Key Benefits |
|--------|-------|-----|---------|----------------|-------------|
| **Standard_E16ds**  | 16 | 128 GB | 12,500 Mbps | 6+ per node | - Additional memory for larger heaps and OS cache<br>- Better performance for data-intensive operations<br>- Enhanced throughput for high-volume clusters |

Collecting workspace information# Completing the Infrastructure Deployment Section

I'll help you finish the infrastructure deployment section for your article. Based on the code in your workspace, here's how to complete the pivot group sections:

## Deploy Infrastructure

The following steps will guide you through deploying the AKS infrastructure needed for your Kafka deployment.

::: zone pivot="azure-cli"

### Deploy using Azure CLI

1. **Prerequisites**
   - Terraform v1.3.0 or later installed
   - Azure CLI installed and authenticated
   - Sufficient permissions to create resources

> [!TIP]
> **If you have an existing AKS cluster:** You can skip the full deployment steps, but ensure your cluster meets these requirements:
>
> - Azure Container Storage is installed on the cluster
> - Node pools are distributed across availability zones (1, 2, and 3)
> - Dedicated node pools for Kafka with appropriate VM sizes (see VM sizing recommendations above)
> - Verify these requirements with:
>   ```bash
>   # Check AKS version and features
>   az aks show -g <resource-group-name> -n <cluster-name> --query "{k8sVersion:kubernetesVersion, zones:agentPoolProfiles[].availabilityZones}" -o jsonc
>   
>   # Check node distribution across zones
>   kubectl get nodes --label-columns=topology.kubernetes.io/zone
>   
>   # If missing, install Azure Container Storage on existing cluster
>   az aks update -g <resource-group-name> -n <cluster-name> --enable-blob-driver --enable-file-driver
>   
>   # Create zone-aware storage classes (see storage class definition in step 5 below)
>   ```

1. **Configure deployment variables**

   Before running the deployment script, export the following variables :

    ```bash
        RESOURCE_GROUP_NAME="myResourceGroup"
        LOCATION="eastus"
        VNET_NAME="vnet-aks-lab"
        SUBNET_NAME="nodecidr"
        AKS_CLUSTER_NAME="myAKSCluster"
        NAT_GATEWAY_NAME="myNatGateway"
        ADDRESS_SPACE="10.31.0.0/16"
        SUBNET_PREFIX="10.31.0.0/17"
        NODE_VM_SIZE="Standard_D8ds_v5"
        NODE_COUNT=3
        LOG_ANALYTICS_WORKSPACE_NAME="myLogAnalyticsWorkspace"
        DIAGNOSTIC_SETTINGS_NAME="aks-diagnostic-settings"
        ACR_NAME="myACR"
        ACR_SKU="Premium"
        USER_ASSIGNED_IDENTITY_NAME="uami-aks"
        KUBERNETES_VERSION="1.30.0"  # Replace with your desired Kubernetes version
        AAD_ADMIN_GROUP_OBJECT_IDS="<your-admin-group-object-id>"  # Replace with your AAD admin group object IDs
        AAD_TENANT_ID="<your-tenant-id>"  # Replace with your AAD tenant ID
        GRAFANA_DASHBOARD_NAME="grafana-kafka-aks"  # Replace with your Grafana dashboard name
    ```

1. **Execute the deployment script**

    **What the script does**
   - Creates a resource group for all resources
   - Sets up a virtual network with subnet and NAT gateway
   - Creates a Log Analytics workspace for monitoring
   - Deploys an Azure Container Registry (ACR)
   - Creates a user-assigned managed identity for AKS
   - Sets up Azure Monitor workspace for Prometheus
   - Deploys an Azure Managed Grafana instance
   - Creates the AKS cluster with:
     - Azure AD integration
     - Azure Monitor integration
     - Azure Container Storage enabled
     - Workload Identity enabled
     - Azure Managed Prometheus and Grafana integration
   - Configures diagnostic settings for the cluster
   - Creates dedicated node pools for Kafka with the appropriate labels in each availability zone

    ```bash
 
        # Create resource group
        az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

        # Create virtual network
        az network vnet create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $VNET_NAME \
        --address-prefix $ADDRESS_SPACE \
        --location $LOCATION

        # Create subnet
        az network vnet subnet create \
        --resource-group $RESOURCE_GROUP_NAME \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --address-prefix $SUBNET_PREFIX

        # Create public IP for NAT gateway
        az network public-ip create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name ${NAT_GATEWAY_NAME}-public-ip \
        --sku Standard \
        --location $LOCATION

        # Create NAT gateway
        az network nat gateway create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $NAT_GATEWAY_NAME \
        --public-ip-addresses ${NAT_GATEWAY_NAME}-public-ip \
        --location $LOCATION

        # Associate NAT gateway with subnet
        az network vnet subnet update \
        --resource-group $RESOURCE_GROUP_NAME \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --nat-gateway $NAT_GATEWAY_NAME

        # Create Log Analytics workspace
        az monitor log-analytics workspace create \
        --resource-group $RESOURCE_GROUP_NAME \
        --workspace-name $LOG_ANALYTICS_WORKSPACE_NAME \
        --location $LOCATION

        # Get Log Analytics workspace ID
        LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
        --resource-group $RESOURCE_GROUP_NAME \
        --workspace-name $LOG_ANALYTICS_WORKSPACE_NAME \
        --query id -o tsv)

        # Create Azure Container Registry (ACR)
        az acr create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $ACR_NAME \
        --sku $ACR_SKU \
        --location $LOCATION \
        --admin-enabled false

        # Create User Assigned Identity
        az identity create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $USER_ASSIGNED_IDENTITY_NAME \
        --location $LOCATION

        # Get User Assigned Identity ID
        USER_ASSIGNED_IDENTITY_ID=$(az identity show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $USER_ASSIGNED_IDENTITY_NAME \
        --query id -o tsv)

        ACR_ID=$(az acr show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $ACR_NAME --query id -o tsv)

        # Create Azure Monitor Workspace for Prometheus
        az monitor workspace create \
        --resource-group $RESOURCE_GROUP_NAME \
        --workspace-name "prometheus-aks" \
        --location $LOCATION

        $AZ_MON_WORKSPACE_ID=$(az monitor workspace show \
        --resource-group $RESOURCE_GROUP_NAME \
        --workspace-name "prometheus-aks" \
        --query id -o tsv)

        # Create Grafana Dashboard
        az grafana create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name "grafana-kafka-aks" \
        --location $LOCATION \
        --api-key-enabled true \
        --deterministic-outbound-ip-enabled true \
        --public-network-access "Enabled" \
        --grafana-major-version 10 \
        --identity-type "SystemAssigned"

        $GRAFANA_ID=$(az grafana show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name "grafana-kafka-aks" \
        --query id -o tsv)

        # Get Resource Group ID
        RESOURCE_GROUP_ID=$(az group show \
        --name $RESOURCE_GROUP_NAME \
        --query id -o tsv)

        # Get Grafana Dashboard Principal ID
        GRAFANA_PRINCIPAL_ID=$(az grafana show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name "grafana-kafka-aks" \
        --query identity.principalId -o tsv)

        # Assign Monitoring Reader Role to Grafana
        az role assignment create \
        --assignee $GRAFANA_PRINCIPAL_ID \
        --role "Monitoring Reader" \
        --scope $RESOURCE_GROUP_ID

        # Create AKS cluster
        az aks create \
        --aad-admin-group-object-ids $AAD_ADMIN_GROUP_OBJECT_IDS \
        --aad-tenant-id $AAD_TENANT_ID \
        --assign-identity $USER_ASSIGNED_IDENTITY_ID \
        --attach-acr $ACR_ID \
        --auto-upgrade-channel patch \
        --azure-monitor-workspace-resource-id $AZ_MON_WORKSPACE_ID \
        --enable-aad \
        --enable-addons monitoring \
        --enable-azure-container-storage azureDisk \
        --enable-azure-monitor-metrics \
        --enable-azure-policy \
        --enable-cluster-autoscaler \
        --enable-managed-identity \
        --enable-oidc-issuer \
        --enable-private-cluster false \
        --enable-workload-identity \
        --grafana-resource-id $GRAFANA_ID \
        --kubernetes-version $KUBERNETES_VERSION \
        --load-balancer-sku standard \
        --location $LOCATION \
        --max-count 5 \
        --max-pods 110 \
        --min-count 3 \
        --network-dataplane cilium \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --network-policy cilium \
        --node-count $NODE_COUNT \
        --node-osdisk-type Ephemeral \
        --node-os-upgrade-channel NodeImage \
        --node-vm-size $NODE_VM_SIZE \
        --nodepool-labels "role=system" \
        --nodepool-name systempool \
        --nodepool-tags "env=production" \
        --nodepool-zones "1" "2" "3" \
        --outbound-type userAssignedNATGateway \
        --pod-cidr 10.244.0.0/16 \
        --resource-group $RESOURCE_GROUP_NAME \
        --tags "env=production" \
        --vnet-subnet-id $(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --name $SUBNET_NAME --query id -o tsv) \
        --workspace-resource-id $LOG_ANALYTICS_WORKSPACE_ID \
        --name $AKS_CLUSTER_NAME

        # Enable diagnostic settings for AKS
        az monitor diagnostic-settings create \
        --resource $(az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --query id -o tsv) \
        --name $DIAGNOSTIC_SETTINGS_NAME \
        --workspace $LOG_ANALYTICS_WORKSPACE_ID \
        --logs '[{"category": "kube-apiserver", "enabled": true}, {"category": "kube-audit", "enabled": true}, {"category": "kube-audit-admin", "enabled": true}, {"category": "kube-controller-manager", "enabled": true}, {"category": "kube-scheduler", "enabled": true}, {"category": "cluster-autoscaler", "enabled": true}, {"category": "cloud-controller-manager", "enabled": true}, {"category": "guard", "enabled": true}, {"category": "csi-azuredisk-controller", "enabled": true}, {"category": "csi-azurefile-controller", "enabled": true}, {"category": "csi-snapshot-controller", "enabled": true}]' \
        --metrics '[{"category": "AllMetrics", "enabled": true}]'

        # Assign Network Contributor role to User Assigned Identity on Resource Group
        az role assignment create --assignee $(az identity show --resource-group $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_IDENTITY_NAME --query principalId -o tsv) --role "Network Contributor" --scope $(az group show --name $RESOURCE_GROUP_NAME --query id -o tsv)

        # Create additional node pools per zone
        for zone in 1 2 3; do
        az aks nodepool add \
            --cluster-name $AKS_CLUSTER_NAME \
            --enable-cluster-autoscaler \
            --labels "app=kafka,acstor.azure.com/io-engine=acstor" \
            --max-count 5 \
            --min-count 1 \
            --mode User \
            --name "kafka$zone" \
            --node-count $NODE_COUNT \
            --node-osdisk-type Ephemeral \
            --node-vm-size $NODE_VM_SIZE \
            --os-sku AzureLinux \
            --resource-group $RESOURCE_GROUP_NAME \
            --vnet-subnet-id $(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --name $SUBNET_NAME --query id -o tsv) \
            --zones $zone
        done

        echo "AKS cluster deployed successfully."

    ```

1. **Verify deployment**

   ```bash
        az aks show -g $RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME --output table
   ```

1. **After verifying the deployment, connect to your AKS cluster to run kubectl commands:**

   ```bash
        # Download the cluster credentials and configure kubectl
        az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
        
        # Verify connectivity by listing nodes
        kubectl get nodes
    ```

1. **Configure Azure Container Storage**

   After the cluster is deployed, apply the multi-zone storage configuration:

    ```bash
   
        kubectl apply -f - << EOF
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

>[!IMPORTANT]
>The storage configuration above represents a starting point. For production deployments, adjust the `iopsReadWrite`, `mbpsReadWrite`, and `storage` values based on your expected Kafka cluster size and workload as discussed in the Azure Container Storage section.
>
>Azure Container Storage cannot currently be configured with a toleration to handle nodes with taints.

::: zone-end

::: zone pivot="terraform"

### Deploy using Terraform

1. **Prerequisites**
   - Terraform v1.3.0 or later installed
   - Azure CLI installed and authenticated
   - Sufficient permissions to create resources

1. **What the Terraform code creates**
   - An AKS cluster using the Azure Verified Module (AVM) pattern
   - Virtual network and subnet configurations
   - NAT gateway for outbound connectivity
   - Azure Container Registry with private endpoint
   - User-assigned managed identity for AKS
   - Azure Monitor workspace for Prometheus metrics
   - Azure Managed Grafana dashboard with Prometheus integration
   - Dedicated node pools for Kafka workloads with appropriate labels
   - Azure Container Storage extension for persistent volumes

1. **Configure deployment variables**

   Review and update the variables in variables.tf as needed:

   ```hcl
   # Example configurations you might want to change:
   variable "resource_group_name" {
     default = "rg-cxe-1"
   }
   
   variable "location" {
     default = "Canada Central"
   }
   
   variable "kubernetes_cluster_name" {
     default = "kafka-cluster"
   }
   
   variable "rbac_aad_admin_group_object_ids" {
     default = [""]  # Add your admin group object IDs
   }
   ```

1. **Initialize Terraform**

   ```bash
       terraform init
   ```

1. **Create a deployment plan**

   ```bash
       terraform plan 
   ```

1. **Apply the configuration**

   ```bash
       terraform apply kafka-aks.plan
   ```

 1. **Verify deployment**

   ```bash
        az aks show -g $RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME --output table
   ```

1. **After verifying the deployment, connect to your AKS cluster to run kubectl commands:**

   ```bash
        # Download the cluster credentials and configure kubectl
        az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
        
        # Verify connectivity by listing nodes
        kubectl get nodes
    ```

1. **Configure Azure Container Storage**

   After the cluster is deployed, apply the multi-zone storage configuration:

    ```bash
   
        kubectl apply -f - << EOF
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

>[!IMPORTANT]
>The storage configuration above represents a starting point. For production deployments, adjust the `iopsReadWrite`, `mbpsReadWrite`, and `storage` values based on your expected Kafka cluster size and workload as discussed in the Azure Container Storage section.
>
>Azure Container Storage cannot currently be configured with a toleration to handle nodes with taints.

::: zone-end

After successfully deploying the infrastructure, you can proceed to install the Strimzi operator and deploy your Kafka cluster as described in Deploying a Kafka cluster on AKS using Strimzi.