RG_NAME=automatic-rg
VNET_NAME=automatic-vnet
CLUSTER_NAME=automatic
IDENTITY_NAME=automatic-uami
LOCATION=eastus
SUBSCRIPTION_ID=$(az account show --query id -o tsv)