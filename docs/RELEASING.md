# Release 发布流程

本文档面向项目维护者和 fork 的发布者，不是普通下载安装步骤。普通用户请从 [GitHub Releases](https://github.com/Rabbitmeaw/codex-usage-loop/releases) 下载，并阅读 [Release 安全说明](RELEASE_SECURITY.md)。

## 发布前检查

1. 确认工作区干净，目标提交已审阅并已推送。
2. 更新 [CHANGELOG.md](../CHANGELOG.md)，并确定版本号与对应 Git tag。
   在 [`docs/releases/`](releases/README.md) 中增加同名的
   `vX.Y.Z.md` 版本化说明。
3. 在 macOS 运行 `swift test`，当前基线为 54 项测试；运行
   `zsh scripts/build-app.sh` 和严格 `codesign` 校验。
4. 在 Windows 运行 `scripts/build-windows.ps1` 和
   `scripts/test-windows-integration.ps1`；当前 Core 基线为 29 项检查。
5. 选择准备写入 Release 说明的稳定 Codex Desktop／CLI 确切版本，验证真实
   app-server 契约、parser fixtures 与窗口／状态定位。不兼容时必须显示错误，
   不得发布伪造数据；发布后的新版本不自动视为已支持。
6. 在可用平台完成实机 smoke。macOS 13 必须确认不请求截图权限、明确显示
   估算、圆环可用且可重测；Windows 必须确认通知区域、原生消息循环、分层窗口、
   点击穿透和退出。
7. 将版本、变更记录和版本化说明提交到 `main`，推送并等待日常 CI 通过。

## 自动发布

日常 CI 只在 PR 和 `main` push 时执行，不创建 Release。正式发布只接受
`vX.Y.Z` tag；tag 必须指向 `origin/main` 中的提交，并与 macOS Bundle、
两个 app-server client 和 Windows 项目版本一致。

从已通过 CI 的 `main` 提交创建并推送 annotated tag：

```bash
git tag -a v0.1.3 -m "v0.1.3"
git push origin v0.1.3
```

`.github/workflows/release.yml` 会独立执行以下门禁：

1. 验证 tag 的主分支归属、版本一致性和版本化说明。
2. 在 macOS 重新运行测试、打包、严格签名校验和 SHA-256 校验。
3. 在 Windows 重新运行核心测试、单文件打包、原生集成和 SHA-256 校验。
4. 检查构建元数据中的版本与提交，随后创建 GitHub Release 并上传五个工件。

只有最终发布 job 获得 `contents: write`；其他 job 和日常 CI 均为只读权限。
Release 说明以版本化文件为前言，并追加 GitHub 自动生成的提交记录。

当前自动流程仅发布正式版本。若需要预发布，必须先定义 tag 后缀与 macOS
`CFBundleShortVersionString` 的映射规则，不直接使用现有正式发布入口。

## 本地生成工件

### macOS

在仓库根目录执行：

```bash
zsh scripts/package-release.sh <version>
```

例如：

```bash
zsh scripts/package-release.sh 0.1.2
```

脚本会构建应用、校验其 ad-hoc 签名，并在 `dist/` 中生成：

- `CodexUsageLoop-<version>.zip`
- `SHA256SUMS.txt`
- `RELEASE_METADATA.txt`

### Windows

在 Windows PowerShell 中执行：

```powershell
.\scripts\package-windows.ps1 -Version <version>
```

Windows 工件名称和运行时依赖以脚本输出及
[`docs/WINDOWS.md`](WINDOWS.md) 为准。macOS 上的交叉构建可以验证编译和
单文件发布，但不能替代 Windows 原生集成 smoke。

推送正式 tag 后，Release workflow 会在 Windows 原生 runner 完成测试、集成
检查与打包；本地打包用于发布前复核，不能代替 workflow 的发布门禁。

## 发布内容

版本化 Release 说明必须明确：

- 包未使用 Developer ID 签名，未经过 Apple 公证；
- 下载者应核对校验和、tag 与提交；
- 安全使用细节见 [Release 安全说明](RELEASE_SECURITY.md)。
- 两个平台支持本次回归并记录确切版本的 Codex 稳定版及能力契约，不承诺未经
  本次回归的历史版本或发布后的新版本。

不要建议下载者关闭 Gatekeeper。ad-hoc 签名仅用于应用包完整性校验，不提供开发者身份保证。

不要手工创建同名 Release 后再推送 tag；自动流程使用 `--verify-tag` 且不会
覆盖既有 Release 或工件。

## 发布后核验

从 Release 页面重新下载各平台工件，核对校验和，并确认 Release 所指向的
tag 与构建元数据中的提交 ID 一致。分别在可用的 macOS 与 Windows 环境执行
一次安装／启动 smoke，并确认应用自身没有发起版本检查或自动更新。
