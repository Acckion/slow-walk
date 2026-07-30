# Medicine MVP Mock 与真实能力边界

## 当前真实能力

- canonical Medicine API DTO 与 ISO 8601 编解码。
- `MedicineAssessmentCoordinator` 的状态编排。
- `LocalMedicineAssessmentRequester` 直接调用设备内 Medicine Pipeline，并对响应执行
  request ID、版本和结构校验。
- iOS 陪伴页使用 canonical `MedicineAssessmentViewState`，真实 Pipeline 返回后才
  显示 ActionCard；没有出行计划时不会进入出行状态。
- 服务端 `POST /api/v1/medicine/assess` 路由。
- 确定性药品解析、健康上下文检查和风险规则。
- `ActionCard`、来源追溯、缓存状态和 typed API error。
- Core 与 Server 的 SwiftPM 测试和 GitHub Actions。
- 五个 JSON fixture 的 response 是真实服务端 Pipeline 的 canonical
  golden output：`MedicineDemoFixtureGoldenTests` 用 fixture request 驱动
  真实 composition root（resolver、健康上下文校验、风险引擎、ActionCard
  工厂、Medicine Pipeline、知识服务、controller 映射），并与 fixture
  response 做全量 DTO equality。fixture 不再是“与自身 expectation 自洽”
  的手工数据。

## 当前 Mock 能力

- OCR 输入来自固定 `recognizedTexts`，不读取真实相机图片。
- 五个成功/保守结果来自版本控制中的稳定 JSON response（其内容已被
  golden test 锁定为真实 Pipeline 输出）。
- timeout 由 `MockMedicineAssessmentRequester(.timeout)` 模拟；它是客户端
  传输场景，不存在可记录的 response，因此没有对应的 JSON fixture。
- 药品目录和知识来源均为合成演示数据（bundled demo catalog +
  mock authoritative / secondary knowledge sources）。
- 健康档案、身体指标、用药历史均为合成数据。

## 当前未实现

- Vision OCR、相机权限和真实药盒图像处理。
- `SlowWalkPresentation` 的最终集成；App 当前使用薄层 canonical ActionCard
  renderer。独立 Package 合入后只复用直接 ActionCard 视图，不把其派生状态保存为
  App 的第三套 Medicine 状态。
- 真实药品数据库、Qwen、RAG 或临床规则。
- HealthKit、Apple Watch 或真实身体指标。
- 生产认证、云数据库、推送、家属账户和隐私治理。
- 生产网络 SLA、离线同步与真实服务部署。
- 真实位置采集；当前出行按钮只修改演示进度，不声称来自 CoreLocation。

## 演示安全规则

- 所有页面持续显示 `DEMO DATA — NOT FOR CLINICAL USE`。fixture 在 payload
  内携带该标签（药品 warnings、response disclaimer、configuration
  notices），页面可见性由 app 壳层负责。
- 不输出 Fixture 或可信来源未提供的剂量信息。
- timeout 不构造假的 API 错误、风险等级或 ActionCard。
- ambiguous 不展示任一候选药品的普通说明。
- redRisk 不提供“继续按说明服用”动作；红色卡片必须包含
  `do_not_take_until_medicine_confirmed`。
- knowledgeWarning（stale offline）必须要求先确认药品，不得直接展示
  绿色或普通说明。
- 缓存命中只说明技术缓存状态，不说明来源新鲜或安全。
