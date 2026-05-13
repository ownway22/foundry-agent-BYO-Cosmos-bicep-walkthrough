@description('Azure region for the Foundry project.')
param location string

@description('Foundry account name.')
param foundryAccountName string

@description('Foundry project name.')
param projectName string

@description('User-assigned managed identity resource ID.')
param userAssignedIdentityId string

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: foundryAccountName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: foundryAccount
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {}
}

output projectName string = foundryProject.name
output projectId string = foundryProject.id
output projectPrincipalId string = foundryProject.identity.principalId
output projectEndpoint string = any(foundryProject.properties).endpoint
output projectWorkspaceId string = any(foundryProject.properties).workspaceId
