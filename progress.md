# 进度日志

## 会话：2026-07-22

### 阶段 1：需求与发现

- **状态：** complete
- 执行的操作：审阅 `AppController`、`Models`、`UsageView` 和打包脚本。
- 结论：刷新和重新检测已有实现；常驻卡片与双环演示互斥需要修复。

### 阶段 2：测试与方案

- **状态：** complete
- 执行的操作：新增 `OverlayBehaviorTests`，先运行失败测试，再实现生产代码。
- 创建/修改的文件：`Tests/CodexPetUsageMacTests/OverlayBehaviorTests.swift`、`Sources/CodexPetUsageMac/Models.swift`、`Sources/CodexPetUsageMac/AppController.swift`。

### 阶段 3：图标替换

- **状态：** complete
- 执行的操作：已生成透明背景蓝绿双环图标，完成本地抠图并写入 `Resources/AppIcon.png`；构建脚本已切换资源，并成功生成含 alpha 的 `.icns`。

### 阶段 4：测试与交付

- **状态：** complete
- 执行的操作：运行 `swift test`、打包脚本与 `codesign --verify --deep --strict`。
- 结果：5 个单元测试通过；应用包签名和图标 alpha 校验通过。

### 阶段 5：右键监听移除

- **状态：** complete
- 执行的操作：确认全局 `.rightMouseDown` 监听为跨应用交互风险，已移除监听、回调与终止清理代码。
- 验证：`swift test` 5 项通过；打包与签名校验通过；源码中不存在全局右键监听相关符号。

### 阶段 6：应用身份更名

- **状态：** complete
- 执行的操作：已将用户可见名称、构建产物、Bundle 标识、菜单提示与 app-server 客户端标题切换为 `CodexUsageLoop`。
- 验证：Info.plist、可执行文件和透明图标均已核验；旧名称应用包已移除，5 项测试与签名校验通过。

### 阶段 7：菜单栏图标与能耗优化

- **状态：** complete
- 执行的操作：状态栏改为加载打包的 `AppIcon.icns`；失败截图改为 5 秒退避，成功结果复用至几何变化；只精确捕获评分最高候选窗口；轮询调整为 1 秒且避免无变化面板更新。
- 验证：7 项单元测试通过，release 应用包签名通过，图标资源存在于应用包中。

### 阶段 8：菜单栏图标模式与服务重启

- **状态：** complete
- 执行的操作：实现并持久化原色／单色菜单栏图标；已精确结束旧 PID `9392`，并启动新版 PID `62797`。
- 验证：8 项测试通过，应用包签名通过，新进程路径为 `dist/CodexUsageLoop.app`。

### 阶段 9：功能缺口审计

- **状态：** complete
- 执行的操作：对照 README、路线图、架构、决策日志和源码，写入 `功能缺口审计.md`。
- 结论：菜单功能均有调用链；主要缺口为协议／定位测试、人工验收、macOS 13 策略和发布能力。

### 阶段 10：审计计划更新与自定义颜色设计

- **状态：** complete
- 执行的操作：将发布路线改为未签名、未公证的开源 Release，并新增安全使用说明；将自定义内外环颜色列入 B10。
- 输出：`docs/RELEASE_SECURITY.md`、更新后的 README、架构、决策和路线图。

### 阶段 11：B01 限额解析与偏好测试

- **状态：** complete
- 执行的操作：新增 `RateLimitParser` 并让 app-server 客户端复用；新增解析与偏好持久化测试。
- 验证：`swift test` 12 项通过，0 失败。

### 阶段 12：B02 宠物定位与坐标换算测试

- **状态：** complete
- 执行的操作：抽取候选窗口评分、宠物估算、CG→AppKit 坐标和圆环位置的纯几何计算；新增透明背景像素宠物定位样例。
- 验证：先以缺失 API 的测试确认测试覆盖点，再实现生产代码；`swift test` 17 项通过，0 失败。
- 文档：新增 `docs/MANUAL.md` 和 `CHANGELOG.md`，并同步 README、架构和路线图。

### 阶段 13：B03 真实环境验收矩阵

