# 代码库地图

## 入口与界面

- `AppController.swift`：应用入口、菜单栏、双 `NSPanel`、定时刷新、位置计算、颜色选择与交互模式。
- `UsageView.swift`：圆环、悬停卡片和 SwiftUI 容器。
- `Models.swift`：`UsageWindow`、`UsageSnapshot`、`UsageStore`、`RingPlacement` 与 sRGB `RingColor` 偏好。
- `PetGeometry.swift`：候选窗口评分、宠物估算、坐标换算与圆环位置的纯几何计算。

## 外部边界

- `CodexAppServerClient.swift`：启动本机 `codex app-server --stdio`，发送 JSON-RPC，解析限额。
- `PetWindowLocator.swift`：从 CGWindowList 选取宠物容器、读取 Codex 本地展示位置提示、处理显示器匹配。
- `ScreenCaptureMascotLocator.swift`：在已有权限下使用 ScreenCaptureKit 和本地像素聚类得到更准确的宠物边界。

## 交付与测试

- `scripts/build-app.sh`：release 构建、创建 `.app`、生成图标、写入 Info.plist、ad-hoc 签名。
- `scripts/package-release.sh`：调用构建脚本并生成 Release ZIP、SHA-256 与构建元数据。
- `Tests/CodexPetUsageMacTests/UsageModelTests.swift`：模型、默认偏好与自定义颜色持久化测试。
- `Tests/CodexPetUsageMacTests/PetLocationTests.swift`：窗口评分、坐标换算和像素宠物定位样例。
- `README.md`：使用、构建、隐私与已知边界。

## 人工批注待补

- 哪些 Codex Desktop 版本和宠物布局是发布支持范围。
- 是否允许依赖 ChatGPT 窗口名称作为兼容候选。
- 对外分发是否为近期目标。
