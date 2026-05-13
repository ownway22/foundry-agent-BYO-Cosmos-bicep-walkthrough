@description('Azure AI Search service name.')
param searchServiceName string

@description('Project system-assigned managed identity principal ID.')
param projectPrincipalId string

@description('Project user-assigned managed identity principal ID.')
param userAssignedIdentityPrincipalId string

var searchIndexDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
var searchServiceContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')

resource searchService 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: searchServiceName
}

resource projectSmiSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, projectPrincipalId, 'SearchIndexDataContributor')
  scope: searchService
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: searchIndexDataContributorRoleDefinitionId
  }
}

resource projectUmiSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userAssignedIdentityPrincipalId, 'SearchIndexDataContributor')
  scope: searchService
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: searchIndexDataContributorRoleDefinitionId
  }
}

resource projectSmiSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, projectPrincipalId, 'SearchServiceContributor')
  scope: searchService
  properties: {
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: searchServiceContributorRoleDefinitionId
  }
}

resource projectUmiSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userAssignedIdentityPrincipalId, 'SearchServiceContributor')
  scope: searchService
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: searchServiceContributorRoleDefinitionId
  }
}

output searchRoleAssignmentIds array = [
  projectSmiSearchIndexDataContributor.id
  projectUmiSearchIndexDataContributor.id
  projectSmiSearchServiceContributor.id
  projectUmiSearchServiceContributor.id
]
