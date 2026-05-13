# 任務：Foundry Standard Agent Greenfield POC

**輸入**：來自 `/specs/001-foundry-poc/` 的設計文件
**先決條件**：`plan.md`、`spec.md`、`research.md`、`data-model.md`、`contracts/script-contracts.md`、`quickstart.md`
**測試**：本功能未要求 TDD test suite；測試任務以 Bash verification scripts、Bicep build、Azure what-if、post-deployment smoke tests 表達。
**組織方式**：任務依使用者故事分組，讓每個故事可在基礎建設完成後獨立實作與驗證。

## 格式：`[ID] [P?] [Story] 描述`

- **[P]**：可平行執行（不同檔案、無相依性）
- **[Story]**：此任務所屬的使用者故事（US1、US2、US3）
- 每個任務描述均包含確切檔案或目錄路徑

## 階段 1：設置（共用基礎建設）

**目的**：建立 Phase 4 實作會使用的 IaC 與 script 結構。

- [x] T001 建立 `infra/modules/` 與 `infra/scripts/` 目錄結構
- [x] T002 [P] 在 `infra/main.bicepparam` 建立 POC 預設參數：`eastus`、`gpt-5.4`、`2026-03-05`、`GlobalStandard`、capacity `50`、`namePrefix='ms'`
- [x] T003 [P] 在 `infra/main.bicep` 建立 resource-group scope、共同參數、`ms` 命名 token、module orchestration skeleton 與 deployment outputs skeleton

---

## 階段 2：基礎建設（阻擋性先決條件）

**目的**：建立所有使用者故事都會共用的 Bash script 基礎與輸出查詢框架。

**重要**：此階段完成前不可開始任何使用者故事工作。

- [x] T004 在 `infra/scripts/deploy.sh` 建立 Bash strict mode、argument parser、Azure CLI login check、target resource group existence check 與 help output skeleton
- [x] T005 [P] 在 `infra/scripts/verify.sh` 建立 Bash strict mode、argument parser、deployment outputs lookup skeleton 與 JSON parsing helper skeleton
- [x] T006 [P] 在 `infra/scripts/smoke-test-reasoning.sh` 建立 Bash strict mode、argument parser、deployment endpoint lookup skeleton 與 AAD token acquisition skeleton

**檢查點**：基礎 script 與 IaC entrypoint 就緒，可以開始使用者故事實作。

---

## 階段 3：使用者故事 1 - 一鍵部署 POC 環境（優先順序：P1）

**目標**：從空的既有 resource group 建立完整 Foundry Standard Agent Setup POC，包括 dependent resources、Foundry account/project、connections、RBAC、wait gate、capability hosts 與 guarded deployment flow。

**獨立測試**：對 `infra/main.bicep` 執行 `az bicep build`，再由 `infra/scripts/deploy.sh --resource-group <name>` 先完成 build 與 what-if；使用者明確確認後部署，並能查到指定資源與 capability hosts。

### 使用者故事 1 的實作

