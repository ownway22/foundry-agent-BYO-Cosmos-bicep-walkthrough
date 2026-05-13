@description('Azure region for the Foundry account.')
param location string

@description('Foundry account name.')
param foundryAccountName string

@description('Model deployment name.')
param modelDeploymentName string

@description('Model name.')
param modelName string

@description('Model version.')
param modelVersion string

@description('Model deployment SKU name.')
param modelSkuName string

@description('Model deployment capacity.')
param modelCapacity int

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryAccountName
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryAccountName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  parent: foundryAccount
  name: 'default'
  properties: {
    capabilityHostKind: 'Agents'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: modelDeploymentName
  sku: {
    name: modelSkuName
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

output foundryAccountName string = foundryAccount.name
output foundryAccountId string = foundryAccount.id
output foundryAccountEndpoint string = 'https://${foundryAccount.properties.customSubDomainName}.cognitiveservices.azure.com/'
output accountCapabilityHostName string = accountCapabilityHost.name
output modelDeploymentName string = modelDeployment.name
