# 开源 Release 与安全使用说明

## 发布立场

CodexUsageLoop 将提供开源 Release 下载，但不提供 Developer ID 签名或 Apple 公证。下载包可能触发 macOS Gatekeeper 警告；这不是应用已被验证为安全的证明，也不应通过关闭系统级安全保护来绕过。

macOS 会检查互联网下载的应用是否来自已识别的开发者、是否经过公证以及是否被篡改。未签名、未公证的应用无法获得这些验证。[Apple 的 Gatekeeper 说明](https://support.apple.com/en-us/102445)

## Release 发布者要求

每个 Release 必须包含：

- `.app` 的压缩包。
- `SHA256SUMS.txt`：列出下载包的 SHA-256 校验和。
- 源码提交 ID、版本号和构建日期。
- Release 页面中指向本仓库对应 tag 的链接。
- 明确声明“未签名、未公证”，并链接本文件。

发布前在干净工作区执行：

```bash
zsh scripts/package-release.sh 0.1.2
```

该脚本会重建应用、校验 ad-hoc 签名，并生成 `CodexUsageLoop-<version>.zip`、`SHA256SUMS.txt` 与 `RELEASE_METADATA.txt`。这里的 ad-hoc 签名只用于校验应用包内部完整性，不提供开发者身份保证。

发布前可用下列命令再次验证下载工件：

```bash
(cd dist && shasum -c SHA256SUMS.txt)
```

## 下载者建议

1. 仅从项目官方 Release 页面下载；核对 Release tag、提交 ID 与 `SHA256SUMS.txt`。
2. 优先自行从已审阅的 tag 构建；不要从转发链接或未知镜像下载应用包。
3. 首次打开若被 Gatekeeper 阻止，先确认来源和校验和；随后可在“系统设置 → 隐私与安全性”中针对该应用选择“仍要打开”。Apple 说明该覆盖操作存在安全风险，应只在确认来源可信时执行。[Apple 操作说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/26/mac/26)
4. 不要全局关闭 Gatekeeper，不要以管理员权限运行应用，不要执行来源不明的“修复安全提示”脚本。
5. 屏幕录制权限只应在需要更精确宠物定位时授予；可随时在“系统设置 → 隐私与安全性 → 屏幕录制”中撤销。

## 发布前待决事项

项目采用 [MIT License](../LICENSE)，官方 Release 已托管在 [Rabbitmeaw/codex-usage-loop Releases](https://github.com/Rabbitmeaw/codex-usage-loop/releases)。每次发布前请确认目标 tag 指向已审阅的提交，并上传脚本生成的三个工件。
