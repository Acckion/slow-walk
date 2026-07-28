# Medicine MVP Mock 与真实能力边界

## 当前真实能力

- canonical Medicine API DTO 与 ISO 8601 编解码。
- `MedicineAssessmentCoordinator` 的状态编排。
- 服务端 `POST /api/v1/medicine/assess` 路由。
- 确定性药品解析、健康上下文检查和风险规则。
- `ActionCard`、来源追溯、缓存状态和 typed API error。
- Core 与 Server 的 SwiftPM 测试和 GitHub Actions。

## 当前 Mock 能力

- OCR 输入来自固定 `recognizedTexts`，不读取真实相机图片。
- 五个成功/保守结果来自版本控制中的稳定 JSON response。
- timeout 由 `MockMedicineAssessmentRequester(.timeout)` 模拟。
- 药品目录和来源均为合成演示数据。
- 健康档案、身体指标、用药历史均为合成数据。

## 当前未实现

- Vision OCR、相机权限和真实药盒图像处理。
- 真实药品数据库、Qwen、RAG 或临床规则。
- HealthKit、Apple Watch 或真实身体指标。
- 生产认证、云数据库、推送、家属账户和隐私治理。
- 生产网络 SLA、离线同步与真实服务部署。

## 演示安全规则

- 所有页面持续显示 `DEMO DATA — NOT FOR CLINICAL USE`。
- 不输出 Fixture 或可信来源未提供的剂量信息。
- timeout 不构造假的 API 错误、风险等级或 ActionCard。
- ambiguous 不展示任一候选药品的普通说明。
- redRisk 不提供“继续按说明服用”动作。
- 缓存命中只说明技术缓存状态，不说明来源新鲜或安全。
