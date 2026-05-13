@description('Azure region for the deployment script.')
param location string

@description('Seconds to wait for RBAC propagation.')
param waitSeconds int

@description('User-assigned managed identity resource ID for the deployment script runtime.')
param userAssignedIdentityId string

resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'wait-rbac-propagation'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.64.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    scriptContent: 'echo "Waiting ${waitSeconds} seconds for RBAC propagation" && sleep ${waitSeconds}'
  }
}

output waitScriptId string = waitScript.id
