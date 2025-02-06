@description('The name of the managed cluster resource.')
param clusterName string = 'aksAutomaticCluster'

@description('The location of the managed cluster resource.')
param location string = resourceGroup().location

@description('The resource ID of the API server subnet.')
param apiServerSubnetId string

@description('The resource ID of the cluster subnet.')
param clusterSubnetId string

@description('The resource ID of the user assigned managed identity.')
param uamiId string

/// Create the private AKS Automatic cluster using the custom virtual network and user assigned managed identity
resource aks 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = {
  name: clusterName
  location: location  
  sku: {
	name: 'Automatic'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
	      count: 3
        vnetSubnetID: clusterSubnetId
      }
    ]
    apiServerAccessProfile: {
        subnetId: apiServerSubnetId
        enablePrivateCluster: true
    }
    networkProfile: {
      outboundType: 'loadBalancer'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
}
