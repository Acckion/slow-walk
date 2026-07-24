# ADR-002：服务端采用 Swift 与 Hummingbird

## 状态

已接受。

## 背景

早期仓库仅预留了空的旧后端目录和空决策文件，没有可迁移的运行代码、接口实现或
数据。当前项目要求客户端、共享业务核心与服务端保持全 Swift 技术路线。

## 决策

- 服务端使用稳定版 Swift 6 和 Swift Package Manager。
- HTTP 框架采用 Hummingbird 2.x。
- 服务端作为独立 `server/` Package，仅负责 HTTP、验证、DTO 映射、日志和演示
  组合根。
- 风险判断由 `SlowWalkRiskEngine` 完成；路由不得复制业务规则。
- 客户端和服务端通过 `SlowWalkAPIContracts` 共用 DTO。
- 演示阶段只使用内存 Repository 和标注为非临床用途的演示数据。

## 依赖方向

`SlowWalkServer` 可以依赖：

- `SlowWalkDomain`
- `SlowWalkRiskEngine`
- `SlowWalkAPIContracts`
- `SlowWalkDataInterfaces`
- Hummingbird 2.x

核心模块不得反向依赖服务端或 Hummingbird。

## 后果

- `SlowWalkCore` 必须在不依赖 Hummingbird 的 GitHub Actions 作业中独立构建测试。
- 服务端必须在 GitHub Actions Linux 容器中完成真实构建与测试。
- 不允许为绕过框架或工具链问题而改用其他运行语言。
- 不手写不可靠的 HTTP 协议实现来伪装服务端完成。

## 已放弃路线

仓库曾预留 FastAPI/Python 空模板，但其中没有有效代码或合同。该路线已经终止；
历史说明不构成当前技术选型。