- [x] T007 [P] [US1] 在 `infra/modules/dependent-resources.bicep` 建立 Cosmos DB Serverless、StorageV2 flat namespace、AI Search Standard S1 與 User-Assigned Managed Identity
- [x] T008 [P] [US1] 在 `infra/modules/foundry-account.bicep` 建立 `Microsoft.CognitiveServices/accounts@2025-04-01-preview`、`disableLocalAuth=true`、`publicNetworkAccess='Enabled'`、account-level capability host `default` 與 `gpt-5.4` model deployment
- [x] T009 [US1] 在 `infra/modules/foundry-project.bicep` 建立 Foundry project，identity type 必須為 `SystemAssigned, UserAssigned` 並綁定 `ms-agent-mi-${token}` UMI
- [x] T010 [P] [US1] 在 `infra/modules/account-role-assignments.bicep` 建立 no-op compatibility module，接受 account/project IDs 與 Project SMI/UMI principal IDs，但 baseline 不建立任何未命名的 Foundry account/project role assignment
- [x] T011 [P] [US1] 在 `infra/modules/cosmosdb-role-assignments.bicep` 建立 Cosmos DB Operator control-plane assignment 與 Cosmos DB Built-in Data Contributor SQL role assignment，scope 必須是 Cosmos DB account
- [x] T012 [P] [US1] 在 `infra/modules/storage-role-assignments.bicep` 建立 Storage Account Contributor assignment 與 Foundry-generated blob container data role assignment patterns for Project SMI + UMI
- [x] T013 [P] [US1] 在 `infra/modules/search-role-assignments.bicep` 建立 Search Index Data Contributor 與 Search Service Contributor assignments for Project SMI + UMI
- [x] T014 [US1] 在 `infra/modules/project-connections.bicep` 建立 Cosmos DB、Storage、AI Search project connections，所有 connection 必須使用 `authType: 'AAD'`
- [x] T015 [US1] 在 `infra/modules/rbac-propagation-wait.bicep` 建立 Bash-only deploymentScript wait gate，等待 30-60 秒且 depends on all RBAC modules
- [x] T016 [US1] 在 `infra/modules/project-capability-host.bicep` 建立 immutable project capability host `default`，綁定 thread storage、file storage、vector store connections，並 depends on connections、RBAC modules 與 wait gate
- [x] T017 [US1] 在 `infra/main.bicep` 串接所有 modules、設定正確 `dependsOn` 鏈、輸出 `foundryAccountName`、`projectName`、`modelDeploymentName`、`cosmosDbAccountName`、`storageAccountName`、`searchServiceName`、`projectEndpoint`、`location`
- [x] T018 [US1] 在 `infra/scripts/deploy.sh` 實作 `az bicep build --file infra/main.bicep`、`az deployment group what-if`、terminal confirmation prompt，以及確認後才執行 `az deployment group create`
- [x] T019 [US1] 針對 `infra/main.bicep` 與 `infra/modules/*.bicep` 執行並修正 `az bicep build` 驗證問題

**檢查點**：US1 完成後，POC deployment definition 應可 build、what-if，並在使用者確認後部署完整資源拓樸。

---

## 階段 4：使用者故事 2 - 驗證 AAD-only Standard Setup（優先順序：P1）

**目標**：提供部署後安全驗證，確認 POC 不使用 API key、secret、service principal，並以 Managed Identity + RBAC 驅動 Standard Setup data access。

**獨立測試**：部署完成後執行 `infra/scripts/verify.sh --resource-group <name>`，確認 account/project capability hosts、project capability host bindings、local auth、project identity、AAD connections、model deployment state、Cosmos DB database/containers、RBAC scopes 與 Cosmos DB SQL role assignment scopes 全部符合規格。

### 使用者故事 2 的實作

- [x] T020 [US2] 在 `infra/scripts/verify.sh` 實作 account capability host 與 project capability host provisioning state 檢查，兩者都必須為 `Succeeded`
- [x] T021 [US2] 在 `infra/scripts/verify.sh` 實作 project capability host thread/file/vector bindings 檢查，必須對應 Cosmos DB、Storage、AI Search connection names
- [x] T022 [US2] 在 `infra/scripts/verify.sh` 實作 Foundry account `disableLocalAuth`、project `SystemAssigned, UserAssigned` identity 與 UMI binding 檢查
- [x] T023 [US2] 在 `infra/scripts/verify.sh` 實作 Cosmos DB、Storage、AI Search project connections 存在且 `authType` 為 `AAD` 的檢查
- [x] T024 [US2] 在 `infra/scripts/verify.sh` 實作 Cosmos DB `enterprise_memory` database 與 `thread-message-store`、`system-thread-message-store`、`agent-entity-store` containers 存在性檢查
- [x] T025 [US2] 在 `infra/scripts/verify.sh` 實作 model deployment state 與 model name/version/SKU/capacity 檢查
- [x] T026 [US2] 在 `infra/scripts/verify.sh` 實作 Cosmos DB Operator、Cosmos DB Built-in Data Contributor SQL role、Storage roles、Search roles 的 principal 與 scope 檢查
- [x] T027 [P] [US2] 在 `README.md` 新增 AAD-only security baseline、public network access POC caveat、Managed Identity/RBAC 說明與 no-secret constraints
- [x] T028 [US2] 在 `infra/scripts/deploy.sh` 確認所有 output/logging 不列印 API keys、connection strings、subscription IDs 或 secrets
- [x] T029 [US2] 針對 `infra/scripts/verify.sh` 執行 shell syntax validation，並修正 AAD/RBAC verification path 的 Bash 錯誤

**檢查點**：US2 完成後，安全審核者可用單一 verification script 證明 AAD-only 與 RBAC baseline。

---

