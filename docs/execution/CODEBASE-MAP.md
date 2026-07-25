# 代码库地图

## macOS 入口与界面

- `AppController.swift`：应用入口、菜单栏、双 `NSPanel`、定时刷新、位置计算、颜色选择与交互模式。
- `UsageView.swift`：圆环、悬停卡片和 SwiftUI 容器。
- `Models.swift`：`UsageWindow`、`UsageSnapshot`、`UsageStore`、
  `isRefreshing`／`statusText`、`RingPlacement` 与 sRGB `RingColor` 偏好。
- `PetGeometry.swift`：候选窗口评分、宠物估算、坐标换算与圆环位置的纯几何计算。

## 外部边界

- `CodexAppServerClient.swift`：启动本机 `codex app-server --stdio`，发送 JSON-RPC，解析限额。
- `PetWindowLocator.swift`：从 CGWindowList 选取宠物容器、读取 Codex 本地展示位置提示、处理显示器匹配。
- `ScreenCaptureMascotLocator.swift`：在已有权限下使用 ScreenCaptureKit 和本地像素聚类得到更准确的宠物边界。

## Windows 入口与边界

- `src/CodexUsageLoop.Core/Models.cs`：Windows 用量模型、`IsRefreshing` 与
  `StatusText`；不依赖 Win32。
- `src/CodexUsageLoop.Core/RateLimitParser.cs`：平台无关 app-server 限额解析。
- `src/CodexUsageLoop.Core/Geometry.cs`：窗口与 pet 的纯几何规则。
- `src/CodexUsageLoop.Windows/AppController.cs`：通知区域、计时器、刷新、
  重测、分层窗口及生命周期的唯一装配入口。
- `src/CodexUsageLoop.Windows/PetLocator.cs`：优先读取 GUI 布局几何，失败时
  回退系统窗口候选。
- `src/CodexUsageLoop.Windows/LayeredRenderer.cs`：GDI+ 预乘 Alpha 圆环与
  用量卡片渲染。
- `src/CodexUsageLoop.Windows/NativeMethods.cs`：集中管理 P/Invoke。

## 交付与测试

- `scripts/build-app.sh`：release 构建、创建 `.app`、生成图标、写入 Info.plist、ad-hoc 签名。
- `scripts/package-release.sh`：调用构建脚本并生成 Release ZIP、SHA-256 与构建元数据。
- `scripts/build-windows.ps1`：构建 Windows Core 与原生应用。
- `scripts/test-windows-integration.ps1`：在 Windows 验证 app-server、
  分层窗口和退出等原生生命周期。
- `scripts/package-windows.ps1`：生成 Windows 单文件发布工件。
- `Tests/CodexPetUsageMacTests/UsageModelTests.swift`：模型、默认偏好与自定义颜色持久化测试。
- `Tests/CodexPetUsageMacTests/PetLocationTests.swift`：窗口评分、坐标换算和像素宠物定位样例。
- `README.md`：使用、构建、隐私与已知边界。

当前自动化基线为 macOS 54 项 Swift 测试与 Windows Core 29 项检查。

## 发布／CI 验证边界

- macOS 13：B38 已完成菜单、授权和捕获门禁；仍需窗口几何估算实机 smoke。
- Windows：原生消息循环、托盘、分层窗口、DPI、点击穿透与退出必须在
  Windows CI／实机验证。
- Codex：不固定历史版本矩阵；每次发布记录确切稳定版本，并验证真实
  app-server 契约、parser fixtures 和窗口／状态定位。
