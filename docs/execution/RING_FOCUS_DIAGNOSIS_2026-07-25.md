# 圆环位置／大小突然失焦诊断

日期：2026-07-25

## 结论

根因不是圆环渲染、用户缩放值或坐标换算突然变化，而是宠物窗口候选误选。

定位器把新出现的 `ChatGPT Computer Use` 辅助窗口 `Software Cursor` 当成了 Codex pet 窗口。该窗口只有 `126×126 pt`。像素检测无法从中识别宠物后，定位器使用这个错误窗口计算降级几何，得到 `42.117978×50.793750 pt` 的“pet”，最终把围绕圆环缩成 `74.092063 pt` 并移动到错误锚点。

## 现场证据

项目自带只读探针在故障现场返回：

```json
{
  "windowID": 24036,
  "owner": "ChatGPT Computer Use",
  "title": "Software Cursor",
  "container": {
    "width": 126,
    "height": 126
  },
  "estimatedPet": {
    "width": 42.117977528089888,
    "height": 50.793750000000003
  }
}
```

统一日志在相同窗口 `24036` 上持续报告：

```text
pet capture unavailable reason=detectorRejected window=24036
```

失败重试约每 5 秒发生一次，符合 `MascotCaptureRefreshPolicy.missingResultRetryInterval`。
当前日志中该错误候选的首条异常出现在 `2026-07-25 10:25:13`，与“几分钟前突然发生”的时间描述吻合。

几何日志随后记录：

```text
pet geometry source=anchoredFallback
pet=[…, …, 42.117978, 50.793750]
ringDiameter=74.092063
```

尺寸链路可完全复算：

```text
错误窗口高度 126
→ 降级 pet 高度 126 × 129 ÷ 320 = 50.79375
→ 圆环直径 50.79375 × 194.35 ÷ 129 × 用户缩放 0.968203… = 74.092063
```

计算值与运行日志完全一致。

## 代码链路

1. `PetWindowLocator.locate()` 接受 owner 名称包含 `codex` 或 `chatgpt` 的任意小窗口。
2. `PetWindowCandidateScoring.score()` 对 owner 含 `chatgpt` 的窗口增加 `100000` 分。
3. `ChatGPT Computer Use / Software Cursor` 因而压过真正的 Codex pet 窗口，成为候选。
4. `ScreenCaptureMascotLocator` 对这个窗口截图，宠物检测失败。
5. 因错误候选的 window ID 与先前测量的真实 pet window ID 不同，`lastMeasuredPet` 的同窗口保护无法生效。
6. 定位器返回由错误 `126×126` 容器推导出的 `anchoredFallback`。
7. `AppController` 正确地按照这个错误 pet frame 计算圆环，所以圆心与直径一起失焦。

## 为什么是“突然发生”

这条缺陷只有在 `ChatGPT Computer Use` 的 `Software Cursor` 辅助窗口出现并进入系统窗口列表时才触发。此前不存在该窗口时，宽泛的 `chatgpt` owner 匹配没有造成冲突；窗口出现后，固定的高额 owner 加分会立即改变候选排序。

因此这是外部窗口集合变化触发的确定性候选冲突，不是运行时间累积、动画采样抖动或随机失焦。

独立调试复核对该主因给出的置信度为 `0.99`。

## 排除项

- 用户设置仍为 `ringPlacement=around`，`aroundRingScale=0.968203…`，没有异常跳变。
- 当前几何来源明确是 `anchoredFallback`，不是坏的 `measured` 结果被缓存。
- `swift test` 共 43 项全部通过，说明现有回归测试没有覆盖“ChatGPT Computer Use 辅助窗口与 Codex pet 同时存在”的候选冲突。
- 当前实际运行的是 `/Applications/CodexUsageLoop.app`，不是仓库中的 `dist/CodexUsageLoop.app`；但现场运行包包含相同的宽泛候选和几何日志逻辑，因此这不是本次失焦的直接原因。

## 修复边界建议

本轮只诊断，未修改运行代码。后续最小修复应先增加可复现测试，再收紧候选身份规则，使 `ChatGPT Computer Use`、`Software Cursor` 等辅助窗口不能参与 pet 候选评分；同时保留对真实 Codex Desktop 历史 owner 名称的兼容。

## 补充：重新检测为什么没有恢复

用户在 Computer Use 会话结束后点击“重新检测宠物位置/大小”，圆环仍未恢复。再次采样确认：

```json
{
  "windowID": 24036,
  "owner": "ChatGPT Computer Use",
  "title": "Software Cursor",
  "container": {
    "width": 126,
    "height": 126
  }
}
```

Computer Use 的交互会话虽然结束，`Software Cursor` 窗口仍保留在 `.optionOnScreenOnly` 系统窗口列表中。因此重新检测不能自行恢复：

1. 菜单动作 `recalibrate()` 调用 `PetWindowLocator.reset()`。
2. `PetWindowLocator.reset()` 只清空 `ScreenCaptureMascotLocator` 的截图结果、输入、尝试时间和 pending 状态。
3. 它不会关闭外部窗口，也不会改变候选准入与评分规则。
4. 紧接着执行的 `updateOverlay()` 重新枚举系统窗口。
5. 仍在列表中的 `ChatGPT Computer Use / Software Cursor` 再次获得最高分，并立即重新成为候选。
6. 新一轮截图继续对 window `24036` 报告 `detectorRejected`，定位器再次返回错误的 `anchoredFallback`。

日志在约 `10:50:45` 显示重新检测后的几何重新计算，圆环直径短暂为 `70.563869 pt`，下一秒随错误窗口恢复到 `74.092063 pt`。这证明按钮动作已执行，但其语义只是“清缓存后用同一套规则重测”，无法修正候选身份错误。

`PetWindowLocator.lastMeasuredPet` 没有解决该问题：当前存在一个得分更高的实时错误候选，因此代码不会进入“完全没有候选时返回上次测量”的保护分支；错误候选的 window ID 也与真实 pet window 不同，不能复用同 window ID 的测量保护。

## 修复结果

B21 已按测试优先完成最小修复：

1. 先增加候选准入回归测试；实现前测试因缺少 `accepts` API 编译失败。
2. 增加大小写不敏感的精确主应用 owner 准入，仅接受 `Codex` 与历史 `ChatGPT`。
3. `PetWindowLocator` 在计算候选评分前应用该准入规则。
4. 未修改评分公式、像素检测、缓存、坐标换算或圆环布局。

自动验证：

- 定向 `PetLocationTests`：16 项通过。
- 完整 `swift test`：45 项通过。
- release 应用构建通过。
- ad-hoc 应用包通过 `codesign --verify --deep --strict`。

现场验证：

- 修复版已安装到 `/Applications/CodexUsageLoop.app` 并重启，只有一个运行实例。
- `Software Cursor` window `24036` 仍存在，证明冲突条件没有被人为移除。
- 修复版选择真实 `ChatGPT / Codex` window `8123`；新进程未再对 window `24036` 发起 pet 检测。
- 几何从启动降级值切换为 `source=measured pet=90×102 ringDiameter=148.785833`，不再使用错误的 `42.117978×50.793750 / 74.092063` 几何。

独立验证结论为 `PASS`。
