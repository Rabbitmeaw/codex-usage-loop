<p align="right">
  <a href="#中文">中文</a> · <a href="#english">English</a>
</p>

<a id="中文"></a>

# CodexUsageLoop

Codex 宠物的本地用量伴随层，在 macOS 和 Windows 上显示 5 小时与 7 天
剩余额度。

## 平台

| 平台 | 原生实现 | 使用说明 |
| --- | --- | --- |
| macOS 13+ | AppKit / SwiftUI；macOS 14+ 可选 ScreenCaptureKit 像素级定位 | 见下方功能与构建说明 |
| Windows 10 22H2 / Windows 11 x64 | .NET 10 + Win32 分层窗口，不使用 WinUI、WPF 或 WinForms | [Windows 构建、运行与限制](docs/WINDOWS.md) |

Windows 商店版 Codex GUI 的内置 CLI 当前不能由普通桌面进程直接启动；实时
额度需要独立安装官方 Codex CLI 或设置 `CODEX_EXECUTABLE`。没有独立 CLI
时，pet 圆环和本地交互仍可使用。Windows 通知区域菜单的“立即刷新”只请求
最新用量，“重新检测宠物位置/大小”独立重查几何；两者都不注册快捷键。也可
由用户主动在默认浏览器打开官方 Releases，应用自身不检查、下载或安装更新。

## 兼容策略

macOS 13 的兼容目标是窗口几何估算且不承诺像素级精度；macOS 14+ 才可由
用户主动启用像素级定位。B38 已完成菜单、授权和捕获门禁的代码与自动化，
仍需 macOS 13 实机 smoke 后才视为完整交付。Codex Desktop／CLI 不固定历史版本
矩阵；每个 Release 只承诺其发布说明中记录的已回归稳定版本与能力契约，发布后
的新版本不自动视为已支持。不兼容时显示明确错误，不伪造用量。详见
[决策日志](docs/execution/DECISIONS.md)与[发布流程](docs/RELEASING.md)。

## macOS 界面示意

<p align="center">
  <img src="docs/images/single-ring.png" alt="单环用量显示在 Codex 宠物周围" width="260">
  <img src="docs/images/dual-ring.png" alt="双环同时显示两个用量窗口" width="280">
</p>

<p align="center">
  <em>左：单窗口用量；右：双窗口用量。截图右上角的浅蓝“1”为说明标记，不属于应用界面。</em>
</p>

<p align="center">
  <img src="docs/images/usage-card.png" alt="常驻用量详情卡显示剩余比例和重置时间" width="620">
</p>

<p align="center">
  <em>常驻详情卡会显示剩余比例、重置时间与最近更新时间；浅蓝“1”为说明标记，不属于应用界面。</em>
</p>

<p align="center">
  <img src="docs/images/left-layout.png" alt="圆环固定在 Codex 宠物左侧，详情卡显示在下方" width="540">
</p>

<p align="center">
  <em>左侧布局示例：圆环与宠物分离，详情卡位于圆环下方。浅蓝“2”为说明标记，不属于应用界面。</em>
</p>

## macOS 功能

- **两类用量一眼可见**：读取本机 Codex app-server 的 5 小时与 7 天剩余额度；一个窗口显示单环，两个真实窗口自动显示双环。
- **围绕真实 pet 的像素级定位**：在 macOS 14+ 且已授权屏幕录制时，圆环圆心与直径直接使用当前可见 pet 的实测像素边界。pet 缩放、拖动、任务卡布局变化和左右边缘位置都会触发重新测量。
- **低能耗的稳定跟随**：成功测量会缓存；只有首次定位或容器／布局变化时才采集 3 个短时样本并取中位数。稳态不持续截图；窗口几何仅以轻量级 1 秒检查维持跟随，用量每 30 秒刷新。
- **三种布局与常驻详情**：选择围绕 pet、左侧或右侧；围绕模式的常驻卡片固定在圆环右侧，左右侧模式固定在圆环下方，并限制在当前屏幕可见范围。
- **可调外观**：围绕模式圆环可在 75%–150% 缩放，双环比例保持一致；内外环可分别使用原生 macOS 取色器设置并持久化，菜单栏图标可切换原色蓝绿或随系统对比度变化的单色。
- **可控交互**：可临时开启自由拖动；关闭后恢复跟随。支持“立即刷新”和“重新检测宠物位置/大小”。真实双环存在时，“演示双环”自动禁用，绝不以模拟值覆盖真实数据。
- **与 Codex pet 共存**：悬浮层默认点击穿透，没有全局右键监听，不影响 pet 的右键菜单、任务卡展开／收起或其他基础功能。
- **可选伴随启动**：安装登录 companion 并开启“随 Codex 宠物启动”后，Codex Desktop 退出时暂停用量读取并隐藏悬浮层；pet 隐藏但 Codex 仍运行时，圆环保留，卡片由“始终显示用量卡片”决定。
- **本地与最小权限**：不读取认证文件，不上传用量或屏幕画面，不保存截图；屏幕录制授权只在用户从菜单主动请求时触发。

