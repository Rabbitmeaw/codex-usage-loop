# 数据模型与本机状态

## 外部协议

| 接口 | 输入 | 关键输出 | 兼容策略 |
| --- | --- | --- | --- |
| `initialize` | 客户端信息与实验能力声明 | 初始化确认 | 失败时在界面显示错误，不伪造额度 |
| `account/rateLimits/read` | 无参数 | `primary`、`secondary` 限额窗口 | 兼容 `remainingPercent` 或 `usedPercent` |
| `account/rateLimits/updated` | 服务端推送 | 最新限额窗口 | 与读取结果走同一映射 |

接口属于 Codex 实验性 app-server，字段变动需先采集真实响应再更新客户端和测试。

## 内存模型

```text
UsageWindow
  label: String
  remainingPercent: Double, 范围 0 至 100
  resetsAt: Date?

UsageSnapshot
  primary: UsageWindow?
  secondary: UsageWindow?
  observedAt: Date
  source: String

UsageStore
  snapshot: UsageSnapshot?
  errorMessage: String?
  demoDualRing: Bool
  alwaysVisible: Bool
  manualMove: Bool
  ringPlacement: RingPlacement
  launchWithCodexPet: Bool
  aroundRingScale: CGFloat
  outerRingColor: RingColor
  innerRingColor: RingColor
```

## 本地持久化

| 键 | 内容 | 生命周期 |
| --- | --- | --- |
| `alwaysVisible` | 悬浮层是否常驻 | 用户修改前永久保留 |
| `manualMoveV2` | 是否启用自由拖动 | 用户修改前永久保留 |
| `ringPlacementV2` | 围绕、左侧或右侧 | 用户修改前永久保留 |
| `launchWithCodexPetV1` | Codex 退出时是否暂停 companion | 用户修改前永久保留 |
| `aroundRingScaleV1` | 围绕 pet 的圆环尺寸比例（75% 至 150%） | 用户修改前永久保留 |
| `outerRingColorV1` | 外环 sRGB 三元组 | 用户修改前永久保留 |
| `innerRingColorV1` | 内环 sRGB 三元组 | 用户修改前永久保留 |

不持久化：用量、重置时间、app-server 输出、窗口几何或屏幕图像。

## 错误与降级

- 无 Codex 可执行文件或 app-server 退出：显示错误，保留界面控制偏好。
- 找不到宠物：仅在常驻模式显示固定位置圆环，否则隐藏悬浮层。
- 无屏幕录制权限或捕获失败：使用容器窗口的比例估算，不保存任何画面。
