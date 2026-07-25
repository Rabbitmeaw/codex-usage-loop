# 进度日志

本文件保留项目阶段性摘要。批次状态、验收证据和当前工作以
[`docs/execution/PROGRESS.md`](docs/execution/PROGRESS.md) 为唯一权威来源。

## 当前状态

- macOS 原生 AppKit／SwiftUI 版本和 Windows .NET 10／Win32 版本均已建立。
- 两个平台都通过本机 `codex app-server --stdio` 读取用量，不读取认证文件，
  不上传用量、窗口信息或屏幕画面。
- macOS 自动化基线为 52 项 Swift 测试；Windows Core 自动化基线为 29 项检查。
- “立即刷新”只刷新用量；“重新检测宠物位置/大小”独立重测几何。
- 两个平台都只允许用户主动用默认浏览器打开官方 Releases，不在应用内检查、
  下载或安装更新。

## 已完成里程碑摘要

1. 建立 macOS 用量读取、宠物定位、圆环／卡片、菜单栏控制与 Release 流程。
2. 补齐 app-server parser、坐标换算、窗口候选和像素定位回归测试。
3. 移除全局右键监听并修复 app-server EOF 忙等；完成能耗与真实桌面验收。
4. 发布 MIT 开源版本，并明确 ad-hoc 签名、无公证及校验和边界。
5. 新增 Windows 原生 Win32 伴随应用、DPI 样式、单文件构建与 CI／集成验证。
6. 排除 Computer Use 辅助窗口，拆分刷新与重测职责，并补充跨平台刷新反馈。
7. 收口 macOS 13 和 Codex Desktop／CLI 的兼容策略，详见 D-018、D-019；
   macOS 13 菜单门禁与状态修正另列 B38。

## 当前发布验证边界

- macOS 13 的目标只承诺窗口几何估算、明确状态提示和可重测；当前菜单门禁与
  授权状态尚待 B38，随后还需实机 smoke。
- Windows 原生消息循环、托盘和分层窗口集成测试必须在 Windows CI／实机执行。
- Codex 不固定历史版本矩阵；每个 Release 只承诺其发布说明记录的已回归稳定
  版本与能力契约。
