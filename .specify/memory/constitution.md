# Foundry Agent BYO Cosmos Bicep Walkthrough Constitution

## Core Principles

### I. Source-of-truth Alignment

`foundry-standard-agent-bicep-walkthrough.md` is the source of truth for Microsoft Foundry Standard Agent Setup architecture, RBAC ordering, capability host behavior, and known pitfalls. If a spec, plan, task, or implementation detail conflicts with that walkthrough, work must stop and the user must decide.

### II. Phase-gated Spec-driven Delivery

Work proceeds in explicit phases: spec, plan, tasks, then implementation. Each phase must be reviewed before the next phase begins. Implementation files under `infra/` must not be created before tasks are approved.

### III. Secure Azure Infrastructure as Code

Bicep is the baseline for Azure resources. Templates and scripts must not hardcode secrets, API keys, connection strings, service principal secrets, or subscription IDs. Managed Identity and least-privilege RBAC are required for data access.

### IV. Guarded Deployment

The implementation may build Bicep and run `az deployment group what-if` during validation. It must not run `az deployment group create` unless the user explicitly says `deploy now` and any deployment script must prompt before creating resources.

### V. Verification-first Acceptance

Each deployable increment must include a verification path. For this POC, verification must cover capability hosts, AAD-only connections, managed identities, RBAC scopes, Cosmos DB `enterprise_memory` storage, model deployment state, and `gpt-5.4` smoke tests without unsupported sampling parameters.

## Additional Constraints

- Public network access is allowed only for this POC variant and must not weaken identity, authentication, or RBAC requirements.
- Capability hosts are immutable after success; changes to bindings require delete/recreate guidance instead of update-in-place behavior.
- Foundry resource API versions remain pinned to `2025-04-01-preview` unless validation requires a user-approved change.
- Bash is the only script language for deployment and verification.

## Governance

This constitution applies to the current repository. Changes to these principles require an explicit user request or approval. Any future spec, plan, tasks, or implementation review must check alignment with this file before proceeding.

**Version**：1.0.0 | **Approved Date**：2026-05-13 | **Last Amended**：2026-05-13
