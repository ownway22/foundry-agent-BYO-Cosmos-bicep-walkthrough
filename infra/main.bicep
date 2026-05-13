targetScope = 'resourceGroup'

@description('Azure region for all POC resources.')
param location string = 'eastus'

@description('Resource name prefix. The approved baseline is ms.')
param namePrefix string = 'ms'

@description('Foundry model deployment name.')
param modelDeploymentName string = 'gpt-5-4'

@description('Foundry model name. Keep gpt-5.4 unless the user explicitly chooses a documented fallback.')
param modelName string = 'gpt-5.4'

@description('Foundry model version. Keep 2026-03-05 for gpt-5.4.')
param modelVersion string = '2026-03-05'

@description('Model deployment SKU name.')
param modelSkuName string = 'GlobalStandard'

@description('Model deployment capacity.')
param modelCapacity int = 50

@description('RBAC propagation wait in seconds before creating the project capability host.')
@minValue(30)
@maxValue(300)
param rbacPropagationWaitSeconds int = 60

var token = take(toLower(uniqueString(resourceGroup().id, location, namePrefix)), 8)
var foundryAccountName = take('${namePrefix}ai${token}', 24)
var projectName = take('${namePrefix}proj${token}', 64)
var cosmosDbAccountName = take('${namePrefix}-cosmos-${token}', 50)
var storageAccountName = take('${namePrefix}st${token}', 24)
var searchServiceName = take('${namePrefix}-srch-${token}', 60)
var userAssignedIdentityName = take('${namePrefix}-agent-mi-${token}', 128)

var cosmosConnectionName = 'cosmos-thread-storage'
var storageConnectionName = 'storage-file-storage'
var searchConnectionName = 'search-vector-store'

module dependentResources 'modules/dependent-resources.bicep' = {
  name: 'dependent-resources'
  params: {
    location: location
    cosmosDbAccountName: cosmosDbAccountName
    storageAccountName: storageAccountName
    searchServiceName: searchServiceName
    userAssignedIdentityName: userAssignedIdentityName
  }
}

module foundryAccount 'modules/foundry-account.bicep' = {
  name: 'foundry-account'
  params: {
    location: location
    foundryAccountName: foundryAccountName
    modelDeploymentName: modelDeploymentName
    modelName: modelName
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
  }
}

module foundryProject 'modules/foundry-project.bicep' = {
  name: 'foundry-project'
  params: {
    location: location
    foundryAccountName: foundryAccount.outputs.foundryAccountName
    projectName: projectName
    userAssignedIdentityId: dependentResources.outputs.userAssignedIdentityId
  }
}

module projectConnections 'modules/project-connections.bicep' = {
  name: 'project-connections'
  params: {
    location: location
    foundryAccountName: foundryAccount.outputs.foundryAccountName
    projectName: foundryProject.outputs.projectName
    cosmosDbResourceId: dependentResources.outputs.cosmosDbAccountId
    cosmosDbEndpoint: dependentResources.outputs.cosmosDbEndpoint
    storageAccountResourceId: dependentResources.outputs.storageAccountId
    storageBlobEndpoint: dependentResources.outputs.storageBlobEndpoint
    searchServiceResourceId: dependentResources.outputs.searchServiceId
    searchEndpoint: dependentResources.outputs.searchEndpoint
    cosmosConnectionName: cosmosConnectionName
    storageConnectionName: storageConnectionName
    searchConnectionName: searchConnectionName
  }
}

module accountRoleAssignments 'modules/account-role-assignments.bicep' = {
  name: 'account-role-assignments'
  params: {
    foundryAccountId: foundryAccount.outputs.foundryAccountId
    projectId: foundryProject.outputs.projectId
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
    userAssignedIdentityPrincipalId: dependentResources.outputs.userAssignedIdentityPrincipalId
  }
}

module cosmosDbRoleAssignments 'modules/cosmosdb-role-assignments.bicep' = {
  name: 'cosmosdb-role-assignments'
  params: {
    cosmosDbAccountName: dependentResources.outputs.cosmosDbAccountName
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
  }
}

module storageRoleAssignments 'modules/storage-role-assignments.bicep' = {
  name: 'storage-role-assignments'
  params: {
    storageAccountName: dependentResources.outputs.storageAccountName
    projectWorkspaceId: foundryProject.outputs.projectWorkspaceId
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
    userAssignedIdentityPrincipalId: dependentResources.outputs.userAssignedIdentityPrincipalId
  }
}

module searchRoleAssignments 'modules/search-role-assignments.bicep' = {
  name: 'search-role-assignments'
  params: {
    searchServiceName: dependentResources.outputs.searchServiceName
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
    userAssignedIdentityPrincipalId: dependentResources.outputs.userAssignedIdentityPrincipalId
  }
}

module rbacPropagationWait 'modules/rbac-propagation-wait.bicep' = {
  name: 'rbac-propagation-wait'
  params: {
    location: location
    waitSeconds: rbacPropagationWaitSeconds
  }
  dependsOn: [
    accountRoleAssignments
    cosmosDbRoleAssignments
    storageRoleAssignments
    searchRoleAssignments
  ]
}

module projectCapabilityHost 'modules/project-capability-host.bicep' = {
  name: 'project-capability-host'
  params: {
    foundryAccountName: foundryAccount.outputs.foundryAccountName
    projectName: foundryProject.outputs.projectName
    cosmosConnectionName: projectConnections.outputs.cosmosConnectionName
    storageConnectionName: projectConnections.outputs.storageConnectionName
    searchConnectionName: projectConnections.outputs.searchConnectionName
  }
  dependsOn: [
    rbacPropagationWait
  ]
}

output foundryAccountName string = foundryAccount.outputs.foundryAccountName
output projectName string = foundryProject.outputs.projectName
output modelDeploymentName string = modelDeploymentName
output cosmosDbAccountName string = dependentResources.outputs.cosmosDbAccountName
output storageAccountName string = dependentResources.outputs.storageAccountName
output searchServiceName string = dependentResources.outputs.searchServiceName
output projectEndpoint string = foundryProject.outputs.projectEndpoint
output location string = location
output cosmosConnectionName string = cosmosConnectionName
output storageConnectionName string = storageConnectionName
output searchConnectionName string = searchConnectionName
