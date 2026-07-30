# SlowWalk 架构

## 目标

SlowWalk 采用 device-first 架构：iOS App 直接调用跨平台 Swift 业务核心，正常
用药评估不依赖云端或本机 HTTP 服务。HTTP 与 Apple 平台能力分别作为外层适配器；
`SlowWalkServer` 保留用于 API contract、跨进程集成和未来受治理的数据能力，不是
当前 App 的运行前置条件。

## 模块依赖

```text
SlowWalkServer
  ├──→ SlowWalkAPIContracts
  │      ├──→ SlowWalkDomain
  │      ├──→ SlowWalkMedicineKnowledge
  │      └──→ SlowWalkLocationRisk ──→ SlowWalkDomain
  ├──→ SlowWalkMedicinePipeline
         ├──→ SlowWalkRiskEngine ──→ SlowWalkDomain
         ├──→ SlowWalkDataInterfaces ──→ SlowWalkDomain
         ├──→ SlowWalkMedicineKnowledge
         └──→ SlowWalkDomain
  └──→ SlowWalkLocationRisk

SlowWalkMedicineKnowledge
  ├──→ SlowWalkDataInterfaces ──→ SlowWalkDomain
  └──→ SlowWalkDomain

SlowWalkClientCore
  ├──→ SlowWalkDomain
  ├──→ SlowWalkAPIContracts
  ├──→ SlowWalkMedicinePipeline
  └──→ SlowWalkLocationRisk（仅使用 canonical location value types）

iOS App
  ├──→ SlowWalkClientCore
  ├──→ SlowWalkDomain
  └──→ Apple platform adapters (outside SlowWalkCore)
```

箭头只指向被依赖模块。核心模块之间禁止循环依赖；Server 和 iOS 是外层适配器，
不能被核心模块引用。

## 核心 Package

### SlowWalkDomain

职责：

- `RiskLevel`、`RiskReason`、`RiskAssessment` 等风险语义。
- `UserHealthProfile`、`BodyMetrics`、`Medicine`、`MedicationRecord`。
- `MedicineScanEvent` 与 `SourceReference`。
- 档案规范化、身体指标数据质量结果和共享 `Clock` 边界。

允许依赖 Foundation，不允许依赖其他项目模块、UI、网络、数据库、服务端框架或
Apple 平台专属 API。领域值优先使用不可变 struct/enum，并在跨任务传递时满足
`Codable`、`Sendable`、`Equatable`。

### SlowWalkRiskEngine

职责：

- 定义 `RiskAssessing`、规则上下文和 `MedicationRiskRule`。
- 执行过敏、重复成分、频繁使用、持续使用、证据不足、识别失败和身体指标数据
  质量规则。
- 合并最高风险、稳定排序原因并去重建议动作。
- `MedicationHistoryAnalyzer` 和 `MedicationRiskContextBuilder`，在进入规则引擎
  前统一完成历史去重、时区边界计算和健康上下文验证。

仅依赖 `SlowWalkDomain` 与 Foundation。规则阈值、时间和 UUID 等外部变化通过
配置或接口注入，不允许网络、数据库、UI、Hummingbird、Vision 或随机判断。

### SlowWalkAPIContracts

职责：

- API v1 请求、响应和结构化错误 DTO。
- canonical `MedicineAssessmentRequestDTO`/
  `MedicineAssessmentResponseDTO` 与 `LocationAssessmentRequestDTO`/
  `LocationAssessmentResponseDTO`。
- 严格的 `UserHealthProfileDTO` wire contract；Server 显式映射到 Domain。
- typed `APIErrorCode`、集中式 route prefix 与 path/body version 映射。
- 稳定 JSON 枚举值、ISO 8601 日期策略和 API 版本字段。
- 领域对象与线上协议之间的显式边界。

依赖 `SlowWalkDomain`、`SlowWalkMedicineKnowledge`、
`SlowWalkLocationRisk` 与 Foundation。这里不包含 URLSession、HTTP 路由或任何
传输实现。

### SlowWalkDataInterfaces

职责：

- Medicine、用户档案、用药历史和缓存协议。
- 药品搜索、Clock/Date 和 UUID 抽象。
- 演示及测试使用的线程安全内存实现。
- actor 隔离的跨平台 JSON 文件 Repository；基础目录由组合根注入，写入使用
  临时文件与原子替换，不依赖 SwiftData、CoreData 或 SQLite。

仅依赖 `SlowWalkDomain` 与 Foundation。协议不泄露具体数据库、HTTP 客户端或
Apple 持久化类型；具体实现由 Server 或 iOS 组合根提供。

### SlowWalkMedicinePipeline

职责：

- 对模拟 OCR 多段文字进行 Unicode、规格、剂型和药厂噪声归一化。
- 按精确 canonical、精确 alias、归一化名称和保守近似顺序稳定产生候选。
- 编排带版本和过期语义的解析缓存；缓存命中仍重验本次置信度。
- 只在药品可靠解析后调用 `MedicationRiskEngine`，并生成结构化 `ActionCard`。
- 每次 assessment（包括解析缓存命中）都使用当前档案、当前历史和当前身体指标
  重新执行 preflight 与 `MedicationRiskContext` 构造。

