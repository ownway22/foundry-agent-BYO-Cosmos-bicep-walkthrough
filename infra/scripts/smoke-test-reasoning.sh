#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP=""
DEPLOYMENT_NAME=""
ACCOUNT_NAME=""
MODEL_DEPLOYMENT_NAME=""

usage() {
  cat <<'USAGE'
Usage: infra/scripts/smoke-test-reasoning.sh --resource-group <name> [options]

Options:
  --resource-group <name>      Resource group that contains the deployment.
  --deployment-name <name>     Deployment name. Defaults to latest successful group deployment.
  --account-name <name>        Foundry account name. Defaults to deployment output.
  --model-deployment <name>    Model deployment name. Defaults to deployment output.
  -h, --help                   Show this help.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
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
    --model-deployment)
      MODEL_DEPLOYMENT_NAME="${2:-}"
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
MODEL_DEPLOYMENT_NAME="${MODEL_DEPLOYMENT_NAME:-$(output_value modelDeploymentName)}"

[[ -n "${ACCOUNT_NAME}" ]] || fail "Foundry account name not provided and not found in deployment outputs"
[[ -n "${MODEL_DEPLOYMENT_NAME}" ]] || fail "Model deployment name not provided and not found in deployment outputs"

ACCOUNT_ENDPOINT="$(az cognitiveservices account show --resource-group "${RESOURCE_GROUP}" --name "${ACCOUNT_NAME}" --query properties.endpoint -o tsv)"
[[ -n "${ACCOUNT_ENDPOINT}" ]] || ACCOUNT_ENDPOINT="https://${ACCOUNT_NAME}.cognitiveservices.azure.com/"

TOKEN="$(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)"
REQUEST_BODY="$(jq -n '{messages: [{role: "user", content: "Say hello in one short sentence."}], max_completion_tokens: 64, reasoning_effort: "low"}')"
RESPONSE_FILE="$(mktemp)"
HTTP_STATUS="$(curl -sS -o "${RESPONSE_FILE}" -w '%{http_code}' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -X POST \
  "${ACCOUNT_ENDPOINT%/}/openai/deployments/${MODEL_DEPLOYMENT_NAME}/chat/completions?api-version=2025-01-01-preview" \
  --data "${REQUEST_BODY}")"

if [[ "${HTTP_STATUS}" -eq 400 ]]; then
  echo "Reasoning smoke test returned HTTP 400:" >&2
  cat "${RESPONSE_FILE}" >&2
  rm -f "${RESPONSE_FILE}"
  exit 1
fi

if [[ "${HTTP_STATUS}" -lt 200 || "${HTTP_STATUS}" -ge 300 ]]; then
  echo "Reasoning smoke test failed with HTTP ${HTTP_STATUS}:" >&2
  cat "${RESPONSE_FILE}" >&2
  rm -f "${RESPONSE_FILE}"
  exit 1
fi

cat "${RESPONSE_FILE}"
rm -f "${RESPONSE_FILE}"
echo
echo "PASS: Reasoning smoke test succeeded"
