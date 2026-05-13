# 功能規格：Foundry Standard Agent Greenfield POC

**功能分支**：`001-foundry-poc`
**建立日期**：2026-05-13
**狀態**：Phase 3 tasks 已產生，等待使用者審核後才可進入 implementation
**輸入**：建立可 end-to-end 部署的 Microsoft Foundry Standard Agent Setup Greenfield POC，使用 BYO Cosmos DB 作為 thread storage，採用 Bicep，最終可透過 `az deployment group create` 一鍵部署。

## 問題陳述與目標

本功能要建立一套 Greenfield POC 規格，讓單一 resource group、單一 region、單一 Foundry project 能從零建立 Microsoft Foundry Standard Agent Setup 所需資源，並以 BYO Cosmos DB 作為 agent thread storage。POC 目標是驗證 Standard Setup 的 capability host、AAD-only connections、最小權限 RBAC、Cosmos DB `enterprise_memory` 儲存結構，以及 `gpt-5.4` reasoning model 的基本 Chat Completions 呼叫可用性，同時保留部署失敗時可判讀的驗證與 fallback 說明。

## Source of Truth Alignment

- 架構、RBAC、capability host 設計與已知地雷以 [foundry-standard-agent-bicep-walkthrough.md](../../foundry-standard-agent-bicep-walkthrough.md) 為唯一真實來源。
- 本 POC 的變體約束必須明確寫入規格；若變體與 walkthrough 產生衝突，不得在後續階段自行選邊，必須回到使用者審核。
- Spec、plan、tasks、implementation 必須依序產出；每個階段完成後都必須等待使用者明確核准，才可進入下一階段。
- Governance baseline is now captured in [.specify/memory/constitution.md](../../.specify/memory/constitution.md): source-of-truth alignment, phase gates, secure Azure IaC, guarded deployment, and verification-first delivery.

## 釐清

### 會話 2026-05-13

- Q: RBAC propagation wait gate 是否納入 baseline？ → A: 加入最小 wait gate（約 30-60 秒）作為 baseline 部署鏈的一部分。
- Q: Foundry API version 要固定 walkthrough 的 `2025-04-01-preview`，還是 implementation 可直接升到 `2025-06-01`？ → A: 固定 `2025-04-01-preview`；若驗證要求升級，停下來問使用者。
- Q: Resource naming 是否採用 plan 建議的 `ms` prefix 衍生命名規則？ → A: 採用 `msai${token}`、`msproj${token}`、`ms-cosmos-${token}`、`msst${token}`、`ms-srch-${token}`、`ms-agent-mi-${token}`。
- Q: Project identity 是否將 UMI 納入 baseline？ → A: 納入 UMI baseline；Project identity 使用 `SystemAssigned, UserAssigned`。

## In-scope / Out-of-scope

<!-- markdownlint-disable MD060 -->

| 類別      | In-scope                                                                                                                                                                          | Out-of-scope                                                                                |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 資源建立  | 從零建立 Foundry account、Foundry project、model deployment、Cosmos DB、Storage、AI Search、connections、account-level capability host、project-level capability host 與必要 RBAC | 引用既有 resource ID、跨 resource group、跨 region、跨 subscription 資源引用                |
| 網路      | POC 使用 public network access，且所有資源位於單一 region                                                                                                                         | Private Endpoint、Managed VNet、APIM as AI Gateway、CMK、跨區資料路徑                       |
| Cosmos DB | 使用 Serverless mode；由 Standard Setup 建立或驗證 `enterprise_memory` database 與三個 required containers                                                                        | Provisioned throughput、低於 3000 RU/s 的 provisioned POC、container scope Cosmos RBAC 綁定 |
| 安全      | Foundry account 禁用 local auth；connections 使用 AAD；project 使用 System-Assigned + User-Assigned Managed Identity；遵循 walkthrough Phase 3 + Phase 5 RBAC                     | API key connection、service principal、hardcoded secret、connection string、subscription ID |
| Model     | 預設部署 `gpt-5.4`、版本 `2026-03-05`、SKU `GlobalStandard`、capacity 50；README 說明 East US quota fallback                                                                      | 把 `gpt-5.4`、`gpt-5.4-mini`、`gpt-5.4-nano` 視為同一模型；POC 階段壓測 400K context 極限   |
| 驗證      | 部署後驗證 capability host、Cosmos DB database/containers、project connections、`gpt-5.4` Chat Completions、`reasoning_effort` smoke test                                         | 建立正式 production runbook、CI/CD pipeline、資料保留政策、負載測試                         |

<!-- markdownlint-enable MD060 -->

## 使用者情境與測試 _（必填）_

### 使用者故事 1 - 一鍵部署 POC 環境（優先順序：P1）

