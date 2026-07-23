# ADR-001：客户端采用 Swift

## 状态

已接受。

## 决策

本项目 iOS 客户端的指定开发语言为 Swift，使用 SwiftUI 构建主要用户界面，
并使用 async/await 管理异步工作。Vision、CoreLocation、AVFoundation、
SwiftData 等 Apple 平台实现只位于 `ios/`，不能进入跨平台核心 Package。

## 原因

1. 项目目标平台为 iOS。
2. 需要使用 Vision、CoreLocation、ActivityKit 等原生能力。
3. 原生 Swift 接入系统权限和无障碍能力更加直接。
4. 减少 Flutter 与原生插件之间的适配工作。
5. 复赛时间有限，不再保留 Kotlin Android 开发路线。
6. 与 Swift 领域模型和 API 合同共享静态类型，减少跨语言协议漂移。

## 后果

- Windows 只构建和测试跨平台 SwiftPM 模块，不能用来验证 Apple 平台 API。
- iOS 源码必须在 Mac/Xcode 中补充工程、签名、权限、模拟器和真机验证。
- 核心业务逻辑不得写入 SwiftUI View、OCR 服务或网络实现。
- Flutter 与 Kotlin 只作为已放弃路线的历史背景，不是当前开发目标。

服务端语言与框架由 ADR-002 单独约束。
