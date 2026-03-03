---
title: Access a Private API Server VNet Integration Cluster from Another Virtual Network
description: Step‑by‑step guidance for exposing the API server of an AKS cluster that has API Server VNet Integration enabled, by using Azure Private Link and consuming it from a separate virtual network.
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 03/03/2026
ms.custom: devx-track-azurecli
# Customer intent: As a network administrator, I want to connect to a private API server in an AKS cluster from a separate virtual network using Private Link, so that I can securely manage and interact with the cluster without exposing it to the public internet.
---

# Connect to an API Server VNet Integration cluster by using Azure Private Link

With API Server VNet Integration, the AKS control plane is reachable through a private IP inside your cluster's virtual network (VNet). This configuration works well for workloads running in the same VNet, but it doesn't automatically cover external networks, such as a hub network, a dedicated operations VNet, or a jump-host environment that need to reach the API server without exposing it to the public internet. This article shows you how to bridge that gap by fronting the API server with a Private Link Service, then connecting to it from a separate virtual network through a Private Endpoint.

This article applies **only to clusters that are created with [API Server VNet Integration](./api-server-vnet-integration.md)** and uses a bring-your-own VNet (BYO VNet) configuration. It shows you how to:

- Deploy a **private** AKS cluster with API Server VNet Integration using your own VNet.
- Expose the API server through a **Private Link Service (PLS)** inside the cluster virtual network.
- Create a **Private Endpoint (PE)** in a different virtual network.
- Configure **private DNS** so Kubernetes tools resolve the cluster's private FQDN inside the remote network.

For private clusters that **don't** use API Server VNet Integration, see [Create a private AKS cluster](./private-clusters.md).

## Region availability

API Server VNet Integration is currently available in a subset of Azure regions and is subject to regional capacity limits. Before you begin, confirm that your target region is supported. For more information, see [API Server VNet Integration](./api-server-vnet-integration.md).

## Prerequisites

| Requirement                 | Minimum                                                                          |
|-----------------------------|----------------------------------------------------------------------------------|
| Azure CLI                   | 2.73.0                                                                           |
| Permissions                 | Contributor + Network Contributor on both subscriptions                          |

If you use custom DNS servers, add Azure's virtual IP **168.63.129.16** as an upstream forwarder.

## Set environment variables

Set the following environment variables for use throughout this article. Feel free to replace the placeholder values with your own.

```bash
LOCATION="westus3"

# Resource groups
AKS_RG="aks-demo-rg"
REMOTE_RG="client-demo-rg"

# AKS cluster VNet and subnets (all user-owned, in AKS_RG)
AKS_VNET="aks-vnet"
AKS_VNET_PREFIX="172.19.0.0/16"
APISERVER_SUBNET="apiserver-subnet"
APISERVER_SUBNET_PREFIX="172.19.0.0/28"
NODE_SUBNET="node-subnet"
NODE_SUBNET_PREFIX="172.19.1.0/24"

# Private Link Service subnet (also in the cluster VNet, user-owned)
PLS_SUBNET="pls-subnet"
PLS_SUBNET_PREFIX="172.19.2.0/24"

# AKS cluster
AKS_CLUSTER="aks-private"
AKS_IDENTITY="aks-identity"

# Private Link Service
PLS_NAME="apiserver-pls"

# Remote VNet
REMOTE_VNET="client-vnet"
REMOTE_SUBNET="client-subnet"
REMOTE_VNET_PREFIX="192.168.0.0/16"
REMOTE_SUBNET_PREFIX="192.168.1.0/24"
PE_NAME="aks-pe"
PE_CONN_NAME="aks-pe-conn"

# DNS
DNS_ZONE="private.${LOCATION}.azmk8s.io"
DNS_LINK="dns-link"
```

## Create resource groups

```azurecli-interactive
az group create --name $AKS_RG --location $LOCATION
az group create --name $REMOTE_RG --location $LOCATION
```

