# Foundry Standard Agent BYO Cosmos DB Bicep Walkthrough

本 repository 提供一套 **Microsoft Foundry Standard Agent Setup Greenfield POC**，使用 **Bicep** 建立 Azure resources，並使用 **Bash scripts** 完成部署、驗證與 smoke test。

這份 README 的目標讀者是客戶端開發者：照順序完成 prerequisites、檢查參數、執行 deployment、再跑 verification。

## 官方參考

- Microsoft Learn: [Standard agent setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)
- Official Bicep sample: [43-standard-agent-setup-with-customization](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/43-standard-agent-setup-with-customization)

## 你會部署什麼

此 POC 會在既有 Azure resource group 中建立：

- Microsoft Foundry account 與 Foundry project
- `gpt-5.4` model deployment
- Azure Cosmos DB for NoSQL Serverless，作為 BYO thread storage
- Azure Storage account，作為 file state storage
- Azure AI Search，作為 vector store
- AAD-only project connections
- Project System-Assigned Managed Identity 與 User-Assigned Managed Identity
- Cosmos DB、Storage、Search 所需 RBAC assignments
- Account-level 與 project-level capability hosts

Source of truth 是 [foundry-standard-agent-bicep-walkthrough.md](foundry-standard-agent-bicep-walkthrough.md)。若 README、Bicep 或 script 與該 walkthrough 衝突，請以 walkthrough 為準並先停下來確認。

## 1. 準備環境

請先確認本機或 Dev Container 具備以下工具：

- Linux Bash shell
- Azure CLI
- Azure Bicep CLI，可透過 Azure CLI 使用
- `curl`
- `jq`

確認 Azure CLI 已登入：

```bash
az login
az account show
```

你也需要一個已存在的 Azure resource group。此 POC 不會自動建立 resource group。

```bash
az group show --name <resource-group-name>
```

部署帳號需要具備以下能力：

- 在 resource group 中部署 Azure resources
- 建立 Azure RBAC role assignments
- 建立 Cosmos DB SQL role assignments
- 在目標 region 具備所選 model 的 quota 或 capacity

## 2. 檢查預設參數

部署參數位於 [infra/main.bicepparam](infra/main.bicepparam)。預設值如下：

| Parameter             | Default          |
| --------------------- | ---------------- |
| `location`            | `eastus`         |
| `namePrefix`          | `ms`             |
| `modelDeploymentName` | `gpt-5-4`        |
| `modelName`           | `gpt-5.4`        |
| `modelVersion`        | `2026-03-05`     |
| `modelSkuName`        | `GlobalStandard` |
| `modelCapacity`       | `50`             |

如需修改 region、model 或 capacity，請先更新 [infra/main.bicepparam](infra/main.bicepparam)，再執行後續步驟。

Fallback 不會自動發生。若 `gpt-5.4` 因 quota 或 capacity 無法部署，請明確改用下列其中一組參數：

- `gpt-5.4-mini`，version `2026-03-17`
- `gpt-5-mini`，version `2025-08-07`

## 3. Validate Bicep

部署前先確認 Bicep 可以成功編譯：

```bash
az bicep build --file infra/main.bicep
```

若你正在修改 module，也可以單獨 build：

```bash
az bicep build --file infra/modules/dependent-resources.bicep
az bicep build --file infra/modules/foundry-account.bicep
az bicep build --file infra/modules/foundry-project.bicep
az bicep build --file infra/modules/project-connections.bicep
az bicep build --file infra/modules/project-capability-host.bicep
```

## 4. Preview Deployment

先用 `what-if` 檢查即將建立的 resources：

```bash
az deployment group what-if \
  --resource-group <resource-group-name> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

此 template 是 greenfield POC，不需要輸入既有 Cosmos DB、Storage、Search 或 Foundry resource IDs。唯一前提是 resource group 已存在。

`what-if` 可能會對部分 deployment-time 才能解析的 role assignment 顯示 `Unsupported`，例如 project identity principal ID 或 workspace ID 相關的 scope。這通常代表 what-if 無法提前計算 resource ID，不代表 Bicep build 失敗。

## 5. Deploy

使用 deployment script 執行完整流程：

```bash
infra/scripts/deploy.sh --resource-group <resource-group-name>
```

script 會依序完成：

1. 檢查 Azure CLI login 狀態。
2. 檢查 target resource group 是否存在。
3. 執行 `az bicep build`。
4. 執行 `az deployment group what-if`。
5. 依 terminal 提示確認後，執行 `az deployment group create`。

部署完成後，Azure deployment outputs 會包含後續 verification scripts 需要的 resource names 與 endpoint。

## 6. Verify Deployment

部署成功後執行：

```bash
infra/scripts/verify.sh --resource-group <resource-group-name>
```

`verify.sh` 會檢查：

- Account capability host 與 project capability host provisioning state
- Project capability host 的 thread、file、vector store bindings
- Foundry account 是否停用 local auth
- Project 是否同時具備 System-Assigned 與 User-Assigned Managed Identity
- Project connections 是否使用 `authType: 'AAD'`
- Cosmos DB `enterprise_memory` database 與必要 containers 是否存在
- Model deployment name、version、SKU、capacity 是否符合預期
- Cosmos DB、Storage、Azure AI Search 的 RBAC scopes 是否正確
- AAD token-based Chat Completions `Hello` smoke test 是否成功

若 resource group 中有多個成功 deployment，可指定 deployment name：

```bash
infra/scripts/verify.sh \
  --resource-group <resource-group-name> \
  --deployment-name <deployment-name>
