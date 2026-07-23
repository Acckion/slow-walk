# Feature 边界

- `MedicineScanner`：相机/OCR 输入与候选药品确认，不计算风险。
- `RiskResult`：显示等级、全部原因、来源和行动卡，不复制业务规则。
- `HealthProfile`：采集和编辑用户明确提供的档案，不进行诊断。
- `MedicationHistory`：展示记录并通过 Repository 保存。
- `LocationGuard`：后续出行守护边界，本阶段不实现 GPS 行为。

Feature 通过初始化器接收协议依赖。跨 Feature 的业务模型来自 SlowWalkCore，不建立
共享可变全局状态。