平台工程師需要一套可審核、可重複部署的 Greenfield POC 定義，從空的目標 resource group 建立完整 Foundry Standard Agent Setup，避免手動步驟漏掉 capability host 或 RBAC。

**優先順序原因**：這是 POC 的核心價值；沒有可重複部署的環境，就無法驗證 BYO storage 與 agent runtime 行為。

**獨立測試**：在具備必要 Azure 權限的 resource group 中執行部署流程，確認所有指定資源與關聯狀態可被查詢到。

**驗收情境**：

1. **假設** 使用者已登入 Azure 並具備目標 resource group 的部署與 role assignment 權限，**當** 執行 POC 部署流程，**則** Foundry account、project、dependent resources、connections 與 capability hosts 均建立成功。
2. **假設** 部署完成，**當** 查詢 project capability host，**則** provisioning state 為 `Succeeded` 且綁定 thread、storage、vector store connections。

---

### 使用者故事 2 - 驗證 AAD-only Standard Setup（優先順序：P1）

安全審核者需要確認 POC 即使使用 public network access，也不使用 API key、secret 或 service principal，且 Standard Agent Setup 的資料存取由 Managed Identity 與最小權限 RBAC 控制。

**優先順序原因**：安全基線是硬性規則，若驗證失敗，POC 不可接受。

**獨立測試**：檢查 Foundry account local auth、account/project capability host state 與 bindings、project identity、connection auth type、RBAC assignment scope、Cosmos DB SQL role assignment scope，以及 Cosmos DB `enterprise_memory` database 和 required containers。

**驗收情境**：

1. **假設** 部署完成，**當** 檢查 Foundry account，**則** local auth 被停用且不需 API key 即可進行 AAD-based 呼叫。
2. **假設** connections 已建立，**當** 檢查 Cosmos DB、Storage、AI Search connections，**則** 每一條 connection 的 authentication type 均為 AAD。
3. **假設** RBAC 已配置，**當** 檢查 Cosmos DB role assignments，**則** control plane role 位於 account scope，data plane role 遵循 walkthrough 的 Phase 3 + Phase 5 處理方式，且不綁在個別 Cosmos DB container 上。

---

### 使用者故事 3 - 驗證 gpt-5.4 reasoning model 呼叫（優先順序：P2）

應用程式開發者需要知道 POC 部署的 `gpt-5.4` 是 reasoning model，與傳統 `gpt-4o` 類模型的 sampling 參數行為不同，並能用不含不支援參數的 smoke test 成功取得一次回覆。

**優先順序原因**：模型呼叫參數若錯誤會直接造成 400，會誤判為部署失敗或服務不可用。

**獨立測試**：使用部署後取得的 endpoint 與 AAD token，送出不含傳統 sampling 參數的 Chat Completions 請求，並再送出包含 `reasoning_effort: "low"` 的 smoke test。

**驗收情境**：

1. **假設** model deployment 成功，**當** 呼叫 Chat Completions API 並要求回覆 `Hello`，**則** 服務回傳成功回應。
2. **假設** 呼叫端加入 `reasoning_effort: "low"` 且不帶 sampling 參數，**當** 執行 reasoning smoke test，**則** 請求成功且可觀察到模型正常回應。

### 邊界情境

- 若 East US 的 `gpt-5.4` Global Standard capacity 50 quota 不足，部署結果必須能讓使用者判斷是 capacity/quota 問題，而 README 必須說明 fallback 至 `gpt-5.4-mini` 或 `gpt-5-mini` 的取捨。
- 若 capability host provisioning 需要等待 RBAC propagation，baseline 部署鏈必須在 project capability host 建立前加入最小 wait gate；不得透過 update existing capability host 修復。
- 若應用程式 smoke test 帶入 `temperature`、`top_p`、`presence_penalty`、`frequency_penalty`、`logprobs` 或 `logit_bias`，預期會收到 400；POC 腳本不得帶入這些參數。
- 若需要變更 connection 名稱、thread storage 來源或 capability host 設定，POC 必須視為需刪除 project 重建，而不是 update capability host。

## 驗收條件

