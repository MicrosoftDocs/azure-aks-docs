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