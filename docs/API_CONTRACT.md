# API v1 合同

## 基本约定

- 基础路径：`/api/v1`
- 媒体类型：`application/json`
- 字段名：lower camel case
- 日期：UTC ISO 8601，例如 `2026-01-15T10:00:00.000Z`
- UUID：标准带连字符字符串
- 业务枚举：本文列出的稳定 raw value，不依赖 Swift 类型名
- 错误码：typed `APIErrorCode`，Server 只输出 `UPPER_SNAKE_CASE`
- 版本：当前固定为 `v1`

未知字段可由解码器忽略；缺失必填字段、无效枚举、无效日期或类型错误必须返回结构化
错误。可选字段为 `null` 或省略时语义相同，编码器默认省略值为 `nil` 的字段。

## 健康检查

### `GET /health`

成功状态：`200 OK`

```json
{
  "status": "ok",
  "service": "slow-walk-server",
  "apiVersion": "v1"
}
```

此接口只表示进程能够响应并完成基础组合，不证明外部数据库、临床数据或 Apple
平台功能可用。

## raw risk endpoint 已关闭

`POST /api/v1/risk/assess` 不再由默认 Server 注册，公开
`RiskAssessmentRequestDTO`/`RiskAssessmentResponseDTO` 已移除。该旧路径允许客户
端提交完整 `Medicine`、ingredient 与 `SourceReference`，会绕过服务端
`MedicinePipeline`、`SourcePolicy` 和 health preflight，因此不能作为兼容入口。

正式药品评估只使用 `POST /api/v1/medicine/assess`。客户端只提交识别证据、严格
健康档案 DTO 与近期用药记录；可信药品事实和来源由 Server 解析。

## 药品知识检索

### `POST /api/v1/medicine/search`

请求体为 `MedicineKnowledgeSearchRequestDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `normalizedQuery` | String | 是 | 已 trim、lowercase 的药品查询，最多 256 字符 |
| `requestID` | UUID | 是 | 客户端关联 ID |
| `apiVersion` | String | 是 | 固定为 `v1` |

成功返回 `MedicineKnowledgeSearchResponseDTO`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `candidates` | `[MedicineKnowledgeCandidate]` | 结构化候选与逐候选冲突证据 |
| `sourceStatus` | String enum | authoritative/corroborated/partial/conflicting/stale_offline/unavailable |
| `knowledgeCacheStatus` | String enum | miss/hit/expired/revalidated/stale_offline/source_version_changed/not_stored |
| `completeness` | Number, 0...1 | 合并与冲突惩罚后的完整度 |
| `sourceReferences` | `[SourceReference]` | 可追溯来源 |
| `warnings` | `[MedicineKnowledgeWarning]` | 稳定 code 与 source identifiers |
| `sourceVersions` | `[String: String]` | source identifier 到数据版本 |
| `generatedAt` | Date | 结果生成时间 |
| `isOffline` | Boolean | 是否使用 stale/offline cache |
| `governanceVerdict` | `KnowledgeGovernanceVerdict` | 汇总 validation、completeness、provenance、freshness 与保守动作 |

当前运行时只连接 mock HTTP source，响应中的
`DEMO DATA — NOT FOR CLINICAL USE` 不是临床数据声明。联网成功不等于来源通过
医学可信校验；白名单、版本和引用验证由 `SourcePolicy` 独立执行。

`KnowledgeGovernanceVerdict` 至少包含：

- `validationStatus`
- `completeness`
- `provenanceStatus`
- `freshnessStatus`
- `requiresConfirmation`
- `requiresConservativeAction`
- `allowsDosageDisplay`
- `warnings`
- `sourceReferences`

response/record validation warning、低于阈值的 completeness、陈旧 record、
response/record reference 或 version 不一致、缺 authoritative source、冲突或
provenance 无法确认都会进入 conservative path。该路径至少 yellow，禁止输出
dosage/frequency，并保留来源与冲突证据。

## 药品解析

### `POST /api/v1/medicine/resolve`

请求体为 `MedicineResolutionRequestDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `input` | `MedicineRecognitionInput` | 是 | 模拟 OCR 文字和证据 |
| `requestID` | UUID | 是 | 客户端关联 ID |
| `apiVersion` | String | 是 | 固定为 `v1` |