依赖 `SlowWalkDomain`、`SlowWalkDataInterfaces`、
`SlowWalkMedicineKnowledge` 和 `SlowWalkRiskEngine`。它不依赖 API DTO、
Hummingbird、UI、Vision 或其他 Apple 平台框架。

### SlowWalkMedicineKnowledge

职责：

- `MedicineKnowledgeSource`、`MedicineKnowledgeSearching` 与
  `HTTPTransporting` 协议。
- 白名单、来源优先级、版本、时间、可追溯引用和完整度验证。
- ETag/Last-Modified、304、重试、取消、响应边界与结构化缓存。
- 多来源合并、冲突证据和 stale/offline 安全降级。
- 以 `KnowledgeGovernanceVerdict` 汇总 validation、completeness、
  provenance、freshness、是否允许展示 dosage 及保守动作。

依赖 `SlowWalkDomain` 与 `SlowWalkDataInterfaces`。生产 HTTP adapter 可使用
Foundation URLSession；当前 Server demo 与所有测试只使用 mock transport。
Domain 和 RiskEngine 不反向依赖该模块。

### SlowWalkLocationRisk

职责：

- 经纬度、时间、精度、速度和样本数量的数据质量检查。
- Haversine 距离、geofence、明确的距离递减趋势、异常停留和持续远离评估。
- 位置领域专属 reason/action/assessment；风险等级复用
  `SlowWalkDomain.RiskLevel`。
- 数据质量问题可以阻止 green，但只有 `prolongedStop`、`movingAway`
  等明确行为信号参与 family-attention red 聚合。
- 根据 arrived、approaching、progressing、trend indeterminate 与 low
  accuracy 分别生成 `LocationActionCard`。

仅依赖 `SlowWalkDomain` 与 Foundation，不导入 `CoreLocation`、MapKit、
SwiftUI 或 UIKit。

### SlowWalkClientCore

职责：

- 定义平台中立的 `MedicineTextRecognizing`、`MedicineAssessmentRequesting`、
  `LocationSampleProviding` 与 `LocationAssessmentRequesting`。
- 将 `[RecognizedTextObservation]` 稳定映射为 `MedicineRecognitionInput`，但不
  生成 candidate、resolution 或 risk。
- 使用 `LocationHistoryBuffer` actor 按最大数量和时间窗口保留 bounded
  `[LocationSample]`，支持乱序 callback、精确去重和 privacy clear。
- 构造 canonical medicine/location request DTO，并把 response 映射为不依赖
  SwiftUI 的 View state 与非颜色单一表达的风险注意语义。
- 通过 `LocalMedicineAssessmentRequester` 在进程内调用
  `SlowWalkMedicinePipeline`；DTO 只作为稳定 use-case envelope，不代表发生 HTTP。
- 校验 response 的 request ID、版本、候选集合和风险/ActionCard 不变量，并只允许
  确认上一轮真实返回的候选 ID。
- 由纯 Swift coordinator 持有 operation cancellation；所有时间来自注入的
  `Clock`，不自动重试不可恢复的 validation error。

依赖 `SlowWalkDomain`、`SlowWalkAPIContracts`、`SlowWalkMedicinePipeline` 与
`SlowWalkLocationRisk`。
对 `SlowWalkLocationRisk` 的直接依赖仅用于当前 canonical `Destination`、
`LocationSample` value types；Client Core 不调用或复制 `LocationRiskEngine`。
该 target 不导入 SwiftUI、UIKit、Vision、CoreLocation、MapKit、AVFoundation、
Hummingbird 或具体 HTTP transport，并由 Linux Core workflow 编译和测试。

## 外层适配器

### SlowWalkServer

`SlowWalkServer` 是可选的 HTTP 适配器和 contract/integration test harness。
当前 iOS MVP 不启动、不发现也不调用它；没有 Server 时设备内用药评估仍完整工作。
只有未来出现受治理的远程数据、账户同步或跨设备协作需求，并经过隐私与安全评审后，
App 才能通过 `MedicineAssessmentRequesting` 的网络实现选择性接入。

服务端负责：

- `GET /health`、`POST /api/v1/medicine/search`、`POST
  /api/v1/medicine/resolve`、`POST /api/v1/medicine/assess` 和
  `POST /api/v1/location/assess` 路由。
- JSON 解码、必要字段验证、DTO/领域映射和统一错误。
- 注入风险引擎、Repository、Clock、UUID 和演示配置。
- request ID、基础结构化日志、Content-Type 和 HTTP 状态码。

路由只编排用例，不包含风险业务分支。Hummingbird 类型不得越过服务端边界进入
核心 Package。

旧 `POST /api/v1/risk/assess` 默认路由已关闭，公开 raw risk DTO 已移除。客户端
不能提交完整 `Medicine`、ingredient 或 `SourceReference` 绕过
`MedicinePipeline`、`SourcePolicy` 与 health preflight。

### iOS App

iOS 层负责：

