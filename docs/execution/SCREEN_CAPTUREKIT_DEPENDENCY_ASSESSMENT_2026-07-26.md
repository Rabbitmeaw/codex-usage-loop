# 降低 ScreenCaptureKit 必要性评估

日期：2026-07-26

## 结论

可以做到，而且 macOS 现有实现已经完成了主要的降级架构：ScreenCaptureKit 不是基本跟随的硬依赖，而是 macOS 14+、用户授权后的可选像素级精确化能力。

在屏幕录制权限未授予、运行中失效或捕获失败时，应用仍可通过 CGWindowList 的可见容器几何、Codex 本地 GUI 状态中的锚点与布局方向，持续给出估算 pet 框；候选窗口暂时消失时，还会尝试使用状态文件中的完整几何。因此“基本跟随完全失效”不是当前设计的预期行为。

不过，不能把状态文件或窗口属性承诺为跨 Codex 版本、始终精确的位置和尺寸真值。当前环境的活动显示器状态只有位置、显示器范围和 placement，缺少 mascot 或 anchor 尺寸；这时只能可靠地跟随位置，尺寸仍是估算。ScreenCaptureKit 仍是获得当前可见边界与缩放尺寸的唯一通用精确路径。

## 已有链路

```text
完整当前状态几何
    → 精确 pet frame（无需屏幕录制）
不完整状态 + 可见 pet 容器
    → 状态锚点 + CGWindowList 容器估算
无候选窗口
    → 最后可信实测 frame，或完整持久化几何
以上均不可用
    → 保留 companion 的安全默认位置

ScreenCaptureKit（已授权且 macOS 14+）
    → 只细化当前可见 pet 的像素边界与尺寸
```

实现证据：

- `PetWindowLocator` 读取的仅是 `~/.codex/.codex-global-state.json` 内的 `electron-avatar-overlay-bounds` 与 `electron-avatar-overlay-open`，不读取认证文件；见 `Sources/CodexPetUsageMac/PetWindowLocator.swift:194`。
- 可见窗口候选使用 CGWindowList 的 owner、title、bounds 和 windowID；持久化锚点与 placement 参与候选评分和估算；见 `PetWindowLocator.swift:85`。
- 屏幕录制未授权或 macOS 13 时，`ScreenCaptureMascotLocator` 返回估算框而不是失败；见 `Sources/CodexPetUsageMac/ScreenCaptureMascotLocator.swift:141` 与 `:251`。
- 候选窗口短暂消失时，定位器优先保留最后一次实测框，再回退到持久化状态；见 `PetWindowLocator.swift:124` 与 `:177`。
- 没有 pet 框时，`AppController` 仍保留圆环的独立可见性与安全位置；见 `Sources/CodexPetUsageMac/AppController.swift:568`。

## 状态与窗口属性的可行性

状态文件在部分 Codex 历史显示器记录中出现过完整字段：容器 `x/y/width/height`，相对 pet 矩形 `mascot.left/top/width/height`，或绝对 `anchor.x/y/width/height`。字段齐全且属于当前显示器时，可直接构造真实 pet frame，不需要 ScreenCaptureKit。

但当前活动记录不含这些完整尺寸字段，只包含 `x/y/displayBounds/displayId/placement`。这与现有分析记录一致：`byDisplayId` 和 `byResolution` 是缓存或布局提示，不能被当作当前 pet 尺寸的稳定来源。窗口 `bounds` 也通常是透明 Electron 容器，而非可见 mascot 的边界。

因此：

| 来源 | 可提供 | 可靠性 | 建议用途 |
| --- | --- | --- | --- |
| 当前显示器的完整状态记录 | 位置和尺寸 | 高，但字段并非总存在 | 无权限时的首选精确路径 |
| 顶层完整状态 | 位置和尺寸 | 中，结构可能随版本变化 | 次选精确路径，需范围校验 |
| CGWindowList + 状态锚点 | 容器、位置、布局方向 | 中，窗口身份是启发式 | 基本跟随和估算尺寸 |
| ScreenCaptureKit | 实际可见边界和尺寸 | 高，需用户授权 | 可选精确化与缩放校准 |

## 当前缺口

1. 当前 macOS 路径仅从 `byDisplayId` 取 mascot 尺寸，没有将其中完整的 `x/y/mascot` 或 `anchor` 组合为当前精确 frame；历史记录绝不能误用，必须先确认记录的 displayId 与当前活动显示器匹配。
2. 顶层完整 `mascot` 已能在“无候选窗口”时作为 `persistedFallback` 使用，但有候选窗口时优先走锚点加容器估算，尚未把完整状态提升为无权限时的首选 frame。
3. 权限失效的完整回归缺少可注入测试。`CGPreflightScreenCaptureAccess()` 目前直接调用，无法稳定模拟“已有实测框 → 权限撤销 → pet 移动”的链路。
4. CGWindowList 的 owner/title 仍是启发式。Computer Use 辅助窗口已被排除，但普通 Codex 小窗口仍需以状态锚点和多候选 fixture 降低误选风险。
5. macOS 13 的自动能力门禁已覆盖，但发布环境实机 smoke 尚未完成。

