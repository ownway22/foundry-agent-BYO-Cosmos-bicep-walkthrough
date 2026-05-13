@description('Foundry account resource ID. Baseline no-op compatibility input.')
param foundryAccountId string

@description('Foundry project resource ID. Baseline no-op compatibility input.')
param projectId string

@description('Project system-assigned managed identity principal ID. Baseline no-op compatibility input.')
param projectPrincipalId string

@description('Project user-assigned managed identity principal ID. Baseline no-op compatibility input.')
param userAssignedIdentityPrincipalId string

// Baseline intentionally creates no account/project management-plane role assignments.
// If provider validation requires a named Foundry role, stop and ask before adding it.
output foundryAccountId string = foundryAccountId
output projectId string = projectId
output projectPrincipalId string = projectPrincipalId
output userAssignedIdentityPrincipalId string = userAssignedIdentityPrincipalId
output roleAssignmentIds array = []