## Create the cluster VNet and subnets

With BYO VNet, you create and own the virtual network before the cluster is deployed. This lets you add resources such as the PLS subnet to the VNet without touching AKS-managed infrastructure.

Three subnets are required:

| Subnet | Purpose | Notes |
| ------ | ------- | ----- |
| `apiserver-subnet` | API server ILB injection | Must be delegated to `Microsoft.ContainerService/managedClusters`; minimum `/28` |
| `node-subnet` | AKS worker nodes | Standard cluster subnet |
| `pls-subnet` | Private Link Service | Must have private link service network policies disabled |

```azurecli-interactive
# Create the cluster VNet
az network vnet create \
  --name $AKS_VNET \
  --resource-group $AKS_RG \
  --location $LOCATION \
  --address-prefixes $AKS_VNET_PREFIX

# Create the API server subnet delegated to AKS so AKS can inject the control-plane ILB
az network vnet subnet create \
  --name $APISERVER_SUBNET \
  --vnet-name $AKS_VNET \
  --resource-group $AKS_RG \
  --address-prefixes $APISERVER_SUBNET_PREFIX \
  --delegations Microsoft.ContainerService/managedClusters

# Create the node subnet
az network vnet subnet create \
  --name $NODE_SUBNET \
  --vnet-name $AKS_VNET \
  --resource-group $AKS_RG \
  --address-prefixes $NODE_SUBNET_PREFIX

# Create the PLS subnet (network policies must be disabled on Private Link Service subnets)
az network vnet subnet create \
  --name $PLS_SUBNET \
  --vnet-name $AKS_VNET \
  --resource-group $AKS_RG \
  --address-prefixes $PLS_SUBNET_PREFIX \
  --disable-private-link-service-network-policies
```

## Create a managed identity and assign permissions

AKS requires a managed identity with Network Contributor rights on both the API server subnet and the node subnet to manage network resources during cluster operations.

```azurecli-interactive
# Create a user-assigned managed identity for the cluster
az identity create \
  --name $AKS_IDENTITY \
  --resource-group $AKS_RG \
  --location $LOCATION

# Get the identity's resource ID for later use
IDENTITY_ID=$(az identity show \
  --name $AKS_IDENTITY \
  --resource-group $AKS_RG \
  --query id -o tsv)

# Get the identity's client ID to assign roles on the subnets
IDENTITY_CLIENT_ID=$(az identity show \
  --name $AKS_IDENTITY \
  --resource-group $AKS_RG \
  --query clientId -o tsv)

# Get the API server subnet ID for role assignment
APISERVER_SUBNET_ID=$(az network vnet subnet show \
  --name $APISERVER_SUBNET \
  --vnet-name $AKS_VNET \
  --resource-group $AKS_RG \
  --query id -o tsv)

# Get the node subnet ID for role assignment
NODE_SUBNET_ID=$(az network vnet subnet show \
  --name $NODE_SUBNET \
  --vnet-name $AKS_VNET \
  --resource-group $AKS_RG \
  --query id -o tsv)

# Assign Network Contributor role to the API server subnet
az role assignment create \
  --scope $APISERVER_SUBNET_ID \
  --role "Network Contributor" \
  --assignee $IDENTITY_CLIENT_ID

# Assign Network Contributor role to the node subnet
az role assignment create \
  --scope $NODE_SUBNET_ID \
  --role "Network Contributor" \
  --assignee $IDENTITY_CLIENT_ID
```

## Deploy a private cluster with API Server VNet Integration

Pass the pre-created subnets and managed identity to `az aks create`. AKS injects the API server ILB into `apiserver-subnet` and places worker nodes into `node-subnet`.

```azurecli-interactive
az aks create \
  --name $AKS_CLUSTER \
  --resource-group $AKS_RG \
  --location $LOCATION \
  --network-plugin azure \
  --enable-private-cluster \
  --enable-apiserver-vnet-integration \
  --vnet-subnet-id $NODE_SUBNET_ID \
  --apiserver-subnet-id $APISERVER_SUBNET_ID \
  --assign-identity $IDENTITY_ID \
  --generate-ssh-keys
```

