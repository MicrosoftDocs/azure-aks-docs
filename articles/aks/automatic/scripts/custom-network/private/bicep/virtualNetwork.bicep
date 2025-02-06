@description('The location of the managed cluster resource.')
param location string = resourceGroup().location

@description('The name of the virtual network.')
param vnetName string = 'aksAutomaticVnet'

@description('The address prefix of the virtual network.')
param addressPrefix string = '172.19.0.0/16'

@description('The name of the API server subnet.')
param apiServerSubnetName string = 'apiServerSubnet'

@description('The subnet prefix of the API server subnet.')
param apiServerSubnetPrefix string = '172.19.0.0/28'

@description('The name of the cluster subnet.')
param clusterSubnetName string = 'clusterSubnet'

@description('The subnet prefix of the cluster subnet.')
param clusterSubnetPrefix string = '172.19.1.0/24'

// Virtual network with an API server subnet and a cluster subnet
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
    name: vnetName
    location: location
    properties: {
        addressSpace: {
            addressPrefixes: [ addressPrefix ]
        }
        subnets: [
            {
                name: apiServerSubnetName
                properties: {
                    addressPrefix: apiServerSubnetPrefix
                }
            }
            {
                name: clusterSubnetName
                properties: {
                    addressPrefix: clusterSubnetPrefix
                }
            }
        ]
    }
}

output apiServerSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, apiServerSubnetName)
output clusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, clusterSubnetName)