1. 規格、計畫、任務與實作四個階段必須逐階段產出，且每個階段完成後等待使用者審核，不得自動跳到下一階段。
2. Phase 4 最終產物必須能在使用者明確要求部署時，透過 `az deployment group create` 對單一 resource group 進行一鍵部署。
3. Template 必須從零建立所有 POC 資源，不接受既有 Cosmos DB、Storage、AI Search、Foundry account 或 model deployment resource ID 作為必要輸入。
4. 預設 region 必須為 `eastus`，且 region 必須是可覆寫參數。
5. Cosmos DB 必須使用 Serverless mode，並驗證 `enterprise_memory` database 及 `thread-message-store`、`system-thread-message-store`、`agent-entity-store` 三個 container 存在。
6. Foundry account 必須禁用 local auth；任何 connection 均不得使用 API key authentication。
7. Project 必須啟用 System-Assigned + User-Assigned Managed Identity，且不得使用 service principal 或 hardcoded secret。
8. RBAC 必須遵循 walkthrough Phase 3 + Phase 5 的最小權限表；Cosmos DB data role 不得綁定在 individual container scope。
9. 必須建立 account-level capability host，即使其 properties 為空；也必須建立 project-level capability host 並綁定三類 storage connections。
10. 不得對既有 capability host 做 update；任何 capability host 設定變更都必須以刪除 project 並重建為邊界條件處理。
11. Model deployment 預設必須明確使用 `gpt-5.4`、版本 `2026-03-05`、SKU `GlobalStandard`、capacity 50。
12. README 與 smoke test 必須明確說明 `gpt-5.4` reasoning model 不支援傳統 sampling 參數，且 smoke test 不得帶入這些參數。
13. README 必須說明 East US quota/capacity 風險，以及 fallback 到 `gpt-5.4-mini` `2026-03-17` 或 `gpt-5-mini` `2025-08-07` 時的能力與相容性取捨。

## 非功能需求

### Security

- POC 必須採 AAD-first posture：Foundry account `disableLocalAuth`、connection `authType`、project identity、role assignments 皆可被部署後驗證。
- 不得在 repository、parameter file 或 shell scripts 中 hardcode secret、connection string、subscription ID 或 API key。
- 所有部署與驗證腳本必須使用 Bash。
- Public network access 是本 POC 變體需求，但不得因此放寬 identity、authType 或 RBAC 基線。

### Cost

- Cosmos DB 使用 Serverless mode，以降低 POC 閒置成本並避開 provisioned RU/s 不足造成 capability host provisioning failure。
- Model capacity 預設為 50；若 East US quota 不足，POC 文件必須引導使用者選擇較小 reasoning model fallback，而非自動改寫主要模型。
- Out-of-scope 的 CMK、Private Endpoint、APIM 與 production-grade monitoring 不納入本 POC 成本。

### Region

- 預設 region 為 `eastus`，所有 Greenfield 資源應部署在同一 region。
- Region 必須可被參數覆寫，但跨 region 資源拓樸不屬於本 POC。
- README 必須提醒 East US Global Standard 容量可能緊張，且 fallback model 是 deploy-time 決策。

## gpt-5.4 Reasoning Model Application-side 注意事項

- `gpt-5.4` 屬於 reasoning model 系列；呼叫端不得沿用傳統 chat model 的 sampling 參數假設。
- 不支援 `temperature`、`top_p`、`presence_penalty`、`frequency_penalty`、`logprobs`、`logit_bias` 等傳統 sampling 參數；呼叫端帶入時預期會收到 400。
- 支援 `reasoning_effort`，允許值為 `minimal`、`low`、`medium`、`high`，用於控制思考深度與可能的成本/延遲取捨。
- 同時支援 Chat Completions API 與 Responses API；POC 階段以 Chat Completions API 驗證基本可用性即可。
- Context window 達 400K，input 272K、output 128K；POC 不需刻意測試極限 context，但 README 必須提醒下游應用程式設計者合理控制 prompt 與輸出長度。
- `gpt-5.4`、`gpt-5.4-mini`、`gpt-5.4-nano` 是不同 model，不得在 Bicep、README 或 smoke test 中混用名稱。

## 需求 _（必填）_

### 功能性需求

