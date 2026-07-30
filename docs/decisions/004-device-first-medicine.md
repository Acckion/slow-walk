# ADR-004：iOS 确定性评估采用 device-first 架构

## 状态

已接受，取代 ADR-002 中“客户端必须通过 Server 使用 Medicine Pipeline”的任何
隐含解释。ADR-002 对 Hummingbird 服务端自身的技术选型仍然有效。

## 背景

用药解析、健康上下文校验、确定性风险规则和 ActionCard 生成都已位于纯 Swift
Package 中。让同一台 iPhone 通过 HTTP 调用另一个进程才能运行这些规则，会增加
网络失败、隐私传输、部署和演示依赖，却没有提供当前 MVP 需要的能力。

## 决策

- iOS 默认通过 `LocalMedicineAssessmentRequester` 直接调用
  `SlowWalkMedicinePipeline`。
- Location 默认通过 `LocalLocationAssessmentRequester` 直接调用
  `LocationRiskEngine`；当前没有真实样本提供者时不生成位置结论。
- `MedicineAssessmentCoordinator` 与 `MedicineAssessmentViewState` 保持为唯一的
  用药用例和界面状态边界。
- 候选确认携带候选稳定 ID，并复用原始识别证据；不得把用户选择伪装成新的 OCR。
- App 在展示前校验 canonical response，不接受 request ID、版本或结构不一致的结果。
- `SlowWalkServer` 保留为可选 HTTP adapter、API contract 和集成测试工具，不是
  App 运行依赖，也不等同于已经部署的云服务。
- 未来只有在真实远程能力具有明确产品价值，并完成认证、隐私、数据治理和故障策略
  评审后，才增加网络 requester。

## Presentation 边界

原 `SlowWalkPresentation` PR #11 已关闭；替代实现当前位于 Draft PR #17，尚未
合入 `develop`。独立 Package 可以保留 SwiftUI 组件和纯映射测试，但 App 只把
canonical `ActionCard` 传给直接渲染组件。App 不长期保存
`MedicineDisplayState`，也不引入第三套可观察 Medicine 状态。

## 后果

- 默认演示在离线状态仍能完成评估闭环。
- 未来接入 CoreLocation 时，无需为了运行确定性位置规则上传完整轨迹。
- Server 与 App 可独立演进和测试。
- 当前演示知识目录仍是合成数据；“设备内”不代表临床可用。
- Vision、CoreLocation、受保护持久化和真实知识来源仍需独立实现与验证。