- **状态：** in_progress
- 执行的操作：新增 `docs/execution/MANUAL_ACCEPTANCE.md`，记录单、多显示器、权限、图标、双环与能耗验收标准，以及本机构建环境。
- 阻塞边界：当前自动化环境无法可靠读取或驱动真实桌面窗口；交互和 5 分钟能耗样本保留为待实际桌面会话确认，未标记通过。

### 阶段 14：B10 自定义内外环颜色

- **状态：** complete
- 执行的操作：增加“圆环颜色”菜单，以 `NSColorPanel` 分别编辑外环与内环；采用 sRGB 三元组持久化，支持恢复默认蓝绿，并让用量卡片颜色与环同步。
- 验证：先新增失败的颜色偏好测试，再实现生产代码；`swift test` 18 项通过，0 失败。

### 阶段 15：并发构建质量收口与 B04 技术准备

- **状态：** complete（技术部分）
- 执行的操作：将异步截图路径中的直接锁操作收敛为同步访问器，保持既有锁保护和退避行为；新增 `scripts/package-release.sh`，生成 ZIP、SHA-256 与构建元数据。
- 验证：`swift test` 18 项通过；`swift build -c release` 无 Swift 并发警告；RC 工件 SHA-256、ad-hoc 签名和 Info.plist 校验通过。
- 待决：B04 的开源许可证、官方 Release 托管位置与维护者身份仍需项目所有者确认。

### 阶段 16：EOF 忙等能耗修复

- **状态：** complete（短样本）
- 执行的操作：从活动监视器和 `sample`／`ps` 证实应用持续占用一个 CPU 核；定位为 app-server stdout 与 stderr 在 EOF 后仍保留可读回调，导致 `NSFileHandle.fd_monitoring` 忙等。EOF 现会移除回调。
- 验证：新增 EOF 输出策略测试；`swift test` 19 项通过。修复后重启实例，12 秒 CPU 时间 0.24 秒、约 0.6% CPU。5 分钟真实能耗采样仍列在 B03。

### 阶段 18：B03 能耗验收

- **状态：** complete（能耗项）
- 验证：修复后实例连续运行 5 分 53 秒，累计 CPU 时间 2.90 秒，当前 CPU 为 0.0%。能耗项已通过；其余涉及 Codex Desktop 实际宠物、屏幕录制权限和多显示器的交互项仍待验收。

### 阶段 17：B04 开源 Release 发布

- **状态：** complete
- 执行的操作：采用 MIT License；创建公开仓库 `Rabbitmeaw/codex-usage-loop`，推送 main，并发布 `v0.1.0`。
- 验证：Release 已包含 `CodexUsageLoop-0.1.0.zip`、`SHA256SUMS.txt`、`RELEASE_METADATA.txt`；GitHub 返回三项工件哈希并确认 Release 非草稿、非预发布。

## 测试结果

| 测试 | 输入 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| `swift test` | 固定布局与双环互斥 | 5 个测试通过 | 5 个通过，0 失败 | 通过 |
| `zsh scripts/build-app.sh` | 新图标打包 | 生成带透明图标的 `.app` | 已生成，`.icns` 含 alpha | 通过 |
| `codesign --verify --deep --strict` | 应用包 | 签名有效 | 通过 | 通过 |

## 错误日志

| 时间戳 | 错误 | 尝试次数 | 解决方案 |
|--------|------|---------|---------|
| 2026-07-22 | 初始测试缺少所需 API | 1 | 实现后复跑通过。 |
| 2026-07-22 | Swift 6 并发迁移警告 | 1 | 已在后续质量收口中将直接异步锁调用迁移为同步访问器；release 构建现无该警告。 |

## 五问重启检查

| 问题 | 答案 |
|------|------|
| 我在哪里？ | B03／B04 的外部确认前。 |
| 我要去哪里？ | 真实桌面验收与开源发布归属决策。 |
| 目标是什么？ | 完成路线图、验证真实交互，并准备可追溯的开源 Release。 |
| 我学到了什么？ | 见 `findings.md`。 |
| 我做了什么？ | 见本文件和 `task_plan.md`。 |
