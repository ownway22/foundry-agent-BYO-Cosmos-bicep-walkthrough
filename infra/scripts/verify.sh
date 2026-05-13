#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP=""
DEPLOYMENT_NAME=""
ACCOUNT_NAME=""
PROJECT_NAME=""
MODEL_DEPLOYMENT_NAME=""
MODEL_NAME="gpt-5.4"
MODEL_VERSION="2026-03-05"
MODEL_SKU="GlobalStandard"
MODEL_CAPACITY="50"

COSMOS_CONNECTION_NAME="cosmos-thread-storage"
STORAGE_CONNECTION_NAME="storage-file-storage"
SEARCH_CONNECTION_NAME="search-vector-store"
DATABASE_NAME="enterprise_memory"
CONTAINERS=("thread-message-store" "system-thread-message-store" "agent-entity-store")

usage() {
  cat <<'USAGE'
Usage: infra/scripts/verify.sh --resource-group <name> [options]

Options:
  --resource-group <name>      Resource group that contains the deployment.
  --deployment-name <name>     Deployment name. Defaults to latest successful group deployment.
  --account-name <name>        Foundry account name. Defaults to deployment output.
  --project-name <name>        Foundry project name. Defaults to deployment output.
  --model-deployment <name>    Model deployment name. Defaults to deployment output.
  --model-name <name>          Expected model name. Defaults to gpt-5.4.
  --model-version <version>    Expected model version. Defaults to 2026-03-05.
  --model-sku <name>           Expected model SKU. Defaults to GlobalStandard.
  --model-capacity <number>    Expected model capacity. Defaults to 50.
  -h, --help                   Show this help.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

json_value() {
  jq -r "$1 // empty"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --deployment-name)
      DEPLOYMENT_NAME="${2:-}"
      shift 2
      ;;
    --account-name)
      ACCOUNT_NAME="${2:-}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --model-deployment)
      MODEL_DEPLOYMENT_NAME="${2:-}"
      shift 2
      ;;
    --model-name)
      MODEL_NAME="${2:-}"
      shift 2
      ;;
    --model-version)
      MODEL_VERSION="${2:-}"
      shift 2
      ;;
    --model-sku)
      MODEL_SKU="${2:-}"
      shift 2
      ;;
    --model-capacity)
      MODEL_CAPACITY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${RESOURCE_GROUP}" ]] || fail "--resource-group is required"
require_command az
require_command jq
require_command curl

az account show --query user.name -o tsv >/dev/null || fail "Azure CLI is not logged in"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

if [[ -z "${DEPLOYMENT_NAME}" ]]; then
  DEPLOYMENT_NAME="$(az deployment group list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "sort_by([?properties.provisioningState=='Succeeded'], &properties.timestamp)[-1].name" \
    -o tsv)"
fi

[[ -n "${DEPLOYMENT_NAME}" ]] || fail "No successful deployment found. Provide --deployment-name."

OUTPUTS_JSON="$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query properties.outputs \
  -o json)"

output_value() {
  jq -r --arg key "$1" '.[$key].value // empty' <<<"${OUTPUTS_JSON}"
}

ACCOUNT_NAME="${ACCOUNT_NAME:-$(output_value foundryAccountName)}"
PROJECT_NAME="${PROJECT_NAME:-$(output_value projectName)}"
MODEL_DEPLOYMENT_NAME="${MODEL_DEPLOYMENT_NAME:-$(output_value modelDeploymentName)}"
COSMOS_DB_ACCOUNT_NAME="$(output_value cosmosDbAccountName)"
STORAGE_ACCOUNT_NAME="$(output_value storageAccountName)"
SEARCH_SERVICE_NAME="$(output_value searchServiceName)"

[[ -n "${ACCOUNT_NAME}" ]] || fail "Foundry account name not provided and not found in deployment outputs"
[[ -n "${PROJECT_NAME}" ]] || fail "Project name not provided and not found in deployment outputs"
[[ -n "${MODEL_DEPLOYMENT_NAME}" ]] || fail "Model deployment name not provided and not found in deployment outputs"
[[ -n "${COSMOS_DB_ACCOUNT_NAME}" ]] || fail "Cosmos DB account name missing from deployment outputs"
[[ -n "${STORAGE_ACCOUNT_NAME}" ]] || fail "Storage account name missing from deployment outputs"
[[ -n "${SEARCH_SERVICE_NAME}" ]] || fail "Search service name missing from deployment outputs"

