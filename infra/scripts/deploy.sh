#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESOURCE_GROUP=""
TEMPLATE_FILE="${REPO_ROOT}/infra/main.bicep"
PARAMETERS_FILE="${REPO_ROOT}/infra/main.bicepparam"

usage() {
  cat <<'USAGE'
Usage: infra/scripts/deploy.sh --resource-group <name> [options]

Options:
  --resource-group <name>  Existing resource group to deploy into.
  --template-file <path>   Bicep entrypoint. Defaults to infra/main.bicep.
  --parameters <path>      Bicep parameter file. Defaults to infra/main.bicepparam.
  -h, --help               Show this help.

The script builds Bicep, runs what-if, then prompts before deployment.
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
    --template-file)
      TEMPLATE_FILE="${2:-}"
      shift 2
      ;;
    --parameters)
      PARAMETERS_FILE="${2:-}"
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
[[ -f "${TEMPLATE_FILE}" ]] || fail "Template file not found: ${TEMPLATE_FILE}"
[[ -f "${PARAMETERS_FILE}" ]] || fail "Parameter file not found: ${PARAMETERS_FILE}"

require_command az

az account show --query user.name -o tsv >/dev/null || fail "Azure CLI is not logged in"
az group show --name "${RESOURCE_GROUP}" --query name -o tsv >/dev/null || fail "Resource group not found: ${RESOURCE_GROUP}"

echo "Building Bicep template..."
az bicep build --file "${TEMPLATE_FILE}"

echo "Running deployment what-if..."
az deployment group what-if \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}"

echo
echo "Deployment is guarded. Type 'deploy now' to run az deployment group create."
read -r -p "Confirmation: " CONFIRMATION

if [[ "${CONFIRMATION}" != "deploy now" ]]; then
  echo "Deployment skipped."
  exit 0
fi

DEPLOYMENT_NAME="foundry-standard-agent-$(date -u +%Y%m%d%H%M%S)"

echo "Starting deployment ${DEPLOYMENT_NAME}..."
az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}" \
  --query properties.outputs \
  -o json

echo "Deployment completed. Deployment name: ${DEPLOYMENT_NAME}"
