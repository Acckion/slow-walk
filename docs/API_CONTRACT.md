# API v1 合同

## 基本约定

- 基础路径：`/api/v1`
- 媒体类型：`application/json`
- 字段名：lower camel case
- 日期：UTC ISO 8601，例如 `2026-01-15T10:00:00.000Z`
- UUID：标准带连字符字符串
- 枚举：本文列出的稳定小写字符串，不依赖 Swift 类型名
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

## 风险评估

### `POST /api/v1/risk/assess`

请求体为 `RiskAssessmentRequestDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `medicine` | `Medicine` | 是 | 已标准化的候选药品 |
| `userProfile` | `UserHealthProfile` | 是 | 当前用户健康档案 |
| `recentRecords` | `[MedicationRecord]` | 是 | 相关时间窗口内的记录，可为空 |
| `scanEvent` | `MedicineScanEvent` | 是 | 本次识别状态和置信度 |
| `requestID` | UUID | 是 | 客户端生成的关联 ID |
| `apiVersion` | String | 是 | 固定为 `v1` |

成功状态：`200 OK`，响应体为 `RiskAssessmentResponseDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `requestID` | UUID | 是 | 与请求保持一致 |
| `assessment` | `RiskAssessment` | 是 | 确定性风险结果 |
| `sourceReferences` | `[SourceReference]` | 是 | 本次使用的可信来源 |
| `generatedAt` | Date | 是 | 服务端生成响应的时间 |
| `apiVersion` | String | 是 | 固定为 `v1` |

完整请求与响应示例位于 `shared/api-examples/`。

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

`medicineCategory` 可选值：`analgesic`、`antipyretic`、`cold_and_flu`、
`antihistamine`、`other`。

`dosageTextFromSource` 只能转录经过验证的来源文本，风险引擎不得自行生成或修改。

### SourceReference

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `sourceName` | String | 是 |
| `documentTitle` | String | 是 |
| `optionalURL` | URL String | 否 |
| `retrievedAt` | Date | 是 |
| `versionOrDate` | String | 是 |

### UserHealthProfile

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | UUID | 是 |
| `age` | Integer | 是 |
| `allergies` | `[String]` | 是 |
| `diagnosedConditions` | `[String]` | 是 |
| `currentMedicineIngredientIDs` | `[String]` | 是 |
| `bodyMetrics` | `BodyMetrics` | 否 |
| `updatedAt` | Date | 是 |

### BodyMetrics

对象和以下四个字段均可省略。数值只用于数据质量检查，不代表诊断。

| 字段 | 类型 |
| --- | --- |
| `systolicBloodPressure` | Integer |
| `diastolicBloodPressure` | Integer |
| `heartRate` | Integer |
| `measuredAt` | Date |

### MedicationRecord

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `id` | UUID | 是 |
| `medicineID` | String | 是 |
| `activeIngredientIDs` | `[String]` | 是 |
| `recordedAt` | Date | 是 |
| `eventType` | String enum | 是 |
| `source` | String enum | 是 |

`eventType`：`scanned`、`taken`、`reported`。

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

错误码与状态：

| HTTP | `code` | 场景 |
| --- | --- | --- |
| 400 | `invalid_json` | 请求体不是合法 JSON |
| 400 | `unsupported_media_type` | Content-Type 缺失或不是 JSON |
| 400 | `unsupported_api_version` | `apiVersion` 不是 `v1` |
| 422 | `validation_error` | 字段缺失、类型、枚举或范围无效 |
| 500 | `internal_error` | 未预期服务端错误 |

错误响应也必须带 `application/json`。如果无法从请求读取合法 ID，服务端生成新的
request ID 并用于日志和响应；不得在响应中暴露调用栈、文件路径或内部秘密。

## Fixtures

`shared/fixtures/*.json` 使用测试专用 envelope：

```json
{
  "request": {},
  "expectedResponse": {}
}
```

`request` 严格解码为 `RiskAssessmentRequestDTO`，`expectedResponse` 严格解码为
`RiskAssessmentResponseDTO`。envelope 不是线上 API 类型。五个 fixtures 分别覆盖：

- `green-risk.json`
- `yellow-risk.json`
- `orange-risk.json`
- `red-risk.json`
- `recognition-failed.json`

所有内容均为演示数据，不得用于临床决策。

## 兼容性

API v1 内新增字段必须是可选字段或有清晰默认语义。删除字段、改变类型、改变枚举
raw value 或改变医学语义属于破坏性变更，应发布新版本路径并增加 ADR。
