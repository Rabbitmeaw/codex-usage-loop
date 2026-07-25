# CodexUsageLoop · 执行入口

## 一句话

为 macOS 与 Windows 的 Codex 宠物提供本地、非侵入式的用量圆环和详情卡，不收集或上传用户数据。

## 新会话顺序

1. 阅读 `AGENTS.md`、本文件与 `docs/02-architecture.md`。
2. 阅读 `docs/execution/PROGRESS.md`，选择第一个待完成批次。
3. 阅读 `docs/execution/DECISIONS.md`，确认不可违反的边界。
4. 先补充或更新相关测试，再实施最小变更。
5. 运行批次指定验收命令，更新进度与必要的决策记录。

## 常用命令

```bash
swift test
zsh scripts/build-app.sh
codesign --verify --deep --strict "dist/CodexUsageLoop.app"
```

Windows 构建与集成验证在 Windows PowerShell 中执行：

```powershell
.\scripts\build-windows.ps1
.\scripts\test-windows-integration.ps1
```

## 目录

```text
Sources/CodexPetUsageMac/       macOS 应用实现
Tests/CodexPetUsageMacTests/    macOS 单元测试
src/CodexUsageLoop.Core/        Windows 平台无关模型、解析与几何
src/CodexUsageLoop.Windows/     Windows Win32 应用实现
Tests/CodexUsageLoop.Core.Tests/ Windows 核心测试
scripts/                        两个平台的构建、验证与打包脚本
docs/                           产品、架构与执行契约
.github/workflows/              CI
dist/                           本地生成的工件，不纳入版本控制
```

根目录的 `progress.md`、`findings.md`、`功能缺口审计.md` 与
`项目进度报告.md` 保留阶段性摘要；批次状态的唯一权威来源是
`docs/execution/PROGRESS.md`。