ACCOUNT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}"
PROJECT_ID="${ACCOUNT_ID}/projects/${PROJECT_NAME}"
ACCOUNT_CAPABILITY_HOST_ID="${ACCOUNT_ID}/capabilityHosts/default"
PROJECT_CAPABILITY_HOST_ID="${PROJECT_ID}/capabilityHosts/default"
COSMOS_DB_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.DocumentDB/databaseAccounts/${COSMOS_DB_ACCOUNT_NAME}"
STORAGE_ACCOUNT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}"
SEARCH_SERVICE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Search/searchServices/${SEARCH_SERVICE_NAME}"

account_json="$(az resource show --ids "${ACCOUNT_ID}" --api-version 2025-04-01-preview -o json)"
[[ "$(json_value '.properties.disableLocalAuth' <<<"${account_json}")" == "true" ]] || fail "Foundry account local auth is not disabled"
pass "Foundry account local auth is disabled"

account_host_json="$(az resource show --ids "${ACCOUNT_CAPABILITY_HOST_ID}" --api-version 2025-04-01-preview -o json)"
[[ "$(json_value '.properties.provisioningState' <<<"${account_host_json}")" == "Succeeded" ]] || fail "Account capability host is not Succeeded"
pass "Account capability host is Succeeded"

project_json="$(az resource show --ids "${PROJECT_ID}" --api-version 2025-04-01-preview -o json)"
PROJECT_PRINCIPAL_ID="$(json_value '.identity.principalId' <<<"${project_json}")"
PROJECT_WORKSPACE_ID="$(json_value '.properties.workspaceId' <<<"${project_json}")"
[[ "$(json_value '.identity.type' <<<"${project_json}")" == *SystemAssigned* ]] || fail "Project missing system-assigned identity"
[[ "$(json_value '.identity.type' <<<"${project_json}")" == *UserAssigned* ]] || fail "Project missing user-assigned identity"
[[ -n "${PROJECT_PRINCIPAL_ID}" ]] || fail "Project principal ID is empty"
[[ -n "${PROJECT_WORKSPACE_ID}" ]] || fail "Project workspace ID is empty"
pass "Project has system-assigned and user-assigned identities"

project_host_json="$(az resource show --ids "${PROJECT_CAPABILITY_HOST_ID}" --api-version 2025-04-01-preview -o json)"
[[ "$(json_value '.properties.provisioningState' <<<"${project_host_json}")" == "Succeeded" ]] || fail "Project capability host is not Succeeded"
jq -e --arg name "${COSMOS_CONNECTION_NAME}" '.properties.threadStorageConnections | index($name)' <<<"${project_host_json}" >/dev/null || fail "Project capability host missing Cosmos binding"
jq -e --arg name "${STORAGE_CONNECTION_NAME}" '.properties.storageConnections | index($name)' <<<"${project_host_json}" >/dev/null || fail "Project capability host missing Storage binding"
jq -e --arg name "${SEARCH_CONNECTION_NAME}" '.properties.vectorStoreConnections | index($name)' <<<"${project_host_json}" >/dev/null || fail "Project capability host missing Search binding"
pass "Project capability host is Succeeded and all bindings are present"

for connection_name in "${COSMOS_CONNECTION_NAME}" "${STORAGE_CONNECTION_NAME}" "${SEARCH_CONNECTION_NAME}"; do
  connection_json="$(az resource show --ids "${PROJECT_ID}/connections/${connection_name}" --api-version 2025-04-01-preview -o json)"
  [[ "$(json_value '.properties.authType' <<<"${connection_json}")" == "AAD" ]] || fail "Connection ${connection_name} is not AAD"
done
pass "Project connections use AAD auth"

az cosmosdb sql database show \
  --resource-group "${RESOURCE_GROUP}" \
  --account-name "${COSMOS_DB_ACCOUNT_NAME}" \
  --name "${DATABASE_NAME}" \
  -o none

