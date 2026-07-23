# SlowWalk Server

Swift 6 + Hummingbird 2 的最小 API 服务，业务风险判断复用本地
`../swift-packages/SlowWalkCore` 中的 `MedicationRiskEngine`。

## 运行

```bash
swift run SlowWalkServer
```

默认监听 `127.0.0.1:8080`。测试：

```bash
swift test
```

## API

- `GET /health`
  - `200 application/json`
  - `{"status":"ok","service":"slow-walk-server","apiVersion":"v1"}`
- `POST /api/v1/risk/assess`
  - 请求与响应分别使用核心模块的 `RiskAssessmentRequestDTO` 和
    `RiskAssessmentResponseDTO`
  - 仅接受 `Content-Type: application/json`
  - 日期由 `SlowWalkJSONCoding` 统一编码为 ISO 8601
  - 错误统一返回 `APIErrorDTO`

Hummingbird 为每个传输请求写入 `hb.request.id` 日志元数据；API DTO
中的 UUID 请求 ID 会作为 `slowwalk.api_request_id` 进入结构化日志。
日志不会记录药品、健康档案或请求正文。
