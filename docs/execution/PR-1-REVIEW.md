# PR #1「增加 Windows 版」检查报告

检查日期：2026-07-24  
PR：https://github.com/Rabbitmeaw/codex-usage-loop/pull/1  
检查提交：`2ae92beab223eb0541ca2093f9e4f7f7c55fab49`

## 结论

当前不要合并，建议先 `Request changes`。

这不是小型兼容补丁，而是 32 个文件、3,929 行新增代码的一套独立 Windows
实现。macOS 回归验证已通过，但 Windows CI 尚未获准运行，并且静态审查发现
一个会影响混合 DPI 多显示器定位的高风险问题。

## 你需要做什么

1. 先决定项目是否从“仅 macOS”扩展为“macOS + Windows”。当前
   `AGENTS.md` 仍把项目限定为 macOS 13+ 原生 SwiftPM 应用。
2. 如果接受 Windows 进入同一仓库，可在
   [Actions run 30088858235](https://github.com/Rabbitmeaw/codex-usage-loop/actions/runs/30088858235)
   点击 `Approve and run workflows`。这只会启动临时 CI，不会合并 PR。
3. 要求贡献者修复混合 DPI 多显示器定位，并补充可复现测试。
4. 要求修正文档中的实现矛盾和未经独立验证的“已完成”声明。
5. 等 `macos` 与 `windows` 两个 job 全绿，再在真实 Windows 10/11、混合 DPI
   多显示器环境进行人工验收，之后才考虑合并。

## 合并阻塞项

### 1. 混合 DPI 多显示器可能把 pet 映射到错误显示器

`src/CodexUsageLoop.Windows/PetLocator.cs:177-193` 使用“物理屏幕原点 ÷
当前屏幕缩放”推导每块屏幕的 Electron 逻辑原点。Windows 混合 DPI
虚拟桌面不能按每块屏幕自身缩放独立反算。

典型场景是主屏 4K、200%，右侧副屏 1080p、100%。现有评分可能选中错误的
显示器，随后 `PetLocator.cs:85-97` 会把副屏 pet 和圆环画到主屏。

修复后至少应覆盖：

- 不同 DPI 的左右排列；
- 不同 DPI 的上下排列；
- 负坐标和非零原点；
- pet 从一块屏移动到另一块屏。

当前 `scripts/test-windows-integration.ps1:110-140` 只验证当前 runner 的卡片
尺寸，没有覆盖跨屏 pet 映射。

### 2. CI 尚未运行

唯一的 GitHub Actions run 状态为 `action_required`，没有生成 job 或 check。
这是首次外部贡献者需要维护者批准工作流，不是测试通过。

静态检查未发现上传数据、读取认证文件或危险系统级写入；工作流也没有使用
仓库 secrets。批准 CI 的风险可控，但批准后仍需等待实际结果。

### 3. 项目边界和决策文档互相矛盾

- 项目级 `AGENTS.md` 仍明确规定这是 macOS 13+ 原生 SwiftPM 应用。
- `docs/execution/DECISIONS.md:92-99` 写的是 CMake、C++20 和顶层窗口交叉
  校验；实际 PR 使用 .NET 10、C#，且持久化状态命中后直接返回。
- `docs/execution/PROGRESS.md` 把多个 Windows 批次直接标为“已完成”，包括
  Windows 10/11、240 DPI 和实机视觉验收，但本次 PR 没有可独立复核的证据。

如果决定接收 Windows，应先统一这些契约；验收完成前相应批次应标为
“进行中”或“待验收”。

## 已验证

- `git diff --check main...origin/pr/1`：通过。
- PR 快照执行 `swift test --disable-sandbox`：43 项通过，0 失败。
- PR 快照执行 `swift build -c release --disable-sandbox`：通过。
- CI YAML 包含独立的 `macos` 与 `windows` job，语法和调用路径合理。
- 静态安全检查未发现网络上传、认证文件读取、系统级 ACL 修改或机器级注册表
  写入。

## 尚未验证

- Windows `.NET 10` 编译、单文件发布与 23 项核心检查；
- Win32 分层窗口生命周期集成测试；
- Windows 10 22H2 与 Windows 11 实机；
- 混合 DPI、多显示器、负坐标和跨屏移动；
- Windows 商店版 Codex 与独立 CLI 的真实兼容行为。

## 可直接发给贡献者的回复

> 感谢提交 Windows 版本。这个 PR 范围较大，我们暂时不能直接合并。请先修复
> 混合 DPI 多显示器的映射：当前按每块屏幕的物理原点除以自身 scale 推导
> Electron 逻辑原点，在 4K 200% 主屏加 1080p 100% 副屏等场景可能匹配到
> 错误显示器。请补充不同 DPI、负坐标、左右／上下排列和跨屏移动测试。
> 另外请把 D-015 中的 CMake/C++20 描述改为实际的 .NET/C# 实现，并把尚未由
> CI 或维护者复核的 Windows 批次从“已完成”调整为“待验收”。修改后我们会
> 批准并运行 macOS/Windows CI，再继续实机验收。
