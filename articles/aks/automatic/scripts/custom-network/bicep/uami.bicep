param location string = resourceGroup().location
param uamiName string = 'aksAutomaticUAMI'

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
}

output uamiId string = userAssignedManagedIdentity.id
output uamiPrincipalId string = userAssignedManagedIdentity.properties.principalId
output uamiClientId string = userAssignedManagedIdentity.properties.clientId
