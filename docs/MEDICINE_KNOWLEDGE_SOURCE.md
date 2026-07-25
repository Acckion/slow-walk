# 药品知识源与可信来源治理

## 结论与适用范围

本模块实现的是可测试的联网检索边界、来源治理、缓存和安全降级，不是临床药品
数据库接入。当前 Server 运行时只使用：

- `MockAuthoritativeMedicineSource`
- `MockSecondaryMedicineSource`
- `DemoMockHTTPTransport`

所有数据均标注：

> DEMO DATA — NOT FOR CLINICAL USE

不得据此声称已经验证真实权威药品数据、真实剂量或临床建议。本阶段没有网页抓取、
任意互联网搜索、LLM、RAG、SwiftUI、Vision、相机或云部署。

## 模块和依赖方向

```text
SlowWalkDomain
      ↑
SlowWalkDataInterfaces
      ↑
SlowWalkMedicineKnowledge
      ↑
SlowWalkMedicinePipeline
      ↑
SlowWalkServer

SlowWalkAPIContracts ──→ SlowWalkMedicineKnowledge
SlowWalkServer       ──→ SlowWalkAPIContracts
```

`SlowWalkMedicineKnowledge` 依赖 `SlowWalkDomain` 与
`SlowWalkDataInterfaces`；`SlowWalkMedicinePipeline` 消费知识检索结果；
`SlowWalkServer` 只负责 HTTP 组合与稳定错误映射。Domain 和 RiskEngine 不依赖
HTTP 或 Server，因此不存在循环依赖。

跨平台 target 只使用 Foundation；生产 HTTP 能力由
`URLSessionHTTPTransport` 提供，测试与当前 demo 不访问真实互联网。

## 公开协议

### MedicineKnowledgeSource

每个配置的数据源必须声明：

- `identifier`
- `displayName`
- `priority`
- `isAuthoritative`
- `supportedDataVersion`
- `search(query:)`
- `fetchMedicine(identifier:)`

### MedicineKnowledgeSearching

负责接收标准化查询并返回 `MedicineKnowledgeSearchResult`。结果保留候选药品、
来源状态、缓存状态、完整度、来源引用、warning、每个来源的数据版本和
`isOffline`，不使用 `Any` 或无类型 payload。

### HTTPTransporting

隔离 HTTP 请求与响应。业务代码不直接创建网络连接，测试可精确注入 timeout、
状态码、header、body、取消和重试场景。

## SourcePolicy

`SourcePolicy` 在任何结果进入 Pipeline 前执行以下不变量：

1. 只接受显式白名单中的 source identifier。
2. source identifier 不得重复，版本声明不得为空。
3. response、record 和配置 source 的 identifier 必须一致。
4. response version 必须等于 source 的 `supportedDataVersion`。
5. response 与 record 必须带正式 `SourceReference`。
6. completeness 必须是有限的 `0...1`。
7. `fetchedAt` 不得超出允许的未来偏差。
8. 过旧来源保留为 warning，不描述为当前权威数据。
9. invalid 或不支持版本的响应不进入可信缓存。

联网成功只说明 transport 可达；只有通过上述验证、来源身份与版本检查的数据才可
参与合并。

## 优先级与冲突

来源先按 `priority` 降序，再按 authoritative 和 identifier 稳定排序。
关键字段冲突时：

- 高优先级字段保留，但低优先级值不会静默丢失；
- `MedicineSourceConflict` 保存字段名、双方 source 和双方值；
- candidate 与总结果加入 `SOURCE_CONFLICT` warning；
- completeness 扣除配置的 conflict penalty；
- candidate 标记 `requiresConfirmation`；
- Pipeline 将风险提高到至少 yellow，并移除普通绿色动作；
- 原 RiskEngine 已产生的 red 永远不会被降低。

只存在 secondary source、来源过旧或 stale/offline 时同样要求确认。来源缺少剂量
字段时保持 `nil`；只有 authoritative、valid、无剂量冲突且不陈旧的来源文本才
有资格透传。本项目不会自行生成剂量。

## HTTP 行为

`HTTPMedicineKnowledgeSource` 支持：

- HTTPS 配置校验；
- 可配置 timeout 和最大响应体；
- retryable status 与 transport failure 重试；
- 取消立即停止，不重试；
- 非 2xx、404、408、504 的稳定映射；
- JSON Content-Type、空响应、非法 JSON 和 body size 校验；
- `ETag`、`Last-Modified` 条件请求；
- `304 Not Modified`；
- `X-Source-Data-Version` 或正式 payload version。

日志和 API 错误不得回传 URL 密钥、source 私有配置、文件路径或调用栈。

## 缓存语义

`InMemoryMedicineKnowledgeCache` 保存：

- 标准化 query；
- 聚合后的结构化 result；
- 各来源原始结构化 response；
- source validation metadata；
- source version；
- stored/expires/offline-use-until 时间。

行为：

- fresh entry 返回 `hit`；
- expired entry 仍保留，优先携带 ETag/Last-Modified 联网重验证；
- 304 返回 `revalidated`；
- version 改变返回 `source_version_changed`；
- 联网失败且仍在 offline grace 内返回 `stale_offline`；
- offline copy 清除 source dosage、要求确认并降低完整度；
- 超出 offline grace 返回 `OFFLINE_CACHE_UNAVAILABLE`。

知识缓存只复用药品来源数据。每次 `MedicinePipeline.assess` 仍使用当前用户档案、
当前用药历史、当前身体指标和当前识别置信度重新运行 RiskEngine。

## Server API

`POST /api/v1/medicine/search` 接收：

```json
{
  "normalizedQuery": "acetaminophen",
  "requestID": "00000000-0000-0000-0000-000000000001",
  "apiVersion": "v1"
}
```

成功响应包含 `candidates`、`sourceStatus`、`knowledgeCacheStatus`、
`completeness`、`sourceReferences`、`warnings`、`sourceVersions`、
`generatedAt`、`isOffline` 与统一的 `governanceVerdict`。

稳定错误 code：

- `KNOWLEDGE_SOURCE_UNAVAILABLE`
- `KNOWLEDGE_SOURCE_TIMEOUT`
- `INVALID_SOURCE_RESPONSE`
- `SOURCE_VERSION_UNSUPPORTED`
- `MEDICINE_NOT_FOUND`
- `SOURCE_CONFLICT`
- `OFFLINE_CACHE_UNAVAILABLE`
- `MALFORMED_REQUEST`

`POST /api/v1/medicine/resolve` 与
`POST /api/v1/medicine/assess` 复用同一个知识 service/cache。
药品未找到仍沿既有 Pipeline 语义生成 `.notFound`；search endpoint 则返回
`MEDICINE_NOT_FOUND`。网络或来源验证失败不会回退成绿色。

## Fixture 与验证边界

`SlowWalkMedicineKnowledgeTests/Fixtures` 覆盖一致来源、冲突、主要来源 timeout、
secondary 可用、304、过期缓存、版本变化、缺少剂量、非法响应和未找到。测试会
逐个解码并检查统一免责声明。

构建与测试结果只能引用 GitHub Actions 的 Swift 6.3.2 Ubuntu 运行；Windows
不作为 Swift 构建或测试环境。
