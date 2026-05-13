# Research: Foundry Standard Agent Greenfield POC

## Decision: Use Bicep with modular structure

**Rationale**：walkthrough 明確指出 Standard Agent Setup portal 不支援完整設定，Cosmos DB connection 需透過 code 建立，且 capability host immutable。Bicep 能讓 RBAC、connections、capability hosts 與 model deployment 的順序可審核且可重複。

**Alternatives considered**：Portal 手動設定、az CLI 手動建立、直接 clone 官方 sample 不改。Portal 不支援；CLI 容易漏 RBAC/capability host；官方 sample 支援既有 resource ID，但本 POC 要 Greenfield-only。

## Decision: Greenfield-only resource creation

**Rationale**：Phase 1 明確禁止引用既有 resource ID。所有 app resources 在單一 resource group、單一 region 建立，讓 POC 可用 `az deployment group create` 重複部署。

**Alternatives considered**：沿用官方 sample 的 `existing resource ID` 參數。這會違反本 POC 變體，且增加跨 RG/subscription 複雜度。

## Decision: Cosmos DB Serverless mode

**Rationale**：walkthrough 指出 Provisioned RU/s 不足是 `CapabilityHostProvisioningFailed` 常見原因；POC 以 Serverless 避開 3000 RU/s 起跳與 idle cost。

**Alternatives considered**：Provisioned throughput。正式環境可再評估，但 POC 明確排除。

## Decision: Foundry API family pinned to `2025-04-01-preview`

**Rationale**：walkthrough 是 source of truth，且使用者已核准固定此 baseline。若 Bicep build 或 provider validation 要求 `2025-06-01`，必須停下來再審核。

**Alternatives considered**：直接使用 schema lookup 顯示的 `2025-06-01`。這可能偏離 walkthrough，不符合 source-of-truth 規則。

## Decision: Project identity uses `SystemAssigned, UserAssigned`

**Rationale**：SMI 滿足安全基線；UMI 貼齊 walkthrough §3、§5.7、§5.8 的 Storage/Search RBAC 表。UMI 不引入 secret 或 service principal。

**Alternatives considered**：只用 SMI。較簡單，但會偏離 walkthrough 的 SMI + UMI RBAC pattern。

## Decision: Add RBAC propagation wait gate

**Rationale**：walkthrough §8 指出 RBAC eventual consistency 是常見地雷。使用者已核准 baseline 加入 30-60 秒 wait gate，位置在 RBAC role assignments 後、project capability host 前。

**Alternatives considered**：只用 `dependsOn` 或 README 提醒重跑。較簡單，但降低首次部署成功率。

## Decision: gpt-5.4 default with explicit fallback

**Rationale**：POC primary model 是 `gpt-5.4` `2026-03-05` GlobalStandard capacity 50。East US 可能 quota/capacity 緊張，fallback 必須顯式由使用者切換，不可 silent fallback。

**Alternatives considered**：預設使用 mini model 或自動 fallback。這會混淆 `gpt-5.4` 驗證目標。

## Decision: Bash-only scripts

**Rationale**：使用者硬性規則禁止 PowerShell。`deploy.sh`、`verify.sh`、`smoke-test-reasoning.sh` 均使用 Bash、Azure CLI、curl、jq。

**Alternatives considered**：PowerShell 或 mixed shell scripts。違反硬性規則。