## macOS 常用操作

| 目标 | 操作 | 结果 |
| --- | --- | --- |
| 调整 pet 大小或位置后重新贴合 | 菜单栏图标 → **重新检测宠物位置/大小** | 清除定位缓存并对当前 pet 重新定位；已授权时重新读取可见像素边界。 |
| 立即获得最新额度 | 菜单栏图标 → **立即刷新** | 仅请求最新用量；刷新中和失败状态会显示在卡片中，失败时保留上次数据。为避免与前台应用冲突，不设置快捷键。 |
| 保持详情卡显示 | 菜单栏图标 → 勾选 **始终显示用量卡片** | 即使鼠标未悬停，或 pet 已隐藏但 Codex 仍运行，也显示详情卡；圆环在该场景始终保留。 |
| 临时把圆环移到别处 | 勾选 **自由拖动位置** 后拖动圆环 | 关闭该选项即可恢复自动跟随 pet。 |
| 调整围绕模式视觉大小 | **围绕 pet 的圆环大小** → 拖动滑杆 | 在 75%–150% 间实时缩放；可选择“恢复默认（100%）”。 |
| 改变环或菜单栏图标外观 | **圆环颜色**／**菜单栏图标** | 可分别修改内外环，或切换原色蓝绿与单色跟随系统。 |
| 在 macOS 14+ 获得最准确的位置和直径 | **启用像素级定位…** → 按 macOS 流程授权并重新打开 | 授权后菜单显示“已授权（像素级定位）”，围绕模式按实测 pet 边界定位。 |

### pet 可见性规则

| 场景 | 圆环 | 用量卡片 |
| --- | --- | --- |
| Codex 运行，pet 可见 | 自动跟随 pet | 悬停圆环或勾选“始终显示用量卡片”时显示 |
| Codex 运行，pet 隐藏 | 保留在最近位置；无历史位置则显示在安全位置 | 只由“始终显示用量卡片”决定 |
| 已开启“随 Codex 宠物启动”，Codex 已退出 | 隐藏 | 隐藏 |
| 未开启“随 Codex 宠物启动”，Codex 已退出 | 保持显示 | 仍由“始终显示用量卡片”决定 |

## macOS 构建与启动

要求 macOS 13+、Xcode Command Line Tools，以及已登录的 Codex CLI 或 Codex Desktop。构建后可直接重启本机实例：

```bash
zsh scripts/build-app.sh
zsh scripts/restart-app.sh
```

如需安装到 `/Applications` 并注册到启动台：

```bash
zsh scripts/install.sh
```

可选：安装登录 companion 后，在菜单开启“随 Codex 宠物启动”。它会等待 Codex Desktop，Codex 退出时暂停用量读取。pet 隐藏时圆环会保留；若还要保留详情卡，请同时勾选“始终显示用量卡片”：

```bash
zsh scripts/install.sh --with-login-agent
```

## macOS 权限与隐私

用量通过本机 `codex app-server --stdio` 的只读接口获取，不读取、解析或上传 `~/.codex/auth.json`。在 macOS 14+，如需精确识别透明宠物窗口内的实际边界，**建议在 macOS“系统设置 → 隐私与安全性 → 屏幕录制”中授权 CodexUsageLoop**；图像只在本机内存中分析，不保存、不上传。应用不会主动访问互联网；只有当你选择“在浏览器查看 GitHub Releases…”时，macOS 才会在默认浏览器打开官方发布页，CodexUsageLoop 自身不会检查、下载或安装更新。

应用不会在启动时自动弹出屏幕录制授权。在 macOS 14+ 需要精确定位时，请在菜单选择“启用像素级定位…”，再按 macOS 的流程授权并重新打开应用。未授权时应用仍可通过 pet 容器的窗口几何估算进行基本跟随，但在非默认布局、pet 实际边界与容器比例不同或任务卡片改变位置时，圆环的位置和直径可能出现偏差。授权后会使用当前窗口的可见 pet 像素边界作为圆心与直径来源，以获得更准确的贴合效果。

菜单会显示当前进程实际检测到的“屏幕录制：已授权（像素级定位）”或“未授权（使用估算）”。若系统设置中的开关显示已开启、菜单仍显示未授权，请关闭再重新开启该开关，然后重启应用。

## macOS 已知定位边界

当宠物特别靠近屏幕左侧或右侧边缘时，圆环的自动跟随可能失效。请将宠物稍微向屏幕内侧移动，保持圆环中心到左右边缘至少约为半个任务卡片宽度的距离，再重新检测宠物位置／大小。

