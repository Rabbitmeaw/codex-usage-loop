# CodexUsageLoop for macOS · 项目规范

## 项目边界

- 这是 macOS 13+ 的原生 SwiftPM 菜单栏伴随应用，不引入自有服务端或数据库。
- 用量仅由本机 `codex app-server --stdio` 提供；不得读取、解析或上传 Codex 的认证文件。
- 宠物定位优先使用系统窗口信息；ScreenCaptureKit 只能在用户已授予屏幕录制权限时作为本地、内存中的精确化手段。
- 应用必须保持为 accessory app：不出现在 Dock，不抢焦点，悬浮层默认点击穿透。

## 模块边界

- `Models.swift` 只定义值对象与可观察状态，不依赖 AppKit 或 ScreenCaptureKit。
- `CodexAppServerClient.swift` 负责 app-server 协议与数据映射，不操作界面。
- `PetWindowLocator.swift` 与 `ScreenCaptureMascotLocator.swift` 负责宠物几何；不得依赖 SwiftUI 视图。
- `UsageView.swift` 只渲染 `UsageStore` 状态，不读取系统窗口或启动进程。
- `AppController.swift` 是唯一的装配与生命周期入口，协调定时器、窗口、菜单和模块调用。

## 变更纪律

1. 新功能先更新 `docs/execution/PROGRESS.md`，有不可逆决策时追加 `docs/execution/DECISIONS.md`。
2. 修改用量协议前先确认实际 app-server 响应；不要根据记忆臆造字段。
3. 修改坐标换算、窗口筛选或像素检测前，先添加可复现测试样例。
4. 每次代码改动至少运行 `swift test`；发布包改动还须运行 `zsh scripts/build-app.sh` 与 `codesign --verify --deep --strict`。
5. 不重构与当前需求无关的代码；保留现有降级路径和用户偏好兼容性。

## 入口文档

先读 `EXECUTION.md`，再读 `docs/execution/PROGRESS.md` 与 `docs/execution/DECISIONS.md`。
