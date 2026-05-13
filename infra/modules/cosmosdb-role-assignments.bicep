@description('Cosmos DB account name.')
param cosmosDbAccountName string

@description('Project system-assigned managed identity principal ID.')
param projectPrincipalId string

var cosmosDbOperatorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '230815da-be43-4aae-9cb4-875f7bd000aa')
var cosmosDbBuiltInDataContributorRoleDefinitionId = '${cosmosDbAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosDbAccountName
}

resource cosmosDbOperator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosDbAccount.id, projectPrincipalId, 'CosmosDBOperator')
  scope: cosmosDbAccount
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: cosmosDbOperatorRoleDefinitionId
  }
}

resource cosmosDbDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, projectPrincipalId, 'BuiltInDataContributor')
  properties: {
    principalId: projectPrincipalId
    roleDefinitionId: cosmosDbBuiltInDataContributorRoleDefinitionId
    scope: cosmosDbAccount.id
  }
}

output cosmosDbOperatorRoleAssignmentId string = cosmosDbOperator.id
output cosmosDbDataContributorRoleAssignmentId string = cosmosDbDataContributor.id
