# SlowWalk 演示脚本

## 演示目的

在 5–7 分钟内展示：SlowWalk 如何把药品识别、用户档案、近期记录和可信来源转换为
可解释风险提示；重点演示确定性规则和安全降级，不展示医疗诊断。

开始前口头声明：

> 以下全部是 `DEMO DATA — NOT FOR CLINICAL USE`。SlowWalk 是风险提示原型，
> 不提供诊断、治疗方案或具体剂量建议。

## 准备

1. 确认演示提交对应的 `Swift Core` GitHub Actions 运行已经通过，并保留运行链接。
2. 只有在另一个已验证环境提供真实运行的 Swift 服务端时才演示 HTTP；当前 Windows
   不调用本机 Swift 或启动服务端。
3. 准备 `shared/api-examples/risk-assessment-request.json` 和五个 fixtures。
4. 若没有真实运行的服务端，只展示 GitHub Actions 日志、源码和 fixtures；不要
   伪造 HTTP 结果。

## 流程

### 1. 健康检查（30 秒）

请求 `GET /health`，说明 `status: ok` 只代表服务可响应，`apiVersion: v1` 固定协议
版本，不代表真实医疗数据已经接入。

### 2. 绿色基线（45 秒）

打开 `green-risk.json`：

- 药品识别可靠。
- 来源、用户资料和身体指标数据完整。
- 没有规则命中。

展示绿色结果和“遵循已核验来源信息”。强调绿色只在证据完整且没有风险命中时出现。

### 3. 黄色安全降级（60 秒）

打开 `yellow-risk.json` 或 `recognition-failed.json`：

- 来源不足或药名无法可靠确认。
- 系统不会把未知解释为安全。
- 建议重新拍摄、核对来源、咨询专业人员。
- 识别失败时明确“确认药品前不要服用”。

### 4. 橙色频繁使用（60 秒）

打开 `orange-risk.json`，展示最近 7 天记录触发演示阈值。说明：

- 阈值通过配置注入。
- 这是比赛演示规则，不是临床标准。
- 结果保留规则标识、证据和建议查看用药历史。

### 5. 红色过敏风险（60 秒）

打开 `red-risk.json`，展示用户过敏信息与有效成分命中：

- 最终等级为红色。
- 原因中保留命中的成分和规则。
- 建议咨询专业人员并联系家人。
- 任何低级规则都不能覆盖红色结果。

### 6. 可测试架构（60 秒）

展示四个核心模块和依赖方向：

- Domain 不依赖 UI/网络。
- RiskEngine 不依赖大语言模型。
- APIContracts 由 iOS 与 Server 共享。
- DataInterfaces 允许内存、SwiftData 或服务端存储适配。

展示测试对等级、原因代码、动作和日期边界的断言，而不是只展示“测试通过”数量。

### 7. 平台边界与下一步（30 秒）

说明 GitHub Ubuntu CI 已验证的是跨平台 Swift Package；Windows 只完成静态审查。
SwiftUI、Vision、CoreLocation、AVFoundation 和 SwiftData 必须进入 Mac/Xcode 后
测试。下一阶段是 iOS 集成和真实来源治理，不是扩大未经验证的医疗结论。

## 失败处理

- 服务端不可用：展示远程运行链接和真实错误，转为核心测试演示。
- fixture 解码失败：停止使用该场景并记录缺陷，不现场修改数据掩盖问题。
- 网络或 OCR 失败：展示安全降级路径，不使用预制“成功截图”冒充实时结果。