- **FR-001**：系統必須提供單一 Greenfield POC 部署定義，建立完整 Foundry Standard Agent Setup 所需資源。
- **FR-002**：系統必須將所有主要資源限制在單一 resource group、單一 region、單一 Foundry project。
- **FR-003**：系統必須提供可覆寫的 deployment region，預設值為 `eastus`。
- **FR-004**：系統必須部署 `gpt-5.4` model，版本 `2026-03-05`，SKU `GlobalStandard`，capacity 50。
- **FR-005**：系統必須使用 Cosmos DB Serverless mode 作為 thread storage 的 BYO data resource。
- **FR-006**：系統必須建立 project connections for Cosmos DB、Storage、AI Search，且所有 connections 必須使用 AAD authentication。
- **FR-007**：系統必須建立 account-level capability host 與 project-level capability host，且 project-level capability host 必須綁定 thread、storage、vector store connections。
- **FR-008**：系統必須遵循 walkthrough 中 Phase 3 + Phase 5 RBAC 要求，包含 Cosmos DB control plane 與 data plane 的特殊順序與 scope。
- **FR-009**：系統必須提供部署前 what-if、部署後 verify、Chat Completions smoke test 與 reasoning smoke test 的操作說明或腳本。
- **FR-010**：系統必須在 README 說明 `gpt-5.4` reasoning model 的 unsupported sampling parameters、`reasoning_effort`、API 支援與 fallback model 取捨。
- **FR-011**：系統不得建立或要求使用 API key、connection string、service principal secret 或 hardcoded subscription ID。
- **FR-012**：系統必須在 RBAC role assignments 完成後、project capability host 建立前加入最小 RBAC propagation wait gate，以降低首次部署因 eventual consistency 失敗的風險。
- **FR-013**：Foundry account、project、connection、capability host 與 model deployment resource type 必須固定使用 walkthrough baseline `2025-04-01-preview`；若 build 或 provider validation 要求升級，必須停下來由使用者審核。
- **FR-014**：系統必須使用 `ms` prefix 衍生命名規則：Foundry account `msai${token}`、project `msproj${token}`、Cosmos DB `ms-cosmos-${token}`、Storage `msst${token}`、Search `ms-srch-${token}`、UMI `ms-agent-mi-${token}`。
- **FR-015**：系統必須建立 User-Assigned Managed Identity 並將 Foundry Project identity 設為 `SystemAssigned, UserAssigned`，以貼齊 walkthrough 中 Project SMI + UMI 的 Storage/Search RBAC 表。

### 關鍵實體

- **Foundry Account**：POC 的 AI Services account，必須啟用 project management、禁用 local auth，並擁有 account-level capability host。
- **Foundry Project**：Standard Agent Setup 的 project boundary，必須啟用 System-Assigned + User-Assigned Managed Identity，承載 connections 與 project-level capability host。
- **Capability Host**：Agent capabilities 的 binding boundary；account-level host 必須存在，project-level host 綁定 Cosmos DB、Storage、AI Search connections，且建立後不可更新。
- **Cosmos DB Thread Storage**：BYO thread state resource，使用 Serverless mode，包含 `enterprise_memory` database 與三個 required containers。
- **Project Connections**：Foundry project 到 Cosmos DB、Storage、AI Search 的 AAD-only connected resources。
- **Model Deployment**：`gpt-5.4` deployment，包含 model name、version、SKU、capacity 與 fallback 說明。
- **RBAC Assignments**：讓 project identity 能建立與使用 dependent resources 的 control plane 與 data plane permission set。

## 成功標準 _（必填）_

### 可衡量的成果

- **SC-001**：具備 Azure 權限的使用者可在 30 分鐘內完成一次 Greenfield POC 部署與基本驗證。
- **SC-002**：部署後驗證能確認 100% 的 required capability hosts、connections、Cosmos DB database/containers 與 model deployment 狀態。
- **SC-003**：安全檢查能確認 0 個 API key based connections、0 個 hardcoded secrets、0 個 service principal secrets。
- **SC-004**：`Hello` Chat Completions smoke test 與 `reasoning_effort: "low"` smoke test 均能成功取得一次模型回應。
- **SC-005**：README 能讓首次接手的開發者在 10 分鐘內理解 `gpt-5.4` reasoning model 的不支援參數、fallback 選項與 POC 部署限制。
- **SC-006**：若遇 East US quota/capacity failure，使用者可從 README 在 5 分鐘內判斷是否改用 `gpt-5.4-mini` 或 `gpt-5-mini` fallback。

## 假設條件與已確認決策

### 假設條件

- 使用者會在 Phase 4 前提供或自行選定目標 subscription 與 resource group；規格與 templates 不 hardcode subscription ID。
- 目標 resource group 已存在，且使用者具備部署 resource 與建立 role assignment 的權限。
- POC 的「從零建立所有資源」指的是 resource group 內的 application resources；resource group 本身不一定由 template 建立。
- POC 使用 public network access 是刻意的 Greenfield 變體，walkthrough §5.3 的 Foundry account 範例已改為 `publicNetworkAccess: 'Enabled'`，但仍保留 AAD-only 與最小權限 RBAC 基線。
- Resource names 會以 `ms` 作為前綴詞，Phase 2 需定義可重複、符合 Azure 命名限制且避免碰撞的衍生規則。

### 已確認決策

1. **Public network access**：以 POC 變體為準，Foundry account example 使用 `publicNetworkAccess: 'Enabled'`；README 需標示此 POC 不代表 production FSI/private baseline。
2. **Project identity**：納入 UMI baseline；Project identity 使用 `SystemAssigned, UserAssigned`，Storage/Search RBAC 指派給 Project SMI + UMI。
3. **Resource naming convention**：使用 `ms` 作為資源名稱前綴；資源名稱採用 `msai${token}`、`msproj${token}`、`ms-cosmos-${token}`、`msst${token}`、`ms-srch-${token}`、`ms-agent-mi-${token}`。
