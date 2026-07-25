# 发现与决策摘要

本文件是阶段性研究摘要。当前批次状态以
[`docs/execution/PROGRESS.md`](docs/execution/PROGRESS.md) 为准，不可逆决策以
[`docs/execution/DECISIONS.md`](docs/execution/DECISIONS.md) 为准。

## 已验证发现

- macOS 与 Windows 都能通过本机 app-server 获取 5 小时和 7 天用量；协议异常
  时显示错误，不伪造数据。
- “立即刷新”和 pet 几何重测是不同职责；两端现已拆分，刷新期间由
  `IsRefreshing`／`isRefreshing` 驱动 `StatusText`／`statusText`。
- 全局右键监听会影响其他应用，已移除；控制入口集中在菜单栏或通知区域。
- Computer Use 的 `Software Cursor` 等辅助窗口可能命中旧候选规则，现已排除。
- macOS 屏幕捕获仅适合作为用户授权后的本地精确化路径；无权限及 macOS 13
  必须保留窗口几何估算。
- Windows 适合独立 Win32 平台层，不应让 Win32 或 AppKit 条件判断跨平台扩散。
- 用户主动打开官方 Releases 可以提高更新可发现性，同时保持应用进程自身不
  主动联网；macOS 使用 `NSWorkspace`，Windows 使用
  `ProcessStartInfo.UseShellExecute`。

## 已采纳取舍

| 主题 | 当前取舍 |
| --- | --- |
| 数据与隐私 | 无自有服务端／数据库；不读取认证文件，不保存截图 |
| macOS 定位 | 窗口几何为基础；macOS 14+ 可由用户主动授权像素级定位 |
| macOS 13 | 估算定位且不承诺像素级精度；B38 门禁已实现，待实机 smoke |
| Windows 架构 | .NET 10 Core + 独立 Win32 平台层 |
| 刷新交互 | 只刷新用量，无菜单或全局快捷键；失败时保留旧数据 |
| 更新策略 | 不检查、不下载、不安装；仅显式打开浏览器 |
| Codex 兼容 | 每个 Release 记录并支持当次已回归的确切稳定版本与能力契约，不维护历史版本矩阵 |
| 发布安全 | macOS 开源工件使用 ad-hoc 完整性签名，无 Developer ID 或公证 |

## 验证基线

- macOS：54 项 Swift 测试。
- Windows Core：29 项检查。
- Windows 原生窗口集成与 macOS 13 实机 smoke 属于发布／CI 验证边界；B38
  的自动化门禁结果不能替代 macOS 13 实机运行。
