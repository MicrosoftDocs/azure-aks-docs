#!/bin/bash

RG_NAME=automatic-rg
VNET_NAME=automatic-vnet
CLUSTER_NAME=automatic
IDENTITY_NAME=automatic-uami
LOCATION=eastasia
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az group create -n ${RG_NAME} -l ${LOCATION}

az network vnet create --name ${VNET_NAME} \
--resource-group ${RG_NAME} \
--location ${LOCATION} \
--address-prefixes 172.19.0.0/16

az network vnet subnet create --resource-group ${RG_NAME} \
--vnet-name ${VNET_NAME} \
--name apiServerSubnet \
--delegations Microsoft.ContainerService/managedClusters \
--address-prefixes 172.19.0.0/28

az network vnet subnet create --resource-group ${RG_NAME} \
--vnet-name ${VNET_NAME} \
--name clusterSubnet \
--address-prefixes 172.19.1.0/24

az identity create --resource-group ${RG_NAME} --name ${IDENTITY_NAME} --location ${LOCATION}
IDENTITY_CLIENT_ID=$(az identity show --resource-group ${RG_NAME} --name ${IDENTITY_NAME} --query clientId -o tsv)

az role assignment create --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}" \
--role "Network Contributor" \
--assignee ${IDENTITY_CLIENT_ID}

az aks create \
--resource-group ${RG_NAME} \
--name ${CLUSTER_NAME} \
--location ${LOCATION} \
--apiserver-subnet-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/apiServerSubnet" \
--vnet-subnet-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/clusterSubnet" \
--assign-identity "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RG_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" \
--sku automatic \
--no-ssh-key