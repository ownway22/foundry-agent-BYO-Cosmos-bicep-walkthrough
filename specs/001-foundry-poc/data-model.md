# Data Model: Foundry Standard Agent Greenfield POC

<!-- markdownlint-disable MD032 -->

## FoundryAccount

**Represents**：Microsoft Foundry account / Cognitive Services `AIServices` resource.

**Fields**：

- `name`: derived as `msai${token}`.
- `location`: default `eastus`, parameterized.
- `kind`: `AIServices`.
- `disableLocalAuth`: `true`.
- `publicNetworkAccess`: `Enabled` for POC.
- `allowProjectManagement`: `true`.

**Relationships**：Owns account capability host, model deployment, and project.

**Validation rules**：API version pinned to `2025-04-01-preview`; local auth must stay disabled.

## FoundryProject

**Represents**：Single project under Foundry account.

**Fields**：

- `name`: derived as `msproj${token}`.
- `identityType`: `SystemAssigned, UserAssigned`.
- `userAssignedIdentity`: `ms-agent-mi-${token}`.

**Relationships**：Owns project connections and project capability host.

**Validation rules**：Must not use service principal or secret; identity must expose principal IDs for RBAC.

## UserAssignedManagedIdentity

**Represents**：UMI used to match walkthrough Storage/Search RBAC pattern.

**Fields**：

- `name`: `ms-agent-mi-${token}`.
- `location`: same as project.
- `principalId`: emitted by Azure.

**Relationships**：Assigned to project; receives Storage/Search data roles where walkthrough requires Project SMI + UMI.

## ModelDeployment

**Represents**：Foundry model deployment for smoke tests.

**Fields**：

- `modelName`: default `gpt-5.4`.
- `modelVersion`: default `2026-03-05`.
- `skuName`: default `GlobalStandard`.
- `capacity`: default `50`.

**Validation rules**：Fallback models must be explicit parameter changes; do not silently substitute model names.

## CosmosDbAccount

**Represents**：BYO thread storage resource created by the POC.

**Fields**：

- `name`: `ms-cosmos-${token}`.
- `mode`: Serverless.
- `database`: `enterprise_memory` created/provisioned through capability host flow.
- `containers`: `thread-message-store`, `system-thread-message-store`, `agent-entity-store`.

**Relationships**：Connected to project via AAD Cosmos DB connection; receives Project SMI RBAC.

**Validation rules**：No provisioned RU/s; Cosmos DB data role is account-scoped before capability host creates `enterprise_memory`.

## StorageAccount

**Represents**：Flat blob storage for agent file state.

**Fields**：

- `name`: `msst${token}`.
- `kind`: `StorageV2`.
- `hierarchicalNamespace`: disabled.

**Relationships**：Connected to project via AAD Storage connection; containers are Foundry-generated.

**Validation rules**：No connection strings or account keys in scripts or parameters.

## SearchService

**Represents**：Azure AI Search vector store.

**Fields**：

- `name`: `ms-srch-${token}`.
- `sku`: Standard S1.

**Relationships**：Connected to project via AAD AI Search connection; receives Project SMI + UMI roles.

## ProjectConnection

**Represents**：Foundry project connected resource.

**Fields**：

- `cosmosConnectionName`: `cosmos-thread-storage`.
- `storageConnectionName`: `storage-file-storage`.
- `searchConnectionName`: `search-vector-store`.
- `authType`: `AAD`.

**Relationships**：Referenced by project capability host.

**Validation rules**：No `ApiKey` auth.

## CapabilityHost

**Represents**：Immutable capability host resource.

**Fields**：

- `name`: `default`.
- `capabilityHostKind`: `Agents`.
- `threadStorageConnections`: Cosmos connection name.
- `storageConnections`: Storage connection name.
- `vectorStoreConnections`: Search connection name.

**State transitions**：`Creating` → `Succeeded` or `Failed`. If succeeded, never update; delete/recreate project for changes.

## RbacAssignment

**Represents**：Azure RBAC or Cosmos DB SQL role assignment.

**Fields**：

- `principalId`: Project SMI or UMI principal ID.
- `scope`: resource-specific scope.
- `roleDefinitionId`: fixed built-in role ID.

**Validation rules**：Cosmos DB SQL role must not be scoped to individual containers; Storage blob data roles are container-scoped when containers exist or can be referenced.

<!-- markdownlint-enable MD032 -->
