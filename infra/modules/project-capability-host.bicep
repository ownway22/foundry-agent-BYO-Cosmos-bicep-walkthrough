@description('Foundry account name.')
param foundryAccountName string

@description('Foundry project name.')
param projectName string

param cosmosConnectionName string
param storageConnectionName string
param searchConnectionName string

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: foundryAccountName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: foundryAccount
  name: projectName
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  parent: foundryProject
  name: 'default'
  properties: any({
    capabilityHostKind: 'Agents'
    threadStorageConnections: [
      cosmosConnectionName
    ]
    storageConnections: [
      storageConnectionName
    ]
    vectorStoreConnections: [
      searchConnectionName
    ]
  })
}

output projectCapabilityHostName string = projectCapabilityHost.name
output projectCapabilityHostId string = projectCapabilityHost.id