`MedicineRecognitionInput`：

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `recognizedTexts` | `[String]` | 是 |
| `capturedAt` | Date | 是 |
| `languageCode` | String | 否 |
| `rawConfidence` | Number, 0...1 | 否 |

只有唯一、达到自动确认阈值且识别置信度充足时返回 `200` 和
`MedicineResolutionResponseDTO`。响应包含 `resolution`、`cacheHit`、
`resolutionCacheStatus`、可选 `knowledgeCacheStatus`、
`sourceDataVersion`、`generatedAt`、`requestID` 和 `apiVersion`。两个 cache
status 不得互相折叠；例如 knowledge 的 `stale_offline` 不能只显示为 resolution
的 `expired`。

`resolution.status` 的稳定值为 `resolved`、`ambiguous`、
`insufficient_evidence`、`not_found`、`recognition_failed`。歧义、未找到、
识别失败和证据不足由此端点映射为结构化 HTTP 错误；候选解析本身仍保留在核心
模型中供完整管线使用。

## 药品解析与风险行动卡

### `POST /api/v1/medicine/assess`

请求体为 `MedicineAssessmentRequestDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `input` | `MedicineRecognitionInput` | 是 | 模拟 OCR 输入 |
| `userProfile` | `UserHealthProfileDTO` | 是 | 严格 wire 档案，Server 显式映射 Domain |
| `recentRecords` | `[MedicationRecordDTO]` | 是 | 本次使用的近期记录，可显式为空 |
| `requestID` | UUID | 是 | 客户端关联 ID |
| `apiVersion` | String | 是 | 固定为 `v1` |

响应为 `MedicineAssessmentResponseDTO`，包含：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `resolution` | `MedicineResolution` | 是 | 解析状态、候选和证据 |
| `assessment` | `RiskAssessment` | 否 | 仅可靠解析后存在 |
| `actionCard` | `ActionCard` | 是 | 所有解析状态均存在 |
| `cacheHit` | Boolean | 是 | 只表示技术缓存命中 |
| `resolutionCacheStatus` | String enum | 是 | hit/miss/expired/source_version_changed |
| `knowledgeCacheStatus` | String enum | 否 | miss/hit/expired/revalidated/stale_offline/source_version_changed/not_stored |
| `sourceDataVersion` | String | 是 | 服务端演示目录版本 |
| `generatedAt` | Date | 是 | 服务端生成时间 |
| `requestID` | UUID | 是 | 与请求一致 |
| `apiVersion` | String | 是 | 固定为 `v1` |
| `healthContextValidation` | `HealthContextValidationDTO` | 是 | 档案、历史和身体指标的数据质量结果 |
| `medicineKnowledge` | `MedicineKnowledgeSearchResult` | 否 | 本次知识源、缓存、冲突与版本证据 |

无法确认药品不是传输错误：此端点返回 `200` 和保守 `ActionCard`，其
`mustConfirmMedicine` 为 true，且必须要求重拍药盒正面和确认前不要服用。
`assessment` 此时为空，不输出剂量或频次。缓存命中后仍使用当前档案、近期记录和
本次识别置信度重新运行安全判断。

`healthContextValidation.status` 的稳定值为 `valid`、
`valid_with_warnings`、`invalid`。成功响应只会出现前两种；`warnings` 中每项
包含稳定 `code`、可选 `field`、`message`、`severity` 和
`ruleIdentifier`。warning 会保留在响应和行动卡中，但不一定导致 HTTP 失败。
`configurationNotices` 必须包含 `NOT FOR CLINICAL USE`，身体指标演示配置还包含
`DEMO DATA QUALITY CONFIGURATION — NOT A CLINICAL DIAGNOSTIC STANDARD`。

## 位置评估

### `POST /api/v1/location/assess`

canonical request 为 `LocationAssessmentRequestDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `destination` | `Destination` | 是 | 虚构目的地与 geofence radius |
| `recentSamples` | `[LocationSample]` | 是 | 按时间提供的位置样本 |
| `requestID` | UUID | 是 | 客户端关联 ID |
| `apiVersion` | String | 是 | 固定为 `v1` |

