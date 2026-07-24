# Release 发布流程

本文档面向项目维护者和 fork 的发布者，不是普通下载安装步骤。普通用户请从 [GitHub Releases](https://github.com/Rabbitmeaw/codex-usage-loop/releases) 下载，并阅读 [Release 安全说明](RELEASE_SECURITY.md)。

## 发布前检查

1. 确认工作区干净，目标提交已审阅并已推送。
2. 更新 [CHANGELOG.md](../CHANGELOG.md)，并确定版本号与对应 Git tag。
3. 在 macOS 13+ 环境确认 `swift test` 通过。

## 生成工件

在仓库根目录执行：

```bash
zsh scripts/package-release.sh <version>
```

例如：

```bash
zsh scripts/package-release.sh 0.1.0
```

脚本会构建应用、校验其 ad-hoc 签名，并在 `dist/` 中生成：

- `CodexUsageLoop-<version>.zip`
- `SHA256SUMS.txt`
- `RELEASE_METADATA.txt`

## 发布内容

创建与版本对应的 Git tag 和 GitHub Release，上传以上三个工件，并在 Release 说明中明确：

- 包未使用 Developer ID 签名，未经过 Apple 公证；
- 下载者应核对校验和、tag 与提交；
- 安全使用细节见 [Release 安全说明](RELEASE_SECURITY.md)。

不要建议下载者关闭 Gatekeeper。ad-hoc 签名仅用于应用包完整性校验，不提供开发者身份保证。

## 发布后核验

从 Release 页面重新下载 ZIP，核对 `SHA256SUMS.txt`，并确认 Release 所指向的 tag 与 `RELEASE_METADATA.txt` 中的提交 ID 一致。
