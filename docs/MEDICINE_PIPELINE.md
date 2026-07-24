# 药品识别到行动卡 MVP

> DEMO DATA — NOT FOR CLINICAL USE

本阶段只接受模拟 OCR 文字，不接入相机、Vision、SwiftUI、CoreLocation、数据库、
大语言模型或真实临床药品库。Windows 只编辑和管理 Git；Swift 编译与测试由
GitHub Actions 的 Linux 容器执行。

## 数据流

```text
MedicineRecognitionInput
  → MedicineNameNormalizer
  → MedicineResolver
  → 服务端内置演示目录
  → MedicineResolution cache
  → 当前 UserHealthProfile + MedicationRecord
  → MedicationRiskEngine
  → ActionCard
```

`MedicineRecognitionInput` 由多段 OCR 文字、拍摄时间、可选语言代码和可选原始
置信度组成。服务端不会接受客户端提交的完整 `Medicine`，因此客户端不能替换
目录中的成分、来源、警告或版本。

## 名称归一化

`MedicineNameNormalizer` 只做确定性文字处理：

- Unicode、大小写和全角/半角折叠；
- 多余空格和换行拆分；
- 规格文字与剂型分离，同时保留片、胶囊、颗粒等剂型证据；
- 剔除明确的药厂行和包装噪声；
- 合并多段 OCR 文本并保留稳定查询变体。

归一化不会猜测药名，也不会把近似字符串直接当作确认结果。被移除的规格和噪声
会进入 `MedicineResolutionEvidence`，便于测试和审计。

## 候选解析

`MedicineResolver` 的顺序固定为：

1. canonical name 精确匹配；
2. alias 精确匹配；
3. 同一归一化键匹配；
4. 受限子串或一次编辑差异的保守近似候选。

全部分数和阈值集中在 `ResolverConfiguration`。候选按分数降序、canonical name
和 ID 升序稳定排列。近似分数低于自动确认阈值；最高分接近、多条共享别名、低
置信度或无置信度时，不会任意选择一个药品。

解析状态的稳定字符串为：

- `resolved`
- `ambiguous`
- `insufficient_evidence`
- `not_found`
- `recognition_failed`

只有 `resolved` 可以进入具体药品的风险评估。其他状态必须要求用户确认。

## 演示目录

SwiftPM resource `demo-medicine-catalog.json` 包含 12 条常见通用名演示记录：

- Acetaminophen
- Ibuprofen
- Dextromethorphan
- Chlorpheniramine
- Amlodipine
- Losartan
- Metformin
- Gliclazide
- Cetirizine
- Loratadine
- Omeprazole
- Famotidine

目录覆盖止痛、退热、感冒、降压、降糖、抗过敏和胃肠道类别。所有记录均带
`DEMO DATA — NOT FOR CLINICAL USE`，`dosageTextFromSource` 一律为 `null`，
不包含剂量、频次或治疗建议。目录来源只表示可追踪的演示数据版本，不代表临床
权威或药品适用性。

## 缓存

`InMemoryMedicineCache` 是 actor。解析缓存键由本次全部归一化查询变体组成，避免
只复用首段 OCR 而忽略后续文字，并记录：

- source data version；
- storedAt 和 expiresAt；
- hit、miss、expired 或 source_version_changed。

缓存只复用名称候选，不缓存 `RiskAssessment`。命中后仍以本次 OCR 置信度重新
解析，并以当前用户档案和近期记录重新运行 `MedicationRiskEngine`。缓存命中
不是医学安全确认。

## 行动卡安全不变量

- 未确认药品时，行动卡必须说明无法确认、要求重拍药盒正面，并要求确认前不要
  服用。
- `recognition_failed`、`not_found`、`ambiguous` 和
  `insufficient_evidence` 不得输出剂量或服用频次。
- 来源缺失时风险不得为绿色，也不得输出普通“按来源使用”动作。
- 红色风险会移除普通使用动作，并明确阻止服用，直到专业人员确认下一步。
- `ActionCard` 从不转录 `dosageTextFromSource`。

## 已知限制

本管线没有验证真实 OCR、包装图像、品牌名穷举、临床数据、SwiftUI 或任何 Apple
平台能力。保守近似只用于产生候选；真实药品确认仍需要用户和合格专业人员。
