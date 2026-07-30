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
- 模拟 OCR 文字归一化、保守候选解析和结构化 `ActionCard` 管线。
- 12 条无剂量演示药品目录，以及带版本/过期语义的 actor 解析缓存。
- Swift 服务端健康检查、药品解析和完整风险评估接口。
- 可运行的 SwiftUI 四 Tab shell，以及预设文字到设备内 ActionCard 的用药闭环。
- 可选 Swift Server HTTP 适配器；当前 iOS 默认流程不依赖云端或 localhost。
- GitHub Actions 中的 Ubuntu Swift 核心与服务端 CI。

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
- Windows 上的源码编辑、Git 管理、静态审查与测试生成。
- GitHub Actions Ubuntu 容器中的 Swift 核心与服务端编译测试。
- Linux 上的 Swift 服务端部署。

所有业务、客户端运行和服务端运行代码均使用 Swift。iOS 平台 API 与跨平台核心
Package 分离，服务端框架也不能进入领域层或风险引擎。

## 项目结构

- `swift-packages/SlowWalkCore/`：领域、风险引擎、API 合同、数据接口与药品管线。
- `server/`：Hummingbird Swift 服务端及演示数据适配。
- `ios/`：SwiftUI 客户端和 Apple 平台服务边界。
- `shared/fixtures/`：可由测试读取的跨场景 JSON fixtures。
- `shared/api-examples/`：API 请求、响应和错误示例。
- `docs/`：范围、架构、合同、计划、演示脚本和 ADR。
- `scripts/`：历史本地辅助脚本；当前 Windows 验证路线不调用它们。
- `.github/workflows/`：核心和服务端持续集成。

详细依赖方向见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)，API 字段定义见
[`docs/API_CONTRACT.md`](docs/API_CONTRACT.md)，药品 MVP 的安全设计见
[`docs/MEDICINE_PIPELINE.md`](docs/MEDICINE_PIPELINE.md)。

## 构建与测试

当前 Windows 工作区不调用本机 `swift`、`swiftc`、`swift build` 或
`swift test`。提交到 `feature/**` 或 `develop` 后，由以下 GitHub Actions
工作流在 `ubuntu-latest` 和官方 `swift:6.3.2-jammy` 容器中执行真实验证：

- [`.github/workflows/swift-core.yml`](.github/workflows/swift-core.yml)：
  对 `swift-packages/SlowWalkCore` 执行依赖解析、构建和测试。
- [`.github/workflows/swift-server.yml`](.github/workflows/swift-server.yml)：
  对 `server` 执行依赖解析、构建和测试。

两个工作流也支持从 GitHub Actions 页面手动触发。任何命令返回非零状态都会让
对应作业失败，不使用本机工具链结果替代远程日志。

## 平台验证边界

Windows 只负责编辑源码、Git 管理、静态审查和生成测试。GitHub Ubuntu CI 真实
构建和测试 `SlowWalkCore` 与 `server/`，但这不代表 Ubuntu 或 Windows 已验证
SwiftUI、Vision、CoreLocation、AVFoundation、SwiftData 或 ActivityKit。

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
分支；推送后等待适用的 GitHub Actions 构建和测试，并在 PR 中如实记录无法验证
的 Apple 平台范围。更多约定见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。