成功响应为 `LocationAssessmentResponseDTO`，包含 `assessment`、`actionCard`、
`warnings`、`generatedAt`、`requestID` 和 `apiVersion`。medicine 与 location
均使用 `SlowWalkDomain.RiskLevel` 的 `green/yellow/orange/red` raw value；
location reason 与 action 保持独立。

只有 inside geofence 才能使用 arrived reason。geofence 外只有明确的连续距离递减
趋势才能使用 progressing/approaching green；趋势不可判定至少 yellow。invalid
coordinate、乱序、跳点、stale、低精度和样本不足可以阻止 green，但不参与
family-attention red 行为信号计数。red 只由至少两个明确行为信号触发。

## 领域对象

### Medicine

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | String | 是 |
| `canonicalName` | String | 是 |
| `aliases` | `[String]` | 是 |
| `activeIngredientIDs` | `[String]` | 是 |
| `medicineCategory` | String enum | 是 |
| `sourceReferences` | `[SourceReference]` | 是 |
| `dosageTextFromSource` | String | 否 |
| `contraindicationTags` | `[String]` | 是 |
| `warnings` | `[String]` | 是 |
| `dataVersion` | String | 是 |

`medicineCategory` 可选值：`analgesic`、`antipyretic`、`cold_and_flu`、
`antihistamine`、`antihypertensive`、`antidiabetic`、`gastrointestinal`、
`other`。

`dosageTextFromSource` 只能转录经过验证的来源文本，风险引擎不得自行生成或修改。

### SourceReference

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `sourceName` | String | 是 |
| `documentTitle` | String | 是 |
| `optionalURL` | URL String | 否 |
| `retrievedAt` | Date | 是 |
| `versionOrDate` | String | 是 |

### UserHealthProfileDTO

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | UUID | 是 |
| `age` | Integer | 是 |
| `allergies` | `[String]` | 是 |
| `diagnosedConditions` | `[String]` | 是 |
| `currentMedicineIngredientIDs` | `[String]` | 是 |
| `bodyMetrics` | `BodyMetrics` | 否 |
| `createdAt` | Date | 兼容可省 |
| `updatedAt` | Date | 是 |
| `schemaVersion` | Integer | 兼容可省 |

API v1 为旧请求提供兼容默认：缺少 `createdAt` 时使用 `updatedAt`，缺少
`schemaVersion` 时使用 `1`。除此之外不提供 wire 默认。

`allergies`、`diagnosedConditions`、`currentMedicineIngredientIDs` 任一字段缺失
都会返回 `INVALID_USER_PROFILE`，因为缺失表示 unknown/incomplete；只有显式
`[]` 才表示用户明确提供“当前没有相关信息”。Domain 持久化 decoder 可以继续兼容
旧 JSON，但不能代替 API DTO 的严格解码。

### BodyMetrics

对象和以下四个字段均可省略。数值只用于数据质量检查，不代表诊断。

| 字段 | 类型 |
| --- | --- |
| `systolicBloodPressure` | Integer |
| `diastolicBloodPressure` | Integer |
| `heartRate` | Integer |
| `measuredAt` | Date |
| `source` | String |
| `deviceIdentifier` | String |

`source` 缺失属于数据质量 warning；`deviceIdentifier` 始终可选。以上字段只做
缺失、格式、时间、过期和明显字段关系检查，不用于疾病诊断。