After the cluster finishes provisioning, capture the node resource group and the private FQDN label. You need the node resource group only to locate the `kube-apiserver` internal load balancer — no writes to it are needed.

```azurecli-interactive
# Get the node resource group where AKS deploys the kube-apiserver ILB
AKS_NODE_RG=$(az aks show \
  --name $AKS_CLUSTER \
  --resource-group $AKS_RG \
  --query nodeResourceGroup -o tsv)

# Get the private FQDN label to construct the DNS record name later
DNS_RECORD=$(az aks show \
  --name $AKS_CLUSTER \
  --resource-group $AKS_RG \
  --query privateFqdn -o tsv | cut -d'.' -f1,2)

# Get the kube-apiserver ILB frontend IP configuration ID for the Private Link Service
FRONTEND_IP_CONFIG_ID=$(az network lb show \
  --name kube-apiserver \
  --resource-group $AKS_NODE_RG \
  --query "frontendIPConfigurations[0].id" \
  -o tsv)
```

## Create a Private Link Service (PLS) in the cluster VNet

Because you own the cluster VNet, you can create the PLS and its subnet directly in `AKS_RG` without interacting with AKS-managed resources. Point the PLS at the `kube-apiserver` internal load balancer frontend that AKS created in the node resource group.

```azurecli-interactive
# Create the Private Link Service in the cluster VNet, fronted by the kube-apiserver ILB
az network private-link-service create \
  --name $PLS_NAME \
  --resource-group $AKS_RG \
  --vnet-name $AKS_VNET \
  --subnet $PLS_SUBNET \
  --lb-frontend-ip-configs $FRONTEND_IP_CONFIG_ID \
  --location $LOCATION
```

## Create a Private Endpoint (PE) in the remote VNet

```azurecli-interactive
# Create the remote VNet
az network vnet create \
  --name $REMOTE_VNET \
  --resource-group $REMOTE_RG \
  --location $LOCATION \
  --address-prefixes $REMOTE_VNET_PREFIX

# Create the remote subnet
az network vnet subnet create \
  --name $REMOTE_SUBNET \
  --vnet-name $REMOTE_VNET \
  --resource-group $REMOTE_RG \
  --address-prefixes $REMOTE_SUBNET_PREFIX

# Get the Private Link Service ID for the Private Endpoint connection
PLS_ID=$(az network private-link-service show \
  --name $PLS_NAME \
  --resource-group $AKS_RG \
  --query id -o tsv)

# Create the Private Endpoint in the remote VNet, connecting to the PLS in the cluster VNet
az network private-endpoint create \
  --name $PE_NAME \
  --resource-group $REMOTE_RG \
  --vnet-name $REMOTE_VNET \
  --subnet $REMOTE_SUBNET \
  --private-connection-resource-id $PLS_ID \
  --connection-name $PE_CONN_NAME \
  --location $LOCATION
```

When the Private Endpoint finishes provisioning, note its network interface (NIC) ID so you can retrieve the allocated private IP address.

```azurecli-interactive
# Get the Private Endpoint NIC ID
PE_NIC_ID=$(az network private-endpoint show \
  --name $PE_NAME \
  --resource-group $REMOTE_RG \
  --query 'networkInterfaces[0].id' \
  --output tsv)

# Get the Private Endpoint private IP address from the NIC
PE_IP=$(az network nic show \
  --ids $PE_NIC_ID \
  --query 'ipConfigurations[0].privateIPAddress' \
  --output tsv)
```

## Configure private DNS

