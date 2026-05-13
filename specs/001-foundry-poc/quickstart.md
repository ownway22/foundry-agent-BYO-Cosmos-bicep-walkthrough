# Quickstart: Foundry Standard Agent Greenfield POC

This quickstart is for the future Phase 4 implementation. It documents the expected operator flow without executing deployment now.

## Prerequisites

- Bash environment on Linux.
- Azure CLI installed and logged in.
- Bicep CLI available through Azure CLI.
- `curl` and `jq` installed.
- Existing target resource group.
- Permissions to deploy resources and create role assignments in the resource group.

## Expected files after Phase 4

```text
infra/
├── main.bicep
├── main.bicepparam
├── modules/
└── scripts/
    ├── deploy.sh
    ├── verify.sh
    └── smoke-test-reasoning.sh
```

## Validate Bicep

Each Bicep file must be built immediately after it is created or changed:

```bash
az bicep build --file infra/main.bicep
az bicep build --file infra/modules/dependent-resources.bicep
az bicep build --file infra/modules/foundry-account.bicep
az bicep build --file infra/modules/foundry-project.bicep
az bicep build --file infra/modules/project-connections.bicep
az bicep build --file infra/modules/account-role-assignments.bicep
az bicep build --file infra/modules/cosmosdb-role-assignments.bicep
az bicep build --file infra/modules/storage-role-assignments.bicep
az bicep build --file infra/modules/search-role-assignments.bicep
az bicep build --file infra/modules/rbac-propagation-wait.bicep
az bicep build --file infra/modules/project-capability-host.bicep
```

## What-if only

Before the user explicitly says `deploy now`, only what-if is allowed:

```bash
az deployment group what-if \
  --resource-group <resource-group-name> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

## Deployment

Deployment is only allowed after explicit approval from the user:

```bash
infra/scripts/deploy.sh --resource-group <resource-group-name>
```

The script must build Bicep, run what-if, prompt for confirmation, then run `az deployment group create` only after confirmation.

## Verification

```bash
infra/scripts/verify.sh --resource-group <resource-group-name>
infra/scripts/smoke-test-reasoning.sh --resource-group <resource-group-name>
```

## gpt-5.4 application-side reminder

Do not send traditional sampling parameters with `gpt-5.4`: `temperature`, `top_p`, `presence_penalty`, `frequency_penalty`, `logprobs`, or `logit_bias`. Use `reasoning_effort` when needed, for example `low` for the POC smoke test.