## macOS 下载与安全

项目采用 [MIT License](LICENSE)，Release 不提供 Developer ID 签名或 Apple 公证。请只从[官方 GitHub Releases](https://github.com/Rabbitmeaw/codex-usage-loop/releases)下载，核对 SHA-256 校验和与 tag；确认来源后再按 macOS 提示打开应用，**不要关闭 Gatekeeper**。详见[安全使用说明](docs/RELEASE_SECURITY.md)。

## 文档

### 用户文档

- [用户手册](docs/MANUAL.md)
- [Windows 构建、运行与限制](docs/WINDOWS.md)
- [变更记录](CHANGELOG.md)
- [Release 安全说明](docs/RELEASE_SECURITY.md)

### 开发与维护

- [发布流程](docs/RELEASING.md)
- [架构](docs/02-architecture.md)

<p align="right"><a href="#english">English ↓</a></p>

---

<a id="english"></a>

# CodexUsageLoop

A local Codex pet companion that displays the remaining 5-hour and 7-day usage
allowances on macOS and Windows.

## Platforms

| Platform | Native implementation | Guide |
| --- | --- | --- |
| macOS 13+ | AppKit / SwiftUI; optional ScreenCaptureKit pixel-level positioning on macOS 14+ | See the macOS features and build instructions below |
| Windows 10 22H2 / Windows 11 x64 | .NET 10 + native Win32 layered windows; no WinUI, WPF, or WinForms | [Windows build, runtime, and limitations](docs/WINDOWS.md) |

The Codex CLI bundled with the Microsoft Store GUI currently cannot be launched
by a regular desktop process. Live usage on Windows requires a separately
installed official Codex CLI or `CODEX_EXECUTABLE`; pet rings and local
interactions remain available without it. In the Windows notification-area menu,
**Refresh now** only requests usage, while pet geometry re-detection remains a
separate action; neither action registers a shortcut. Users can explicitly open
the official Releases page in their default browser, but the app itself never
checks for, downloads, or installs updates.

## Compatibility policy

The macOS 13 compatibility target is window-geometry estimation without
pixel-level guarantees; user-enabled pixel positioning requires macOS 14+.
The B38 menu, authorization, and capture gates are implemented and covered by
automated tests; a macOS 13 smoke test is still required before this target is
considered fully delivered. Rather than freezing a historical
Codex Desktop/CLI version matrix, each release supports only the exact stable
versions and capability contract recorded after its release validation; later
Codex versions are not assumed compatible. Incompatibilities produce explicit
errors instead of fabricated usage. See the
[decision log](docs/execution/DECISIONS.md) and
[release process](docs/RELEASING.md).

## macOS features

- **Usage at a glance:** reads the local Codex app-server's 5-hour and 7-day windows. One real window renders one ring; two real windows render dual rings.
- **Pixel-accurate pet geometry:** on macOS 14+ with Screen Recording access, the around-pet ring uses the visible pet's measured pixel bounds for both center and diameter. Resizing, dragging, task-card layout changes, and left/right edge placement trigger a new measurement.
- **Stable, low-energy tracking:** a successful measurement is cached. Capture runs only for the first measurement or a container/layout change, collects three short samples, and uses their median. There is no continuous capture while stable; lightweight window geometry is checked once per second and usage refreshes every 30 seconds.
- **Three layouts and a persistent card:** choose around, left, or right. In around-pet mode, the persistent card sits to the ring's right; in side modes it sits below the ring and stays within the visible screen.
- **Adjustable appearance:** around-pet rings scale from 75% to 150% while preserving dual-ring proportions. Outer and inner colors can be set independently with the native macOS color panel and persisted; the menu-bar icon supports blue/green color or system-adaptive monochrome.
- **Controlled interaction:** temporarily enable free dragging, then turn it off to resume pet following. **Refresh now** refreshes usage only; pet geometry recalibration remains a separate action. A real dual ring disables **Demo dual ring**, so simulated data never replaces real usage.
- **Coexists with the Codex pet:** the overlay is click-through by default and has no global right-click listener. It does not change the pet's context menu, task-card expansion, or other native behavior.
- **Optional companion startup:** install the login companion and enable **Start with Codex pet**. Usage reading pauses and both panels hide when Codex Desktop quits. While Codex is running and the pet is hidden, the ring stays visible and **Always show usage card** controls the detail card only.
- **Local and minimal-permission:** the app never reads auth files, uploads usage or screen imagery, or saves captures. On macOS 14+, Screen Recording is requested only after the user selects the menu action.

## macOS common tasks

| Goal | Action | Result |
| --- | --- | --- |
| Refit after moving or resizing the pet | Menu-bar icon → **Re-detect pet position / size** | Clears cached geometry and repositions around the current pet; with permission, it remeasures visible pixels. |
| Get current usage immediately | Menu-bar icon → **Refresh now** | Refreshes usage only, shows progress or failure, and keeps the last data on failure. No shortcut is assigned to avoid conflicts with the frontmost app. |
| Keep the detail card visible | Enable **Always show usage card** | The ring and detail card remain visible without hovering. |
| Move the ring temporarily | Enable **Free drag position**, then drag the ring | Disable it to resume automatic pet following. |
| Change around-pet size | **Around-pet ring size** → move the slider | Adjusts from 75% to 150%; **Reset to default (100%)** restores the default. |
| Change ring or menu-bar appearance | **Ring colors** / **Menu-bar icon** | Set outer and inner colors independently, or choose color and system-adaptive monochrome icon modes. |
| Get the most accurate center and diameter on macOS 14+ | **Enable pixel-level positioning…** → authorize in macOS and reopen | The menu reports **Authorized (pixel-level positioning)** and around-pet geometry uses measured pet bounds. |

### Pet visibility rules

| Situation | Ring | Detail card |
| --- | --- | --- |
| Codex running, pet visible | Follows the pet | Shown while hovering the ring or when **Always show usage card** is enabled |
| Codex running, pet hidden | Retains its most recent position, or a safe fallback position | Controlled only by **Always show usage card** |
| **Start with Codex pet** enabled, Codex quits | Hidden | Hidden |
| **Start with Codex pet** disabled, Codex quits | Remains visible | Controlled by **Always show usage card** |

## macOS build and run

Requires macOS 13+, Xcode Command Line Tools, and a signed-in Codex CLI or Codex Desktop installation. Build and restart the local instance with:

```bash
zsh scripts/build-app.sh
zsh scripts/restart-app.sh
```

To install into `/Applications` and register it with Launch Services:

```bash
zsh scripts/install.sh
```

Optional: install the login companion and enable **Start with Codex pet** from the menu. It waits for Codex Desktop and pauses usage reads when Codex quits. The ring remains visible while the pet is hidden; also enable **Always show usage card** to retain the detail card:

```bash
zsh scripts/install.sh --with-login-agent
```

## macOS permissions and privacy

Usage is read from the local, read-only `codex app-server --stdio` interface. The app does not read, parse, or upload `~/.codex/auth.json`. On macOS 14+, for precise detection inside the transparent pet window, **we recommend granting CodexUsageLoop Screen Recording access** in macOS System Settings → Privacy & Security; frames are analyzed only in local memory and are never stored or uploaded. The app does not proactively access the internet. Only when you choose **View GitHub Releases in Browser…** does macOS open the official release page in your default browser; CodexUsageLoop itself never checks for, downloads, or installs updates.

The app never requests Screen Recording automatically at launch. On macOS 14+, when precise positioning is needed, choose **Enable pixel-level positioning…** from the menu, then follow macOS’s authorization and relaunch flow. Without permission, the app still follows the pet using estimated window geometry, but the ring's position or diameter can be less accurate with non-default layouts, a mascot whose visible boundary differs from the container proportions, or a repositioned task card. Granting access makes the visible pet pixel bounds the source of the around-pet ring's center and diameter.

On macOS 14+, the menu reports the permission seen by the current process: **Screen Recording: Authorized (pixel-level positioning)** or **Not authorized (estimated positioning)**. On macOS 13, it reports that estimated positioning is in use and disables the pixel-level authorization action. If System Settings shows its switch as enabled while the menu still reports not authorized on macOS 14+, turn the switch off and on again, then restart the app.

## macOS known positioning boundary

Automatic ring tracking can fail when the pet is extremely close to the left or right edge of a display. Move the pet slightly inward so the ring center remains at least roughly half a task-card width from either side, then use **Re-detect pet position / size**.

## macOS downloads and security

The project is licensed under the [MIT License](LICENSE). Releases do not have a Developer ID signature or Apple notarization. Download only from the [official GitHub Releases](https://github.com/Rabbitmeaw/codex-usage-loop/releases), verify the SHA-256 checksum and tag, and follow macOS only after confirming the source. **Do not disable Gatekeeper.** See the [release security guide](docs/RELEASE_SECURITY.md).

## Documentation

### For users

- [User manual](docs/MANUAL.md)
- [Windows build, runtime, and limitations](docs/WINDOWS.md)
- [Changelog](CHANGELOG.md)
- [Release security guide](docs/RELEASE_SECURITY.md)

### For developers and maintainers

- [Release process](docs/RELEASING.md)
- [Architecture](docs/02-architecture.md)

<p align="right"><a href="#中文">中文 ↑</a></p>