### MedicationRecord

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | UUID | 是 |
| `medicineID` | String | 是 |
| `activeIngredientIDs` | `[String]` | 是 |
| `recordedAt` | Date | 是 |
| `eventType` | String enum | 是 |
| `source` | String enum | 是 |

`eventType`：`scanned`、`confirmed_intake`、`reported`。`taken` 是保留给旧
API v1 fixture 的兼容值。只有 `confirmed_intake` 和旧 `taken` 参与已确认服药
统计；`scanned` 绝不自动等同服药。

`source`：`manual_entry`、`medicine_scan`、`demo_data`。

### MedicineScanEvent

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | UUID | 是 |
| `recognizedText` | String | 是 |
| `candidateMedicineID` | String | 否 |
| `confidence` | Number | 是 |
| `scannedAt` | Date | 是 |
| `recognitionStatus` | String enum | 是 |

`recognitionStatus`：`recognized`、`uncertain`、`failed`。`confidence` 必须位于
0 到 1；失败时可省略 `candidateMedicineID`。

## 风险结果

### RiskAssessment

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `level` | String enum | 是 |
| `reasons` | `[RiskReason]` | 是 |
| `recommendedActions` | `[String enum]` | 是 |
| `assessedAt` | Date | 是 |
| `requiresProfessionalAdvice` | Boolean | 是 |
| `requiresFamilyAttention` | Boolean | 是 |
| `evidenceCompleteness` | String enum | 是 |

`level`：`green`、`yellow`、`orange`、`red`。
该 enum 为 `SlowWalkDomain.RiskLevel`，药品与位置响应共享同一 wire raw value。

`evidenceCompleteness`：`complete`、`partial`、`insufficient`。

`recommendedActions` 可选值：

- `follow_verified_source_information`
- `consult_healthcare_professional`
- `notify_family_member`
- `review_medicine_sources`
- `update_health_profile`
- `retake_medicine_photo`
- `do_not_take_until_medicine_confirmed`
- `review_medication_history`
- `remeasure_body_metrics`

### RiskReason

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `code` | String enum | 是 |
| `message` | String | 是 |
| `evidence` | String | 是 |
| `ruleIdentifier` | String | 是 |

`code` 可选值：

- `allergy_match`
- `duplicate_active_ingredient`
- `frequent_use`
- `prolonged_use`
- `missing_evidence`
- `recognition_failed`
- `body_metrics_missing`
- `body_metrics_stale`
- `body_metrics_invalid`
- `health_context_warning`
- `knowledge_source_warning`

消息面向用户，证据说明来源或命中数据，`ruleIdentifier` 稳定标识产生原因的规则。

## 错误

所有失败返回 `APIErrorDTO`：

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `code` | String | 是 |
| `message` | String | 是 |
| `requestID` | UUID | 是 |
| `details` | `[APIErrorDetailDTO]` | 否 |

错误 detail：

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `field` | String | 否 |
| `code` | String | 是 |
| `message` | String | 是 |

`APIErrorDTO.code` 是 `APIErrorCode`，不是任意 String。Server 新响应只输出
canonical `UPPER_SNAKE_CASE`。client decoder 为早期 v1 的
`invalid_json`、`validation_error`、`unsupported_api_version`、
`unsupported_media_type` 等 lowercase 值保留单一 alias mapper；业务代码不得
各自处理大小写。

所有 POST endpoint 共享：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 400 | `UNSUPPORTED_MEDIA_TYPE` | Content-Type 缺失或不是 JSON |
| 400 | `MALFORMED_REQUEST` | 请求体不是合法 JSON |
| 400 | `UNSUPPORTED_API_VERSION` | path 与 body `apiVersion` 不匹配 |
| 422 | `VALIDATION_ERROR` | 普通字段缺失、类型、枚举或范围无效 |
| 500 | `INTERNAL_ERROR` | 未预期服务端错误 |

