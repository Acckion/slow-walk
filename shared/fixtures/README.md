# JSON Fixtures

这些文件是可重复测试场景。原有风险 fixtures 不是线上 API body，每个文件包含：

- `request`：严格匹配 `RiskAssessmentRequestDTO`。
- `expectedResponse`：严格匹配 `RiskAssessmentResponseDTO`。

测试 target 使用私有 envelope 类型解码两个字段，再分别验证 DTO 与业务结果。日期
固定为带毫秒的 UTC ISO 8601，ID 固定，确保测试不依赖当前时间或随机 UUID。

健康上下文 fixtures 分为三类：

- `profile-*` 与 `body-metrics-*`：单个领域值示例。
- `medication-history-*`：带 `schemaVersion` 的文件 Repository envelope。
- `health-context-*`：可提交到 `POST /api/v1/medicine/assess` 的请求示例；额外
  `demoNotice` 字段会按 API v1 未知字段兼容规则忽略。

所有药品名称、来源和用户信息均为
`DEMO DATA — NOT FOR CLINICAL USE`。不得从这些示例推导真实剂量、频次、禁忌或
临床判断。
