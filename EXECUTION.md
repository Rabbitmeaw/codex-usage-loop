# CodexUsageLoop for macOS · 执行入口

## 一句话

为 macOS Codex 宠物提供本地、非侵入式的用量圆环和详情卡，不收集或上传用户数据。

## 新会话顺序

1. 阅读 `AGENTS.md`、本文件与 `docs/02-architecture.md`。
2. 阅读 `docs/execution/PROGRESS.md`，选择第一个待完成批次。
3. 阅读 `docs/execution/DECISIONS.md`，确认不可违反的边界。
4. 先补充或更新相关测试，再实施最小变更。
5. 运行批次指定验收命令，更新进度与必要的决策记录。

## 常用命令

```bash
swift test
swift build -c release
zsh scripts/build-app.sh
codesign --verify --deep --strict "dist/CodexUsageLoop.app"
```

## 目录

```text
Sources/CodexPetUsageMac/  应用实现
Tests/CodexPetUsageMacTests/ 单元测试
Resources/                 打包资源
scripts/                   本地构建与打包
docs/                      产品、架构与执行契约
.github/workflows/         CI
dist/                      本地生成的应用包，不纳入版本控制
```