## 2026-07-26 无屏幕录制实机观察

用户在其图形登录会话中运行了不带 `--capture` 的 60 秒只读探针，并移动了可见 pet、切换了任务卡布局。探针连续命中同一候选：`owner=ChatGPT`、`title=Codex`、`windowID=1516`；容器固定为 408×400，窗口坐标、状态锚点和 placement 都会随交互更新。由此确认 CGWindowList 候选和状态锚点不是推测，而是在当前 Codex Desktop 会话中可观察的真实输入。

同时观察到二者不是原子同步的。一次移动中，容器已从右侧更新为左侧附近，而 `overlayAnchor` 仍保留先前右侧坐标；约一秒内才变为新位置。这说明原始输入存在短暂时序差，但单独探针不复现应用内的实测缓存与容器投影，不能据此断言用户界面会停在旧位置。

后续用户在同一实机测试中确认：圆环会正常跟随 pet，即使移动到左右屏幕边缘也正常；只有圆环大小始终与可见 pet 不完全贴合。因此，该实测确认无屏幕录制的基本位置跟随有效，问题收敛为无当前精确尺寸来源时的尺寸估算偏差。

用户补充的两张未授权截图进一步确认：圆心会以近乎固定的相对偏移落在 pet 的右下方，且 pet 视觉大小变化时圆环直径不随之变化。这正符合当前 fallback 的实现：它以固定 119:356 与 129:320 比例从透明容器构造代理尺寸，并以状态锚点替换该代理框的 origin。当前会话的容器保持 408×400，所以代理框持续为约 136×161，围绕模式的圆环直径也保持恒定。该代理框能提供位置连续性，但不是实际可见 pet 的边界。

同日的应用统一日志提供了实现级证据：七次 `source=anchoredFallback` 更新中，pet origin 随拖动从 `[576,189.75]` 变到 `[984,-54.25]`，圆心也相应移动；但每次 pet 尺寸都固定为 `136.382022×161.25`，`ringDiameter` 也固定为 `235.212898`。日志本身不能证明用户是否操作了缩放控件；若这些位置变化间确有 pet 缩放操作，则它直接证明该操作未向无授权定位路径暴露任何尺寸变化。

## 无授权精度的最终边界

当前可验证输入只给出 pet 的锚点和透明容器。锚点可用于稳定附着位置，但围绕 pet 的圆心等于 pet origin 加上实际宽高的一半；实际宽高未知时，不可能让圆心在所有缩放比例下都精确。固定补偿只能改善某个默认尺寸，缩放后仍会偏移；同理，左右侧圆环也需要实际宽度才可精确贴边。

没有新的权限时，只有两类来源可能改变这个结论：Codex 将当前 pet 的完整几何持久化为公开且可验证的字段，或当前透明窗口的尺寸随 pet 缩放而变化。当前实测均不成立。macOS Accessibility API 只能访问另一应用公开的可访问元素，且需要独立的辅助功能信任；它不能通用地提供任意渲染图像的像素边界，因此既不能替代 ScreenCaptureKit，也不符合“无额外授权”的目标。

因此无授权模式可以承诺“稳定锚点跟随”，不能承诺“围绕实际 pet 的精确圆心和自适应直径”。可选的无权限体验改进仅包括：提供用户手动选择的 pet 尺寸／偏移校准，或将圆环改为相对锚点的固定 companion 徽标；两者都不是自动精确定位。

## 最小后续方案

不需要改变产品边界，也不需要增加权限。若决定进一步降低依赖，建议按以下顺序实施：

1. 为当前活动显示器新增纯解析器：只接受完整且自洽的 `byDisplayId` 或顶层字段，验证显示器范围、非零尺寸、容器包含关系与当前 displayId。`mascot` 是相对容器的坐标，`anchor` 是绝对坐标，必须分别构造 frame；成功时生成 `persistedExact` frame。
2. 保持已有 `measured` frame 及其随容器移动的投影为最高优先级，不能在捕获暂不可用时用状态或估算框覆盖它。仅在没有有效测量缓存时采用“当前完整状态 → CGWindowList 加锚点估算 → 现有安全默认位置”；ScreenCaptureKit 不变，仅在可用时写入新的 `measured`。
3. 加入 fixture：完整当前记录、仅历史完整记录、仅锚点记录、损坏记录、多窗口竞争，以及权限撤销后的继续跟随。
4. 在 macOS 13 和 macOS 14+ 无授权环境执行手动 smoke：启动、拖动、隐藏／显示、跨显示器和状态文件暂时不可用。
5. 为“窗口先更新、状态随后更新”的输入时序加入 fixture，确保缓存与投影路径继续保持实机已验证的位置跟随；不要仅凭原始探针的不同步结果改变现有优先级。
6. 将未授权展示明确为“位置跟随估算、尺寸固定估算”，并为容器 408×400 与不同实际 pet 尺寸加入 fixture，防止把固定比例代理框误称为自适应尺寸。

这会把 ScreenCaptureKit 从“当前尺寸的通用准确来源”进一步收敛为“当 Codex 未提供完整当前状态时的可选精确化”，但不应移除它，也不应对所有 Codex 版本承诺无权限下的像素级精度。
