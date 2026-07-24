# SlowWalk Server

Swift 6 + Hummingbird 2 的最小 API 服务，业务风险判断复用本地
`../swift-packages/SlowWalkCore` 中的 `MedicationRiskEngine`。

## 运行

以下命令仅供具备受支持 Swift 工具链的 Linux/macOS 环境使用；当前 Windows
工作区不执行它们。仓库的真实构建与测试结果以 `Swift Server` GitHub Actions
工作流为准。

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
- `POST /api/v1/medicine/resolve`
  - 接收模拟 OCR 的 `MedicineRecognitionInput`
  - 只解析服务端 SwiftPM resource 中的演示目录
  - 歧义、未找到和证据不足使用稳定的 `APIErrorDTO` 错误码
- `POST /api/v1/medicine/assess`
  - 完成归一化、候选解析、当前档案/历史风险重评估和 `ActionCard` 生成
  - 无法确认药品时仍返回保守行动卡，不返回剂量或频次
  - 响应包含解析缓存状态；缓存命中不代表医学安全

演示目录明确标注 `DEMO DATA — NOT FOR CLINICAL USE`，所有剂量字段均为空。
完整设计和限制见 `docs/MEDICINE_PIPELINE.md`。

Hummingbird 为每个传输请求写入 `hb.request.id` 日志元数据；API DTO
中的 UUID 请求 ID 会作为 `slowwalk.api_request_id` 进入结构化日志。
日志不会记录药品、健康档案或请求正文。