## 階段 5：使用者故事 3 - 驗證 gpt-5.4 reasoning model 呼叫（優先順序：P2）

**目標**：提供 `gpt-5.4` Chat Completions 與 `reasoning_effort` smoke tests，避免傳統 sampling parameters 造成 400 被誤判為部署失敗。

**獨立測試**：部署完成後執行 `infra/scripts/verify.sh --resource-group <name>` 的 `Hello` smoke test，以及 `infra/scripts/smoke-test-reasoning.sh --resource-group <name>` 的 `reasoning_effort: "low"` smoke test。

### 使用者故事 3 的實作

- [x] T030 [US3] 在 `infra/scripts/verify.sh` 實作 Chat Completions `Hello` smoke test，payload 不得包含 `temperature`、`top_p`、`presence_penalty`、`frequency_penalty`、`logprobs` 或 `logit_bias`
- [x] T031 [P] [US3] 在 `infra/scripts/smoke-test-reasoning.sh` 實作 AAD token-based `reasoning_effort: "low"` request，HTTP 400 時必須清楚輸出 response body
- [x] T032 [P] [US3] 在 `README.md` 新增 `gpt-5.4` reasoning model 注意事項、unsupported sampling parameters、`reasoning_effort` allowed values、Chat Completions smoke test 操作
- [x] T033 [P] [US3] 在 `README.md` 新增 East US quota/capacity failure 判讀，以及 `gpt-5.4-mini` `2026-03-17`、`gpt-5-mini` `2025-08-07` fallback 取捨與手動參數切換方式
- [x] T034 [US3] 在 `infra/main.bicepparam` 保留 `gpt-5.4` primary defaults，並以註解標示 fallback 必須由使用者顯式修改，不得 silent fallback
- [x] T035 [US3] 對 `infra/scripts/verify.sh` 與 `infra/scripts/smoke-test-reasoning.sh` 執行 grep 檢查，確認沒有傳送 unsupported sampling parameters

**檢查點**：US3 完成後，開發者可用 AAD token smoke test 驗證 `gpt-5.4` 與 reasoning request path。

---

## 階段 6：收尾與跨切面關注點

**目的**：完成文件、格式、安全掃描與非部署 validation；除非使用者明確說 `deploy now`，不得執行實際部署。

- [x] T036 [P] 在 `README.md` 補齊 prerequisites、resource group assumption、`az deployment group what-if`、`infra/scripts/deploy.sh`、`infra/scripts/verify.sh` 與 `infra/scripts/smoke-test-reasoning.sh` 操作流程
- [x] T037 在 `infra/main.bicep` 與 `infra/modules/*.bicep` 檢查 Foundry API family 仍為 `2025-04-01-preview`；若 build/provider validation 要求 `2025-06-01`，停止並回報使用者審核
- [x] T038 在 `infra/main.bicep`、`infra/main.bicepparam`、`infra/modules/*.bicep`、`infra/scripts/*.sh`、`README.md` 執行 hardcoded secret、connection string、API key、subscription ID pattern scan 並移除違規內容
- [x] T039 在 `infra/main.bicep`、`infra/modules/*.bicep` 與 `README.md` 執行 out-of-scope feature scan，確認未加入 Private Endpoint、Managed VNet、APIM、CMK、Key Vault encryption 或 production monitoring baseline
- [x] T040 在 `infra/scripts/*.sh` 執行 Bash syntax validation，修正 syntax、quoting、exit-code handling 與 missing command checks
- [X] T041 在 `infra/main.bicep` 對完整 deployment graph 執行 `az deployment group what-if` dry-run guidance 驗證，確認不需要 existing resource IDs
- [x] T042 在 `README.md` 記錄 capability host immutability、RBAC propagation retry guidance、不得 update existing capability host 的操作邊界
- [x] T043 確認 `.specify/memory/constitution.md` 的 source-of-truth、phase-gate、secure IaC、guarded deployment 與 verification gates 仍與 `specs/001-foundry-poc/spec.md`、`plan.md`、`tasks.md` 一致

---

## 相依性與執行順序

### 階段相依性

- **設置（階段 1）**：無相依性，可立即開始。
- **基礎建設（階段 2）**：相依於階段 1，阻擋所有使用者故事。
- **US1（階段 3）**：相依於階段 2，是 MVP 與 US2/US3 的實際部署基礎。
- **US2（階段 4）**：相依於階段 2，可在 US1 IaC 接近完成後實作 verification logic；完整驗證需 US1 deployment outputs。
- **US3（階段 5）**：相依於階段 2，可平行實作 reasoning smoke script；完整驗證需 US1 model deployment。
- **收尾（階段 6）**：相依於 US1、US2、US3 完成。

