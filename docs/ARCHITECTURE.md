# SlowWalk 架构

## 目标

SlowWalk 将可测试的业务核心、HTTP 适配和 Apple 平台能力分开。风险引擎和服务端
在 GitHub Actions Linux 容器中独立构建和测试；Windows 只做编辑、Git 与静态
审查；iOS 代码在 Mac/Xcode 中集成。服务端可以替换 HTTP 或持久化实现而不改变
风险规则。

## 模块依赖

```text
                        ┌─────────────────────┐
                        │   SlowWalkDomain    │
                        └──────────▲──────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
┌─────────────┴──────────┐ ┌───────┴───────────┐ ┌─────┴────────────────┐
│ SlowWalkRiskEngine     │ │ SlowWalkAPIContracts│ │ SlowWalkDataInterfaces│
└─────────────▲──────────┘ └────────▲──────────┘ └──────────▲───────────┘
              │                     │                       │
              └─────────────────────┼───────────────────────┘
                                    │
                   ┌────────────────┴───────────────┐
                   │                                │
           ┌───────┴────────┐              ┌────────┴────────┐
           │ SlowWalkServer │              │     iOS App     │
           │ + Hummingbird  │              │ + Apple APIs    │
           └────────────────┘              └─────────────────┘
```

箭头只指向被依赖模块。核心模块之间禁止循环依赖；Server 和 iOS 是外层适配器，
不能被核心模块引用。

## 核心 Package

### SlowWalkDomain

职责：

- `RiskLevel`、`RiskReason`、`RiskAssessment` 等风险语义。
- `UserHealthProfile`、`BodyMetrics`、`Medicine`、`MedicationRecord`。
- `MedicineScanEvent` 与 `SourceReference`。

允许依赖 Foundation，不允许依赖其他项目模块、UI、网络、数据库、服务端框架或
Apple 平台专属 API。领域值优先使用不可变 struct/enum，并在跨任务传递时满足
`Codable`、`Sendable`、`Equatable`。

### SlowWalkRiskEngine

职责：

- 定义 `RiskAssessing`、规则上下文和 `MedicationRiskRule`。
- 执行过敏、重复成分、频繁使用、持续使用、证据不足、识别失败和身体指标数据
  质量规则。
- 合并最高风险、稳定排序原因并去重建议动作。

仅依赖 `SlowWalkDomain` 与 Foundation。规则阈值、时间和 UUID 等外部变化通过
配置或接口注入，不允许网络、数据库、UI、Hummingbird、Vision 或随机判断。

### SlowWalkAPIContracts

职责：

- API v1 请求、响应和结构化错误 DTO。
- 稳定 JSON 枚举值、ISO 8601 日期策略和 API 版本字段。
- 领域对象与线上协议之间的显式边界。

仅依赖 `SlowWalkDomain` 与 Foundation。这里不包含 URLSession、HTTP 路由或任何
传输实现。

### SlowWalkDataInterfaces

职责：

- Medicine、用户档案、用药历史和缓存协议。
- 药品搜索、Clock/Date 和 UUID 抽象。
- 演示及测试使用的线程安全内存实现。

仅依赖 `SlowWalkDomain` 与 Foundation。协议不泄露具体数据库、HTTP 客户端或
Apple 持久化类型；具体实现由 Server 或 iOS 组合根提供。

## 外层适配器

### SlowWalkServer

服务端负责：

- `GET /health` 和 `POST /api/v1/risk/assess` 路由。
- JSON 解码、必要字段验证、DTO/领域映射和统一错误。
- 注入风险引擎、Repository、Clock、UUID 和演示配置。
- request ID、基础结构化日志、Content-Type 和 HTTP 状态码。

路由只编排用例，不包含风险业务分支。Hummingbird 类型不得越过服务端边界进入
核心 Package。

### iOS App

iOS 层负责：

- SwiftUI 页面、无障碍和导航。
- Vision OCR、相机、CoreLocation、系统语音与权限。
- SwiftData 或本地 JSON 缓存实现。
- 调用 Swift 服务端并显示可解释的风险行动卡。

iOS 可以依赖核心公开模块；核心模块不能反向依赖 iOS。Apple 平台文件只放在
`ios/`，不加入跨平台 SwiftPM target。

## 数据流

```text
相机或文字输入
  → Vision OCR 结果与置信度
  → 药品名称/别名标准化
  → 药品来源与证据完整性检查
  → 用户档案 + 近期用药记录 + 身体指标数据质量
  → 确定性风险规则
  → 最高风险 + 全部原因 + 稳定建议动作
  → iOS 风险行动卡 / API v1 响应
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
- iOS 集成可以在 Mac/Xcode 独立演进。
- 服务端和客户端共享同一组领域语义与 DTO。
- 平台权限、生命周期和持久化变化不会污染业务规则。

## 并发与可测试性

- 面向跨任务使用的值类型声明 `Sendable`。
- Repository 共享可变状态需要 actor 或等价隔离。
- 依赖通过初始化器注入，不建立全局单例。
- 时间窗口一律通过 Clock/Date provider 计算。
- 测试使用固定时间与固定 UUID，避免依赖执行顺序。

## 医疗安全不变量

- 缺少来源、用户信息或识别置信度时不得返回确定绿色。
- 红色命中不得被低风险覆盖。
- 所有命中原因必须保留并可追溯。
- 不生成来源未提供的剂量、频次、禁忌或治疗方案。
- 演示阈值和数据必须明确标注为非临床标准。
