# iOS CI 预留计划

当前阶段不创建 `.github/workflows/ios-build.yml`，也不在 Windows 上伪造
`.xcodeproj` 或 `.xcworkspace`。Ubuntu 上的 SwiftPM 工作流只验证
`swift-packages/SlowWalkCore` 和 `server`，不能证明 SwiftUI 或任何 iOS
专属功能可以构建。

## 启用条件

只有满足以下条件后才建立 iOS 工作流：

1. 在 Mac 上使用 Xcode 创建并提交真实的 `.xcodeproj` 或 `.xcworkspace`。
2. 提交一个可供 CI 使用的 shared scheme。
3. 用 Xcode 确认项目引用 `SlowWalkCore` 的方式和最低 iOS 版本。
4. 确认模拟器构建不需要证书、描述文件或仓库中的私密配置。

## 预定验证方式

未来的 `.github/workflows/ios-build.yml` 应当：

- 使用 `runs-on: macos-latest`。
- 使用 `xcodebuild` 和真实工程、workspace、scheme 名称。
- 选择 iOS Simulator 目标。
- 设置 `CODE_SIGNING_ALLOWED=NO` 和 `CODE_SIGNING_REQUIRED=NO`。
- 在任何解析、编译或测试失败时让工作流真实失败。
- 明确区分模拟器构建结果与真机、签名、权限和发布验证。

在真实 Xcode 工程和 shared scheme 存在前，上述命令参数保持未填写状态，
不创建占位工作流。
