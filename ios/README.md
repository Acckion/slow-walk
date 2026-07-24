# SlowWalk iOS 客户端

此目录保存 Apple 平台专属源码。当前仓库在 Windows 上只建立边界和最小 SwiftUI
app shell，不声称已经编译或验证 SwiftUI、Vision、CoreLocation、AVFoundation、
SwiftData、ActivityKit、相机权限或真机行为。

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
- Feature 可以依赖 `SlowWalkDomain`、`SlowWalkRiskEngine`、
  `SlowWalkAPIContracts` 和 `SlowWalkDataInterfaces` 的公开 API。
- `Services/` 实现 OCR、网络、持久化、语音和定位协议。
- Feature/View 不直接创建 URLSession、Repository、Clock 或定位对象。
- 任何 Apple 平台类型都不得加入 `SlowWalkCore` 的跨平台 SwiftPM target。
- 风险等级由核心引擎或服务端计算，View 只显示结果，不复制规则。

## Mac/Xcode 集成清单

1. 在 Xcode 中创建正式 iOS App 工程，不手写 `pbxproj`。
2. 以本地 Package 方式添加 `../swift-packages/SlowWalkCore`。
3. 将 `SlowWalkApp/` 源码加入 iOS target，并设置稳定 deployment target。
4. 开启严格并发检查，处理所有 actor/sendability 诊断。
5. 配置相机、位置、语音等用途说明与最小权限。
6. 提供 URLSession、Vision、SwiftData、AVSpeechSynthesizer 和 CoreLocation 实现。
7. 验证 Dynamic Type、VoiceOver、对比度、触控尺寸和非颜色风险表达。
8. 在模拟器和真机测试权限拒绝、离线、超时、低置信度与数据清除。

## 医疗与隐私

- 屏幕必须明确这是风险提示，不是诊断。
- 识别失败或证据不足不能显示绿色“安全”状态。
- 不缓存未加保护的真实健康资料，不把健康数据写入日志。
- 日后引入真实数据前必须完成隐私清单、保留期限和删除流程评审。
- 任何演示数据都标注 `DEMO DATA — NOT FOR CLINICAL USE`。
