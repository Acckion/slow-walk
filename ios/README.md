# SlowWalk iOS 客户端

此目录保存 Apple 平台专属源码。可由 Linux 验证的客户端 use-case protocol、
View state、协调器、本地/网络请求协议与 bounded location history 已统一放入
`SlowWalkClientCore`。App 当前已把预设演示文字接入设备内 Medicine Pipeline，
可以得到 canonical `ActionCard`；这不代表已经验证 Vision、CoreLocation、
AVFoundation、SwiftData、ActivityKit、相机权限或真实药品数据。

## 当前界面结构

```text
TabView
├── 今天：今日演示安排与进入陪伴
├── 陪伴：设备内用药评估、候选确认、ActionCard、按钮模拟出行
├── 守护记录：仅内存保存的过程记录
└── 关怀设置：能力边界与未接入项
```

当前只添加少量有行为意义的协议和 app shell，不用空 Swift 文件机械填充目录。

## Xcode 工程

- 工程：`ios/SlowWalkApp.xcodeproj`
- Shared Scheme：`SlowWalkApp`
- 最低系统版本：iOS 17.0
- Bundle Identifier：`com.creaope.slowwalk`
  - provisional，尚未注册正式 App ID
- 本地 Package：`../swift-packages/SlowWalkCore`
- App Target 显式依赖：
  - `SlowWalkDomain`
  - `SlowWalkAPIContracts`
  - `SlowWalkClientCore`
- Swift Language Mode：Swift 6
- Strict Concurrency Checking：Complete
- 本阶段未配置真机签名。

无签名模拟器构建命令：

```bash
xcodebuild \
  -project ios/SlowWalkApp.xcodeproj \
  -scheme SlowWalkApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/slowwalk-ios-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## 依赖边界

- `App/` 是 iOS 组合根，负责把平台实现注入 Feature。
- Feature 优先依赖 `SlowWalkClientCore` 的协调器与 View state；只有组合根和 adapter
  需要直接接触底层公开模块。
- `Services/` 承载 `SlowWalkClientCore` 定义的 Apple 平台 adapter；当前只有明确
  标注的预设文字 recognizer。定位、持久化、语音和网络 requester 尚未接入，
  其中网络 requester 也只会是可选路径。
- Feature/View 不直接创建 URLSession、Repository、Clock 或定位对象。
- 任何 Apple 平台类型都不得加入 `SlowWalkCore` 的跨平台 SwiftPM target。
- 风险等级由核心引擎或服务端计算，View 只显示结果，不复制规则。
- 默认 Medicine requester 是 `LocalMedicineAssessmentRequester`，直接运行同进程
  Pipeline。未来网络 adapter 也只能实现同一个 `MedicineAssessmentRequesting`
  contract，并传输 canonical API DTO。
- `CompanionSessionModel` 只保存 canonical `MedicineAssessmentViewState`；整体陪伴
  state 只负责导航阶段，不复制识别、候选或风险结果。
- 旧 raw risk DTO 与 `/api/v1/risk/assess` 已关闭；iOS 不得构造或提交完整
  `Medicine`、ingredient 或 `SourceReference`。
- 错误分支统一按 typed `APIErrorCode` 处理；旧 lowercase code 只由 contracts
  中的单一兼容 decoder 接收。
- 后续 UI 若展示缓存状态，必须分别解释 `resolutionCacheStatus` 与
  `knowledgeCacheStatus`，不得把 cache hit 当作 freshness 或医学安全结论。
- 药品与位置卡片共享 `SlowWalkDomain.RiskLevel`，但分别显示各自 reasons/actions。

## Canonical client flow

```text
OCRImageInput
  → MedicineTextRecognizing
  → [RecognizedTextObservation]
  → MedicineRecognitionInputMapper
  → MedicineAssessmentCoordinator
  → LocalMedicineAssessmentRequester
  → MedicinePipeline
  → MedicineAssessmentViewState

LocationSampleProviding
  → bounded [LocationSample]
  → LocationAssessmentCoordinator
  → LocationAssessmentRequestBuilder
  → LocationAssessmentRequestDTO
  → LocationAssessmentRequesting（默认 LocalLocationAssessmentRequester）
  → LocationRiskEngine
  → LocationAssessmentResponseDTO
  → LocationAssessmentViewState
```

`LocalLocationAssessmentRequester` 已存在于 ClientCore，但 App 尚未注入真实
`LocationSampleProviding`，因此当前出行页面只提供明确标注的按钮模拟，不产生
位置风险结果。

旧的 `imageData → MedicineScanEvent` OCR 协议、`LocationSnapshotProviding` 单点协议
和 raw risk network 协议不再是正式接口，也不在 `ios/` 保留并行定义。

## Mac/Xcode 集成清单

1. 已在 Xcode 中创建正式 iOS App 工程，未手写 `pbxproj`。
2. 已以本地 Package 方式添加 `../swift-packages/SlowWalkCore`。
3. 已将 `SlowWalkApp/` 源码加入 iOS target，并将 deployment target 设为 iOS 17.0。
4. 已使用 Swift 6 Complete strict concurrency 完成 app shell 模拟器编译。
5. 配置相机、位置、语音等用途说明与最小权限。
6. 在 Mac/Xcode 中实现并验证：
   - `VisionMedicineTextRecognizer`
   - `CoreLocationSampleProvider`
   - 可选的 `URLSessionMedicineAssessmentClient`
   - 可选的 `URLSessionLocationAssessmentClient`
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

当前 App 已接通预设 OCR 文字、本地 Coordinator/Pipeline、canonical ViewState 和
ActionCard。预设适配器不读取图片，出行进度只由按钮模拟；尚未验证 Vision、
CoreLocation、网络 adapter、权限或真机行为。模拟器构建不能替代真机验证。
