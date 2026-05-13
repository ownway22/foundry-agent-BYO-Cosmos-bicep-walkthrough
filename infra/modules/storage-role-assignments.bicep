@description('Storage account name.')
param storageAccountName string

@description('Foundry project workspace ID used in generated storage container names.')
param projectWorkspaceId string

@description('Project system-assigned managed identity principal ID.')
param projectPrincipalId string

@description('Project user-assigned managed identity principal ID.')
param userAssignedIdentityPrincipalId string

var storageAccountContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageBlobDataOwnerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
var azuremlBlobstoreContainerName = '${projectWorkspaceId}-azureml-blobstore'
var agentsBlobstoreContainerName = '${projectWorkspaceId}-agents-blobstore'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource azuremlBlobstoreContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: azuremlBlobstoreContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource agentsBlobstoreContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: agentsBlobstoreContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource storageAccountContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, projectPrincipalId, 'StorageAccountContributor')
  scope: storageAccount
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageAccountContributorRoleDefinitionId
  }
}

resource projectSmiAzuremlBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azuremlBlobstoreContainer.id, projectPrincipalId, 'StorageBlobDataContributor')
  scope: azuremlBlobstoreContainer
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
  }
}

resource projectUmiAzuremlBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azuremlBlobstoreContainer.id, userAssignedIdentityPrincipalId, 'StorageBlobDataContributor')
  scope: azuremlBlobstoreContainer
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
  }
}

resource projectSmiAgentsBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agentsBlobstoreContainer.id, projectPrincipalId, 'StorageBlobDataOwner')
  scope: agentsBlobstoreContainer
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRoleDefinitionId
  }
}

resource projectUmiAgentsBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agentsBlobstoreContainer.id, userAssignedIdentityPrincipalId, 'StorageBlobDataOwner')
  scope: agentsBlobstoreContainer
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRoleDefinitionId
  }
}

output azuremlBlobstoreContainerName string = azuremlBlobstoreContainer.name
output agentsBlobstoreContainerName string = agentsBlobstoreContainer.name
output storageRoleAssignmentIds array = [
  storageAccountContributor.id
  projectSmiAzuremlBlobDataContributor.id
  projectUmiAzuremlBlobDataContributor.id
  projectSmiAgentsBlobDataOwner.id
  projectUmiAgentsBlobDataOwner.id
]
