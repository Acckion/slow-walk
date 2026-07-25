# 健康上下文与 JSON 持久化

## 当前基线

health context 已进入 `develop`，本文件描述当前 canonical medicine assessment
契约。Windows 只负责编辑、Git 和静态审查；Swift 构建与测试结论以 GitHub
Actions 为准。

## 设计落点

本轮没有新增 SwiftPM target：

- `SlowWalkDomain`：档案/身体指标模型、规范化与数据质量协议。
- `SlowWalkRiskEngine`：用药历史分析、重复成分上下文和
  `MedicationRiskContextBuilder`。
- `SlowWalkDataInterfaces`：Repository 协议、内存 actor 和文件 actor。
- `SlowWalkMedicinePipeline`：每次请求的 preflight、解析、上下文构造、风险评估
  与行动卡编排。
- `SlowWalkAPIContracts`：健康上下文 DTO 和结构化 validation response。
- `SlowWalkServer`：DTO 解码、API version 检查、typed error 到 HTTP 的映射。

依赖方向保持为外层依赖核心；Domain 不依赖 Repository，RiskEngine 不依赖
Server，核心模块不导入 Hummingbird 或 Apple 平台框架。

## 严格 wire contract

`POST /api/v1/medicine/assess` 使用 `UserHealthProfileDTO`，Server 再显式映射为
`UserHealthProfile`。以下三个数组是独立必填字段：

- `allergies`
- `diagnosedConditions`
- `currentMedicineIngredientIDs`

字段缺失表示 unknown/incomplete，必须在解码阶段失败，不能静默转换成空数组。
显式 `[]` 才表示用户明确提供“当前没有相关信息”。API 只保留两项兼容默认：
缺少 `createdAt` 时使用 `updatedAt`，缺少 `schemaVersion` 时使用 `1`。

Domain 的 `UserHealthProfile` decoder 继续为已有持久化 JSON 保留宽松读取逻辑；
该兼容行为不得被 HTTP 边界直接复用。

## 档案验证

`UserHealthProfileValidator` 只验证数据质量：

- 拒绝 nil UUID、超出支持格式范围的年龄、倒置或未来时间。
- 检查 `schemaVersion`。
- 对过敏、疾病标签和有效成分 ID 去首尾空白、移除空值，并按不区分大小写去重。
- 通过 `valid`、`valid_with_warnings`、`invalid` 和稳定 code 返回结果。

上述结果不代表医学安全，也不用于诊断、严重程度解释或治疗方案生成。

## 身体指标数据质量

`BodyMetricsQualityAssessor` 仅检查字段是否存在、正数格式、未来/过期时间、血压
字段成对关系和来源。配置集中在 `BodyMetricsQualityConfiguration`，强制标注：

> DEMO DATA QUALITY CONFIGURATION — NOT A CLINICAL DIAGNOSTIC STANDARD

它不包含疾病阈值，也不从血压或心率生成临床风险结论。

## 用药历史

`MedicationHistoryAnalyzer` 使用注入的 `Clock`、固定 `Calendar.Identifier` 和
`TimeZone`。时间窗口采用闭区间；输入先稳定排序，再按 UUID 和同一配置分钟窗口
去重。只有 `confirmed_intake` 与旧版兼容 `taken` 参与服药次数、有效成分次数和
连续日期统计，`scanned` 不参与。

未来记录和空 ID 是 error；重复 ID 与同一分钟等价事件是 warning。Repository
只有在调用方显式调用 `removeDuplicates()` 时才持久删除语义重复记录。

## RiskContext 构造

流程固定为：

1. 验证并规范化当前档案。
2. 评估当前身体指标数据质量。
3. 检查、排序并分析当前历史。
4. 确认解析状态、候选药品和 scan event 一致。
5. 合并并稳定排序 `SourceReference`。
6. 计算重复有效成分证据和 `EvidenceCompleteness`。
7. 构造不可变 `MedicationRiskContext`。
8. 调用 deterministic `MedicationRiskEngine`。

warning 会同时进入结构化 response 与 risk reason。缺少来源时 completeness 为
`insufficient`；存在 warning 时最多为 `partial`。解析失败不构造普通服药上下文，
只返回要求确认药品的保守行动卡。

## JSON 文件 Repository

文件实现使用 Foundation、Codable、async/await 和 actor：

- `FileUserHealthProfileRepository`
- `FileMedicationHistoryRepository`

基础目录由 initializer 注入，不包含绝对用户目录。文件 envelope 包含
`schemaVersion` 和 `records`。保存时先编码到同目录 staging 文件，再使用
Foundation 的 `.atomic` 写入策略替换已有文件；失败时旧文件不被直接覆盖。该
路径同时适用于 Darwin 与 Linux Foundation。

typed error 区分 `fileNotFound`、`emptyFile`、`corruptedJSON`、
`unsupportedSchemaVersion`、目录创建失败和原子写入失败。日志和错误不包含完整
档案、过敏详情、身体指标或文件路径。身体指标随档案持久化，因此当前架构不需要
独立 `FileBodyMetricsRepository`。

当前 JSON 文件只提供编码格式、schemaVersion 与单进程 actor/原子替换语义：

- **未加密**；
- **没有 Apple Data Protection**；
- 不提供跨进程锁、云同步或密钥管理。

因此在完成 Apple 平台受保护存储设计前，不应把真实敏感健康资料写入该文件实现。

## 安全边界与限制

- 全部默认值和 fixtures 均为 `NOT FOR CLINICAL USE`。
- 不接入网络、LLM、RAG、真实医疗数据库或 Apple 平台 API。
- 不生成来源未提供的剂量、频次或治疗方案。
- cache 只复用药品名称解析；健康上下文永远按当前请求重建。
- 文件 Repository 是单进程 actor 隔离，不提供跨进程锁或云同步。
- 当前 JSON 未加密且没有 Data Protection；真实用户数据接入前必须另行处理。
