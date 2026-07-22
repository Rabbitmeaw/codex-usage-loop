# CodexUsageLoop for macOS

macOS 版 Codex 宠物用量伴随层。它将 5 小时和 7 天剩余比例显示在 Codex 宠物旁边，并提供菜单栏开关让悬浮窗常驻。

## 行为

- 默认模式：检测到 Codex 的小型宠物窗口时，透明双环持续跟随并覆盖在宠物外圈；围绕 pet 时信息卡片显示在圆环右侧，两者属于同一个悬浮层。
- 常驻模式：点击菜单栏双环图标 → `始终显示用量卡片`，用量卡片将固定在圆环旁；即使宠物隐藏也保留整个悬浮层。
- 卡片位置：圆环围绕 pet 时，卡片显示在圆环右侧；圆环在 pet 左侧或右侧时，卡片显示在圆环正下方。
- 真实用量同时返回两个窗口时自动显示双环；此时“演示双环”会被禁用，避免覆盖真实数据。
- 菜单栏双环图标 → `菜单栏图标` 可切换原色蓝绿图标与单色系统图标；单色模式会随 macOS 菜单栏自动显示白色或黑色。
- 菜单栏双环图标 → `圆环颜色` 可分别自定义外环和内环颜色；颜色以 sRGB 保存，并可恢复默认蓝绿。
- 自由移动：点击菜单栏双环图标 → `自由拖动位置`，然后拖动整个悬浮层；关闭后恢复跟随 pet。
- 悬浮层点击穿透，不抢占 Codex 或其他应用焦点。
- 用量每 30 秒刷新，宠物位置每 1 秒检查；用户已在系统设置授予屏幕录制权限后，会从 Codex 宠物窗口的实际画面识别宠物边界，因此移动到屏幕下方也不会被容器边界截停。
- 菜单栏双环图标 → `重新检测宠物位置/大小` 可在 Codex 设置中调整宠物大小后立即重新校准。

## 构建

要求 macOS 13+、Xcode Command Line Tools 和已登录的 Codex CLI 或 Codex Desktop：

```bash
zsh scripts/build-app.sh
open "dist/CodexUsageLoop.app"
```

发布者可使用 `zsh scripts/package-release.sh 0.1.0` 生成 ZIP、SHA-256 和构建元数据；发布安全要求见下文链接。

## 数据与隐私

用量通过本机已安装的 `codex app-server --stdio` 的只读接口获取，不读取、解析或上传 `~/.codex/auth.json`。为识别透明窗口内的宠物实际位置，应用仅在用户已在系统设置授予 macOS“屏幕录制”权限后使用画面；画面只在本机内存中分析，不保存、不上传。`codex app-server` 属于实验性接口，Codex 更新后可能需要兼容适配。

## 当前边界

macOS Codex Desktop 的宠物窗口命名和窗口层级可能随版本变化。本实现优先选择 Codex/ChatGPT 的可见小型窗口，并在常驻模式下即使找不到宠物也显示在屏幕左下角。

## 工程文档

- [执行入口](EXECUTION.md)
- [架构骨架](docs/02-architecture.md)
- [数据模型与本机状态](docs/03-data-model.md)
- [交付路线图](docs/execution/PROGRESS.md)
- [真实环境验收矩阵](docs/execution/MANUAL_ACCEPTANCE.md)
- [决策日志](docs/execution/DECISIONS.md)
- [开源 Release 与安全使用说明](docs/RELEASE_SECURITY.md)
- [用户手册](docs/MANUAL.md)
- [变更记录](CHANGELOG.md)