- SwiftUI 页面、无障碍和导航，消费 `SlowWalkClientCore` View state。
- 在组合根注入 `LocalMedicineAssessmentRequester`，正常路径直接运行设备内
  `MedicinePipeline`，不通过 localhost 或云端绕一圈。
- `LocalLocationAssessmentRequester` 已提供同样的设备内规则 adapter；当前 App
  尚未接入 CoreLocation，因此不会用模拟按钮生成伪造位置样本或位置结论。
- 在 Mac/Xcode 中实现 Vision OCR、相机、CoreLocation、系统语音与权限 adapter；
  网络 adapter 只作为未来可选实现。
- SwiftData 或本地 JSON 缓存实现。
- 显示 canonical `ActionCard`，不在 App 内复制风险规则或维护第三套 Medicine 状态。

iOS 可以依赖核心公开模块；核心模块不能反向依赖 iOS。`VisionMedicineTextRecognizer`、
`CoreLocationSampleProvider`、`URLSessionMedicineAssessmentClient` 与
`URLSessionLocationAssessmentClient` 当前只是可选 adapter 名称，尚未
实现或经 Mac/Xcode 验证。Apple 平台文件只放在 `ios/`，不加入跨平台 SwiftPM
target。

## 数据流

```text
设备内主路径：

相机或明确标注的演示文字输入
  → OCRImageInput（图片只停留在 adapter 调用栈）
  → [RecognizedTextObservation]
  → MedicineRecognitionInput
  → MedicineAssessmentCoordinator
  → LocalMedicineAssessmentRequester
  → MedicinePipeline 药品名称/别名标准化
  → 白名单知识源 + 版本/时间验证 + 冲突/缓存状态
  → 用户档案 + 近期用药记录 + 身体指标数据质量
  → 确定性风险规则
  → 最高风险 + 全部原因 + 稳定建议动作
  → canonical MedicineAssessmentResponseDTO
  → MedicineAssessmentViewState

可选 HTTP 路径（当前 App 未接入）：

MedicineAssessmentRequestDTO
  → MedicineAssessmentRequesting 网络适配器
  → SlowWalkServer
  → 相同 MedicinePipeline
  → 经校验的 MedicineAssessmentResponseDTO

位置样本
  → LocationSampleProviding
  → bounded LocationHistoryBuffer
  → LocationAssessmentRequestDTO
  → LocationAssessmentCoordinator
  → LocalLocationAssessmentRequester
  → 设备内数据质量 + 距离/geofence/趋势 + 行为规则
  → LocationAssessmentResponseDTO
  → LocationAssessmentViewState

可选 Location HTTP requester 可以实现相同 contract，但不是默认路径；完整轨迹不应
仅为运行本地可计算规则而离开设备。
```

识别失败或来源不足会沿数据流保留下来，不能在中间层被转换为“无风险”。

## 为什么风险引擎不依赖大语言模型

最终风险必须可复现、可审计并能解释到规则和证据。生成式模型可能因模型版本、
提示或服务状态产生不同结果，也可能编造剂量或医学结论。因此大语言模型不能参与
等级计算。本阶段不接入模型；未来即使加入文字整理，也只能消费引擎结果，不能改变
风险等级或来源。

## 为什么分离 iOS 与跨平台 Package

GitHub Actions Linux 容器能运行 SwiftPM/XCTest，但不能编译 SwiftUI、Vision
或 CoreLocation。若把平台 API 混入 Domain 或 RiskEngine，就无法在跨平台 CI
中验证核心，也会迫使服务端链接无关框架。分离后：

- 核心规则可以在 GitHub Actions Linux 容器中快速测试。
- 客户端 use-case contract、状态、轨迹窗口和 cancellation 也由 Linux XCTest
  验证。
- iOS 集成可以在 Mac/Xcode 独立演进。
- 服务端和客户端共享同一组领域语义与 DTO。
- 平台权限、生命周期和持久化变化不会污染业务规则。

## 并发与可测试性

- 面向跨任务使用的值类型声明 `Sendable`。
- Repository 共享可变状态需要 actor 或等价隔离。
- 客户端 bounded location history 使用 actor 隔离，不保留无限轨迹。
- 依赖通过初始化器注入，不建立全局单例。
- 时间窗口一律通过 Clock/Date provider 计算。
- Coordinator 使用结构化 `async/await` 与显式 cancellation，不使用
  `Task.detached`。
- 测试使用固定时间与固定 UUID，避免依赖执行顺序。

## 医疗安全不变量

- 缺少来源、用户信息或识别置信度时不得返回确定绿色。
- 字段缺失不能被解释成用户明确填写的空数组。
- knowledge validation warning、低 completeness、stale 或 provenance
  无法确认时至少 yellow，并禁止 dosage/frequency 展示。
- geofence 外只有明确距离递减趋势才能返回 progressing green。
- 数据质量 orange 不参与 family-attention red 行为信号计数。
- 红色命中不得被低风险覆盖。
- 所有命中原因必须保留并可追溯。
- 不生成来源未提供的剂量、频次、禁忌或治疗方案。
- 演示阈值和数据必须明确标注为非临床标准。
