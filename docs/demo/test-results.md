# Day 1 成员 C 测试记录

记录日期：2026-07-28  
分支：`feature/demo-fixtures`

## 本地 Fixture 验证

结果：通过。

- 5 个 JSON 文件均通过 `jq` 语法检查。
- 5 个 request 均成功解码为 `MedicineAssessmentRequestDTO`。
- 5 个 response 均成功解码为 `MedicineAssessmentResponseDTO`。
- request/response `requestID` 一致。
- Fixture 未包含可展示的剂量内容。

## Core

结果：281/281 通过，0 failures。

本机 Apple Swift 独立运行仓库中的 Core Package 时，既有
`Package.swift` 未声明 macOS deployment platform，会在并发 API 可用性检查阶段
失败。成员 C 无权修改 Core，因此在 `/tmp` 验证副本中只增加
`platforms: [.macOS(.v14)]` 后执行完整 `swift test`。源码、测试和资源均来自当前
分支，没有修改仓库中的 Core 文件。

该临时调整属于验证环境适配，不是本分支交付物。Linux CI 不需要此调整。

## Server

本机状态：未完成本地运行。

原因：本地没有 Hummingbird checkout，SwiftPM 通过 Git HTTPS 下载依赖时连接
GitHub 超时。没有将网络失败记录为代码失败，也没有改写 Server 依赖。

新增 `DemoFixtureContractTests` 将由本分支 GitHub Actions 执行，覆盖：

- canonical endpoint 与 API version
- `RiskLevel` wire values
- `APIErrorCode` 大写编码
- 五个 Fixture 的 canonical DTO 解码
- 风险等级、ActionCard 文案、联系动作和 ViewState 预期

## 最新 develop CI 基线

核验提交：`develop@31fbd8930f73b84168abb34bb54d282f4712011d`

| Workflow | Run | 结果 | 测试 |
| --- | --- | --- | --- |
| Swift Core | [30335451251](https://github.com/creaope/slow-work/actions/runs/30335451251) | success | 281/281 |
| Swift Server | [30335451258](https://github.com/creaope/slow-work/actions/runs/30335451258) | success | 67/67 |

两个 workflow 均使用官方 `swift:6.3.2-jammy` 容器。上述结果是分支开发前的基线，
不是本功能分支最终 CI 结果；最终结果在推送后补充。

