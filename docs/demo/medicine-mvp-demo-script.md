# Medicine MVP 第一版演示视频脚本

目标时长：2 分 30 秒至 3 分钟
主场景：`normal` → `ambiguous` → `healthWarning` → `knowledgeWarning` →
`redRisk` → `timeout`

## 0:00–0:15 开场

画面：

- 启动 `SlowWalkApp`。
- 显示产品名和醒目的 `DEMO DATA — NOT FOR CLINICAL USE`。

旁白：

> 慢慢走把药盒识别、健康档案和可信来源整理成可解释的风险提示。它不是诊断系统，
> 也不会替代医生给出治疗或剂量建议。

## 0:15–0:45 normal

操作：

1. 选择 `normal`。
2. 展示识别中、评估中状态。
3. 展示绿色 Acetaminophen ActionCard。
4. 打开来源区域。

必须出现：

- 标题 `Acetaminophen`
- `Review the verified source information before use.`
- 来源名称和版本
- 非颜色的“常规查看”语义

旁白重点：药名来自服务端解析，客户端不能自行提交药品事实。

## 0:45–1:10 ambiguous

操作：

1. 选择 `ambiguous`，输入展示为 `Cold Relief`。
2. 展示需要确认药品页面。
3. 展示重新拍摄和咨询专业人员动作。

必须出现：

- 黄色提示
- `Unable to confirm the medicine`
- 不允许普通药品说明
- 不展示任一候选药品的来源或剂量

旁白重点：无法唯一确认药品时，系统不会把不确定性解释成安全。

## 1:10–1:30 healthWarning

操作：

1. 选择 `healthWarning`。
2. 展开风险原因，展示身体指标已过期。

必须出现：

- 黄色风险
- 重新测量身体指标
- 建议联系专业人员
- 不建议自动通知家属

旁白重点：这里只判断数据质量，不根据血压或心率生成诊断。

## 1:30–1:50 knowledgeWarning

操作：

1. 选择 `knowledgeWarning`。
2. 展开知识来源警告和缓存状态。

必须出现：

- 黄色风险
- `Knowledge source requires review.`
- 查看来源与咨询专业人员
- 缓存命中不等同于信息新鲜或医学安全

## 1:50–2:15 redRisk

操作：

1. 选择 `redRisk`。
2. 展示过敏成分命中原因。
3. 聚焦“联系专业人员”和“通知家属”动作。

必须出现：

- 红色以及文字/图标的立即关注语义
- `Do not take this medicine until a healthcare professional confirms the next step.`
- 可解释的规则原因
- 来源追溯

旁白重点：风险等级由确定性规则计算，大模型不参与最终等级判断。

## 2:15–2:35 timeout

操作：

1. 选择 `timeout`。
2. 展示可恢复的网络超时状态。
3. 点击用户主动重试。

必须出现：

- 不显示虚构风险等级
- 不显示虚构 ActionCard
- 不自动无限重试

## 2:35–2:50 收尾

画面：并列展示六个场景入口和四级风险说明。

旁白：

> Day 1 闭环已经把稳定 Fixture、协调器状态和可访问的 SwiftUI 风险卡片连通。
> 当前所有药品和健康数据均为合成演示数据，不可用于临床。

## 拍摄检查

- 开启较大 Dynamic Type 再录一段关键卡片。
- VoiceOver 至少朗读一次风险等级、标题、主要动作和来源。
- 画面中不得出现剂量、疗程、最大剂量或“确认安全”等表述。
- 不录入真实姓名、健康数据、位置或药盒照片。
