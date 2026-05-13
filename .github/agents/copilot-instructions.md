# Foundry Standard Agent POC Development Guidance

Automatically generated for active SpecKit feature plans. Last updated: 2026-05-13.

## Active Technologies

- Bicep for Azure infrastructure-as-code.
- Bash for deployment and verification scripts.
- Azure CLI, Azure Bicep CLI, curl, and jq.
- Microsoft Foundry Standard Agent Setup with BYO Cosmos DB Serverless thread storage.

## Project Structure

```text
specs/001-foundry-poc/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
	└── script-contracts.md

infra/
├── main.bicep
├── main.bicepparam
├── modules/
└── scripts/
```

## Commands

- Validate Bicep syntax with `az bicep build --file <path>` after each Bicep file is created or changed.
- Use `az deployment group what-if` before any deployment.
- Do not run `az deployment group create` unless the user explicitly says `deploy now`.

## Code Style

- Bicep code, comments, and identifiers must be in English.
- Scripts must be Bash only.
- Do not hardcode secrets, connection strings, subscription IDs, or API keys.
- Foundry API resource family is pinned to `2025-04-01-preview` unless provider validation forces a user-approved change.

## Recent Changes

- Added feature `001-foundry-poc` for a Greenfield Microsoft Foundry Standard Agent Setup POC.
- Captured baseline decisions for Project SMI + UMI, RBAC wait gate, `ms` naming, Cosmos DB Serverless, and `gpt-5.4` reasoning model usage.

<!-- 手動新增區段開始 -->
<!-- 手動新增區段結束 -->
