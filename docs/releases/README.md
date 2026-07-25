# 版本化 Release 说明

每个正式 tag 的提交中必须包含与 tag 同名的说明文件：

```text
docs/releases/vX.Y.Z.md
```

自动发布会把该文件作为 Release 说明前言，并在其后追加 GitHub 自动生成的变更
记录。文件至少应包含：

- 面向用户的主要变化；
- `## 验证` 小节；
- 本次实际回归的 Codex Desktop／CLI 确切版本与能力契约；
- macOS `ad-hoc` 签名且未公证、Windows 无 Authenticode 签名的说明；
- 核对 tag、提交与 SHA-256 的下载建议，以及不要关闭 Gatekeeper 的提醒。

当前自动流程仅接受 `vX.Y.Z` 正式版本。预发布版本需要先单独定义 tag 与
`CFBundleShortVersionString` 的映射规则，不能直接把 `-rc` 后缀写入 macOS
版本字段。
