# Medicine MVP 接口冻结核验

核验日期：2026-07-28
核验范围：成员 C / `feature/demo-fixtures`

## 冻结结论

本轨道没有修改公共接口。Day 1 集成使用以下既有类型和路径：

| 项目 | 冻结值 | 代码来源 |
| --- | --- | --- |
| App 名称 | `SlowWalkApp` | Day 1 任务约定 |
| 展示模块 | `SlowWalkPresentation` | Day 1 任务约定 |
| 请求协议 | `MedicineAssessmentRequesting` | `SlowWalkClientCore` |
| 协调器 | `MedicineAssessmentCoordinator` | `SlowWalkClientCore` |
| 状态来源 | `MedicineAssessmentViewState` | `SlowWalkClientCore` |
| API | `POST /api/v1/medicine/assess` | `SlowWalkAPI.Endpoint.medicineAssess` |
| API 版本 | `v1` | `SlowWalkAPI.version` |

`MedicineAssessmentViewState` 当前只有通用 `result`，没有
`healthWarning`、`knowledgeWarning` 或 `redRisk` 独立 case。因此 Fixture 使用：

```text
expectedViewState = 既有 Coordinator case
expectedPresentationVariant = Presentation 展示变体
```

这只是 Fixture 元数据，不改变 Core public API。

## Canonical DTO

请求必须解码为 `MedicineAssessmentRequestDTO`，仅包含：

- `input: MedicineRecognitionInput`
- `userProfile: UserHealthProfileDTO`
- `recentRecords: [MedicationRecordDTO]`
- `requestID: UUID`
- `apiVersion: String`

客户端不得提交完整 `Medicine`、有效成分事实、来源引用或风险等级。药品事实必须由
服务端目录或知识来源重新解析。

响应必须解码为 `MedicineAssessmentResponseDTO`，并保留：

- `resolution`
- 可空的 `assessment`
- 始终存在的 `actionCard`
- 两类独立缓存状态
- 来源数据版本和生成时间
- 健康上下文验证
- 可空的药品知识结果

## 风险等级

稳定 wire values：

```text
green
yellow
orange
red
```

UI 不得只用颜色表达等级。`red` 必须有立即关注语义；识别歧义不能产生普通绿色
说明。

## APIErrorCode

`APIErrorCode` 编码统一输出 canonical `UPPER_SNAKE_CASE`。Medicine assess 覆盖：

- 传输与版本：`UNSUPPORTED_MEDIA_TYPE`、`MALFORMED_REQUEST`、
  `UNSUPPORTED_API_VERSION`、`VALIDATION_ERROR`
- 健康上下文：`INVALID_USER_PROFILE`、`UNSUPPORTED_PROFILE_SCHEMA`、
  `INVALID_MEDICATION_RECORD`、`FUTURE_MEDICATION_RECORD`、
  `INVALID_BODY_METRICS`
- 知识来源：`KNOWLEDGE_SOURCE_UNAVAILABLE`、`KNOWLEDGE_SOURCE_TIMEOUT`、
  `INVALID_SOURCE_RESPONSE`、`SOURCE_VERSION_UNSUPPORTED`、
  `MEDICINE_NOT_FOUND`、`SOURCE_CONFLICT`、`OFFLINE_CACHE_UNAVAILABLE`
- 服务端：`INTERNAL_ERROR`

早期 lowercase 值只由 contracts 中央兼容 decoder 接收，Fixture 不使用旧值。

## 路由核验

Server 的 Medicine controller 注册在 canonical path：

```text
POST /api/v1/medicine/assess
```

该端点对 resolved、ambiguous、识别失败、证据不足、健康档案错误和知识来源异常均
已有服务端测试。旧 `/api/v1/risk/assess` 不属于正式客户端调用路径。
