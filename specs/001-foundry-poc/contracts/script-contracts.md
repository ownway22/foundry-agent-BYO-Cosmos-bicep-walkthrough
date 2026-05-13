# Contracts: Deployment and Verification Scripts

<!-- markdownlint-disable MD032 -->

This POC does not expose a runtime application API. The contract surface is the Bash script interface plus Azure deployment outputs consumed by verification scripts.

## `infra/scripts/deploy.sh`

**Purpose**：Validate prerequisites, build Bicep, run what-if, prompt for confirmation, and deploy only after explicit user confirmation.

**Required inputs**：

- `--resource-group <name>`: existing resource group.
- Optional `--parameters <path>`: defaults to `infra/main.bicepparam`.
- Optional `--template-file <path>`: defaults to `infra/main.bicep`.

**Preconditions**：

- Azure CLI logged in.
- Target resource group exists.
- User has permission to deploy resources and create role assignments.

**Behavior contract**：

- Must run `az bicep build --file infra/main.bicep` before what-if.
- Must run `az deployment group what-if` before deployment.
- Must prompt before running `az deployment group create`.
- Must not run deployment unless the user confirms in the terminal.
- Must not hardcode subscription ID, connection string, API key, or secret.

## `infra/scripts/verify.sh`

**Purpose**：Validate deployed resource state after deployment.

**Required inputs**：

- `--resource-group <name>`.
- `--account-name <foundry-account-name>` or derived from deployment outputs.
- `--project-name <project-name>` or derived from deployment outputs.

**Behavior contract**：

- Check account capability host provisioning state is `Succeeded`.
- Check project capability host provisioning state is `Succeeded`.
- Check project capability host thread, file, and vector bindings reference the expected Cosmos DB, Storage, and AI Search connection names.
- Check Foundry model deployment exists and matches the expected model name, model version, SKU, and capacity outputs.
- Check project connections exist and use AAD auth.
- Check Cosmos DB `enterprise_memory` database exists.
- Check `thread-message-store`, `system-thread-message-store`, `agent-entity-store` containers exist.
- Check local auth remains disabled and project identity includes System-Assigned + User-Assigned identities.
- Check Cosmos DB, Storage, and AI Search role assignments use the expected principal and scope boundaries.
- Perform one Chat Completions smoke test for `Hello` without unsupported sampling parameters.

## `infra/scripts/smoke-test-reasoning.sh`

**Purpose**：Validate a reasoning request to `gpt-5.4`.

**Required inputs**：

- Foundry account endpoint or deployment endpoint derived from Azure.
- Deployment name.

**Behavior contract**：

- Must acquire AAD token through Azure CLI.
- Must send `reasoning_effort: "low"`.
- Must not send `temperature`, `top_p`, `presence_penalty`, `frequency_penalty`, `logprobs`, or `logit_bias`.
- Must fail clearly on HTTP 400 and print response body.

## Deployment outputs consumed by scripts

- `foundryAccountName`
- `projectName`
- `modelDeploymentName`
- `cosmosDbAccountName`
- `storageAccountName`
- `searchServiceName`
- `projectEndpoint`
- `location`

<!-- markdownlint-enable MD032 -->