medicine search/resolve/assess 还可能使用：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 404 | `MEDICINE_NOT_FOUND` | 白名单来源均未找到候选 |
| 409 | `SOURCE_CONFLICT` | source adapter 明确返回不可聚合冲突 |
| 502 | `INVALID_SOURCE_RESPONSE` | JSON、Content-Type、空 body 或大小验证失败 |
| 502 | `SOURCE_VERSION_UNSUPPORTED` | source data version 不受支持 |
| 503 | `KNOWLEDGE_SOURCE_UNAVAILABLE` | 来源不可用或请求被取消 |
| 503 | `OFFLINE_CACHE_UNAVAILABLE` | 联网失败且无可用 offline grace cache |
| 504 | `KNOWLEDGE_SOURCE_TIMEOUT` | 来源请求超时 |

medicine resolve 还会使用：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 409 | `MEDICINE_AMBIGUOUS` | 多个候选过于接近 |
| 422 | `MEDICINE_RECOGNITION_FAILED` | 没有可用识别文字 |
| 422 | `MEDICINE_INSUFFICIENT_EVIDENCE` | 置信度或匹配分数不足 |

medicine assess 的健康上下文错误：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 400 | `MALFORMED_REQUEST` | 无法识别为有效 assessment DTO 的 JSON |
| 400 | `UNSUPPORTED_API_VERSION` | `apiVersion` 不受支持 |
| 422 | `INVALID_USER_PROFILE` | 档案 ID、年龄或时间关系无效 |
| 422 | `UNSUPPORTED_PROFILE_SCHEMA` | 档案 schemaVersion 不受支持 |
| 422 | `INVALID_MEDICATION_RECORD` | 历史记录字段无效 |
| 422 | `FUTURE_MEDICATION_RECORD` | 历史记录时间在未来 |
| 422 | `INVALID_BODY_METRICS` | 身体指标存在明显无效数据 |

location assess 的输入/数据质量错误：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 422 | `INVALID_LOCATION_SAMPLE` | 坐标、时间或 speed 无效 |
| 422 | `LOCATION_DATA_STALE` | 全部位置样本过期 |
| 422 | `LOCATION_ACCURACY_INSUFFICIENT` | 当前样本精度均不可用 |
| 422 | `INSUFFICIENT_LOCATION_HISTORY` | 可用样本不足 |

错误响应也必须带 `application/json`。如果无法从请求读取合法 ID，服务端生成新的
request ID 并用于日志和响应；不得在响应中暴露调用栈、文件路径或内部秘密。

## Fixtures

`shared/fixtures` 中原有 raw risk envelope 只保留为历史审计样本，不再由
APIContracts 或 Server 测试解码，也不代表线上 endpoint：

```json
{
  "request": {},
  "expectedResponse": {}
}
```

这些 legacy 文件曾覆盖：

- `green-risk.json`
- `yellow-risk.json`
- `orange-risk.json`
- `red-risk.json`
- `recognition-failed.json`

健康上下文 fixtures 可直接表示档案、身体指标、历史 envelope 或
`MedicineAssessmentRequestDTO`，包括：

- `profile-complete.json`
- `profile-missing-evidence.json`
- `body-metrics-current.json`
- `body-metrics-stale.json`
- `medication-history-empty.json`
- `medication-history-frequent-use.json`
- `medication-history-duplicate-ingredient.json`
- `health-context-valid.json`
- `health-context-warning.json`
- `health-context-invalid.json`

所有内容均为演示数据，不得用于临床决策。

## 兼容性

API v1 内新增字段必须是可选字段或有清晰默认语义。删除字段、改变类型、改变枚举
raw value 或改变医学语义通常属于破坏性变更，应发布新版本路径并增加 ADR。本轮在
public API 冻结前完成安全收口：关闭不可信 raw endpoint、严格健康字段、typed
`APIErrorCode`，并将模糊 `cacheStatus` 拆为
`resolutionCacheStatus`/`knowledgeCacheStatus`。iOS adapter 必须以本文为新基线。
