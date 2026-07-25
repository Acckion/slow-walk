# SlowWalk 开发协作语言规范

## 默认语言

团队说明、PR 描述、Issue、测试报告和 Codex 最终报告优先使用清晰中文。面向外部
参与者时可以附英文摘要，但中文结论必须完整，不能只给机器翻译链接。

代码标识符、API 字段、framework 名称和成熟技术术语保留英文，例如
`MedicationRiskContext`、SwiftPM、actor、async/await、Hummingbird、fixture、
DTO 和 Repository。不要为了形式统一把这些术语生硬翻译成难懂中文。

## Git 与提交

commit message 使用英文 Conventional Commits：

- `feat: add health context validation`
- `test: cover medication history edge cases`
- `fix: preserve validation warnings in action cards`
- `docs: describe JSON persistence boundaries`

禁止 force push 到协作分支，不直接修改或合并 `main`。stacked branch 必须在文档
和 PR 中明确上游分支。

## PR 描述

PR 标题建议使用简洁中文，描述至少包含：

1. 中文修改摘要。
2. 实际 GitHub Actions 测试结果和链接。
3. 安全边界、已知限制和风险。
4. stacked branch 或其他依赖关系。
5. fixture、API 合同和迁移兼容性说明。

只有 GitHub Actions 的真实结果可以写成“Swift 构建通过”或“测试通过”。Windows
静态审查不能替代 Swift 编译，也不得声称验证了 SwiftUI、Vision、CoreLocation
或真机功能。

## 医疗与隐私表述

- 使用“数据质量 warning”“演示配置”“风险提醒”，不写“诊断”“确认安全”。
- 所有演示健康数据标注 `DEMO DATA — NOT FOR CLINICAL USE`。
- 日志、Issue 和 PR 不粘贴完整病史、过敏详情、身体指标、用户文件路径或调用栈。
- 测试数据必须完全虚构，不使用团队成员或真实用户信息。