```azurecli-interactive
# Create or reuse the regional DNS zone
az network private-dns zone create \
  --name $DNS_ZONE \
  --resource-group $REMOTE_RG

# Create an A record in that zone for the API server's private FQDN, pointing to the PE IP address
az network private-dns record-set a create \
  --name $DNS_RECORD \
  --zone-name $DNS_ZONE \
  --resource-group $REMOTE_RG

# Add the A record pointing to the Private Endpoint IP
az network private-dns record-set a add-record \
  --record-set-name $DNS_RECORD \
  --zone-name $DNS_ZONE \
  --resource-group $REMOTE_RG \
  --ipv4-address $PE_IP

# Link zone to the remote VNet
REMOTE_VNET_ID=$(az network vnet show \
  --name $REMOTE_VNET \
  --resource-group $REMOTE_RG \
  --query id -o tsv)

# Link the DNS zone to the remote VNet so the private FQDN resolves inside that network
az network private-dns link vnet create \
  --name $DNS_LINK \
  --zone-name $DNS_ZONE \
  --resource-group $REMOTE_RG \
  --virtual-network $REMOTE_VNET_ID \
  --registration-enabled false
```

## Test the connection

If you try to test the connection locally, you might get an error because the DNS zone isn't linked to your local network.

```azurecli-interactive
az aks get-credentials --resource-group $AKS_RG --name $AKS_CLUSTER
```

```bash
kubectl get nodes
```

### Deploy a test VM in the remote VNet

To confirm the Private Endpoint path, deploy a test VM in the remote VNet and use it to connect to the AKS cluster.

```azurecli
# Create Network Security Group that allows inbound SSH (TCP 22)
az network nsg create \
  --name "${REMOTE_VNET}-nsg" \
  --resource-group $REMOTE_RG \
  --location $LOCATION

# Add an NSG rule to allow SSH
az network nsg rule create \
  --nsg-name "${REMOTE_VNET}-nsg" \
  --resource-group $REMOTE_RG \
  --name allow-ssh \
  --priority 100 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes '*' \
  --destination-port-ranges 22

# Associate the NSG with the remote subnet
az network vnet subnet update \
  --name $REMOTE_SUBNET \
  --vnet-name $REMOTE_VNET \
  --resource-group $REMOTE_RG \
  --network-security-group "${REMOTE_VNET}-nsg"

# Create a small Ubuntu VM in that subnet (with a public IP for quick SSH)
az vm create \
  --resource-group $REMOTE_RG \
  --name test-vm \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name $REMOTE_VNET \
  --subnet $REMOTE_SUBNET \
  --public-ip-sku Standard

# Capture the public IP address
VM_PUBLIC_IP=$(az vm show -d -g $REMOTE_RG -n test-vm --query publicIps -o tsv)
```

### Connect to the VM and test the connection

```bash
ssh -i ~/.ssh/id_rsa azureuser@$VM_PUBLIC_IP

# Inside the VM
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
sudo az aks install-cli

# Re-export the AKS variables
export AKS_RG="aks-demo-rg"
export AKS_CLUSTER="aks-private"

# Log in to Azure. Follow the instructions to authenticate.
az login

# Get the AKS credentials
az aks get-credentials --resource-group $AKS_RG --name $AKS_CLUSTER

# Test the connection
kubectl get nodes

# You should see the AKS nodes

# Exit the VM
exit
```

## Clean up resources

To avoid ongoing Azure charges, delete the resource groups using the [`az group delete`](/cli/azure/group#az-group-delete) command.

```azurecli-interactive
az group delete --name $AKS_RG --yes --no-wait
az group delete --name $REMOTE_RG --yes --no-wait
```

## Related content

- [API Server VNet Integration](./api-server-vnet-integration.md)
- [Private Link](/azure/private-link/private-link-overview)
- [Private Link Service](/azure/private-link/private-link-service-overview)
- [Private Endpoint](/azure/private-link/private-endpoint-overview)
- [Private DNS](/azure/dns/private-dns-overview)
- [Integrate your own DNS solution with Azure Private Link](/azure/private-link/private-endpoint-dns-integration)