### 使用者故事相依性

- **US1（P1）**：MVP；不相依其他故事，但包含建立可部署 POC 所需的 RBAC 與 capability host ordering。
- **US2（P1）**：可獨立實作安全驗證腳本，但 deployment-state 驗證需 US1 完成。
- **US3（P2）**：可獨立實作 smoke scripts 與 README model guidance，但 runtime 驗證需 US1 完成。

### 使用者故事內部順序

- Bicep resource modules 優先於 `infra/main.bicep` final wiring。
- RBAC modules 與 wait gate 必須早於 `project-capability-host.bicep` 生效。
- `deploy.sh` 必須先 build，再 what-if，再 prompt，最後才可 create。
- `verify.sh` security checks 與 smoke tests 可分階段加入，但最終必須共用 deployment outputs。

### 平行執行機會

- T002 與 T003 可在 T001 後平行進行。
- T005 與 T006 可與 T004 平行進行。
- T007、T008、T010、T011、T012、T013 可由不同人平行撰寫，之後由 T017 統一串接。
- T027 可與 T020-T026 平行進行。
- T031、T032、T033 可與 T030 平行進行。
- T036 可與 T037-T040 平行進行，但 T041-T043 應在主要 IaC、README 與治理文件更新後執行。

---

## 平行執行範例：使用者故事 1

```text
Task T007: 在 infra/modules/dependent-resources.bicep 建立 dependent resources
Task T008: 在 infra/modules/foundry-account.bicep 建立 Foundry account 與 model deployment
Task T011: 在 infra/modules/cosmosdb-role-assignments.bicep 建立 Cosmos DB role assignments
Task T012: 在 infra/modules/storage-role-assignments.bicep 建立 Storage role assignments
Task T013: 在 infra/modules/search-role-assignments.bicep 建立 Search role assignments
```

## 平行執行範例：使用者故事 2

```text
Task T020-T026: 在 infra/scripts/verify.sh 實作 capability host、identity、AAD connection、Cosmos DB、model deployment 與 RBAC 驗證 checks
Task T027: 在 README.md 撰寫 AAD-only security baseline 文件
```

## 平行執行範例：使用者故事 3

```text
Task T030: 在 infra/scripts/verify.sh 實作 Hello smoke test
Task T031: 在 infra/scripts/smoke-test-reasoning.sh 實作 reasoning smoke test
Task T032-T033: 在 README.md 撰寫 reasoning model 與 fallback 文件
```

---

## 實作策略

### MVP 優先（US1）

- 完成階段 1：設置。
- 完成階段 2：基礎 script skeleton。
- 完成階段 3：US1 one-click deployment definition。
- 停止並驗證：`az bicep build` 與 guarded what-if flow。
- 在使用者明確說 `deploy now` 前，不執行 `az deployment group create`。

### 漸進式交付

- 交付 US1 後，可先展示完整 Bicep graph、what-if 與 deployment script guard。
- 交付 US2 後，可展示 AAD-only、Managed Identity、RBAC scope verification。
- 交付 US3 後，可展示 `gpt-5.4` non-sampling payload 與 reasoning smoke test。
- 最終收尾再執行全域 build、syntax、secret scan 與 README 校對。

### 任務完整性檢查

- US1 覆蓋 FoundryAccount、FoundryProject、UserAssignedManagedIdentity、ModelDeployment、CosmosDbAccount、StorageAccount、SearchService、ProjectConnection、CapabilityHost、RbacAssignment。
- US2 覆蓋 account/project capability host state and bindings、Cosmos DB database/containers、model deployment state、AAD-only connections、local auth disabled、Project SMI + UMI、RBAC principal/scope validation。
- US3 覆蓋 Chat Completions `Hello`、`reasoning_effort: "low"`、unsupported sampling parameter exclusion、fallback model documentation。
- 收尾覆蓋憲章 gates 一致性、hardcoded secret scan、out-of-scope feature scan、Bash syntax validation 與 what-if dry-run guidance。
- 所有 implementation files 皆位於 `infra/` 或 root `README.md`，符合 plan.md 的 infrastructure-only POC 結構。
