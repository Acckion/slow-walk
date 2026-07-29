# Day 1 成员 C 测试记录

记录日期：2026-07-29
分支：`fix/pr7-canonical-fixtures-k3`（PR #7 修复轨道）

## 本地 Fixture 验证

结果：通过。

- 5 个 JSON 文件均通过语法检查。
- 5 个 request 均成功解码为 `MedicineAssessmentRequestDTO`。
- 5 个 response 均成功解码为 `MedicineAssessmentResponseDTO`。
- request/response `requestID` 一致。
- Fixture 未包含可展示的剂量内容。
- 5 个 response 现在是真实服务端 Pipeline 的 canonical golden output，
  由 `MedicineDemoFixtureGoldenTests` 以 fixture request 驱动真实
  composition root 并做全量 DTO equality，无任何字段归一化。

## Golden test 防自证说明

- expected 只来自 fixture.response；actual 只来自真实 Pipeline。
- 测试不复制生产算法，也不从 fixture.response 反向构造输出。
- 失败证明（手工 mutation probe，非仓库内自动化测试）：在 `/tmp` 下的
  隔离克隆中，把修复前 HEAD 的五个 fixture 放回 `demo-fixtures/`，经同一
  golden harness 比较，**5/5 均被拒绝**（`XCTAssertEqual failed`）。另外
  单独把修复后 fixture 的深层字段人工改写（`medicine-red-risk.json` 的
  `actionCard.mustConfirmMedicine`、`medicine-source-warning.json` 的
  `medicineKnowledge.candidates[0].completeness`），两次改写均被拒绝，
  说明比较覆盖到最深层叶子字段。修复后的原始 fixture 全部通过。
- 上述 probe 只在隔离克隆内进行，审查工作区未被修改；probe 本身尚未作为
  仓库内自动化测试提交，重跑需要手工重建隔离克隆。

## Core

结果：281/281 通过，0 failures。

本机 Apple Swift 直接运行仓库中的 Core Package 时，既有
`Package.swift` 未声明 macOS deployment platform，会在并发 API 可用性检查
阶段失败（Linux CI 无此问题）。本次本地验证使用命令行
`-Xswiftc -target -Xswiftc arm64-apple-macosx14.0` 覆盖部署目标执行完整
`swift test`。源码、测试和资源均来自当前分支，没有修改仓库中的任何 Core
文件。Linux CI 仍是权威检查。

## Server

结果：80/80 通过，0 failures（与 Core 相同的本机 platform manifest
边界，使用相同的 target 覆盖；未修改仓库文件）。

相比修复基线 71 项新增 9 项，全部实际执行并通过：

- `MedicineDemoFixtureGoldenTests`（2 项）：4 个在线场景与 1 个
  stale-offline 知识警告场景的全量 DTO golden equality。
- `DemoFixtureContractTests` 新增 7 项：Coordinator 语义一致性、动作
  内容与顺序冻结、canonical 版本/配置字符串、候选与状态一致性、证据
  完整度与警告一致性、知识/缓存联合状态、disclaimer 责任边界。
- Fixture 路径解析改为从测试文件向上搜索 `demo-fixtures/README.md`
  锚点；缺失 fixture 是明确失败，不是静默跳过。

## 最新 CI 基线

核验提交：本分支 `db58ceceba5942a357857cb4db531f193ff0198d`

| Workflow | Run | 结果 |
| --- | --- | --- |
| Swift Core | [30369761730](https://github.com/creaope/slow-walk/actions/runs/30369761730) | success |
| Swift Server | [30369761447](https://github.com/creaope/slow-walk/actions/runs/30369761447) | success |

最新 develop 基线（合并 PR #4 后）：

| Workflow | Run | 结果 |
| --- | --- | --- |
| Swift Core | [30410860272](https://github.com/creaope/slow-walk/actions/runs/30410860272) | success |
| Swift Server | [30410860265](https://github.com/creaope/slow-walk/actions/runs/30410860265) | success |

两个 workflow 均使用官方 `swift:6.3.2-jammy` 容器。上述 success 是修复前
代码的结果：原测试只验证 fixture 与自身 expectation 自洽，不能证明
fixture 正确。本分支修复后的最终结果在推送后补充。
