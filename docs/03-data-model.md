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
  isRefreshing: Bool
  statusText: String
  demoDualRing: Bool
  alwaysVisible: Bool
  manualMove: Bool
  ringPlacement: RingPlacement
  launchWithCodexPet: Bool
  aroundRingScale: CGFloat
  outerRingColor: RingColor
  innerRingColor: RingColor
```

Windows Core 使用语义对应的 `UsageWindow`、`UsageSnapshot` 与 `UsageState`；
其中 `IsRefreshing` 和只读 `StatusText` 与 macOS 展示规则一致。平台层可使用
不同持久化机制，但不得改变用量、错误和刷新状态的含义。

### 状态文本优先级

1. 正在手动刷新 → `正在刷新…`
2. 双环演示开启 → `双环演示（本地模拟）`
3. 有旧快照且刷新失败 → `刷新失败，仍显示上次数据`
4. 无快照且请求失败 → 显示具体错误
5. 有快照 → 显示最近更新时间
6. 无数据 → `等待 Codex 用量`

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

Windows 使用当前用户注册表保存平台展示偏好；同样不持久化实时用量、
`IsRefreshing`、错误、app-server 输出或窗口画面。Windows pet 定位只读取
GUI 状态文件中的布局几何键，不扩大到认证字段。

## 错误与降级

- 无 Codex 可执行文件或 app-server 退出：显示错误，保留界面控制偏好。
- 找不到宠物但 companion 仍在运行：保留圆环；详情卡仅由 `alwaysVisible` 决定。开启随 Codex pet 启动且 Codex 已退出时，两个面板均隐藏。
- 无屏幕录制权限或捕获失败：使用容器窗口的比例估算；若有最近一次可信的实测边界，临时失败不会覆盖它；不保存任何画面。
- macOS 13：捕获实现会降级为窗口几何估算，但当前菜单入口和授权状态仍需
  B38 按系统版本门禁；完成前不能宣称“不请求且明确标示”已完全实现。
- Windows GUI 几何状态不可用：回退到系统窗口候选；原生窗口集成需要在
  Windows CI／实机验证。
- Codex Desktop／CLI 协议变化：对发布说明所记录的确切稳定版本验证真实契约
  和 parser fixtures；发布后的新版本不自动视为已支持。不兼容时显示明确错误，
  不生成模拟额度。
