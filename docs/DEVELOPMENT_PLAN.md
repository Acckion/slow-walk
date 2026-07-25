# 开发计划

## 原则

- 先稳定跨平台核心，再接入 HTTP 和 Apple 平台能力。
- 每个阶段都有可执行验收，不以目录或空文件数量衡量完成度。
- 医疗安全、来源追溯和证据不足降级行为先于界面美化。
- Windows 只做编辑、Git、静态审查与测试生成；SwiftPM 构建测试由 GitHub
  Actions Ubuntu 容器执行，iOS 结论必须来自 Mac/Xcode。

## 阶段 1：基础架构

交付：

- `SlowWalkDomain`、`SlowWalkRiskEngine`、`SlowWalkAPIContracts`、
  `SlowWalkDataInterfaces`。
- Swift 6 严格并发配置和单向依赖。
- 根配置、脚本、CI、范围和架构文档。

验收：

- GitHub Actions Ubuntu 容器中的 `swift build`、`swift test`。
- 无循环依赖、无 Apple 平台 API 泄露到核心。

## 阶段 2：确定性风险引擎

交付：

- 过敏、重复有效成分、频繁使用、持续使用。
- 来源/置信度不足、识别失败和身体指标数据质量规则。
- 集中演示阈值、稳定原因顺序和最高等级合并。

验收：

- 绿、黄、橙、红场景。
- 多规则命中、7 天边界、未来记录、重复记录和固定 Clock。
- 原因代码、证据、建议动作和家人/专业人员标记的精确断言。

## 阶段 3：共享 API 与数据接口

交付：

- API v1 请求、响应、错误 DTO。
- Medicine/Profile/Record Repository 与缓存协议。
- 线程安全内存实现。
- 五个 fixture envelopes 与独立 API examples。

验收：

- DTO 编码后再解码保持语义。
- 所有 fixtures 可读取并解码。
- Repository 基本读写、缺失值和并发访问测试。

## 阶段 4：Swift 服务端

交付：

- Hummingbird 2.x `GET /health`。
- 历史 `POST /api/v1/risk/assess` 已关闭；正式药品评估统一由
  `POST /api/v1/medicine/assess` 经 `MedicinePipeline` 编排。
- request ID、结构化错误、基础日志和演示数据组合。

验收：

- 健康检查、成功风险评估、非法 JSON、错误媒体类型、字段缺失和版本错误测试。
- Ubuntu CI 构建并运行全部服务端测试。

## 阶段 5：iOS 集成

在 Mac/Xcode 上完成：

- 正式 Xcode 工程、签名、权限和 Swift Package 依赖。
- MedicineScanner、RiskResult、HealthProfile、MedicationHistory、LocationGuard。
- Vision OCR、网络、持久化、语音、定位适配。
- Dynamic Type、VoiceOver、色彩之外的风险表达和失败恢复。

验收：

- 模拟器与真机编译。
- 权限拒绝、离线、超时、低置信度和识别失败路径。
- UI、无障碍、隐私、性能和数据清除测试。

## 后续阶段

只有在安全评审和数据治理完成后，才考虑真实药品数据、认证、云持久化、家属协作或
通知。大语言模型不得进入最终风险计算；任何文字辅助都必须保留来源和规则结果。

## 完成定义

- 代码、文档、示例和 API 字段一致。
- 所有适用构建与测试真实执行并记录结果。
- 未验证部分明确列出，不以“理论可行”替代。
- Git diff 不包含密钥、个人隐私、真实健康数据或构建产物。
