# SlowWalk iOS 客户端

此目录保存 Apple 平台专属源码。可由 Linux 验证的客户端 use-case protocol、
View state、request builder、协调器、mock 与 bounded location history 已统一放入
`SlowWalkClientCore`。当前仓库在 Windows 上只维护边界和最小 SwiftUI app shell，
不声称已经编译或验证 SwiftUI、Vision、CoreLocation、AVFoundation、SwiftData、
ActivityKit、相机权限或真机行为。

## 计划结构

```text
SlowWalkApp/
├── App/                 SwiftUI 入口与依赖组合
├── Features/
│   ├── MedicineScanner/
│   ├── RiskResult/
│   ├── HealthProfile/
│   ├── MedicationHistory/
│   └── LocationGuard/
├── Services/
│   ├── OCR/
│   ├── Network/
│   ├── Persistence/
│   ├── Speech/
│   └── Location/
└── Resources/
```

当前只添加少量有行为意义的协议和 app shell，不用空 Swift 文件机械填充目录。

## 依赖边界

- `App/` 是 iOS 组合根，负责把平台实现注入 Feature。
- Feature 优先依赖 `SlowWalkClientCore` 的协调器与 View state；只有组合根和 adapter
  需要直接接触底层公开模块。
- `Services/` 在 Mac/Xcode 中实现 `SlowWalkClientCore` 定义的 OCR、网络和定位
  协议，以及 iOS 专属的持久化和语音协议。
- Feature/View 不直接创建 URLSession、Repository、Clock 或定位对象。
- 任何 Apple 平台类型都不得加入 `SlowWalkCore` 的跨平台 SwiftPM target。
- 风险等级由核心引擎或服务端计算，View 只显示结果，不复制规则。
- Medicine network adapter 只实现 `MedicineAssessmentRequesting`，Location network
  adapter 只实现 `LocationAssessmentRequesting`；两者只传输 canonical API DTO。
- 旧 raw risk DTO 与 `/api/v1/risk/assess` 已关闭；iOS 不得构造或提交完整
  `Medicine`、ingredient 或 `SourceReference`。
- 错误分支统一按 typed `APIErrorCode` 处理；旧 lowercase code 只由 contracts
  中的单一兼容 decoder 接收。
- UI 分别解释 `resolutionCacheStatus` 与 `knowledgeCacheStatus`，不得把 cache hit
  当作 freshness 或医学安全结论。
- 药品与位置卡片共享 `SlowWalkDomain.RiskLevel`，但分别显示各自 reasons/actions。

## Canonical client flow

```text
OCRImageInput
  → MedicineTextRecognizing
  → [RecognizedTextObservation]
  → MedicineRecognitionInputMapper
  → MedicineAssessmentRequestDTO
  → MedicineAssessmentRequesting
  → MedicineAssessmentViewState

LocationSampleProviding
  → bounded [LocationSample]
  → LocationAssessmentRequestBuilder
  → LocationAssessmentRequestDTO
  → LocationAssessmentRequesting
  → LocationAssessmentViewState
```

旧的 `imageData → MedicineScanEvent` OCR 协议、`LocationSnapshotProviding` 单点协议
和 raw risk network 协议不再是正式接口，也不在 `ios/` 保留并行定义。

## Mac/Xcode 集成清单

1. 在 Xcode 中创建正式 iOS App 工程，不手写 `pbxproj`。
2. 以本地 Package 方式添加 `../swift-packages/SlowWalkCore`。
3. 将 `SlowWalkApp/` 源码加入 iOS target，并设置稳定 deployment target。
4. 开启严格并发检查，处理所有 actor/sendability 诊断。
5. 配置相机、位置、语音等用途说明与最小权限。
6. 在 Mac/Xcode 中实现并验证：
   - `VisionMedicineTextRecognizer`
   - `CoreLocationSampleProvider`
   - `URLSessionMedicineAssessmentClient`
   - `URLSessionLocationAssessmentClient`
7. 另外提供受保护的 SwiftData/文件存储与 `AVSpeechSynthesizer` 实现。
8. 验证 Dynamic Type、VoiceOver、对比度、触控尺寸和非颜色风险表达。
9. 在模拟器和真机测试权限拒绝、离线、超时、低置信度与数据清除。
10. 为 arrived、approaching、progressing、trend indeterminate、low accuracy
   分别验证文案和无障碍标签，禁止用统一“已接近或到达”覆盖不同证据。

## 医疗与隐私

- 屏幕必须明确这是风险提示，不是诊断。
- 识别失败或证据不足不能显示绿色“安全”状态。
- 当前 JSON Repository **未加密且没有 Apple Data Protection**；正式 adapter
  完成受保护存储前，不得写入真实健康资料。
- 不把健康数据、完整位置轨迹、药名或来源详情写入日志/错误响应。
- 日后引入真实数据前必须完成隐私清单、保留期限和删除流程评审。
- 任何演示数据都标注 `DEMO DATA — NOT FOR CLINICAL USE`。

上述四个 Apple adapter 当前仅有接口预期和命名，尚未实现。当前也尚未在
Mac/Xcode 验证 SwiftUI、Vision、CoreLocation、URLSession adapter 或 Apple 平台
strict concurrency；Linux CI 通过不能替代 simulator/真机验证。
