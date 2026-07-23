# 慢慢走 SlowWalk

银发族出行与用药安全守护 iOS App。SlowWalk 将药品识别结果、可信来源、
用户健康档案与近期用药记录整理为可解释的风险提示，帮助用户决定何时重新识别、
查看可靠来源、联系家人或咨询专业人员。

> SlowWalk 是风险提示原型，不是诊断系统，也不提供治疗方案。仓库中的药品和健康
> 数据均为 `DEMO DATA — NOT FOR CLINICAL USE`。

## 当前 MVP

- 纯 Swift 领域模型与四级风险体系：绿、黄、橙、红。
- 确定性用药风险引擎，保留每条命中原因、证据与建议动作。
- 客户端与服务端共享的 API v1 DTO 和 JSON fixtures。
- 可替换的 Repository、缓存、Clock 与 UUID 接口及内存实现。
- Swift 服务端最小健康检查和风险评估接口。
- iOS 源码边界与平台服务协议骨架。
- Windows 核心构建脚本以及 Windows/Ubuntu CI。

## 技术栈

- Swift
- SwiftUI
- async/await
- Vision
- CoreLocation
- AVFoundation
- SwiftData
- Hummingbird 2
- Swift Package Manager

## 目标平台

- iOS 客户端。
- Windows 上的跨平台核心开发与测试。
- Linux 上的 Swift 服务端构建与部署。

所有业务、客户端运行和服务端运行代码均使用 Swift。iOS 平台 API 与跨平台核心
Package 分离，服务端框架也不能进入领域层或风险引擎。

## 项目结构

- `swift-packages/SlowWalkCore/`：领域、风险引擎、API 合同与数据接口。
- `server/`：Hummingbird Swift 服务端及演示数据适配。
- `ios/`：SwiftUI 客户端和 Apple 平台服务边界。
- `shared/fixtures/`：可由测试读取的跨场景 JSON fixtures。
- `shared/api-examples/`：API 请求、响应和错误示例。
- `docs/`：范围、架构、合同、计划、演示脚本和 ADR。
- `scripts/`：Windows 验证与服务端启动脚本。
- `.github/workflows/`：核心和服务端持续集成。

详细依赖方向见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)，API 字段定义见
[`docs/API_CONTRACT.md`](docs/API_CONTRACT.md)。

## 构建与测试

需要稳定版 Swift 6 工具链。Windows 原生工具链还需要 MSVC 与 Windows SDK。

核心 Package：

```powershell
swift package --package-path .\swift-packages\SlowWalkCore resolve
swift build --package-path .\swift-packages\SlowWalkCore
swift test --package-path .\swift-packages\SlowWalkCore
```

服务端：

```powershell
swift package --package-path .\server resolve
swift build --package-path .\server
swift test --package-path .\server
pwsh -File .\scripts\run-server.ps1
```

Windows 一键验证：

```powershell
pwsh -File .\scripts\verify-windows.ps1
```

脚本默认把 SwiftPM scratch 数据放在仓库内被忽略的 `.local/`。如需显式使用 D 盘
缓存，可在运行前设置：

```powershell
$env:SLOWWALK_SCRATCH_ROOT = "D:\DevTools\SlowWalk\scratch"
pwsh -File .\scripts\verify-windows.ps1
```

## 平台验证边界

Windows 可以真实构建和测试 `SlowWalkCore`，并在 Swift 服务端依赖受支持时构建
`server/`。这不代表 Windows 已验证 SwiftUI、Vision、CoreLocation、AVFoundation、
SwiftData 或 ActivityKit。

进入 Mac/Xcode 后仍需：

- 创建并维护正式 Xcode 工程、签名和 entitlements。
- 编译 iOS target 并开启严格并发检查。
- 验证相机、OCR、定位、语音、持久化、权限和无障碍体验。
- 在模拟器与真机执行 UI、集成、性能和隐私测试。

不要手写或伪造 `.xcodeproj`/`pbxproj` 来替代 Xcode 验证。

## 医疗安全边界

- 不生成没有可信来源支持的剂量、频次、禁忌或最大剂量。
- 不把信息不足解释为“安全”；证据不足时至少返回黄色风险提示。
- 识别失败时不得给出具体服药建议，并明确提示确认药品前不要服用。
- 大语言模型不参与最终风险等级计算。
- 医学信息必须可追溯到 `SourceReference`。
- 使用“风险提示、信息整理、就医建议、专业人员确认”，避免“诊断、治疗方案、
  确认安全、保证无副作用”等表述。

## 当前不包含

- 完整 SwiftUI 成品页面、真实 OCR、GPS 守护或 ActivityKit。
- 真实医疗数据库、真实用户数据或临床规则。
- 大语言模型、RAG、推送、家属账户或实时通知。
- 用户认证、数据库迁移、云部署、图片存储或 WebSocket。
- App Store 签名、打包与发布。

## 协作

不要直接在 `main` 上开发。从 `develop` 创建 `feature/*`、`fix/*` 或 `docs/*`
分支；提交前运行可执行的构建和测试，并在 PR 中如实记录无法验证的 Apple 平台
范围。更多约定见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。
