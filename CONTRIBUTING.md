# 参与 SlowWalk 开发

SlowWalk 是面向银发族出行与用药风险提示的原型。提交代码前，请先阅读
`docs/PROJECT_SCOPE.md`、`docs/ARCHITECTURE.md` 与 `docs/API_CONTRACT.md`。

## 分支与提交

- 不直接在 `main` 上开发。
- 从 `develop` 创建短生命周期分支，格式为 `feature/<主题>`、`fix/<主题>` 或
  `docs/<主题>`。
- 一个提交只处理一个清晰目的；不要把格式化、重构和功能混在同一提交中。
- 不提交密钥、个人健康信息、构建产物或本地工具缓存。
- 合并前保持提交可构建、测试可重复，并在 PR 中说明未能验证的范围。

## 技术边界

- 业务代码、iOS 运行代码和服务端运行代码均使用 Swift。
- 跨平台代码位于 `swift-packages/SlowWalkCore`；Apple 平台专属代码只位于
  `ios/`；HTTP 适配只位于 `server/`。
- `SlowWalkDomain` 不依赖 UI、网络、数据库或服务端框架。
- `SlowWalkRiskEngine` 必须保持确定性、可解释且不依赖大语言模型。
- 共享 DTO 只放在 `SlowWalkAPIContracts`，不能把 Swift 类型名当作外部协议。
- 时间、UUID、Repository 和缓存通过初始化器注入；禁止业务全局单例。

## 本地验证

在 Windows PowerShell 中运行：

```powershell
pwsh -File .\scripts\verify-windows.ps1
```

或单独验证核心 Package：

```powershell
swift package --package-path .\swift-packages\SlowWalkCore resolve
swift build --package-path .\swift-packages\SlowWalkCore
swift test --package-path .\swift-packages\SlowWalkCore
```

服务端验证：

```powershell
swift package --package-path .\server resolve
swift build --package-path .\server
swift test --package-path .\server
```

iOS 源码必须在 Mac/Xcode 中另行验证。Windows 上通过的 SwiftPM 构建不能证明
SwiftUI、Vision、CoreLocation 或其他 Apple 平台能力可用。

## 测试要求

- 为每条业务规则断言具体风险等级、原因代码和建议动作。
- 时间窗口测试使用固定 Clock，不直接依赖当前时间。
- 编解码测试必须覆盖 `shared/fixtures` 中的所有场景。
- 缺失证据、识别失败、未来时间、重复记录等边界输入不可只测试“不崩溃”。
- 修复缺陷时应先增加能够复现问题的测试。

## 医疗安全与演示数据

本项目只提供风险提示和信息整理，不提供诊断或治疗方案。不得生成无来源支持的
剂量、频次或禁忌信息。任何演示药品数据必须标注
`DEMO DATA — NOT FOR CLINICAL USE`，不得提交真实个人健康数据。
