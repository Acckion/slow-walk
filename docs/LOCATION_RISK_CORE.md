# 位置风险核心

## 定位与安全边界

`SlowWalkLocationRisk` 是不依赖 Apple 平台定位框架的纯 Swift 演示核心。它只处理调用方已经提供的位置样本，不读取 GPS、不申请权限、不执行后台定位，也不提供正式地图导航。

所有阈值均标记为：

- `DEMO LOCATION SAFETY CONFIGURATION`
- `NOT A PRODUCTION NAVIGATION STANDARD`

这些阈值只能用于架构验证、fixture 和自动化测试，不能作为生产导航或绝对位置安全标准。

## 模块依赖

```text
SlowWalkDomain
    ↓
SlowWalkLocationRisk
    ↓
SlowWalkAPIContracts
    ↓
SlowWalkServer
```

- `SlowWalkLocationRisk` 只依赖 `SlowWalkDomain` 提供的 `Clock`。
- `SlowWalkAPIContracts` 复用正式位置模型定义 API v1 DTO。
- `SlowWalkServer` 只负责解码、输入分类、错误映射和依赖注入。
- Hummingbird route 不包含位置判断规则。
- 跨平台模块不导入 `CoreLocation`、`MapKit`、`SwiftUI` 或 `UIKit`。

## 数据流

```text
LocationSample
  → LocationDataQualityAssessor
  → HaversineDistanceCalculator
  → GeofenceEvaluator
  → ProlongedStopEvaluator / MovingAwayEvaluator
  → LocationRiskEngine
  → LocationAssessment
  → LocationActionCardFactory
```

风险计算不使用随机数、网络或大语言模型；相同输入与相同 `Clock` 必须产生相同输出。

## 数据质量

`LocationDataQualityAssessor` 检查：

- 经纬度范围与有限数值；
- 未来、过期和乱序时间戳；
- 缺失、负值或低质量 horizontal accuracy；
- 非法 speed；
- 超出可配置速度阈值的瞬时跳跃；
- 可用样本数量。

存在无效或不足数据时，核心不会输出确定性绿色结果。Server 在全部数据过期、全部精度不足或可靠历史不足时分别返回稳定 typed error。

## 距离与地理围栏

`HaversineDistanceCalculator` 使用固定地球半径和 Haversine 公式，单位统一为米。它显式处理相同坐标、赤道和 ±180° 经度边界，不依赖 `CLLocation`。

`GeofenceEvaluator` 按 destination radius 与可配置 approaching buffer 输出：

- `outside`
- `approaching`
- `inside`

## 异常停留

`ProlongedStopEvaluator` 同时要求：

- 样本数与时间跨度达到阈值；
- 样本最大空间跨度位于停留半径内；
- 最新位置与目的地仍有足够距离。

单独命中只产生 orange 演示风险，不把普通短时间等车直接标为紧急风险。

## 持续远离

`MovingAwayEvaluator` 要求：

- 至少三个可靠样本；
- 足够时间跨度；
- 连续距离增量超过噪声容差；
- 总远离距离超过配置阈值。

单个点、单次远离或 GPS 小幅噪声不会触发规则。

## 风险合并

`LocationRiskEngine`：

1. 保留全部命中原因并稳定排序；
2. 使用命中规则的最高等级；
3. 数据不足至少 yellow；
4. 可靠样本进入目的地 geofence 时可返回 green；
5. 单个 prolonged stop 或 moving away 为 orange；
6. 至少两个独立 orange 信号才按 demo 配置升级为 red；
7. red 不会被低等级提示覆盖。

`LocationActionCardFactory` 根据最终等级生成结构化提示。它只建议用户在安全位置重新确认、检查方向或主动联系家属/工作人员，不会自动联系任何人。

## API

### `POST /api/v1/location/assess`

请求：

```json
{
  "destination": {
    "id": "fictional-destination",
    "name": "虚构目的地",
    "point": {
      "latitude": 10.0,
      "longitude": 20.0
    },
    "geofenceRadiusMeters": 50.0
  },
  "recentSamples": [],
  "requestID": "00000000-0000-0000-0000-000000000001",
  "apiVersion": "v1"
}
```

成功响应包含：

- `LocationAssessment`
- `LocationActionCard`
- `warnings`
- `generatedAt`
- `requestID`
- `apiVersion`

稳定错误码：

- `INVALID_LOCATION_SAMPLE`
- `LOCATION_DATA_STALE`
- `LOCATION_ACCURACY_INSUFFICIENT`
- `INSUFFICIENT_LOCATION_HISTORY`
- `UNSUPPORTED_API_VERSION`
- `MALFORMED_REQUEST`

错误响应不返回完整轨迹、内部文件路径或调用栈。

## Fixtures

八个 fixture 使用虚构坐标并覆盖：

- 到达；
- 接近；
- 低精度；
- 过期数据；
- 异常停留；
- 持续远离；
- 正常接近；
- 非法坐标。

当前未验证 `CoreLocation`、后台定位、地图、真机 GPS、真实公交路线、推送通知或 Apple 平台 UI。
