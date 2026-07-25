# JSON Fixtures

这些文件是可重复的历史测试场景。原有 raw risk fixtures 不是线上 API body，
每个文件包含：

- `request`：旧 raw risk request 的审计样本。
- `expectedResponse`：旧 raw risk response 的审计样本。

`POST /api/v1/risk/assess` 已关闭，相关公开 DTO 已移除；当前 test target 不再
解码这些 legacy envelope。文件仅用于说明旧边界为何不可信，不得重新接入默认
Server 或 iOS network contract。日期和 ID 仍保留为固定值，方便审计。

健康上下文 fixtures 分为三类：

- `profile-*` 与 `body-metrics-*`：单个领域值示例。
- `medication-history-*`：带 `schemaVersion` 的文件 Repository envelope。
- `health-context-*`：可提交到 `POST /api/v1/medicine/assess` 的请求示例；额外
  `demoNotice` 字段会按 API v1 未知字段兼容规则忽略。

所有药品名称、来源和用户信息均为
`DEMO DATA — NOT FOR CLINICAL USE`。不得从这些示例推导真实剂量、频次、禁忌或
临床判断。