for container_name in "${CONTAINERS[@]}"; do
  az cosmosdb sql container show \
    --resource-group "${RESOURCE_GROUP}" \
    --account-name "${COSMOS_DB_ACCOUNT_NAME}" \
    --database-name "${DATABASE_NAME}" \
    --name "${container_name}" \
    -o none
done
pass "Cosmos DB database and required containers exist"

model_json="$(az cognitiveservices account deployment show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${ACCOUNT_NAME}" \
  --deployment-name "${MODEL_DEPLOYMENT_NAME}" \
  -o json)"
[[ "$(json_value '.properties.model.name' <<<"${model_json}")" == "${MODEL_NAME}" ]] || fail "Model name mismatch"
[[ "$(json_value '.properties.model.version' <<<"${model_json}")" == "${MODEL_VERSION}" ]] || fail "Model version mismatch"
[[ "$(json_value '.sku.name' <<<"${model_json}")" == "${MODEL_SKU}" ]] || fail "Model SKU mismatch"
[[ "$(json_value '.sku.capacity | tostring' <<<"${model_json}")" == "${MODEL_CAPACITY}" ]] || fail "Model capacity mismatch"
pass "Model deployment matches expected model, version, SKU, and capacity"

az role assignment list --assignee "${PROJECT_PRINCIPAL_ID}" --scope "${COSMOS_DB_ID}" --role "Cosmos DB Operator" --query '[0].id' -o tsv | grep -q . || fail "Cosmos DB Operator role assignment missing"
az cosmosdb sql role assignment list --resource-group "${RESOURCE_GROUP}" --account-name "${COSMOS_DB_ACCOUNT_NAME}" --query "[?principalId=='${PROJECT_PRINCIPAL_ID}' && scope=='${COSMOS_DB_ID}'] | [0].id" -o tsv | grep -q . || fail "Cosmos DB SQL data contributor assignment missing"
az role assignment list --assignee "${PROJECT_PRINCIPAL_ID}" --scope "${STORAGE_ACCOUNT_ID}" --role "Storage Account Contributor" --query '[0].id' -o tsv | grep -q . || fail "Storage Account Contributor assignment missing"
az role assignment list --assignee "${PROJECT_PRINCIPAL_ID}" --scope "${SEARCH_SERVICE_ID}" --role "Search Index Data Contributor" --query '[0].id' -o tsv | grep -q . || fail "Search Index Data Contributor assignment missing for project SMI"
az role assignment list --assignee "${PROJECT_PRINCIPAL_ID}" --scope "${SEARCH_SERVICE_ID}" --role "Search Service Contributor" --query '[0].id' -o tsv | grep -q . || fail "Search Service Contributor assignment missing for project SMI"
pass "Core RBAC assignments exist at expected scopes"

ACCOUNT_ENDPOINT="$(az cognitiveservices account show --resource-group "${RESOURCE_GROUP}" --name "${ACCOUNT_NAME}" --query properties.endpoint -o tsv)"
[[ -n "${ACCOUNT_ENDPOINT}" ]] || ACCOUNT_ENDPOINT="https://${ACCOUNT_NAME}.cognitiveservices.azure.com/"
TOKEN="$(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)"
REQUEST_BODY="$(jq -n '{messages: [{role: "user", content: "Hello"}], max_completion_tokens: 32}')"
RESPONSE_FILE="$(mktemp)"
HTTP_STATUS="$(curl -sS -o "${RESPONSE_FILE}" -w '%{http_code}' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -X POST \
  "${ACCOUNT_ENDPOINT%/}/openai/deployments/${MODEL_DEPLOYMENT_NAME}/chat/completions?api-version=2025-01-01-preview" \
  --data "${REQUEST_BODY}")"

if [[ "${HTTP_STATUS}" -lt 200 || "${HTTP_STATUS}" -ge 300 ]]; then
  echo "Chat Completions smoke test failed with HTTP ${HTTP_STATUS}:" >&2
  cat "${RESPONSE_FILE}" >&2
  rm -f "${RESPONSE_FILE}"
  exit 1
fi

rm -f "${RESPONSE_FILE}"
pass "Chat Completions Hello smoke test succeeded"
