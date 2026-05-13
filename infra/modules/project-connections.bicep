@description('Azure region for connected resources metadata.')
param location string

@description('Foundry account name.')
param foundryAccountName string

@description('Foundry project name.')
param projectName string

@description('Cosmos DB resource ID.')
param cosmosDbResourceId string

@description('Cosmos DB document endpoint.')
param cosmosDbEndpoint string

@description('Storage account resource ID.')
param storageAccountResourceId string

@description('Storage blob endpoint.')
param storageBlobEndpoint string

@description('Azure AI Search resource ID.')
param searchServiceResourceId string

@description('Azure AI Search endpoint.')
param searchEndpoint string

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

resource cosmosConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: cosmosConnectionName
  properties: {
    category: 'CosmosDb'
    target: cosmosDbEndpoint
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmosDbResourceId
      location: location
    }
  }
}

resource storageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: storageConnectionName
  properties: {
    category: 'AzureStorageAccount'
    target: storageBlobEndpoint
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: storageAccountResourceId
      location: location
    }
  }
}

resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: searchConnectionName
  properties: {
    category: 'CognitiveSearch'
    target: searchEndpoint
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchServiceResourceId
      location: location
    }
  }
}

output cosmosConnectionName string = cosmosConnection.name
output storageConnectionName string = storageConnection.name
output searchConnectionName string = searchConnection.name
