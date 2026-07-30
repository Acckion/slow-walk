# Feature 边界

- `Today`：展示演示计划和当前流程摘要，不推断健康状态。
- `Companion`：驱动陪伴导航，并直接消费 canonical
  `MedicineAssessmentViewState`；候选、风险和 ActionCard 不建立 App 内副本。
- `CareRecords`：展示本次运行的内存事件，不声称已经持久化。
- `Settings`：披露当前能力和安全边界，不伪装尚未接入的设置。

相机/Vision、真实定位、健康档案编辑、持久化和联系人能力尚未接入。后续 Feature
仍通过组合根接收协议依赖；跨 Feature 的业务模型来自 SlowWalkCore，不建立第二套
Medicine 状态或风险规则。