```

## 7. Run Reasoning Smoke Test

若要單獨測試 `gpt-5.4` reasoning request path，執行：

```bash
infra/scripts/smoke-test-reasoning.sh --resource-group <resource-group-name>
```

此 script 使用 Azure CLI 取得 AAD token，並送出包含 `reasoning_effort: "low"` 的 request。若 service 回傳 HTTP 400，script 會輸出 response body，方便判斷是 payload、model 或 API version 問題。

`gpt-5.4` smoke test 不會送出以下 traditional sampling parameters：

- `temperature`
- `top_p`
- `presence_penalty`
- `frequency_penalty`
- `logprobs`
- `logit_bias`

## 架構與檔案結構

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

主要 Bicep 職責：

- [infra/main.bicep](infra/main.bicep)：deployment orchestration、naming、outputs
- [infra/modules/dependent-resources.bicep](infra/modules/dependent-resources.bicep)：Cosmos DB、Storage、Search、UMI
- [infra/modules/foundry-account.bicep](infra/modules/foundry-account.bicep)：Foundry account、account capability host、model deployment
- [infra/modules/foundry-project.bicep](infra/modules/foundry-project.bicep)：Foundry project 與 Managed Identity binding
- [infra/modules/project-connections.bicep](infra/modules/project-connections.bicep)：Cosmos DB、Storage、Search AAD connections
- [infra/modules/project-capability-host.bicep](infra/modules/project-capability-host.bicep)：project capability host bindings

## Security Notes

此 POC 採用 AAD-only baseline：

- Foundry account 設定 `disableLocalAuth: true`
- Project connections 使用 `authType: 'AAD'`
- 不使用 API keys、connection strings、service principal secrets 或 hardcoded credentials
- Cosmos DB、Storage、Azure AI Search access 透過 Managed Identity 與 RBAC 授權
- Storage account 與 Cosmos DB local/key-based access 在 template 中停用或避免使用

為了簡化 POC，public network access 是 enabled。以下 production hardening 項目不在此 POC 範圍內：

- Private Endpoint
- Managed VNet
- Customer-managed key
- APIM
- Key Vault encryption integration
- Production monitoring baseline

## Capability Host 注意事項

Project capability host 成功建立後即視為 immutable。若要修改 thread storage、file storage 或 vector store bindings，建議重新建立 project，而不是 update 既有 capability host。

RBAC propagation 可能需要時間。Template 內含 60 秒 wait gate；若首次部署仍遇到 RBAC propagation 類型錯誤，請等待後重新執行相同 deployment。

## 常見問題

### `gpt-5.4` 部署失敗

常見原因是 region quota 或 capacity 不足。請先確認錯誤訊息是否為 quota、capacity 或 model availability，再明確改用 fallback model parameters。

### `what-if` 顯示 `Unsupported`

若訊息與 project identity principal ID、workspace ID 或 role assignment resource ID 有關，通常是 Azure what-if 無法在部署前解析 deployment-time values。請確認 `az bicep build` 已通過，並檢查 what-if 是否有真正的 error。

### Verification 找不到 deployment outputs

若 resource group 中有多個 deployment，請加上：

```bash
--deployment-name <deployment-name>
```

### Reasoning smoke test 回傳 HTTP 400

請先查看 script 印出的 response body。確認 request 未包含 traditional sampling parameters，且 model deployment name、model availability、API version 符合目前環境。

## 本機開發檢查

修改 Bicep 或 scripts 後，建議至少執行：

```bash
az bicep build --file infra/main.bicep
bash -n infra/scripts/deploy.sh infra/scripts/verify.sh infra/scripts/smoke-test-reasoning.sh
grep -R "2025-06-01" infra || true
```

Foundry resource API family 目前固定使用 `2025-04-01-preview`，以對齊 walkthrough。
