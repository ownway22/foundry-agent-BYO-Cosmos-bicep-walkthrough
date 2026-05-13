# Foundry Standard Agent BYO Cosmos DB Bicep Walkthrough

This repository contains a greenfield Microsoft Foundry Standard Agent Setup POC implemented with Bicep and Bash. It deploys a Foundry account/project, `gpt-5.4` deployment, BYO Cosmos DB thread storage, Storage, Azure AI Search, AAD-only project connections, Managed Identity RBAC, and account/project capability hosts.

The walkthrough source of truth is [foundry-standard-agent-bicep-walkthrough.md](foundry-standard-agent-bicep-walkthrough.md). If the walkthrough and implementation guidance conflict, stop and review before changing behavior.

## Prerequisites

- Linux Bash environment.
- Azure CLI installed and logged in.
- Azure Bicep CLI available through Azure CLI.
- `curl` and `jq` installed.
- An existing target resource group in the target subscription.
- Permission to deploy resources and create role assignments in that resource group.
- Quota for the selected Foundry model in the selected region.

The default region is `eastus`. The deployment assumes the resource group already exists and does not create it.

## Infrastructure Layout

```text
infra/
├── main.bicep
├── main.bicepparam
├── modules/
│   ├── account-role-assignments.bicep
│   ├── cosmosdb-role-assignments.bicep
│   ├── dependent-resources.bicep
│   ├── foundry-account.bicep
│   ├── foundry-project.bicep
│   ├── project-capability-host.bicep
│   ├── project-connections.bicep
│   ├── rbac-propagation-wait.bicep
│   ├── search-role-assignments.bicep
│   └── storage-role-assignments.bicep
└── scripts/
    ├── deploy.sh
    ├── smoke-test-reasoning.sh
    └── verify.sh
```

## Default Parameters

[infra/main.bicepparam](infra/main.bicepparam) contains the POC defaults:

- `location`: `eastus`
- `namePrefix`: `ms`
- `modelDeploymentName`: `gpt-5-4`
- `modelName`: `gpt-5.4`
- `modelVersion`: `2026-03-05`
- `modelSkuName`: `GlobalStandard`
- `modelCapacity`: `50`

Fallback is never automatic. If the primary model is unavailable, explicitly edit the model parameters and rerun validation.

## Validate Bicep

Run Bicep build before any what-if or deployment:

```bash
az bicep build --file infra/main.bicep
```

You can also build modules individually while changing them:

```bash
az bicep build --file infra/modules/dependent-resources.bicep
az bicep build --file infra/modules/foundry-account.bicep
az bicep build --file infra/modules/foundry-project.bicep
az bicep build --file infra/modules/project-connections.bicep
az bicep build --file infra/modules/project-capability-host.bicep
```

## What-if

Before an actual deployment, inspect the resource graph with what-if:

```bash
az deployment group what-if \
  --resource-group <resource-group-name> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

The implementation does not require existing resource IDs. It only requires an existing resource group.

## Guarded Deployment

Use the deployment script for the intended operator flow:

```bash
infra/scripts/deploy.sh --resource-group <resource-group-name>
```

The script performs these steps:

1. Checks Azure CLI login and resource group existence.
2. Runs `az bicep build --file infra/main.bicep`.
3. Runs `az deployment group what-if`.
4. Prompts for the exact confirmation text `deploy now`.
5. Runs `az deployment group create` only after that terminal confirmation.

Do not run `az deployment group create` directly unless the operator has explicitly approved deployment.

## AAD-only Security Baseline

The POC is intentionally no-secret:

- Foundry account sets `disableLocalAuth: true`.
- Project connections use `authType: 'AAD'`.
- Project identity is `SystemAssigned, UserAssigned`.
- Cosmos DB, Storage, and Azure AI Search access is granted with Managed Identity and RBAC.
- Scripts acquire AAD tokens through Azure CLI and do not require API keys, connection strings, service principals, or client secrets.

For POC simplicity, public network access is enabled. Private endpoints, Managed VNet, customer-managed keys, APIM, Key Vault encryption, and production monitoring baselines are intentionally out of scope.

## Post-deployment Verification

After deployment succeeds, run:

```bash
infra/scripts/verify.sh --resource-group <resource-group-name>
```

The verification script checks:

- Account and project capability host provisioning state.
- Project capability host Cosmos DB, Storage, and Azure AI Search bindings.
- Foundry account local auth setting.
- Project System-Assigned and User-Assigned identities.
- AAD project connections.
- Cosmos DB `enterprise_memory` database and required containers.
- Model deployment name, version, SKU, and capacity.
- Cosmos DB, Storage, and Azure AI Search RBAC scopes.
- One Chat Completions `Hello` smoke test through AAD token auth.

If multiple successful deployments exist in the resource group, pass `--deployment-name <name>`.

## Reasoning Smoke Test

Run the focused reasoning request smoke test with:

```bash
infra/scripts/smoke-test-reasoning.sh --resource-group <resource-group-name>
```

The request sends `reasoning_effort: "low"` and prints the HTTP 400 response body if the service rejects the request.

For `gpt-5.4`, do not send traditional sampling fields such as `temperature`, `top_p`, `presence_penalty`, `frequency_penalty`, `logprobs`, or `logit_bias`. Use `reasoning_effort` for this POC path.

## Model Quota and Fallbacks

The primary target is `gpt-5.4` version `2026-03-05` with `GlobalStandard` capacity `50` in `eastus`.

If deployment fails due to quota or capacity, use an explicit parameter change:

- First fallback: `gpt-5.4-mini`, version `2026-03-17`.
- Second fallback: `gpt-5-mini`, version `2025-08-07`.

These fallback models validate the Standard Agent Setup plumbing but are not equivalent to the primary `gpt-5.4` target.

## Capability Host Boundary

The project capability host is immutable after it reaches `Succeeded`. Do not update an existing successful project capability host to change storage, file, or vector bindings. For binding changes, recreate the project through the Bicep deployment flow.

RBAC propagation can take time. The template includes a 60-second wait gate after role assignments and before project capability host creation. If deployment still fails with an RBAC propagation symptom before the capability host succeeds, rerun the same deployment after waiting. Do not mutate a successful capability host.

## Development Validation

Useful local checks:

```bash
az bicep build --file infra/main.bicep
bash -n infra/scripts/deploy.sh infra/scripts/verify.sh infra/scripts/smoke-test-reasoning.sh
grep -R "2025-06-01" infra || true
```

The Foundry API family is intentionally pinned to `2025-04-01-preview` to match the walkthrough.
