@description('The name of the virtual network.')
param vnetName string = 'aksAutomaticVnet'

@description('The principal ID of the user assigned managed identity.')
param uamiPrincipalId string

// Get a reference to the virtual network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing ={
  name: vnetName
}

// Assign the Network Contributor role to the user assigned managed identity on the virtual network
// '4d97b98b-1d4f-4787-a291-c67834d212e7' is the built-in Network Contributor role definition
// See: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/networking#network-contributor
resource networkContributorRoleAssignmentToVirtualNetwork 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uamiPrincipalId, '4d97b98b-1d4f-4787-a291-c67834d212e7', resourceGroup().id, virtualNetwork.name)
  scope: virtualNetwork
  properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
      principalId: uamiPrincipalId
  }
}
