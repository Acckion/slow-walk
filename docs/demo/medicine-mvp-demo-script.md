# Medicine MVP 第一版演示视频脚本

目标时长：2 分 30 秒至 3 分钟
主场景：`normal` → `ambiguous` → `healthWarning` → `knowledgeWarning` →
`redRisk` → `timeout`

## 录制前状态声明（2026-07-29）

**当前状态：本脚本是彩排口径，尚不可正式录制。**

已完成能力：

- 五个 JSON fixture 的 response 是真实服务端 Pipeline 的 canonical
  golden output，由 `MedicineDemoFixtureGoldenTests` 全量 DTO equality 锁定。
- `MedicineAssessmentCoordinator` 可把 fixture response 驱动为正确的
  View state（`result` / `requiresMedicineConfirmation` / `failed`）。
- 服务端 `POST /api/v1/medicine/assess` 路由与全部风险规则真实可用。
- iOS 已接通预设文字、`MedicineAssessmentCoordinator`、设备内 Pipeline、canonical
  ViewState 和 ActionCard；默认路径不依赖 Server。
- App Tests Target 已合入 develop；架构分支覆盖无结果禁止推进、取消竞态和无出行
  计划不进入 travelling。

未完成依赖：

- 六场景选择器尚未接入 App；当前可见闭环只使用 normal 预设输入。
- 独立 `SlowWalkPresentation` 替代实现在 PR #17 审阅中，尚未合入 develop。最终
  集成只复用直接 ActionCard 视图，不保存它的派生 display state。
- 无真实 OCR、相机、VoiceOver 录制口径或真机验证。

何时才可正式录制：SwiftUI ActionCard 与确认页在 app 内真实接通、
`DEMO DATA — NOT FOR CLINICAL USE` 在页面可见、且本脚本中的文案与真实 UI
逐字核对通过之后。在此之前按本脚本录制的任何视频都属于彩排，不得作为
交付证据。

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
- 来源名称和版本（Mock Authoritative / Mock Secondary Medicine Source）
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
- 动作顺序：`do_not_take_until_medicine_confirmed`、
  `retake_medicine_photo`、`consult_healthcare_professional`
- 不允许普通药品说明
- 不展示任一候选药品的来源或剂量（response 中保留两个真实候选供确认
  流程使用，但 UI 不得把它们解释成安全结果）

旁白重点：无法唯一确认药品时，系统不会把不确定性解释成安全。

## 1:10–1:30 healthWarning

操作：

1. 选择 `healthWarning`。
2. 展开风险原因，展示身体指标已过演示新鲜度窗口。

必须出现：

- 黄色风险
- 原因文案 `Body metrics are older than the configured demo age limit.`
- 证据完整度为 `partial`，不得读作 complete
- 重新测量身体指标
- 建议联系专业人员
- 不建议自动通知家属

旁白重点：这里只判断数据质量，不根据血压或心率生成诊断。

## 1:30–1:50 knowledgeWarning

操作：

1. 选择 `knowledgeWarning`。
2. 展示需要确认药品页面（stale offline 知识不允许直接出结果）。
3. 展开知识来源警告和缓存状态。

必须出现：

- 黄色风险与 `mustConfirmMedicine`
- 原因文案
  `Medicine knowledge requires source review, so a green result is not permitted.`
- 警告 `Live sources were unavailable. Stale cached demo data is being used and is not current authoritative data.`
- `knowledgeCacheStatus: stale_offline`，`cacheHit: false`
- 查看来源与咨询专业人员
- 缓存状态只说明技术状态，过期缓存不等于信息新鲜或医学安全

## 1:50–2:15 redRisk

操作：

1. 选择 `redRisk`。
2. 展示过敏成分命中原因。
3. 聚焦“不要服用”“联系专业人员”和“通知家属”动作。

必须出现：

- 红色以及文字/图标的立即关注语义
- `Do not take this medicine until a healthcare professional confirms the next step.`
- 动作顺序：`do_not_take_until_medicine_confirmed`、
  `consult_healthcare_professional`、`notify_family_member`
- 原因文案
  `The medicine label matches information in the allergy profile.`
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

> Day 1 已经冻结了稳定 Fixture、协调器状态和 Pipeline golden test。
> 六场景入口与独立 Presentation 组件接通后将按本脚本正式录制。
> 当前所有药品和健康数据均为合成演示数据，不可用于临床。

## 拍摄检查

- 开启较大 Dynamic Type 再录一段关键卡片。
- VoiceOver 至少朗读一次风险等级、标题、主要动作和来源（正式录制前
  检查项，当前无已接通 UI 可验证）。
- 画面中不得出现剂量、疗程、最大剂量或“确认安全”等表述。
- 不录入真实姓名、健康数据、位置或药盒照片。
